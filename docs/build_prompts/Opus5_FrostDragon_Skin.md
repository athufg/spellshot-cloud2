# SPELLSHOT — Build Prompt #[N]: Cryo "Frost Dragon" Mythic Skin (in-world VFX and animation)

Continuation of the Opus 5 / Claude Code build sequence (previous: the Frost Lotus Epic upgrade; filename unknown).
This is visual/VFX/animation work: real reference before styling, checkpoint before final. The HUD icons are a separate prompt (`Opus5_FrostDragon_HUDIcons.md`). The avatar change is **not** part of this work (later).

<role>
You are building the Cryo "Frost Dragon" skin for SPELLSHOT, a Roblox PvP elemental-duel FPS, for the solo developer. It is the **Mythic** skin, the top of Cryo's cosmetic ladder (Uncommon Frostblade, Rare Snow Globe, Epic Frost Lotus, Mythic Frost Dragon), so every ability must look clearly better than the same ability on Frost Lotus, and Frost Lotus must stay clearly better than Snow Globe. The solo developer wants this to be the best skin in the game. You are done when every ability and the kill effect below are built in-game and the user approved each stage's comparison.
</role>

<token_budget>
Be efficient with tokens. One agent, no subagents. Use targeted searches and function-level reads, never whole-file or whole-repo reads. View at most two images per stage (a concept or silhouette sheet and an in-game comparison). Keep progress notes to a line and each stage report short.
</token_budget>

<context>
- **Name and status.** The skin was earlier called "Frost Drake" and is now **Frost Dragon**. Check with one targeted search whether a "Frost Drake" or "Frost Dragon" entry already exists in the skin registry. If it does, rename its display name to Frost Dragon and report its id (keep the id unless renaming it is trivial and safe). If none exists, register Frost Dragon as a Mythic Cryo skin in the same place Frost Lotus is registered, with no price or shop changes. Do nothing else in the registry.
- **Art direction.** The user does not want the comic look for this skin: "it should just look good". Build it in the style of **Frost Lotus**, which the user prefers: luminous, glowing, angular crystal, taken a clear level further. Read how Frost Lotus's pieces are built (mesh, material, transparency, glow) and extend that pipeline. Drop the ink-outline hull, flat tone bands and halftone for this skin. If Frost Lotus's pipeline breaks a project rule (for example opaque meshes), report it in one line and leave it as it is. Cryo identity stays: angular, faceted crystal, six-arm snowflake and hexagon motifs, never soft round blobs.
- **The dragon.** One consistent creature across the whole kit: a lean western dragon of glowing ice crystal. Overlapping faceted scale plates, deep blue shading toward pale ice on the belly, bright white edge highlights, a polished sheen. Horns and spine ridge are crystal spires. Wings have crystal bone arms and veined, softly glowing translucent membranes with a faint six-arm snowflake etched in them. Eyes are white-hot cyan. Cold mist at the jaw and claws. Cryo blues and whites only: **no gold or amber** (gold is the Ultimate UI colour `#F5B800`), **no pink or magenta** (`#E91E8C` is reserved for Sparks). Each ability uses a different part of the dragon so the kit feels like one creature.
- **Mythic ladder.** Mythic = everything Epic has, plus a kill effect, plus an avatar change. The HUD icons and the health-bar accent are separate work. **Do not touch the health-bar accent or anything that implements it** (a teammate builds it). Do not make the avatar change.
- **Mirror Cage facts.** A hemisphere of radius 20, rings of 14, 10 and 5, 12 bolts per enemy, a 1.6 s volley. Its gameplay geometry, radius, bolt count and timing never change.
- `CryoFX.lua` is at Luau's 200 top-level-locals limit: add no new top-level locals. Put new code in the skin's own module (find how Frost Lotus is wired and follow it) and make only the smallest hook if one is needed.
- Facts here come from design manual v0.24 and a project reference checked 2026-09-13. The code wins on how something works today, and the manual wins on what it should do. Say so in your report if they disagree.
</context>

<design>
Theme: **a living glacier, awake**. Each ability is a part of the dragon acting, with a clear signature moment. Everything below is a proposal; flag any item that conflicts with the current build.

**Shared base: the Frost Dragon model set (build once, reuse).** Head, a long segmented body (coil-able), claw, wing, tail tip, scale plate, spine crystal. Build the dragon in Blender with a simple rig or bone chain so the body can coil and unwind and the wings can flap, and drive it in Studio with CFrame or tween animation. One mesh set, many poses, pooled.

