# Scorpion — Toxin Rare skin (HANDOFF_SPEC, checkpoint 1)

**Status:** built in Studio, at checkpoint (2026-10-21). It is NOT in `SkinCatalog.ElementSkins.Toxin`. The line is staged and commented out with a "not approved" note. It is not live, selectable or final.
**Tier:** Rare (`SkinCatalog.Skins.Scorpion`: `Rarity = "Rare"`, `Rework = true`, no palette or wrap). There is no `SkinCatalog.Hud.Scorpion` and no `IconAssets.Ability.Skins.Scorpion`.
**Modules:** `ReplicatedStorage.IceMagic.ScorpionKit` (forms, meshes, painted textures) and `ScorpionFX` (pieces, motion, particles). Both run through ToxinFX's own-module skin table `BREW`, which now serves Witch's Brew and Scorpion.
**Stage:** in Studio, a body with `StudioSkin = "Scorpion"` wears it. It can be a player's character or a Training Ground dummy. There is no `_ScorpionStage` script; the checkpoint was staged from MCP calls, so there is nothing to delete.
**Clips:**
- `scorpion_ultimate_round2.mp4` (round 2: the sting at the cast): the whole Ultimate at real speed from a wide camera (outside the burst's cloud), then the sting close up at 0.2x. Round 1's clip, with the tail at the burst, is in `_superseded/`.
- `scorpion_vent_6s_hold.mp4`: real speed.
- `scorpion_acid_rain.mp4`: real speed, then the gather and the first rain at 0.4x.
- `scorpion_m1_primary_passive.mp4`: real speed, then 0.5x.

**Stills:** `scorpion_vs_toxin_skins_30pct.png` shows Default, Pixel Potion, Scorpion and Witch's Brew. The same dummy, cameras and moments are used for each, at 30% scale.

## Asset family (a small set of related modelled assets, several material layers per piece)

| Piece | Forms | Material layers |
|---|---|---|
| Tail plate | A rounded box with a slight flare and a keel. One EditableMesh grid, 12x20. Eight per tail, tapering 1.0 to 0.67. | Matte chitin (two tones alternating), plus a Neon seam ring at each joint |
| Barb | A closed base and a swept tube hooking down. One grid, 18x12. Used as the tail's stinger, the gland's heart and Acid Rain's spines. | Dark barb chitin, plus a Neon seam ring at its base (spines) |
| Venom gland | Two closed halves that hinge open along the seam. Grids 12x20 each. | Translucent venom glass, plus a Neon seam disc, plus a dark barb inside |
| Bulb | The tail's stinger bulb, a sphere | Venom glass, plus a Neon seam ring |
| Pellet | Acid Rain's shot, a sphere | Venom glass, plus a Neon seam ring |
| Painted textures (EditableImage) | Sigil (256), Etch (256), Crack (128), Flake (32), Dot (32) | Tinted where used |

The build is 4 fixed mesh copies and 1,740 template triangles, built once per client through MeshBudget (Essential, with retry). Until they are built, or if the build fails, the Default draws.

## Per ability (all six covered, none Default)

| Slot | Scorpion | Authored motion arc |
|---|---|---|
| M1 Toxic Bubbles | A venom gland (amber-green glass with a dark barb inside) replaces the sac on the Default throw beat. It tumbles in flight and settles on its side at rest. On a hit, a conversion or rest expiry it cracks open along its glowing seam: the top half swings 100°, venom spills and a puddle spreads. The Default pop is skipped. No tail. | LOB, SETTLE, CRACK |
| Primary Corrosive Cloud | The Default olive miasma, with chitin dust drifting through it (the Rare layer). The ground under it etches outward from the centre, and venom beads swell and pop while it sits; it fades with the cloud (the expiry tell). No tail. | ERUPT, ETCH, SETTLE |
| Passive Symbiosis | A thin (0.07) glowing venom thread arcs from the enemy to the caster's hand in 0.22 s. It then dissolves from the enemy's end (0.35 to 0.75 s) with a venom puff at the hand. The Default strands are hidden. No tail. | ARC AND FADE |
| Ultimate Patient Zero | **Round 2 (owner, 2026-10-21): one tail action, at the cast.**<br>**The sting:**
- The burst's tail asset (glass-droplet bulb, barb), at the same 4.2x, bursts out of the ground 4.4 studs behind the target (0 to 0.14 s). That distance is shortened if a wall is nearer.
- The direction is fixed at the cast, so it never swings round a target who turns. It rears over them, then lashes down in a scorpion's J: the tail comes down behind them, its end rises forward at shoulder-blade height, and the barb's hook curls down into their upper back at 0.28 s.
- The barb's point is placed in the wound each frame from the kit's `BarbTip`; measured, the point sits exactly on the wound. It holds there to 0.44 s, then draws out part way and sinks, gone at 0.94 s.

**The ring:** the hit delivers the mark. A small sigil glyph stamped on the skin of the wound hinges down about the target's right and opens out into the 9.5-stud ground ring over 0.35 s. Nothing is drawn before the hit. If the sting cannot be made or misses its beat, the ring is delivered at 0.53 s anyway.<br>**The beat:** it keeps the Default's gears timed from the cast (0.6, then 1.8, then 4.6 Hz over the telegraph minus the fuse, 3.15 s; capped at 1 Hz under Reduce Flashing). It beats by **scale and spin, never brightness**, then draws in and holds for the 0.35 s fuse. The Default mark's drips fall from the wound.<br>**The burst:** no tail. The Default's pressure wave and mass cloud burst, with the Primary's etch, dust and beads; its flash stays out.<br>The caster's worn tail does not move in the Ultimate. The Default glob, wreath shapes, chest glow and lights are hidden; the wreath's smoke still rises round the target. All numbers are unchanged. | STING AND COUNTDOWN |
| Antitoxin Vent | The tail curls over the shoulder in AssembleTime (0.35 s) and its bulb covers the mouth, measured at about (0.05, -0.27, -0.72) in head space. It holds for the full Duration, breathing a faint venom vapor, then uncurls home. **Measured: the pose released at 6.00 s.** Nothing else is worn. The cleanse threads end on the bulb, in Scorpion colours. | ASSEMBLE AND HOLD |
| Acid Rain | Inside GatherTime with no added delay, the tail rears (0 to 0.2 s) and fires 7 venom pellets at 0.24 s. They reach the Default's cloud over the area at 0.46 s and burst into it. The tail settles home by 0.70 s. **Measured: the pose released at 0.40 s, followed by a 0.3 s blend.** The Default drops are replaced by thin barbed spines falling point-first on the Default rain window (26/s at full density). Each sticks, sizzles and leaves a corrode mark. A struck enemy shows faint glowing chitin cracks whose strength tracks Corroded stacks (`ToxinVuln` over `VulnMaxStacks` 4) and fades as `ToxinVulnUntil` lapses. The cracks are hidden in the victim's own first-person view. The Default glaze is not drawn. | RISE, FIRE, RAIN |

## The tail (the one flagged avatar piece: the owner's one-off exception at Rare, not a precedent)

- **Form:** a segmented chitin tail at the lower back (19 parts) with a barbed stinger. It glows only at its joint seams.
- **Idle:** a slow sway and bob on an S-arch up behind the head.
- **Performs only in three abilities:**
  - The Ultimate: its sting at the cast. This is the tail's form at body scale, coming out of the ground behind the target; the worn tail itself stays idle.
  - Acid Rain: rear, aim and fire.
  - The Vent: curl over the mouth.
  - The M1, Primary and Passive never move it.
- **Posing:** each pose is 5 points through a Catmull-Rom curve, with the plates laid out by arc length and blended between poses. Parts move with `workspace:BulkMoveTo`.
- **First person:** hidden in the wearer's own first-person view. Verified on the real player with the live module: 19 of 19 parts at LocalTransparencyModifier 1.

## Glow (edges and seams only)

- Neon is used only on the seam rings (tail joints, bulb, barb base, spines, pellets) and the gland seam.
- Beam glow is used only on the thin siphon thread.
- SurfaceGui line art is used only on the sigil and the chitin cracks.
- There is no self-lit core or body, no light added by the skin, and no brightness pulse.
- The seam colour is **Toxin's own `ToxinTuning.Neon.Virulence` (140,175,80)**. The first build's (150,205,40) clipped to #F8FF02 lime-yellow on screen.

## Particles

- **BASE layer:** steam and dust puffs. Scaled by Graphics Quality through ToxinFX's `density()`, the same scale as the Default (EffectDensity 0.4 to 1, halved for an enemy's effect under Reduce Enemy VFX).
- **RARE layer ("Fleck"):** chitin dust, venom droplets and glass chips. It has its own switch: the `ReplicatedStorage.IceMagic` attribute `ScorpionFlecks` (absent or true is on). It is scaled the same way.
- No glints and no motes.
- `ScorpionFX.Stats` counts both layers. They are published as `IceMagicFX.SC_StatBase` and `SC_StatFleck`.
- Many small puffs share one re-aimed host: the cloud's bead pops, the rain's sizzles and the Vent breath. Acid Rain keeps 2 emitters instead of 2 per spine.

