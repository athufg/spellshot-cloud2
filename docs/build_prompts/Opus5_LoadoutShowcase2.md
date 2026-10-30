<role>
You work for SPELLSHOT's solo owner-developer, building in Roblox Studio. The Loadout Altar in the hub currently opens a flat menu. Replace it with a genuine showcase moment: interacting with the altar pushes the camera into a cinematic display of the player's equipped attack, a side rail lets them browse all 6 Elements, and a dropdown previews every move in an Element's kit. This is a flagship feature — the kind of moment a player screenshots and shows friends — so build it to that bar, not to a functional minimum. Done means the full flow works end to end, looks genuinely polished at every transition, and the new UI is indistinguishable in style from SPELLSHOT's existing UI rather than looking bolted on.
</role>

<context>
SPELLSHOT has 6 Elements: Pyro, Terra, Radiant, Voltaic, Zephyr, Aqua. Each has an established identity color used elsewhere in the game — pull these for ambient lighting, VFX tinting, and mood shifts in this feature:

- Pyro — Base #F25C0D / Light #FFC74D / Dark #6B1708
- Terra — Base #826B24 / Light #CCBA5C / Dark #33210D
- Radiant — Base #F5C230 / Light #FFF7D6 / Dark #70520A
- Voltaic — Base #F5C70F / Light #FFF573 / Dark #4A1A8C
- Zephyr — Base #4FD1C5 / Light #FFFFFF / Dark #125C59
- Aqua — not listed here; pull its real identity color from `AquaWrap.lua` rather than guessing or approximating from the other five.

Two systems already exist and must be reused, not rebuilt: the Loadout Altar's hub geometry (a Terra stone-dais area), and the wrap-showcase pedestal rig that renders each wrap's real M1 projectile VFX per element in place of a generic placeholder. This feature is the pedestal rig relocated into a dedicated showcase moment, not a parallel system.

This is loosely inspired by showcase screens that exist in other Roblox games (camera pushes into a display area, an item rotates on a stand, a side list to browse). Do not name or reference any other specific game anywhere in the prompt, code comments, or in-game text, and do not replicate another game's specific backdrop, camera framing, or layout closely enough that a player who's seen both would call this a copy. The differentiators that must carry through everywhere: the Terra stone/crystal dais already built for this altar, SPELLSHOT's pop-art/comic VFX language (not photorealistic smoke/glow), and SPELLSHOT's existing rarity color ladder for wraps.
</context>

<instructions>
1. **Explore first.** Before writing anything, locate and read: the wrap-showcase pedestal system (the M1 VFX display rig), the Loadout Altar's existing hub script/geometry, SPELLSHOT's existing UI component patterns (panels, buttons, tiles, fonts, colors — check the interact-prompt UI, the pedestal's own UI, and any existing equip/wrap menus), and `AquaWrap.lua` for Aqua's color. Every new UI element in this feature should reuse these components directly, not approximate them.

2. **The transition in.** Interacting with the Loadout Altar smoothly pushes the camera from the hub into a showcase framing of that same altar space — don't hard-cut, and don't teleport to a disconnected scene. Treat this as a real cinematic beat: ease the camera move, bring up rim lighting or a spotlight on the dais as it settles, and let ambient hub sound duck under a quieter showcase atmosphere if audio hooks exist. The player should feel like they've stepped into a moment, not opened a menu.

3. **The centerpiece.** The pedestal rig displays the equipped element's M1 projectile, center-stage, slow continuous auto-rotation. Add click-drag input so the player can manually orbit and inspect it — this should feel weighty and smooth (inertia/easing on release, not an instant stop), not a raw 1:1 mouse-delta spin.

4. **Element switching.** A side rail of all 6 element icons. Selecting one swaps the centerpiece to that element's M1 projectile — this swap is a moment in its own right, not a cut: dissolve the current projectile apart using its own element's VFX language (e.g. Pyro crumbles to embers, Aqua dissolves into droplets/mist, Voltaic breaks into arcing sparks) and reform the new one the same way in the new element's style. Pair the swap with an ambient mood shift — the dais lighting, particle color, and any fog/glow in the showcase should drift toward the new element's identity color (base/light/dark from the table above) rather than snapping instantly, so each element reads as its own distinct atmosphere, not a reskinned palette swap. Below or beside the rail, show that element's wrap list as rarity-colored tiles matching SPELLSHOT's existing rarity ladder; clicking a tile equips that wrap.

5. **Preview Moves.** A "Preview Moves" button beside the selected element opens a dropdown listing that element's kit move names (M1 plus its other ability slots). Selecting a move swaps the centerpiece from the M1 projectile to a looping preview of that move's actual VFX, playing in place on the stage (effect only — no character model needed to perform it). This swap deserves the same transition craft as step 4, not a plain cut. Closing the dropdown, or switching elements, returns the centerpiece to that element's M1 projectile.

6. **UI fidelity.** Every new UI element — rail, tiles, dropdown, equip buttons, any labels — must be visually indistinguishable from SPELLSHOT's existing UI: same fonts, same color language, same panel/button treatment already established elsewhere in the game. If something doesn't have a clear existing equivalent to reuse, match the closest existing pattern rather than inventing a new visual language for just this screen.
</instructions>

<output_format>
Before your first tool call, say in one line what you're about to build, after you've finished the exploration in step 1. While working, flag anything important you find (e.g. "the pedestal rig doesn't currently support color-tinting on demand, extending it for the mood-shift transitions") rather than silently working around it.

When done, deliver:
- A clip or screenshot sequence covering: the hub-to-showcase transition, the centerpiece with manual orbit, switching between two elements (showing the dissolve/reform and the mood/lighting shift), and the Preview Moves dropdown with a move preview playing.
- A short list of what was reused from existing systems vs newly built.
- Anything that needed a judgment call (e.g. which VFX language a specific element's dissolve uses) and why you chose it.
</output_format>

<edge_cases>
If a wrap or element is locked/unowned, show it in the rail/list rather than hiding it, visually marked as locked (e.g. desaturated or with a lock icon matching existing locked-item styling elsewhere in the game) rather than inventing a new locked state. If the Preview Moves dropdown is open when the player switches elements, close it and reset the centerpiece to the new element's M1 — don't leave it showing a stale move from the previous element. If an ability doesn't currently have a version of its VFX that can loop standalone without a character, build the minimum needed to loop that effect in place rather than reworking the ability's full kit logic. If the pedestal rig's current implementation can't support the per-element dissolve/reform or color-tinting without changes, extend it — don't fork a second copy of the system.
</edge_cases>

<tone_preference>
This feature is worth the extra care — don't default to the simplest version that technically satisfies each instruction. Where a step leaves room for judgment on exactly how a transition or effect should feel, lean toward what would look best in the game's existing comic/pop-art style, and say what you chose and why rather than picking silently.
</tone_preference>
