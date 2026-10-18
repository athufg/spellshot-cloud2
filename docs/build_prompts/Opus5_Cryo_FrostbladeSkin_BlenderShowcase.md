# SPELLSHOT — Build Prompt #[N]: Cryo "Frostblade" Uncommon Element Skin (Blender, world pieces only)

Continuation of the Opus 5 / Claude Code build sequence (keep [N] as a placeholder).
**Quality bar: make it genuinely amazing.** A player must tell "Frostblade" from Default Cryo in under a second at game distance, from the flat black silhouette alone. **And be very token efficient** (see the last section).

<role>
You are the VFX artist for SPELLSHOT, a Roblox PvP elemental-duel game, working for its solo developer, Sigma Boy. Task: design and render, in Blender, a full **skin** of Cryo (the ice Element) called **Frostblade**: the same real ice, but every piece of the kit is remodelled as an ice **kunai** or blade. The developer reviews the look personally, so you build to the direction below and do not spend tokens judging or re-polishing it. Done means: the difference test below passed, one checkpoint approved, each piece rendered, and the handoff spec written.
</role>

<context>
**Vocabulary (the developer's).** A **skin** is a full rework of the ability's models and effect geometry, built in Blender. A **wrap** is a recolour of the existing shapes and is a different thing. This is a skin.

**Where Frostblade sits in the cosmetic ladder.** It is an **Uncommon Element Skin**: the Blender remodel only, with **the same amount of particle effects as Default Cryo** (no more). It has no Rare-layer particle extras, no HUD icons or health-bar accent, no kill effect and no avatar change. Those belong to other, higher-tier Cryo skins, so do not design them.

**The lesson from the last attempt.** A dropped skin ("Everfrost") kept Default's shape family and only changed material and palette, and three rounds could not make it read as different. So here **the difference is the OBJECT, not the material.** The ice stays the shipped Cryo real ice; the shapes become kunai. Identity: a **leaf-shaped blade with a centre ridge, a short tang and a small ring at the tail.** If a piece is not told apart from Default in flat black, change its shape, never its colour.

**Cryo's kit as it is built today (the code wins over this summary; where they differ, say so in one line).**
1. **M1 Icicle Shard:** fast flat shot, low damage, stacks Chill. It fires about every 0.5 seconds, more than anything else, and is conjured at the hand with no wind-up and no pick-up, so its replacement must be small, light and the leanest effect in the kit.
2. **Primary Flash Freeze:** a ground zone; linger past 1 s and you are rooted, then shattered for heavy damage if still frozen when it ends. Enemies must read the zone edge at a glance.
3. **Passive Cold Momentum:** +10% move speed for 2 s after landing a hit. It already draws a thin ragged frost print under each footfall, bright for a moment, gone in about a second.
4. **Ultimate Mirror Cage:** a hemisphere of ice-mirror panels (three rings of 14, 10 and 5; ground radius 20) forms round a locked target, reflections step out of the panels, and 12 bolts per trapped enemy fire in a 1.6 s volley. The developer likes the cage: **no change to its layout, size, timing or windup.**
5. The Techniques Deep Freeze and Blizzard are not part of this pass.

**Look.** Match the shipped Cryo "real ice" method and palette exactly (clear faceted ice with a glassy core, frost skin, inner glow; `ice_recipe` in the file named below). The **Frost Line** (thin electric cyan `#3FE0FF`, flash `#8DF3FF`, at the leading edge of spreading frost or growing ice, never white) stays exactly as Default's thin line. PROPOSAL: a thin cold-silver bevel along the blade edges to sell "blade"; flag it. No magenta `#E91E8C`. The `FROZEN!` burst stays as is. Only the HUD and callouts are flat comic; keep that out of the ice.

**Engine reality.** Buildable in Roblox later: meshes with Ice/Glass material and reflectance, an inner emissive mesh, neon trim, decals, particle sprites, beams and trails. No true refraction. Effects go through a shared emitter helper that scales with Graphics Quality and Reduce Enemy VFX; Reduce Flashing and Camera Shake are respected. Shape carries identity because the Colourblind-Safe toggle swaps Element colours.
</context>

<where_the_work_lives>
Read only these, and never edit the originals:
- `Opus5-5_Cryo_Rework_v2_RealIce_Blender.md` in the repo root: its `ice_recipe`, palette and the pieces for Icicle Shard, Flash Freeze, Cold Momentum and Mirror Cage.
- `roblox\CryoTuning.lua`: only the `Look`, `MirrorCage` and Cold Momentum tables, for the real numbers (including the Default's tallest Flash Freeze spike and the Default bolt width).
- The Blender scripts from the Cryo v2 run. Find them first and say what you found; if a piece has no script, rebuild it from the ice recipe and say so.
- From the old `cryo_everfrost_skin_2026_10_13\` folder (read-only): reuse only the **scene helpers** (camera, dummy, floor, flat-black and grayscale render helpers) to save tokens. Do not reuse any of its shapes.
Create a sibling output folder `cryo_frostblade_skin_2026_10_14\` with one subfolder per piece (script, mp4 or frame sheet, a game-camera still, stats). Import the shared kit; do not copy it.
</where_the_work_lives>

<pieces>
Shapes and numbers marked PROPOSAL are mine. Flag what you change in one line each.

**1. Icicle Shard (M1) becomes an ice kunai.** A leaf-shaped blade of clear ice with a centre ridge, a short tang and a small ring at the tail, in place of the slender six-facet shard. Keep the Default's length class and release beat, and keep the visible width within the shot's hit width (hits count where the shot visibly passes). Keep trail and impact particle counts at or below the Default's, and state both. It is the leanest piece: small enough to read at two per second. The Chill stack tells on the victim are not remodelled.

**2. Flash Freeze (Primary) becomes a ring of planted blades.** The zone's footprint, edge readability, timing and Frost Line ring stay exactly the Default's. PROPOSAL: kunai-shaped blades planted point-down at a slight outward lean along the zone edge, ring-pommels up, with the Default's flat frost patch inside. They are cosmetic with no collision, no taller than the Default's tallest spike, and must not hide an enemy standing in the zone (check it with a dummy at game distance). **The shatter payoff** keeps the Default's timing, damage beat and fragment count, and its fragments become small kunai-shaped shards. No new statue sequence.

**3. Mirror Cage (Ultimate).** Dome layout, ring counts, radius, timings, windup and bolt count are unchanged. Change two things:
- **Panels:** each panel keeps its position, orientation and footprint, and takes a **pointed blade-slab silhouette** (a leaf-shaped, ridged mirror blade) inside that footprint, no larger than the Default panel. Their Frost Line edge stays Default. Flag in one line if the pointed shape opens visible gaps in the dome.
- **Bolts:** each of the 12 bolts per enemy becomes a **long thin kunai-like lance** with the Frost Line along its leading edge. PROPOSAL: no wider than about 1.5 times the Default bolt, because twelve must stay readable. Keep the flight time and volley spacing.

**4. Cold Momentum (Passive).** Restyle the existing footfall prints as small crossed-blade nicks in the frost with the Default's Frost Line rim: same count, same size class, same life of about a second. Subtle by design, because it triggers on every hit.
</pieces>

<difference_test>
This is the requirement that failed last time, so run it yourself **before** posting anything. For the shard, one Flash Freeze blade ring with a dummy standing in it, a mirror panel and a bolt: render Default beside Frostblade at game distance in colour, as a **flat black silhouette**, and in grayscale. Pass means a viewer can tell which is which in each of those alone. If the black silhouettes are not clearly different, change the shape (never the colour) and retest. Do not post a sheet that has not passed.
</difference_test>

<rules_that_do_not_change>
- **Cosmetic only.** Do not change damage, range, hitboxes, timing or cooldowns. Keep every animation beat and pose of Default; if a model genuinely needs a pose change, stop and flag it.
- **Budgets.** For each piece, state parts, particles and lights against the Default's, and flag any that are higher with a reason. Frostblade must have **no more particles than Default**. The shard stays the leanest effect. Graphics Quality scales everything.
- **Readability.** No effect may hide an enemy or be less of a tell than the Default. The Default look stays untouched unless the skin is equipped.
</rules_that_do_not_change>

<checkpoint>
One checkpoint, one combined image, after the difference test has passed: the four pieces above, Default beside Frostblade, in colour, flat black and grayscale where listed in the difference test, plus a near view of the kunai. Stop and wait for approval. After approval, render every piece at full quality into the output folder, make one combined overview image, and write the handoff spec.
</checkpoint>

<handoff_spec>
A short spec for the later Roblox build, per piece: how Roblox fakes each look (materials, emissive inner mesh, trim, decals, particle sprites), its polygon and particle budget against the Default's, and that every piece belongs to the **Base layer** (this is an Uncommon skin). List the existing hooks the Studio build will use, **read-only, do not touch them**: `SkinCatalog.ElementSkins` (Radiant's Devil is the working example, with `Rework`, `Blurb`, `Label` and the `ElementSkin_<Element>` attribute), `SkinCatalog.Origin` and `Kinds` (Cryo has no entries yet), and `CryoFX.ShardCast`, `ShardImpact`, `FlashFreezeSlam`, `Shatter`, `FrozenHold`, `ColdMomentumMark` and `MirrorCage`.
</handoff_spec>

<scope>
Not in this pass: Studio wiring, the skin catalog, the Loadout menu, HUD icons and the health-bar accent, any kill effect, any avatar, Rare-layer particle extras, Deep Freeze, Blizzard, Chill stack visuals, the `FROZEN!` burst, any other skin, the skin's price, and its final name ("Frostblade" is the developer's working name). Flag in one line whether Deep Freeze and Blizzard should also become blades, and do not build them. Add nothing unrequested; flag anything ambiguous in one line instead of deciding it.
</scope>

<efficiency>
The developer asked for this to be very token efficient. One agent, no subagents. Read only the files named above and the one script for the piece you are working on, with targeted reads, and do not re-read a file after editing it. Copy scripts and make small targeted edits, not rewrites. Iterate at low resolution and with few frames; render at full quality only after the checkpoint is approved. At most two images in total: the checkpoint sheet and the final overview. Before your first tool call say in one line what you are about to do, give no narration between steps beyond that, and finish with a short report: what you built per piece, the stats against the Default's budgets, and everything you flagged.
</efficiency>
