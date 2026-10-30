<role>
You are rebuilding SPELLSHOT's social hub to feel alive and distinctly SPELLSHOT instead of static and generic. You work for the game's solo owner-developer. The hub has four wings, each tied to one of the game's four primary Elements — Duels = Zephyr, Loadout Altar = Terra, Training = Aqua, Store = Pyro — arranged around a central plaza. Done means: each wing's elemental decor is real and animated (not a flat decal), the Loadout wing actually has a Terra identity (it currently has none), the whole hub has a layer of constant ambient motion, two new NPCs replace the current silent altar/counter prompts, a rotating cosmetic showcase pedestal exists near the Store, and (if time allows within this pass) a leaderboard and duel-queue pads add visible competitive presence. Checkpoint everything with screenshots/clips in both idle and triggered states; nothing goes onto a live/selectable list or gets called final until the owner reviews.
</role>

<context>
**Current problems, confirmed from footage.** The entrance "waterfall" and the Training-wing water pillars are a static glow beam with painted droplet decals, not moving water. The Store's fire torches are flat 2D flame cutouts with no flicker or embers. The Loadout wing has zero Terra identity — generic neon pillars and decorative plants only. Fire and water props have bled across wings in places (water columns appearing near the Store), which dilutes each wing's identity, so confirm each wing reads as exactly one Element's decor before moving on. Interact prompts currently use the default Roblox ProximityPrompt look in some places; the existing "G — Loadout Altar — Choose Techniques" style (dark pill, bold label, key icon) is SPELLSHOT's established custom prompt style — match it for every new interactable rather than introducing another look. The existing "REACTIONS" board (white/parchment background, bold black outline, comic-panel feel) is the house style for in-world information panels — match it for the new leaderboard rather than a glossy esports-style card.

**Element identity colors (base / light / dark), confirmed:**
| Element | Base | Light | Dark |
|---|---|---|---|
| Pyro (Store) | #F25C0D | #FFC74D | #6B1708 |
| Terra (Loadout) | #826B24 | #CCBA5C | #33210D |
| Zephyr (Duels) | #4FD1C5 | #FFFFFF | #125C59 |

Aqua (Training) isn't in this table — pull its identity color from your own current `AquaWrap.lua` rather than guessing one.

**Explicitly out of scope this pass:** sound/SFX (the owner is doing audio separately later), training dummy damage-state visuals, and any branching NPC dialogue system — the two new NPCs get a single directional prompt straight into the existing menu, not a conversation.

**Respect `SpellshotSettings.EffectDensity`** for every new particle/glow effect this pass adds, consistent with the rest of the project (thinner on LOW/MEDIUM, fuller on ULTRA).
</context>

<instructions>
**1. Fix each wing's elemental decor so it's real and animated, not a static decal.**
- Pyro/Store torches: replace the flat flame cutout with genuine flicker (animated shape or particle-based flame), add drifting embers, use Pyro's hex table above.
- Aqua/Training water (both the entrance feature and the Training pillars): replace the static glow-beam-with-decals with actual moving water — a flowing cascade, foam/splash where it hits the basin, ripple rings expanding outward. Use Aqua's real identity color from `AquaWrap.lua`.
- Terra/Loadout: build a real identity from scratch. Give the Loadout archway its own signature shape the way Duels has its crescents — a cracked stone arch with an embedded crystal cluster, rough-cut rock pillars instead of smooth neon ones, Terra's hex table above. Add one ambient loop: slow pebble-trickle down a stone face, or a pulsing light vein through the crystal.
- Zephyr/Duels crescents: add motion — a drifting air-current ribbon curling around them, a few leaves/light debris caught in a slow loop, subtle banner sway.
- Audit all four wings for cross-contamination (e.g. water props near the Store) and relocate anything that isn't that wing's own Element.

**2. Add an ambient-motion layer across the whole hub.**
- A soft colored light pool on the floor at each wing's archway, tinted to that wing's identity color, so the wing is identifiable from across the plaza.
- A small idle elemental wisp/mote drifting near each archway, in that wing's color.
- A reaction-cycling centerpiece: the existing central crystal/halo should slowly cycle through pairs of two wings' identity colors swirling together, then flash into that pair's Reaction color per the existing Reactions chart, looping continuously.
- Animated directional floor arrows (chevrons) along the main entry corridor — currently the emptiest stretch of the hub — in the existing ceiling-trim yellow (not a new color), pulsing in sequence toward whichever wing they point to.

