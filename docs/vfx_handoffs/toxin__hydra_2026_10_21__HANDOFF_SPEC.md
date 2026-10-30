# Hydra — Toxin Mythic skin (HANDOFF_SPEC, checkpoint 1)

**Status:** built in Studio, at checkpoint (2026-10-21). It is NOT in `SkinCatalog.ElementSkins.Toxin`. The line is staged and commented out with a "not approved" note. It is not live or final.
**Tier:** Mythic (`SkinCatalog.Skins.Hydra`: `Rarity = "Mythic"`, `Rework = true`, no palette or wrap).
**HUD set:** deliberately NOT done (no `SkinCatalog.Hud.Hydra`, no `IconAssets.Ability.Skins.Hydra`). It is a separate follow-up task. This is a gap against the Mythic contract.

**Modules:**
- `ReplicatedStorage.IceMagic.HydraKit`: part classes, meshes, painted textures.
- `ReplicatedStorage.IceMagic.HydraFX`: the performance, particles and the client kill effect.
- `ServerScriptService.HydraKillHook`: the kill stamp.
- The skin is the third entry in ToxinFX's own-module skin table, `BREW` (push25: one line, no new local).

**Stage:** in Studio, a body with `StudioSkin = "Hydra"` wears it. There is no `_HydraStage` script; the checkpoint was staged from MCP calls, so there is nothing to delete.
**Sheets:**
- `hydra_beats_sheet.png`: freeze-frame bursts of 3–7 frames per beat (the Ultimate, the Vent's 6 s, Acid Rain, the Primary, the kill effect).
- `hydra_vs_witchsbrew_30pct.png`: identical cameras for both skins.


## Round 2 (2026-10-21): Blender-modelled, lit

The owner asked for every recurring piece to be modelled hard-surface in Blender, and for the luminous core and the glint layer to be visible.

**Assets** (`helm/`: `hydra_creature.py`, `hydra_helm.py`, `hydra_export.py`, then the generated `HydraData` module):
- **HeadSkull + HeadJaw:** ONE head. It has a faceted skull, ridged dorsal scutes, swept brow plates with horns, glowing eye-slits and edge ribbons, cheek scales, fangs, a three-spine crest with a membrane, a venom gem plus a throat crystal (Core), and a hinged jaw with pale scutes and a glowing lip line.
- **NeckSeg:** ONE armoured neck segment: dorsal plate and keel, a spike, belly scutes, a glowing seam and throat vein.
- **HelmBack + HelmFace:** the approved helm.
- **Reuse:** every head in the kit is this head at a size. The shoulder head is 0.88, the Ultimate's three are 1.5, Acid Rain's are 0.55 and the kill effect's are 1.3. Every neck is made of this segment. The helm is the one separate asset.
- **Cost:** 24 part-class meshes, 7,642 template triangles, built per client one mesh a frame (0.9 s measured). No uploads.

**Luminous core:** every head's Core (Neon gem and throat crystal) carries a PointLight (range 4.5 x scale, breathing 0.85–1.4, steady under Reduce Flashing) and a soft core glow. The M1 glob has a light. The shut helm's eye-slits light the face (1.6).

**Glint layer:** glitter motes drift off every head continuously (3/s; halved under Reduce Flashing), glint along the shut helm's slits (5/s), and fill the clouds (9/s). It stays on its own switch, `HydraGlints`, scaled by Graphics Quality. Measured: 30 glints per 10 s at rest; 823 glints against 1,514 base particles over the full beats take.

**Vent:** at rest the faceplate stands raised above the forehead like a visor flipped up. On cast it swings down on its one hinge (smooth ease) and is flush shut at 0.35 s, the head fully enclosed and the eye-slits lit. It starts back at 6.06 s on the same hinge (measured).

**Clips and sheets:** `hydra_vent_helm.mp4` (the full Vent at real speed, then the close and reopen at 0.2x), `hydra_beats_sheet_v2.png`, `hydra_vs_witchsbrew_30pct_v2.png`.

## Part classes (round 1 -- superseded by round 2 above)

| Class | What | Material |
|---|---|---|
| Scale | The heads' skulls and jaws, and the faceplate | Matte jade (46,88,54) / (78,120,64); the pale jaw is (136,148,96) |
| Coil | The necks: tapering plates laid along a curve | The two scale tones, alternating |
| Fang | Fangs, the faceplate's tusks, Acid Rain's spines | Ivory (226,218,186); one curved, hooked mesh |
| Frill | The crest membranes | Translucent amber-green (112,146,52), T 0.3 |
| Glow | Neon edge ribbons: brows, joint seams, eye-slits, the throat vein | Toxin's Neon.Virulence (140,175,80); eyes (186,214,92) |
| Core | The Neon venom heart in each head's glass throat, and the glob's heart | (160,200,78) inside venom glass (172,198,58) |

**Meshes:** 5 procedural EditableMesh grids, 2,420 template triangles (Plate, Fang, HeadTop, HeadJaw, Frill), built once per client through MeshBudget Essential. Scorpion uses 4 meshes and 1,740 tris; Witch's Brew uses 1 mesh and 486 tris.
**Textures:** 6 EditableImages (Sigil 256², Etch 256², Crack 128², Flake/Dot/Glint 32²), about 0.6 MB.

## Resting presence (the open flag, proposed)

- **The shoulder head:** one head coiled up out of the right shoulder blade. It is dormant: a slow breath, its core dim.
- **The faceplate:** raised on its temple hinge, lying on top of the head as a crest.
- **On cast only:** the Ultimate's three heads and Acid Rain's small heads.
- **Cost:** 36 parts per wearer, no emitters. Scorpion's worn piece is 19 parts; Witch's Brew's is 20.
- **First person:** all of it is hidden in the wearer's own first-person view. This is open for you: hiding the shoulder head means the wearer never sees their own bite-and-spit.

## Per ability (all six covered, none Default) — the performed beat

| Slot | Beat | What happens (all numbers the Default's) |
|---|---|---|
| M1 Toxic Bubbles | BITE-AND-SPIT | On the throw the shoulder head snaps forward down the aim, jaw wide, and spits the venom glob (glass round a Core, a spinning seam). For the first 0.1 s the glob leaves from the mouth, then it follows the Default path. It bursts in a scorched splash; the Default pop is skipped. |
| Primary Corrosive Cloud | WIND-UP-AND-EXHALE | The head rears back (0–0.18 s), then breathes a jet of the miasma at the cloud's heart for the rest of FormTime (0.6). The ground etches and bubbles; shed scales and glints drift in the gas. |
| Passive Symbiosis | PULSE-AND-GLOW | A thin venom thread runs from the enemy into the shoulder head's mouth. It gulps, and a light runs down the throat vein from head to shoulder (0.45 s). The pulse is smaller under Reduce Flashing. |
| Ultimate Patient Zero | STRIKE-COIL-STRIKE | **Beat one:** three heads (1.5x) burst from the ground round the target and lunge. The bite lands at 0.30 s and **delivers the mark**: a glyph stamped on the bite hinges down into the hydra sigil ring. **Countdown:** the necks coil round the target and tighten on the Default's gears, timed from the cast (0.6 → 1.8 → 4.6 Hz over 3.15 s), jaws hissing on the beat; the ring beats by scale and spin. **Beat two:** at the fuse they rear high (3.15–3.40 s); at the burst they strike down together (0.1 s) as the Default's wave and cloud erupt, then sink. The Default flash stays out. |
| Antitoxin Vent | HINGE-CLOSE | One rigid fanged hydra skull on one hinge through the temples swings down over the face in AssembleTime (0.35 s, with a small clunk). It holds shut with its eye-slits lit; measured, it starts to reopen at 6.07 s (Duration 6), then swings back to the crest. It replaces the Default mask. The cleanse threads end on its snout. |
| Acid Rain | EMERGE-AND-SPIT | Three small heads come out of the back beside the shoulder head (0–0.16 s). All four spit venom up into the Default's cloud (0.22 / 0.27 / 0.32 / 0.37 s; the last lands at 0.57 s) and sink back. **Measured: the extra heads are present 0.01–0.68 s, inside the 0.7 s GatherTime.** Fang-spines then fall from the cloud on the rain window (26/s), sticking, sizzling and leaving corrode marks. A struck enemy's scales crack and glow with their Corroded stacks (out of 4) and fade as they lapse. |
| Kill effect | THE HYDRA'S DUE | Three heads (1.3x) rise round the fallen (0–0.18 s), rear (to 0.38 s) and strike down together (0.48 s). Venom bursts, cracked-scale glow covers the body, the heads sink, and a corroded stain is left; gone at 1.6 s. Client-side, from the server stamp. |

## Glow and particles

- **Luminous core:** a Neon venom heart in each head's glass throat and in the glob. The heads' cores breathe slowly (a colour lerp, never a flash).
- **Edge ribbons:** Neon on the hard edges (brows, every neck joint, the eye-slits, the throat vein).
- **BASE layer:** steam and the breath jet, scaled by Graphics Quality through ToxinFX's `density()`.
- **FLECK layer:** venom drops and shed scales (`ReplicatedStorage.IceMagic` attribute `HydraFlecks`).
- **GLINT layer:** four-point glints off the scales (`HydraGlints`), halved under Reduce Flashing.
- Both switchable layers scale the same way as the base layer.
- **Counts:** `HydraFX.Stats` counts all three; they are published as `IceMagicFX.HY_StatBase` / `HY_StatFleck` / `HY_StatGlint`.

## Measured in Play (2026-10-21, Training Ground, peak added over the scene)

| Test | Default parts / emitters / lights | Hydra parts / emitters / lights | Hydra base / fleck / glint |
|---|---|---|---|
| Resting creature | 0 / 0 / 0 | 36 / 0 / 0 | 0 / 0 / 0 |
| M1 + burst | 24 / 3 / 1 | 9 / 6 / 1 | 2 / 17 / 5 |
| Corrosive Cloud | 33 / 13 / 1 | 42 / 21 / 1 | 11 / 80 / 17 |
| Symbiosis x3 | 0 / 0 / 0 | 6 / 2 / 0 (plus 2 beams) | 0 / 6 / 0 |
| Patient Zero | 158 / 47 / 4 | 264 / 53 / 3 | 24 / 103 / 25 |
| Antitoxin Vent | 14 / 0 / 2 | 7 / 7 / 0 | 0 / 16 / 2 |
| Acid Rain | 208 / 15 / 1 | 163 / 26 / 1 | 108 / 218 / 5 |

**Mesh memory:** the build is the 5 template meshes (2,420 tris); every head, neck and faceplate is a copy, with no per-piece mesh builds. Nothing needs a denser mesh, so there is no Octopus-style budget wall.

## ToxinFX change

**push25:** `BREW.Skins` gains `{ Kit = "HydraKit", FX = "HydraFX" }`. Nothing else changed. All earlier hooks are reused as they are: BubbleStart/Draw/Rest/Splash/Expire, Cloud, Bubblify, Siphon, Mark (+ HideCore, DripAt), PZBurst, Vent/VentEnd, AcidRain (`"drops"`) and Corrode.

## Flags for the owner

1. **The Ultimate's heads come from the ground round the target, not from the caster.** Patient Zero's Range is 60, so necks reaching that far would be absurd. Both reads are kept: the bite causes the mark, and the later strike erupts with the cloud.
2. **Resting presence.** The shoulder head plus the faceplate crest, as above, and all hidden in the wearer's own first person. Tell me if you want the shoulder head visible to its wearer.
3. **Kill hook attributes.** `HydraKillFX` / `HydraKillFXVictim` / `HydraKillFXVictimRef`, rather than Frost Dragon's `KillFX`, because Frost Dragon's client effect listens on `KillFX`. The hook was compile-checked and its client effect previewed (`HydraFX.PlayKill`), but it was not fired by a real Hydra-wearing player's kill in this pass.
4. **Push method.** I used `tools/push_to_studio.py` (a Studio compile check, `UpdateSourceAsync`, then a hash read-back) instead of the prompt's http.server + loadstring route. The result is the same, and it is the verified path from every earlier Toxin skin.
5. **Acid Rain is a shared-pool Technique.** It is skinned only when the caster's Element is Toxin, the same as every Toxin skin.
6. **Palette.** It stays in Toxin's olive/venom key: jade scale, ivory fangs, Toxin's own Neon. At 30% Witch's Brew is still more luminous (purple glow, glints); Hydra out-reads it in form (a creature in every slot) but not in brightness. Say if you want Hydra's cores and glints pushed brighter.
7. **The Vent clunk.** The faceplate's close overshoots slightly (a small "clunk"), so it reads shut from about 0.13 s; the swing still ends at the 0.35 s AssembleTime.
8. **Nothing gameplay-side was touched.** Hit widths, timings, ranges and damage are untouched; nothing was held back for needing a number change.
