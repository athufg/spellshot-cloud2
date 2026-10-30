<role>
You are migrating Terra's wrap system onto SPELLSHOT's rarity-ladder pattern and building its three missing wraps, directly in the owner's live Roblox Studio place, through Studio's own MCP connection (Assistant → ... → Manage MCP Servers → "Enable Studio as MCP server" must be on; if it isn't, stop and ask the owner to turn it on rather than editing files blind). You work for the game's solo owner-developer. Cryo, Toxin, Umbra and Aqua already have finished five-wrap ladders (Uncommon ×2, Rare, Epic, Mythic) — your structural reference, don't touch them. Terra has exactly one wrap today, Obsidian Magma, still wired through the project's older per-ability `SkinCatalog.Offer` system rather than the newer `ElementWraps`/`ElementWrap_<Element>` rarity-ladder pattern. Done means: Terra migrated onto that ladder pattern, Obsidian Magma confirmed still working under it, the three missing wraps built to the locked roster below, each checkpointed against Default with real screenshots, and nothing wired live/selectable until the owner reviews.
</role>

<context>
**Check for a project skill first.** This project has used Claude-Code-only skills before for exactly this kind of sorting work (this session's own equivalent is called `spellshot-skin-tiers`, for full Element skins). List whatever skills are available to you and look for a wrap-tier equivalent — it may be named something like `spellshot-wrap-tiers`, but don't assume the exact name; search before concluding it doesn't exist. If found, follow its tier/texture conventions ahead of the table below where the two differ, and flag the difference. If none exists, use this prompt's table as the source of truth.

**The locked roster — already designed and approved by the owner.** Build exactly these; propose refinements to exact numbers at checkpoint, not to the concept, name or texture call. Obsidian Magma (Uncommon, already built) stays untouched except for the one flagged fix below.

| Wrap | Tier | Texture change? | Look |
|---|---|---|---|
| Sandstone | Uncommon | No — recolor only, deliberately plain | Warm desert-tan rock, flat and matte — the plain counterpart to Magma's drama |
| Rusted Iron Ore | Rare | Yes — add rust veining/streaking | Dull grey-brown stone streaked with oxidized rust-orange veins and a few raw metallic highlight facets |
| Amethyst Geode | Epic | Yes — add crystal facet clusters with real internal glow | Violet crystal bursting through the rock shell |
| Meteorite Core | Mythic | Yes — add starmetal veining | Dark iron-nickel exterior, glowing blue-white veins — a crashed-star theme, distinct from Magma's lava |

**Tier escalation matters.** Across every finished ladder on this project, Epic adds a real luminous core and richer particle/glint layer over Rare, and Mythic adds something Epic doesn't have at all. Amethyst Geode needs a genuine step up from Rusted Iron Ore, not just another texture; Meteorite Core needs to clearly outclass Amethyst Geode, not restate it in new colours. Meteorite Core especially should make someone stop and look.

**Identity colours — check every new wrap against these, so nothing drifts back onto an Element's own Default look (a real near-miss already caught on a different Element this project):**
| Element | Base | Light | Dark |
|---|---|---|---|
| Pyro | #F25C0D | #FFC74D | #6B1708 |
| Terra | #826B24 | #CCBA5C | #33210D |
| Radiant | #F5C230 | #FFF7D6 | #70520A |
| Voltaic | #F5C70F | #FFF573 | #4A1A8C |
| Zephyr | #4FD1C5 | #FFFFFF | #125C59 |

Obsidian Magma's rock/crack/rim colours already sit safely off Terra's own tan/gold identity. Keep the three new wraps similarly distinct from Terra's own Base/Light/Dark.

**Respect the game's Graphics Quality setting.** The Settings menu exposes `GraphicsQuality` (LOW/MEDIUM/HIGH/ULTRA), which `SettingsRuntime.client.lua` turns into one scalar, `SpellshotSettings.EffectDensity` (LOW 0.45, MEDIUM 0.75, HIGH 1.00 — the default, ULTRA 1.15), that other wrap modules (`CryoWrap.lua`, `AquaWrap.lua`) and Pyro's and Radiant's own base draw files already read the moment an emitter is built — not Roblox's own quality slider, which this game's menu never touches. `TerraWrap.lua` does **not** currently read this scalar at all, so Obsidian Magma's effects render at one fixed density regardless of the setting — a real, pre-existing gap, and not something this prompt is asking you to fix on Magma itself (leave Magma's rendering alone beyond the HitFlash note below). But the three new textured wraps (Rusted Iron Ore's veining, Amethyst Geode's crystal clusters, Meteorite Core's starmetal veining) are exactly the kind of added-particle work that should scale by it from the start — wire their new effect layers to `SpellshotSettings.EffectDensity` (read via `require(ReplicatedStorage.Spellshot.SpellshotSettings).EffectDensity`, the pattern `CryoWrap.lua`'s `solidOn` function uses) rather than copying Magma's density-blind approach forward.

**A small, optional fix while you're already in `TerraWrap.lua`.** Obsidian Magma's impact flash (`HitFlash`) is currently set to Terra's own stock Light colour (#CCBA5C), not a Magma-specific one, so the one moment that should read as "different material" still flashes plain Default Terra gold. Fix it to something that matches Magma's own palette (a warm ember tone fits what's already there) if it's trivial alongside the rest of this work; otherwise just flag it rather than spending real time on it — it's not core to this prompt's scope.

**Migrating off the old system.** Terra is currently wired through `SkinCatalog.Offer.Terra` (a flat list per ability: BoulderShot, BulwarkCharge, Bedrock, Aftershock, BulwarkWall, EarthenTomb — confirm the live keys, don't assume this list is current), not the `ElementWraps`/`ElementWrap_<Element>` pattern Cryo/Toxin/Umbra/Aqua use. Bring Terra onto that same pattern: `Rarity` and `Wrap` fields on each `SkinCatalog.Skins` entry, chosen via one `ElementWrap_Terra` player attribute rather than per-ability `Skin_<ability>` attributes, with the Studio-only `WrapStudio` preview pattern already established for Umbra/Cryo/Toxin. Read how that migration was actually done for Umbra (its own code comments note the date and reasoning) before replicating it. Note from the project's own comments: Obsidian Magma's big kits (Aftershock, Bulwark Wall, Earthen Tomb) use baked-mesh `MeshPart.Color` tints rather than the standard palette path, since those kits are too many baked meshes to remake per client — confirm this special-case path survives the migration rather than silently simplifying it away.
</context>

<instructions>
1. Check for the project skill (above) first.
2. Read the live `SkinCatalog.lua`, `SpellshotConfig.lua` and `TerraWrap.lua` to confirm current state before changing anything.
3. Migrate Terra onto the `ElementWraps`/`ElementWrap_Terra` pattern. Confirm Obsidian Magma still renders correctly under the new system — including its baked-mesh tint path for Aftershock/Bulwark Wall/Earthen Tomb — before building anything else.
4. Build Sandstone, Rusted Iron Ore, Amethyst Geode and Meteorite Core to the roster table's texture-change call. Leave every ability's timing, damage, range and hitbox values untouched — wraps are colour and surface only. Scale the three textured wraps' added effect layers by `SpellshotSettings.EffectDensity`, even though Magma itself doesn't currently do this.
5. If trivial, fix Obsidian Magma's `HitFlash`; otherwise flag it.
6. Checkpoint: screenshot every new wrap against Default, same ability, same angle, in both cast/hold and break/impact states — a single static frame can't fairly show Terra's crack-glow or crystal effects fairly. Confirm Obsidian Magma still works post-migration in the same sheet.
7. Don't add Terra's new wraps to the live `ElementWraps`/offer list as selectable, and don't call the ladder final, until the owner reviews.
8. Report an upfront scope/time estimate before your first Studio push.
</instructions>

<output_format>
- The upfront scope/estimate message, before any Studio push.
- One line before you start.
- Default-vs-wrap screenshot pairs for all four wraps (Sandstone, Rusted Iron Ore, Amethyst Geode, Meteorite Core), covering hold/cast and break/impact, plus Obsidian Magma's post-migration confirmation.
- A short report: which wraps landed as designed, the identity-colour check for each, whether the `HitFlash` fix was made or flagged, and anything that needed a judgment call against the roster table.
</output_format>

<edge_cases>
- If migrating breaks Obsidian Magma's baked-mesh tint path for its big kits, stop and report rather than pushing forward with a broken Uncommon tier.
- If a "No — recolor only" wrap starts looking flat once built, don't quietly add texture — flag it at checkpoint instead; the plain/textured split across tiers is deliberate.
- If any new wrap's built look drifts close to Terra's own identity colour or another Element's, flag it with the specific hex comparison rather than deciding unilaterally.
</edge_cases>

<tone_preference>
Keep the checkpoint report plain and factual — what was built, the evidence, what's flagged.
</tone_preference>
