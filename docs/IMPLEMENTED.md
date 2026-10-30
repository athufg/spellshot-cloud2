# SPELLSHOT — everything that is actually built

**As of 2026-09-13.** Place: **Cool VFX**, placeId `126362651110745`. 29 scripts, 12,876 lines of
Luau, 55 uploaded assets.

This is an inventory of what *exists and runs*, not a plan and not a changelog. It was compiled by
reading every script in `roblox/` and by querying the live Studio DataModel — not from `README.md`,
which is a chronological pass log and is stale in places (it still says the M1 is unimplemented).

Where something is designed but has no code behind it, it is in **[§16](#16-designed-but-not-built)**,
not in the sections above it.

| | |
|---|---|
| ✅ **Built** | code exists, runs, and has been seen working |
| ⚠️ **Built, with a caveat** | works, but something about it is unfinished or unverified |
| 📋 **Data only** | defined in config; nothing executes it |
| ❌ **Not built** | does not exist |

---

## 1. What is installed in the place right now

Measured from the Edit DataModel, not assumed.

**ServerScriptService (6):** `AbilityHandler`, `CombatFeedback`, `SettingsStore`, `SpellshotService`,
`TrainingGround`, `UniformAvatar`

**StarterPlayerScripts (12):** `AbilityFX`, `DeathFX`, `DevPanel`, `FirstPersonController`,
`LoadoutMenu`, `MovementController`, `PopupScaler`, `SettingsMenu`, `SettingsRuntime`, `SlideAudio`,
`SpellshotInput`, `StatusReactions`

**StarterGui (2):** `PopArtHUD` (live), `MatchHUD_RETIRED` (present but `Disabled = true`)

**ReplicatedStorage.Spellshot (6 ModuleScripts):** `BarKit`, `Callouts`, `IconAssets`,
`PopArtAssets`, `SpellshotConfig`, `SpellshotSettings`

**ReplicatedStorage.IceMagic (5):** `CastPose`, `VFXLibrary`, `Viewmodel`, `Sounds` (folder),
`ViewmodelArm4` (model)

**ReplicatedStorage.IceMagicMeshes (13 meshes):** ChillAuraRing, CryoCharge, CryoNozzle,
CryoRuneRing, FrostTrail_01/02, NovaCrust_01–04, NovaRing, RimeCrust_01/02

**Workspace:** Baseplate, SpawnLocation, `TrainingGround` (4 dummies + 4 boards), `ViewmodelArm3`

`game.PlaceVersion` reads **158** in Edit.

---

## 2. Uniform avatar ✅

`UniformAvatar.server.lua` — every player renders with the same body regardless of the avatar they
own. Uniform R15 blocky rig at scale 1, recoloured per Element.

- **Enforced in three layers**, because any one can be bypassed:
  1. `StarterPlayer.LoadCharacterAppearance = false` — the avatar is never fetched.
  2. `ApplyDescription` with a code-built `HumanoidDescription` carrying no asset ids.
  3. A `DescendantAdded` watcher that strips anything arriving later (an Accessory from a tool, a
     Shirt from another script).
- **Colour split:** torso = Element base, arms = Element dark, hands = Element light, head and legs
  = neutral slate on every Element. The head is deliberately neutral — a headshot target that
  changed colour per Element would be a legibility advantage for some Elements. Arms are a step
  *down* in saturation because the viewmodel clones those limbs and holds them at arm's length.
- Hitbox consistency comes from uniform **scale**, which is the actual competitive requirement.

---

## 3. First person and the viewmodel ✅

`FirstPersonController.client.lua` (208 lines) + `Viewmodel.lua` (1,033 lines).

- `Player.CameraMode = LockFirstPerson`, so Roblox's own camera is kept — it already handles mouse
  lock, gamepad, and touch look controls.
- The local character is **hidden outright**; the camera renders a purpose-built pair of arms
  parented to the Camera.
- **One bare arm per side.** No sleeve, no cuff, no hand, no fingers, no Element colour on the
  geometry — the arms are skin. Two earlier attempts (cloned character limbs; an armoured gauntlet
  with fingers) were both rejected.
- `Humanoid.CameraOffset` carries both the cast punches and the crouch/slide dip; the Viewmodel owns
  that property and sums the two so neither overwrites the other.
- **The arms are normalised to one light level (2026-09-16).** Their three skin tones were solved against a Hub
  capture, i.e. against flat light with the two camera lamps off, so in the daylight range the sun plus lamps at
  full blew them out white-yellow (the user: "glowing like a lamp"). `sceneLight()` now estimates the scene's own
  light on each arm face per frame in units of that flat reference: the lamps fill the shortfall and any face the
  scene overshoots has its `Color` cut by `(1/level)^(1/2.2)` — the sRGB inverse, since a linear divide reads muddy
  brown. Flat light comes out at lamps-off and untouched tones, so the Hub is unchanged. The estimate runs per
  channel, because the range's lavender Ambient and blue skylight left the arms cool and pale once their brightness
  was right; `SkyTint` is what takes that back out.
  **Solved against captures, the way the tones were** (2026-09-16, place lighting `INK_UNDER_SUN_375`): the Hub
  control measures (244,213,148), exactly the Hub capture. In the range the arms went from (254,236,201) — the
  blowout — to (237,208,158), within about 3% of the Hub on red and green. Blue still runs +8 on one arm and +19 on
  the other: the sky term is one number for every face, and the two arms show faces that catch different amounts of
  sky. The estimate also has no idea whether the player is in shade, so a face aimed at a sun behind a wall is still
  corrected. Constants: `LampFull`, `SunShare`, `SkyShare`, `SkyTint`, `ToneGamma`, `ToneFloor`.
- Cursor is re-locked every frame above `RenderPriority.Camera`, because the stock CameraModule
  fights for it.
- **Two independent animation systems, on purpose.** `Viewmodel` drives the arms you see;
  `CastPose` drives the real body everyone else sees. Neither reads the other and they are not
  frame-matched. The viewmodel is driven from **raw local input** (is Shift down right now) rather
  than the replicated `MoveState`, so the arms move on the keypress with no round trip.

### CastPose ✅ — the third-person body layer
`CastPose.lua` (715 lines). One clip table, one stance table, applied to the real character body.

- **Clips** are one-shot and beat-timed, played on a cast; **stances** are continuous and selected
  by the character's replicated `MoveState` attribute (idle / sprint / crouch / slide).
- Because `MoveState` is a server-set character attribute, every client already has it for every
  character — the stance driver needs no remotes and no per-player wiring.
- A clip that is not `Both` leaves the off hand on the stance rather than dropping it to neutral.
- R15 rigs are `AnimationConstraint`-based now (no `Motor6D`, `C0` read-only), so poses are written
  through `Attachment0.CFrame`, and the stock Animate script is disabled server-side or it cancels
  the pose.

---

## 4. Movement ✅

`MovementController.client.lua` (401 lines). All numbers live in `SpellshotConfig.Movement`.

| | Value | Note |
|---|---|---|
| Base walk speed | 16 | Roblox default; only what you stand at |
| **Sprint** | **25** studs/s | Automatic — there is no walk, and no stamina meter |
| Crouch speed | 8 | Half base |
| Crouch hip height | 2.0 → **0.9** | Genuinely lowers head and hitbox, not just the camera |
| Crouch camera dip | −1.15 | |
| **Slide duration** | 1.1 s | |
| Slide entry speed | 27 | Or your current speed, if already faster |
| Slide end speed | 18 | Below the run — the slide gives ground back |
| Slide curve | `end + (entry−end)·(1−t^0.75)` | Front-loaded: most speed gone by halfway. Averages ~22 |
| Slide cooldown | 1.2 s | Measured from slide **start** |
| Slide minimum speed | 12 | Must actually be moving; no crouch-jump in place |
| Slide camera roll | 6.5° | Held the whole slide, 0.13 s to bank in and out — measured off RIVALS |
| Slide camera dip | −0.45 | On top of the hip-height drop; eye ends at ~2/3 standing height |
| **Slide-jump apex** | 6.0 studs | Against a normal jump's 7.2 |
| Slide-jump boost | +20 studs/s | Clamped to 40–50 |
| Slide-jump air hold | 1.2 s | Launch speed held while airborne… |
| Slide-jump land bleed | 0.35 s | …then eased back to sprint |

- **Slide exit:** still holding Crouch → crouch. Otherwise straight back into the run.
- **The slide-jump writes its own launch velocity** and never touches `Humanoid.JumpHeight`, so an
  ordinary jump is untouched by it.
- Jumping early in a slide carries further than jumping late (27+20 = 47 vs 18+20 = 38 → clamped
  40), so the timing is worth something.
- Crouch is hold-by-default with a **Toggle Crouch** setting; the keybind is rebindable on keyboard
  and gamepad.
- Input is gated while the settings or loadout menu is open.

---

## 5. Resources, state and the cast pipeline ✅

`SpellshotService.server.lua` (581 lines). Everything is exposed as **attributes** rather than a
bespoke replication channel — attributes already replicate, are cheap, and let a test script drive
the HUD without touching HUD code.

- **On the Player:** `Element`, `Mobility`, `Defense`, `Ultimate` (the loadout)
- **On the Character:** `Mana`, `UltCharge`, `CD_<role>`, `CDTotal_<role>`,
  `PassiveActive` / `PassiveExpires` / `PassiveStacks` / `PassiveProc`, `Status` / `StatusExpires` /
  `StatusTotal`, `MoveState` (None | Sprint | Crouch | Slide), `SlideReadyAt`, and the dev flags

**Baselines:**

| | Value |
|---|---|
| Max health | **150** (manual says 100; raised on request) |
| Max mana | 100 |
| Mana regen | 7/s, passive |
| Health regen | 1/s, **after a 2 s pause since the last hit** |

- Health heals **per frame** after the pause, the way mana refills — Roblox's default one-second-step
  regen script is removed by this service.
- **Ultimate charge** accrues from damage taken/dealt at `(damage)/260` per event, clamped 0–1.
- **Split of responsibility:** this script decides whether a cast is *allowed* (alive, off cooldown,
  enough mana, enough Ultimate charge) and spends the resources. `AbilityHandler` decides what the
  cast *does*. They talk over one BindableEvent, so adding an ability never means touching the
  resource rules.
- Public API for other server scripts: `Spellshot.ApplyStatus:Fire(character, status, duration)`
  and `Spellshot.AddUltCharge:Fire(player, amount01)`.

---

## 5b. The Terra kit — all 6 pieces ✅ (2026-09-18; Ultimate, Defense and Mobility 2026-09-19; Mobility replaced by Aftershock 2026-09-25)

`TerraFX.lua` draws it, `TerraHandler.server.lua` makes it hurt — the PyroFX/PyroHandler split. **Every
number in this kit is new**: the design manual gives Terra behaviour and no figures, and `SpellshotConfig`
carried none for Terra either (only the manual's cooldowns: Bulwark Wall's 16 s — dropped on 2026-09-20 for a
mana drain — and Tremor Vault's 12 s, which Aftershock took over when it replaced Tremor Vault on 2026-09-25).
They live in `TerraFX.Tuning` and are meant to be tuned.

| Slot | Key | Ability | Cooldown | Mana | Status |
|---|---|---|---|---|---|
| M1 | LMB (hold) | **Boulder Shot** | 0 (floor: 0.85 s between throws) | 4 | ✅ |
| Primary | F | **Bulwark Charge** | 9 s | 30 | ✅ |
| Passive | — | **Bedrock** | — | — | ✅ |
| Defense | E (hold) | **Bulwark Wall** | **none** (2026-09-20) | 10 to raise + **20/s** held | ✅ |
| Mobility | Q | **Aftershock** *(2026-09-25; replaced Tremor Vault)* | 12 s | 20 | ✅ |
| Ultimate | R | **Earthen Tomb** v2 *(working name; replaces Seismic Slam)* | charge-gated, spent on the catch | — | ✅ |

⚠️ **A `CastPose` bug found while filming these (fixed 2026-09-20).** `CastPose.Start`'s per-character `watch()`
asked `stateFor(character)` once and **returned** if it answered nil — which it does when `CharacterAdded` lands
before the model is in the world. That character then had *no* watchers for the rest of its life: its stance never
restanced off `MoveState`, and the Earthen Tomb and Bulwark Wall poses never played at all. Measured on a live
character: the shoulder did not move a degree through a cast of either while the VFX ran fine. It now waits for the
body instead of giving up on it. This was not new; it had been there since the watcher was written, and it silently
swallowed every attribute-driven pose.

**Animation (2026-09-20).** Three of the six now have both layers — Earthen Tomb, Boulder Shot and Bulwark
Wall, each with a `Viewmodel` clip (first person) and a `CastPose` clip (the body everyone else sees), timed to
the same beat as the effect. Bulwark Charge and Bedrock still run on the stock animation. Nothing
waits on a clip: Boulder Shot still fires on the release itself, not on an animation beat. (Aftershock,
2026-09-25, came with both layers from the start.)

**Shape language (a proposal, set by this pass).** Terra is chunky faceted polygons, built from **Parts, not
a Blender mesh kit** — flat planes and hard angles are what a Part already is, so the kit costs no upload, no
Import 3D and no mesh folder. Each rock is 5–7 facets, one flat Element tone each (Base `#826B24`, Light
`#CCBA5C`, Dark `#33210D`), with a single `Highlight` for the ink outline. An inflated black Part cannot serve
as an inverted hull the way a mesh does — a Part has no backface culling, so it would swallow the coloured
one inside it.

### Boulder Shot (M1) — the one chargeable M1 in the game
Hold LMB to gather a rock, release to throw. A tap still throws a proper boulder (24 damage, the hardest M1
hit in the game); a full 1.1 s charge doubles it to 48 and nearly doubles the rock, 2.2 → 4.1 studs. It
**drops** (26 studs/s²), so it has to be led. The charge is announced to the server on the press, which is
what lets the server clamp a release's claim to the hold it actually saw — *tested: a tap claiming a full
charge threw 27, not 48*. The hit is client-reported and server-validated like Icicle Shard's, but against an
**arc** rather than a line. The crosshair charge ring `PopArtHUD` never had is now there and closes in on the
cross as the rock gathers.

**The rework (2026-09-23) ✅ in Studio, tested in Play.** Built in Blender first
(`vfx_blocking/terra/m1_rework/`, `blender_scripts/terra/m1_rework_bl.py`) and brought into the game on request,
design and animation both. It replaces the 2026-09-20 animation and the 2026-09-18 look whole. The kit's one
realistic-lighting exception: lit stone, Neon seams and cracks, soft lit dust, PointLights. Notes:
`vfx_blocking/terra/m1_rework/INTEGRATION_m1_rework.md` §7.
- **One rock, first frame to last** (`TerraFX` "M1: BOULDER SHOT -- the look: THE REWORK").
  - The rock is `TR_Boulder_L` cut into 11 pieces: `export/terra_kit/TerraM1.fbx`, imported into
    `EarthMagicMeshes.TerraM1` (40 MeshParts), set up by `tools/terra_m1_kit_setup.lua`.
  - The pieces tear out of the floor and are whole by 0.18 s; 24 more stones feed the rock while held.
  - It grows continuously with the charge, and its cracks light at ⅓ and ⅔.
  - `Charge()` returns the rock and `FireBoulder()` flies that same rock: no swap at release.
  - First person draws the rock at the viewmodel's fist, standing in for the full-size rock `FPDepth` 11 studs
    out. Measured in Play, its distance grows on every flight frame.
- **The break.** The rock breaks back into its 11 pieces, plus 14 chunks and 30 grit, falling at 35 studs/s².
  - The debris is flown by script and raycast against the world. It is never physics parts, which shoved the
    player they broke on and became queryable floor.
  - Dust (Roblox smoke, lit), gold sparks, a light flash, and a bloom kick (third person only).
  - A scuff decal on the floor and a mark on the body. Uploaded decals: `TR_M1_Scuff` 102375587925629,
    `TR_M1_Divot` 70521802119621, grit sprite 82803520621527.
  - Everything sinks at +1.8 s and is gone by +2.3 s; the scuff is gone by +3.3 s.
- **Arms.**
  - `Viewmodel.BoulderWindup` (seconds from the press, held at 1.10) and `BoulderThrow` (Trigger 0.05) are new
    `Spline = true` clips (Catmull-Rom, the film's `FP_R`/`FP_L` rows). `SetArmOffset` carries the tremble and
    the dips under each landing stone.
  - `CastPose.BoulderWindup` / `BoulderThrow` are fitted by forward kinematics on the range dummy's rig.
- **Nothing about the shot changed:** still 24.7 at a tap and 48 at full, and the same line, drop, hit report and
  0.85 s floor. The one server change: an accepted release now *announces* the end of the hold
  (`BoulderChargeStop`, `Reason = "Release"`). Previously a release whose M1 cast was then refused left every
  other client holding the rock forever. A drop (death, the burrow) lets the rock go at once.
- **Play (2026-09-23, Dummy_16 at 24 studs):**
  - Holds of 1.30 / 0.05 / 0.50 / 0.12 s dealt 48 / 25.4 / 35.3 / 26.8.
  - No console errors; everything cleared 3.5 s later.
  - Checked visually in first and third person.
- ⚠️ **Not fixed (existing before the port):**
  - With M1 Auto-Fire on, every Boulder release is dropped by the fire interval.
  - ~~The caster's own client does not hear a server-side drop (Tremor Vault mid-charge).~~ Fixed 2026-09-25 with
    Aftershock: a `BoulderChargeStop` with Reason `"Interrupted"` (her own slam, or somebody else's Aftershock striking
    her) now tears the hold down on her own client too.

### Bulwark Charge (Primary)
26 studs in 0.62 s. The movement is the caster's own client (`DashMotor`); what it hits is swept on the
**server's** copy of the body, so nothing the client claims about who it ran into is taken. 40% damage
reduction while it runs, 35 damage and 1.2 s of **Staggered** (the existing status, raised through
`Core.ApplyStatusTag` — no new status was invented) on whoever it reaches, plus a knock along the charge.
On a dummy that is the full throw; on a player's own body the client owns the physics, so it reads as a shove.

### Bedrock (Passive)
Flat 10% off every hit while you are Terra, plus 4% per stack to a cap of five — 30% at full. Stacks build
only while committed to an attack (holding a Boulder Shot charge, or mid Bulwark Charge) and lapse together
2.5 s after you stop. *Measured with a 100-damage hit: 90 bare, 70 at five stacks, 100 as Cryo.* The count is
published as `Bedrock_Stacks` / `Stacks_Passive`, so every client draws the plates and the HUD's passive chip
reads it with no new remote.

**The plates curve round the body** (2026-09-18, on request): each bends on a 2.6-stud radius, the ring's own
radius, so it sits flush on the circle it orbits. It is three flat columns under one ink outline, so there are
shallow folds, not a smooth arc (`Tuning.Bedrock.PlateBend` / `PlateFacets`). The Blender kit's
`TR_Plate_01..04` bend the same way. Before and after: `vfx_blocking/terra/terra_bedrock_curve.png`.

⚠️ **The training range's practice thrower bypasses every mitigation in the game.** It calls
`Humanoid:TakeDamage` directly (`TrainingGround.server.lua:117`) instead of `CombatCore.DealDamage`, so
Bedrock, Cinder Shield and Heat Rush all do nothing against it. Found while testing Bedrock; not fixed here.

### Earthen Tomb v2 (Ultimate, redesigned 2026-09-19) ✅ in Studio, tested in Play
The first Earthen Tomb (an aimed fissure line, and Terra lifted on a perch of her own beside the target) was replaced in place the same day. Its pool slot, ability row, status and callout style carry over; its mechanic and its meshes do not.

**In Studio and tested in Play (2026-09-19).** `TerraTomb.fbx` was imported into `EarthMagicMeshes` and v1's pieces were removed. Pivots are fixed, and seven scripts were pushed byte-verified; `CastPose` was merged over another session's newer copy in Studio. Server logs, with a range dummy and the player at 16 studs:

| Outcome | Result |
|---|---|
| Airborne dodge | The player made a real client jump. The server judged them airborne as the head arrived (0.35 s), so the Tomb ended and nothing rose. |
| Terra misses | The dummy hopped. Terra was capped only during the 0.35 s cast and her charge stayed at 1. Her pose went 3° → 58° on `"Cast"` and back to 3° within ~0.2 s of the miss. |
| Catch → burst → land | The dummy slid 5 studs sideways and was caught anyway. Charge went 1 → 0 at the catch, and Terra's pose released on the catch frame. The dummy rose 12 studs in 1.61 s and took −75. After a 0.47 s hold, it was set down 1.0 s later. Bedrock stacked only during the grip. |
| Catch → escape | The player was the target. A real Frost Slide cast went through `CastRequest` 0.5 s into the rise and was accepted, which freed them. The Tomb ended at once with the pillar straight down; they had risen 8 studs. |
| No lock | Aim at the sky, or a target 55 studs away: no cast, and the charge stayed at 1. |

⚠️ **The server sees a client's jump ~0.25 s late** (measured in Studio). A target has to jump about that much before the head visibly reaches them, and on a live server with real ping it will be later still. A small airborne grace window would fix it, but it isn't built; it's a design call. Recording: `vfx_blocking/terra/tomb/tomb2_outcomes.mp4`. Tests: `tools/tomb_tests/`.

Every number is a proposal, in `TerraFX.Tuning.EarthenTomb`.

1. **Cast: the lock.** The server locks the enemy nearest the caster's aim line.
   - Lock rules: within 4.5 studs of the line (Cross-Slash Dash's `LockRadius`, the game's only lock precedent), in front, within the row's **Range 40** (+2 slack), with nothing solid between.
   - If there's no target, there's no cast and nothing is spent.
   - Terra holds a floor-grab pose (see below). After a 0.12 s grip, a fissure leaves her and **homes** on the target's current ground position at **60 studs/s**, re-aimed every tick. Running, turning and dashing never shake it.
   - When its head arrives (reach 2.0 × margin 1.075 = 2.15 studs), the server asks one question: is the target **airborne** on its own copy of the body? Feet more than 1.5 studs off the floor count, so a plain jump works.
   - Airborne means it ends there. Nothing is spent (`ChargeOnCatch`), and Terra is released.
   - The crack gives out after 1.6 s of travel, or off an edge.
2. **Catch.** The charge is spent now.
   - The target gets **Entombed** (`RX_Entombed`, the status tag). It's still its own status, not Rooted.
   - The target is held by Cryo Beam's lift over the plinth that erupts under them. Its claws spring open and slam shut.
   - **Terra is done at this moment:** her pose, her speed cap and her Bedrock window all end on the same server line.
3. **Rise** (1.6 s, 12 studs; v1 was 1.2 s and 10 studs). The target climbs alone.
   - A Mobility Technique the server accepts from them breaks it: the `CCBreak` stamp, the one Mobility-breaks-CC hook in the game (written for v1, reused here).
   - The target is freed that instant, and the pillar goes straight down empty. No timer is run out.
4. **Burst.** Eight boulders converge over the last 0.6 s, then a guaranteed crit: 50 × 1.5 = **75**.
   - For comparison: Boulder Shot is 48 at full, Bulwark Charge is 35, and Cryo Beam is up to ~110 over 2.4 s (46/s, in `AbilityHandler`'s `Tune`, not `SpellshotConfig`).
   - The payoff word is **ENTOMBED!** in the existing `entombed` callout style.
   - Hold 0.45 s at the top.
5. **Descent** (0.8 s). The pillar lowers with the target on it and lets them go on the floor. There is no fall damage anywhere.

Once the target is caught, the Tomb no longer needs Terra: it runs out even if she falls. It ends early only if she leaves the arena or the game.

**The floor-grab pose.** `CastPose.Clips.EarthenTombReach` is a held pose, not an animation clip: knees bent, body folded over, both arms driven down.
- `CastPose` plays it while Terra's replicated `TombPhase` attribute is `"Cast"`, and releases it (at `ReleaseRate` 22) the moment that changes.
- `TombPhase` is set in the same server call that moves the mechanic on, so the pose can't drift from the mechanic.
- Bedrock's `committing()` and her `SpeedCapUlt` 0 key off the same phase, so her Bedrock window is now the grip, not the climb.
- The first-person Viewmodel has no matching pose. That's left for the animation pass.

**Its own kit** (`blender_scripts/terra/build_terra_tomb.py` → `TerraTomb.fbx`, 14 pieces, 3,303 tris; none reused from Terra's other pieces):
- **Pillar:** `TR_Tomb_Plinth`, a monolith split along two slanted fractures, and `TR_Tomb_Clamp_01/02`, claws that flare out and hook in over the shoulders, pivoting at the root.
- **Fissure:** `TR_Tomb_Crack_01/02` (chainable 1.5-stud segments), `TR_Tomb_CrackHead` (a splinter spray), and `TR_Tomb_Mark`, the warning under the target that grows from 1.4 to 3.6 studs as the head closes.
- **Burst:** `TR_Tomb_Boulder_01..03`, `TR_Tomb_Blast` (a 3D stone starburst, ~14 studs in play), and `TR_Tomb_Shard_01..03`.
- **Particles:** two new `VFXLibrary` particle pieces, `TombGrit` and `TombShatter`, both through `emitter()` on the Shard sprite.
- **Shape checkpoint:** `vfx_blocking/terra/tomb/tomb2_shapes_checkpoint.png`. The v1 review material is in `vfx_blocking/terra/tomb/v1/`.

**v2.1, the claw replaced by a heap of rocks (2026-09-20) ✅ in Studio, tested in Play.** On the user's call ("a bunch of rocks that surround the player till their torso", dense "from the circumference of the platform itself", the claw removed entirely), built in Blender first and imported the same day:
- **The kit:** `TR_Tomb_Clamp_01/02` are gone from `build_terra_tomb.py`. `TR_Tomb_Rock_01..04` (a block, a pointed shard, a slab, a wedge) are laid 30 times by `ENCASE_RINGS` and `SCREE`:
  - four rings plus four loose stones spilled over the rim;
  - the bottom ring's outer faces sit on the plinth's rim;
  - each ring above is smaller and further in, and the top reaches ~3.4 studs, mid-chest, leaving the shoulders and head clear.
  - Every number is a proposal.
- **Shaped by an independent review** of the first pile: a pile as wide as the rim all the way up, bulging past it, with an even row of round rocks at the chest, still read as a stone fist from a distance. So the heap now tapers, the rocks are angular with a heavier ink hull and little overlap, and the rocks are lit from above (inner faces Base, not Dark).
- **Its beats (new, proposals, in `tomb_encase_anim.py`):**
  - Each rock punches up out of the plinth's stone, rim first, rings 0.05 s apart, 0.18 s each, ~7% overshoot, throwing chips. The whole heap is up ~0.43 s after the catch. It replaces the claw's 0.08 s spring and 0.12 s slam.
  - The burst throws the heap off (0.6 s), as it used to blow the claws open.
  - Every other beat is `TerraFX.Tuning.EarthenTomb`'s.
- **Review:** `vfx_blocking/terra/tomb/encase/tomb_encase_anim.mp4` (real time, then the catch 4x slower and the burst 2x slower) and `tomb_encase_anim.blend` (the animation keyed at 30 fps, opening in the camera in the kit's look). Stills are `tomb2_final_encase*.png` / `tomb2_silhouette_*.png` beside them.
- **In the game:**
  - The Studio side: `TerraTomb.fbx` re-exported and imported, replacing the v2 kit model in `EarthMagicMeshes`. There are 16 pieces; the claw's two are gone. Pivots are fixed and each piece is white SmoothPlastic, anchored, with no collide, query, touch or shadow.
  - `TerraFX`: the claw code is gone. `TombCatch` lays the heap from `ENCASE`, a table generated by `blender_scripts/terra/tomb_encase_lua.py` straight from `encase_slots`, converted to Roblox's axes. It is laid in the target's own frame (their facing at the catch), so it is wide where their arms are whichever way they stand.
  - The eruption and burst beats are in `Tuning.EarthenTomb.Encase*`, and `blowRocks` throws the heap off at the burst (and, gentler, on an escape). Ring grit comes from the existing `TombGrit`; there is no new particle.
  - The rocks are CanQuery off like every Terra piece, so shots through the heap still reach the target.
- **Tested in Play (2026-09-20):**
  - Terra cast at a range dummy: caught, heap up round the dummy to the chest, 12-stud rise, burst of 75 with ENTOMBED!, heap thrown off, bare pillar lowered and sunk.
  - The dummy cast at the player, who escaped with a real Frost Slide 0.55 s into the rise: freed 3.7 studs up, heap thrown off.
  - No `TerraFX` errors, and no Tomb pieces left behind.

**v2.2, the platform hangs and the cast is two-armed (2026-09-20) ✅ in Studio, tested in Play.** Three changes, all
look and animation; the lock, the catch, the escape, the burst, the damage and the charge cost are untouched.
- **Nothing holds it up.** `plinth()` in `build_terra_tomb.py` was a 16.6-stud monolith reaching down into the
  ground; it is now a torn slab 3.5 studs deep with roots hanging off its underside — 4.38 × 3.5 × 4.65 in Studio
  (was 4.84 × 16.61 × 4.71). `TerraFX`'s `PILLAR_DEPTH` came down from 17 to 6 to match, so the slab still starts
  buried and tears out, and what rises is a slab with open air under it.
- **The heap is 40% bigger.** `TOMB_SCALE = 1.4` in `TerraFX` scales the plinth, every `ENCASE` slot's offset, its
  travel and its piece — one number, so the heap and the slab grow together and the rocks still sit on the rim.
  ⚠️ At 1.4 the heap reaches the shoulders rather than the chest; if that reads as too much, `TOMB_SCALE` is the
  one knob, and `1.0` restores the 2026-09-20 morning look exactly.
- **The cast is a two-arm smash, then a one-arm raise clocked by the climb.** The old one-arm floor reach
  (`EarthenTombReach`) is gone. `EarthenTombSlam` (Trigger **0.12**, = `GripTime`, `Both = true`) winds both arms up
  and drives them into the floor on the beat the ground gives; `EarthenTombRaise` then hauls one arm up and is
  *clocked by the platform itself* — `CastPose.PlayClocked` reads `TombRiseAt` / `TombRiseFor` (published beside
  `TombPhase` on the same server line) and feeds the clip `1 - (1-u)^2.2`, `TerraFX.TombRise`'s own curve, so the arm
  and the stone are on one motion whatever the rise time is. Both layers: `Viewmodel` `EarthenTomb` /
  `EarthenTombRaise` (`TombWind/TombSmash/TombGrip/TombHaul/TombLift`) and `CastPose` the same two names.
- Recording (all three of this pass): `vfx_blocking/terra/terra_final_touches.mp4`.

### Bulwark Wall (Defense, built 2026-09-19) ✅ in Studio, tested in Play
**What existed before (the audit):** nothing that ran. There was no ability row, no server or client code and no
test: only the manual's one line (`SpellshotConfig.Defense.BulwarkWall`, 16 s), the Blender showcase's animation and
the kit's wall slabs in `EarthMagicMeshes`. So it was built, not wired, to the showcase's design: "a channelled
hold, capped, that breaks on damage; the 16 s cooldown starts when it drops".

- **The hold runs on MANA, not a cooldown (changed 2026-09-20).** The 16 s cooldown is gone (`Cooldown = 0`) and so
  is the 5 s cap (`MaxHold`, deleted). The key going down pays **10** mana and raises the wall; holding it drains
  **`ManaPerSecond` = 20 a second** (`TerraFX.Tuning.BulwarkWall`), scaled by the same `ShotTimeScale` everything else
  in the kit is. **No hard time cap** — the bar is the cap, and the invariant that makes it one is that the drain must
  stay above `SpellshotConfig.ManaRegenPerSecond` (**7**): at 20 the net is 13 a second, so a full bar buys
  **~6.9 s** and it can never be held forever. *Measured: 6.93 s from a full bar, the bar bottoming at 0.1.*
  It still ends early on the key coming up or on **200** absorbed (`WallHP`: four full Boulder Shots and change).
  Whichever ends it, `ReleaseHold` ends the hold on the server and the wall goes with it.
- **The wall is a real body on the server:** an anchored, invisible box the size of the slab kit (12.4 × 8.4 × 1.7),
  5.5 studs ahead (`WallAhead`), collidable and queryable, in a `BulwarkWall` model with a `Humanoid` (`WallOwner` =
  the caster's UserId). The Humanoid is what lets every kit's hits damage it through `Core.DealDamage` with no change
  to any kit. A modifier caps each hit at what is left, and the hit that empties it breaks it.
- **`CombatCore` needed fixes**, because it treated anything with a Humanoid as a character:
  - `Blocked` now counts a `WallOwner` model as cover, so it stops shots and sightlines.
  - `CheckTarget` checks a wall hit against the wall's box, not a 4.5-stud reach from its middle, so its ends count.
  - `IsFriendly` treats a wall as its owner (and the owner's team) for friendly fire.
- **The look** (`TerraFX.WallRaise / WallHit / WallDrop`, broadcast as `WallRaise / WallHit / WallDrop`) is the
  showcase ported. The slabs slam up course by course. Each hit bursts, throws debris and swaps the nearest whole slab
  for its broken half. A break is a big burst, debris and dust while the slabs topple; a release sinks them. There is
  no camera punch (the showcase has one on the break; left out of this pass).
- **The hand calls it up, then she braces (2026-09-20).** `BulwarkWallRaise` (`CastPose`) and `BulwarkWall`
  (`Viewmodel`) both have Trigger **0.06** against the slabs' own `RiseTime` **0.26**, so the hand drives up out of the
  floor a frame before the first course leaves it and the stone follows the hand. It settles at 0.26 into a bracing
  stance — side-on, knees set, that hand up across the face — and **holds there for as long as the wall does**. Both
  clips are `Hold` clips watched off one replicated attribute, `Holding_Defense`, so they let go on the release, the
  break, an empty bar and a death alike, with no state of their own to leak.
- **The lit face turns to each camera.** The slabs are lit on their front only, and their backs are black, so the
  caster standing behind her own wall saw a black wall in the first Play test. Each client now draws the wall turned so
  its lit face is toward its own camera, decided once at the raise (the Tomb blast's `litToward`, for a wall). The
  server's body does not turn.
- ⚠️ **Hitting the wall counts as a hit** for the attacker (it is a Humanoid): it feeds their Ultimate charge and
  Cryo's Cold Momentum. The hit's point on the wall is estimated from where the shot came from.
- ⚠️ **It blocks Terra's own shots too** (a full block both ways, "the one wall in the game"). Her hits never damage it.
- ⚠️ **Two server re-checks can still be fooled.** Boulder Shot's arc check (`TerraHandler` `flightBlocked`) and Pyro's
  (`PyroHandler` lines 71 and 205) see past any model with a Humanoid, the wall included. An honest client's shot stops
  on the wall (its own raycast hits the body), but a modified client could claim a hit on someone behind it and the
  server would take it (*tested: a forged Boulder claim through the wall landed 32.6*). The fix is one line in each
  (`if model:GetAttribute("WallOwner") then return true end`, as `Core.Blocked` has); not made, since Boulder Shot and
  Pyro were out of this pass's scope.
- ⚠️ **The range's practice thrower flies through walls** (it moves its shot itself and never checks geometry), so on
  the training range it still hits Terra behind her wall. Enemy hits in the tests went through `Core.DealDamage`
  (TerraTestServer) instead.

**Tested in Play (2026-09-19, and again 2026-09-20 for the mana hold)**, Terra with the full kit 14–16 studs from a
range dummy, logged on the server:

| Test | Result |
|---|---|
| Held 3.5 s, then released | Up on the press, 5.6 studs ahead; down on the key-up. Her arm went up with the slabs and stayed braced for the whole hold, then came home to the stance (shoulder 39° → −32° → 39°). |
| Held and never released | The drain emptied the bar and the **server** let go at **6.93 s**; `Holding_Defense` cleared, the wall went, the arm came home. |
| Broken by damage at a full-ish bar | Wall 200/200 held, then real damage through `CombatCore` spent it: wall gone, `Holding_Defense` nil, **mana still 94** — so it was the break that ended the hold, not the bar. |
| Killed with the wall up | Wall gone, `Holding_Defense` nil (the 2026-09-19 leak, fixed and re-checked). |
| Five enemy hits of 48 (the dummy's side, spread along it) | 152, 104, 56, 8, then broken on the fifth (2026-09-19, when the cooldown still existed). |
| A real full-charge Boulder Shot at the dummy through the wall | The rock stopped on `WallBody`; the dummy stayed at 150 and the wall took nothing (it is her own). |
| A forged Boulder hit claimed through the wall | **Accepted (32.6)**: the arc re-check gap above. |
| Defense pressed while burrowed (Tremor Vault, retired 2026-09-25) | Refused: no wall, no hold. |

Recording: `vfx_blocking/terra/wall/wall_hold_break.mp4` (real E key: held and broken, then let go) and its sheet.

### Aftershock (Mobility, 2026-09-25; replaced Tremor Vault) ✅ in Studio, tested in Play
Both fists driven into the ground a step ahead. After a 0.68 s windup, a ring of erupting rock races out 24 studs,
and everyone standing on the floor it reaches takes 20, is thrown back and is interrupted. It is built from the
Blender showcase (`blender_scripts/terra/aftershock_bl.py`, `vfx_blocking/terra/aftershock/`); the build contract is
`vfx_blocking/terra/aftershock/PORT_SPEC.md`. It is the second Terra piece, after the M1, in the realistic-lighting
style exception: earth-toned, no glow, nothing emissive.

- **The press** goes through the generic cast path with an empty payload (`Precheck = true` on the row).
  `Precheck_Aftershock` (a BindableFunction in `ReplicatedStorage.Spellshot`, made by `TerraHandler`) refuses it, at
  no cost, unless the caster is alive, not Entombed, not already in one, and has a floor within 3.5 studs under the
  feet.
- **The cast is the server's.** `castAftershock` fixes the start time, the flat facing, the centre (the floor 2.15
  studs ahead, where both fists land) and a seed, and broadcasts them once. Every client draws from that; nothing in
  the payload is read.
- **Timing (seconds from the key):** arms overhead at 0.40, held to 0.54, fists land at **0.68**. The contact frame
  is held **4/60 s** (the hitpause), then the front leaves. It reaches **24 studs in 0.70 s**, launching at 47.3
  studs/s and slowing linearly to 21.3 at the edge. The scar holds 2 s, then the plates sink (0.8 s) and the cracks
  fill and fade; everything is gone about 4.7 s after the key.
- **The caster is rooted** (`SpeedCapUlt` 0) from the key until 0.30 s after the slam on the hitpause clock (1.05 s
  real). That cap slot is shared, and Aftershock owns it the way Earthen Tomb does: each only lifts a cap that is
  still its own.
- **The windup can be cut** until the fists land: death, a clear, being Entombed, or an interrupt from somebody else
  ends it outright (`AftershockEnd`). After the slam the ring is committed and runs out even if the caster falls.
- **A strike:** a body the front reaches (flat distance, 1.2-stud body radius) with its feet between 3 studs below
  and 3 above the centre's floor takes **20** through `CombatCore`. Only if that lands, it is thrown out at 36 and
  up at 22 studs/s, both × the front's strength where it stood (never below 0.62), and **interrupted**: every held
  ability ends, a Boulder charge or Bulwark Charge is dropped, and casting is refused for 0.5 s (`InterruptedUntil`,
  Undertow's mechanism). A player's own client drives their throw (`AftershockKnock`); a server-owned dummy gets a
  `LinearVelocity`; an anchored range dummy is carried along the arc and put back. A Bulwark Wall, or a body in an
  Earthen Tomb, takes the damage only. No Status tag, no stars.
- **Jump it:** a body in the air while the front passes under it is spared, and landing afterwards doesn't count.
  Only the band the front swept since the last tick can strike.
- **Her own Boulder charge:** the slam takes both arms, so a rock in hand is dropped.
- **The look** (`TerraFX`):
  - **Plates:** 162 ground plates from a Blender kit (`EarthMagicMeshes.TerraAftershock`, 175 MeshParts: the 162 plates,
    8 rock blocks, 4 spikes and the `AS_Origin` marker; plate shapes and timings live in `ReplicatedStorage.Spellshot.AftershockKitData`).
    They are laid as a crust 0.06 over the floor on a dark underlay, heave as the front passes, and settle into a
    scar.
  - **Debris:** ~80 erupting rocks (× EffectDensity, halved for somebody else's cast), grit, dust emitters, a scuff
    decal, and a shard under each struck body.
  - **No physics:** everything is anchored and flown by script, one `BulkMoveTo` a frame. Plate sets are pooled (two
    kept).
  - **Floors:** a floor can't be cut or colour-sampled, so the plates use a fixed earth palette. Plates on floor
    more than 0.25 studs below the centre's (a step down) are left out, and the underlay stops short of a drop.
- **Animation:** a `CastPose` body clip for everyone (the legs return to the stance once the caster moves after
  the release) and a `Viewmodel` first-person clip, both on the hitpause clock. The caster's camera shakes on each
  windup thump, on the slam (0.5) and through the ring's rumble; anyone else within 40 studs gets the slam and the
  rumble (not the thumps), scaled by distance, and a struck body gets its own small shake.
- **The caster's own client** starts the arms and shakes on the key and treats the press as provisional: if no
  broadcast comes back within max(0.6, 2 × ping + 0.3) s, it takes them down and flashes the slot.
- **Removed:** Tremor Vault's whole server section (the burrow, the hidden body, its collision group and the
  `Burrowed` damage modifier), its client handlers, and the harness's `vault:` mode. The `Burrowed` guards in
  `SpellshotService`, `CombatCore` and `AbilityHandler` are dormant now (nothing sets it). The `TerraVault` meshes
  stay in the place, unreferenced.
- Every number is a proposal, in `TerraFX.Tuning.Aftershock`, except the 12 s cooldown (the manual's, inherited).
  Mana 20.
- The live scripts from before the push are kept in `ServerStorage.AftershockBackup_2026_09_25` (9 scripts,
  disabled).

**Tested in Play (2026-09-25, Training Ground, one client)**, logged on the server by `tools/aftershock_tests/setup.lua`:

| Test | Result |
|---|---|
| A real press (the key's own path) | Accepted; the broadcast came back 0.05 s after the key. Centre 2.15 studs ahead, on the floor. 12 s cooldown. Rooted from the key, released 1.05 s later. |
| Dummy_16, 18.1 studs from the centre | Struck for 20 at 1.18 s after the key, exactly the front's predicted time. Carried ~10 studs out on its arc (0.7 up), then put back. |
| Dummy_Thrower, 26.2 studs from the centre | Not struck (outside 24 + 1.2). |
| Pressed 25 studs up in the air | Refused: mana stayed at 100, no cooldown, no root. The client took the arms down. |
| Slow motion (ShotTimeScale 0.25): her own cast and a dummy's | The crater, the ring out to 24, the scar, the settle and the fill were all drawn, and nothing visible was left afterwards. No console errors in any run. |

⚠️ **Not tested:**
- a second client: being struck as a player (the knock, the interrupt, the dropped charge);
- Earthen Tomb or Bulwark Wall in the ring;
- uneven floors.

**Flags (proposals to confirm):**
- **The range dummy's throw barely lifts.** An anchored range dummy is carried on a plain ballistic arc, so 22 ×
  strength gives it under a stud of height (0.5–1.2) and it reads as a shove along the ground; Aqua's knocks use
  30–45 up. A player or a server-owned dummy is different: its `LinearVelocity` holds the launch for `KnockTime`
  (0.22 s) against gravity, so it should rise ~3.5–6 studs (untested). See that in Play before raising `KnockLift`.
- The strike's interrupt does not end an Earthen Tomb cast phase, a Cryo or Aqua channel, or a Ring of Fire draw.
- `CastPose.Clips.Aftershock.StanceLegsFrom` (0.98) repeats Hit + RootUntil by hand. Keep it in step with the
  tuning.
- `Pulse("Knockback")` on the struck client draws nothing today (the fans were retired 2026-09-24).
- At 24 studs the front arrives 1.45 s after the key. Walking (16) out from the key escapes only from beyond ~2
  studs of the centre, and from the slam only from beyond ~13; a sprint (25) from the key clears it from anywhere.
  Jumping is the dodge.

### Tremor Vault (Mobility, 2026-09-19 – 2026-09-25) — retired
Replaced by Aftershock. It was the pool's burrow-and-pop, **held**: sink, travel underground where the player
looked while the mana lasted, then come up. Its code is deleted. `SpendMana` and `GiveBack`, the two bindables it
added to `SpellshotService`, are general and stay. Its shapes (`TerraVault.fbx`) remain in `EarthMagicMeshes`,
unreferenced. Its recording is `vfx_blocking/terra/vault/vault_burrow_pop.mp4`.

### VFX polish pass (2026-09-18) ✅ meshes imported 2026-09-19
VFX only; no gameplay code, numbers or cooldowns changed. The Boulder Shot still does 48 at full charge and 24.7 at a tap.
- **Meshes first, Parts as the fallback.** TerraFX clones the Quarry Slab kit's MeshParts from
  `ReplicatedStorage.EarthMagicMeshes` (baked bands, inverted-hull ink), and falls back to Parts only if they
  are missing. The kit is imported: 51 MeshParts, white SmoothPlastic, anchored, DoubleSided off. Every client
  keeps one hidden copy of each piece loaded (`TerraMeshCache`), Zephyr's fix for a clone's slow first draw.
- **Re-importing needs one extra step.** Studio's importer bakes each piece's rotation into the mesh and stores
  the Blender frame, turned 90°, in `PivotOffset`. Placed as imported, the plates lay flat. So after every
  Import 3D of `TerraKit.fbx`, run `tools/terra_fix_pivots.lua` once in Edit mode. The import settings are
  Scale Unit Stud, Merge Meshes off.
- **Bedrock**: a clink (the flat comic burst plus Light chips) as each plate locks. At five, the whole set's
  outline swells once. On the lapse the plates crack and fall one at a time, newest first, and sink.
- **Bulwark Charge**:
  - Damage reduction shows as three of Bedrock's plates snapping onto the charger's front. They crack off when
    the charge ends.
  - Dust and rubble kick off every footfall, replacing the old slab trail.
  - The contact gets a burst and a camera punch.
  - Staggered targets get three stars circling the head, drawn from `RX_Staggered` on every client. The victim's
    own screen gets the existing Knockback displacement fan (`StatusReactions`).
- **Boulder Shot** (all three points below were replaced by the 2026-09-23 rework; see Boulder Shot above):
  - The kit's three boulders swap in at each third of the charge, with a clink. The bigger two carry cracks of
    light.
  - A charged rock sheds chips in flight: 0, 10 or 34 a second by tier.
  - The impact is a burst, Shard debris, and a ground crack that fades in 0.55 s. A character hit cracks the
    floor under them.
- **Camera punch**: `Viewmodel.Punch`, through the clip punch's own camera path. It peaks at 0 / 0.21 / 0.42
  studs at Camera Shake 0 / 50 / 100, and Reduce Flashing removes it.
- **Bulwark Wall** had no mechanics when this pass ran; it was built on 2026-09-19 (above). The showcase's **Seismic
  Slam** shot is now deprecated review content, because Earthen Tomb replaced the Slam (see above). Its
  proposed `slam` callout style lives on as `entombed`.
- Review: `vfx_blocking/terra/showcase/terra_polish_review.png` (each piece in colour and in grey) and
  `terra_showcase.mp4`.

## 6. The Cryo kit — all five abilities ✅

The only Element with a cast path. `VFXLibrary.lua` (1,248 lines) draws it,
`AbilityHandler.server.lua` (873 lines) makes it hurt.

| Slot | Key | Ability | Cooldown | Mana | Status |
|---|---|---|---|---|---|
| M1 | LMB | **Icicle Shard** | 0 (rate: 0.333 s, 3/s) | 2 | ✅ |
| Primary | F | **Flash Freeze** | 14 s | 30 | ✅ |
| Mobility | Q | **Frost Slide** (a dash since 2026-09-14) | 3 charges, 9 s each | 18 a dash | ✅ |
| Defense | E | **Chill Aura** | 15 s | 22 | ✅ |
| Ultimate | R | **Cryo Beam** | charge-gated | — | ✅ |

### Icicle Shard (M1)
- 8 damage a shot, 120 stud range. **One click, one shot** — holding does not repeat.
- A click that lands early is **held over** rather than dropped, so fast tapping gives a steady rate.
- The arms **take turns**: one palm thrust per shot, and the shard leaves that hand at full
  extension, released on the rendered extension frame.
- 2 mana a shot = 6/s at the fastest tapping, under the 7/s regen — so M1 alone can never empty the
  bar and is never refused for want of mana.
- **Chill stacks:** speed capped to 22 at one stack, 15 at two. Stacks lapse 3.0 s after the last
  hit. The **third stack roots for 0.8 s**, then clears, with 1.2 s of immunity to new stacks after.
- The shard's look is the Build Prompt #20 crystal cluster (`VFXLibrary.FireIcicleShard`), imported
  2026-09-14 into `IceMagicMeshes.IcicleShard` (`IS_Cluster`, `IS_Streak`): it forms at the hand, flies
  with a flat streak, and shatters into flat shards and a frost-burst. Without those meshes it falls back
  to the old rod. Its hit is real.

### Flash Freeze (Primary)
Ground zone that tracks time-inside per victim. 10 contact damage; linger past 1 s and you are
**rooted**; still frozen when the zone expires and you are **shattered for 34**. Slow speed 5.
Dwell never decays, so the timer cannot be juked by strafing in and out of the edge.

### Frost Slide (Mobility) -- a dash
Rebuilt 2026-09-14 to the Cryo kit brief: the manual's slide is now a **dash**, and the ground you
leave **freezes over**.
- **13 studs in 0.2 s** along your movement input (the camera's facing when standing still), on the
  ground or in the air; walls stop it. A slow shortens it; a root, a freeze or a slow under 12 refuses
  it. The client moves on the keypress (`ReplicatedStorage.Spellshot.DashMotor`, a LinearVelocity).
- **3 charges**, 18 mana each, one charge back every 9 s, dashes at least 0.35 s apart. The server owns
  the charges (`Charges_Mobility`, `ChargeAt_Mobility`, `CastSeq_Mobility`); the HUD slot shows the count.
- **The patch:** radius 5.5 at the dash start, formed over 0.25 s, gone after 4 s. Anyone who lands on
  it is **frozen for 4 s** (a clean root: no damage, no slow first), once per patch, with 1.2 s of
  immunity after they thaw so chained patches cannot lock anyone down. It counts as a landed hit for
  Cold Momentum.
- Visuals: a solid frost line under each foot, the Flash Freeze ice sheet scaled to the patch with six
  small rim crystals, a shard break; short first- and third-person dash clips.
- Also fixed on the way: cooldowns are stamped in server time (they were read against each client's
  own clock), overlapping slows can no longer shorten or extend a root, and a shorter freeze no longer
  cuts a longer frozen state short.

### Chill Aura (Defense)
Follows the caster for 6 s. 3 damage a tick, slows to 8 for 1.0 s on contact, and escalates to a
**root after 2.5 s of continuous exposure**. Deliberately not a blockable object — it is a melee
deterrent.
- **Look: Chill Aura v2 (2026-09-14, the reference sequence; grey checkpoint approved, variant B, then slimmed to
  variant A's swoosh width and crystal length to match the checkpoint clip -- same layout and radii).** It FORMS
  in place -- nothing is ever drawn larger or smaller than it is:
  - **Edge** on the floor at the true radius 8 (24-corner band, ink rim, sawtooth teeth): its facets grow out
    of 6 seed corners (the first in front of the caster) and close by 0.30, before damage can tick (0.35);
    it holds whole until the zone ends, then draws back into the seeds (6.00-6.15).
  - **Orbit** (0.6 rad/s): the concentric middle and inner rings form facet by facet and six Icicle crystals
    grow from the heel into two tiers (waist, above the head), 0.32-0.74; at the linger the rings draw back
    and the crystals shrink to their tips as they fall.
  - **Wind** (1.0 rad/s): three swooshes draw themselves from the ring up around the caster, chord by chord;
    at the linger each is wiped from its base toward its head.
  - **Frost**: a FrostTile floor disc spreads under a still tile, recedes 5.45-5.85. **Snow**: sparse
    hard-edged Shard flakes on a shell round the caster (the built-in Sparkle rendered as dark stars).
  - Everyone else sees the whole aura for the whole zone. The caster sees it all form, then their own
    swooshes are wiped away (`Tuning.ChillAura.OwnWindOut`, 0.95-1.30) because in first person they cross the
    view; their edge, rings, crystals, frost and snow stay. Low Graphics Quality, or someone else's aura with
    Reduce Enemy VFX, shows the edge only. Airborne, the floor edge shrinks
    horizontally to the real reach of the root's 8-stud sphere (12 across at a jump apex). A caster's
    death un-forms everything from where it is in 0.15-0.25 s.
  - Kit: 88 pieces + 3 merged meshes in `IceMagicMeshes.ChillAuraV2`, layout and timing in
    `IceMagic.ChillAuraData` (`blender_scripts/cryo_blocking/final_chill_aura_v2.py`). Pieces are drawn
    only while forming or un-forming; in between each component is one merged mesh (3 MeshParts a frame),
    sets are pooled. The waist crown kit (`IceMagicMeshes.ChillAura`) is no longer referenced.
- Fixed on the way: the root now really needs *continuous* exposure (stepping out resets the count;
  it used to add up across visits), and the aura ends when its caster dies (it kept ticking until
  respawn) -- every client collapses the ring.

### Cryo Beam (Ultimate)
Levitate → visible charge windup → forward beam. **46 damage/second**, ticking every 0.15 s, 4.0
stud hit radius at the end of the server's ray, 60 stud range, slowing to 9 for 0.9 s. A full 2.4 s
channel does about 105 (MaxHealth is 150, so no longer lethal on its own). Long, loud and committed,
on the "predict and dodge" philosophy.
- **Look: Cryo Beam v2 (2026-09-15, the reference sheet; grey checkpoint approved: revision 2, variant A,
  levitation kept).** Everything forms in place on the server clock (the casts' T0):
  - **Channel (0-1.05):** a toothless ground ring forms from 3 seeds under the lifted caster; ten Icicle crystals
    grow from the heel and orbit, a hero crystal over the hands; two rune rings; three chorded wind arcs beside the
    hands; a small core point.
  - **Focus (1.05-1.75):** the orbit slows to a stop, the crystals fly into a sunburst pointing at a 4-point star,
    the arcs become a vortex, a needle flare grows; it holds until the fire arrives.
  - **Unleash / Sustain:** the beam is ONE uniform cylinder (r 0.46, flat head, no tip) that tears out at 400
    studs/s, with shard tiles and a swirl of crescents travelling along it, two ribbon strands rolling, a muzzle
    ring shedding travelling rings, frost trails; the crystals shoot along it. **Impact:** a spike crown inside the
    r 4 hit sphere + a halo (the halo alone marks the 60-stud tip in open air). **End:** crown folds, the beam
    pulls back into the hand.
  - First person: your own arcs are small and wiped at Focus, the sunburst rings the screen edge, the beam is
    slimmer, your right hand thrusts low at the right so the beam runs diagonally into the crosshair (moved there
    after the 2026-09-15 Play review; from the centre it was seen end-on), its decoration slimmed with it and starting
    near the hand, specks only from 6 studs; your muzzle ring is wiped soon after the fire. A beam at your camera
    stops 3 short with no crown on you. Reduce Enemy VFX / low quality keep the ground ring, crystals, star,
    cylinder, muzzle ring, crown and halo.
  - No shatter (no gameplay behind it); the freeze is the shared frozen look. Both animation layers re-authored
    (1P: hands open low -> cupped together -> right thrust with a left brace; 3P: float legs, the old backward
    fire arm retired); the cast glow stays off. Kit `IceMagicMeshes.CryoBeamV2` + `IceMagic.CryoBeamData`
    (`blender_scripts/cryo_blocking/final_cryo_beam_v2.py`); the old CryoNozzle / CryoCharge / CryoRuneRing,
    frost crusts, LevitateFX (its emitter leak) and the additive Beams are no longer used.

*Glacial Spikes and Diamond Skin were **cut** with the v0.2 kit — cast paths, damage tables and
remote actions deleted rather than disabled. Their meshes remain in the place, unreferenced.*

### Toon rendering rules ✅
No toon/outline post-process exists in Roblox (verified: no `OutlineEffect`/`ToonEffect` class), so
the outline is **real geometry** — an inverted-hull shell. Consequences enforced throughout:
- Every crystal MeshPart keeps `DoubleSided = false`, or the shell stops reading as an outline.
- `MeshPart.Color` stays white and `Material` stays `SmoothPlastic` — any tint multiplies the baked
  vertex-colour bands; Ice/Glass/Neon destroy the flat read.
- Crystals are opaque (transparency shows the black inside of the outline shell); spikes hide by
  sinking into the ground rather than fading.
- Particles use a hard-edged shard sprite, never soft round dust.

---

## 7. Hit registration ✅

The hardest-won system in the project.

- **The shooter's client decides what a shot hit** — the rod it draws stops on something and it
  reports that (`ShardHit`) — and the server checks the claim before applying it.
- **Why:** the server used to fly the shot itself and missed whatever moved. Every client draws
  moving things ~0.15–0.2 s behind the server, so a strafing target dead centre on your screen was
  already 2–3 studs further on server-side. **18 of 20 such shots missed** in a trial.
- Server-side validation: range, a perpendicular-distance tolerance of 1.5, a token bucket of
  capacity 2 at `FireInterval / ShotTimeScale`, and a `SAME_SURFACE = 0.75` depth test for the
  line-of-sight check.
- `ServerStorage.ShotStats` counts every rejection by reason, with a 20 s `warn` summary, so a
  refused shot can be named instead of guessed at.
- After the last fix, **22 of 22 synthetic hits landed**.

---

## 8. Status effects and reactions ✅

### The vocabulary — 15 statuses 📋/✅
Defined in `SpellshotConfig.Statuses`. Each carries the Element that caused it, which drives the
tag's colour and icon.

Burning (Pyro) · **Chilled (Cryo)** · **Rooted (Cryo)** · **Slipping (Cryo)** · Shocked (Voltaic) ·
Revealed (Voltaic) · Staggered (Terra) · **Entombed (Terra)** · Airborne (Zephyr) · Marked (Umbra) · Blinded (Umbra) ·
Purified (Radiant, benign) · Blessed (Radiant, benign) · Poisoned (Toxin) · Snared (Toxin)

The three bold Cryo statuses have live sources in the Cryo kit, and Entombed (2026-09-19) in Terra's Ultimate. The rest are named and coloured but nothing
raises them except the dev panel.

### The reaction layer ✅
`StatusReactions.client.lua` (785 lines) — every treatment is a Blender-rendered asset; the script
decides when it is on screen, where it sits, and which one wins.

- **10 sustained treatments** driven by `RX_<Kind>` character attributes: Burning, Chilled,
  Poisoned, Shocked, Shielded, Marked, Stealth, VisionDenial, Haste, ZoneWarning.
- **10 one-shot pulses:** BurnTick, Krak (freeze), Punish, ShieldBreak, Cleanse, SpendSurge
  (mana), Knockback, Pull, Ready (burst), DecoyPoof.
- **Shape language is fixed per trigger; only the accent colour changes per Element.** A burn from
  any source is always the flame crest. That is what lets a player learn twelve reactions instead
  of twelve times eight.
- **The four clash rules are implemented, not left as notes:**
  - **R1** One fill treatment at a time on the health bar — frost crust, acid overlay and ember
    flicker repaint the same pixels. Most recent wins; the displaced status drops to a chip rather
    than vanishing.
  - **R2** Zone warning vs shield ring — with a shield up the warning moves onto the shield ring as
    a pulsing outer glow instead of competing for the same millimetre.
  - **R3** One edge treatment only, priority `visionDenial > marked > stealth`. Not blended — two
    stacked vignettes just read as one darker vignette.
  - **R4** Displacement suppresses haste (both are white comic lines), for 0.4 s at a heavier stroke.
- **Two ScreenGuis, and the split is not cosmetic:** bar treatments are positioned off the HUD's
  `AbsolutePosition` so they need the same `IgnoreGuiInset`; full-screen treatments must cover the
  topbar. One ScreenGui put every bar treatment exactly one topbar-inset off vertically.

---

## 9. Combat feedback — the comic callouts ✅

`Callouts.lua` (module) + `CombatFeedback.server.lua` + `PopupScaler.client.lua`.

- Five styles: **damage number**, **KO!**, **CHILL xN**, **FROZEN!** (held for as long as the freeze
  lasts), and the training board's **score**.
- Built the way the kit builds display type: colour fill, ink outline, and a solid ink copy knocked
  down-right behind it; the big moments get a jagged burst behind them (FROZEN! on the icy comic
  burst, KO! on the plain one).
- **Slots:** a new callout replaces the one already showing in its slot on that target, so callouts
  of one kind never stack. Damage numbers have no slot and get a small sideways jitter.
- `Shift` moves a callout in **screen** space by fractions of its own size, so kinds stay apart at
  any distance — an offset in studs shrinks to a few pixels far away.
- Created **server-side**, so the shooter, the target and every spectator see the same callout over
  the same head at the same moment.
- `PopupScaler` (client) reads `BaseW`/`BaseH` and the `Distance` frame and scales each popup by the
  viewer's own camera distance — at twice the distance, half the size.
- **This was a bug fix.** Every callout used to live inside `TrainingGround` and attach only to
  models with the `TrainingDummy` attribute, so hitting a real player did full damage, stacked Chill
  and rooted them while showing nothing at all.

### Death FX ⚠️
`DeathFX` pins the volume of Roblox's injected "Died" sound to 0 the moment it appears (rather than
forking `RbxCharacterSounds`, which would take footsteps and jump with it) and plays one visible
death treatment. **It is installed in the place but has no file in `roblox/` — see [§18](#18-gaps-and-risks).**

---

## 10. HUD ✅

`PopArtHUD.client.lua` (778 lines) + `BarKit.lua` (410 lines). Built on the approved
`SPELLSHOT Pop-Art HUD Kit v2.pdf`, row 01.

**Layout:** bottom-left health bar, mana bar beneath, each with its icon chip and a readout pill ·
bottom-right Primary / Mobility / Defense then the larger Ultimate, with the Passive pill above ·
top-centre round counter · top-right duel feed · centre crosshair.

- **Design metrics:** `DESIGN_W/H = 1060×600`, scale clamped to **0.34–0.85** — capped below 1 on
  purpose, so at RIVALS density the HUD never occupies its full authored footprint even on a large
  monitor.
- **No M1 slot.** The manual makes M1 the always-available click with no cooldown and no resource,
  so a slot for it displayed a plate whose entire content was an icon that never changed state.
- **One label per slot, not two.** The keybind chip stays; the spelled-out role name is gone. The
  Ultimate keeps a word because its label bar is where **READY!** fires.
- **The top-right tags are a duel feed** — the two most recent duel results, hidden entirely when
  there are none, rather than a permanently half-empty tag.
- **The health and mana bars are art, not Frames.** Blender renders with thick comic ink, a
  hand-wobbled panel edge, halftone dots in the empty channel and a hard offset shadow — none of
  which a `UICorner` and `UIStroke` can produce, because their whole character is that they are not
  geometrically even.
- **The fill is clipped, never stretched:** a clip frame of the current width holds a full-width
  fill image, so the halftone keeps its pixel scale at every health value.
- `BarKit` can build the same geometry **two ways** off one table — native Roblox Frames or the
  Blender PNGs — so a side-by-side compares only how the chassis is produced.
- Every number in `BarKit` was read out of the PDF's **content stream** and scaled by one factor
  (K = 1.6 design px per PDF point). Nothing was measured off a screenshot.
- **Runtime-settings-aware:** UI scale, HUD opacity (one full-screen CanvasGroup per ScreenGui
  layer — per-corner canvases clipped the keybind tabs), text size, crosshair (colour/shape/size/
  outline, rebuilt from settings), kill-feed duration with an expiry loop.

⚠️ The round counter reads `RoundsWon`/`RoundsLost` attributes that **nothing currently sets** — see
[§17](#17-not-built-at-all).

---

## 11. Settings — 45 rows, all working ✅

Three scripts and one shared module: `SpellshotSettings.lua` (the store),
`SettingsMenu.client.lua` (1,259 lines — the panel), `SettingsRuntime.client.lua` (the appliers),
`SettingsStore.server.lua` (persistence).

**22 shared rows, 17 PC-only, 6 mobile-only.** A touch device and a keyboard/controller device get
separate lists, never one list with dead rows.

### Video (6)
Graphics Quality (LOW/MEDIUM/HIGH/ULTRA) · Field of View (70–110, default 90) · Brightness (0–100) ·
Camera Shake (0–100) · **Motion Blur** (0–100) · Reduce Enemy VFX

### Controls — PC (10 + 6 gamepad)
Sensitivity (1–100) · Sensitivity While Channeling (10–200%) · Invert Y-Axis · Toggle Crouch ·
rebindable **Primary / Mobility / Defense / Ultimate / Crouch / Interact** on both keyboard
(F/Q/E/R/LeftControl/None) and gamepad (ButtonX/L1/R1/Y/L3/None)

### Controls — Mobile (6)
Touch Sensitivity · Camera Assist · Auto Fire · Button Size (50–150) · Button Opacity (20–100) ·
Left-Handed

### Audio (5)
Master · SFX · Music · Interface · Mute When Unfocused

### HUD (9)
Crosshair Colour (6 swatches) · Crosshair Shape (CROSS+DOT / CROSS / DOT / CIRCLE) · Crosshair Size
(50–200) · Crosshair Outline (0–3) · Damage Numbers · Status Intensity · **UI Scale (50–150)** ·
HUD Opacity (20–100) · Kill Feed Duration (2–10 s)

### Access (3)
Colourblind-Safe palette · Reduce Flashing · Text Size (80–150)

### How it works
- **The menu is thin.** A row says what it is called, what it does, and which setting it drives. The
  range, option list and default all come from the definition in `SpellshotSettings`, so the menu
  cannot promise a range the store will not accept. Changing a row calls `Settings.Set` and nothing
  else — the script that owns the behaviour is listening.
- **Ownership:** `SettingsRuntime` does view/audio/mouse/quality/flashing/text; `PopArtHUD` does UI
  size, opacity, crosshair, kill feed; `Viewmodel` does camera shake; `StatusReactions` does status
  intensity; `SpellshotInput` does the ability binds; `MovementController` does crouch/slide binds;
  `PopupScaler` does damage numbers.
- Every applier is `Settings.Bind(id, fn)` — runs once at startup **and** on every change, so there
  is no separate "apply all on load" pass to forget.
- **Layout:** two columns so a whole category fits with no scrolling; help arrives as a comic speech
  bubble pinned to the row the pointer is on. Categories that can show something have a **live
  preview** at the top of the right column — the crosshair draws itself, the Element palette shows
  its chips, the view shows its own brightness and FOV.
- **Skin:** newsprint. Paper stock under a coarse ink dot screen, heavy black rules, square-ish
  corners, hard offset shadows, red Bangers headings, red as the only accent. No gloss anywhere.
- **Keybind rebinder:** Esc cancels, Backspace clears, taking a held key swaps it, and key vs pad
  columns are enforced. Per-tab double-tap Reset on every tab.
- **Persistence:** DataStore `SpellshotSettings_v1`, key `p_%d`. The client is the source of truth
  while you play and pushes a **whole snapshot** on a 0.4 s debounce — idempotent, so a dropped or
  reordered message cannot leave the save half-applied. 120 s autosave, `BindToClose`, and
  everything re-validated server-side, so a forged message can only ever set that player's own
  preferences to something inside the range the menu offers anyway.
- **Studio API access off** → `GetAsync` throws, it warns **once**, and the session runs on
  in-memory settings. A settings menu must never be dead because a DataStore is.

### Four Roblox limits established by measurement, not assumption
| Wanted | Reality | What we did |
|---|---|---|
| `UserGameSettings.SavedQualityLevel` | RobloxScript-only | Quality drives our own shadows + an effect-density multiplier |
| `UserGameSettings.CameraYInverted` | RobloxScript-only | Negate camera pitch on a render step above Camera priority |
| `SoundGroup.SoundGroup` | Does not exist — groups do not nest | Master became a multiplier over the three groups |
| `Enum.SavedQualitySetting.Level01` | Does not exist | Items are `QualityLevel1..10` |

---

## 12. Loadout menu ⚠️ (placeholder look, real behaviour)

`LoadoutMenu.client.lua` (464 lines), 660×352, opened from a chip beside the settings gear.

- **Two separate choices**, as the manual separates them: **your Element** (M1 + Primary + Passive,
  one bundle) and **your Techniques** (Mobility / Defense / Ultimate, each drawn from a pool of
  eight, one per Element) — so a Cryo player can run Pyro's Ember Trail.
- All eight Elements listed; Cryo marked EQUIPPED, the other seven dimmed and marked **SOON**.
- Three technique cyclers over the full eight-entry pools, each showing its origin Element.
- **Selections really apply**, through `Spellshot.LoadoutRequest`, validated server-side: the
  Element must exist *and* be built; a Technique must be in that role's pool *and* come from a built
  Element. Rate-limited to one change per 0.08 s. Verified — Pyro, Pyro's Ember Trail and a
  made-up Ultimate were all refused; Cryo + Chill Aura went through.
- `LoadoutOpen` attribute gates casting and crouching while it is open.
- Newsprint skin, matching the settings panel.
- **Placeholder in look, not behaviour.**

---

## 13. Dev panel ✅

`DevPanel.client.lua` (465 lines). Hidden by default, toggled with `;`.

- **It drives the real paths, not test-only ones.** Equipping an Element sets the same player
  attribute the loadout system sets; a status raises the same `RX_<Kind>` character attribute the
  server raises. A green result means the real path works.
- Sections: Elements (equip) · Element Kit readout · Techniques × 3 roles · Status–Sustained ·
  Status–One-shot moments · Status–Health/resource · Status–Crosshair/icon/feed · Status–Legacy tag ·
  Match state · **Scenarios** (stacked cases from the clash rules).
- Toggles: Free Ultimate, No Cooldowns, Free Mana; buttons for Fill Ult and Reset Cooldowns.
- Hotkeys: `]` fill ult, `` ` `` toggle free ult, `[` toggle no cooldowns, `'` toggle free mana.
- **Design rule: coverage over polish.** A plain scrolling list of labelled buttons — if it looked
  like the HUD it would be harder to tell the tool from the thing under test.
- **Who counts as a dev:** in Studio, whoever is playing. In a live server, only the place owner
  (checked against `game.CreatorId`) and only when `AllowInLiveGame` is on.
- ⚠️ `Config.Dev.AllowInLiveGame = true` right now, so that **Team Test** works — a Team Test
  session runs on a real Roblox server where `RunService:IsStudio()` is false. **Turn it off before
  the game is public.**

---

## 14. Training ground ✅

`TrainingGround.server.lua` + `TrainingGround_build.lua` (a command-bar rebuild script, because the
range lives only inside the place).

- **4 dummies** at 16 / 28 / 44 studs (12° / 24° / 34° left) plus a **strafer** walking a 16-stud
  lane ~30 studs out for practising leading a moving target.
- **4 target boards** at 25 / 50 / 75 / 100 studs (34° / 24° / 16° / 10° right).
- Dummies take real damage from every ability, show damage numbers, Chill stacks and FROZEN!,
  **cannot die** (at 0 health they show KO and refill instantly, so no hit is ever lost on a dummy
  that is down), and refill to full a set time after the last hit.
- Boards leave a mark where the shot landed and pop the ring score: **10** in the bull, then
  8 / 6 / 4 / 2 outward.
- **The thrower** (2026-09-16), `Dummy_Thrower`, 24 studs straight down the range: something live to parry with
  Deflect Gust (equip it, press the Defense key). A dummy with the `Thrower` attribute throws a plain practice shot at
  you -- see *Zephyr: Deflect Gust* below.

---

## 15. Audio ✅

- **4 sound assets** in `ReplicatedStorage.IceMagic.Sounds`: `SFX_GlassShatter`, `SFX_GroundBoom`,
  `SFX_IceShatter`, `SFX_Slide`.
- Eight cue mappings across the kit (nova slam, nova frost, shatter, slide start, trail drop, aura
  on, ult charge, ult fire) — each with its own volume, pitch and pitch spread, so four clips cover
  the kit without sounding like four clips.
- **`SlideAudio.client.lua`** — Roblox's own character sounds are driven by Humanoid state and
  speed, so sliding with W held kept the Running loop going and you slid to the sound of footsteps.
  This watches every character's replicated `MoveState`, plays the slide clip at the root and zeroes
  the Running sound, restoring it on exit. Client-side deliberately: your slide's sound starts on
  the keypress, not a round trip later. Positional, so you hear other players slide.
- Three `SoundGroups` (SFX / Music / Interface) with Master as a multiplier, plus Mute When
  Unfocused.

---

## 16. Designed but not built

### Seven Elements 📋
Every one has a name, archetype, three-colour palette, M1, Primary, Passive, and one Technique in
each of the three pools — **and no cast path**. `Config.BuiltElements` is the one flag; the loadout
menu greys the rest out and the server refuses them. *(2026-09-15: the flag is now
`{ Cryo = true, Pyro = true, Zephyr = true }`. Pyro's kit is not written up in this file yet; Zephyr
is only partly built, see below.)*

| Element | Archetype | M1 | Primary | Passive |
|---|---|---|---|---|
| Pyro | Aggro/DPS | Fireball | Immolate | Ember Refund |
| Voltaic | High-skill snowball | Chain Bolt | Overcharge | Static Charge |
| Terra | Aggressive tank | Boulder Shot *(the only chargeable M1)* | Bulwark Charge | Bedrock |
| Zephyr | Mobility/Flank | Wind Blade ⚠️ *(built, see below)* | Cross-Slash Dash ⚠️ *(built 2026-09-16, see below; was Blade Cyclone, manual v0.5)* | Updraft |
| Umbra | Assassin/Playmaker | Shadow Dart | Mark for Death | Unseen |
| Radiant | Support | Light Lance | Blessing | Afterglow |
| Toxin | Area denial/DoT | Spore Burst | Corrosive Cloud | Symbiosis |

#### Zephyr: Wind Blade (M1) ⚠️ (2026-09-15; look and slash rebuilt 2026-09-16; VFX upgrade pass the same day; hands smoothed and the extras switched off after it)
- **What it does:** a very fast, light shot that pierces, hitting up to 3 characters in a line once
  each; anything else stops it. Stand-in numbers in `ZephyrFX.Tuning.WindBlade`: 0.12 s fire
  interval, 3 damage, 80 studs, 240 studs/s. It costs 0.8 Mana (`VFXLibrary` row `WindBlade`).
- **The slash:** the hands alternate, and each hand alternates its stroke. A burst starts with LEFT slashing
  down; RIGHT comes up from the bottom, LEFT goes back up, RIGHT comes back down. Every stroke fires. A 0.45 s pause
  starts the next burst over. The choreography is `blender_scripts/zephyr/wind_blade_v3/wb3_choreo.py`.
  - First person: `Viewmodel ArmClips.WindBladeDown/Up`, keys every 0.015 s. The arm holds after its slash until its
    next shot, or settles by 0.45 s.
  - **Smoothed (2026-09-16):** both clips are `Spline = true, Catch = 0.10`. Instead of an eased step per key, the arm
    follows one cubic Hermite curve through the keys (each key's slope the choreography's own), and the gap from wherever
    the arm was -- and the speed it was already moving at -- is let go over the first 0.10 s. The eased step had stopped
    the arm dead on the 0.045 s key and restarted it a frame later, every stroke, and from rest it jumped the arm up to the
    wind-up pose in three frames and reversed it. Replayed at 60 fps on the real keys, the biggest one-frame change in hand
    velocity went from 29 to 16 studs/s at the full rate, and from 37 to 15 from rest. Inside those 0.10 s a stroke from
    rest releases a little short of the choreographed release pose; the blade leaves from wherever the hand is.
    Only the first-person layer changed: `CastPose` already blends its keys at Rate 50.
  - Third person: `CastPose WindBlade<Down|Up><R|L>`, with the other arm held (Off).
  - The release is at 0.06 s in both layers.
- **Look:** the Wind Blade VFX kit (`blender_scripts/zephyr/wind_blade_vfx`, `export/zephyr_wind_blade_vfx`) in
  `ReplicatedStorage.WindMagicMeshes`: `ZephyrWindBladeVFX_Kit`, 71 parts in one model. Its pieces ride in
  `ZephyrInkData` via `final_ink_gust.py`. A shot draws at most 34 parts: 11 + 19 + 1, plus 3 for the swirl.
  - **Switched off (2026-09-16), because the slash could not be seen under them:** the swirl and the flash on the hand,
    the two accent strokes, the ink specks, and the trail on your OWN blade (from behind, its near end ran back at your
    camera and was the biggest thing on screen). `ZephyrFX.Tuning.WindBlade`: `HandSwirl`, `HandFlash`, `Accents`,
    `InkSpecks`, `OwnTrail`, all `false`; `true` puts one back, and the meshes and emitters stay in the place. So your own
    shot draws the crescent (9 parts), and other players' blades the crescent and the trail. The bullets below describe the
    whole kit, switched-off pieces included.
  - One style-A crescent for each hand and stroke: `WindBladeVFX_L`, `_R`, `_LU`, `_RD`. The silhouette is tight, the
    Light band runs down the middle of the body as a bright core, and two small accent strokes flank each blade.
  - Each draws in head first from the hand, and is squashed along the flight at the release, stretched at speed and
    back to its own shape by 0.22 s (`InkStroke:Place`'s `stretch`: geometry, never a blur).
  - The hand gets `WindBladeVFX_Swirl` (three thin curls) and `WindBladeVFX_Flash` (a white-cored spike-burst), both
    gone within a few frames. The swirl belongs just BEFORE the slash: `ZephyrFX.WindBladeSwirl(position, side,
    stroke)` is the entry for that, and until something calls it `FireWindBlade` plays it on the release instead.
  - A three-streak trail draws out behind it over 9 studs (layer 1), with a few black/teal ink specks shed behind it
    (layer 2, `VFXLibrary E.WindInkSpecks` -- particles, so they fade; every mesh here still wipes).
  - An impact burst plays on every character hit: camera-facing, popping out and shrinking away, with a handful of
    sharp Shard-sprite fragments under it (`E.WindShards`).
  - Both emitters are built by `VFXLibrary.WindBladeInkEmitter` / `WindBladeShardEmitter`, which go through the
    library's own `emitter()`, so Graphics Quality density and Reduce Enemy VFX apply. ZephyrFX pools their hosts
    (4 ink rigs, 4 shard rigs): a shot creates no instances.
  - At the end the blade, its accents and the trail wipe toward the tail. Nothing fades.
  - Without the meshes it still flies and hits, undrawn, with one warning per piece.
- **Code:** `ZephyrFX` (client flight, pierce and look), `ZephyrHandler` (server: `WindBladeRelease` /
  `WindBladeHit`, checked against the line, one shot kept for up to 3 characters; broadcasts Side + Stroke),
  `SpellshotInput.fireWindBlade`, `AbilityFX handlers.WindBlade`.
- **Loadout:** `Config.PartialKits = { Zephyr = { M1 = true, Primary = true, Defense = true, Mobility = true } }`. Zephyr
  can be picked; `Config.IsTechniqueBuilt` keeps Cyclone locked in the menu and in the server's loadout check
  (Deflect Gust unlocked 2026-09-16 and Gust Jump 2026-09-17, see below).
- **Tested in Play (2026-09-16, solo, Training Ground):**
  - Clicks 0.125 s apart fired all four crescents in order (L, R, LU, RD), with trails and an impact burst on
    Dummy_16.
  - The server counted every release and hit (13 releases, 14 hits), and the dummy took damage.
  - The first-person arms swing high and low in turn. Sheet: `vfx_blocking/zephyr/wind_blade_vfx/wbvfx_ingame.png`.
  - Cross-Slash Dash (F) still dashes and hits for 30 after the same pushes.
- **Re-tested in Play after the VFX upgrade (2026-09-16, solo, the Training Grounds island):**
  - Every click fired. 47 parts on screen at the peak (two blades overlapping plus a burst), and the crescent, its
    accents, the trail, the release flash, the pre-fire swirl and the impact burst all drew.
  - Both new emitters ran: two `WindBladeInk` rigs and two `WindBladeShards` rigs, pooled and reused.
  - No warnings and no errors in the console.
  - Cross-Slash Dash (F): the load strokes, the braid and the X all still draw, and the dash still moves the caster.
    `InkStroke:Place`'s new `stretch` argument is only ever passed by Wind Blade, so nothing else can see it.
  - Note for the next Play test: synthetic mouse input through the MCP (`user_mouse_input`) never reached
    UserInputService that session -- not for UI, not for the M1. Keyboard worked, and real clicks through computer-use
    worked. The SOLO TEST button would not take a synthetic click either; walking the character into `TY_Portal_Pane`
    runs HubServer's real transition.
- **Re-tested in Play after smoothing the hands and switching the extras off (2026-09-16, solo, the range):**
  - Real clicks (computer-use): six single clicks, then a run. Both first-person hands were recorded every Heartbeat
    (the CastPoint, camera space): no stop-start stutter frame in either hand, and the strokes match the 60 fps replay.
  - At most 13 effect parts on screen at once (32 in the test just before, with your own trail still on); no ink rig
    was made. No warnings and no errors in the console.
  - Sheet: `vfx_blocking/zephyr/wind_blade_vfx/wbvfx_smooth.png` (the replay, the recording, first-person captures, and
    what was switched off).
- **Caveats:**
  - No sound cue; damage numbers may stack at 8 hits/s.
  - Your own crescent is still drawn smaller once it is well away (`OwnFarScale` 0.55), so in first person it reads
    clearly at the hand and small by the crosshair.
  - The third-person clips were not watched from a second client.
  - While `HandSwirl` is off, `ZephyrFX.WindBladeSwirl` does nothing.

#### Zephyr: Cross-Slash Dash (Primary) ⚠️ (2026-09-16)
- **What it does:** on F, the forearms cross (0.30 s charge, the body held still), then one held low glide along
  the aim with the hands behind (44 studs/s, up to 22 studs), stopping 3.5 studs short of the character nearest the
  aim line within 30 studs. At 0.92 s the arms fling open and the X stamps: every character up to 8 studs ahead
  takes 30 damage (stand-ins in `ZephyrFX.Tuning.CrossSlash`). Cooldown 10 s, 25 Mana (`VFXLibrary` row
  `CrossSlashDash`).
- **Look:** the approved choreography and finished look (`vfx_blocking/README.md`, `primary_final.png`). The load
  strokes, the braid on the hands and the heads-up X come from `ZephyrPrimary_Kit.fbx`, re-imported 2026-09-16
  (84 parts), and are drawn by `ZephyrFX.CrossSlash`.
- **VFX polish pass (2026-09-17)**, layered on that look with the cast, its timing and both clips untouched
  (`blender_scripts/zephyr/cross_slash_vfx`, `export/zephyr_cross_slash_vfx`, `ZephyrCrossSlashVFX_Kit`, 56 parts;
  review sheet `vfx_blocking/zephyr/cross_slash_vfx/cxv_review.png`). From the reference sheet's effect breakdown, in
  the kit's flat language (no glow, blur or fade):
  - **Wind Ring:** three flat ring strokes round the caster through the charge (pressed heads, tapers, no strands),
    spinning heads first, wiped to their tails by 0.36 s.
  - **Dash streaks:** three calligraphy streaks trailing the glide, growing with the ground covered, wiped tail first
    at the plant.
  - **Release:** a black spike-burst with a white rim under the X for 0.06 s (the impact frame), then the hard comic
    flash (white core, Base spikes, Dark rim, ink; its long spikes between the X's arms) popping out, holding and
    shrinking away, and four slash streaks flying off the X's arm ends.
  - **Debris / ink splash:** `VFXLibrary.CrossSlashDebris`, teal chips and ink flecks on the hard-edged Shard sprite,
    thrown once at the stamp. Graphics Quality scales both counts; Reduce Enemy VFX halves somebody else's.
  - **Reduce Flashing** drops the black impact frame and draws the flash at 0.8. Your own view draws the frame and
    flash at 0.8.
  - Every number is look-only, in `ZephyrFX.Tuning.CrossSlash` (Ring*, Streak*, InkFrame*, Burst*, SlashStreak*,
    ImpactBehind, OwnImpactScale, Debris*).
  - Tested in Play (solo, the range): every piece drew on the cast's clock (ring 0.06-0.36 s, streaks 0.41-1.00, frame
    0.95-0.98, flash 0.98-1.15, slash streaks 0.95-1.18) beside the untouched Load, Braid and X; the dash stopped short
    of the locked dummy, which dropped 150 -> 120; no console errors. Captured with a spectator camera beside the lane
    and the caster's body un-hidden for the capture. The flash was raised from 1.0 to 1.35 after that capture (so its
    spikes clear the X's arms); the re-run recorded it drawing on time, but its frames came out render-throttled.
  - Not checked: a second client watching; the caster's own first-person view of the new pieces; low-end devices.
- **Wind pass (2026-09-17, second pass), in Studio and play-tested.** Asked for: make it look like the Zephyr logo
  (`textures/icons/Element_Zephyr.png`, the open spiral) and windy, animations too. Every piece now coils, hooks or leans
  like that spiral and turns counter-clockwise on screen (`ZephyrCrossSlashVFX_Kit` rebuilt, 105 parts; the review sheet
  `vfx_blocking/zephyr/cross_slash_vfx/cxv_review.png` now shows this pass, stills in `cxv_wind_pieces.png`):
  - the rings became logo coils that tighten in on the forearms as they turn (`RingScaleFrom/To`, `RingSpin` 560);
  - new `CrossSlashVFX_ChargeSwirl`: the logo itself spinning over the crossed forearms; not drawn to a camera within
    `SwirlNear` (5 studs) of it, i.e. your own first person;
  - the dash streaks roll up into curls; the slash streaks hook over at their ends and whip round (`SlashStreakWhip`);
  - the impact frame and flash are hooked pinwheels that spin (`InkFrameSpin`, `BurstSpin`);
  - new `CrossSlashVFX_GustCurls`: four small logo spirals unfurl between the X's arms and whirl outward;
  - the debris is carried downwind along the dash (`DebrisWind`, `VFXLibrary.CrossSlashDebris`'s new `wind`).
  - The first two imports of the rebuilt FBX failed at upload; the user imported it, and it replaced the 56-part kit in
    `ReplicatedStorage.WindMagicMeshes` (664 MeshParts).
  - Tested in Play (solo, the range, Studio in front at 60 fps): coils 0.03-0.35 s, charge swirl 0.05-0.37, dash lines
    0.40-0.99, impact frame 0.94-0.97, flash 0.97-1.14, slash streaks 0.94-1.17, gust curls 0.97-1.34, beside the
    untouched Load, Braid and X; the dummy dropped 150 -> 120; no console errors. Captured from two spectator cameras
    with the caster's body un-hidden. From the side, the flash and some gust curls sit behind the caster's body.
  - Studio renders slowly while it is not the front window; captures of short effects need it in front.
  - The character animation clips (Viewmodel / CastPose) are unchanged; "animations" was taken as the effects' motion.
- **Code:**
  - `SpellshotInput.tryCrossSlash`: target lock, the `DashMotor` request with a spec, and the strike on the
    Trigger frame.
  - `DashMotor`: an opt-in request spec (charge hold, direction, distance, speed, exclude). Frost Slide is
    unchanged.
  - `ZephyrHandler`: `castCrossSlashDash`, and the `CrossSlashStrike` check against the dash line, reach, timing
    and line of sight.
  - `AbilityFX handlers.CrossSlashDash`.
  - `CastPose Clips.CrossSlashDash`, with new opt-in per-side legs in `Off`.
  - `Viewmodel Clips.CrossSlashDash`, with a new per-clip `Rate`.
- **Tested in Play (2026-09-16, solo, the Training Ground):**
  - Charge, dash, target stop, load strokes, braid, X and wipe all play.
  - The locked dummy took 30 (150 -> 120).
  - Both clips run, and the sampled body joints match the keys.
- **Caveats:**
  - Another player watching (the broadcast path) is untested, since it needs two clients.
  - No sound cue.
  - The one-frame cross in the release is soft in both layers (rates raised to 60 / 45).
  - The whole-body lean is folded into Waist, and the head does not lift, because CastPose has no root or neck
    channel.
  - The X's wipe ends on two heads for a few frames.

#### Zephyr: Deflect Gust (Defense) — equippable, on the Defense key, 12 s cooldown; catches the range's practice shots only ⚠️ (2026-09-16)
Built first as a self-contained practice rig on V (below). The same day it became a real Defense Technique:
**equippable in the loadout, cast on the Defense key (E), with its 12 s cooldown spent on every press**. What it can
catch is still only the range thrower's server-flown practice shot; a defender recognising somebody else's
client-flown shot in a duel is not solved.
- **Equipping:** `Config.PartialKits.Zephyr.Defense = true`, so `IsTechniqueBuilt` unlocks Deflect Gust in the LOADOUT
  menu and the server's loadout check (Gust Jump and Cyclone stay locked). `VFXLibrary` row `DeflectGust`:
  `Role = "Defense"`, `Cooldown = 12` (the manual's, `SpellshotConfig.Defense.DeflectGust`), `ManaCost = 0`.
  The HUD's Defense slot shows the Zephyr Defense glyph and its cooldown sweep from `CD_Defense` / `CDTotal_Defense`,
  like any Defense.
- **The press** (`SpellshotInput.tryDeflectGust`, reached through the normal Defense bind, so a rebind or the gamepad's
  `Pad_Defense` works too):
  - The lead hand swings at once (the Viewmodel's `WindBladeUp` clip, borrowed).
  - The client looks for a practice shot aimed at it inside the window (`DeflectPractice.Catchable`) and sends ONE cast,
    `CastRequest("Defense", { Id, Contact })`, or `{}` for a whiff.
  - A client latch of at least 0.5 s (`DeflectPractice.Tuning.PressLatch`, or 2 x ping + 0.1 when that is longer) holds
    a second press back until the cooldown reaches the client. Presses in the Hub, in a menu, dead, or on cooldown do
    nothing, as for every ability.
  - The swing goes on an arm that is not partway through an M1 shot (`Viewmodel.ShotPending`): swinging over one would
    let it go early, a Fireball out of its wind-up. With both arms busy there is no swing; the press still counts.
- **The cooldown is the server's:** `SpellshotService`'s generic cast path stamps `CD_Defense = now + 12` before
  `PerformCast`, so a whiff and a catch cost the same. The dev panel's NO COOLDOWNS / RESET COOLDOWNS and the reset on
  every respawn apply as for any Defense. Every accepted press also adds the generic 0.06 Ultimate charge.
- **The catch is the server's:** `ZephyrHandler.castDeflectGust` passes the claim to `CombatCore.TryParry`, which asks
  every registered resolver (`CombatCore.OnParry`). TrainingGround registers `tryParry`: the shot must be aimed at that
  player, still on its way out, and inside the window by the server's own copy (`DeflectPractice.InWindow` with 5 studs of
  `ServerSlack`); then it is returned. The rig's old `DeflectPracticeRemote` "Parry" handler is gone, so no client can
  return a shot without a cast that has paid the cooldown. The remote now only carries the server's shot broadcasts.
- **The dummy:** the existing range, extended rather than duplicated. `TrainingGround.server.lua` gives any
  dummy with the `Thrower` attribute a throw loop:
  - It throws at the nearest player standing in the range (`Zone` Arena, `Map` TrainingGround), one shot at a
    time, 1.6 s after the last one ended, with a 0.35 s turn-and-wind-up.
  - The shot is flown by the server: a straight line at 42 studs/s from its right hand to your chest, 80 studs
    at most, carrying Damage 10 and Kind `PracticeShot`.
  - It lands on you (10 damage, never below 1 HP), is spent, or is returned.
  - `TrainingGround_build.lua` builds `Dummy_Thrower`; it was added to the live place by hand, since the builder
    refuses to run over an existing range.
- **The window:** a parry catches a shot that is aimed at you, will reach your body within 0.30 s, is on a line within
  4 studs of you, and has not gone by. A caught shot is turned round where it is and flies back at the dummy with the
  same Speed, Damage and Kind. `DeflectGustPractice.client.lua` draws the shots and keeps them in
  `DeflectPractice.Live` for the press to read.
- **As first built (the rig, superseded the same day):** V swung the hand (not E, then, because E cast the equipped
  Defense), a whiff locked the key for 0.55 s on the client only, and the claim went straight to TrainingGround on
  `DeflectPracticeRemote` with no cooldown at all.
- **The VFX:** `ZephyrFX.DeflectParry(contact, incomingDir)` and `ZephyrFX.DeflectTrail(origin, dir, speed, t0)`,
  from the Deflect Gust VFX kit (`blender_scripts/zephyr/deflect_gust_vfx`, `export/zephyr_deflect_gust_vfx`,
  `ZephyrDeflectGustVFX_Kit`, 24 parts, pieces in `ZephyrInkData`).
  - Parry Arc: a tall cutting crescent across the incoming line, drawn head first, held, then wiped toward
    its tail.
  - Wind Shear: four short cut strokes over the contact, on the same draw / hold / wipe clock, a touch quicker.
  - Trail: one stroke riding the returned shot, wiped tail first into it when the shot lands.
  - Nothing fades. The shot and its hit keep their own plain white look (`DeflectPractice`), out and back, and
    nothing Zephyr's is added on the landing.
- **Tested in Play on E (2026-09-16, solo, the range, 12 s cooldown on):**
  - Equipped through the real LOADOUT menu (Zephyr, then `>` three times on the Defense row): EQUIPPED, and the
    server's loadout check accepted it (`Defense = DeflectGust`).
  - E 0.30 s after a throw caught it: `CD_Defense` stamped 11.97 s ahead, the shot returned with the player as parrier
    and landed on the thrower. E again 2 s later changed nothing, and the next throws landed on the player.
  - E just before a throw left the hand was a whiff: `CD_Defense` stamped 11.96 s ahead, no return.
  - E 0.38 s after a throw caught it, then E mashed every ~0.27 s for 5 s. Two of those presses fell inside the next two
    throws' windows (+0.28 s, +0.41 s); neither caught, both shots landed, and the cooldown was not stamped again.
  - The HUD's E slot showed the cooldown veil and countdown. No errors or warnings in the console.
- **Tested in Play as the rig (2026-09-16, solo, the range):** a 40 s watch, with V pressed every 0.62 s for the first
  10 s.
  - 16 throws: 3 parried, each drawing the Parry Arc, Wind Shear and Trail and landing back on the dummy
    (3 hits on it); the other 13 landed on me.
  - 16 plain hit pops, one per shot. No warnings, no errors.
  - Frame capture of a parry in first person: `vfx_blocking/zephyr/deflect_gust_vfx/dgvfx_review.png`.
- **Caveats / not done:**
  - The production version -- a defender recognising somebody else's client-flown shot and substituting a new
    path -- is not solved here. Equipped in a duel or on another map, every press is a whiff that costs 12 s.
  - No third-person pose, no broadcast of the swing, and no sound. The first-person swing is a borrowed clip.
  - The thrower does not check for a duel: on a duel voted onto the TrainingGround map it may throw at duellists
    within 70 studs of it (not checked in Studio).
  - The loadout's equip message still shows the manual's "reflects one projectile at its owner".
  - In first person the Trail is nearly edge-on (the shot flies straight away from you); the side view on the
    sheet shows it.
  - The older Ink Gust Deflect pieces (Cut / Burst / ShotFlicks / ParryCurl / ReturnTrail) are superseded but
    left in place, untouched.

#### Zephyr: Gust Jump (Mobility) — the bonus jump and short glide, on the jump key, 7 s cooldown from the landing ✅ (2026-09-17)
The Zephyr entry in the Mobility pool, "double jump / short glide -- the only vertical option", built whole: mechanic,
VFX and both animation layers. Tested in Studio Play (solo, the range).
- **Equipping:** `Config.PartialKits.Zephyr.Mobility = true` unlocks it in the LOADOUT menu and the server's loadout check
  (Cyclone stays locked). `VFXLibrary` row `GustJump`: `Role = "Mobility"`, `Cooldown = 7` (the manual's,
  `SpellshotConfig.Mobility.GustJump`), **`ManaCost = 12` -- provisional**: nothing in the manual or the config sets one;
  it matches Heat Rush, the other single-use Mobility Technique, and sits under Frost Slide's 18 a dash.
  `Held = true`.
- **The press** (changed 2026-09-17 on request: "when someone jumps and then presses Q then gust jump activates and if they
  double jump, the gust jump doesnt get activated"): the Mobility key (Q, or its rebind / pad bind) IN THE AIR,
  `SpellshotInput.tryGustJump` -> `GustJumpMotor.Try`. A jump press in the air is always the everyone double jump, and is
  refused while a Gust Jump is under way. On the ground the key only flashes the slot red. Ready means: equipped; alive and
  airborne; not rooted or lifted, dashing or under a zero speed cap; out of the Hub and the menus; `CD_Mobility` over;
  not still held on the server; the mana there. (As first built, the jump press in the air took Gust Jump first.)
- **Where it goes** (same request: "if theyre targetting somewhere it jumps to there but theres a limit"): the aim ray from
  the camera looks `AimReach` 150 studs for a surface. Found, that spot is the landing target -- `WallStandOff` 1.5 studs out
  from a wall -- pulled in to `MaxDistance` 30 studs along the ground from the push-off (then down onto whatever is under
  that point) and to `MaxRise` 16 above it. The body is thrown up to `ArcHeight` 8 over the higher end and carried along the
  ground by a LinearVelocity on X/Z (DashMotor's), re-aimed at the spot every frame, no faster than `MaxSpeed` 40; through
  the glide the speed is whatever lands it as it comes down. Over the spot, or stopped by something, the push lets go and
  the glide carries on down. Nothing hit (the sky), or a spot under `MinDistance` 3 away: the straight-up jump below.
  The Humanoid finds the floor ~0.8 studs above it and the landing ends the push there, so a targeted glide is timed to
  arrive over the spot 0.9 studs up (it first landed ~2 studs short). Tested in Play: landings 0.55-0.83 studs from the
  spot under the crosshair at 8, 15, 22 and 26 studs; aimed 60-80 studs away, it landed at the limit; aimed at the sky, the
  straight-up jump; jump then jump again, the double jump and no Gust Jump; jump, double jump, then Q, a Gust Jump. Sheet:
  `vfx_blocking/zephyr/gust_jump_vfx/gjv_targeted.png`.
- **The jump** (`GustJumpMotor`, a new client ModuleScript beside DashMotor; numbers in `ZephyrFX.Tuning.GustJump`, all
  stand-ins): CAST, the body hangs for `LeadIn` 0.08 s (PROPOSED, not decided; Frost Slide's is 0), its fall held to
  3 studs/s; LAUNCH, targeted onto the arc above, or untargeted up `LaunchHeight` 13 studs keeping and re-aiming its ground
  speed like the double jump; AIRBORNE to the apex; GLIDE, a VectorForce holds up 65% of gravity, the fall capped at
  11 studs/s (untargeted: ground speed under 30, the Humanoid's own air steering left as it is, for up to 1.8 s); LANDING,
  on the ground. A wall run, a dash or a root ends the glide; the jump still lands. Measured: ~13 studs up, ~1.4 s of glide,
  ~2.0 s from the press to the landing.
- **The server:** `SpellshotService`'s HELD path (Heat Rush's) checks alive, the Hub, the cooldown and the mana, spends the
  12 and sets `Holding_Mobility`; `ZephyrHandler.castGustJump` refuses a rooted or lifted body (cooldown started, nothing
  drawn) and broadcasts `GustJump`. The client's release on the landing starts the 7 s cooldown and broadcasts
  `GustJumpLand`; `MaxAir` 6 s and a round reset (`Core.OnClear`) end a jump that never lands (no mark). A cast the server
  turns away brings no broadcast back: the client cuts its glide after `max(0.6, 2 x ping + 0.3)` s and flashes the slot.
  The launch has already happened by then, as a refused Frost Slide's dash has: movement is the client's.
- **Tested in Play:** every run launched on the air press, glided and landed; the hold set ~0.06 s after the press and
  cleared on the landing with the cooldown at 7.0 s; mana 100 -> 88.2; no console errors.
- **The look** (`ZephyrFX.GustJump` / `GustJumpLand`, the Gust Jump VFX kit: `blender_scripts/zephyr/gust_jump_vfx`,
  `export/zephyr_gust_jump_vfx`, `ZephyrGustJumpVFX_Kit`, 45 parts, pieces in `ZephyrInkData`). Built to a shape checkpoint
  (`gjv_checkpoint.png`, marks drawn solid ink in play), then restyled after the reference sheet the user sent back:
  - CAST: two logo spirals and a gather ring under the feet, and two swirl strokes wrapping up round the body.
  - LAUNCH: a tall fountain of spikes shooting up from the push-off with ink shards in it, two rings spreading round the
    spot, and teal chips and ink flecks sprayed up (`VFXLibrary.GustJumpChips`, through `emitter()`).
  - AIRBORNE / GLIDE: calligraphy streaks with ink slashes trailing the body along its travel, face on to the camera,
    as long as the speed makes them. Your own are not drawn (they trail from your eye).
  - LANDING: a low wide splash on the ground, the rings small round the feet, chips and flecks skidding out.
  - Flat bands, hard ink, opaque; the meshes pop and wipe, only the particles fade. Reduce Flashing draws the fountain
    at 0.7 and grows it in rather than popping it. Your own swirl, fountain and rings draw at 0.7.
  - A session's FIRST jump drew no cast or launch marks: a MeshPart cloned from the kit for the first time drew nothing
    for ~0.5 s. `PreloadAsync` and a 2 s warm-up did not fix it; hidden clones of the kit kept in `workspace.ZephyrMeshCache`
    for the session did (every client, 45 invisible parts that nothing can touch or query). The other Zephyr VFX kits
    likely have the same first-use gap; not checked.
  - Review sheet: `vfx_blocking/zephyr/gust_jump_vfx/gjv_review.png`. `InkSilhouette = true` on
    `ReplicatedStorage.IceMagic` draws the pieces solid ink (the checkpoint's review hook).
- **Animation, both layers, on one beat** (`Trigger` 0.08 = `LeadIn`): `CastPose.Clips.GustJump` (crouch in the air, snap
  long with both arms flung up, arms down, then the glide held until the landing: a forward lean with the arms trailing
  back) and `GustJumpLand` (a short absorb); `Viewmodel.Clips.GustJump` (forearms in low, shoved down out of view with a
  camera kick, home by 0.34 s -- brief, because a playing clip holds the M1 off). The body clip starts from the broadcast,
  so on the caster's own client it trails the motion by ~0.07 s. No sound: the project has no Zephyr sound cues
  (`VFXLibrary.Config.Sounds` is Cryo's).
- **Not built, flagged:** the LeadIn value; the mana cost; the target limits (30 along, 16 up) and the arc; there is no
  landing-spot preview before the press (the crosshair is the aim); first person looking down sees the cast wraps sweep
  through the bottom of the view for ~0.2 s. The old see-through Gust Jump pieces (StepMark / Glide / Land) are
  unused.

#### Zephyr: the rest of the Ink Gust kit — meshes only 📋 (2026-09-15)
Toon meshes for every other piece are built on the same brush stroke and exported
(`export/zephyr_ink_gust/`, data in `ZephyrInkData`, placement and draw/wipe in `InkStroke`): the X
payoff (a camera-facing billboard), the load strokes and dash braid, the Updraft halo, Gust Jump's step
marks / glide / landing, Deflect Gust's cut / burst / flicks / parry curl / return trail, and Cyclone's
tornado. **None of it is wired to a cast** — there is no broadcast kind, handler or animation clip for
them yet. Review sheets: `vfx_blocking/zephyr/ink_gust_mesh_*.png`. Imported into the place 2026-09-15:
444 MeshParts in seven models under `ReplicatedStorage.WindMagicMeshes` (464 since the Primary kit's 2026-09-16 re-import; 507 with the Wind Blade VFX kit, `ZephyrWindBladeVFX_Kit`, 43 parts, the same day; 525 with its 18-part return strokes; 535 when the upgrade pass replaced the whole kit with one 71-part model — see `vfx_blocking/zephyr/wind_blade_vfx/README.md`; 559 with the Deflect Gust VFX kit, `ZephyrDeflectGustVFX_Kit`, 24 parts; 615 with the Cross-Slash VFX polish kit, `ZephyrCrossSlashVFX_Kit`, 56 parts, 2026-09-17; 664 when its wind pass replaced it with 105 parts; 709 with the Gust Jump VFX kit, `ZephyrGustJumpVFX_Kit`, 45 parts,
2026-09-17 -- the live Gust Jump draws that kit, not the old step marks / glide / landing); `tools/ink_gust_demo.lua`
ran all 16 pieces' draw / hold / wipe in Play with no errors.

### 24 Techniques 📋 — some built
Three pools of eight, one contributed by each Element. **Frost Slide**, **Chill Aura** and **Cryo Beam** (Cryo),
**Heat Rush**, **Cinder Shield** and **Ring of Fire** (Pyro), and **Deflect Gust** (Zephyr; so far it only catches the
range's practice shots) and **Gust Jump** (Zephyr, 2026-09-17) have code. (The Pyro names in the pools below are the manual's older ones.)

- **Mobility:** Ember Trail · *Frost Slide* ✅ · Chain Lurch · *Aftershock* ✅ *(2026-09-25; replaced Tremor Vault)* · *Gust Jump* ✅ · Fade Step ·
  Lightstep · Overgrowth Vault
- **Defense:** Cinder Shield · *Chill Aura* ✅ · Static Field · *Bulwark Wall* ✅ *(the only wall in the
  game; 2026-09-19)* · *Deflect Gust* ⚠️ *(2026-09-16: equippable, catches the range's practice shots only)* · Decoy Double ·
  Cleansing Ring · Antidote Cloak
- **Ultimate:** Meteor Storm · *Cryo Beam* ✅ · Thunderclap · *Earthen Tomb* ✅ *(2026-09-19, replaces Seismic Slam)* · Cyclone · Nightfall ·
  Radiant Judgment · Bloom

Every entry was checked against the others in its pool for the **distinct-verb rule**.

### The Sparks currency mark 📋
Designed and exported 2026-09-13 (`sparks_icon/`): hero and inline treatments, transparent PNGs at
1024/512/256/128, hot process magenta `#E91E8C`. **Not uploaded to Roblox and not wired into
anything.** There is no economy code of any kind.

---

## 17. Not built at all

- ❌ **No match loop.** No rounds, no scoring, no win condition, no team assignment, no
  round timer. The HUD's round counter reads `RoundsWon`/`RoundsLost` attributes that nothing sets,
  and the duel feed has no producer.
- ❌ **No maps.** The place is a Baseplate, a SpawnLocation and the training range.
- ❌ **No economy.** No Sparks balance, no shop, no Cache, no Contracts, no Robux products, no
  persistence beyond the settings DataStore.
- ❌ **No Mana Shards** in-match upgrade system (explicitly parked).
- ❌ **No progression** — no levels, no unlocks, no season, no stats.
- ❌ **No menus outside the match** — no main menu, no hub, no quick play, no lobby.
- ❌ **No touch control layer.** The six mobile settings save and load correctly but there are no
  on-screen buttons for them to size, fade or flip.
- ❌ **No spectator, no replay, no matchmaking.**
- ❌ `Bind_Interact` / `Pad_Interact` default to `None` and are bound to nothing.

---

## 18. Gaps and risks

1. **`DeathFX` exists in the place but not in `roblox/`.** 4,923 bytes of working script with no
   file in the repo, so the backup does not have it and a lost place loses it. Worth pulling in.
2. **Publish state unverified.** `game.PlaceVersion` reads 158 in Edit. Whether the *current* code
   is in the version Roblox serves has not been confirmed — and Team Test loads the **saved** place,
   not the open one. The place has never been saved or published by me.
3. **`Config.Dev.AllowInLiveGame = true`** — on for Team Test. It only ever grants the place owner,
   but it must go off before the game is public.
4. **The kit PDF's match-end banner reads "+120 SHARDS"** — a stale name from the dropped
   two-currency era. Should read SPARKS if that banner is ever built.
5. **The M1's visual is a placeholder rod.** Its hit registration is real and tuned; the art is not.
6. **`README.md` is stale** — a chronological pass log, not a state document. It still describes the
   M1 as unimplemented and describes sprint as 30 (it is 25).
7. **Retired code still in the place:** `MatchHUD_RETIRED` (disabled), `ViewmodelArm3` in Workspace,
   `ViewmodelArm4` in ReplicatedStorage, and the cut Glacial Spikes / Diamond Skin meshes.

---

## 19. File inventory

| Script | Destination | Lines |
|---|---|---|
| `SettingsMenu.client.lua` | StarterPlayerScripts | 1,259 |
| `VFXLibrary.lua` | ReplicatedStorage/IceMagic | 1,248 |
| `Viewmodel.lua` | ReplicatedStorage/IceMagic | 1,033 |
| `AbilityHandler.server.lua` | ServerScriptService | 873 |
| `StatusReactions.client.lua` | StarterPlayerScripts | 785 |
| `PopArtHUD.client.lua` | StarterGui | 778 |
| `CastPose.lua` | ReplicatedStorage/IceMagic | 715 |
| `MatchHUD.client.lua` | StarterGui *(retired, disabled)* | 619 |
| `SpellshotService.server.lua` | ServerScriptService | 581 |
| `DevPanel.client.lua` | StarterPlayerScripts | 465 |
| `LoadoutMenu.client.lua` | StarterPlayerScripts | 464 |
| `BarKit.lua` | ReplicatedStorage/Spellshot | 410 |
| `MovementController.client.lua` | StarterPlayerScripts | 401 |
| `SettingsRuntime.client.lua` | StarterPlayerScripts | 367 |
| `SpellshotConfig.lua` | ReplicatedStorage/Spellshot | 348 |
| `SpellshotSettings.lua` | ReplicatedStorage/Spellshot | 342 |
| `PopArtAssets.lua` | ReplicatedStorage/Spellshot | 334 |
| `SpellshotInput.client.lua` | StarterPlayerScripts | 291 |
| `TrainingGround.server.lua` | ServerScriptService | 236 |
| `FirstPersonController.client.lua` | StarterPlayerScripts | 208 |
| `UniformAvatar.server.lua` | ServerScriptService | 179 |
| `TrainingGround_build.lua` | *command bar, run once* | 171 |
| `Callouts.lua` | ReplicatedStorage/Spellshot | 153 |
| `SettingsStore.server.lua` | ServerScriptService | 144 |
| `AbilityFX.client.lua` | StarterPlayerScripts | 115 |
| `SlideAudio.client.lua` | StarterPlayerScripts | 105 |
| `IconAssets.lua` | ReplicatedStorage/Spellshot | 94 |
| `CombatFeedback.server.lua` | ServerScriptService | 82 |
| `PopupScaler.client.lua` | StarterPlayerScripts | 76 |
| *`DeathFX`* | *StarterPlayerScripts — **in place only***  | *~120* |

**Total in `roblox/`: 12,876 lines across 29 files.**

### Art and pipeline
- **55 uploaded assets** (`asset_manifest.json`): 8 Element logos, 40 role glyphs (5 roles × 8
  palettes), 5 HUD bar pieces, 2 VFX textures — plus the pop-art chassis ids in `PopArtAssets.lua`.
- **27 Blender build scripts** (`blender_scripts/`) — the icons, the HUD bars, the pop-art chassis,
  the status art, the FX world, the toon rigs and the Cryo kit geometry.
- **13 meshes** in `ReplicatedStorage.IceMagicMeshes`.
- Reference libraries: `m1_reference/` (94 files), `textures/` (68), `settings_reference/` (24, the
  RIVALS captures plus the four layout treatments), `blender/` (28), `export/` (17),
  `slide_reference/` (5), `sparks_icon/` (18).
- Backup: `C:\Users\work\SPELLSHOT_Backup`, refreshed by `vmarm/update_backup.py`.

---

## 20. How this was compiled

Every claim above came from one of three places, in this order of authority:

1. **The live Studio DataModel** (Edit), queried for what is actually installed — the script
   inventory, the mesh list, the sound ids, the training-range contents, `PlaceVersion`.
2. **The source in `roblox/`**, read directly for behaviour and for every number quoted.
3. **Measurements recorded when the work was done** — the 18-of-20 missed shots, the 22-of-22 after,
   the four Roblox API limits, the RIVALS slide capture.

`README.md` was **not** used as a source; it is a pass log and it disagrees with the code in at
least two places.