## Measured in Play (2026-10-21, Training Ground, peak added over the scene)

| Test | Default parts / emitters / lights | Scorpion parts / emitters / lights | Scorpion base / fleck particles |
|---|---|---|---|
| Idle (worn) | 0 / 0 / 0 | 19 / 0 / 0 | 0 / 0 |
| M1 + crack | 24 / 3 / 1 | 10 / 5 / 1 | 1 / 16 |
| Corrosive Cloud | 33 / 13 / 1 | 40 / 17 / 1 | 10 / 79 |
| Symbiosis x3 | 0 / 0 / 0 (its strands are Terrain beams) | 6 / 2 / 0, plus 2 beams | 0 / 6 |
| Patient Zero (sting at the cast, round 2) | 158 / 47 / 4 | 166 / 48 / 3 | 12 / 68 |
| Antitoxin Vent | 14 / 0 / 2 | 8 / 10 / 0 | 8 / 24 |
| Acid Rain | 208 / 15 / 1 | 183 / 21 / 1 (it was 119 emitters before the puffs were pooled) | 108 / 215 |

- **Persistent cost per wearer:** 19 parts, no emitters, no lights.
- **Meshes:** 4 fixed meshes, 1,740 template triangles. For comparison, Witch's Brew has 1 fixed mesh (486 tris) and Pixel Potion has 9 fixed meshes.
- **Pixel Potion parts per cast:** Cloud 186, Patient Zero 398, Acid Rain 904 (Default 604), from its own handoff.
- **Witch's Brew parts per cast:** Patient Zero 12, Acid Rain 194 parts added.

