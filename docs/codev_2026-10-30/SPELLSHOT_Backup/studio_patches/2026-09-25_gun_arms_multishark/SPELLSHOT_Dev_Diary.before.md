# SPELLSHOT — Dev Diary

**What this file is.** The Design Manual (`SPELLSHOT_Design_Manual.md`) is the *locked-state* record — what's true right now. This file is the *decision* record: why something landed where it did, what got tried and rejected first, and what's still genuinely open — the stuff a version-note summary compresses away and a compaction summary can lose outright. Read this fresh every session, same rule as the manual. New entries get appended at the bottom, newest last, dated. Don't rewrite old entries; if a decision changes later, say so in a new entry and leave the old one standing so the "why" trail stays intact.

This file started 2026-09-24, prompted directly by a real miss: an Aqua design-collaboration session ran long, hit a context compaction, and came back out the other side missing Aqua's M1 entirely — every other ability survived the summary, that one didn't. Everything below from that date is backfilled from what's still known; going forward, entries get written as decisions happen, not reconstructed after.

---

## 2026-09-24 — Elemental Application (status effects) + HUD, locked

Resolved the two explicitly-flagged blocking questions that had been open since v0.9: whether Voltaic/Terra get their own statuses (yes — **Charged**, **Cracked**), and what Zephyr gets (nothing, deliberately, to avoid forcing a "nonsense combination"). HUD resolved as world-space head cluster + screen-space top-third dual display (own + target's statuses), both full comic pop-art even though Charged/Cracked come from grounded-styled abilities — that split is deliberate, not an oversight.

Wrote `Opus55_ElementalApplication_StatusHUD_AuditGate.md` for this — first draft was mislabeled "Opus 5" and used the wrong template; corrected after being told directly to use the Opus 5.5 prompting structure (`/opus-5-5-prompt-writer`). Locked into manual v0.13.

Also proposed an update to the `spellshot-vfx-comic-prompt` skill reflecting the two-track visual system below — shown as a review card, save status not confirmed as of this writing.

## 2026-09-24 — Ability VFX two-track system, as actually confirmed in Studio

The manual's Section 0 describes the grounded baseline from watching a render. Two real audits since then nailed down the actual Roblox construction, and it's worth keeping the distinction straight:

- **Track 1 (grounded)** — Terra's Boulder Shot, audited directly (`ReplicatedStorage.IceMagic.TerraFX` / `TerraM1`): opaque MeshParts ("cells"), `SmoothPlastic`, white `Part` color, baked vertex color (tone + AO), `CastShadow` on, no outline hull, lit by the scene's real sun/fill light. One accent: thin crack/seam parts switched to `Neon`, ramped stone → gold → white, tied to charge tiers. No transparency anywhere.
- **Track 2 (comic)** — the pre-v0.9 default, kept for UI/HUD/kill-effects/status icons: flat vertex-color fills, real inverted-hull outline shell, opaque.
- **Cryo's grounded rebuild** (proposal stage, `cryo_grounded_2026_09_24/Cryo_Grounded_Direction_Note.md`) confirmed the same Track 1 recipe holds for a second Element, plus the one ice-specific addition — a slightly glossy SurfaceAppearance (roughness ~0.3–0.4) for facet glints, not a glow. Palette pass v2 corrected v1 for being under-saturated (measured against the Terra film: rock median saturation 0.42, gold glow 0.52; Terra's shipped palette 0.55–0.75; Cryo v1 sat around 0.16, v2 brought it to ~0.64).
- **Named per-Element signature accents so far**, each reading a different way on purpose:
  - **Terra's crack** — reads by *intensity* (brighter = more charge).
  - **Cryo's Frost Line** — reads by *position* (shows how far a freeze/gauge has reached; goes dark when done, inverted from Terra's logic).
  - **Aqua's Tideline** — reads by *motion* (glow rides the leading edge of whatever's currently moving; dies when motion stops). See below.

## 2026-09-24 — "Pitch me AQUA. Movesets and everything."

Explicitly overrides the earlier handoff instruction that Elements beyond the launch 8 were fully deferred. Went through a full pitch → iteration cycle, several ability names changed or got cut entirely along the way — recording the dead ends here so nobody re-proposes them cold:

