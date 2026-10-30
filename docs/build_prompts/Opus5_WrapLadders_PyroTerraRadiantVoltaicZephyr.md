<role>
You are building every missing wrap in SPELLSHOT's five incomplete wrap ladders — Pyro, Terra, Radiant, Voltaic and Zephyr — directly in the owner's live Roblox Studio place, through Studio's own MCP connection (Assistant → ... → Manage MCP Servers → "Enable Studio as MCP server" must be on; if it isn't, stop and ask the owner to turn it on rather than editing files blind). You work for the game's solo owner-developer. Cryo, Toxin, Umbra and Aqua are already finished five-wrap ladders (Uncommon ×2, Rare, Epic, Mythic) and are your structural reference — don't touch them. Pyro, Terra and Radiant each have exactly one wrap built today, still wired through the project's older per-ability `SkinCatalog.Offer` system; Voltaic and Zephyr have none at all. Done, for this prompt, means: all five Elements brought onto the same rarity-ladder pattern Cryo/Toxin/Umbra/Aqua already use, every wrap in the locked roster below built, each checkpointed against Default (and, for Pyro/Terra/Radiant, against the one already-built wrap) with real screenshots, and nothing wired live/selectable until the owner reviews — this is a human-in-the-loop build across a lot of ground, so checkpoint by Element rather than going silent for the whole pass.
</role>

