<role>
You are making one more correction to Moonlight, continuing directly from the solidity fix you just shipped. You work for the game's solo owner-developer. Stained Glass, Starlight, Prism Bloom and Rainbow are untouched by this pass — don't touch them. Done means Moonlight's palette is fully grey/monochrome (no blue, no color tint at all), solidity stays exactly as it was just restored, re-checkpointed against both Default and Starlight, nothing wired live/selectable until the owner reviews.
</role>

<context>
**The owner's exact feedback, watching `moon.mp4` after the solidity fix:** "it looks similar to starlight wrap."

**This is correct — confirmed directly.** The solidity fix restored Moonlight's Blessing/Halo back to full density, which was the right call. But the cool silver/blue-white hue from the original pass, now at full density, reads as a saturated, crackling electric-blue effect with spiky fringe lines and white highlight points — and that's close enough to Starlight's own look (an indigo-blue crackling night-sky effect with pinpoint stars and spiky linework) that the two wraps now share the same color family AND the same shape language. Cropped side-by-side comparison of Moonlight's Halo against Starlight's Halo confirms it: both read as "saturated blue crackling energy," differing mainly in exactly how dark/indigo the blue is. That's not an acceptable gap between an Uncommon and an Epic.

**The owner's instruction for fixing this:** make Moonlight fully grey. Not "paler blue," not "silver with a blue tint" — drop the blue entirely and make the whole palette grey/monochrome. This also moves Moonlight further from Default (warm gold-white) and further from Starlight (indigo-blue) at the same time, since grey shares no hue with either.

**What "fully grey" means for implementation:** every color value currently driving Moonlight's tint — core color, rim/edge color, particle color, any gradient stops — should be true greyscale (equal or near-equal R/G/B channels), not a blue-grey or a warm-grey. Light Lance, Blessing, Halo, Overflow Light and Benediction should all land on the same grey family so the wrap reads as one consistent palette, the way Azure Flame or Ashfire do with their own single-hue identity. You can still vary value (how light vs. dark the grey is) between effects or between the particle core and its glow/rim, the same way Default varies its own gold brightness — just no hue, anywhere.

**Solidity is not up for revision again.** The density/fill/opacity you just fixed should carry over untouched — this pass only changes color values, nothing about particle count, line width, or fill.
</context>

<instructions>
1. Read your own current code for Moonlight's Light Lance, Blessing, Halo, Overflow Light and Benediction (wherever the palette values from the last two passes landed) before changing anything.
2. Replace every color value in Moonlight's palette with true greyscale equivalents — strip the blue hue out entirely rather than desaturating it partway. Keep relative brightness relationships (what's bright vs. dim within an effect) so the shapes still read clearly.
3. Do not touch particle count, line width, fill, opacity or density — that's the fix you already shipped and it should carry over exactly as-is.
4. Leave every ability's timing, damage, range and hitbox values untouched — this is still colour-only work.
5. Re-checkpoint: Default vs. Moonlight for Light Lance, Blessing and Halo (same framing as before), plus one direct Moonlight vs. Starlight comparison on Halo so the owner can confirm the two no longer read as similar.
6. Don't add this to a live/selectable offer list, and don't call it final, until the owner reviews.
</instructions>

<output_format>
- One line before you start.
- Default-vs-Moonlight screenshot pairs for Light Lance, Blessing and Halo.
- One Moonlight-vs-Starlight pair on Halo specifically.
- A short report: confirmation every Moonlight effect is now true greyscale with no hue, and that solidity/density is unchanged from the last fix.
</output_format>

<edge_cases>
- If a fully grey effect starts looking identical to a desaturated/dim version of Default once rendered (i.e. grey reading as "dull white" rather than as its own distinct tone), push the value range wider — darker darks, brighter brights — rather than adding any hue back in to compensate.
- If any particle or glow texture has color baked into the asset itself rather than being tinted at runtime, flag that specifically rather than approximating grey with a tint on top of a colored texture.
</edge_cases>

<tone_preference>
Keep the report plain and factual — what changed, the evidence.
</tone_preference>
