# SPELLSHOT — Build Prompt #[N]: Cryo Wrap 4, "Sakura Frost" (Epic)

Continuation of the Opus 5 / Claude Code build sequence (previous: the Black Ice wrap; filename unknown).
This is visual/VFX work: real reference before styling, checkpoint before final.

<role>
You are adding the fourth Cryo wrap to SPELLSHOT, a Roblox PvP elemental-duel FPS, for the solo developer. A **wrap** never changes geometry, particle counts of the Default effects, timing or gameplay. "Sakura Frost" is the **Epic** wrap, the second-highest tier of the wrap ladder (Uncommon Mint Rime and Deep Glacier, Rare Black Ice, Epic Sakura Frost, Mythic Aurora). Epic = a core-to-edge **gradient**, plus a **slow glow pulse**, plus **a few sparkle motes** in the wrap's highlight colour (small glints on M1 impact, along the Flash Freeze zone edge, and at the caster's hands on cast). You are done when Sakura Frost recolours every Default Cryo visual the earlier wraps cover, has the gradient, the pulse and the sparkle motes, the user approved the colour checkpoint, and it is wired as a selectable wrap the same way as the others.
</role>

<token_budget>
Be efficient with tokens. One agent, no subagents. Use targeted searches and function-level reads, never whole-file or whole-repo reads. Do not re-survey the codebase: reuse the colour-site list and the wrap module (including the gradient code) from the earlier wraps. View at most three images in total: the sheet, a pulse and sparkle strip, and one close-up. Keep progress notes to a line and the report short.
</token_budget>

<context>
- Cryo's Default look: Blender meshes with three flat tone bands baked into per-face vertex colours (IceDeep `#0E4FA8`, IceMid `#3FB6F0`, IceLight `#D6F6FF`, Rim `#FFFFFF`, Outline `#080E1A`), plus an ink-outline hull, and particles that take colours through ColorSequences from the same palette.
- The wrap mechanism already exists (a separate module, one data entry per wrap, palette lookup, and the core-to-edge gradient built for Black Ice). Find the module and its format with one targeted search and extend it. Black Ice may still be in review: reuse its gradient code as it stands.
- `CryoFX.lua` is at Luau's 200 top-level-locals limit: add no new top-level locals. Put all new code in the wrap module.
- The code wins on how something works today, and the manual (v0.24) wins on what it should do. Say so in your report if they disagree.
- Wraps recolour the Default Cryo shapes only. Do not touch the Frostblade, Frost Lotus, Snow Globe or Frost Dragon skins, the HUD, the callouts or the status reactions.

**Lessons from the earlier wraps (apply from the start):**
1. The recolour must be on the dominant visible colour, not on a near-white highlight, or the wrap looks like Default. Bright tones need real saturation: pale, muted pastels read grey and cheap against the bright sky.
2. The soft sites are easy to miss: ground discs, haze and fog, glows around rings, and particle ColorSequences. Recolour every one and list them.
3. The M1 shard, its head, trail and hit particles must stay clearly visible against sky and floor, at least as visible as Default.
4. Airborne particles must never end dark: dark airborne sprites read as soot against the bright sky.
5. Check every site at the real 30% on-screen scale on sky, on a dark floor and on a light floor.
</context>

<design>
**Concept:** cherry blossom on frost. A luminous, glowing pink-ice look: rose at the core, pale blush toward the edge, a slow shimmer like light moving through petals. Cryo's angular crystal shapes carry its identity.

**Palette (hex values are proposals; tune in-game and report what you changed):**
- Core tone (centre of an effect): Main `#EE86B0` rose, Shadow `#A94B7E` dusty plum-rose
- Edge tone (outer edge): Main `#FFC4DA` pale sakura blush, Shadow `#D78FB3`
- Tip (third gradient stop): `#FFF3F8`
- Highlight (replaces IceLight, and the colour of the sparkle motes): `#FFE6F0`
- Accent (small details only: crack lines, ground-pattern lines, particle cores): soft lilac `#C9B6FF`
- Unchanged: Rim `#FFFFFF`, Outline `#080E1A`
- Pink is normally kept out of Cryo effects, because magenta `#E91E8C` is reserved for the Sparks Element. The user has explicitly chosen a pink wrap, so use **soft rose and blush only, never saturated magenta**, and show the Sparks Default effect next to Sakura Frost at the checkpoint so the two can be told apart.

**Gradient (same rule as Black Ice):** blend from the Core tone to the Edge tone by normalised distance from the effect's origin, reaching the full Edge/Tip colour by about 60% of the radius so most of the visible volume reads in the lighter tones. Particles and haze never end dark: they run Tip, Edge, then a rose Core only at their very end if at all.

**Slow glow pulse:** the existing glow elements (haze, ring glows, glow colours on existing emitters) breathe slowly: about one cycle every 2 to 2.5 seconds, a smooth sine of about plus or minus 15% brightness, drifting toward the Tip colour at the peak. No on and off flashing, no strobe. When Reduce Flashing is on, hold the pulse at its mid value (no animation). Drive it from the same per-frame loop as the gradient, only while a wrapped effect is active, and report the cost.

**Sparkle motes (extras, Epic only):** small glints in the Highlight colour, using **existing sprites only**: prefer Frost Lotus's petal or mote sprite if one exists (it ties Sakura Frost to the Lotus), otherwise the small star or glint sprite already in the project. Do not create new art. Three sites: (1) on M1 impact, a few motes; (2) along the Flash Freeze zone edge, sparse and spread over the zone's life; (3) at the caster's hands on cast. Budget (assumption, flag it): the extra emitters add no more than about +10 to +15% to Default's per-ability particle totals. Everything goes through `emitter()`, so Graphics Quality density, Reduce Enemy VFX and Reduce Flashing still apply, and the motes are pooled and short-lived. Report the counts per site against Default.

