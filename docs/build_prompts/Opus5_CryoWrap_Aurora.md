# SPELLSHOT — Build Prompt #[N]: Cryo Wrap 5, "Aurora" (Mythic)

Continuation of the Opus 5 / Claude Code build sequence (previous: the Sakura Frost wrap; filename unknown).
This is visual/VFX work: real reference before styling, checkpoint before final. Make it amazing.

<role>
You are adding the fifth and final Cryo wrap to SPELLSHOT, a Roblox PvP elemental-duel FPS, for the solo developer. A **wrap** is a recolour of existing Default shapes: it never changes geometry, the Default particle counts (except the capped extras below), timing or gameplay. "Aurora" is the **Mythic** wrap, the top of the wrap ladder (Uncommon Mint Rime and Deep Glacier, Rare Black Ice, Epic Sakura Frost, Mythic Aurora). Mythic = everything Epic has (a bright gradient and a living glow) plus **flowing colour**, **light curtains** and **starlight**. Aurora must look **amazing and clearly better than every earlier Cryo wrap**, and it must never look dull. You are done when Aurora recolours every Default Cryo visual the earlier wraps cover, has the flowing blend, the curtains and the twinkles, the user approved the checkpoint, and it is wired as a selectable wrap the same way as the others.
</role>

<token_budget>
Be efficient with tokens. One agent, no subagents. Use targeted searches and function-level reads, never whole-file or whole-repo reads. Do not re-survey the codebase: reuse the colour-site list, the wrap module, the gradient code (Black Ice and Sakura Frost) and the pulse and sparkle code (Sakura Frost). View at most four images in total. Keep progress notes to a line and the report short.
</token_budget>

<context>
- Cryo's Default look: Blender meshes with baked flat tone bands (IceDeep `#0E4FA8`, IceMid `#3FB6F0`, IceLight `#D6F6FF`, Rim `#FFFFFF`, Outline `#080E1A`), an ink-outline hull, and particles whose ColorSequences come from the same palette.
- The wrap mechanism exists (a separate module, one data entry per wrap, palette lookup, a core-to-edge gradient, a slow glow pulse and sparkle motes from Sakura Frost). Find the module and its format with one targeted search and extend it.
- `CryoFX.lua` is at Luau's 200 top-level-locals limit: add no new top-level locals. All new code goes in the wrap module (or a new module next to it).
- The code wins on how something works today, and the manual (v0.24) wins on what it should do. Say so in your report if they disagree.
- Wraps recolour the Default Cryo shapes only. Do not touch the Frostblade, Frost Lotus, Snow Globe or Frost Dragon skins, the HUD, the callouts or the status reactions.
- **The user's reference** is a video of a real aurora: soft glowing ribbons with vertical rays, flowing and blending turquoise-teal, blue, violet and orchid-pink into each other, with a bright star-speckled feel. Colours sampled from it: teal `#30D4D6`, violet `#A966D8`, orchid `#D76BD8`. The background in the reference is deep indigo night sky: do **not** use that dark as an effect colour. Take the luminous aurora colours only.

**Lessons from the earlier wraps (apply from the start; the user rejected several earlier versions for these reasons):**
1. **Never dull.** Every large piece must be as bright and emissive as the Sakura Frost cage panels: solid, glowing, with a white-hot edge. No dark navy or indigo fills, no grey or muddy mid-blends, no pale muted pastels, no flat low-emission surfaces. Dark colours are only thin shading bands.
2. The recolour must be on the dominant visible colour, and every soft site must be recoloured: ground discs, haze and fog, ring and disc glows, particle ColorSequences, light sources. List them.
3. No leftover Default blue anywhere in the effect.
4. Solid bodies (discs, panels, rings, the M1 body) stay opaque. **Crystals (spikes, shards) are translucent glowing crystal** (Transparency about 0.35 to 0.55) with a bright inner glow and white-hot edges.
5. The M1 shard, head, trail and hit particles must be clearly visible against sky and floor, at least as visible as Default. Airborne particles never end dark.
6. Check every site at the real 30% on-screen scale on the sky, on a dark floor and on a light floor.
</context>

<design>
**Concept:** the northern lights alive on every Cryo effect. Colour flows through each effect like an aurora: mint-green, teal, sky-blue, violet and orchid blend into each other smoothly, in harmony, and keep moving. Cryo's angular crystal shapes still carry its identity.

