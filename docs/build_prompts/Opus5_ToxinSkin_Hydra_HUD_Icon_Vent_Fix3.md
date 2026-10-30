<role>
You are fixing the Q icon (Antitoxin Vent) a third time — the previous fix picked the wrong reference moment. You work for the game's solo owner-developer. The other three Hydra icons are approved — don't touch them.
</role>

<context>
**The actual bug:** the mask was never two side-by-side lobes. That reading came from a frame of the helm mid-swing (the hinged faceplate captured while it was still rotating closed, so two pieces appeared side by side in that one frame) — not its resting, locked shape. The owner has now sent the real reference for the locked state (attached as `hydra_mask_locked.png`) and it's **one single unified dome helmet**, not two pieces. The current icon (attached as `hydra_vent_icon_v3.png`) has a smaller extra piece sticking out to the left of the main dome that doesn't exist in the real mask at all — remove it entirely, it's not a second lobe, a vent, or anything else; it's just wrong.

**What the real locked mask actually looks like, read directly from `hydra_mask_locked.png`:**
- One unified dome-shaped helmet, full coverage, no second piece beside it.
- Five pale horn/spike shapes along the top ridge, evenly spread.
- A light green/yellow horizontal visor band across the front, with a small diamond/gem accent centered on it.
- Vertical white strap/rib lines running down the front below the visor band, over dark green panel sections.
- Flat tone-banded shading (a lighter highlight patch on the dome's upper-left, mid and dark green bands elsewhere) — comic-flat, not a smooth gradient.
- Thick black outline throughout, consistent with the other three approved icons.

**Fix:** rebuild Q as this single dome shape — delete the extra left-side piece completely, keep five horn spikes across the top (not split across two shapes), one visor band with the centered diamond accent, and the vertical white straps below it.
</context>

<instructions>
1. Compare `hydra_vent_icon_v3.png` (current, wrong) against `hydra_mask_locked.png` (correct reference) directly before changing anything.
2. Rebuild the icon as one unified dome: five horn spikes along the top ridge, one visor band with the centered diamond, vertical white straps below it, flat tone-banded shading, thick outline — matching the locked reference's proportions, not the mid-swing two-piece shape.
3. Confirm no extra piece remains to either side of the main dome.
4. Confirm it still reads clearly at actual HUD size and under the deuteranopia sim, matching the comparison sheet format already in use.
</instructions>

<output_format>
- The rebuilt Q icon in the same comparison format (real HUD size, 2x, Default Toxin same slot, deuteranopia sim).
- One line confirming the extra piece is gone and the shape now matches the single-dome reference.
</output_format>

<edge_cases>
- If any detail from `hydra_mask_locked.png` doesn't survive legibly at small badge size, drop the diamond accent or the strap count before dropping the single-dome silhouette or the horn spikes — the dome shape and spikes are what make it read as "mask" at a glance.
</edge_cases>

<tone_preference>
Short — one specific fix, using the attached reference image directly rather than re-deriving from video.
</tone_preference>