- **Original Undertow** pulled the enemy *to the caster*. Flagged as disadvantageous for a non-tank Element (you're handing the enemy a free position on top of you). Fixed by having the pull target the vortex's *own center point* instead — caster stays where they are, target gets displaced to a spot, not into melee range. Kept the "quick" pacing (fast cast, snaps shut) per direct request, and kept the original circular-hand-motion visual (inspired by a user-supplied video reference — an unrelated underwater film scene used only for the gesture, not reproduced or described in detail) throughout every mechanic revision.
- **Original Ultimate ("Maelstrom"/described informally as "whirlpool")** — too close to Zephyr's Cyclone (both funnel-pull tornado-shaped effects). Replaced with a twin-tsunami-walls-closing concept per direct request ("2 large tsunamis from either side closing in, obviously not jumpable").
- That twin-tsunami concept later got **demoted from Ultimate to a Technique** ("Twin Tide") when a new Ultimate idea landed: a ground-slam that summons a fish-tank/shark structure. Locked as **Leviathan's Maw** once described ("you slam the ground with a big fish tank").
- **Working Technique "Geyser"** (an invisible proximity trap) — too close to Cryo's Deep Freeze, same "invisible until it triggers" verb. Cut outright, does not appear in the locked kit.
- **Working Technique "Riverbed"/"Slick Lane"** (a slick-ground zone technique) — too close to Cryo's Blizzard. Resolved by moving its slip effect onto the **Passive** instead (an enemy who crosses your wet trail slips — loses turn control briefly, doesn't fall) and dropping Riverbed entirely once Twin Tide filled that Technique slot.
- **The water-gun idea** ("hold a gun made of water, tap or hold, more mana on hold") started as a replacement for the cut Geyser technique, went through a working name "Spout," and landed as **Sidearm** — confirmed the *held/charged* shot is the one that knocks the target back/up on impact, not the tapped one.
- **M1 was never actually re-confirmed in writing during the iteration passes** — it survived untouched from the original pitch, which is exactly why it went missing across the later compaction (nothing flagged it as "still decided," so the summary had nothing to point at). Re-confirmed directly 2026-09-24: **Riptide**, a crescent of whitewater surged along the ground.

**Aqua's kit, locked 2026-09-24** (also now in the manual, Section 2, v0.14):

| Slot | Name | Mechanic |
|---|---|---|
| M1 | Riptide | Crescent whitewater ground-surge, aim-required skillshot |
| Primary | Undertow | Vortex at a point in front of you, pulls to its own center (not the caster), interrupts, quick |
| Passive | Riding the Current | Speed buff riding your own wet trail; enemies crossing it slip (lose turn control briefly) |
| Ultimate | Leviathan's Maw | Ground-slam → rising flood → glass-walled tank closes overhead, shark lunge finish |
| Technique | Twin Tide | Two lower/narrower wave-walls close in on a lane, not jumpable |
| Technique | Sidearm | Held water-gun, tap/hold-charge, charged slug knocks back/up |

Archetype: **Control/Zone** (joins Cryo, Toxin). Visual direction: **Track 1 grounded**, confirmed explicitly — not the comic track, despite Aqua being a fresh design rather than a rebuild.

**One open fragment, not resolved, noted so it isn't lost:** at one point the user said Twin Tide's walls are "obviously not jumpable, only M1 can be jumped" — the second half of that sentence was never clarified (jumped *over*? jumped *through*? comparison to something else in the kit?). Not treated as blocking the build prompt; flagged here and in the build prompt itself for a tuning-pass confirmation later.

## 2026-09-24 — Leviathan's Maw: glass vs. the no-transparency rule

The manual's no-transparency rule (Section 0, locked v0.8, restated as project-wide v0.10) says real transparency was tried once on the project's most prominent effect and reverted for reading "weak and insubstantial" — and explicitly isn't a direction to try again anywhere in the project. The user wanted the tank visibly see-through from outside. First proposal (mine): keep the walls opaque, fake the read with a backlit silhouette projected on the inner surface. User pushed back, restating the ask more firmly ("so glass"). Given this was a real, expensive-to-redo fork with a genuine tension against a locked project rule, asked directly rather than guessing: offered real cutaway viewing-windows (opaque tank, actual removed-geometry portholes, zero Transparency property used — same family as Mirror Cage's panel-gap technique) as the recommended option, literal glass as an explicit rule exception, or the backlit-silhouette compromise as a third option.