**3. Build two new interactable NPCs, no dialogue trees.**
Both are standard Roblox avatar-proportioned mannequins (reuse the existing rig; build only custom clothing/accessory meshes), each with an idle loop, a short greet animation that plays on proximity before the prompt appears, and the house-style prompt box re-targeted to fire on the NPC's own proximity instead of the altar/counter object (the altar/counter remain as set dressing).

Build pipeline for both: model the mannequin's custom accessories (robe/apron, hood, held prop, etc.) and author both animations (idle loop, greet) in Blender, rigged to the same skeleton/bone structure as the Roblox avatar rig so the animation data maps cleanly on import — don't model in Blender and then hand-rebuild the animation inside Roblox Studio from scratch. Export accessories as meshes (FBX/OBJ as appropriate) and export the animations as FBX with the rig, then bring both into Roblox Studio: import the accessory meshes as MeshParts/accessories fitted to the rig, and import the animation via Studio's animation import (Animation Editor or the Moon Animator / bulk-import path you already use for this project, matching the pipeline from the Scorpion kit's Blender animation pass) so the idle and greet clips play on the NPC in-engine exactly as authored in Blender, not reanimated by hand in Studio.
- **Loadout Keeper** (Terra-flavored): stone-grey/mossy robe, hood, a chest accessory with a subtle rune/crystal inlay, a held prop (floating rune-tablet or shard-staff). Idle: subtle body weight-shift/sway plus the prop rotating slowly or pulsing. Greet: head turns toward the player, prop flares brighter. Stands beside/behind the altar. Prompt: "G — Loadout Altar — Choose Techniques" (same text/behavior as today, just NPC-triggered).
- **Shop Merchant** (Pyro-flavored): rust-red/bronze apron or vendor coat, a satchel or small lantern prop carrying a faint ember glow. Posture more animated than the Keeper's (e.g. leaning on the counter). Idle: weight-shift plus the lantern/satchel swaying. Greet: head turn, prop glow flares. Prompt: matches the Store's existing menu entry.

**4. Add a rotating featured-wrap showcase pedestal near the Store.**
A mannequin/bust on a stone/crystal plinth matching the hub's existing pillar material, cycling through a short rotation of finished wraps (e.g. Phoenix, Meteorite Core, Prism Bloom — use whichever are flagged live-ready). The plinth's glow color matches whichever wrap is currently displayed. A floating nameplate below shows the wrap's name and rarity-tier color.

**5. If time allows within this pass, add a leaderboard near Duels.**
A wall-mounted plaque styled identically to the existing REACTIONS board — same parchment/black-outline comic-panel look, not a glossy esports card. Shows top duelists (name, primary-Element icon, win count or rating), refreshing live. Flag clearly in your report if this needs backend/data wiring beyond this pass's scope rather than shipping a half-working version.

**6. If time allows within this pass, add duel queue pads with a VS card, in the Duels wing.**
Floor pads that light up in each queuing player's own primary-Element color (not an arbitrary team color). On match found, a VS card in the same comic-panel style shows both players' names, Element icons, and equipped technique icons. Flag the same way as the leaderboard if backend wiring is beyond this pass.

Leave every ability's timing, damage, range and hitbox values, and all existing menu functionality, untouched — this is environment, NPC and UI work only.
</instructions>

<output_format>
- One line before you start.
- Checkpoint screenshots/clips per wing (before/after), per new NPC (idle + greet + prompt triggered), the showcase pedestal (cycling through at least two wraps), and the leaderboard/queue pads if built.
- A short report: what was built, what was flagged as needing backend/data wiring beyond this pass (if anything), and confirmation nothing is live/selectable yet.
</output_format>

<edge_cases>
- If the leaderboard or queue pads would need real match/rank data that doesn't exist yet, build the visual/UI shell, flag what's missing, and don't fake live data.
- If any new ambient light pool or wisp makes an archway's interact prompt harder to read, pull the effect back rather than letting polish hurt usability.
- If Terra's new signature shape starts resembling another wing's archway too closely, differentiate the silhouette, not just the color.
</edge_cases>

<tone_preference>
Keep the report plain and factual — what was built, what's flagged, the evidence.
</tone_preference>
