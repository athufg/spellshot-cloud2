# Pixel Potion — Toxin Uncommon skin (HANDOFF_SPEC, v2)

**Status:** APPROVED and LIVE (2026-10-20): `SkinCatalog.ElementSkins.Toxin = { "Default", "PixelPotion" }`, so it is on Toxin's Loadout SKINS page. Tested: equipping through LoadoutRequest "ElementSkin" draws it with no Studio stand-in.
**Tier:** Uncommon (`SkinCatalog.Skins.PixelPotion.Rarity = "Uncommon"`, `Rework = true`, no palette).
v1 (a plain green box, rejected by the owner) is kept in `_superseded/`.

## The object family (PixelPotionKit)

One blocky Minecraft-style **potion bottle**, 3 parts, built once per client from EditableMeshes and cloned:

| Part | Look |
|---|---|
| Liquid | octagonal voxel body (rows of half-width 2-3-4-4-4-4-4-3-2), Toxin's own greens in the vertices: deep base/right, lit upper left, one glint pixel |
| Glass | pale blue-white voxel shell round the liquid + a narrow 2x2 neck; **Glass** material, T 0.5 (plain plastic while fading: Roblox hides see-through parts behind Glass) |
| Cork | 3x3x3 tan Part, **Wood** |

- A squashed caller box keeps 25% of its squash, so the bottle keeps its proportions.
- **Different potions:** "Compact" bottles take one of 5 liquid tints (hue ±, saturation, value shifts of the same greens). The M1 bubble ("Full") keeps the base liquid. Glass and cork never change.
- Until the meshes are built, or if the build fails: a 4-Part stand-in with the same silhouette.

**Voxel gas** (`PP.Gas`): a blocky ball 5 voxels across, uncoloured. Each cloud lobe gets one, axis-aligned, carrying the lobe's own size, colour, material and transparency.

## Per ability (owner rulings 2026-10-20: only the M1 and multi-instance pieces are bottles; cloud-type pieces and the whole Ultimate are voxel gas)

| Slot | Pixel Potion |
|---|---|
| M1 Toxic Bubbles | the bottle (base liquid), neck first in flight, upright at rest; pop petals, drops, splats, residue = bottles (tinted); pop puff = voxel gas |
| Primary Corrosive Cloud | every lobe a voxel gas chunk |
| Passive Symbiosis | a tinted bottle rides each thread head |
| Ultimate Patient Zero | all pixelated cloud, no bottles (owner, 2026-10-20): wreath, wave and mass = voxel gas at 1.35x the lobe (bigger, like the Default Ultimate's cloud); the mark = a blocky voxel glob; drips and burst drops = Default |
| Antitoxin Vent | the Default's own gas mask, voxelized (`PP.Voxelize`, owner 2026-10-20: same silhouette, no bottle parts): its domes (body, seam) become a 9-voxel ball, its cylinders (canister, ribs, grille, lenses) a 7-voxel pixel disc, and the lens rims a thin pixel ring round each lens (so the Default rim glow reads as two eye-piece lights); same sizes, colours and materials. Eye pieces (rims +0.07 s, lenses +0.09 s) and the canister group (+0.06 s) sit forward of the voxel dome: flush, they z-fought its stepped face in a jagged glow. Straps are blocks already. Air vent (owner 2026-10-20): three dark pixel slats (canister colour) laid across the filter grille's face, the Default grille pulse glowing between them. The Default's own animation (rim glow, lens tint, grille pulse, canister light) runs on the new parts. No bottle parts anywhere on the Vent: its cleanse threads keep the Default heads (owner 2026-10-20) |
| Acid Rain | hold puff + cloud = voxel gas; it rains cubical pixel drops (`PP.RainDrop`: a plain cube, 0.8 of the Default drop's size, in its own colour; owner 2026-10-20: no bottles in the rain, cubes not teardrops); landing splats = bottles on their side |

## Rules kept

- **Particle delta 0%:** Default emitters and lights are untouched. Default shapes are hidden on this client with `LocalTransparencyModifier = 1`.
- **No added glow:** the mask's rim glow and grille pulse are the Default's own, on its voxelized pieces.
- **Hit-honest:** no timing, hitbox or gameplay change; ToxinHandler is unchanged. `dropMask` is byte-identical to the Default's.

## Measured in Play (2026-10-20, Training range, client counts under IceMagicFX + Terrain beams)

| Slot | Emitters D/PP | Lights D/PP | Beams D/PP | Parts D/PP |
|---|---|---|---|---|
| M1 rest + Cloud | 16 / 16 | 3 / 3 | 330 / 330 | 65 / 186* |
| Symbiosis x3 | 0 / 0 | 0 / 0 | 99 / 99 | 0 / 9 |
| Patient Zero | 47 / 47 | 4 / 4 | 1188 / 1188 | 177 / 398 |
| Antitoxin Vent | 0 / 0 | 2 / 2 | 66 / 66 | 14† / 14‡ The Default's 14 mask pieces, voxelized in place (each replaces its Default part), plus the 3 vent slats; no thread-head bottles.
| Acid Rain | 15 / 15 | 1 / 1 | 0 / 0 | 604† / 904 |

\* Measured on the bottle-lobe build just before the voxel-gas change. That change swaps one shape part per lobe (one gas chunk instead of three bottle parts), so emitters and lights are unaffected and the part count drops.
† Default part counts are from the v1 checkpoint run, using the same procedure.
‡ Counts parts added: the 10 voxelized pieces replace (destroy) the Default ones, so the live mask has the Default's piece count; the rest are the bottles on the thread heads.

No errors on client or server. Beams on Cloud and Patient Zero are Symbiosis threads drawn by real poison ticks.

Studio copies: `studio_sources/` (ToxinFX also carries another session's Studio-only wrap work, so it is kept out of `roblox/`).