## ToxinFX changes (Studio-only module; the pushes are compare-and-swap)

**push21:**
- `BREW` serves a list of own-module skins (`BREW.Skins`, `BREW.on`, `BREW.call`). A hook a skin lacks is skipped.
- The Splash hooks receive the bubble.
- `b.WB.OwnBurst` skips the Default pop.
- New `BubbleExpire` hook.
- The Mark record's `HideCore` hides the Default chest glow and lights.
- A `PZBurst` hook that returns true replaces the burst's flash.
- The Vent record carries its skin's FX and thread colours.
- `AcidTick` calls a `Corrode` hook.

**push22:**
- An own burst replaces only the flash; the pressure wave stays.
- `AcidRain` may return `"drops"`: the skin draws only the drops, the Default cloud stays and the hand wisp is skipped. Returning `true` (Witch's Brew) still hides the whole Default rain.

**push23 (round 2):** the Default mark's drips ask the skin's mark record for `DripAt()`, pcall-wrapped (Scorpion: the wound on the skin, once the sting has landed; nil before, so no drip). A record without `DripAt` (Witch's Brew), and the Default, drip from the glob as before.

**push24:** comments only (the burst's flash note no longer mentions a tail).

**Witch's Brew:** its behaviour is unchanged by every push. Its hooks return what they always did.

**Sources:** `studio_sources/` holds byte-verified copies (ScorpionKit, ScorpionFX, ToxinFX push24) and the patch scripts.

## 30% scale read (scorpion_vs_toxin_skins_30pct.png)

- Scorpion reads above Pixel Potion in Idle (a worn, seam-lit tail against nothing), the M1, the Ultimate (the towering tail over the Default wave and mass) and Acid Rain (dense spines and corrode marks under the cloud).
- It reads clearly below Witch's Brew, which has a luminous cauldron, a glowing core in every piece and glints.
- **The Vent is the quiet slot:** the tail over the mouth is subtler at 30% than the Default's glowing mask. This is by design, since the owner's spec asks for no mask or prop.

## Flags for the owner

1. **Sigil pulse.** Rare forbids a brightness pulse. The sigil keeps the Default's tempo by scale and spin at a constant edge brightness.
2. **Blender first.** The skill's design-in-Blender step was skipped, because the owner's prompt asked for a direct Studio build (as Witch's Brew was).
3. **Push method.** The modules were pushed with `tools/push_to_studio.py` (a Studio compile check, `UpdateSourceAsync`, then a hash read-back). ToxinFX was pushed with the compare-and-swap pusher, because it is a Studio-only module.
4. **Acid Rain is a shared-pool Technique.** It is skinned only when the caster's Element is Toxin, the same rule as Pixel Potion and Witch's Brew. Today `TechniquesOwnElementOnly = true`.
5. **The Default mark glob.** It is hidden for Scorpion; only its drips show, and since round 2 they fall from the sting's wound.
6. **Readability.** The Ultimate's sting rears up to ~10 studs behind the target for under a second at the cast, then is gone. The ring and the burst are as before. The sting is hidden in the target's own first-person view.
7. **Wrap over the skin.** Scorpion draws in Toxin's own colours. A ToxinWrap palette does not repaint its pieces; this was not in scope.
8. **Agreement check** (`agreement_check.py`, run on Studio's live SkinCatalog, fetched in Edit mode on 2026-10-21; the local `roblox/SkinCatalog.lua` is stale and has no Witch's Brew or Scorpion entry):
   - **Scorpion:** the one finding is "not in any `ElementSkins` list", which is intended until approval. The kit header's old "planned Epic" wording, which tripped the check, is reworded and pushed.
   - **Other skins, reported only:**
     - Devil has no `Rarity` field.
     - FrostLotusFX's header says Rare but the catalog says Epic.
     - WitchsBrewKit's header says Rare but the catalog says Epic.
   - **Script limitation:** it misses the `ElementSkins.Toxin = {…}` line form, so it wrongly reports Pixel Potion and Witch's Brew as unlisted. Both are live.
9. **Out of scope, reported, not fixed:** `WitchsBrewKit.lua` `WB.Straps` has `out[#out + 1], out[#out + 1] = front, top`. Both indexes resolve before the assignment, so it returns only the top straps and never the front ones. Scorpion's kit had the same slip; that one is fixed, since it broke the tail's first-person hide.
