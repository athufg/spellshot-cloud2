# SPELLSHOT — Build Prompt #[N]: Cryo "Frost Lotus" Rare Element Skin (Blender, world pieces plus the M1 hold-and-pluck animation)

Continuation of the Opus 5 / Claude Code build sequence (previous: `Opus5_Cryo_FrostbladeSkin_BlenderShowcase.md`; keep [N] as a placeholder).
**Quality bar: make it genuinely amazing.** A player must tell "Frost Lotus" from both Default Cryo and Frostblade in under a second at game distance, from the flat black silhouette alone. **And be very token efficient** (see the last section).

<role>
You are the VFX artist for SPELLSHOT, a Roblox PvP elemental-duel game, working for its solo developer, Sigma Boy. Task: design and render, in Blender, a full **skin** of Cryo (the ice Element) called **Frost Lotus**: the same real ice, but every piece of the kit is remodelled as a soft, curved, graceful ice **lotus petal**, with a beautiful sparkle layer on top. The developer reviews the look personally, so you build to the direction below and do not spend tokens judging or re-polishing it. Done means: the difference test below passed, one checkpoint approved, each piece rendered, and the handoff spec written.
</role>

<context>
**Vocabulary (the developer's).** A **skin** is a full rework of the ability's models and effect geometry, built in Blender. A **wrap** is a recolour of the existing shapes and is a different thing. This is a skin.

**Where Frost Lotus sits in the cosmetic ladder.** It is a **Rare Element Skin**: the Blender remodel plus **richer, more animated particle VFX** (the petal and sparkle signature). No HUD icons or health-bar accent, no kill effect and no avatar change; those belong to other Cryo skins, so do not design them. Design the sparkle layer so it can be switched off on its own, because it is the Rare layer.

**The lessons from the last two skins.** "Everfrost" kept Default's shape family and only changed material, and could not be told apart from Default. "Frostblade" changed the OBJECT (straight pointed kunai blades) and passed. So **the difference is the object, never the colour.** Frost Lotus must differ from Default AND from Frostblade in flat black. Frostblade is straight, hard, pointed, ninja-like (leaf-shaped lens panels, thin shafts). Frost Lotus is the opposite: **broad, rounded-shouldered, cupped petals with a gentle S-curve and a soft tip.** If a piece is not told apart in flat black, change its shape, never its colour.

**Cryo's kit as it is built today (the code wins over this summary; where they differ, say so in one line).**
1. **M1 Icicle Shard:** fast flat shot, low damage, stacks Chill. It fires about every 0.5 seconds (read the exact interval from `CryoTuning.lua`), more than anything else, and is conjured at the hand. It must stay the leanest effect.
2. **Primary Flash Freeze:** a ground zone; linger past 1 s and you are rooted, then shattered for heavy damage if still frozen when it ends. Enemies must read the zone edge at a glance.
3. **Passive Cold Momentum:** +10% move speed for 2 s after landing a hit. It already draws a thin frost print under each footfall, gone in about a second.
4. **Ultimate Mirror Cage:** a hemisphere of ice-mirror panels (three rings of 14, 10 and 5; ground radius 20) forms round a locked target, reflections step out of the panels, and 12 bolts per trapped enemy fire in a 1.6 s volley. The developer likes the cage: **no change to its layout, size, timing or windup.**
5. **Techniques Deep Freeze (a trap that freezes its target in a block) and Blizzard (a storm zone).** Read their footprints, timings and numbers from `CryoTuning.lua`; they keep all of them.

**Look.** Match the shipped Cryo "real ice" method (clear faceted ice with a glassy core, frost skin, inner glow; `ice_recipe` in the file named below). Palette: **pale ice-blue petals shading to white at the tips, with a deeper blue heart (`#1D6FB8`)**. The **Frost Line** (thin electric cyan `#3FE0FF`, flash `#8DF3FF`) runs as thin veins along the petal edges and stays the most saturated, brightest thing in the frame, never white. **No pink and no magenta `#E91E8C` (Sparks), no gold (Radiant: lotus stamens are cyan-white, not gold), no violet, teal-green, orange or red.** The `FROZEN!` burst stays as is. Only the HUD and callouts are flat comic; keep that out of the ice.

**Engine reality.** Buildable in Roblox later: meshes with Ice/Glass material and reflectance, an inner emissive mesh, neon trim, decals, particle sprites, beams and trails. No true refraction. Effects go through a shared emitter helper that scales with Graphics Quality and Reduce Enemy VFX; Reduce Flashing and Camera Shake are respected. Shape carries identity because the Colourblind-Safe toggle swaps Element colours.
</context>

<where_the_work_lives>
Read only these, and never edit the originals:
- `Opus5-5_Cryo_Rework_v2_RealIce_Blender.md` in the repo root: its `ice_recipe`, palette and the pieces for Icicle Shard, Flash Freeze, Cold Momentum and Mirror Cage.
- `roblox\CryoTuning.lua`: only the `Look`, `MirrorCage`, Cold Momentum, M1 interval, Deep Freeze and Blizzard tables, for the real numbers (including the Default's tallest Flash Freeze spike, the Default bolt width and the Default shatter's peak height).
- The Blender scripts from the Cryo v2 run. Find them first and say what you found; if a piece has no script, rebuild it from the ice recipe and say so.
- From the `cryo_frostblade_skin_2026_10_14\` folder (read-only): reuse only the **scene helpers** (camera, dummy, floor, flat-black and grayscale render helpers, and the character animation harness from the Cold Momentum run if it exists) to save tokens. Do not reuse any of its shapes. Also use its finished Frostblade renders as the second comparison in the difference test.
Create a sibling output folder `cryo_frostlotus_skin_<today's date as YYYY_MM_DD>\` with one subfolder per piece (script, mp4 or frame sheet, a game-camera still, stats). Import the shared kit; do not copy it.
</where_the_work_lives>

<pieces>
Shapes and numbers marked PROPOSAL are mine. Flag what you change in one line each.

**1. Icicle Shard (M1) becomes an ice petal dart.** A single broad curved ice petal with a gentle S-curve and a soft pointed tip, in place of the slender six-facet shard. Keep the Default's length class and release beat, and keep the visible width within the shot's hit width (hits count where the shot visibly passes). It trails two or three tiny petal motes plus the sparkle layer, and on impact a tiny bloom of petals opens with a few glints. State the triangle count (aim near the Default's; the shard must stay the leanest piece) and the particle counts.

**2. M1 hold-and-pluck animation (the developer's request).** The caster's off-hand holds an ice lotus bloom, and the throwing hand plucks one petal from it and throws it forward in **one very fast continuous motion**, so the M1's fire rate stays exactly what it is today.
- **Timing is law.** The petal's release frame matches the Default's release beat exactly, and the whole pluck-and-throw fits inside the Default's cast animation length, so it never delays or advances a shot. It must chain with no drift when M1 is held (shots every 0.5 s). The pluck is part of the throw, not a wind-up before it.
- **The held lotus** regrows the plucked petal instantly (a new petal unfurls with a glint), so it always looks full.
- **Which hand:** keep the Default cast's throwing hand as the throwing hand and give the other hand the lotus. Flag which hand that is.
- PROPOSAL: the held lotus appears with the first shot and folds into petals and sparkles about a second after the last shot, so it is not carried during other abilities. Flag it.
- **Third person:** build and render it on the character rig the project uses (check R6 or R15 first and say which). **First person:** a viewmodel version with the lotus in the off-hand and the petal pluck-and-throw, kept low in frame so it never blocks the crosshair or the view; the viewmodel arms stay bare skin (no frost, no glove, no Element colour); only the lotus and petal are ice.
- **Flag, do not decide, in one line each:** (a) this reaches onto the avatar's body, which the manual reserves for the Mythic tier, and the developer asked for it anyway; (b) the pose moves the off-arm from where the Default cast leaves it, and hits count where the body visibly is, so state how far the arms and torso move against the Default cast in studs, and stop and flag if it is more than a small amount.

**3. Flash Freeze (Primary) becomes a lotus bloom.** The zone is a lotus bloom opening on the ground, with layered petal rings unfurling outward as a wave. The zone's footprint, edge readability, timing and Frost Line ring stay exactly the Default's, with the Frost Line along the outermost petal tips. They are cosmetic with no collision and no taller than the Default's tallest spike. **When a target is rooted**, petals rise and half-close around its legs and torso like a bud, **with the head clearly visible and the target visible through the petals** (state the visible fraction against Default in game camera and ground camera). **The shatter payoff** keeps the Default's timing, damage beat and total fragment count: the bud bursts open into heavy irregular ice chunks, shards and frost powder that burst outward and fall with gravity inside the zone, and a few petals fall and fade low. **Nothing floats above the target's head, nothing rises higher than the Default shatter's peak,** and petal-shaped pieces are a small minority of the debris.

**4. Mirror Cage (Ultimate).** Dome layout, ring counts, radius, timings, windup and bolt count are unchanged. The three rings of 14, 10 and 5 become the **outer, middle and inner petal tiers of a lotus**:
- **Panels:** each panel keeps its position, orientation and footprint and becomes a **broad, cupped petal mirror**, tilted inward like a closed bud that opens as the cage forms, inside the Default's timing. They stay no larger than the Default panel. Their Frost Line edge stays the Default's bright cyan. Flag in one line if the petal shape opens visible gaps in the dome and show a dome view at game distance against Default.
- **Bolts:** each of the 12 bolts per enemy becomes a **thin spiralling petal lance** with the Frost Line along its leading edge, **no wider than about 1.5 times the Default bolt**, with the flight time and volley spacing unchanged. Keep triangles low (state them; there are 12 per enemy). It must read differently from the M1 petal dart (longer and slimmer).

**5. Cold Momentum (Passive).** Restyle the existing footfall prints as small lotus-bloom prints with a Frost Line rim and a couple of petals drifting up: same count, same size class, same life of about a second. Subtle by design, because it triggers on every hit.

**6. Deep Freeze and Blizzard (Techniques).** Footprints, timings and readability stay exactly as Default. **Deep Freeze:** the target is encased in a lotus bud of ice (the target stays visible, as in the Default), which breaks low and outward into ice chunks and a few falling petals, with the same no-floating rules as Flash Freeze. **Blizzard:** the storm is a swirl of ice petals and fine glitter instead of snow. It must not hide players or fight readability; cap and state the counts.

**7. The sparkle layer (Rare layer, the second thing the developer asked for).** Beautiful sparkling effects across the kit, built as two particle types: **dew glints** (tiny soft four-point star sprites that twinkle) and **ice glitter** (fine drifting motes that catch light). Use them on the held lotus, the petal dart's trail and impact, the Flash Freeze bloom wave, a soft shimmer sweeping across the Mirror Cage petals, the footfall prints, Deep Freeze and Blizzard. Rules: sparkles are pale white-cyan and low in saturation, never gold or pink, and never outshine the Frost Line; **soft fade in and out over at least about 0.3 s, never a hard flash, never strobing**; with Reduce Flashing on they become a steady soft glow instead of twinkling. They scale with Graphics Quality and Reduce Enemy VFX. They never whiteout or hide an enemy. The M1 gets only a small, capped number per shot (state it). Show the two sparkle types as one swatch on a dark and a light floor.
</pieces>

<difference_test>
This is the requirement that failed on Everfrost, so run it yourself **before** posting anything. For the petal dart, one Flash Freeze bloom with a dummy standing in it (before the bud closes), a mirror panel and a bolt: render **Default, Frostblade and Frost Lotus side by side** at game distance in colour, as a **flat black silhouette**, and in grayscale. Pass means a viewer can tell all three apart in each of those alone. If the black silhouettes of Lotus and Frostblade are not clearly different (watch the leaf-shaped panels especially), change the Lotus shape (broader, rounder, cupped), never the colour, and retest. Do not post a sheet that has not passed.
</difference_test>

<rules_that_do_not_change>
- **Cosmetic only.** Do not change damage, range, hitboxes, timing, fire rate or cooldowns. Keep every animation beat of Default (the one deliberate exception is the M1 pose in piece 2, with its flags); if any other model genuinely needs a pose change, stop and flag it.
- **Budgets.** For each piece, state parts, particles and lights against the Default's. This Rare skin **may** use more particles than Default (that is the Rare layer), but state the counts, flag the increase with a reason, and build everything to scale down with Graphics Quality and Reduce Enemy VFX. The M1 stays the leanest effect, and Squad Clash can have many players and frozen targets at once.
- **Readability.** No effect may hide an enemy or be less of a tell than the Default. The Default look stays untouched unless the skin is equipped.
</rules_that_do_not_change>

<checkpoint>
One checkpoint, one combined image, after the difference test has passed: the petal dart (near view and game distance), the Flash Freeze bloom with the dummy before and after the bud closes, a mirror petal and the three-tier dome view, a bolt, the M1 hold-and-pluck as a three-shot strip at the real 0.5 s cadence with the release frame marked (side and three-quarter views, plus the first-person viewmodel mock), and the sparkle swatch. Add one short mp4 of the M1 loop (not counted as an image). Stop and wait for approval. After approval, render every piece at full quality into the output folder, including the Flash Freeze shatter as a frame sheet, make one combined overview image, and write the handoff spec.
</checkpoint>

<handoff_spec>
A short spec for the later Roblox build, per piece: how Roblox fakes each look (materials, emissive inner mesh, trim, decals, particle sprites, petal meshes), its polygon and particle budget against the Default's, and which layer it belongs to: the remodel is the Base layer, the sparkles and extra petal particles are the Rare layer (switchable on their own), and the held lotus with the pluck-and-throw animation gets its own switch. For the M1 animation, say how Roblox does it (a throw animation on the Animator, the lotus prop attached to the off-hand, the first-person viewmodel hook) and how the release frame stays locked to the shot so fire rate cannot change. List the existing hooks the Studio build will use, **read-only, do not touch them**: `SkinCatalog.ElementSkins` (Radiant's Devil is the working example, with `Rework`, `Blurb`, `Label` and the `ElementSkin_<Element>` attribute), `SkinCatalog.Origin` and `Kinds`, and `CryoFX.ShardCast`, `ShardImpact`, `FlashFreezeSlam`, `Shatter`, `FrozenHold`, `ColdMomentumMark` and `MirrorCage`. **Important:** `CryoFX.lua` has hit Luau's limit of 200 top-level local variables, so all Frost Lotus code must live in its own separate ModuleScript that `CryoFX` calls into, the same way the Frostblade code was kept apart. Say so in the spec.
</handoff_spec>

<scope>
Not in this pass: Studio wiring, the skin catalog, the Loadout menu, HUD icons and the health-bar accent, any kill effect, any avatar change, Chill stack visuals, the `FROZEN!` burst, any other skin, the skin's price, and its final name ("Frost Lotus" is the developer's working name). Add nothing unrequested; flag anything ambiguous in one line instead of deciding it.
</scope>

<efficiency>
The developer asked for this to be very token efficient. One agent, no subagents. Read only the files named above and the one script for the piece you are working on, with targeted reads, and do not re-read a file after editing it. Copy scripts and make small targeted edits, not rewrites. Iterate at low resolution and with few frames; render at full quality only after the checkpoint is approved. At most two images in total (the checkpoint sheet and the final overview) plus the one short M1 mp4. Before your first tool call say in one line what you are about to do, give no narration between steps beyond that, and finish with a short report: what you built per piece, the stats against the Default's budgets, and everything you flagged.
</efficiency>
