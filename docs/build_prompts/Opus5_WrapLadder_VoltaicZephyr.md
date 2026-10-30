<role>
You are building the first wrap ladders for two Elements that currently have none at all — Voltaic and Zephyr — directly in the owner's live Roblox Studio place, through Studio's own MCP connection (Assistant → ... → Manage MCP Servers → "Enable Studio as MCP server" must be on; if it isn't, stop and ask the owner to turn it on rather than editing files blind). You work for the game's solo owner-developer. Cryo, Toxin, Umbra and Aqua already have finished five-wrap ladders (Uncommon ×2, Rare, Epic, Mythic) — your structural reference. Unlike Pyro/Terra/Radiant, there's no old per-ability system to migrate here: both Elements go straight onto the `ElementWraps`/`ElementWrap_<Element>` pattern from scratch. Done means: both five-wrap ladders built to the locked roster below, each checkpointed against Default with real screenshots, and nothing wired live/selectable until the owner reviews.
</role>

<context>
**Check for a project skill first.** This project has used Claude-Code-only skills before for exactly this kind of sorting work (this session's own equivalent is called `spellshot-skin-tiers`, for full Element skins). List whatever skills are available to you and look for a wrap-tier equivalent — it may be named something like `spellshot-wrap-tiers`, but don't assume the exact name; search before concluding it doesn't exist. If found, follow its tier/texture conventions ahead of the table below where the two differ, and flag the difference. If none exists, use this prompt's table as the source of truth.

**The locked roster — already designed and approved by the owner.** Build exactly these; propose refinements to exact numbers at checkpoint, not to the concept, name or texture call.

*Voltaic:*
| Wrap | Tier | Texture change? | Look |
|---|---|---|---|
| Crimson Arc | Uncommon | No — recolor only | Simple red-toned electricity, flat recolor of the base bolts |
| Copper Current | Uncommon | No — recolor only | Warm amber-copper electricity |
| Plasma Storm | Rare | Yes — add crackle/branching detail | Intensified teal-cyan arcs with extra branching beyond Default's bolt |
| Thunderhead | Epic | Yes — add a storm-cloud atmosphere layer | Bolts dancing through a dark storm-cloud around the caster, not just a brighter bolt |
| Fusion Core | Mythic | Yes — molten surface treatment | Molten white-gold electricity, reads as a supercharged reactor core |

*Zephyr:*
| Wrap | Tier | Texture change? | Look |
|---|---|---|---|
| Dustwind | Uncommon | No — recolor only | Tan desert-wind recolor, simple and flat |
| Mistral | Uncommon | No — recolor only | Pale cool-blue wind |
| Autumn Gale | Rare | Yes — add leaf particle shapes | Orange-red wind with drifting leaf-sweep particles |
| Monsoon | Epic | Yes — add rain-streak ribbon density | Deep teal storm wind, denser and more layered than Default's thin ribbons |
| Jetstream | Mythic | Yes — add light-trail streaking | Silver-white supersonic wind with streaking light trails, leaning into Zephyr's own motion-line shape language |

**Confirmed baselines to build away from** (from a live visual audit of Default, so these are real, not guessed): Voltaic's Default reads as a white-hot electric core with pale-yellow glow and a yellow ground light, bursting violet-blue on impact — every new Voltaic wrap needs to clearly leave that white-yellow-violet combination behind, not just shift its brightness. Zephyr's Default is deliberately thin and understated — translucent cyan-mint ribbons with white glints, Wind Blade nearly invisible at range, Cyclone the one real showpiece — which is exactly why Rare/Epic/Mythic here (Autumn Gale, Monsoon, Jetstream) are specced to add real particle/ribbon density rather than just recolor Default's already-thin look; don't undersell those three the way Default itself is thin.

**Tier escalation matters.** Across every finished ladder on this project, Epic adds a real luminous core and richer particle/glint layer over Rare, and Mythic adds something Epic doesn't have at all. For Voltaic: Thunderhead needs a genuine step up from Plasma Storm (the storm-cloud atmosphere, not just more arcs), and Fusion Core needs to clearly outclass Thunderhead. For Zephyr: Monsoon needs to clearly read richer than Autumn Gale, and Jetstream needs to outclass Monsoon. Fusion Core and Jetstream especially should make someone stop and look.

**Identity colours — check every new wrap against these, so nothing drifts onto an Element's own Default look, or onto a neighboring Element's.** One real risk already flagged: Voltaic's Base (#F5C70F) sits almost on top of Radiant's (#F5C230), with both Lights the same pale yellow-white.
| Element | Base | Light | Dark |
|---|---|---|---|
| Pyro | #F25C0D | #FFC74D | #6B1708 |
| Terra | #826B24 | #CCBA5C | #33210D |
| Radiant | #F5C230 | #FFF7D6 | #70520A |
| Voltaic | #F5C70F | #FFF573 | #4A1A8C |
| Zephyr | #4FD1C5 | #FFFFFF | #125C59 |

Keep Crimson Arc, Copper Current and Plasma Storm clearly off that shared yellow both Voltaic and Radiant sit on. Watch Fusion Core especially — "molten white-gold" could easily drift onto that same shared colour once actually built; if it's trending that way, pull it toward a hue that isn't Voltaic's or Radiant's own, and flag the call rather than shipping it as-is.

**Building from scratch — the pattern to follow.** Read exactly how Umbra's `ElementWraps`/`ElementWrap_Umbra` system is wired (its own code comments note the date and reasoning for the whole pattern) and replicate that shape for both `ElementWrap_Voltaic` and `ElementWrap_Zephyr`: `Rarity`/`Wrap` fields on each `SkinCatalog.Skins` entry, one Element-wide player attribute rather than per-ability attributes, the Studio-only `WrapStudio` preview pattern. Find or create the Voltaic and Zephyr equivalents of a dedicated wrap-drawing module (`VoltaicWrap.lua`, `ZephyrWrap.lua`) following `CryoWrap.lua`'s or `ToxinWrap.lua`'s structure, rather than inventing a new shape.
</context>

<instructions>
1. Check for the project skill (above) first.
2. Read the live `SkinCatalog.lua`, `SpellshotConfig.lua`, `VoltaicFX.lua`/`VoltOrbFX.lua`/`ChainBoltFX.lua` and `ZephyrFX.lua`/`ZephyrFX_WindBlade.lua`/`ZephyrFX_Cyclone.lua` to understand each Element's current draw paths before building anything.
3. Build the `ElementWraps`/`ElementWrap_<Element>` system fresh for both Elements, following Umbra's pattern.
4. Build all five Voltaic wraps and all five Zephyr wraps to each roster table's texture-change call — a "No" wrap should be a genuine flat recolor, a "Yes" wrap needs the specific added effect named. Leave every ability's timing, damage, range and hitbox values untouched — wraps are colour and surface only.
5. Checkpoint each Element separately: screenshot every wrap against Default, same ability, same angle, in both cast and impact/active states — a single static frame can't fairly show arcing electricity or flowing wind fairly. For Voltaic, cover Chain Bolt and Volt Orb at minimum; for Zephyr, cover Wind Blade and Cyclone at minimum.
6. Don't add either Element's wraps to a live/selectable offer list, and don't call either ladder final, until the owner reviews.
7. Report an upfront scope/time estimate before your first Studio push — this is 10 wraps and two new systems built from nothing, so ground the estimate against how long a finished ladder (Cryo's or Toxin's) took if that's recorded anywhere.
</instructions>

<output_format>
- The upfront scope/estimate message, before any Studio push.
- One line before starting each Element.
- Voltaic's checkpoint: Default-vs-wrap pairs for all five wraps, cast and impact.
- Zephyr's checkpoint: Default-vs-wrap pairs for all five wraps, cast and impact.
- A short report per Element: which wraps landed as designed, the identity-colour check for each (explicit on the Voltaic/Radiant yellow-white overlap), and anything that needed a judgment call against the roster table.
</output_format>

<edge_cases>
- If Chain Bolt's hitscan nature makes it hard to capture a clean cast frame, say so and lean on Volt Orb's coverage instead rather than skipping Voltaic's cast state entirely.
- If a "No — recolor only" wrap starts looking flat once built, don't quietly add texture — flag it at checkpoint instead; the plain/textured split across tiers is deliberate.
- If any new wrap's built look drifts close to its own Element's identity colour or a neighboring Element's (Voltaic/Radiant above all), flag it with the specific hex comparison rather than deciding unilaterally.
</edge_cases>

<tone_preference>
Keep each checkpoint's report plain and factual — what was built, the evidence, what's flagged.
</tone_preference>
