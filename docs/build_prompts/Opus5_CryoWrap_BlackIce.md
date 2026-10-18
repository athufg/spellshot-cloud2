# SPELLSHOT — Build Prompt #[N]: Cryo Wrap 3, "Black Ice" (Rare)

Continuation of the Opus 5 / Claude Code build sequence (previous: the Deep Glacier wrap; filename unknown).
This is visual/VFX work: real reference before styling, checkpoint before final.

<role>
You are adding the third Cryo wrap to SPELLSHOT, a Roblox PvP elemental-duel FPS, for the solo developer. A **wrap** is a recolour of existing shapes. It never changes geometry, particle counts, timing or gameplay. "Black Ice" is the **Rare** wrap: where the Uncommon wraps (Mint Rime, Deep Glacier) are one flat four-colour palette, Black Ice is a **two-tone gradient from the core of an effect to its edge**, with no animation and no pulse. You are done when Black Ice recolours every Default Cryo visual the earlier wraps cover, the user approved the colour checkpoint, and it is wired as a selectable wrap the same way as the others.
</role>

<token_budget>
Be efficient with tokens. One agent, no subagents. Use targeted searches and function-level reads, never whole-file or whole-repo reads. Do not re-survey the codebase: reuse the colour-site list and the module from the Mint Rime and Deep Glacier passes. View at most two images in total: one Default Cryo reference and your checkpoint sheet. Keep progress notes to a line and the report short.
</token_budget>

<context>
- Cryo's Default look is built from Blender meshes (`ReplicatedStorage.IceMagicMeshes`) with three flat tone bands baked into per-face vertex colours, plus an ink-outline hull. The bands are IceDeep `#0E4FA8` (shadow), IceMid `#3FB6F0` (mid, the visible bulk), IceLight `#D6F6FF` (lit), with Rim `#FFFFFF` and Outline `#080E1A` (`VFXLibrary.Config.Colors`). Meshes use white `MeshPart.Color` and `SmoothPlastic`, because a tint multiplies the baked bands. Particles take colours through ColorSequences from the same palette.
- A wrap mechanism already exists (a separate module, one data entry per wrap, palette lookup via a tiny palette image). Find the module and the data format with one targeted search. Uncommon wraps are one palette. **Black Ice needs a gradient, so first check whether the mechanism can carry it with no geometry change** (see instructions, step 1).
- `CryoFX.lua` is at Luau's 200 top-level-locals limit: add no new top-level locals. Put any new code in the wrap module.
- The code wins on how something works today, and the manual (v0.24) wins on what it should do. Say so in your report if they disagree.
- Wraps recolour the Default Cryo shapes only. Do not touch the Frostblade, Frost Lotus, Snow Globe or Frost Dragon skins, the HUD, the callouts or the status reactions.

**Lessons from the Mint Rime and Deep Glacier checkpoints (apply from the start):**
1. The recolour must be on the **dominant visible colour**, not on a near-white highlight, or the wrap looks like Default.
2. The soft sites are easy to miss: ground discs, haze and fog, glow around rings, and particle ColorSequences. Recolour every one and list them.
3. The M1 shard, its head, trail and hit particles must stay clearly visible against sky and floor, at least as visible as Default.
4. Dark effects vanish on dark floors, and the Outline `#080E1A` is itself almost black, so dark fills can merge with the ink outline and lose the shape.
</context>

<design>
**Concept:** black ice, the dark, glassy, nearly black ice on a frozen lake. Dark in the middle, with frosty silver-blue light catching at the edges. Because of lesson 4, the gradient runs **dark core to bright edge**, so the bright edge carries the silhouette on dark floors.

**Palette (hex values are proposals; tune in-game and report what you changed):**
- Core tone (centre of an effect): Main `#1B2B45`, Shadow `#0F1828`
- Edge tone (outer edge): Main `#7EA3C2`, Shadow `#35506E`
- Highlight (shared, replaces IceLight): `#E4F1FA` cool white
- Accent (shared, small details only: crack lines, shard cores, particle cores): `#9BE4FF` pale ice cyan
- Unchanged: Rim `#FFFFFF`, Outline `#080E1A`

**Gradient rule (proposal, flag if it does not fit a given ability):** blend from the Core tone to the Edge tone by normalised distance from the effect's origin. Flash Freeze: zone centre to rim. Mirror Cage: the middle of the cage to its outer rings. Blizzard: centre to outer edge. M1 shard: the body goes from the tail (Edge tone) to the head, but **keep the head's glow and the trail core bright (Highlight/Accent)** so the shot stays easy to see. No pulse, no animation, no new emitters or particles.