**Colour risks to check and flag, not decide:**
- Rose against Sparks magenta (`#E91E8C`): must be clearly distinguishable at 30% scale.
- Lilac Accent and plum Shadow against Umbra (dark purple `#4F2191`).
- Pink against a light floor and against bright cloud: check the contrast and keep the deeper rose Core and Shadow bands so the silhouette holds.
- Whether the sparkle sprites read as sparkles and not as noise at on-screen size.
- Whether Sakura Frost reads as the same family as Frost Lotus (see `<match_frost_lotus>`).
</design>

<match_frost_lotus>
The user wants Sakura Frost to match Frost Lotus (the Epic Cryo skin, built from luminous translucent angular crystal petals). Read this as a matching visual family, not as a wrap applied on the Lotus skin (if the brief seems to ask for that, flag it and do not build it). Do not change the Lotus skin.
- **Glow language:** with one targeted read, see how Frost Lotus's petals glow (material, transparency, glow colours) and match that feel on the Default shapes: luminous, bright, white-hot edges, a soft inner glow. No flat pink fill.
- **Blossom feel:** the sparkle motes use Frost Lotus's petal or mote sprite if one exists (see the motes rule), and the pulse should feel like a bloom breathing.
- **Colour harmony:** keep the same white-hot highlight whites and cool-white Rim as Frost Lotus, with rose and blush replacing its icy blue as the main colour. Adjust Tip and Highlight toward the same white as Lotus's highlights so the two look like they belong together.
- At the checkpoint, show one Sakura Frost frame (M1 or Flash Freeze) next to the same frame on Frost Lotus, and say whether they look like one family.
</match_frost_lotus>

<quality_bar>
Sakura Frost is Epic, so at 30% on-screen scale it must look clearly richer and more premium than Mint Rime, Deep Glacier and Black Ice as it stands, not just pinker. A flat pink recolour fails this bar. The gradient must be obvious on every large piece, bright glints on facet edges, the glow pulse must be visible without being distracting, and the sparkles must read. If it still looks no richer than the Rare wrap after you apply these, say which lever is missing and what extra it would need (for example a soft pearlescent material on solid bodies, the same route as Black Ice's material pass). Flag it, do not decide: the extras are capped by the tier table.
</quality_bar>

<instructions>
1. **Feasibility (text only, 10 lines at most).** Confirm the Black Ice gradient code can carry the three-stop gradient with a second palette. Say how the pulse will modulate the existing glow elements, and where the three sparkle sites hook in (the M1 impact, the Flash Freeze edge, the caster's hands on cast), including whether each event is visible to the wrap module today. If anything needs more than a small hook in the wrap module or a change outside it, stop and describe the smallest option, and wait for my choice. Otherwise say so in one line and continue.
2. **Reuse the colour-site list** from the earlier wraps. Do not repeat the full survey.
3. **Add Sakura Frost as one data entry** (Core and Edge tones, Tip, Highlight, Accent, an id, the Epic tier, plus the pulse and sparkle settings) in the same place and format as the other wraps, plus the smallest new code in the wrap module. Particle counts of the Default effects, geometry and timing stay identical; only the sparkle motes are new.
4. **Colour checkpoint (three images at most):** (a) one sheet at on-screen size from normal 1v1 distance (30% scale like the earlier sheets), showing Default, Deep Glacier, Black Ice and Sakura Frost for the M1 shard, the Flash Freeze zone, the Mirror Cage and Blizzard, plus Sakura Frost with Colourblind-Safe on, and on the dark floor and the light floor; (b) one strip with the pulse at its dim and bright points on Flash Freeze, and the three sparkle sites (M1 impact, Flash Freeze edge, hands on cast), with the Sparks Default effect and one Frost Lotus frame alongside; (c) one close-up of a cage panel, a spike and the M1 shard so I can judge the gradient and the glints. Then give, in two lines, the hue and lightness of Core Main, Edge Main and Highlight next to Sparks magenta and Umbra's purple, and say whether Sakura Frost is clearly richer than the Uncommon wraps and Black Ice, readable on both floors, and not mistaken for Sparks or Umbra. Report the particle counts of the sparkle motes against Default. Stop for approval. Do not wire it up yet.
5. After approval, wire Sakura Frost as a selectable wrap the same way the other wraps are wired. Add nothing else.
</instructions>

<rules>
Cosmetic only: no gameplay value, timing or hitbox changes, and visibility stays hit-honest (nothing may hide a player or projectile more than the Default effect does). No new shapes or geometry. The only new particles are the sparkle motes, from existing sprites, within the cap above. All emitters go through `emitter()`, so Graphics Quality, Reduce Enemy VFX and Reduce Flashing apply. No full-screen flash, no strobing, no kill effect, no HUD or status-reaction retint, no new callout words. No saturated magenta, no gold or amber.
</rules>

<scope>
Only the Sakura Frost wrap on the Default Cryo shapes. Not in scope: Aurora, wraps on skins, and any HUD icon, health-bar or rarity change. Make routine judgment calls yourself and list them. Flag anything ambiguous instead of deciding it, and add nothing that wasn't asked for.
</scope>

<output_format>
Step 1: the short text note. Step 4: the checkpoint images plus the two-line colour note and the particle counts. Final report in a few lines: the data entry location, the code you added for the pulse and sparkles, how many colour sites were recoloured, what was wired, and anything flagged (including how a skin could consume a wrap's palette later, without deciding it).
</output_format>
