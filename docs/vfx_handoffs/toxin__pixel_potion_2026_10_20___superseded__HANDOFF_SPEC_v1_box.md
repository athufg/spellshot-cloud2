# Pixel Potion — Toxin Uncommon skin (HANDOFF_SPEC)

**Status:** built in Studio (2026-10-20), checkpoint stage. NOT in `SkinCatalog.ElementSkins.Toxin` until the owner approves.
**Tier:** Uncommon (`SkinCatalog.Skins.PixelPotion.Rarity = "Uncommon"`, `Rework = true`, no palette).
**Built directly in Studio, no Blender pass** — the owner's build brief asked for a Studio build; the skill's Blender-first
step was skipped on purpose (plain voxel Parts, nothing to model).

## The one object family

A blocky Minecraft-style voxel **potion bottle**: flat SmoothPlastic cubes, hard edges, no Neon, no texture (the voxels
are the pixels). Toxin's own colours: glass `SOLID.MembraneHi`, liquid `SOLID.LiquidDeep`, stopper `SOLID.MaskDark`,
highlight pixel `SOLID.LiquidSpec` (flat, not lit). Module: `ReplicatedStorage.IceMagic.PixelPotionKit`.

| Build | Parts | Used for |
|---|---|---|
| Full | 5 (glass, liquid, neck, stopper, pixel) | the bubble, Patient Zero's mark, the Vent's face bottle |
| Compact | 4 (liquid block, glass shoulder, neck, stopper) | every lobe, petal, drop, splat, residue, raindrop, thread head |

## Per ability (all six covered, none left Default)

| Slot | Default piece | Pixel Potion | Beat |
|---|---|---|---|
| M1 Toxic Bubbles | membrane sac (murk + body + rim) | Full bottle, neck first in flight, upright at rest; sags/flattens on the Default's squash | Default's fly / hold / rest / convert / expire |
| M1 pop | 5 petals, a puff, drops, residue | 5 Compact bottles on the petal paths; puff lobes, drops, splats as bottles; a bottle stuck where it burst | Default's |
| Primary Corrosive Cloud | 15 lobes | 15 Compact bottles in the lobes' places | Default's grow / breathe / fade |
| Passive Symbiosis | lifesteal threads | a Compact bottle rides each thread's head (strands stay) | Default's head / tail |
| Ultimate Patient Zero | thrown glob, 9-lobe wreath, 40-lobe wave, 19-lobe mass, drips | Full bottle thrown and stuck; every lobe a Compact bottle; drips and drops as bottles | Default's |
| Antitoxin Vent | 13-part gas mask, cleanse threads | a Full bottle over mouth and nose, stopper forward; bottles on the thread heads | Default's on / off |
| Acid Rain | hand wisp, 15-lobe cloud, teardrop rain, splats | bottle lobes; it rains Compact bottles neck down; splats are bottles on their side | Default's |

## Rules kept

- Particle delta **0%**: every Default emitter and light is kept; the Default shapes are hidden on this client with
  `LocalTransparencyModifier = 1` (emitters on them keep running).
- No added glow: the Vent's grille / rim Neon flash has no bottle part to light (its keys map to a hidden part).
- Hit-honest: no timing, hitbox or gameplay value touched; ToxinHandler unchanged.

## Not skinned (flagged)

- `ToxinSelfTick` (the self-damage screen tell) and the Corroded glaze (`watchGlaze`, a victim's status) — not a caster's
  piece; status / HUD-like visuals are out of scope.

## Measured in Play (2026-10-20, Training range; Default vs Pixel Potion, same casts)

Counted on the client: every instance created under `workspace.IceMagicFX` (and beams on `workspace.Terrain`) during
the cast. Pixel Potion = the Studio stand-in (`StudioSkin = "PixelPotion"` on the casting body).

| Slot (test) | Emitters D / PP | Lights D / PP | Beams D / PP | Parts D / PP |
|---|---|---|---|---|
| M1 x3 (fly, pop) | 6 / 6 | 6 / 6 | 0 / 0 | 121 / 312 (3-part Compact, before the drop fix) |
| M1 rest + Corrosive Cloud | 16 / 16 | 3 / 3 | 0 / 0 | 63 / 228 (final build) |
| Symbiosis x3 threads | 0 / 0 | 0 / 0 | 99 / 99 | 0 / 12 |
| Patient Zero (mark, burst, mass) | 47 / 47 | 4 / 4 | 1221 / 1386* | 178 / 700 |
| Antitoxin Vent | 0 / 0 | 2 / 2 | 66 / 66 | 14 / 18 |
| Acid Rain | 15 / 15 | 1 / 1 | 0 / 0 | 604 / 1248 (final build) |

Particle delta 0% on every slot. *Beams in the Patient Zero run are the Default lifesteal threads Symbiosis drew from
real poison ticks (33 beams each: 37 vs 42 threads), a timing difference, not the skin. No errors on server or client.
Head/torso visibility: no Toxin ability roots or encases; cloud bottles take each Default lobe's own transparency.

Studio copies of the patched scripts: `studio_sources/` (ToxinFX and SkinCatalog also carry another session's
Studio-only Toxin wrap work, so they are kept here rather than in `roblox/`).
