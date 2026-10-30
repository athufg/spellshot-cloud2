<role>
You are doing a fix pass on Radiant's wrap ladder, continuing from the build you already did. You work for the game's solo owner-developer. Done means Moonlight actually reads as a distinct cool silver/blue-white wrap instead of a near-duplicate of Default, and Stained Glass, Starlight and Prism Bloom each get a small escalation polish so the Rare→Epic→Mythic step-up reads clearly. Re-checkpoint the same way as the original build, nothing wired live/selectable until the owner reviews.
</role>

<context>
**The owner's exact feedback, watching a full showreel:** Moonlight needs real improvement — it doesn't look like it deserves its tier. The rest of the ladder could use a little improvement too, so each wrap reads as earning its place.

**Moonlight — confirmed, concrete problem.** Comparing Default's Halo and Blessing against Moonlight's versions of the same two abilities side by side: both effects on Moonlight come out as plain white/gold, functionally indistinguishable from Default's own warm white-gold wings and ring. The original spec was "pale silver and cool blue-white, simple flat palette" — that cool shift isn't showing up in the actual rendered result. This is the headline fix. Push the hue clearly toward cool silver-blue (a visible blue/grey cast, not just a slightly paler white) so it reads as a different wrap at a glance, not just a dimmer Default. Keep it a flat recolor per the roster (no new texture) — the fix is entirely about making the color shift actually land, not about adding anything new.

**Stained Glass, Starlight and Prism Bloom — already working, just need a small polish pass.** Checked against Default and each other: Stained Glass's jewel-tone panels, Starlight's indigo night-sky with pinpoint stars, and Prism Bloom's cycling iridescent effect all read as clearly distinct from Default and from each other already. The owner wants "a little bit" more on these — not a rebuild, just push each one slightly further toward standing out for its tier: a touch more facet definition on Stained Glass, a few more visible pinpoint stars or a slightly richer glow on Starlight, and a touch more color-cycle range or a slightly stronger shimmer on Prism Bloom. Small, additive nudges only — these three are not broken.

**Rainbow is explicitly out of scope for this pass.** The owner previously asked that Rainbow's current tuning (faint by design, `SkinCoreLift` pushed toward white) be left alone, and that instruction hasn't changed. If it's genuinely part of what "all wraps" should mean here, that's a separate decision for the owner to make explicitly — don't retune it as part of this pass.

**Identity colours — recheck Moonlight specifically against this table once the cool shift is in**, since pushing toward blue-white risks drifting toward Voltaic's or Zephyr's own territory instead of just away from Radiant's:
| Element | Base | Light | Dark |
|---|---|---|---|
| Pyro | #F25C0D | #FFC74D | #6B1708 |
| Terra | #826B24 | #CCBA5C | #33210D |
| Radiant | #F5C230 | #FFF7D6 | #70520A |
| Voltaic | #F5C70F | #FFF573 | #4A1A8C |
| Zephyr | #4FD1C5 | #FFFFFF | #125C59 |
</context>

<instructions>
1. Read your own current `RadiantDraw.lua`/`RadiantFX_Hand.lua`/`RadiantFX_Staff.lua` (or wherever Moonlight's palette is actually set) to see why the cool shift isn't landing before changing anything.
2. Rebuild Moonlight's palette so Halo, Blessing, Light Lance, Overflow Light and Benediction all read as cool silver/blue-white at a glance next to Default — not just technically a different hex value that renders the same in practice.
3. Give Stained Glass, Starlight and Prism Bloom each one small additive polish pass per the specifics above. Don't restructure any of the three.
4. Leave every ability's timing, damage, range and hitbox values untouched — this is still colour/surface work only. Leave Rainbow untouched.
5. Re-checkpoint: Default vs. Moonlight across at least Halo, Blessing and Light Lance (the three abilities most likely to show whether the cool shift actually reads), plus a quick Default-vs-each for Stained Glass, Starlight and Prism Bloom to confirm the small polish is visible.
6. Don't add anything to a live/selectable offer list, and don't call the ladder final, until the owner reviews.
</instructions>

<output_format>
- One line before you start.
- Default-vs-Moonlight screenshot pairs for Halo, Blessing and Light Lance.
- A short Default-vs-wrap pair for each of Stained Glass, Starlight and Prism Bloom showing the polish.
- A short report: whether Moonlight now reads as clearly cool-toned next to Default, the identity-colour check against Voltaic/Zephyr, and what was nudged on the other three.
</output_format>

<edge_cases>
- If Moonlight's cool shift starts drifting toward Voltaic's or Zephyr's own identity colours once pushed further, flag it with the hex comparison rather than deciding unilaterally.
- If pushing Moonlight cooler makes it look washed-out or flat in a bad way (not just "plain"), say so and propose an alternative read (e.g. leaning more silver/grey than blue) rather than forcing the original wording.
</edge_cases>

<tone_preference>
Keep the report plain and factual — what changed, the evidence, what's flagged.
</tone_preference>
