<role>
You are fixing one HUD icon — Hydra's Antitoxin Vent icon (the Q slot) — because the last pass didn't match the actual built mask. You work for the game's solo owner-developer. The other three icons (Corrosive Cloud, Acid Rain, Patient Zero) are approved and must not be touched. This is a one-icon fix, scoped tight — be efficient, don't re-derive the whole icon set's style from scratch.
</role>

<context>
**What's wrong:** the current Q icon is a smooth rounded dome/beetle-face shield with a small crest and one horizontal line across it — generic, and it doesn't match the mask that's actually built and already approved in-game.

**What the real mask looks like — read directly from the kit showcase video, labeled "Antitoxin Vent: the helm drops and locks" (~35s in):** it's a **two-lobe mechanical helmet**, not a single smooth dome.
- A smaller left lobe with a **dark tinted visor/eye-slit** and **fang-like hooks hanging below it**.
- A larger right lobe with a **yellow chevron/arrow marking** and visible **vertical hard-surface panel seams**.
- **Pale horn/spike clusters on top of both lobes** (not just one small crest).
- Overall reads as hinged, segmented, mechanical plating — the Iron-Man-style reference the owner gave earlier in this build, not an organic beetle shell.

**Fix:** rebuild the Q icon's silhouette around these two asymmetric lobes, the visor/eye-slit, the chevron marking, the fang-hooks, and the paired horn spikes — in that priority order, since the two-lobe asymmetric shape plus the visor are what's most recognizable at small badge size; the chevron and panel-seam detail matter most once the base shape is right.

**Format, unchanged:** flat saturated colour fills, bold black outline, same rounded-square badge format and size as the other three Hydra icons and as Default Toxin's icons, readable at actual on-screen HUD size, no magenta, halftone used sparingly if at all (the shape fixes matter more than texture here).
</context>

<instructions>
1. Re-watch the ~35s "the helm drops and locks" segment of the kit video directly before redrawing anything — don't work from this description alone, confirm the two-lobe shape, visor placement, chevron side, and horn placement against the actual frame.
2. Rebuild Q's silhouette first (no colour) around the two-lobe mask, checkpoint it alone before reapplying colour.
3. Reapply colour/outline matching the other three icons' finish level.
4. Confirm it reads as clearly "mask/helmet" and clearly distinct from the other three icons at actual HUD size, and confirm it reads correctly under the deuteranopia simulation the owner is already checking icons against.
5. Leave the other three icon files untouched.
</instructions>

<output_format>
- One line before the silhouette checkpoint.
- The rebuilt Q icon file, at full size, real HUD size, and the deuteranopia-sim crop, matching the comparison sheet format already in use.
- A short confirmation that the two-lobe shape, visor, chevron, fang-hooks and paired horns are all present, or a note on which one didn't fit at small size and why.
</output_format>

<edge_cases>
- If fitting all five details (two lobes, visor, chevron, fang-hooks, paired horns) legibly at small badge size isn't possible, keep the two-lobe shape and the visor first — those read the mask fastest — and drop the chevron or panel-seam detail before dropping the horns or fang-hooks.
- If the ~35s timestamp doesn't land on the right frame, search nearby frames in that same labeled segment rather than guessing from memory.
</edge_cases>

<tone_preference>
Short and plain — one known fix, not a design pitch.
</tone_preference>
