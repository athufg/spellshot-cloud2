<role>
You are building Voltaic's first wrap ladder — it currently has none at all — directly in the owner's live Roblox Studio place, through Studio's own MCP connection (Assistant → ... → Manage MCP Servers → "Enable Studio as MCP server" must be on; if it isn't, stop and ask the owner to turn it on rather than editing files blind). You work for the game's solo owner-developer. Cryo, Toxin, Umbra and Aqua already have finished five-wrap ladders (Uncommon ×2, Rare, Epic, Mythic) — your structural reference. There's no old per-ability system to migrate here: Voltaic goes straight onto the `ElementWraps`/`ElementWrap_Voltaic` pattern from scratch. Done means: the full five-wrap ladder built to the locked roster below, checkpointed against Default with real screenshots, and nothing wired live/selectable until the owner reviews.
</role>

<context>
**Check for a project skill first.** This project has used Claude-Code-only skills before for exactly this kind of sorting work (this session's own equivalent is called `spellshot-skin-tiers`, for full Element skins). List whatever skills are available to you and look for a wrap-tier equivalent — it may be named something like `spellshot-wrap-tiers`, but don't assume the exact name; search before concluding it doesn't exist. If found, follow its tier/texture conventions ahead of the table below where the two differ, and flag the difference. If none exists, use this prompt's table as the source of truth.

**The locked roster — already designed and approved by the owner.** Build exactly these; propose refinements to exact numbers at checkpoint, not to the concept, name or texture call.

| Wrap | Tier | Texture change? | Look |
|---|---|---|---|
| Crimson Arc | Uncommon | No — recolor only | Simple red-toned electricity, flat recolor of the base bolts |
| Copper Current | Uncommon | No — recolor only | Warm amber-copper electricity |
| Plasma Storm | Rare | Yes — add crackle/branching detail | Intensified teal-cyan arcs with extra branching beyond Default's bolt |
| Thunderhead | Epic | Yes — add a storm-cloud atmosphere layer | Bolts dancing through a dark storm-cloud around the caster, not just a brighter bolt |
| Fusion Core | Mythic | Yes — molten surface treatment | Molten white-gold electricity, reads as a supercharged reactor core |

**Confirmed baseline to build away from** (from a live visual audit of Default, so this is real, not guessed): Voltaic's Default reads as a white-hot electric core with pale-yellow glow and a yellow ground light, bursting violet-blue on impact. Every new wrap needs to clearly leave that white-yellow-violet combination behind, not just shift its brightness.

**Tier escalation matters.** Across every finished ladder on this project, Epic adds a real luminous core and richer particle/glint layer over Rare, and Mythic adds something Epic doesn't have at all. Thunderhead needs a genuine step up from Plasma Storm — the storm-cloud atmosphere, not just more arcs — and Fusion Core needs to clearly outclass Thunderhead, not restate it in a new colour. Fusion Core especially should make someone stop and look.

**Identity colours — check every new wrap against these, so nothing drifts onto Voltaic's own Default look, or onto a neighboring Element's.** One real risk already flagged: Voltaic's own Base (#F5C70F) sits almost on top of Radiant's (#F5C230), with both Lights the same pale yellow-white.
| Element | Base | Light | Dark |
|---|---|---|---|
| Pyro | #F25C0D | #FFC74D | #6B1708 |
| Terra | #826B24 | #CCBA5C | #33210D |
| Radiant | #F5C230 | #FFF7D6 | #70520A |
| Voltaic | #F5C70F | #FFF573 | #4A1A8C |
| Zephyr | #4FD1C5 | #FFFFFF | #125C59 |

Keep Crimson Arc, Copper Current and Plasma Storm clearly off that shared yellow. Watch Fusion Core especially — "molten white-gold" could easily drift onto that same shared colour once actually built; if it's trending that way, pull it toward a hue that isn't Voltaic's or Radiant's own, and flag the call rather than shipping it as-is.

**Respect the game's Graphics Quality setting.** The Settings menu exposes `GraphicsQuality` (LOW/MEDIUM/HIGH/ULTRA), which `SettingsRuntime.client.lua` turns into one scalar, `SpellshotSettings.EffectDensity` (LOW 0.45, MEDIUM 0.75, HIGH 1.00 — the default, ULTRA 1.15), read the moment an emitter is built — not Roblox's own quality slider, which this game's menu never touches. `VoltaicFX.lua` already reads this scalar for Volt Orb's own draw path, but `ChainBoltFX.lua` does not — a real, pre-existing inconsistency between the two, not something this prompt asks you to fix on Chain Bolt's base FX. For the new wraps, follow the pattern that's already there rather than the gap: scale Plasma Storm's branching detail, Thunderhead's storm-cloud layer and Fusion Core's molten treatment by `SpellshotSettings.EffectDensity` (read via `require(ReplicatedStorage.Spellshot.SpellshotSettings).EffectDensity`, the pull pattern `CryoWrap.lua`'s `solidOn` function uses), fuller on ULTRA and thinner on LOW/MEDIUM.

**Building from scratch — the pattern to follow.** Read exactly how Umbra's `ElementWraps`/`ElementWrap_Umbra` system is wired (its own code comments note the date and reasoning for the whole pattern) and replicate that shape for `ElementWrap_Voltaic`: `Rarity`/`Wrap` fields on each `SkinCatalog.Skins` entry, one Element-wide player attribute rather than per-ability attributes, the Studio-only `WrapStudio` preview pattern. Find or create Voltaic's equivalent of a dedicated wrap-drawing module (`VoltaicWrap.lua`) following `CryoWrap.lua`'s or `ToxinWrap.lua`'s structure, rather than inventing a new shape.
</context>

<instructions>
1. Check for the project skill (above) first.
2. Read the live `SkinCatalog.lua`, `SpellshotConfig.lua`, `VoltaicFX.lua`, `VoltOrbFX.lua` and `ChainBoltFX.lua` to understand Voltaic's current draw paths before building anything.
3. Build the `ElementWraps`/`ElementWrap_Voltaic` system fresh, following Umbra's pattern.
4. Build all five wraps to the roster table's texture-change call — a "No" wrap should be a genuine flat recolor, a "Yes" wrap needs the specific added effect named. Leave every ability's timing, damage, range and hitbox values untouched — wraps are colour and surface only. Scale the three textured wraps' added effect layers by `SpellshotSettings.EffectDensity`.
5. Checkpoint: screenshot every wrap against Default, same ability, same angle, in both cast and impact/active states — a single static frame can't fairly show arcing electricity. Cover Chain Bolt and Volt Orb at minimum.
6. Don't add any wrap to a live/selectable offer list, and don't call the ladder final, until the owner reviews.
7. Report an upfront scope/time estimate before your first Studio push — five wraps and a new system built from nothing, so ground the estimate against how long a finished ladder (Cryo's or Toxin's) took if that's recorded anywhere.
</instructions>

<output_format>
- The upfront scope/estimate message, before any Studio push.
- One line before you start.
- Default-vs-wrap screenshot pairs for all five wraps, covering cast and impact.
- A short report: which wraps landed as designed, the identity-colour check for each (explicit on the Voltaic/Radiant yellow-white overlap), and anything that needed a judgment call against the roster table.
</output_format>

<edge_cases>
- If Chain Bolt's hitscan nature makes it hard to capture a clean cast frame, say so and lean on Volt Orb's coverage instead rather than skipping the cast state entirely.
- If a "No — recolor only" wrap starts looking flat once built, don't quietly add texture — flag it at checkpoint instead; the plain/textured split across tiers is deliberate.
- If any new wrap's built look drifts close to Voltaic's own identity colour or Radiant's, flag it with the specific hex comparison rather than deciding unilaterally.
</edge_cases>

<tone_preference>
Keep the checkpoint report plain and factual — what was built, the evidence, what's flagged.
</tone_preference>
