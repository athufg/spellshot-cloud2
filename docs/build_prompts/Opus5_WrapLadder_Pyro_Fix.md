<role>
You are fixing two wraps from Pyro's wrap ladder you just built: Phoenix (Epic) and Void Flame (Mythic). You work for the game's solo owner-developer, continuing directly from the checkpoint sheet you just produced (`PYRO WRAP LADDER - checkpoint 2026-10-24`). Azure Flame, Ashfire and Solar Flare are confirmed good — don't touch them. Done means Phoenix and Void Flame rebuilt to read clearly as their tier, re-checkpointed the same way (Default vs. wrap, Ring of Fire cast + eruption, Fireball charge + impact), and nothing wired live/selectable until the owner reviews.
</role>

<context>
**The owner's exact feedback, looking at the checkpoint sheet:** Phoenix reads too close to Default Pyro — it needs to look better for an Epic tier. Void Flame reads as just a recolor and doesn't feel Mythic yet — it needs more effects, more detail, something beyond a palette swap.

**Phoenix — what's actually wrong.** In the checkpoint, Phoenix's Ring of Fire and eruption are an orange-to-red-to-yellow gradient that sits very close to Default's own orange-to-yellow gradient — same silhouette, same general warmth, just a slightly different mix. The original brief called for "gold-to-crimson gradient flame with drifting feather-shaped embers, not present in Default," and the embers specifically were supposed to be the one visible thing Default never has. They aren't reading in this checkpoint — the eruption and impact shots show something closer to a recolored Default flame than a flame with a distinct added particle layer on top. Fix this by making the feather-embers an unmissable, continuously visible layer — larger, more numerous, drifting independently of the flame body with their own motion — not a subtle addition buried inside the flame shape. The gold/crimson gradient itself can stay close to the brief, but the ember layer is what has to carry Phoenix's identity, and right now it isn't carrying anything.

**Void Flame — what's actually wrong.** The original roster table called Void Flame "No — recolor only, but push it dramatically," and that's exactly what got built: a navy/violet recolor of the same flame shape, same behavior as Default, just darker and cooler. Looking at the result, that's not enough for Mythic — every other finished Mythic on this project (Umbra's Umbral Eclipse, Toxin's pH Indicator, Aqua's Maelstrom, and now this ladder's own forthcoming Fusion Core) has a genuine signature behavior beyond its tier's palette, not just a hue shift. Override the original "recolor only" call: Void Flame needs an actual added effect layer, the kind of thing that makes someone stop and look the way the tier-escalation guidance in the original prompt asked for. Pick a treatment that fits "forbidden/cursed fire" rather than just going darker — options already consistent with this project's shape language: dark ash/ember particles that drift upward and dissolve rather than falling like Default's embers, a faint smoke or void-wisp trail clinging to the flame body, crackling dark-violet energy arcing across the surface, or a pulsing/breathing corona around the core. Pick one (or combine two if they read cleanly together) and build it as a real, visible layer — not a tint.

**Keep both honest to their tier, not to each other.** Phoenix is Epic — it should sit clearly below Void Flame in drama once Void Flame is fixed. Don't over-correct Phoenix into Mythic territory; the ember layer should read as "a step up from Solar Flare," while Void Flame's new effect should read as "a step beyond Phoenix" per the project's established Epic→Mythic escalation.

**Respect `SpellshotSettings.EffectDensity`** for whatever new particle work goes into both fixes, the same way the rest of this ladder was asked to — thinner on LOW/MEDIUM, fuller on ULTRA.
</context>

<instructions>
1. Read your own just-built `PyroWrap.lua` (or wherever Phoenix/Void Flame ended up) to see exactly what's currently there before changing it.
2. Rebuild Phoenix's ember-feather layer so it's clearly visible and reads as something Default never has, in every one of the checkpoint's shot types (Ring of Fire cast, eruption, Fireball charge, impact) — not just the ones where it happens to catch the light.
3. Rebuild Void Flame with one real added effect layer (pick from the options above or propose your own cursed-fire treatment), on top of its existing black/violet recolor — not instead of it.
4. Leave every ability's timing, damage, range and hitbox values untouched — this is still colour/surface/particle work only.
5. Re-checkpoint exactly like the sheet you already produced: Default vs. Phoenix and Default vs. Void Flame, Ring of Fire cast + eruption, Fireball charge + impact, same dummy/spot/camera/lighting/EffectDensity-HIGH setup for a fair side-by-side.
6. Don't add either wrap to a live/selectable offer list, and don't call them final, until the owner reviews.
</instructions>

<output_format>
- One line before you start.
- The re-checkpoint sheet: Default-vs-Phoenix and Default-vs-Void-Flame pairs, same four shot types as before.
- A short report: what changed in each, and whether you combined effect options for Void Flame or picked one.
</output_format>

<edge_cases>
- If Phoenix's embers still read as subtle once rebuilt, say so plainly in the report rather than calling it fixed — don't ship a second near-miss.
- If Void Flame's new effect makes it look more like a different Element's identity (check it against the hex table from the original Pyro wrap-ladder prompt) rather than "cursed fire," pull back and flag it instead of shipping it as-is.
</edge_cases>

<tone_preference>
Keep the report plain and factual — what changed, the evidence, what's flagged.
</tone_preference>
