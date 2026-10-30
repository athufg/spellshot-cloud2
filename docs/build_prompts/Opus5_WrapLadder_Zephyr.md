<role>
You are building Zephyr's first wrap ladder — it currently has none at all — directly in the owner's live Roblox Studio place, through Studio's own MCP connection (Assistant → ... → Manage MCP Servers → "Enable Studio as MCP server" must be on; if it isn't, stop and ask the owner to turn it on rather than editing files blind). You work for the game's solo owner-developer. Cryo, Toxin, Umbra and Aqua already have finished five-wrap ladders (Uncommon ×2, Rare, Epic, Mythic) — your structural reference. There's no old per-ability system to migrate here: Zephyr goes straight onto the `ElementWraps`/`ElementWrap_Zephyr` pattern from scratch. Done means: the full five-wrap ladder built to the locked roster below, checkpointed against Default with real screenshots, and nothing wired live/selectable until the owner reviews.
</role>

<context>
**Check for a project skill first.** This project has used Claude-Code-only skills before for exactly this kind of sorting work (this session's own equivalent is called `spellshot-skin-tiers`, for full Element skins). List whatever skills are available to you and look for a wrap-tier equivalent — it may be named something like `spellshot-wrap-tiers`, but don't assume the exact name; search before concluding it doesn't exist. If found, follow its tier/texture conventions ahead of the table below where the two differ, and flag the difference. If none exists, use this prompt's table as the source of truth.

**The locked roster — already designed and approved by the owner.** Build exactly these; propose refinements to exact numbers at checkpoint, not to the concept, name or texture call.

| Wrap | Tier | Texture change? | Look |
|---|---|---|---|
| Dustwind | Uncommon | No — recolor only | Tan desert-wind recolor, simple and flat |
| Mistral | Uncommon | No — recolor only | Pale cool-blue wind |
| Autumn Gale | Rare | Yes — add leaf particle shapes | Orange-red wind with drifting leaf-sweep particles |
| Monsoon | Epic | Yes — add rain-streak ribbon density | Deep teal storm wind, denser and more layered than Default's thin ribbons |
| Jetstream | Mythic | Yes — add light-trail streaking | Silver-white supersonic wind with streaking light trails, leaning into Zephyr's own motion-line shape language |

**Confirmed baseline to build away from** (from a live visual audit of Default, so this is real, not guessed): Zephyr's Default is deliberately thin and understated — translucent cyan-mint ribbons with white glints, Wind Blade nearly invisible at range, Cyclone the one real showpiece. That's exactly why Rare/Epic/Mythic here (Autumn Gale, Monsoon, Jetstream) are specced to add real particle/ribbon density rather than just recolor Default's already-thin look — don't undersell those three the way Default itself is thin. Dustwind and Mistral, being pure recolors, can stay as thin as Default; it's specifically the textured tiers that need to visibly earn their density.

**Tier escalation matters.** Across every finished ladder on this project, Epic adds a real luminous core and richer particle/glint layer over Rare, and Mythic adds something Epic doesn't have at all. Monsoon needs to clearly read richer than Autumn Gale, not just a darker hue; Jetstream needs to outclass Monsoon, not restate it in silver. Jetstream especially should make someone stop and look.

**Identity colours — check every new wrap against these, so nothing drifts onto Zephyr's own Default look, or onto a neighboring Element's.** No specific collision risk has been flagged for Zephyr the way Voltaic/Radiant's shared yellow-white was, but check anyway as each wrap comes together rather than assuming it's safe by default.
| Element | Base | Light | Dark |
|---|---|---|---|
| Pyro | #F25C0D | #FFC74D | #6B1708 |
| Terra | #826B24 | #CCBA5C | #33210D |
| Radiant | #F5C230 | #FFF7D6 | #70520A |
| Voltaic | #F5C70F | #FFF573 | #4A1A8C |
| Zephyr | #4FD1C5 | #FFFFFF | #125C59 |

Keep an eye on Mistral especially — "pale cool-blue" sits close to Zephyr's own cyan-mint identity, so make sure it reads as a distinct recolor rather than a washed-out Default. If any wrap trends back onto Zephyr's own Base/Light/Dark once actually built, flag it rather than shipping it as-is.

**Respect the game's Graphics Quality setting.** The Settings menu exposes `GraphicsQuality` (LOW/MEDIUM/HIGH/ULTRA), which `SettingsRuntime.client.lua` turns into one scalar, `SpellshotSettings.EffectDensity` (LOW 0.45, MEDIUM 0.75, HIGH 1.00 — the default, ULTRA 1.15), read the moment an emitter is built — not Roblox's own quality slider, which this game's menu never touches. `ZephyrFX.lua` does **not** currently read this scalar (confirm whether `ZephyrFX_WindBlade.lua` and `ZephyrFX_Cyclone.lua` do either rather than assuming) — a real, pre-existing gap, and not something this prompt asks you to fix on Zephyr's base FX. But the three new textured wraps are exactly the kind of added-particle work this scalar exists for: Autumn Gale's leaf particles, Monsoon's rain-streak density and Jetstream's light-trail streaking should all scale by it (read via `require(ReplicatedStorage.Spellshot.SpellshotSettings).EffectDensity`, the pull pattern `CryoWrap.lua`'s `solidOn` function uses) — fewer/thinner on LOW/MEDIUM, fuller on ULTRA — rather than rendering at one fixed density the way Zephyr's current FX does.

