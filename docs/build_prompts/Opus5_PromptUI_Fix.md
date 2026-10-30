<role>
You are polishing the new custom interact-prompt UI you just shipped (the "G — Loadout Altar — Choose Techniques" / "G — Store — Shop" style box). You work for SPELLSHOT's solo owner-developer. The style itself is approved — this pass fixes four concrete problems: no transition animation, the hold-charge bar colliding with the text, wrong anchor point, and size. Done means the prompt animates smoothly in and out, the charge bar has its own space, it anchors above the relevant NPC's head, and it's small enough not to cover the NPC's face or nearby UI.
</role>

<context>
Confirmed from screenshots: the Loadout Altar prompt is large enough to overlap the REACTIONS board behind it, and the Shop prompt sits directly over the Shop NPC's face. Both just cut in/out instantly right now. Separately, holding G fills a charge bar that currently overlaps the label text, making it unreadable mid-hold.
</context>

<instructions>
1. Add a smooth pop-in when the prompt appears (scale/fade up, not an instant cut) and a matching pop-out when it disappears.
2. Give the hold-charge fill bar its own dedicated space in the layout — it should never overlap the label or action text at any fill level.
3. Anchor the prompt above the NPC's head (Loadout Keeper, Shop Merchant) rather than its current anchor, so it never covers the NPC's face or body.
4. Shrink the overall box so it reads as a compact callout — small enough that it doesn't cover the REACTIONS board or other nearby UI.
5. Re-check both prompts in idle and mid-hold states at the new size/position/animation.
</instructions>

<output_format>
- One line before you start.
- Before/after shots for both prompts (idle + mid-hold-with-bar), showing the new size and position.
- One short line confirming the pop animation works and the bar no longer collides with text.
</output_format>

<edge_cases>
- If the charge-bar fix needs a bit more vertical space than the current box budgets, grow it slightly rather than letting the bar clip — but keep the overall footprint at the smaller target size.
- If anchoring above the NPC's head causes clipping into hub geometry (ceiling trim, signage) at some camera angles, pull the anchor down just enough to stay clear rather than letting it clip.
</edge_cases>

<tone_preference>
Keep the report short and factual.
</tone_preference>
