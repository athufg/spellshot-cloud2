<role>
You are doing a major fix pass on Terra's wrap ladder (Obsidian Magma, Sandstone, Rusted Iron Ore, Amethyst Geode, Meteorite Core), continuing from the build you already shipped. You work for the game's solo owner-developer. Done means every wrap recolors/retextures every visible part of every ability it touches — not just the cast flash — Sandstone's Bulwark Wall and Earthen Tomb actually read as sandstone, and Epic/Mythic visibly escalate in complexity over Uncommon/Rare instead of just being a different tint on the same effect. Re-checkpoint Default vs. every wrap across the full ability set, nothing wired live/selectable until the owner reviews.
</role>

<context>
**The owner's exact feedback, watching the full showreel:** the tiers don't feel like they matter — every wrap just reads as a recolor, nothing else, even though texture changes were discussed for Terra specifically. Epic and Mythic need to look better than Uncommon and Rare, not just differently colored. And on Sandstone specifically: the Bulwark Wall and Earthen Tomb (the ultimate) don't show the sandstone material at all. More generally, every part of an ability — the impact, the particles, everything — should be recolored by the wrap, not just some of it.

**Confirmed directly from the showreel, frame by frame, across all five wraps.** Terra's kit is Boulder Shot and Bulwark Charge (Basics), Bedrock (Passive), Aftershock (Technique), Bulwark Wall (Technique), Earthen Tomb (Ultimate).

**Problem 1 — Bulwark Wall's panel material barely changes, confirmed on Sandstone specifically.** Cropped side-by-side: Default's Bulwark Wall is a near-black panel with bright orange crack lines. Sandstone's Bulwark Wall is still a near-black panel — same dark base material — just with the crack-line color swapped to tan/gold instead of orange. Sandstone is supposed to read as light tan/beige stone, and right now the wall's actual surface material never gets there; only a thin decorative line changed color. Obsidian Magma, Rusted Iron Ore, Amethyst Geode and Meteorite Core have the exact same problem relative to their own identity colors — only the crack-line tint changes, the panel's base material stays the same dark default stone underneath every wrap.

**Problem 2 — the same panel-stays-dark issue likely extends past Bulwark Wall.** Check Bedrock's shield shape and Boulder Shot's rock texture the same way — confirm whether the actual surface material (not just a glow line or particle tint) is changing, or whether it's the same base texture with a colored overlay on top. If it's the latter anywhere, that's the same bug and needs the same fix: the wrap's identity should read in the base material itself, not just in an accent color layered over the default one.

**Problem 3 — no complexity escalation across the tier ladder.** Comparing the dome shape in Aftershock and the burst/shield shapes in Boulder Shot and Bulwark Charge across all five wraps: Obsidian Magma (Uncommon) and Meteorite Core (Mythic) use visually the same mesh/particle count/behavior for each ability, differing only in hue and a glow-line tint. This project's own tier-escalation convention (used on every other finished Element) is that Epic adds a richer particle or luminous-core layer over Rare, and Mythic adds a genuine signature behavior beyond Epic — not just a darker or shinier palette. Right now Terra's ladder doesn't do this anywhere; Amethyst Geode and Meteorite Core need a real added layer or behavior, not just their own hue.

**Respect `SpellshotSettings.EffectDensity`.** Confirmed this project's own `TerraWrap.lua` does NOT currently read `EffectDensity` the way `CryoWrap.lua`, `AquaWrap.lua`, `PyroDraw.lua` and `RadiantDraw.lua` already do. Wire whatever new particle/texture work goes into this fix pass into `EffectDensity` the same way those files do — thinner on LOW/MEDIUM, fuller on ULTRA — while you're already in this code.

**Identity materials, for reference while rebuilding each wrap's actual surface (not just its accent color):**
| Wrap | Tier | Intended material/identity |
|---|---|---|
| Obsidian Magma | Uncommon | glassy black volcanic rock, molten red cracks |
| Sandstone | Uncommon | light tan/beige layered sedimentary stone |
| Rusted Iron Ore | Rare | dark metallic grey-brown with orange rust streaks/patina |
| Amethyst Geode | Epic | purple crystal facets, internal glow |
| Meteorite Core | Mythic | dark blue-black pitted meteorite rock with a molten blue-white core glow |
</context>

<instructions>
1. Read your own current `TerraWrap.lua` (and wherever Bulwark Wall's, Bedrock's, Boulder Shot's and Earthen Tomb's materials/textures are actually set) to find where each wrap currently only tints a color line instead of changing the base material.
2. For every wrap, rebuild the actual surface material/texture on every ability it touches — Boulder Shot, Bulwark Charge, Bedrock, Aftershock, Bulwark Wall and Earthen Tomb — so the wrap's identity reads in the base rock material itself, not just in a crack-line or glow accent. Sandstone's Bulwark Wall and Earthen Tomb are the two confirmed-broken cases; fix those first, then verify the same pattern on the other four wraps.
3. Confirm Earthen Tomb's falling debris and Boulder Shot's impact fragments also pick up each wrap's material/color — these are the "impact" and "particles" the owner specifically called out. If any debris or impact-fragment system is hardcoded to Default's colors instead of reading the equipped wrap, fix that at the source so it can't happen on future wraps either.
4. Add a real escalation layer to Amethyst Geode (Epic) and Meteorite Core (Mythic) specifically — an added particle/glow layer for Amethyst Geode beyond Rusted Iron Ore, and a genuine signature behavior for Meteorite Core beyond Amethyst Geode (for example a pulsing core glow, drifting embers, or a brief shockwave ring on Earthen Tomb's impact) — so they visibly earn their tier rather than just being a different hue of the same effect.
5. Wire whatever new particle/texture work this pass adds into `SpellshotSettings.EffectDensity`, matching the pattern already used in `CryoWrap.lua`/`AquaWrap.lua`/`PyroDraw.lua`/`RadiantDraw.lua`.
6. Leave every ability's timing, damage, range and hitbox values untouched — this is still colour/material/particle work only.
7. Re-checkpoint: Default vs. each of the five wraps, covering Boulder Shot (cast + impact), Bulwark Wall (summon), Bedrock (passive proc) and Earthen Tomb (cast + debris), so the material fix and the impact/debris fix are both visible, plus one direct Rusted Iron Ore vs. Amethyst Geode vs. Meteorite Core comparison on Aftershock showing the complexity step-up.
8. Don't add any of these to a live/selectable offer list, and don't call the ladder final, until the owner reviews.
</instructions>

<output_format>
- One line before you start.
- Default-vs-wrap screenshot pairs for all five wraps, covering Boulder Shot (cast + impact), Bulwark Wall, Bedrock and Earthen Tomb (cast + debris).
- One three-way Rusted Iron Ore vs. Amethyst Geode vs. Meteorite Core comparison on Aftershock showing the tier escalation.
- A short report: what was actually causing the material/impact to stay default-colored (texture swap vs. color-overlay-only), what was added to Amethyst Geode and Meteorite Core specifically, and confirmation EffectDensity is wired in.
</output_format>

<edge_cases>
- If a given ability's debris/impact system turns out to be shared code that every wrap (including future ones) feeds through, fix it at that shared layer rather than patching each wrap's call site separately, and say so in the report.
- If making Amethyst Geode's or Meteorite Core's added layer too elaborate starts to meaningfully change how readable the ability is mid-fight, scale it back and say so rather than shipping something that hurts gameplay clarity for the sake of escalation.
</edge_cases>

<tone_preference>
Keep the report plain and factual — what was actually broken, what changed, the evidence.
</tone_preference>
