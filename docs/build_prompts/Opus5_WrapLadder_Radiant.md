<role>
You are migrating Radiant's wrap system onto SPELLSHOT's rarity-ladder pattern and building its three missing wraps, directly in the owner's live Roblox Studio place, through Studio's own MCP connection (Assistant → ... → Manage MCP Servers → "Enable Studio as MCP server" must be on; if it isn't, stop and ask the owner to turn it on rather than editing files blind). You work for the game's solo owner-developer. Cryo, Toxin, Umbra and Aqua already have finished five-wrap ladders (Uncommon ×2, Rare, Epic, Mythic) — your structural reference, don't touch them. Radiant has exactly one wrap today, Rainbow, still wired through the project's older per-ability `SkinCatalog.Offer` system rather than the newer `ElementWraps`/`ElementWrap_<Element>` rarity-ladder pattern. Done means: Radiant migrated onto that ladder pattern, Rainbow confirmed still working under it (at its current tuning — don't retune it, see below), the three missing wraps built to the locked roster below, each checkpointed against Default with real screenshots, and nothing wired live/selectable until the owner reviews.
</role>

<context>
**Check for a project skill first.** This project has used Claude-Code-only skills before for exactly this kind of sorting work (this session's own equivalent is called `spellshot-skin-tiers`, for full Element skins). List whatever skills are available to you and look for a wrap-tier equivalent — it may be named something like `spellshot-wrap-tiers`, but don't assume the exact name; search before concluding it doesn't exist. If found, follow its tier/texture conventions ahead of the table below where the two differ, and flag the difference. If none exists, use this prompt's table as the source of truth.

**The locked roster — already designed and approved by the owner.** Build exactly these; propose refinements to exact numbers at checkpoint, not to the concept, name or texture call. Rainbow (Uncommon, already built) stays untouched.

| Wrap | Tier | Texture change? | Look |
|---|---|---|---|
| Moonlight | Uncommon | No — recolor only | Pale silver and cool blue-white, simple flat palette |
| Stained Glass | Rare | Yes — add segmented panel facets | Jewel-toned colour panels across the light forms, not a flat wash |
| Starlight | Epic | Yes — add pinpoint star detail | Deep indigo-navy night sky with glowing white pinpoint stars — a cool departure from Default's warm white-gold, not a brighter version of it |
| Prism Bloom | Mythic | Yes — animated colour-shift, not a static texture | Iridescent opal effect, slowly cycling cool blues/pinks/greens rather than sitting on one fixed hue |

**Important: Rainbow is confirmed working, just tuned very faint on purpose — don't "fix" it.** A recent audit confirmed Rainbow is correctly wired but pushed 55% toward white (`SkinCoreLift`) plus bloom washes out most of the rest, so its six colours survive only as pastel tints — clearest on Blessing/Halo, barely visible on Light Lance. That's a deliberate tuning value the owner may revisit separately; leave it exactly as-is in this pass. Don't let it influence how subtle you make the three new wraps — Moonlight, Stained Glass, Starlight and Prism Bloom should each read clearly on their own, regardless of how faint Rainbow currently is.

**Tier escalation matters.** Across every finished ladder on this project, Epic adds a real luminous core and richer particle/glint layer over Rare, and Mythic adds something Epic doesn't have at all. Starlight needs a genuine step up from Stained Glass, not just another texture; Prism Bloom needs to clearly outclass Starlight — its animated colour-shift is exactly that kind of signature behavior. Prism Bloom especially should make someone stop and look.

**Identity colours — check every new wrap against these, so nothing drifts back onto an Element's own Default look. This matters more for Radiant than any other Element right now**, since an earlier proposed Mythic wrap for this exact ladder ("Supernova," a white-gold starburst) was caught before being built because it would have looked almost identical to Radiant's own shipped identity — warm white and gold, confirmed directly from the live config:
| Element | Base | Light | Dark |
|---|---|---|---|
| Pyro | #F25C0D | #FFC74D | #6B1708 |
| Terra | #826B24 | #CCBA5C | #33210D |
| Radiant | #F5C230 | #FFF7D6 | #70520A |
| Voltaic | #F5C70F | #FFF573 | #4A1A8C |
| Zephyr | #4FD1C5 | #FFFFFF | #125C59 |

Moonlight, Stained Glass, Starlight and Prism Bloom were each deliberately designed to sit away from Radiant's own warm white-gold (cool silver, jewel-tone panels, indigo night sky, and a cycling iridescent effect respectively) — hold that line as you build them; if any of them is trending back toward warm white-gold once actually rendered, say so rather than shipping a second near-miss.

**Respect the game's Graphics Quality setting.** The Settings menu exposes `GraphicsQuality` (LOW/MEDIUM/HIGH/ULTRA), which `SettingsRuntime.client.lua` turns into one scalar, `SpellshotSettings.EffectDensity` (LOW 0.45, MEDIUM 0.75, HIGH 1.00 — the default, ULTRA 1.15), read the moment an emitter is built — not Roblox's own quality slider, which this game's menu never touches. `RadiantDraw.lua` already reads this scalar for Radiant's base draw, so the three new wraps need to scale through the same value rather than hardcoding one density. Starlight's pinpoint-star count and Prism Bloom's animated colour-shift layer are the two most likely to need this — fewer stars and a slower/simpler shift on LOW/MEDIUM, fuller on ULTRA, the way Radiant's existing FX already behaves. Read `CryoWrap.lua`'s `solidOn` function for the established pull pattern (`require(ReplicatedStorage.Spellshot.SpellshotSettings).EffectDensity`).

**Migrating off the old system.** Radiant is currently wired through `SkinCatalog.Offer.Radiant` (a flat list applied to all five abilities — LightLance, Blessing, Halo, PositionTrade, Benediction — confirm the live keys, don't assume this list is current), not the `ElementWraps`/`ElementWrap_<Element>` pattern Cryo/Toxin/Umbra/Aqua use. Bring Radiant onto that same pattern: `Rarity` and `Wrap` fields on each `SkinCatalog.Skins` entry, chosen via one `ElementWrap_Radiant` player attribute rather than per-ability `Skin_<ability>` attributes, with the Studio-only `WrapStudio` preview pattern already established for Umbra/Cryo/Toxin. Read how that migration was actually done for Umbra (its own code comments note the date and reasoning) before replicating it.
</context>

<instructions>
1. Check for the project skill (above) first.
2. Read the live `SkinCatalog.lua`, `SpellshotConfig.lua`, `RadiantDraw.lua`, `RadiantFX_Hand.lua` and `RadiantFX_Staff.lua` to confirm current state before changing anything.
3. Migrate Radiant onto the `ElementWraps`/`ElementWrap_Radiant` pattern. Confirm Rainbow still renders correctly, at its current faint tuning, under the new system before building anything else.
4. Build Moonlight, Stained Glass, Starlight and Prism Bloom to the roster table's texture-change call. Leave every ability's timing, damage, range and hitbox values untouched — wraps are colour and surface only. Scale Starlight's star count and Prism Bloom's shift layer by `SpellshotSettings.EffectDensity`, matching how Radiant's base FX already respects Graphics Quality.
5. Checkpoint: screenshot every new wrap against Default, on a real staff-equipped player (not a training dummy — dummies carry no Radiant staff and understated an earlier Rainbow test), covering at least two abilities (Light Lance plus one more) in both gather/cast and impact/active states.
6. Don't add Radiant's new wraps to the live `ElementWraps`/offer list as selectable, and don't call the ladder final, until the owner reviews.
7. Report an upfront scope/time estimate before your first Studio push.
</instructions>

<output_format>
- The upfront scope/estimate message, before any Studio push.
- One line before you start.
- Default-vs-wrap screenshot pairs for all four wraps (Moonlight, Stained Glass, Starlight, Prism Bloom), covering gather/cast and impact/active, on a real player, plus Rainbow's post-migration confirmation.
- A short report: which wraps landed as designed, the identity-colour check for each (explicit on how far each sits from Radiant's own warm white-gold), and anything that needed a judgment call against the roster table.
</output_format>

<edge_cases>
- If migrating breaks Rainbow's rendering or changes its tuning, stop and report rather than pushing forward with an altered Uncommon tier.
- If a "No — recolor only" wrap (Moonlight) starts looking flat once built, don't quietly add texture — flag it at checkpoint instead; the plain/textured split across tiers is deliberate.
- If any new wrap's built look drifts close to Radiant's own identity colour or another Element's (Voltaic's yellow-white is a known near-neighbor), flag it with the specific hex comparison rather than deciding unilaterally.
- If Light Lance still can't be fired without a real held M1 the way the earlier Rainbow audit found, use Blessing/Halo as your primary evidence and say plainly that Light Lance couldn't be directly captured.
</edge_cases>

<tone_preference>
Keep the checkpoint report plain and factual — what was built, the evidence, what's flagged.
</tone_preference>
