# SPELLSHOT — Build Prompt #[N]: Cryo "Frost Dragon" HUD Ability Icons

Continuation of the Opus 5 / Claude Code build sequence (previous: the Frost Lotus HUD icons; filename unknown).
This is visual work: real reference before styling, checkpoint before final. The in-world skin is a separate prompt (`Opus5_FrostDragon_Skin.md`). Run this after the skin's Stage 0 dragon silhouette sheet is approved.

<role>
You are making the HUD ability icons for the Cryo "Frost Dragon" skin in SPELLSHOT, a Roblox PvP elemental-duel FPS, for the solo developer. Frost Dragon is the Mythic skin, the top of Cryo's cosmetic ladder, and Mythic = everything Epic has (including HUD icons) plus more. The icons must look clearly better than the Frost Lotus (Epic) icons and amazing in their own right. A teammate is doing the health-bar accent, so the health bar, its art and its code are out of scope, and so is the avatar change. You are done when four final icon PNGs exist that the user approved at a checkpoint.
</role>

<token_budget>
Be efficient with tokens. One agent, no subagents. Use targeted searches and reads only, never whole-folder reads. View at most four images in total: one Default Cryo icon, one Frost Lotus icon, the Frost Dragon concept sheet, and the checkpoint contact sheet. Keep progress notes to a line and the report short.
</token_budget>

<context>
- **Dragon reference.** Find the approved Frost Dragon concept sheet (the Stage 0 silhouette or colour sheet from the skin build) with one targeted search: {{DRAGON_CONCEPT_SHEET_PATH}}. The dragon is a lean western dragon of glowing ice crystal: faceted scale plates, crystal horns and spine ridge, wings with crystal bone arms and veined membranes with a faint six-arm snowflake, white-hot cyan eyes. Draw it exactly as that sheet shows it, so the icons and the in-world effects are the same creature. If no approved sheet exists, stop and tell the user.
- **Icon style (flag, don't decide).** The user said the skin itself need not be comic, but the HUD is a set: every icon in a slot row must look like the same family. Match the existing icon style (heavy black ink outline, flat cyan and white, halftone dots) and put the extra richness in the subject, not in more detail. If you think the dragon looks clearly better in a more polished style, say so in one line in your report and still deliver the matching style.
- Only four HUD slots exist. M1 and Cold Momentum have no HUD slot, so they get no icon.
- The game's difference rule: a skin differs from Default by object and silhouette, not by recolouring alone. Keep the palette inside the existing Cryo icon palette: no amber or gold, no pink or magenta.
</context>

<design>
Make four icons, each showing the ability's shape as the Frost Dragon:
1. **F, Flash Freeze:** a dragon claw slamming into the ground, with a ring of tall crystal spines radiating around it, seen from a slight angle, lying flat like a ground burst. It must not look like the ultimate.
2. **Q, Technique Blizzard:** two dragons facing inward from opposite sides, wings spread mid-beat, with thick crescent streaks of wind and snow between them (a symmetrical composition). Do not draw an open spiral (that is Zephyr's logo).
3. **E, Technique Deep Freeze:** a frozen figure silhouette sealed in crystal that has dragon-scale facets, with a dragon head breathing frost onto it. The Default icon shows a person frozen in ice, so keep the person.
4. **R, Ultimate Mirror Cage:** the big dragon curled in a circle around a hemisphere cage in a bold front view, its neck arching over so the head points down from above, with the cage plates glowing along its back, wings and neck. This is the Ultimate: the R plate is bigger than the others, so use that space for the strongest, most striking image of the four.

Mythic is a step above Epic: the dragon is a more dramatic subject than the lotus, with a bright white-cyan glow on the eyes and focal point of each icon. The richness comes from a strong focal subject, not from many small details.

Lessons from the earlier icon sets, apply them from the start:
- Judge every icon at the real HUD size, not at 2x. Use fewer, bigger, thicker shapes.
- Make every icon fill about 80% of its plate. The R plate is bigger than the others.
- Each icon needs a different outline from the other three, so they can be told apart at a glance.
- At real size the F, Q, E and R must be clearly different from each other, from the Default icon in the same slot, and from the Frost Lotus icon in the same slot.
- No text on any icon.
</design>

<instructions>
Find the existing Default Cryo icons and the Frost Lotus icons with one targeted search each (file names containing Cryo or FrostLotus and Icon). Read their pixel size, format, folder and naming convention and match all of it. View one Default icon and one Frost Lotus icon only.

Build the icons in Blender from the dragon models in the concept sheet (a simple posed dragon head, claw and wing are enough). Export transparent-background PNGs with one clear focal shape each.

Readability is the bar. Make it look amazing.

CHECKPOINT: render one contact sheet with the four drafts at actual HUD size on the slot plate, plus a second row at 2x, a third row with the Default icon in the same slot, and a fourth row with the Frost Lotus icon in the same slot. Stop and show that single image with a one-line note per icon. Do not export finals until the user approves.

After approval, export the final PNGs to the icon folder using the existing naming convention with a FrostDragon marker that matches how other skins are named. Do not wire them into Studio and do not upload to Roblox, because the user does both.
</instructions>

<scope>
Only these four icons. No M1 or Cold Momentum icon, no health bar, no avatar change, no kill effects, no extra variants. Make routine judgment calls yourself and list them in the report. Ask the user only if the Default icon specs contradict each other.
</scope>

<output_format>
Final report in a few lines: file paths and pixel sizes, the one icon you are least sure about at real size, and anything you changed from this brief.
</output_format>
