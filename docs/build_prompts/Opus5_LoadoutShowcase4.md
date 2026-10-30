<role>
You work for SPELLSHOT's solo owner-developer, building in Roblox Studio. The Loadout Showcase (dedicated chamber, pedestal centerpiece, element rail, two-dummy move preview) is built and mostly working, but has confirmed bugs and still looks basic in places. Fix every bug below, add the missing Skins tab, and push the visual polish further. Done means all listed bugs are gone and the chamber/pedestal/UI all look like a flagship feature, verified across every element in the game, not just the ones shown in the review footage.
</role>

<context>
Confirmed working, don't rebuild: the dedicated showcase chamber, the two-dummy combat preview (caster performs the move via real ability logic, target takes the real hit reaction), and per-element chamber lighting (color genuinely shifts per element already).

Confirmed from review footage: the element roster is bigger than previously assumed — at least nine (Pyro, Cryo, Terra, Radiant, Voltaic, Zephyr, Aqua, Umbra, Toxin), possibly more. Pull the live list from the game's actual element data/scripts, never a hardcoded list, so every current and future element gets full treatment automatically.
</context>

<instructions>
**Bugs — fix all:**
1. Camera drag-to-orbit on the centerpiece doesn't respond to input in-game at all. Wire it up with inertia/easing on release.
2. Pyro's M1 projectile renders as a plain black unlit sphere on the pedestal — no fire material/particles applied. Every other element's M1 displays correctly; find and fix what's different about Pyro's instance.
3. Cryo's M1 projectile is mispositioned off in the top-left of the screen instead of centered on the pedestal.
4. A flicker/black seam around the floor ring lines up with console warnings about EditableMesh memory budget limits. Rebuild whatever's generating that warning (likely the floor ring or a transition effect) as static geometry — it doesn't need to be runtime-generated.
5. Radiant: during Preview Moves the ability VFX plays but the caster dummy isn't holding the staff accessory that move uses. Attach the held item as part of triggering the preview, not just the ability VFX/animation.
6. Verify the two-dummy preview actually fires the attack and hit-reaction for every element in the dynamic list, not just the ones already confirmed working.

**Add — Skins tab:**
7. Add a "Skins" tab next to the existing "Wraps" tab. Skins are full kit reworks at a rarity tier (distinct system from Wraps' recolors). Selecting a Skin shows its reworked M1 on the centerpiece and its reworked move VFX in the two-dummy preview, same mechanism as Wraps.

**Polish — push further:**
8. Pedestal: currently a plain black disc regardless of selection. Give it element-reactive material/glow matching whichever element/wrap/skin is currently shown.
9. UI side panel: currently flat colored bars with text, the most basic-looking part of this feature. Add per-row icons instead of flat color blocks, a real selected/hover state (not just a thin outline), and a panel frame/border treatment matching SPELLSHOT's existing UI polish elsewhere in the game.
10. General pass: push the chamber, lighting, pedestal, and UI further toward genuinely impressive — this is a flagship feature, not a functional minimum.
</instructions>

<output_format>
One line before starting. When done: a clip/screenshots covering the fixed Pyro and Cryo M1s, manual orbit working, the floor ring with no flicker, Radiant's staff showing in preview, the new Skins tab, and the upgraded pedestal/UI. List what was fixed vs newly added vs polished.
</output_format>

<edge_cases>
If an element's M1/move preview has its own undiscovered version of the Pyro/Cryo bugs, fix it the same way rather than only patching the two named cases. If a Skin doesn't exist yet for a given element, leave its Skins tab entry empty/locked rather than placeholder content.
</edge_cases>

<tone_preference>
Be efficient — keep exploration and reporting tight. This is a real multi-fix plus polish pass; don't shrink the scope to save time, shrink the narration instead.
</tone_preference>
