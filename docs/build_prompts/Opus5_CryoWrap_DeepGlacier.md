# SPELLSHOT — Build Prompt #[N]: Cryo Wrap 2, "Deep Glacier" (Uncommon)

Continuation of the Opus 5 / Claude Code build sequence (previous: the Mint Rime wrap; filename unknown).
This is visual/VFX work: real reference before styling, checkpoint before final.

<role>
You are adding the second Cryo wrap to SPELLSHOT, a Roblox PvP elemental-duel FPS, for the solo developer. A **wrap** is a recolour of existing shapes. It never changes geometry, particle counts, timing or gameplay. "Deep Glacier" is an Uncommon wrap: one flat four-colour palette, no animation, the same particle amount as Default. It is the second data entry on the wrap mechanism that Mint Rime already built. You are done when Deep Glacier recolours every Default Cryo visual the Mint Rime pass covered, the user approved the colour checkpoint, and it is wired as a selectable wrap the same way Mint Rime is.
</role>

<token_budget>
Be efficient with tokens. One agent, no subagents. Use targeted searches and function-level reads, never whole-file or whole-repo reads. Do not re-survey the codebase: reuse the colour-site list and the module from the Mint Rime pass. View at most two images in total: the Default Cryo reference and your checkpoint sheet. Keep progress notes to a line and the report short.
</token_budget>

<context>
- Cryo's Default look is built from Blender meshes (`ReplicatedStorage.IceMagicMeshes`) with three flat tone bands baked into per-face vertex colours, plus an ink-outline hull. The bands are IceDeep `#0E4FA8` (shadow), IceMid `#3FB6F0` (mid, the visible bulk), IceLight `#D6F6FF` (lit), with Rim `#FFFFFF` and Outline `#080E1A` (`VFXLibrary.Config.Colors`). Meshes use white `MeshPart.Color` and `SmoothPlastic`, because a tint multiplies the baked bands. Particles take colours through ColorSequences from the same palette.
- Mint Rime already built the wrap mechanism (a separate module, one data entry per wrap, palette lookup). Find that module and its data format with one targeted search. A wrap here is a data entry, so adding Deep Glacier should need no new code. If it does need code (the mechanism assumed something Mint-specific), say what and make the smallest change, and list it.
- `CryoFX.lua` is at Luau's 200 top-level-locals limit: add no new top-level locals.
- The code wins on how something works today, and the manual (v0.24) wins on what it should do. Say so in your report if they disagree.
- Wraps recolour the Default Cryo shapes only. Do not touch the Frostblade, Frost Lotus, Snow Globe or Frost Dragon skins, the HUD, the callouts or the status reactions.

**Lessons from the Mint Rime checkpoint (apply from the start):** the first Mint Rime sheet looked almost the same as Default. The causes were (1) a near-white Highlight, which made white carry the look; (2) a Shadow too close in brightness to the Main, so the three bands blurred; (3) a recolour that missed the M1 shard and some particle ColorSequences. So for Deep Glacier the **Main colour must be the dominant visible colour**, not white. The Highlight must be tinted. The Shadow-to-Main brightness gap must match or exceed Default's. Every site, including the M1 shard, its trail, hit particles and the particle cores, must be recoloured.
</context>

<palette>
Deep Glacier, four colours plus the two fixed ones (hex values are proposals; tune them in-game and report what you changed):
- Main (replaces IceMid): `#2F63D6` deep cobalt, the dominant colour
- Shadow (replaces IceDeep): `#172A7E` dark navy
- Highlight (replaces IceLight): `#A8C6FF` pale periwinkle (not near-white)
- Accent: `#3DF0FF` electric cyan, for small bright details only (crack lines, ground-pattern lines, shard core, particle cores)
- Unchanged: Rim `#FFFFFF`, Outline `#080E1A`

Concept: dense old glacier ice, a deep cobalt that is clearly different from Default's bright sky blue (`#3FB6F0`). Cryo identity still comes from the angular shapes and the six-arm snowflake.

**Colour risks to check and flag, not decide:**
- Shadow `#172A7E` may blur into the Outline `#080E1A` at on-screen size, which would lose the shadow band. If so, lighten the Shadow and report it.
- Main is close in hue to Default's IceDeep (`#0E4FA8`). It must still read clearly different from Default as a whole.
- Umbra is dark purple (`#4F2191`). Deep Glacier must not read as Umbra.
- Dark effects can vanish against dark map areas. Check readability on a dark and a light background.
- Mint Rime (green) and Zephyr (teal `#4FD1C5`) are far in hue, but Black Ice (Rare, later) will also be dark, so note anything that would make the two collide.
</palette>

<instructions>
1. **Reuse the Mint Rime colour-site list** (meshes, emitter ColorSequences, hard-coded colours for M1 Icicle Shard, Flash Freeze, Cold Momentum, Mirror Cage, Blizzard). Do not repeat the full survey. If the Mint Rime report is not available, do one targeted search to rebuild it.
2. **Add Deep Glacier as one data entry** (the four colours, an id, the Uncommon tier) in the same place and format as Mint Rime. Particle counts, geometry and timing stay identical to Default. Make sure Main dominates the visible area, the Shadow and Accent show on the Flash Freeze ring, the Mirror Cage rings and bolts, and the Blizzard pieces, and the M1 shard and its particles read as cobalt.
3. **Colour checkpoint (one image):** one sheet at on-screen size from normal 1v1 distance, showing Default, Mint Rime and Deep Glacier side by side for the M1 shard, the Flash Freeze zone, the Mirror Cage and Blizzard. Add Deep Glacier with the Colourblind-Safe setting on, and a dark-background and a light-background shot of Deep Glacier's Flash Freeze zone and Blizzard. Then give, in two lines, the hue and lightness of Main, Shadow and Highlight next to Default's IceMid and IceDeep and Umbra's purple, and say whether Deep Glacier reads as clearly different from Default and not as Umbra. If it is still too close to Default or to the outline, say which band is the problem. Stop for approval. Do not wire it up yet.
4. After approval, wire Deep Glacier as a selectable wrap the same way Mint Rime is wired. Add nothing else.
</instructions>

<rules>
Cosmetic only: no gameplay value, timing or hitbox changes, and visibility stays hit-honest (nothing may hide a player or projectile more than the Default effect does). Colour only: no new shapes, no animation, no new particles, no gradients (Uncommon is one flat palette). No magenta, no gold or amber. All emitters keep going through `emitter()`, so Graphics Quality, Reduce Enemy VFX and Reduce Flashing still apply. No kill effect, no HUD or status-reaction retint, no new callout words.
</rules>

<scope>
Only the Deep Glacier wrap on the Default Cryo shapes. Not in scope: the other wraps (Black Ice, Sakura Frost, Aurora), wraps on skins, and any HUD icon, health-bar or rarity change. Make routine judgment calls yourself and list them. Flag anything ambiguous instead of deciding it, and add nothing that wasn't asked for.
</scope>

<output_format>
Step 3: the checkpoint sheet plus the two-line colour note. Final report in a few lines: the data entry location, any code you had to change, how many colour sites were recoloured, what was wired, and anything flagged.
</output_format>
