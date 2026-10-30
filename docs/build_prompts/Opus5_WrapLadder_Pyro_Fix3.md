<role>
You are making one small, narrow adjustment to Void Flame's smoke/particle layer, continuing from the checkpoint you just produced. You work for the game's solo owner-developer. Solar Flare and Phoenix are untouched by this pass — don't touch them. Done means Void Flame's smoke particles bumped up slightly on the abilities where they're currently too sparse, re-checkpointed, nothing wired live/selectable until the owner reviews.
</role>

<context>
**The owner's exact feedback:** a little more smoke/particle density for Void Flame — but only a little. Not a reversal of the last fix pass.

**Where it's currently too sparse.** In the last checkpoint, Ember Refund in particular came out as just a tiny, barely-visible wisp on the caster's chest — the previous fix pass (which pulled Void Flame's Basics way down so they'd stop blocking the screen) pulled that one down further than it needed to. Immolate and Detonate still read fine as compact clusters; Ember Refund is the one that lost too much presence. Check the other Basics (Fireball) against the same standard while you're in there, but Ember Refund is the known problem.

**Keep this small.** The goal is restoring a bit of visible smoke/particle density, not going back toward the old screen-filling scale. A modest bump — enough that Ember Refund reads clearly as "void smoke" rather than a faint wisp — is the target, not a dramatic increase. If in doubt, err toward too little rather than re-creating the original problem.
</context>

<instructions>
1. Read your own current `PyroWrap.lua` to find exactly where Void Flame's per-ability particle counts/scale are set.
2. Bump Ember Refund's smoke/particle density up slightly. Spot-check Fireball, Immolate and Detonate too, and nudge any that read as similarly under-scaled — but leave alone anything that already reads fine.
3. Don't touch Scorching Lash or Ring of Fire — those are already at the right scale.
4. Leave every ability's timing, damage, range and hitbox values untouched — this is still colour/surface/particle-scale work only.
5. Re-checkpoint: Default vs. Void Flame for whichever Basics you adjusted, same shot style as before.
6. Don't add this to a live/selectable offer list, and don't call it final, until the owner reviews.
</instructions>

<output_format>
- One line before you start.
- The re-checkpoint shots for whichever Void Flame abilities you adjusted.
- A short report: what you bumped and by roughly how much, and confirmation you left Scorching Lash/Ring of Fire and the other wraps alone.
</output_format>

<edge_cases>
- If bumping Ember Refund's density starts making it block the ally's nameplate again, pull back — that's exactly the problem the last fix pass solved, and this pass shouldn't undo it.
</edge_cases>

<tone_preference>
Keep the report plain and factual — what changed, the evidence.
</tone_preference>