**Colour risks to check and flag, not decide:**
- Core Shadow `#0F1828` is very close to the Outline `#080E1A`. If the shadow band disappears into the outline at on-screen size, lighten the Core Shadow and report it.
- Dark effects on a dark floor and on a light floor. Check both.
- Umbra is dark purple (`#4F2191`). Black Ice must not read as Umbra.
- Deep Glacier's navy Shadow `#172A7E` and Black Ice's dark core are both dark blue. They must be clearly distinguishable from each other.
- A dark haze or ground disc must never hide a player standing inside the effect more than Default's does (hit-honest).
- Do not use pink, magenta, gold or amber.
</design>

<quality_bar>
Black Ice is Rare, so at 30% on-screen scale it must look **clearly richer and more premium than Mint Rime and Deep Glacier**, not just darker. A plain dark recolour fails this bar. Use these colour-only levers (no new shapes, emitters, particles or animation):
1. **Visible depth:** the core-to-edge gradient must be obvious on every large piece (ring, cage rings and panels, Blizzard disc) without squinting. If a mesh cannot carry it, say so.
2. **Glassy glint edges:** put the Highlight and white band on the leading edges and tips of spikes, shards and ring rims, so each shape has a bright polished edge against its dark body. This is what makes black ice look glossy and expensive.
3. **Accent veins:** recolour the existing crack and ground-pattern lines in the Accent so they read as pale ice veins through the dark body. Recolour only what exists.
4. **Particles that glint and darken:** particle ColorSequences start bright (Highlight), pass through the Edge tone, and end in the Core tone, so the gradient runs through time as well as space. Counts stay identical.
5. **Ground disc and haze:** dark in the middle and frosted silver toward the rim, so the whole zone shows the gradient.

At the checkpoint, say per ability whether Black Ice looks clearly richer than both Uncommon wraps. Where it does not, say which lever is missing and what extra would fix it (for example a third gradient stop). Flag it, do not decide: the Rare tier is defined as a two-tone gradient with no animation, so anything beyond that is the user's call.
</quality_bar>

<instructions>
1. **Gradient feasibility (text only, 8 lines at most).** Can the existing palette-lookup carry a second palette and a per-site blend by distance, using only a data entry plus the smallest code in the wrap module and no mesh re-export? Say how you would do it for (a) meshes with baked bands, (b) particle ColorSequences (start colour to end colour), (c) ground discs and fog. If it **needs a mesh re-export, new UVs or a larger code change**, stop and describe the options with their costs, and wait for my choice. If it fits the smallest-change route, say so in one line and continue.
2. **Reuse the colour-site list** from the earlier wraps (meshes, emitter ColorSequences, hard-coded colours, soft fog, ground fills and glows for M1 Icicle Shard, Flash Freeze, Cold Momentum, Mirror Cage, Blizzard). Do not repeat the full survey.
3. **Add Black Ice as one data entry** (Core and Edge tones, shared Highlight and Accent, an id, the Rare tier) in the same place and format as the other wraps, plus the smallest blend code from step 1. Particle counts, geometry and timing stay identical to Default.
4. **Colour checkpoint (one image):** one sheet at on-screen size from normal 1v1 distance (30% scale like the earlier sheets), showing Default, Deep Glacier and Black Ice side by side for the M1 shard, the Flash Freeze zone, the Mirror Cage and Blizzard. Add Black Ice with the Colourblind-Safe setting on, and a dark-floor and a light-floor shot of Black Ice's Flash Freeze, Blizzard and M1. Then give, in two lines, the hue and lightness of the Core Main, Edge Main and Highlight next to Default's IceMid, Deep Glacier's Main and Umbra's purple, and say whether Black Ice reads as clearly different from Default and Deep Glacier, clearly richer than both Uncommon wraps (see `<quality_bar>`), readable on the dark floor, and not like Umbra. If it still looks too close to Default or the shadow band merges with the outline, say which band is the problem. Stop for approval. Do not wire it up yet.
5. After approval, wire Black Ice as a selectable wrap the same way the other wraps are wired. Add nothing else.
</instructions>

<rules>
Cosmetic only: no gameplay value, timing or hitbox changes, and visibility stays hit-honest. Colour only: no new shapes, no animation or pulse, no new particles or emitters (the extra effects belong to Epic and Mythic wraps). Rare means the two-tone gradient and nothing else. All emitters keep going through `emitter()`, so Graphics Quality, Reduce Enemy VFX and Reduce Flashing still apply. No kill effect, no HUD or status-reaction retint, no new callout words.
</rules>

<scope>
Only the Black Ice wrap on the Default Cryo shapes. Not in scope: Sakura Frost and Aurora, wraps on skins, and any HUD icon, health-bar or rarity change. Make routine judgment calls yourself and list them. Flag anything ambiguous instead of deciding it, and add nothing that wasn't asked for.
</scope>

<output_format>
Step 1: the short text note. Step 4: the checkpoint sheet plus the two-line colour note. Final report in a few lines: the data entry location, any code you added for the gradient, how many colour sites were recoloured, what was wired, and anything flagged (including how a skin could consume a wrap's palette later, without deciding it).
</output_format>