<context>
**First, check for a project skill before designing anything.** This project has used Claude-Code-only skills before for exactly this kind of sorting work (this session's own equivalent is called `spellshot-skin-tiers`, for full Element skins rather than wraps). List whatever skills are available to you and look for a wrap-tier equivalent — it may be named something like `spellshot-wrap-tiers` or similar, but don't assume the exact name; search for it before concluding it doesn't exist. If you find it, read it and follow its tier/texture conventions ahead of the table below where the two differ, flagging the difference. If no such skill exists in your environment, proceed on the table below, which was built from a live visual audit of this project's actual wraps and Elements, not guessed.

**The locked roster — 22 wraps across 5 Elements, already designed and approved by the owner.** Build exactly these; propose refinements to exact numbers at each Element's checkpoint, not to the concept, name or texture call.

*Pyro* (Azure Flame already built, Uncommon — leave it untouched):
| Wrap | Tier | Texture change? | Look |
|---|---|---|---|
| Ashfire | Uncommon | No — recolor only | Smoldering grey-charcoal flame, dull red embers, same shapes/particle count as Default |
| Solar Flare | Rare | No — recolor/intensity only | White-gold superheated fire, brighter and hotter-reading than Default |
| Phoenix | Epic | Yes — add ember-feather particle shapes | Gold-to-crimson gradient flame with drifting feather-shaped embers, not present in Default |
| Void Flame | Mythic | No — recolor only, but push it dramatically | Black fire with a deep violet-indigo core (never magenta) — reads as forbidden/cursed, not just hotter |

*Terra* (Obsidian Magma already built, Uncommon — leave it untouched, but see the flagged fix below):
| Wrap | Tier | Texture change? | Look |
|---|---|---|---|
| Sandstone | Uncommon | No — recolor only, deliberately plain | Warm desert-tan rock, flat and matte — the plain counterpart to Magma's drama |
| Rusted Iron Ore | Rare | Yes — add rust veining/streaking | Dull grey-brown stone streaked with oxidized rust-orange veins and a few raw metallic highlight facets |
| Amethyst Geode | Epic | Yes — add crystal facet clusters with real internal glow | Violet crystal bursting through the rock shell |
| Meteorite Core | Mythic | Yes — add starmetal veining | Dark iron-nickel exterior, glowing blue-white veins — a crashed-star theme, distinct from Magma's lava |

*Radiant* (Rainbow already built, Uncommon, confirmed working but tuned very faint — leave its logic alone, that's the owner's call to retune separately):
| Wrap | Tier | Texture change? | Look |
|---|---|---|---|
| Moonlight | Uncommon | No — recolor only | Pale silver and cool blue-white, simple flat palette |
| Stained Glass | Rare | Yes — add segmented panel facets | Jewel-toned colour panels across the light forms, not a flat wash |
| Starlight | Epic | Yes — add pinpoint star detail | Deep indigo-navy night sky with glowing white pinpoint stars — a cool departure from Default's warm white-gold, not a brighter version of it |
| Prism Bloom | Mythic | Yes — animated colour-shift, not a static texture | Iridescent opal effect, slowly cycling cool blues/pinks/greens rather than sitting on one fixed hue |

*Voltaic* (nothing built — this Element goes straight onto the new ladder system, no migration needed):
| Wrap | Tier | Texture change? | Look |
|---|---|---|---|
| Crimson Arc | Uncommon | No — recolor only | Simple red-toned electricity, flat recolor of the base bolts |
| Copper Current | Uncommon | No — recolor only | Warm amber-copper electricity |
| Plasma Storm | Rare | Yes — add crackle/branching detail | Intensified teal-cyan arcs with extra branching beyond Default's bolt |
| Thunderhead | Epic | Yes — add a storm-cloud atmosphere layer | Bolts dancing through a dark storm-cloud around the caster, not just a brighter bolt |
| Fusion Core | Mythic | Yes — molten surface treatment | Molten white-gold electricity, reads as a supercharged reactor core |

*Zephyr* (nothing built — straight onto the new ladder system, no migration needed):
| Wrap | Tier | Texture change? | Look |
|---|---|---|---|
| Dustwind | Uncommon | No — recolor only | Tan desert-wind recolor, simple and flat |
| Mistral | Uncommon | No — recolor only | Pale cool-blue wind |
| Autumn Gale | Rare | Yes — add leaf particle shapes | Orange-red wind with drifting leaf-sweep particles |
| Monsoon | Epic | Yes — add rain-streak ribbon density | Deep teal storm wind, denser and more layered than Default's thin ribbons |
| Jetstream | Mythic | Yes — add light-trail streaking | Silver-white supersonic wind with streaking light trails, leaning into Zephyr's own motion-line shape language |

**Tier escalation is the whole point — don't let Epic and Mythic read as "Rare but recolored again."** Across every already-finished ladder on this project (Cryo, Toxin, Umbra, Aqua), Epic adds a real luminous core and a richer particle/glint layer over Rare, and Mythic adds something Epic doesn't have at all — an animated or signature behavior (Umbra's Mythic flows and twinkles over time; Toxin's Mythic shifts with game state). Match that budget curve here: Phoenix, Amethyst Geode, Starlight and Thunderhead (the four Epics) each need a genuine luminous/glint treatment beyond their Rare neighbor, and Void Flame, Meteorite Core, Prism Bloom and Fusion Core (the four Mythics) each need to clearly outclass their own Epic, not just restate it in a new colour. These four Mythics are the ones that should make someone stop and look.

**Identity colours — check every new wrap against these, so nothing reads as "secretly just Default again" the way an earlier Radiant proposal almost did:**
| Element | Base | Light | Dark |
|---|---|---|---|
| Pyro | #F25C0D | #FFC74D | #6B1708 |
| Terra | #826B24 | #CCBA5C | #33210D |
| Radiant | #F5C230 | #FFF7D6 | #70520A |
| Voltaic | #F5C70F | #FFF573 | #4A1A8C |
| Zephyr | #4FD1C5 | #FFFFFF | #125C59 |

One real risk already flagged: Voltaic's Base (#F5C70F) sits almost on top of Radiant's (#F5C230), with both Lights the same pale yellow-white. Keep Crimson Arc, Copper Current and Plasma Storm clearly off that shared yellow — and double-check Fusion Core doesn't drift back onto it once its "molten white-gold" look is actually built; if it's trending that way, pull it toward a hue that isn't Radiant's own, and flag the call.

**A small, optional fix while you're already in `TerraWrap.lua`:** Obsidian Magma's impact flash (`HitFlash`) is currently set to Terra's own stock Light colour (#CCBA5C), not a Magma-specific one, so the one moment that should read as "different material" still flashes plain Default Terra gold. Fix it to something that matches Magma's own palette (a warm ember tone fits what's already there) if it's a trivial change alongside the rest of this work; otherwise just flag it rather than spending real time on it — it's not part of this prompt's core scope.

**Migrating Pyro, Terra and Radiant off the old system.** These three are still wired through `SkinCatalog.Offer` (a flat per-ability list, no rarity tiers) rather than the `ElementWraps`/`ElementWrap_<Element>` rarity-ladder pattern Cryo, Toxin, Umbra and Aqua use. Bring all three onto that same pattern: `Rarity` and `Wrap` fields on each `SkinCatalog.Skins` entry (matching the shape already on Azure Flame, Obsidian Magma and Rainbow's siblings in the finished ladders), chosen via one `ElementWrap_<Element>` player attribute rather than per-ability `Skin_<ability>` attributes, with the Studio-only `WrapStudio` preview pattern Umbra/Cryo/Toxin already use. Read how that migration was actually done for Umbra (its own comments note the exact date and reasoning) before replicating it, rather than inventing a new shape.
</context>

<instructions>
1. Look for a project wrap-tier skill first (see above). Follow it if found; otherwise use this prompt's table and identity-color check as the source of truth.
2. Read the live `SkinCatalog.lua`, `SpellshotConfig.lua`, and each Element's existing wrap file (`PyroWrap`/whatever Pyro's wrap logic currently lives under, `TerraWrap.lua`, the Radiant equivalent) to confirm current state before changing anything — Pyro and Radiant may not have dedicated Wrap modules the way Terra does; find out rather than assuming one exists.
3. Work one Element at a time, in this order: Pyro, Terra, Radiant, Voltaic, Zephyr. For Pyro/Terra/Radiant, migrate that Element onto the `ElementWraps`/`ElementWrap_<Element>` pattern first (per the migration note above), confirm the already-built wrap still works correctly under the new system, then build that Element's remaining wraps from the roster table. For Voltaic/Zephyr, build the ladder system and all five wraps fresh.
4. Build each wrap's `Palette` block to the texture-change call in the roster table — a "No" wrap should be a genuine flat recolor, not secretly textured, and a "Yes" wrap needs the specific added pattern/effect named, not just a different hue. Keep every ability's timing, damage, range and hitbox values untouched — wraps are colour and surface only, the same standing rule as every wrap already shipped on this project.
5. Checkpoint each Element before moving to the next: screenshot every new wrap in that Element against Default, same ability, same angle, in both a resting/cast state and an impact/motion state — a single static frame can't fairly show an animated or textured effect, a lesson this project has paid for before. For Pyro/Terra/Radiant, also confirm the already-built wrap still renders correctly after the system migration.
6. Don't add any Element to its live `ElementWraps`/offer list as selectable, and don't call any ladder final, until the owner has reviewed each Element's checkpoint — match this project's own standing precedent (every wrap built so far stays staged, commented out of the live list, until approved).
7. Report an upfront scope/time estimate before your first Studio push — this is 22 wraps plus a system migration across three Elements, the largest wrap pass on the project yet, so ground the estimate against how long Cryo's or Toxin's five-wrap ladders took if that's recorded anywhere (dev diary, prior checkpoint reports), and say plainly it's an estimate.
</instructions>

<output_format>
- The upfront scope/estimate message, before any Studio push.
- One line before starting each Element's work, so progress is traceable across a long pass.
- Each Element's checkpoint: Default-vs-wrap screenshot pairs for every new wrap in that Element, covering both resting/cast and impact/motion states, plus a short report — which wraps landed as designed, the identity-colour check result for each, confirmation the already-built wrap (where applicable) still works post-migration, and anything that needed a judgment call against the roster table.
- A final short summary once all five Elements are checkpointed: total wraps built, the Obsidian Magma flash fix (done or flagged), and anything held back because it needed the owner's decision rather than yours.
</output_format>

<edge_cases>
- If Pyro or Radiant has no dedicated wrap module and its wrap logic lives inline somewhere else, say what you found and propose the closest-fitting structure rather than guessing a module layout.
- If migrating Pyro/Terra/Radiant breaks the already-built wrap's rendering, stop and report rather than pushing forward with a broken Uncommon tier.
- If a "No — recolor only" wrap starts looking flat or boring once actually built, don't quietly add texture to fix that — flag it at that Element's checkpoint instead, since the plain/textured split across tiers is a deliberate escalation structure, not a quality judgment on the simpler ones.
- If any wrap's built look drifts close to its own Element's identity colour, or another Element's, flag it with the specific hex comparison rather than deciding unilaterally to change the design.
</edge_cases>

<tone_preference>
Keep each checkpoint's report plain and factual — what was built, the evidence, what's flagged. This is a long pass; don't pad it with narrative beyond what's needed to track real progress.
</tone_preference>
