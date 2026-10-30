<role>
You are correcting a regression in Moonlight from the last fix pass. You work for the game's solo owner-developer. The last pass pushed Moonlight's color cooler but also made it thin and sparse — it now looks broken, not simply plain. Done means Moonlight matches Default's solidity and fullness exactly, with only the hue changed, re-checkpointed, nothing wired live/selectable until the owner reviews.
</role>

<context>
**The owner's exact reaction, looking at the new checkpoint sheet:** "what is this moonlight bro like it looks superbad."

**What actually went wrong.** Comparing the Default-vs-Moonlight sheet directly: Default's Blessing is a solid, fully-filled gold-white ring of light around the caster. Moonlight's Blessing is thin, scratchy white lines that barely read as a ring at all — sparse rays instead of a filled glow. Same problem on Halo: Default's wings are solid, well-defined feather shapes; Moonlight's wings came out as thin wireframe-like scratches, not solid shapes. Light Lance is closer but still reads thinner than Default's.

This means the last fix pass didn't just shift the hue — it also reduced the particle count, line width, or fill/opacity, and that's what makes it look broken rather than "plain." A flat recolor should keep every bit of Default's visual weight, density and solidity — the ONLY thing that should change is color. Nothing about "plain" or "Uncommon" means thinner, sparser, or lower-opacity than Default. Sandstone and Ashfire and Crimson Arc and Copper Current (the other flat-recolor Uncommons across this project) all keep their Default's full visual weight — only Moonlight has this problem.

**The fix:** go back to whatever is driving Blessing's ring and Halo's wings for Moonlight and make them structurally identical to Default's own versions — same particle count, same line/fill width, same opacity, same density — and change only the color values (pushing toward cool silver/blue-white, per the original direction). If the cool shift was implemented by swapping to a different, sparser effect template instead of recoloring the existing one, that's the bug — recolor the existing full effect, don't substitute a thinner one.

**Light Lance** should get the same check even though it's closer — confirm it's not also slightly thinned relative to Default once you're in the code.
</context>

<instructions>
1. Read your own current code for Moonlight's Blessing and Halo (and Light Lance) to find where the effect's particle count, line width, fill or opacity was changed alongside the color in the last pass.
2. Restore full solidity/density/weight to match Default exactly on all three — this is the priority fix.
3. Keep the cool silver/blue-white color shift from the last pass; don't revert the hue, only the thinness.
4. Leave every ability's timing, damage, range and hitbox values untouched — colour/surface work only.
5. Re-checkpoint: Default vs. Moonlight for Light Lance, Blessing and Halo, same framing as the sheet the owner just reviewed, so it's a direct apples-to-apples recheck.
6. Don't add this to a live/selectable offer list, and don't call it final, until the owner reviews.
</instructions>

<output_format>
- One line before you start.
- Default-vs-Moonlight screenshot pairs for Light Lance, Blessing and Halo.
- A short report: what was actually causing the thinness (template swap vs. parameter change), and confirmation the fix is color-only now.
</output_format>

<edge_cases>
- If restoring full density makes the cool colour shift harder to see (a denser white-ish effect can wash out a subtle tint), push the hue shift stronger rather than letting density slip again — solidity is non-negotiable, color visibility is the thing to tune.
</edge_cases>

<tone_preference>
Keep the report plain and factual — what was actually broken, what changed.
</tone_preference>