**Palette (hex values are proposals; tune in-game and report what you changed).** Five flow stops, all bright and saturated, in this order:
- Mint-green `#3DF5B0`
- Teal-cyan `#30E0E0`
- Sky-violet `#6C8BFF`
- Violet `#A56BFF`
- Orchid `#E070F0`
- Highlight (white-hot edges and glints) `#F4FFFD`. Rim `#FFFFFF` and Outline `#080E1A` unchanged.
- Shading (thin bands next to the outline only, never a large fill): luminous indigo `#5B4FD6`.
No gold or amber. No saturated hot magenta (`#E91E8C` is Sparks): keep the orchid light and violet-leaning.

**Blend rule (important):** blend through the stops in a perceptual way (interpolate in OKLab/OKLCH or through the intermediate stops). Do not lerp straight in RGB between far-apart colours, or the middle goes grey and dull. At every point the blend stays saturated and bright, with no visible hard bands between stops.

**Flowing colour (the Mythic centrepiece):** the blend is a travelling band of colour, not a static gradient. A phase advances through the five stops, a full loop in about 6 s, offset by distance from the effect's origin so the colours ripple through the effect: from the centre outward on discs, rings and the cage, from base to tip on spikes, from tail to head along the M1 shard. At any moment an effect shows three or four of the stops at once (for example mint at one part and violet or orchid at another) and they visibly move. When **Reduce Flashing** is on, hold the flow still at a fixed phase that shows all five stops (a static gradient, no animation). Drive it from the same per-frame loop as the earlier wraps, only while a wrapped effect is active, and report the cost.

**Light curtains (extras, Mythic only):** a few tall, soft, translucent ribbons of light rise from the effect and sway slowly, like aurora curtains: bright at the base, fading to transparent at the top, with the hue shifting along the height (mint or teal at the base, violet and orchid at the top) following the same flow. Build them from **existing soft glow and haze sprites** stretched vertically, additive, so no new art. Sites: the Flash Freeze zone rim, the Blizzard zone rim, around the outside of the Mirror Cage, a thin ribbon wake behind the M1 shard, and ribbon trails behind the player's movement for Cold Momentum. Hit-honest: curtains stay at the rim or outside, thin and transparent, and must not hide a player or projectile more than the Default effect does.

**Starlight (extras, Mythic only):** small star-shaped twinkles in the Highlight colour and the flow colours around the curtains, the spike tips and the cage panels, short-lived, using the existing star or glint sprite (prefer the Sakura Frost mote sprite if it fits). No new art.

**Budget (assumption, flag it):** Epic's extras were capped at about +10 to +15% of Default's per-ability particles. For Mythic assume up to about +25 to +30%. Everything goes through `emitter()` (so Graphics Quality, Reduce Enemy VFX and Reduce Flashing apply), pooled and short-lived. Report the counts per site against Default. If the cap is what stops the curtains from reading, show the best result within it and report the smallest increase that would fix it. Flag it, do not decide.

**Per ability:**
- **M1 shard:** a thick, bright, glowing shard: a white-hot head, a body flowing mint, teal and violet from head to tail, and a thin aurora ribbon wake. The hit: a ring burst in the flowing colours and a few twinkles.
- **Flash Freeze:** a solid, bright disc flowing outward from the centre through the palette, with a glowing white rim. Spikes are translucent glowing crystals, mint or teal at the base and violet or orchid at the tips, with white-hot tips. Curtains at the rim.
- **Mirror Cage:** solid emissive panels with the aurora flowing across the dome like the sky itself (teal or mint near the ground, violet and orchid toward the top), white neon edges, bright floor disc and floor spikes, bright bolts, and curtains around the outside.
- **Blizzard:** the disc, rim, swirl and haze flowing in the aurora colours, translucent gradient shards, and starlight twinkling in the snow. Haze and swirl stay at Default density.
- **Cold Momentum:** ribbon trails in the flowing colours behind the player's movement.

**Colour risks to check and flag, not decide:**
- The teal stop is close to Zephyr's teal (`#4FD1C5`), the mint to Toxin's lime (`#80D421`, Colourblind-Safe `#007A5E`), the violet to Umbra (`#4F2191`), the orchid to Sparks magenta (`#E91E8C`), and the whole wrap to Sakura Frost. Show Aurora beside the Default effects of Zephyr, Toxin, Umbra and Sparks and beside Sakura Frost at the 30% scale, and say if any can be confused. If one can, say which stop to shift and how (for example nudge the teal toward cyan-blue), and do it only after my answer.
- **Colourblind-Safe:** green and violet can look alike for some players. Check a deuteranopia and a protanopia simulation and keep the flow readable: the stops must differ in brightness as well as hue. Report the result.
- Light floor and dark floor: bright cyan and mint can wash out on a light floor. The white edges and the saturated violet and orchid must hold the silhouette. Check both.
</design>

