<role>
You are fixing three things in SPELLSHOT's hub: replacing the default Roblox interact prompt with a custom one, removing a stray VFX bug, and finishing the Training-entrance water fix. You work for the game's solo owner-developer. Done means every interact prompt uses one new custom SPELLSHOT-styled UI (not default Roblox, not a copy of any other game), the stray glowing circles are gone, and the entrance waterfall reads as real moving water. Checkpoint with screenshots; nothing live until reviewed.
</role>

<context>
Every interact prompt right now (Store/Shop, Loadout Altar/Choose Techniques, Duel Pad/SOLO TEST, and any others) uses the stock Roblox ProximityPrompt: a plain dark rounded badge, a key icon, a small label line, a bold action line. That's the thing to replace — build one reusable custom prompt component and swap every interact point onto it. Match it to SPELLSHOT's own existing UI, not a generic redesign: same comic-panel/bold-outline language as the REACTIONS board, same button language as the Shop/Play/Loadout corner buttons. Keep the same two-line info hierarchy (small label on top, bold action below) and the instant appear-on-range/disappear-on-leave behavior — those parts already work, only the visual skin needs to change.

Separately, there are glowing concentric-ring circle effects floating at several spots in the hub (near the Training water pillar, along a path edge, and directly overlapping the Duels corridor's floor arrows) that read as a stray bug, not an intentional effect — remove them.

The Training-entrance waterfall is still a static glow column with painted droplet decals, not moving water — give it real flowing motion, foam/splash at the base, and ripple rings on the floor, same as the rest of the water fix already scoped for that wing.
</context>

<instructions>
1. Build one custom interact-prompt UI component (icon + two-line label/action, SPELLSHOT's comic-panel style) and replace the default ProximityPrompt visuals everywhere it's currently used.
2. Find and remove the stray concentric-circle glow effects at the locations above. If they're leftover from the per-wing floor-light-pool work, delete them rather than trying to repair the ring pattern.
3. Rebuild the Training-entrance waterfall as real flowing water: cascading motion, foam/splash at the basin, expanding ripple rings.
4. Leave all gameplay values and existing menu functionality untouched — this is UI/VFX only.
</instructions>

<output_format>
- One line before you start.
- Before/after shots: one interact prompt (old vs. new style), the circle-removal spots, and the waterfall.
- One short line confirming all three are done and nothing is live/selectable yet.
</output_format>

<edge_cases>
- If any other interact point uses the default prompt beyond the three shown, swap it too and name it in your report.
- If the stray circles turn out to be tied to something functional (not just visual), flag it instead of deleting blind.
</edge_cases>

<tone_preference>
Keep the report short and factual.
</tone_preference>
