<role>
You are doing a third fix pass on Terra's wrap ladder, continuing from the material fix you just shipped. You work for the game's solo owner-developer. Obsidian Magma and Sandstone are confirmed good — don't touch them. Done means Rusted Iron Ore (Rare), Amethyst Geode (Epic) and Meteorite Core (Mythic) all read as more dramatic than Obsidian Magma, with a clear step up from Rare to Epic to Mythic, re-checkpointed against both Default and Obsidian Magma, nothing wired live/selectable until the owner reviews.
</role>

<context>
**The owner's exact feedback, watching the fix-pass showreel:** Obsidian Magma looks better than all the others — fix that, and make Rare, Epic and Mythic look better than Magma.

**Confirmed directly, comparing all four wraps' Aftershock dome at the same crop/zoom.** Obsidian Magma's dome is the most dramatic of the four: a near-black cracked surface with a bright glowing red rim and vivid red fissure lines running through it — strong contrast, reads as "molten rock" clearly. By contrast: Rusted Iron Ore's dome is flat grey stone with thin orange-red crack lines and no rim glow at all — it's noticeably duller and flatter than Magma's, not a step up despite being the next tier. Amethyst Geode's dome (navy base, purple glowing cracks) and Meteorite Core's dome (navy base, blue glowing cracks) are close to each other in composition and drama — same dark-dome-with-colored-cracks formula, no rim glow either — and neither clearly reads as more dramatic than Magma, let alone escalating past each other. Mythic should be the single most dramatic wrap in the ladder and right now it isn't.

**The core problem: Magma has a treatment the other three don't.** Magma's rim glow is a real, extra visual layer the higher tiers are missing. Rare, Epic and Mythic need their own equivalent — not necessarily the same rim-glow technique, but something that gives each of them the same kind of punch, and each one needs to go further than the last:
- **Rusted Iron Ore (Rare)** needs a real escalation over Magma first — right now it's a flat recolor that reads duller, not a step up. Push contrast and saturation on the base material (the grey is too flat/desaturated next to Magma's near-black), and consider a glowing rim or vein treatment of its own — molten orange cracks pulsing through dark rusted metal, for instance — rather than thin static crack lines on plain grey stone.
- **Amethyst Geode (Epic)** needs to read as a clear step up from Rusted Iron Ore: a richer glow, more crack density, or an added particle layer (drifting crystal shards, internal light pulses) on top of whatever Rusted Iron Ore ends up with.
- **Meteorite Core (Mythic)** needs a genuine signature behavior beyond Amethyst Geode, not just a different hue of the same dome-with-cracks treatment — for example a pulsing/breathing core glow, a brief shockwave ring on impact, or embers/sparks drifting up off the surface. This is the project's standing Epic→Mythic convention (richer layer for Epic, real added behavior for Mythic) and right now Meteorite Core doesn't apply it — it's visually just Amethyst Geode in blue.

**Apply the same check to Boulder Shot, Bulwark Charge, Bedrock, Bulwark Wall and Earthen Tomb**, not just Aftershock — the dome was the clearest comparison point, but if Magma's punch (vivid saturation, a rim/edge glow, strong core-vs-edge contrast) is missing from the other three wraps' versions of these abilities too, fix it there as well.

**Keep this escalation-only — don't touch Magma or Sandstone**, and don't undo the material fix from the last pass (Sandstone's tan Bulwark Wall/Earthen Tomb, the per-wrap base-material changes) while you're in this code.

**Respect `SpellshotSettings.EffectDensity`** for whatever new glow/particle work this pass adds, same as the rest of the ladder.
</context>

<instructions>
1. Read your own current `TerraWrap.lua` to see exactly what makes Obsidian Magma's treatment (especially the Aftershock rim glow) more dramatic than the other three, before changing anything.
2. Rebuild Rusted Iron Ore's base material and glow treatment so it reads with more contrast and saturation than it currently does, and give it its own equivalent of Magma's extra glow layer so it reads as a clear step up from Magma, not a dull version of it.
3. Add a richer glow/crack-density/particle layer to Amethyst Geode so it reads as a clear step up from Rusted Iron Ore.
4. Add a genuine signature behavior to Meteorite Core (pulsing core, shockwave ring, drifting embers, or similar) so it reads as a clear step up from Amethyst Geode and lands as the most dramatic wrap in the ladder.
5. Check Boulder Shot, Bulwark Charge, Bedrock, Bulwark Wall and Earthen Tomb on all three wraps the same way, and apply the same punch-up wherever they're currently flatter than Magma's version of that ability.
6. Don't change Obsidian Magma or Sandstone, and don't regress the material fix from the last pass.
7. Leave every ability's timing, damage, range and hitbox values untouched — this is still colour/material/particle work only.
8. Re-checkpoint: Default vs. each of Rusted Iron Ore, Amethyst Geode and Meteorite Core across Boulder Shot, Aftershock, Bulwark Wall and Earthen Tomb, plus a four-way Magma vs. Rusted Iron Ore vs. Amethyst Geode vs. Meteorite Core comparison on Aftershock so the escalation is directly visible in one sheet.
9. Don't add any of these to a live/selectable offer list, and don't call the ladder final, until the owner reviews.
</instructions>

<output_format>
- One line before you start.
- Default-vs-wrap screenshot pairs for Rusted Iron Ore, Amethyst Geode and Meteorite Core, covering Boulder Shot, Aftershock, Bulwark Wall and Earthen Tomb.
- One four-way Magma vs. Rusted Iron Ore vs. Amethyst Geode vs. Meteorite Core comparison on Aftershock.
- A short report: what was added to each of the three wraps, and confirmation Magma and Sandstone are unchanged.
</output_format>

<edge_cases>
- If pushing Rusted Iron Ore's saturation/glow starts making it look too close to Obsidian Magma's own red palette, pull back toward a distinctly orange/rust hue rather than red, and say so.
- If Meteorite Core's new signature behavior makes Earthen Tomb's impact harder to read mid-fight, scale it back rather than shipping something that hurts gameplay clarity for the sake of drama.
</edge_cases>

<tone_preference>
Keep the report plain and factual — what changed, the evidence.
</tone_preference>
