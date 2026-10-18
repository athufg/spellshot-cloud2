# SPELLSHOT — Build Prompt #[N]: Cryo Wrap 1, "Mint Rime" (Uncommon)

Continuation of the Opus 5 / Claude Code build sequence (previous: the Frost Lotus Epic upgrade; filename unknown).
This is visual/VFX work: real reference before styling, checkpoint before final.

<role>
You are building the first Cryo wrap for SPELLSHOT, a Roblox PvP elemental-duel FPS, for the solo developer. A **wrap** is a recolour of existing shapes. It never changes geometry, particle counts, timing or gameplay. "Mint Rime" is the Uncommon wrap: one flat four-colour palette, no animation, and the same particle amount as Default. You are done when Mint Rime recolours every Default Cryo visual, the user approved the colour checkpoint, and it is wired as a selectable wrap.
</role>

<token_budget>
Be efficient with tokens. One agent, no subagents. Use targeted searches and function-level reads, never whole-file or whole-repo reads. View at most two images in total: the Default Cryo reference for the checkpoint, and the checkpoint sheet. Keep progress notes to a line and the report short.
</token_budget>

<context>
- Cryo's Default look is built from 13 Blender meshes (in `ReplicatedStorage.IceMagicMeshes`) with three flat tone bands baked into per-face vertex colours, plus an ink-outline hull. The bands are IceDeep `#0E4FA8` (shadow), IceMid `#3FB6F0` (mid), IceLight `#D6F6FF` (lit), with Rim `#FFFFFF` and Outline `#080E1A`. These are `VFXLibrary.Config.Colors`. The meshes use white `MeshPart.Color` and `SmoothPlastic`, because any tint multiplies the baked bands. Particles take colours through ColorSequences from the same palette.
- Wraps recolour the Default Cryo shapes only. Do not change the Frostblade, Frost Lotus or Snow Globe skins, and do not retint the HUD, the callouts or the status reactions.
- `CryoFX.lua` is at Luau's 200 top-level-locals limit: add no new top-level locals. Put new code in a separate module.
- The code wins on how something works today, and the manual (v0.24) wins on what it should do. Say so in your report if they disagree.
</context>

<palette>
Mint Rime, four colours plus the two fixed ones (colours are proposals, flag them if they look wrong in-game):
- Main (replaces IceMid): `#6EDDB8` seafoam
- Shadow (replaces IceDeep): `#1F9A7B` mid green
- Highlight (replaces IceLight): `#E6FFF5` white frost with a mint tint
- Accent: `#0B5E4B` deep green, for small details only (crack lines, ground-pattern lines, particle cores)
- Unchanged: Rim `#FFFFFF`, Outline `#080E1A`

Keep Mint Rime pale and blue-leaning (cyan-green), with frost white dominant. The Toxin Element is green, so the wrap must not read as Toxin. Shape (angular crystals, six-arm snowflake) carries Cryo's identity.
</palette>

<instructions>
1. **Find every Default Cryo visual** with targeted searches in the VFX module: each mesh, each emitter preset's ColorSequence, and any hard-coded colour in the ability handlers (M1 Icicle Shard, Flash Freeze, Cold Momentum, Mirror Cage, Blizzard, and any other Default Cryo visual that exists). Produce a short list of colour sites.
2. **Propose how a wrap swaps the baked vertex colours (text only, no images).** Compare, in at most 12 lines: (A) re-export mesh variants per wrap with the bands baked in that wrap's palette; (B) re-export once with neutral grey bands and tint with `MeshPart.Color` (note the effect on the shadow band's hue); (C) re-export once with a palette-lookup so a wrap is a tiny palette texture swap. Judge each on one-off cost, how it scales (eventually 8 Elements x 5 wraps), and risk to the Default look. Also judge whether it can later carry, with no geometry change, a colour gradient (Rare), a slow brightness pulse (Epic), and a few extra small tier-based emitters (Epic and Mythic). Mint Rime itself needs none of these. Recommend one. **Stop and wait for the user to choose.** Flag, do not decide: the user picks.
3. After the user chooses, implement it in a separate module, so a wrap is one data entry (the four colours plus an id and the Uncommon tier). Recolour the meshes and every ColorSequence and hard-coded colour from step 1. Particle counts, geometry and timing stay identical to Default.
4. **Colour checkpoint:** render one sheet at on-screen size from normal 1v1 distance, showing Default and Mint Rime side by side for the M1 shard, the Flash Freeze zone, the Mirror Cage and Blizzard. Include a Toxin Default shot for comparison, and the same Mint Rime shots with the Colourblind-Safe setting on (Toxin becomes deep teal `#007A5E` there). Stop and show it with a one-line note on whether Mint Rime still reads as Cryo and not Toxin in both modes. Do not wire it up until the user approves.
5. After approval, wire Mint Rime as a selectable wrap the same way skins are selected where sensible. If no wrap slot or equip path exists yet, report what is missing and add only the smallest data field needed. Do not invent a shop, a price, or a new menu.
</instructions>

<rules>
Cosmetic only: no gameplay value, timing or hitbox changes, and visibility stays hit-honest. Colour only: no new shapes, no animation, no new particles, no gradients (Uncommon is one flat palette). No magenta, no gold or amber. All emitters keep going through `emitter()`, so Graphics Quality, Reduce Enemy VFX and Reduce Flashing still apply. No kill effect, no HUD or status-reaction retint, no new callout words.
</rules>

<scope>
Only the Mint Rime wrap on the Default Cryo shapes. Not in scope: the other four wraps (Deep Glacier, Sakura Frost, Black Ice, Aurora), wraps on skins, and any HUD icon, health-bar or rarity change. Make routine judgment calls yourself and list them. Flag anything ambiguous instead of deciding it, and add nothing that wasn't asked for.
</scope>

<output_format>
Step 2: the short text proposal. Step 4: the checkpoint sheet with a one-line note. Final report in a few lines: files and module name, how many colour sites were recoloured, what was wired, and anything flagged (including how a skin could consume a wrap's palette later, without deciding it).
</output_format>
