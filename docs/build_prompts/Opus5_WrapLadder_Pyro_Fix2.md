<role>
You are doing a second fix pass on Pyro's wrap ladder, continuing from your own checkpoint sheet and the first fix pass on Phoenix/Void Flame. You work for the game's solo owner-developer. Azure Flame and Ashfire are confirmed good — don't touch them. Done means: Phoenix's and Void Flame's added effect layers scaled down on every ability except the Ultimate so they stop blocking the player's view during normal play, and Solar Flare rebuilt so it reads as clearly hotter than Default on every ability, not just the Ultimate. Re-checkpoint the same way as before, nothing wired live/selectable until the owner reviews.
</role>

<context>
**The owner's exact feedback, watching the showreel:** Phoenix's and Void Flame's particle layers work for the ultimate, but on normal abilities the particles are too big — big enough that the owner can't see what's happening during the normal moves. Solar Flare still looks too similar to Default Pyro and needs to actually look different.

**This game has a real Basic/Technique/Ultimate split — use it.** Pyro's own ability handler comments confirm Ring of Fire is the Ultimate and Scorching Lash is a Technique; Fireball, Immolate, Ember Refund and Detonate are Basics. A screen-filling effect is correct and expected on the Ultimate — Default's own Ring of Fire already fills the screen, that's the point of an ultimate. The problem is every other ability is getting treated at the same scale.

**Phoenix — the concrete problem.** On Immolate (a Basic), the ember-feather cluster comes out roughly 4-5x the caster's own height, directly overlapping the nearby ally's nameplate and health bar, and the same oversized cluster shows up on Fireball, Ember Refund and Detonate too. That's not "richer than Solar Flare," that's blocking the player's view of the fight during an ability they'll cast constantly. Scale the feather layer down hard for every Basic — small enough to read clearly as feather-shaped without covering anything else on screen, closer in footprint to Default's own compact Immolate flame than to a screen-filling burst. Scorching Lash (a Technique) can stay a step bigger than the Basics since it's already a bigger move in Default too, but still well short of Ring of Fire's scale. Ring of Fire (the Ultimate) is the one place the current big, dramatic feather burst is earning its keep — leave that one alone.

**Void Flame — the same problem, worse.** On Immolate, the dark smoke cloud and crackling void-shard particles are even larger — roughly 5-6x the caster's height, swallowing most of the upper half of the screen and the ally's nameplate with it. Same fix: pull the smoke cloud and shard count/size down hard for every Basic, a step bigger for Scorching Lash, and keep the current full-drama version for Ring of Fire only.

**Solar Flare — still not different enough from Default.** The Ring of Fire burst reads as genuinely hotter and brighter than Default's. Every other ability — Immolate, Ember Refund, Detonate, Scorching Lash — still reads as basically Default's own orange-yellow flame with a faint extra warmth, which is exactly the owner's complaint. The original spec is "recolor/intensity only," so don't add new particle shapes (that's Phoenix's job) — instead make the actual colour/light treatment read as hotter at every scale, not just a big one: give it a visibly white-hot core with the gold/orange pushed to the rim (contrast between core and edge, not just a brighter overall glow), and/or a thin heat-shimmer or corona that's present even on a one-frame Basic cast. Check this specifically against Immolate, Ember Refund, Detonate and Scorching Lash — those are where it's currently failing — not just Ring of Fire.

**Respect `SpellshotSettings.EffectDensity`** for all of this, same as the rest of the ladder — the per-ability size reduction for Phoenix/Void Flame is about fixed scale, separate from (and in addition to) density scaling by Graphics Quality.
</context>

<instructions>
1. Read your own current `PyroWrap.lua` to see exactly what's driving Phoenix's and Void Flame's effect scale per ability before changing anything.
2. Confirm which of Pyro's abilities are Basics, which is the Technique (Scorching Lash) and which is the Ultimate (Ring of Fire) directly from `PyroHandler.server.lua`'s own comments, rather than assuming.
3. Scale down Phoenix's ember-feather layer and Void Flame's smoke/shard layer for every Basic, a step bigger for Scorching Lash, full scale unchanged on Ring of Fire only.
4. Rebuild Solar Flare's core/rim treatment so it reads as hotter than Default on Immolate, Ember Refund, Detonate and Scorching Lash specifically, not just Ring of Fire. No new particle shapes — this stays a recolor/intensity wrap.
5. Leave every ability's timing, damage, range and hitbox values untouched — this is still colour/surface/particle-scale work only.
6. Re-checkpoint: Default vs. Phoenix, Default vs. Void Flame, Default vs. Solar Flare, covering Fireball, Immolate, Detonate and Ring of Fire at minimum so the Basic-vs-Ultimate scale difference is visible in the same sheet.
7. Don't add any of these to a live/selectable offer list, and don't call the ladder final, until the owner reviews.
</instructions>

<output_format>
- One line before you start.
- The re-checkpoint sheet: Default-vs-wrap pairs for Phoenix, Void Flame and Solar Flare, covering at least Fireball, Immolate, Detonate and Ring of Fire.
- A short report: what scale Phoenix's and Void Flame's Basics/Technique/Ultimate effects landed at relative to each other, and how Solar Flare's core/rim treatment reads on the Basics now.
</output_format>

<edge_cases>
- If pulling Phoenix's or Void Flame's Basic-scale effects down makes them hard to tell apart from a flat recolor at that size, say so rather than quietly shrinking past the point where the added layer still reads at all.
- If Solar Flare's new core/rim contrast starts drifting toward white enough to look like Radiant's identity colours, flag it with the hex comparison rather than deciding unilaterally.
</edge_cases>

<tone_preference>
Keep the report plain and factual — what changed, the evidence, what's flagged.
</tone_preference>