**Decided: literal glass.** Confirmed directly as a deliberate, scoped one-off exception — it does not reopen the no-transparency rule anywhere else in the project, and any future ask for real transparency elsewhere still needs its own explicit sign-off, not a precedent pulled from this one. Written into the manual (v0.14 changelog + Aqua's kit entry) exactly that way, so nobody downstream mistakes it for a policy change.

## 2026-09-24 — Aqua's Tideline, full per-ability treatment (as given, verbatim intent preserved)

The signature accent across Aqua's whole kit: wherever her water is actively moving, the leading edge glows bright teal-white; the instant it stops moving, the glow dies. Not charge-level (Terra) or position/countdown (Cryo) — motion. Per-ability:

- **Riptide (M1):** chunky opaque whitewater crescent, foam-white crest → teal-blue body → darker slate-teal trough, all baked vertex color, no shading tricks. Tideline rides the front lip of the wave — that's where the hit currently is.
- **Undertow (Primary):** vortex built from orbiting droplet-shaped low-poly water-shard chunks (not a flat ground effect). Tideline traces the vortex rim, flares bright the instant the pull snaps, then the whole thing blows apart into hard-edged mist chunks (no soft glow puffs — stays within the no-transparency/no-glow-shader rules). Reads as almost one motion.
- **Riding the Current (Passive):** small foam splashes at the feet each step while buffed; the wet trail's edge carries a dim, ambient Tideline (deliberately not bright — not a payoff moment, just makes the buff visible on the ground instead of purely a stat).
- **Leviathan's Maw (Ultimate):** ground-slam kicks up debris/spray, flood rises, wave-wall ring closes overhead with bright Tideline around the whole rim. The shark is mostly a fast dark shape under the flooded floor — fin and full model only break the surface right before the lunge. The bite is the one loud beat allowed: bigger Tideline flash, foam burst, teeth. Everything else in the kit stays comparatively restrained so this lands as the biggest thing she does.
- **Twin Tide (Technique):** same wave-wall material as Riptide, two of them, lower/narrower, Tideline on each leading face, closing on a lane; sharp flash where they collide.
- **Sidearm (Technique):** held, chunky coiled-water construct; Tideline lives at the muzzle and brightens as it charges, so charge level is readable at a glance. Fires a dense solid slug (not a spray) — small splash-burst and knockup on impact.

## 2026-09-24 — Wet (Aqua's Elemental Application status)

Proposed, not yet confirmed by playtest but design-consistent: stacks from Riptide (M1) hits (same assumed pattern as Charged/Cracked, flagged for confirmation same as those two). Standalone climax at max stacks: brief loss of turn/steering control — deliberately reuses the "slip" flavor already established in Riding the Current instead of inventing an unrelated mechanic. Same 5s-refresh duration model as the other stacking statuses. HUD icon needs a shape distinct from Poison's drip (both are liquid-themed) — proposed a wave/ripple-crescent shape echoing Riptide, flagged for confirmation in the build prompt rather than locked here.

Two candidate Reaction pairs flagged for a later pass, deliberately not added to the Reactions table yet (per that section's own one-pair-at-a-time process rule): **Conductor** (Aqua × Voltaic — water conducts electricity) and **Steam** (Aqua × Pyro — extinguishes Burn, vision-denial cloud).

## 2026-09-24 — Two Opus 5.5 build prompts written

`Opus55_Aqua_Element_Build.md` (full Element, all 6 abilities + Tideline, Track 1, the glass exception) and `Opus55_Wet_ElementalApplication_Build.md` (extends the existing status/HUD system, references the earlier audit-gate prompt as a dependency). Both delivered to the project folder and via chat.

---

*(Append new entries below this line, dated, as decisions happen — don't wait for a natural stopping point.)*


## 2026-09-24 — Aqua build, Phase 1 audit answered (slip, Twin Tide height, placeholders, order)

After the Aqua build prompt's Phase 1 audit, the owner settled four things:

- **What "slip" means** (Riding the Current, and the flavour Wet reuses): *"it should be very hard to walk, u can still walk but its more like that its tough to redirect yourself but you still can."* So slip is **low traction**, not a lock: momentum carries you and changing direction is slow and heavy, but you keep control. It is neither a skid with the keys ignored nor a camera lock. It has to run on the victim's own client, because movement is client-owned.
- **Twin Tide's walls are 13 studs tall** ("slightly smaller"), solid, and not wall-runnable. A ground jump plus the double jump rises about 13.7 studs, so a perfectly timed double jump can just clear a 13-stud wall; Gust Jump can too. Noted, not changed.
- **Aqua's logo and HUD slot icons:** placeholders are fine until the real UI art is made.
- **Order: wait.** Aqua's Phase 2 waits until the Wet status build has finished, so the two passes don't edit the status system at the same time.

Audit findings that shape the build, in short:
- The live Track 1 kits draw their VFX meshes with shadows off.
- The Glass material hides every transparent part and particle behind it, so the Leviathan's Maw tank walls will be transparent SmoothPlastic, never Glass.
- Semi-transparent walls cast solid shadows, so the tank walls have shadows off.
- The existing FX clone helpers force opacity, so the tank needs its own path.
- Frost Slide's old code freezes on contact rather than slipping; only its trail-contact pattern is reused.

## 2026-09-25 — Aqua build, Phases 2–3: mechanics live, VFX rebuilt in Blender

- **Mechanics (Phase 2) are in the game and tested live** against the training dummies: Riptide (12 a body, pierces up to 4, a jump clears it), Undertow (pulls to the vortex's own centre and interrupts), Twin Tide (a 35 crush where the walls meet), Sidearm (12 tapped, 30 fully charged, only the charged slug launches), Leviathan's Maw (a 65 bite on the trapped enemy nearest the centre, 25 to everyone else inside) and Riding the Current (+25% on your own wet ground; an enemy on it slips for 0.8 s and takes about a second to change direction). Every hit that Riptide lands fires one hook, which the separate Wet status build will use.
- **The first visual blockout was rejected.** It used plain Studio boxes, and the owner said *"These were supposed to be detailed and done in blender, so as to avoid the blocky design"*, then *"stick to the visual design mentioned in prompt as also as the other elements are (cryo and terra)"* and *"make sure the water gun has like water drops dripping"*.
- **So every Aqua piece is now a Blender mesh kit** in the Cryo/Terra construction: chunky faceted water, baked colour and ambient occlusion, real light, shadows on, and the Tideline as its own glowing mesh on the leading edge. That makes 60 meshes (39k triangles for the whole kit), and the water gun drips from four points under it. The Maw's walls and roof are still the only see-through thing in Aqua's kit.
- **Lesson:** six Blender processes rendering at once crashed the computer twice, so Blender work now runs one process at a time.

## 2026-09-25 — Undertow's vortex, corrected: open ring, swept into being, not already spinning

A new reference clip (a different unrelated film scene from the one that inspired the original circular-hand-motion cast, used the same way — only its VFX shape language, not reproduced or described beyond that) showed a different formation than what Phase 3 actually built. Analyzed frame-by-frame: a point of light appears away from the body, the hand sweeps an arc and the light trails behind it as it's drawn, the trail gathers into a large glowing ring with the caster near its centre, then the ring blooms outward into a full release, leaving a glow afterimage hanging in place.

**Correction from the owner: the ring in the reference is not a closed 360° loop — it's left open, an incomplete arc, not an "O."**

What this changes versus the current built Undertow (`aqua_phase3_2026_09_25/blender_aqua_ut.png`: 16 droplet shards in 4 tightening rings forming a closed column over a closed circular pool/rim, already spinning CCW when it appears, snap at t=0.6s, blows apart into mist by t=0.85s):
- **Formation should be swept, not pre-spun.** The vortex should read as drawn into existence by the cast's circular arm motion — matching the very first description of this move ("your hand does circular motion") more literally than the current "already orbiting when it appears" build does. Tideline riding the leading edge of that sweep as it's traced is actually a cleaner fit for Tideline's own motion-reads rule than a column that's already spinning when you first see it.
- **The ring reads as an open structure, not closed** — a gap in the loop, like the sweep stops short of a full circle, rather than the current build's fully closed rim/column.
- **Everything else about Undertow stays**: the pull-to-the-vortex's-own-centre mechanic (locked, live in Phase 2), the snap/interrupt trigger, the blow-apart-into-mist-chunks release, keeping it a Blender mesh kit in the Cryo/Terra faceted construction (not the rejected plain-box approach).
- **Genuinely open, not resolved here:** which specific piece goes from closed to open — the ground-level pool/rim, the vertical column's own cross-section, or the whole silhouette read as one swept shape. Best guess, not locked: the ground rim is the most literal "ring" in the current build, so that's the one most likely meant — flagged for the build agent to show at a checkpoint rather than guessed silently.

New scoped patch prompt written for this: `Opus55_Aqua_Undertow_Ring_Refinement.md` — VFX-only, doesn't touch Phase 2's mechanics, told explicitly to work from the actual current Blender kit and this diary rather than the original (now superseded in places) `Opus55_Aqua_Element_Build.md`.

## 2026-09-25 — Undertow swept open (checkpoint), Sidearm draw + rapid fire, splashes on everything

**Undertow's vortex, built as the correction asked — Blender checkpoint only, not in the game yet** (`aqua_ut_open_2026_09_25/`). What was there first: the Blender source had already moved past the faceted build this diary describes. It was the lighter, smooth-shaded restyle (Blender-only; the game still runs the first kit), and the column was 5 wrung water ribbons round a stem, as well as the 16 droplets. Otherwise it matched: a closed rim, a closed column spinning from the first frame, snap at 0.6 s, mist by ~0.9 s.

What changed, and only this:
- **Swept into being.** A spark (the Tideline's bright tip) appears on the ground on the side nearest the caster. A breaking wave-front, the head, then runs round the pool counter-clockwise, and the rim rises out of the floor behind it, segment by segment. Droplets are thrown up off the crest as it passes, and each column ribbon climbs out of the pool as the sweep passes its foot. Nothing spins before it is drawn.
- **Open.** The sweep stops 60° short of where it began, so the rim is a C and not an O. It climbs from 0.3 to 0.8 studs toward the head, so the break (tall head, low tail) reads from any side. The pool's lip is lowered, and its water runs out through the gap. After the sweep the whole C keeps turning with the sweep's momentum, about 67° by the snap, so the gap travels round.
- **Timing unchanged.** The sweep takes 0.40 s, the old ConjureTime, and the snap stays at 0.6 s. The flare runs white-hot along the whole C. The blow-apart is unchanged, as are the pull, the interrupt and the material.
- **Still open (owner's call):** only the rim open (A, the prompt's working assumption), or the column's ribbons and droplets open too (B). From the side they look almost the same; from above, B is one open C from floor to top.

**Sidearm, reworked on the owner's word** (pushed, not saved; live-tested on the training dummies):
- *"It should look like you hold out a gun and then shoot."* The press draws the gun: it forms out of water, swings up and is held out. The first shot leaves 0.14 s later, whether or not the key is still down, so a tap is that one shot. Each shot kicks the gun, flashes the muzzle's Tideline white and throws spray. The gun stays out 0.35 s after the last shot, then drops away into water.
- *"If u keep holding it rapid fires bullets but takes mana in return."* Held on, it fires 7 bullets a second, 5 damage each, and each costs 4 mana. It stops when the key comes up; when the bar runs dry, the hold lets go by itself and the cooldown starts. The server checks every shot: the draw timing, the rate, and the mana it spends. Tested: a tap did 12 for 15 mana; a 2 s hold fired 12 shots and did 67; holding to empty fired 30 shots in 4.5 s, then the hold let go.
- *"Make the bullets smaller."* The first shot is 0.55× the old slug and rapid bullets 0.42×.
- **The charged slug is gone, and with it the launch.** Only the charged shot ever launched; the rapid fire replaced the charge. Flagged in case the launch should live somewhere else. The loadout description now reads "A water-gun: draw it and fire, or hold to rapid-fire (every bullet costs mana)".

**Splashes on everything** (the owner: *"just in general everywhere make water splashes etc because water is liek a liquid"*; pushed, not saved; all from kit meshes already in the game):
- Every thrown bit of water now splashes where it lands, including on the Maw's flood surface. Leviathan's Maw's rocks stay dry.
- Riptide sheds spray off its crest as it runs, splashes at each body it passes through, and throws a big splash where it breaks.
- Twin Tide rains drops off both curls into the lane, bursts at the meeting, and splashes along its feet as it sinks.
- Leviathan's Maw throws water with the slam, rings a splash at every panel's foot as the walls tear up and again as they crash down, trails a wake behind the fin, and bursts spray at the bite.
- Sidearm bullets shed drops and splash where they hit (a big splash for the first shot, a small one for rapid bullets). A wet puddle is left under the first shot and every third bullet, not under every one.
- An enemy slipping on Aqua ground now kicks up foot splashes too, like the owner riding it.
- The live count is capped (110 pieces), so a busy fight on a phone never piles up hundreds of parts.

**Flagged, not changed:** AquaFX draws the solid kit meshes with shadows on, per the build prompt. The Phase 1 audit above found the live Track 1 kits draw VFX meshes with shadows off, and the Undertow prompt says an audit corrected this; it needs a decision. The restyled kit and the new Undertow meshes still need one Import 3D to reach the game.

## 2026-09-25 — Undertow redone in front of your face; the Aqua kit uploaded; a realistic shark; the gun gripped

**Undertow, second correction (owner, with a reference clip).** The owner rejected the swept ground ring outright: *"IT SHOULD BE INFRONT OF YOUR FACE, YOUR HANDS DOING THE CIRCULAR ARC"*, and asked of the pull, *"stays in front of you"*.
- **What it looks like now.** Your right hand draws a whirlpool disc in the air 6 studs in front of your eye, standing up and facing you. A point of light at the hand sweeps clockwise, and the water trails behind it and spirals inward: foam-streaked bands, a glowing Tideline rim brightest at the hand, a dark eye you look into. Because it is a spiral it never closes, which keeps the earlier "open, not an O" correction. The disc then turns, flares white at the snap, and bursts into spray.
- **The pull changed.** At the snap every enemy in front of you (within 24 studs, inside 35° of your aim, and not behind a wall) is pulled to the floor under the disc, right up to you, and interrupted. Both numbers are stand-ins.
- **Your own arm.** In first person your right arm traces the circle while the disc forms. Other players see the body's circling arms and the disc in front of the caster.

**The Aqua kit is uploaded** (the owner's green light, after the two changes below): one Import 3D of 85 meshes, about 40,600 triangles, now in `IceMagicMeshes.AquaKit`.
- It brings the lighter, less comic restyle of every move, the new Undertow disc and the new shark.
- The replaced meshes are moved to `ServerStorage.AquaKitSuperseded/v1_comic_2026_09_25`, not deleted. That includes the 3 ground-Undertow pieces the kit no longer has.
- The final sheets for all six moves are in `aqua_final_upload_2026_09_25/`.

**The shark, more realistic** (*"slightly more realsitic but with those visual design like new elements"*). It now has great-white proportions: a pointed snout, the deepest body a third of the way back, a slim tail stalk, a tall triangular dorsal fin, long sickle pectorals and a crescent tail. It is slate above and white below with a ragged line between, with small dark eyes, thin gill slits and more, smaller teeth. The mesh names and jaw hinge are unchanged.

**The gun, gripped** (*"the gun holding looks weird"*). In first person it used to sit at the hand's cast point, past the fist and turned 24° in, so it floated in front of the hand. Now its grip is in the right fist, the barrel points at the crosshair, and it is drawn slightly smaller (0.34).

Everything is live-tested in Studio Play, pushed and **not saved**. Backups are in `SPELLSHOT_Backup/studio_patches/2026-09-25_undertow_face_gun_grip` and `SPELLSHOT_Backup/aqua_kit_2026-09-25/v3_face_upload`.
