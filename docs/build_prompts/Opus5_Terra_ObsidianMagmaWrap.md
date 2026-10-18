# SPELLSHOT — Build Prompt #[N]: Terra "Obsidian Magma" wrap

Continuation of the Opus 5 / Claude Code build sequence (previous: the Radiant Rainbow wrap prompt; keep [N] as a placeholder).
**Vocabulary (the developer's):** a **wrap** is a recolour and re-material of an ability's existing shapes. A **skin** is reserved for a full rework of an ability. This pass builds a wrap only. Terra's shapes, timings and behaviour do not change, and nothing here touches damage, range, cooldowns, hitboxes or the knockdown. Colour only, and only when the player equips it.

## Current state (from the notes and the developer, NOT from code — read the code before trusting this)

- **Terra is partly built.** In the Loadout menu Terra is marked "M1 + Primary + Passive only", so the wrap covers: **Boulder Shot** (M1: hold to charge, release early for less damage), **Bulwark Charge** (Primary: charge forward with damage reduction, knock down what you hit) and **Bedrock** (Passive: a stacking shield while charging the M1 or mid-Bulwark Charge). Terra's Techniques and Ultimate (the notes list Tremor Vault, Bulwark Wall, Seismic Slam) are not built. Do not wrap or build anything unbuilt; confirm what exists from the code and use the real ability names.
- **Terra's shipped colours:** Base `#826B24`, Light `#CCBA5C`, Dark `#33210D`. Logo: a faceted rock cluster. Shape language: chunky, heavy, faceted polygons, nothing rounded. The Colourblind-Safe uniform swaps Terra to purple `#784E9E`.
- **Terra's crack signature:** cracks in the rock show intensity. Find how Terra's cracks are built today (mesh, decal, particle) and drive the wrap through it.
- **The wrap system comes from the Radiant Rainbow pass** (a catalog, a `Resolve(element, ability, id)` lookup, one chosen id per ability stored with the loadout and validated by the server through an `OwnsSkin`-style stub that returns true, the id carried on the existing broadcast, and a button inside the Loadout panel). **Check first whether it exists. If it does, extend it with data only.** If it does not exist yet, stop and tell the user to run the Radiant prompt first. Do not build a second system.
- **Naming:** if the Radiant pass labelled the user-facing button or rows "SKINS", change the **visible label** to **WRAPS** (code names may stay). Report this as one line.

## Reference before styling

No reference image was supplied. In words: black volcanic glass (obsidian) cut into hard, flat facets, with thin veins of molten rock glowing through it. Do not build from adjectives. First post a **swatch sheet** (below) for approval before it goes on any ability. Flat pop-art comic style: hard colour bands, ink outline, no smooth gradients on the rock.

## Design direction — Obsidian Magma (all values are PROPOSALS, flag them)

**Rock body (3 flat tone bands, the existing toon method):** shadow `#14101C`, mid `#2A2236`, lit `#4A3E5E`, plus a thin hard-edged highlight facet `#D9CCFF` on the sharpest edges so the glass reads. Ink outline `#080E1A` stays on outlined meshes.

**Magma cracks (the one glowing element, and the developer wants them a bit more glowing than a plain flat red):** each crack is three flat layers from outside in: outer deep red `#E5231B`, middle orange `#FF7A1A`, core hot yellow-white `#FFF1C2`. The core is the brightest thing in the effect.
- Make the cracks glow noticeably: build them from Neon-material thin geometry (not on the outlined rock meshes), so they catch bloom, with at most **one** small, low-intensity point light per ability, not per crack. Expose one tunable constant `CrackGlow` (0 to 1, start at **0.6**) so the developer can turn it up or down without touching code. Report where it is.
- **Glow limit:** only the cracks glow. No inner-glow wash on the rock, no soft halo around the whole effect, no bloom blowout. The rock stays dark and flat so the cracks pop.
- **Intensity link:** the crack brightness follows the existing intensity signal (Boulder Shot charge level, Bulwark Charge speed, Bedrock stack count). Low intensity: dark red, thin. Maximum: orange with the white-yellow core. It is a static brightness per intensity step, never a flicker or a pulse.
- **Bedrock:** the shield reads as obsidian plates, and each stack lights one more magma seam between the plates.
- **Debris and impacts:** impact chunks are obsidian shards (reuse the existing angular `Shard` debris) with a few orange ember flecks. Use the existing particles recoloured; add no new emitters.

**Identity anchor (PROPOSAL, flag it):** opponents read an Element by shape and colour. Orange can look like Pyro, so Terra must stay readable as Terra: keep Terra's chunky faceted silhouettes untouched, make the cracks thin jagged **lines** (never flame, teardrop or lick shapes), and keep the **impact dust puff and hit-flash in Terra's tan Light `#CCBA5C`**. Pyro stays the flame element, and Terra stays the rock element.

**Not in the wrap:** the viewmodel arms (bare skin, always), the third-person Element uniform colours, the hotbar icons, and any magenta or hot pink (`#E91E8C` is the Sparks mark).

## Build

1. **Wrap data only.** Add a `Terra / ObsidianMagma` entry to the catalog: the palette above, plus whatever the crack and band resolver needs. Terra's effect code gets only the same single lookup used for Radiant. `Default` must render exactly as it does today.
2. **Where colour lives (find out first):** if Terra's meshes have baked vertex-colour tone bands, `MeshPart.Color` multiplies the baked olive-brown, and a dark tint goes muddy. Reuse whatever approach the Radiant pass chose (neutral-grey bake tinted per wrap, a second baked set, or non-mesh parts). Report which. Keep the white `SmoothPlastic`, opaque, `DoubleSided = false` rule for outlined meshes. Never make an outlined mesh transparent.
3. **Others see it.** The caster's wrap id rides on the existing broadcast, and every client resolves it. No server-side visual objects.
4. **Loadout.** Obsidian Magma appears as a selectable wrap on Terra's three built ability rows (Boulder Shot, Bulwark Charge, Bedrock) in the existing WRAPS view, with `< >` stepping Default and Obsidian Magma. Everything is unlocked for now (the stub returns true).

## Integration and rules

- **Budget:** zero new emitters and zero new parts compared with Default, except the Neon crack geometry and the single light per ability if the existing cracks cannot take Neon in place. Report the exact cost. It must hold on low-end mobile.
- Respect Reduce Flashing, Graphics Quality and Reduce Enemy VFX exactly as Default does. No flicker. Keep `CrackGlow` bounded so the cracks cannot blind in first person or on a pale background.
- **Colourblind-Safe:** identity comes from shape and the tan hit-flash, not from crack colour. Check it with the toggle on, and check the crack contrast against the dark rock.
- Cosmetic only: no gameplay value and no hit-feedback timing changes.

## Checkpoints (stop and post, in this order)

1. **Swatch sheet:** the three rock bands and the three crack layers on a flat panel, and on a single Boulder Shot, at on-screen size, with `CrackGlow` at 0.4, 0.6 and 0.8 side by side. Approval, and the developer picks the glow level.
2. **One ability first:** Boulder Shot in Default and Obsidian Magma side by side at low and max charge, first and third person, at on-screen size.
3. **The rest:** Bulwark Charge (including the knockdown impact) and Bedrock, Default vs wrap, one contact sheet, plus one Loadout screenshot of the WRAPS view for Terra.

## Scope reminder

Not in this pass: any other Element or any other Terra wrap, Terra's unbuilt Techniques and Ultimate, a Mythic or animated tier, Sparks or rarity gating, a shop, new shapes, retiming, the hotbar icons, the uniform, other menu changes (beyond the WRAPS rename if needed), and the open ❓ items (Aqua above all). Add nothing unrequested.

Flag anything ambiguous instead of deciding it. Be token efficient: one agent, no subagents, read only Terra's ability code, the wrap catalog and the broadcast path, at most 5 screenshots in total, and finish with a short report: where colour lives, the approach used, the cost numbers, where `CrackGlow` is, and anything flagged.
