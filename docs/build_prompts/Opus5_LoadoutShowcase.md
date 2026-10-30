<role>
You work for SPELLSHOT's solo owner-developer, building in Roblox Studio. The Loadout Altar in the hub currently opens a flat menu. Replace it with a showcase experience: the player's equipped element's attack floats center-stage and rotates, a side rail switches between all 6 Elements, and a dropdown previews each element's other moves. Done means all of this is built, reuses the game's existing systems instead of duplicating them, and matches the game's existing UI style exactly.
</role>

<context>
SPELLSHOT has 6 Elements: Pyro, Terra, Radiant, Voltaic, Zephyr, Aqua. The Loadout Altar already sits in the hub with a Terra stone-dais identity — reuse that physical space, don't build a separate room. The hub also already has a wrap-showcase pedestal system that renders each wrap's real M1 projectile VFX per element (not a placeholder) — that is the rig to reuse as this feature's centerpiece display, not rebuild.

This is loosely inspired by showcase screens in other Roblox games (camera pushes into a display area, item rotates on a stand, side list to browse). Do not copy one specifically — do not replicate a specific other game's exact backdrop, layout, or camera framing closely enough that it reads as a copy. Keep it visibly SPELLSHOT: the altar's stone/crystal Terra dais, SPELLSHOT's pop-art/comic VFX style, SPELLSHOT's existing rarity color ladder for wraps.

The dev has very limited token budget left this week. Explore and reuse existing code/assets wherever possible; don't regenerate systems that already exist.
</context>

<instructions>
1. Before building, find and read: the existing wrap-showcase pedestal system (M1 VFX display rig), the existing Loadout Altar hub geometry/script, and the game's existing UI component library (buttons, panels, tiles, fonts, colors already used elsewhere — e.g. the interact-prompt UI, the wrap pedestal's UI, any existing menus). Reuse these components directly for every new UI element in this feature rather than styling anything from scratch.
2. Interacting with the Loadout Altar smoothly transitions the camera into a showcase framing of that same altar space (push/zoom, not a hard cut to a different scene).
3. Centerpiece: the pedestal rig displays the player's currently equipped element's M1 projectile, slow auto-rotating. Add click-drag input to let the player manually orbit it.
4. Add a side rail of the 6 element icons. Selecting one swaps the centerpiece to that element's M1 projectile via a dissolve/reform transition in that element's own VFX style (not an instant pop), and shows that element's wrap list (rarity-colored tiles per SPELLSHOT's existing rarity ladder, click to equip).
5. Add a "Preview Moves" button beside the selected element that opens a dropdown listing that element's kit move names (M1 + other ability slots). Selecting a move swaps the centerpiece from the M1 projectile to a looping preview of that move's VFX in place (effect only, no character needed). Closing the dropdown or switching elements returns the centerpiece to the M1 projectile.
6. All new UI (rail, tiles, dropdown, buttons) must visually match the components found in step 1 — same fonts, colors, panel and button styles already in use. No new ad-hoc UI style.
</instructions>

<output_format>
- One line before you start, after you've located the existing systems from step 1.
- Before/after clip or screenshots covering: the camera transition, the centerpiece with manual orbit, switching between two elements, and the Preview Moves dropdown.
- Short confirmation line listing what was reused vs newly built.
</output_format>

<edge_cases>
If a wrap or element is locked/unowned, show it in the list but visually marked locked rather than hiding it. If the dropdown is open and the player switches elements, close the dropdown and reset to that element's M1. If an ability's VFX has no existing standalone-loop version, build the minimum needed to loop it in place rather than reworking the ability itself.
</edge_cases>

<tone_preference>
Short and factual. Be efficient — minimize exploration beyond step 1, keep the report brief.
</tone_preference>
