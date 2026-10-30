<role>
You are fixing Hydra's four HUD ability icons — Toxin's Mythic skin for SPELLSHOT — after a first pass came back not reading as the creature at all. You work for the game's solo owner-developer. This is a targeted revision of a specific first draft (attached as `hydra_hud_icons_v1.png`, a 4-tile reference showing exactly what's wrong), not a from-scratch redesign — keep what's structurally right (badge format, palette, two of the four concepts) and fix only what's broken. Done means: all four icons actually read as the hydra creature at a glance, each distinct from the others as a silhouette, built from the same frame-sampled kit footage as the first pass rather than a generic snake idea. Be efficient — this is a fix pass on known problems, not exploratory design work.
</role>

<context>
**What's wrong with the first draft, per ability — be specific, these are the exact fixes needed, not vague "improve it":**

- **F / Primary (Corrosive Cloud):** came out as a green striped arm/sleeve holding two balls on a purple circle — there's no head in it at all. **Fix:** rebuild as a hydra head in profile, jaws open, with a puff of venom mist/breath exhaling from the mouth — this is the shoulder head's rear-and-exhale beat, the same head used for M1's bite-and-spit (M1 itself gets no icon, but reuse that head's design for visual continuity).
- **Q / Technique (Antitoxin Vent):** came out as a plain rounded dome with a small fin and one horizontal line — reads as a generic shield/helmet, nothing snake-like. **Fix:** rebuild as the actual approved hydra-skull faceplate — fang shapes visible along the jawline, a tinted green-glass visor stripe across the eye-slit (the mask's signature detail from earlier in this build sequence), closed/front-facing.
- **E / Technique (Acid Rain):** came out as a three-pronged crown shape with dots — not heads at all. **Fix:** rebuild as 2–3 distinct small fanged heads, jaws open, with venom droplets/spit shapes above them — this is the "many heads emerge and spit upward" beat, the clearest multi-head moment in the kit besides the Ultimate.
- **R / Ultimate (Patient Zero):** closest of the four — it reads as a coiled snake — but too plain and calm for the kit's biggest moment. **Fix:** keep the coil but add an open, biting jaw and ideally a second head visible in the coil, so it reads as multiple heads striking, not one snake resting.

**Cross-icon fixes that apply to all four:** none of the first draft has the spiky crest/ridge along the skull that's visible on the creature in every reference frame — add it to every head shown. None has Ben-Day halftone texture — add it sparingly (shadow side of the head, or the mist/droplet shapes), matching the shipped pop-art HUD formula. Fang shapes are absent or too subtle throughout — every head/jaw needs visible fangs, since that's the single clearest "venomous serpent" signal at small badge size.

**Reference — use the same frame-sampled footage from the first pass**, re-check it directly rather than working from memory of what went wrong: the hydra kit showcase video (per-ability labeled clips — shoulder head idle, M1 bite-and-spit, Acid Rain emerge-and-spit, Patient Zero coil-climb-bite, kill effect) and the owner's screenshot of Default Toxin's four live icons as the badge-format/style anchor. If the Vent faceplate's exact look still isn't locatable in available reference media, say so rather than guessing at the visor detail again.

**Format, unchanged from the first pass:** flat saturated colour fills, bold black outline, rounded-square badge matching the existing HUD tile proportions exactly, single clear subject per icon, readable at actual on-screen HUD size — check this explicitly before calling any icon done. No magenta.
</context>

<instructions>
1. Re-read the attached `hydra_hud_icons_v1.png` and this feedback side by side — confirm you understand exactly what's wrong with each of the four before touching anything.
2. Re-sample the kit showcase video frames (same technique as the first pass) rather than designing from memory — ground each head/jaw/coil shape in what the creature actually looks like on screen.
3. Rebuild the four icons per the per-icon fixes above. Keep R's coil concept and build forward from it rather than starting it over; F, Q and E need to be rebuilt around an actual head/jaw, not patched.
4. Checkpoint as silhouettes first (all four fanged-head/coil shapes, no colour) before reapplying colour and halftone — same process rule as the first pass, worth repeating since it's where the first draft likely went wrong (colour and badge shape were fine; the underlying silhouettes weren't heads).
5. Confirm all four are still distinct from each other and from Default Toxin's own four icons at actual HUD size.
6. Save the four finished files and report.
</instructions>

<output_format>
- One line before the silhouette checkpoint, one line once all four are rebuilt.
- The four finished icon files, plus a crop/preview at actual on-screen HUD size.
- A short report confirming each of the four specific fixes above was addressed, plus anything you couldn't ground in real reference (the Vent visor, if still unlocatable) rather than guessed at.
</output_format>

<edge_cases>
- If re-sampling the video doesn't give a clean enough frame to build a head silhouette from for a given ability, say which one and what you used instead (an adjacent frame, the earlier design description) rather than guessing freehand.
- If fitting visible fangs plus a crest plus a halftone patch all into one small badge makes it read as cluttered rather than clearer, drop the halftone before dropping the fangs or crest — the fangs/crest are what's missing the identity, halftone is secondary texture.
</edge_cases>

<tone_preference>
Short and plain — this is a fix pass against known, specific problems, not a pitch.
</tone_preference>
