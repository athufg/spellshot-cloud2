<role>
You are correcting the last pass on the interact-prompt bubble — it added a small triangle under the existing rectangular card instead of actually changing the shape to a speech bubble. You work for SPELLSHOT's solo owner-developer. Done means the box itself reads as a rounded speech-bubble silhouette, not a rectangular card with a flag stuck on the bottom.
</role>

<context>
The owner's reference is a plain stick-figure sketch: an organically-rounded balloon shape (soft, almost cloud-like rounded corners, not a crisp rectangle) with one small clean triangular tail pointing down toward the speaker's head — and there's a visible gap between the tail's tip and the head, it doesn't touch.

What shipped instead: the exact same rectangular card from before (sharp-edged rounded rectangle, dotted background, thin border — that part's fine) with a small triangle glued to the bottom-center. The owner's "it still doesn't look like that" is about the body shape, not the tail — a rectangle with a triangle under it reads as a label with a pointer, not a speech bubble. The corners and overall proportions need to actually become balloon-like.

Also: on the Merchant NPC, the tail is landing on the character's goggles/headwear instead of pointing cleanly at the center of the head — the tail's target point needs to track the head itself, not whatever geometry happens to be directly below the box's current position.
</context>

<instructions>
1. Rework the bubble body's corner radius and proportions so the silhouette reads as an actual rounded speech balloon, not a rectangle — compare directly against the sketch's roundness, not just the previous rectangular shape with softened corners.
2. Keep the tail as one small clean triangle, but leave a visible gap between its tip and the NPC's head — it shouldn't touch or overlap the head.
3. Fix the tail's target point so it aims at the center-top of the NPC's actual head on both the Keeper and the Merchant, regardless of accessories (hood, goggles) sitting in between.
4. Keep the thinner border weight, icon, text layout, size, pop in/out animation, and above-the-head anchor from the last two passes — only the body silhouette and tail targeting change here.
</instructions>

<output_format>
- One line before you start.
- A shot of the new bubble next to the sketch reference, for both Keeper and Merchant.
- One short confirmation line.
</output_format>

<edge_cases>
- If matching the sketch's roundness exactly makes the text cramped at the current size, loosen the internal padding slightly rather than shrinking the text to fit.
</edge_cases>

<tone_preference>
Keep the report short and factual.
</tone_preference>