**M1, Icicle Shard: the Frost Wyrmling (must be cooler than Frost Lotus's M1).** Lotus's M1 is a glowing petal blade with a trail of petal motes that blooms into a small lotus on hit. The dragon's M1 must be a clear step above that, because each tier is cooler than the one below. The shot is a **compact spectral ice dragon**: a faceted head with open jaws and glowing eyes, with three or four small crystal body segments that undulate behind it in flight, a cold-breath wisp trail and a few scale-chip motes. On hit, the jaws **snap shut** on the impact point with a crack, then the head shatters into angular crystal shards with a small white-cyan ring puff (use existing sprites). It fires up to 3 times a second, so keep it to one pooled head, a few pooled segments and minimal particles. It must stay clearly visible in flight and hit-honest at the normal 1v1 distance, and during rapid fire it must still read as obviously cooler than Lotus's M1.

**Flash Freeze: the claw slam.** A dragon claw slams down at the zone's origin and a ring of tall, sharp crystal spines (like a spine ridge) rises around the zone across its expand time, with the glowing snow and mist field inside. On the shatter beat the spines shatter outward as spinning shards. Ring only, no dome over the rooted target. The rooted-target effect stays readable.

**Blizzard: two dragons, one on each side.** Two Frost Dragons flank the zone at opposite sides, rise out of the ground mist on the cast, and **flap their wings to blow the wind** across the zone. Wing beats are slow and powerful, about 1 to 1.5 beats per second (no strobing, so Reduce Flashing stays honest), and each beat pushes a gust of snow streaks inward. The flurry is thick, hard-edged crescent and streak shapes flowing across the zone from both sides, thin in the middle and heavier toward the edges. **Do not draw an open spiral** (that is Zephyr's logo); if two converging gusts start to read as a swirl, straighten them and flag it. The Frost Line stays clearly legible. The dragons stand at the Frost Line edge or just outside it, never in the middle, so Blizzard's screen obstruction must be **no greater than Default Blizzard's** and no player or projectile is hidden more than Default hides them. The existing settle-to-clear expiry tell stays: the dragons settle and dissolve into snow as the zone clears.

**Cold Momentum:** frosted claw prints and a few scale chips that drop and fade behind the player. Low count, pooled.

**Mirror Cage: the dragon curled around the cage (the headline, stage 1).** The **same Frost Dragon model as the standing dragon, scaled up uniformly** (identical proportions: torso thickness, neck length, head, legs, wings and tail taper; never a stretched neck or a thin snake body) lies curled in one big circle around the caster, bent into the circle by the rig, its whole body following the cage footprint with the tail tip tucked in near its neck. Its forequarters rear up so the head rises over the cage and **points down toward the centre from the space above**. Do not lengthen the neck to reach: if the head only reaches over the near rim, report how far it gets and flag it. Choose the uniform scale so the nose-to-tail length matches the circle (report the scale and the head height in studs). If that scale is too big for hit-honesty or the budget, flag the options instead of deciding. The 29 scale plates ride on the dragon and keep the cage's ring structure of 14, 10 and 5: 14 along its back and flanks in the ground ring, 10 on the raised wing membranes at mid height, and 5 on the neck and head crest at the top. On the cast beat the dragon curls into place from the outside in, the wings lift, the head arcs over last, the dragon holds the pose for the volley, and **each scale plate fires from where it sits as one bolt and is spent**, so the body thins out over the 1.6 s volley. Reuse the existing bolt flight path and timing from the current build and change only where each bolt starts. Any plates not tied to a bolt (few or no enemies) shed and fall at the end of the volley. At expiry the dragon roars (a white-cyan ring puff and a shatter of the remaining body into shards) and is gone. **Keep it hit-honest:** a player standing inside must be fully visible from outside at 1v1 distance, the dragon must leave gaps to see through (keep the body low at ground level, with raised legs, an arched back or a lifted wing where needed), the head must not hide the caster, and the caster's own nearby parts use `VFXLibrary.RegisterProximityFade`. At the stage-1 checkpoint show a player inside from three camera angles. The user chose this curled-dragon design over the alternatives, so build it as described.

**Deep Freeze (proposal, flag it, since the other skins leave it on the Default look):** the dragon's frost breath wraps the target in crystal that has dragon-scale facets. It must stay see-through enough that you can still see who is inside and the frozen state stays readable. The frozen-body colour logic stays as Default.

**Kill effect (the Mythic signature, stage 4):** on a kill, a ghostly ice dragon rushes through the victim, freezes them solid, and they shatter into crystal shards that drift upward like snow. Short (about 1.5 s), pooled, and it respects Reduce Flashing, Reduce Enemy VFX and Graphics Quality. First check how kill effects are implemented today (a hook, an event, who sees it). If no kill-effect system exists, stop and report the smallest hook you would add, and do not invent one.

**Animation.** The dragons themselves animate (coil, unwind, head tracking, wing beats, roar, settle) in the world layer. The existing cast beats stay: each Viewmodel and CastPose clip's `Trigger` equals `VFXLibrary.Tuning.<Ability>.LeadIn`, and the world effects land on that beat. Review in slow motion with `ShotTimeScale` and `CastPoseTimeScale`. Do **not** author new first-person or third-person cast clips yet. Instead, in your stage-1 report, propose in a few lines which new clips (for example a claw swipe or a roar pose) would add the most, and wait for the user's decision.
</design>

<rules>
- Cosmetic only. Parts are Massless, CanCollide false, CanQuery false, CanTouch false. No gameplay value, timing or hitbox changes. Visibility stays hit-honest: nothing may hide a player or projectile more than the Default effect does.
- Particles go through the `emitter()` helper so Graphics Quality density, Reduce Enemy VFX and Reduce Flashing apply. No full-screen flash. Pool anything that spawns repeatedly. Mobile low-end performance is real, and glow and transparency cost more than opaque meshes.
- **Budget (assumption, flag it):** Mythic may spend up to about 2x Default's per-ability triangle and particle totals as a starting cap. Measure Default and Frost Lotus first and report the new totals against both for each ability. Never exceed the cap without telling the user.
- Palette: Cryo blues and whites only. No magenta, no pink, no gold or amber. No new callout words. Keep the existing callouts and status reactions unchanged.
- Scope: no HUD icons, no health-bar accent, no avatar change, no wraps, no rarity or price changes beyond the registration step in `<context>`, and no new ability, word or mechanic.
- Reskin note (flag, don't decide): record how this skin's palette could be swapped later. Do not decide the approach.
</rules>

<instructions>
Work in stages. Do not start a stage until the user approved the previous one.

**Stage 0, concept sheet (before building):** show one concept sheet for the whole dragon: flat silhouettes (no colour detail) of the full body, the head, a wing, a claw and a scale plate, with the dragon next to a player model at on-screen size, plus the coiled Mirror Cage pose and the two-dragon Blizzard layout as small silhouettes. Stop for approval. After approval, add colour and glow and show it once more. Stop again. (The HUD icon prompt starts after the Stage 0 silhouette is approved. If the FrostDragon HUD icons exist by Stage 1, use them as the blueprint and check each in-world piece against its icon from the icon's camera angle.)

**Stage 1, Mirror Cage:** build it, then show one in-game comparison (new, Frost Lotus, Snow Globe, Frostblade) with a player inside, plus a three-frame strip of the cast (coils set, volley, bare and gone). Stop for approval.

**Stage 2, M1 and Flash Freeze:** build, then one in-game comparison against Frost Lotus, Snow Globe and Frostblade, including a rapid-fire M1 frame. Stop for approval.

**Stage 3, Blizzard and Cold Momentum:** same pattern, with Blizzard shown at 1v1 distance and from the side. Stop for approval.

**Stage 4, Deep Freeze and the kill effect:** same pattern. Stop for approval.

At each comparison, report anything where Frost Dragon still looks weaker than Frost Lotus, and anything you flagged.
</instructions>

<scope>
Only the Frost Dragon in-world effects above (and the registration step). Not in scope: the HUD icons, the health-bar accent, the avatar change, wraps, other skins, new cast clips (propose only), and any new ability, word or mechanic. Make routine judgment calls yourself and list them. Flag anything ambiguous instead of deciding it, and add nothing that wasn't asked for.
</scope>

<output_format>
After each comparison, a short report: what changed, new vs Default vs Frost Lotus triangle and particle totals, and anything flagged. A final report at the end of stage 4 in a few lines: files and modules, what is registered, and the open flags.
</output_format>
