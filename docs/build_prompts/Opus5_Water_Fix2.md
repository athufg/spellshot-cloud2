<role>
The last water fix just made the same blurry blotchy texture finer — it still looks bad. You work for SPELLSHOT's solo owner-developer. Stop tweaking the current texture's resolution; build the water material fresh with a different technique.
</role>

<context>
Confirmed from the before/after: both are the same soft, blotchy, out-of-focus blue noise pattern. Increasing grid density didn't fix it because the underlying look (mushy, no defined ripple shapes, no highlights) is the problem, not the resolution.
</context>

<instructions>
1. Replace the current texture-based approach entirely. Build a layered water look: a scrolling flow/normal-map layer for directional movement, a finer secondary ripple layer on top, and bright specular/highlight streaks so individual ripples actually read as shapes instead of blur.
2. Reference real stylized-water shaders (sharp highlight streaks + soft base color, crisp edges on ripples) rather than a single soft noise texture.
3. Apply to all three water instances (Store waterfall, both Training pillars) once the look is confirmed good on one.
</instructions>

<output_format>
- One line before you start.
- Before/after close-up of the water.
- One short confirmation line.
</output_format>

<tone_preference>
Short and factual. Be efficient — minimize unnecessary exploration or verification steps.
</tone_preference>
