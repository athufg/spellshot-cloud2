<role>
You work for SPELLSHOT's solo owner-developer, building in Roblox Studio. The first build of the Loadout Showcase didn't land — it reused the literal hub hallway with a flat ray-burst and bokeh-circle overlay slapped on top, so it read as wallpaper rather than a real moment. This rewrite replaces that approach entirely. Done means: a new dedicated showcase chamber the camera cuts into, the old ray/circle effect fully gone, a two-dummy combat preview that shows each move actually landing, and UI that's indistinguishable from the rest of SPELLSHOT. This is a flagship feature — build it to the bar of something a player screenshots and shows friends, not to the bar of "technically works."
</role>

<context>
**Why the last attempt failed, specifically:** the showcase was the hub altar hallway reused as-is — same pillars, same lanterns, same benches visible in frame, same lighting as the normal hub — with a radial ray-burst texture and scattered glow-dot circles painted uniformly across the backdrop. Because the geometry was identical to the hub and the ray/circle effect didn't react to anything (same regardless of element), it never stopped feeling like "the hub with a filter on it." There's also a leftover bug: the element-list side panel header still reads "REACTIONS", copy-pasted from the existing leaderboard UI component instead of labeling an element list.

**What's being built instead:** one new, dedicated showcase chamber — built as a stage, not a lived-in space. No hub set-dressing carried over (no reused benches or lantern props). It should be unmistakably SPELLSHOT's own pop-art/comic visual identity — bold shapes, saturated color, the game's existing VFX language — and must not read as a copy of another Roblox game's showcase screen. Never name or reference any other specific game anywhere in code, comments, or in-game text.

SPELLSHOT has 6 Elements, each with an established identity color used elsewhere in the game:
- Pyro — Base #F25C0D / Light #FFC74D / Dark #6B1708
- Terra — Base #826B24 / Light #CCBA5C / Dark #33210D
- Radiant — Base #F5C230 / Light #FFF7D6 / Dark #70520A
- Voltaic — Base #F5C70F / Light #FFF573 / Dark #4A1A8C
- Zephyr — Base #4FD1C5 / Light #FFFFFF / Dark #125C59
- Aqua — not listed here; pull its real identity color from `AquaWrap.lua` rather than guessing.

Two systems already exist and should be reused, not duplicated: the wrap-showcase pedestal rig (renders each wrap's real M1 projectile VFX in place of a placeholder), and the hub's central crystal effect (a pulsing inner glow + soft diffuse corona — no shard/debris particles). The crystal effect is the reference for any ambient energy in this new room: soft and premium, never a flat ray or circle overlay.
</context>

<instructions>
1. **Explore first.** Find and read the wrap-showcase pedestal rig, the hub crystal's glow/corona implementation, SPELLSHOT's existing UI component patterns (fonts, panel/button styles, the leaderboard component you'll be un-copying the label from), the real move/ability-casting and hit-reaction logic used in actual combat, and `AquaWrap.lua` for Aqua's color. Everything new should be built from these, not from scratch.

2. **Remove the old effect completely.** Delete the ray-burst and bokeh-circle backdrop effect from the current showcase implementation before building the replacement — don't layer the new room on top of the old VFX.

3. **Build the new chamber.** A single dedicated showcase space, visually separate from the hub (don't reuse hub benches/lantern props as set dressing), with dramatic focused lighting on the centerpiece — this is the thing the room exists to frame. Interacting with the Loadout Altar in the hub triggers a camera cut into this chamber (a real transition beat — not an instant teleport with no feedback, but it also does not need to be the altar space itself, since this is now its own room). Give the chamber a baseline SPELLSHOT identity (shapes, materials, lighting character consistent with the game) that then shifts per selected Element.

4. **Fix the label bug.** The element-list side panel gets its own correct header — not "REACTIONS".

5. **Centerpiece.** The pedestal rig displays the equipped element's M1 projectile for the currently equipped wrap, slow continuous auto-rotation, click-drag manual orbit with inertia/easing on release (not a raw 1:1 spin that stops dead).

6. **Element switching.** A side rail of all 6 Elements. Selecting one swaps the centerpiece's M1 projectile via a dissolve/reform transition that uses that element's own VFX language (embers for Pyro, mist/droplets for Aqua, arcing sparks for Voltaic, etc. — use your judgment per element, consistent with how each element already looks in combat), paired with the chamber's lighting and any ambient energy drifting toward that element's identity color (base/light/dark) rather than snapping instantly. Below/beside the rail, show that element's wrap list as rarity-colored tiles matching SPELLSHOT's existing rarity ladder; clicking one equips/selects it as the previewed wrap.

7. **Two-dummy combat preview.** A "Preview Moves" button beside the selected element opens a dropdown listing that element's kit move names (M1 plus other ability slots). Selecting a move brings two standard Roblox-mannequin dummies onto the stage: a caster and a target. The caster performs the move by triggering the real in-game ability logic (actual VFX, actual animation, actual cast behavior) in a sandboxed preview context — not a separate faked animation — so it's guaranteed to match what the move looks like in an actual duel. The target dummy takes the real hit reaction for that move (hit VFX, flinch/knockback, whatever it does in combat). This plays automatically on selecting the move, repeating on a loop or interval so the player doesn't have to press anything extra to keep watching it. Closing the dropdown or switching elements clears both dummies and returns the centerpiece to that element's M1 projectile.

8. **Skin tie-in.** Whichever wrap is currently selected for that element is what's shown both on the M1 projectile centerpiece and on the caster dummy's move VFX during a move preview, so switching wraps changes what you see in both places — never a generic default while a specific wrap is selected.

9. **UI fidelity.** Every new UI element (rail, tiles, dropdown, buttons, any preview-area chrome) must be visually indistinguishable from SPELLSHOT's existing UI — same fonts, same color language, same panel/button treatment used elsewhere in the game. Where there's no exact existing equivalent, match the closest existing pattern rather than inventing a new visual language for this one screen.
</instructions>

<output_format>
Before your first tool call, say in one line what you're about to build, after finishing the exploration in step 1. While working, flag anything important you find or change your approach on (e.g. "the pedestal rig doesn't currently support color-tinting on demand, extending it for the mood-shift transitions").

When done, deliver:
- A clip or screenshots covering: the cut into the new chamber, the centerpiece with manual orbit, switching between two elements (dissolve/reform plus the lighting/mood shift), and a full Preview Moves cycle (dropdown open, caster performing the move, target reacting).
- What was reused from existing systems vs newly built.
- Any judgment calls you made (e.g. a specific element's dissolve VFX choice, the chamber's baseline look) and why.
</output_format>

<edge_cases>
If a wrap or element is locked/unowned, show it in the rail/list marked locked using SPELLSHOT's existing locked-item styling, rather than hiding it or inventing a new locked state. If the Preview Moves dropdown is open when the player switches elements, clear the dummies and reset to the new element's M1 — don't leave a stale move preview running. If a move's hit-reaction logic can't run standalone without a real target player (e.g. it depends on live player state), build the minimum sandboxed stand-in needed so the target dummy still visibly reacts, rather than skipping the reaction or faking an unrelated animation. If the pedestal rig can't currently support per-element color-tinting or the dissolve/reform transition without changes, extend it rather than forking a parallel copy of the system.
</edge_cases>

<tone_preference>
This is worth the extra care. Where a step leaves room for judgment on how an effect or transition should feel, lean toward whatever looks best in SPELLSHOT's existing comic/pop-art style, and say what you chose and why rather than defaulting silently to the simplest version.
</tone_preference>