<quality_bar>
Aurora is Mythic, so at 30% on-screen scale it must look **clearly richer, brighter and more alive than Sakura Frost, Black Ice and the Uncommon wraps**. A static gradient with a few extra sparkles fails this bar. The flow must be obvious on every large piece, the curtains must read at that distance, and every large piece must be as bright as the Sakura Frost cage panels. At the checkpoint, say per ability whether Aurora is clearly better than Sakura Frost. Where it is not, say which lever is missing and what extra would fix it. Flag it, do not decide.
</quality_bar>

<instructions>
1. **Feasibility (text only, 10 lines at most).** Can the existing gradient code carry a five-stop palette with a travelling phase and a per-site flow direction, using a data entry plus the smallest new code in the wrap module? How will the curtains and the twinkles hook into each site (M1 flight and hit, Flash Freeze, Mirror Cage, Blizzard, Cold Momentum), and is each event visible to the wrap module today? What is the per-frame cost? If anything needs more than a small hook or a change outside the wrap module, stop and describe the smallest option, then wait for my choice. Otherwise say so in one line and continue.
2. **Reuse the colour-site list** from the earlier wraps. Do not repeat the full survey.
3. **Add Aurora as one data entry** (the five stops, Highlight, Shading, an id, the Mythic tier, the flow, curtain and twinkle settings) in the same place and format as the other wraps, plus the smallest new code in the wrap module.
4. **Colour checkpoint (four images at most):**
   (a) one sheet at 30% scale from normal 1v1 distance showing Default, Sakura Frost and Aurora for the M1 shard, Flash Freeze, Mirror Cage and Blizzard, plus Aurora on the dark floor and the light floor;
   (b) one strip of Flash Freeze at four moments across about 6 s so the colours can be seen travelling, plus the Reduce Flashing static version;
   (c) one strip with Aurora beside the Default effects of Zephyr, Toxin, Umbra and Sparks, and Sakura Frost, at 30% scale;
   (d) one close-up each of a cage panel, a spike, the M1 shard and a curtain.
   Then, in three lines, give the hue and lightness of each of the five stops next to Sparks magenta, Zephyr's teal, Umbra's purple and Toxin's green, and say yes or no for each: reads as a smooth, bright blend of aurora colours with no grey or muddy mid-blend, no dull or dark large fill, no Default blue left (sample the effect pixels and report the hue check), clearly richer than Sakura Frost, readable on both floors, not mistaken for Zephyr, Toxin, Umbra or Sparks, readable with Colourblind-Safe simulation, nothing hides a player more than Default. Report the particle counts of the curtains and twinkles against Default and the per-frame cost. Stop for approval. Do not wire it up yet.
5. After approval, wire Aurora as a selectable wrap the same way the other wraps are wired. Add nothing else.
</instructions>

<rules>
Cosmetic only: no gameplay value, timing or hitbox changes, and visibility stays hit-honest (nothing may hide a player or projectile more than the Default effect does). No new shapes or geometry. The only new particles are the curtains and twinkles from existing sprites, within the cap above. All emitters go through `emitter()`, so Graphics Quality, Reduce Enemy VFX and Reduce Flashing apply. No full-screen flash, no strobing, no kill effect, no HUD or status-reaction retint, no new callout words. No gold or amber, no saturated hot magenta, no dark fills.
</rules>

<scope>
Only the Aurora wrap on the Default Cryo shapes. Not in scope: wraps on skins and any HUD icon, health-bar or rarity change. Make routine judgment calls yourself and list them. Flag anything ambiguous instead of deciding it, and add nothing that was not asked for.
</scope>

<output_format>
Step 1: the short text note. Step 4: the checkpoint images plus the three-line colour note, the counts and the cost. Final report in a few lines: the data entry location, the code you added for the flow, the curtains and the twinkles, how many colour sites were recoloured, what was wired, and anything flagged (including how a skin could consume a wrap's palette later, without deciding it).
</output_format>
