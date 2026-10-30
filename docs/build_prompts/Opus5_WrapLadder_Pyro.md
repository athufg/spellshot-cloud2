<role>
You are migrating Pyro's wrap system onto SPELLSHOT's rarity-ladder pattern and building its three missing wraps, directly in the owner's live Roblox Studio place, through Studio's own MCP connection (Assistant → ... → Manage MCP Servers → "Enable Studio as MCP server" must be on; if it isn't, stop and ask the owner to turn it on rather than editing files blind). You work for the game's solo owner-developer. Cryo, Toxin, Umbra and Aqua already have finished five-wrap ladders (Uncommon ×2, Rare, Epic, Mythic) — your structural reference, don't touch them. Pyro has exactly one wrap today, Azure Flame, still wired through the project's older per-ability `SkinCatalog.Offer` system rather than the newer `ElementWraps`/`ElementWrap_<Element>` rarity-ladder pattern. Done means: Pyro migrated onto that ladder pattern, Azure Flame confirmed still working under it, the three missing wraps built to the locked roster below, each checkpointed against Default with real screenshots, and nothing wired live/selectable until the owner reviews.
</role>

<context>
**Check for a project skill first.** This project has used Claude-Code-only skills before for exactly this kind of sorting work (this session's own equivalent is called `spellshot-skin-tiers`, for full Element skins). List whatever skills are available to you and look for a wrap-tier equivalent — it may be named something like `spellshot-wrap-tiers`, but don't assume the exact name; search before concluding it doesn't exist. If found, follow its tier/texture conventions ahead of the table below where the two differ, and flag the difference. If none exists, use this prompt's table as the source of truth.

**The locked roster — already designed and approved by the owner.** Build exactly these; propose refinements to exact numbers at checkpoint, not to the concept, name or texture call. Azure Flame (Uncommon, already built) stays untouched.

| Wrap | Tier | Texture change? | Look |
|---|---|---|---|
| Ashfire | Uncommon | No — recolor only | Smoldering grey-charcoal flame, dull red embers, same shapes/particle count as Default |
| Solar Flare | Rare | No — recolor/intensity only | White-gold superheated fire, brighter and hotter-reading than Default |
| Phoenix | Epic | Yes — add ember-feather particle shapes | Gold-to-crimson gradient flame with drifting feather-shaped embers, not present in Default |
| Void Flame | Mythic | No — recolor only, but push it dramatically | Black fire with a deep violet-indigo core (never magenta) — reads as forbidden/cursed, not just hotter |

**Tier escalation matters.** Across every finished ladder on this project, Epic adds a real luminous core and richer particle/glint layer over Rare, and Mythic adds something Epic doesn't have at all. Phoenix needs a genuine step up from Solar Flare, not just another hue; Void Flame needs to clearly outclass Phoenix, not restate it in a new colour. Void Flame especially should make someone stop and look.

**Identity colours — check every new wrap against these, so nothing drifts back onto an Element's own Default look (a real near-miss already caught on a different Element this project):**
| Element | Base | Light | Dark |
|---|---|---|---|
| Pyro | #F25C0D | #FFC74D | #6B1708 |
| Terra | #826B24 | #CCBA5C | #33210D |
| Radiant | #F5C230 | #FFF7D6 | #70520A |
| Voltaic | #F5C70F | #FFF573 | #4A1A8C |
| Zephyr | #4FD1C5 | #FFFFFF | #125C59 |

Azure Flame already sits safely opposite Pyro's own warm orange/gold identity (confirmed: its whole palette is blue/cyan/white). Keep the three new wraps similarly distinct from Pyro's own Base/Light/Dark, not just different from each other.

**Respect the game's Graphics Quality setting.** The Settings menu exposes `GraphicsQuality` (LOW/MEDIUM/HIGH/ULTRA), which `SettingsRuntime.client.lua` turns into one scalar, `SpellshotSettings.EffectDensity` (LOW 0.45, MEDIUM 0.75, HIGH 1.00 — the default, ULTRA 1.15), read the moment an emitter is built — not Roblox's own quality slider, which this game's menu never touches. `PyroDraw.lua` already reads this scalar for Pyro's base draw, so the new wraps need to scale through the same value rather than hardcoding one density. Phoenix is the one wrap here that adds a genuinely new particle layer (the ember-feather shapes) — make sure that layer comes out thinner on LOW/MEDIUM and fuller on ULTRA the way Pyro's existing FX already does, rather than rendering at a fixed count regardless of setting. Read `CryoWrap.lua`'s `solidOn` function for the established pull pattern (`require(ReplicatedStorage.Spellshot.SpellshotSettings).EffectDensity`).

**Migrating off the old system.** Pyro is currently wired through `SkinCatalog.Offer.Pyro` (a flat list per ability: Fireball, Immolate, EmberRefund, RingofFire, Detonate, ScorchingLash — confirm the live keys, don't assume this list is still current), not the `ElementWraps`/`ElementWrap_<Element>` pattern Cryo/Toxin/Umbra/Aqua use. Bring Pyro onto that same pattern: `Rarity` and `Wrap` fields on each `SkinCatalog.Skins` entry, chosen via one `ElementWrap_Pyro` player attribute rather than per-ability `Skin_<ability>` attributes, with the Studio-only `WrapStudio` preview pattern already established for Umbra/Cryo/Toxin. Read how that migration was actually done for Umbra (its own code comments note the date and reasoning) before replicating it, rather than inventing a new shape. Note from the project's own comments: Azure Flame currently only draws through `PyroFX`'s flame look, not the toon look, and isn't offered on Heat Rush or Cinder Shield (no flame look to paint) — confirm this is still true and preserve it through the migration rather than silently expanding scope.
</context>

<instructions>
1. Check for the project skill (above) first.
2. Read the live `SkinCatalog.lua`, `SpellshotConfig.lua`, `PyroDraw.lua`, `PyroFX.lua` and wherever Pyro's wrap-drawing logic currently lives (Pyro may not have a dedicated `PyroWrap.lua` the way Terra does — find out rather than assuming).
3. Migrate Pyro onto the `ElementWraps`/`ElementWrap_Pyro` pattern. Confirm Azure Flame still renders correctly under the new system before building anything else.
4. Build Ashfire, Solar Flare, Phoenix and Void Flame to the roster table's texture-change call — a "No" wrap should be a genuine flat recolor, a "Yes" wrap needs the specific added effect named, not just a different hue. Leave every ability's timing, damage, range and hitbox values untouched — wraps are colour and surface only. Scale Phoenix's added particle layer by `SpellshotSettings.EffectDensity`, matching how Pyro's base FX already respects Graphics Quality.
5. Checkpoint: screenshot every new wrap against Default, same ability, same angle, in both cast and impact/eruption states — a single static frame can't fairly show flame motion. Confirm Azure Flame still works post-migration in the same sheet.
6. Don't add Pyro's new wraps to the live `ElementWraps`/offer list as selectable, and don't call the ladder final, until the owner reviews — match this project's standing precedent of staging wraps commented out of the live list.
7. Report an upfront scope/time estimate before your first Studio push.
</instructions>

<output_format>
- The upfront scope/estimate message, before any Studio push.
- One line before you start.
- Default-vs-wrap screenshot pairs for all four wraps (Ashfire, Solar Flare, Phoenix, Void Flame), covering cast and impact, plus Azure Flame's post-migration confirmation.
- A short report: which wraps landed as designed, the identity-colour check for each, and anything that needed a judgment call against the roster table.
</output_format>

<edge_cases>
- If Pyro has no dedicated wrap module and its logic lives inline somewhere else, say what you found and propose the closest-fitting structure rather than guessing a module layout.
- If the migration breaks Azure Flame's rendering, stop and report rather than pushing forward with a broken Uncommon tier.
- If a "No — recolor only" wrap starts looking flat once built, don't quietly add texture — flag it at checkpoint instead; the plain/textured split across tiers is deliberate, not a quality judgment.
- If any new wrap's built look drifts close to Pyro's own identity colour or another Element's, flag it with the specific hex comparison rather than deciding unilaterally.
</edge_cases>

<tone_preference>
Keep the checkpoint report plain and factual — what was built, the evidence, what's flagged.
</tone_preference>