**Building from scratch — the pattern to follow.** Read exactly how Umbra's `ElementWraps`/`ElementWrap_Umbra` system is wired (its own code comments note the date and reasoning for the whole pattern) and replicate that shape for `ElementWrap_Zephyr`: `Rarity`/`Wrap` fields on each `SkinCatalog.Skins` entry, one Element-wide player attribute rather than per-ability attributes, the Studio-only `WrapStudio` preview pattern. Find or create Zephyr's equivalent of a dedicated wrap-drawing module (`ZephyrWrap.lua`) following `CryoWrap.lua`'s or `ToxinWrap.lua`'s structure, rather than inventing a new shape.
</context>

<instructions>
1. Check for the project skill (above) first.
2. Read the live `SkinCatalog.lua`, `SpellshotConfig.lua`, `ZephyrFX.lua`, `ZephyrFX_WindBlade.lua` and `ZephyrFX_Cyclone.lua` to understand Zephyr's current draw paths before building anything.
3. Build the `ElementWraps`/`ElementWrap_Zephyr` system fresh, following Umbra's pattern.
4. Build all five wraps to the roster table's texture-change call — a "No" wrap should be a genuine flat recolor, a "Yes" wrap needs the specific added effect named, not just a different hue. Leave every ability's timing, damage, range and hitbox values untouched — wraps are colour and surface only. Scale the three textured wraps' added effect layers by `SpellshotSettings.EffectDensity`, even though Zephyr's base FX doesn't currently do this.
5. Checkpoint: screenshot every wrap against Default, same ability, same angle, in both cast and active/impact states — a single static frame can't fairly show flowing wind or ribbon density. Cover Wind Blade and Cyclone at minimum.
6. Don't add any wrap to a live/selectable offer list, and don't call the ladder final, until the owner reviews.
7. Report an upfront scope/time estimate before your first Studio push — five wraps and a new system built from nothing, so ground the estimate against how long a finished ladder (Cryo's or Toxin's) took if that's recorded anywhere.
</instructions>

<output_format>
- The upfront scope/estimate message, before any Studio push.
- One line before you start.
- Default-vs-wrap screenshot pairs for all five wraps, covering cast and active/impact.
- A short report: which wraps landed as designed, the identity-colour check for each (explicit on Mistral vs. Zephyr's own cyan-mint), and anything that needed a judgment call against the roster table.
</output_format>

<edge_cases>
- If Wind Blade is too thin or fast to capture a clean cast frame even on the wrapped versions, say so and lean on Cyclone's coverage instead rather than skipping the cast state entirely.
- If a "No — recolor only" wrap starts looking flat once built, don't quietly add texture — flag it at checkpoint instead; the plain/textured split across tiers is deliberate.
- If any new wrap's built look drifts close to Zephyr's own identity colour or another Element's, flag it with the specific hex comparison rather than deciding unilaterally.
</edge_cases>

<tone_preference>
Keep the checkpoint report plain and factual — what was built, the evidence, what's flagged.
</tone_preference>
