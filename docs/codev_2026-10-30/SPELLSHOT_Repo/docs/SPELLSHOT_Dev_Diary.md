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

## 2026-09-25 — Sidearm held with both hands; one shark per trapped enemy

- **Sidearm, the owner's notes** (from their own play test: *"the gun needs to be bigger, also the arm needs to be slightly less inclined and closer to person, and other arms needs to be like 'filling water bullets' animation in the gun and slow down the fire rate when held"*):
  - The first-person gun is bigger (0.46, was 0.34).
  - The right arm holds it flatter (16 degrees less steep) and nearer the eye.
  - The LEFT hand comes over to the gun's reservoir and pours water in: drops run from the hand into the gun, and the hand pushes in with every shot and keeps a steady pour between shots.
  - Held, it fires 4 a second (was 7); each bullet still costs 4 mana and does 5 damage.
  - Pushed and live-tested, not saved.
- **Leviathan's Maw** (*"if more than 1 person is in the shark tank, more than 1 shark will appear and each will get hit separately"*):
  - One shark circles for every enemy the tank closes on, up to 6.
  - At the lunge each trapped enemy gets its own shark, and each is bitten separately for the full 65 and thrown up.
  - Anyone past the 6-shark cap takes the old surge (25).
  - Live-tested: three dummies in the tank, three sharks, three separate 65 bites.

## 2026-09-25 — Sidearm: slow knockback shots; Twin Tide: build-up, faster, a real crash

- **Sidearm** (*"make it much slower since all bullets should do knockback"*, *"the first 12 dmg thing, remove that"*, *"make it like its supplying water to it essentially, scrap the bullet idea"*):
  - Held, it fires 1.6 a second (was 4). Every bullet is the same: 8 damage, 6 mana, and it knocks the target back and up.
  - The special 12-damage first shot and its hold-forward pose are gone. The gun is drawn and the first bullet leaves 0.14 s later.
  - The left hand no longer pumps in bullets. It stays at the reservoir and feeds a steady stream of water into it.
  - Live-tested: 4 bullets in a 2.6 s hold, each 8 damage with knockback.
- **Twin Tide** (*"animate their build up"*, *"reduce the amount of curved they are inwards"*, *"way too sloww"*, *"what is the middle thing that comes out of ground?? remove it"*, *"make reastic water physics for when the tsunamis crash"*):
  - The walls curl less; the new mesh is imported and placed in `IceMagicMeshes.AquaKit`.
  - Each wall swells out of the ground over 0.45 s, with water boiling at its foot, while it starts to move.
  - The walls meet 1.1 s after the cast (was 2.5).
  - Nothing rises out of the ground any more. The crash of the two walls is the only damage: 35, and the target is thrown up.
  - At the crash, water is thrown up in a plume about twice the wall height and out of both ends of the lane. It rains back down, and every drop splashes where it lands. Then both walls slump into the lane and spill out, leaving it wet.
  - Live-tested with a real cast: Dummy_16 and Dummy_Thrower each took 35 at the crash.
- The old Twin Tide wall and lip are moved to `ServerStorage.AquaKitSuperseded/tt_curl248_2026_09_25`, not deleted.
- Sheets are in `aqua_gun_twintide_2026_09_25/`.
- Backups are in `SPELLSHOT_Backup/studio_patches/2026-09-25_knockback_twintide_crash` and `2026-09-25_twintide_plume_bigger`.
- Everything is pushed and **not saved**.

## 2026-09-25 — First marketing asset: two hero shots for a temporary social PFP

Different kind of task — not a gameplay build. The owner wants a temporary 500×500 profile picture for social media, wants it done properly (looked at how RIVALS, Nosniy Games, and Blox Fruits actually handle their own social presence before proposing anything), and picked **hero action art over a flat logo/monogram**: one shot of Terra's Boulder Shot (M1) held at charge, one of Aqua's Undertow. Explicit instruction: **Track 1 grounded, not comic** — "thats why i dont want to do it in comic and i didnt choose comic looking elements for now before their rework." Background: something better than a literal reused arena screenshot if possible, "outside our current maps."

Caught up on everything logged above before scoping this — Undertow in particular has moved twice since the ring-open correction: it's no longer a ground effect at all. It's now a spiral disc drawn in the air in front of the caster's face (eye height, 6 studs out), open because it's a spiral rather than a closed ring, Tideline brightest at the casting hand, a dark "eye" at the center — confirmed live in Studio Play (`aqua_final_upload_2026_09_25/2_Undertow_Primary.png`, `aqua_ingame_after_upload.jpg`). This is the version the hero shot uses, not the earlier ground-ring one this diary describes further up.

Backdrop proposed: a new marketing-only location, **"Stormwatch Spire"** — a broken watchtower/observatory on a cliff or floating shard at dusk, storm clouds, built partly from Ascendant Bastion's existing stone/platform kit (so it isn't fully new geometry) but re-silhouetted and dramatically re-lit rather than a straight reuse of a real arena screenshot. Not a real playable map — pure backdrop.

Text call: recommended **against** putting the "SPELLSHOT" wordmark on the actual 500×500 PFP crop itself — X/Discord etc. circle-crop and shrink avatars to well under 100px, and Blox Fruits' own PFP carries no text at all for exactly that reason. Instead: produce the PFP crops text-free, and pull a companion wide banner crop from the same render with a proper wordmark (grounded/etched-glow treatment, not comic lettering — gold accent on the Terra version, teal on the Aqua version) for the actual banner slot, where text has room to be legible.

Build prompt: `Opus55_SPELLSHOT_Marketing_Hero_Shots.md`.

## 2026-09-26 — Discord server polish, Phases 1–2 (`Opus55_SPELLSHOT_Discord_Server_Polish.md`)

Not a game build. The SpellShot Discord server (1553071671122858188) was a bare skeleton: 2 people (both Owner) and 3 bots, no topics, no AutoMod, Community off. The plan is at https://claude.ai/artifact/BoLfok38faiRwqzJJ5em3N.

- **Phase 2 is built (additive only).** Nothing existing was renamed, moved or re-permissioned; checked by diffing a full API read before and after.
  - 9 Element roles and 4 ping roles.
  - A read-only #faq, the Duo Voice (2) and Squad Voice (5) rooms, and a private PLAYTEST category.
  - Topics on every public channel and post guidelines on both forums.
  - Pinned welcome, rules and FAQ posts.
  - 5 AutoMod rules, block-only for now.
- **Element role colours come from `Config.Elements` Base, with three exceptions.** The manual has no hex values. On Discord the game's own colours break in three places: Voltaic and Radiant are the same yellow, and Umbra and Terra are unreadable on the dark theme. So:
  - Radiant uses its game Light, #FFF7D6.
  - Umbra uses its game Light, #B58CF0.
  - Terra uses sandstone #C29A5B, which is not a game colour.
  - Aqua uses #268CB0, which is still a stand-in in the config.

  A 10th Element needs a hue check against these nine.
- **Proposed for Phase 3, not decided:** the staff roles move off the Element hues. Owner goes to #E91E8C (the Sparks magenta, the one hue no Element owns), Dev Team to #FF6FA8 and Moderator to #7289DA.
- **Emoji wait for the Element logo rework.** The current logos are the pop-art set and smudge at emoji size, and the owner doesn't want comic-looking Elements in public before the rework.
- **Banner and invite splash are boost-locked**: the splash needs 2 boosts and the banner 7. The art already exists in `marketing_hero_2026_09_25/duel/`.

## 2026-09-26 — Discord server polish, Phase 3 done

The owner approved Phase 3 separately. Nothing was deleted: every original channel, role and message is still there.

- **Community is on.**
  - Rules channel: 📜・rules. Updates channel: #mod-chat.
  - 📢・announcements is a real Announcement channel.
  - Welcome screen: rules, announcements, general, LFG, bug-reports.
- **Onboarding is on.** It has 17 default channels and 3 questions:
  1. "Which Element are you drawn to?" gives an Element role. It's single choice, or "Not sure yet".
  2. "What do you want to be pinged for?" gives the 4 ping roles.
  3. "What else are you here for?" opens strategy, art/memes, events and off-topic.

  Members change their picks in Channels & Roles. There's no reaction-role bot.
- **Info channels are read-only**; staff can still post. **@everyone** lost Mention Everyone, Create Expressions, Create Events and Create Private Threads.
- **Settings:** verification Medium, media scan on for all members, notifications set to @mentions, join messages in #general.
- **Public channels are renamed "emoji・name"**, e.g. 📜・rules. Staff, playtest and voice channels stay plain.
- **Roles:**
  - Dev Team #FF6FA8, Moderator #7289DA, Content Creator #F47FFF.
  - "Bug Hunter / Playtester" is now **Playtester**, #B5BAC1.
  - Owner is still #E74C3C, because the bot can't edit it; the owner will change it to #E91E8C.
- **Moderation permissions** the bot can't grant (Timeout, Kick, View Audit Log and others) are the owner's to add.

## 2026-09-26 — Toxin rework, in progress

Not a build yet — design-only, worked out in chat, nothing built in Studio. Toxin is the second post-launch Element after Aqua, replacing its launch-era kit.

**Corrected early confusion, worth recording so it isn't re-litigated:** first pass of this discussion assumed Toxin should move to an "Offensive" archetype and kept its old Nature/plant flavor (spores, seeds, vines) in the new pitch. Both wrong. The owner's actual call: **archetype categories are Offense(Aggro), Mobility, Control/Zone, Tank, Support — Toxin stays Control/Zone**, unchanged from the launch manual (matches the "Area denial/DoT" tag it already had, and the "joining Cryo and Toxin" line already in Aqua's section — nothing was actually contradicted here, just my own first draft of the pitch). And the identity drops Nature/plant entirely for pure toxic/poison cloud — no spores, seeds, vines, or cloak going forward.

**Locked so far:**
- **M1 — Toxic Bubbles:** fires bubbles that travel outward. Exact behavior on hit (single-target vs. piercing) not yet nailed down — a small open detail, not blocking anything else.
- **Primary:** pressing Primary while a Toxic Bubble is still in flight converts it into a lingering toxic cloud at that point in space, instead of it landing as a normal on-hit poison tick. This is the core of the kit — a second ability that reacts to the first rather than being fully separate.
- **Passive:** unchanged from the current manual — DoT you apply heals you slightly (lifesteal-on-DoT).
- **Technique 1 — Antitoxin Vent (confirmed):** grants immunity to poison/DoT (yours or an enemy's) and lets you pass through toxic clouds, including your own, without taking damage while it's active. Explicit reasoning from the owner: if Toxin's base kit is this strong, it needs a real self-damage risk baked in somewhere, and Antitoxin Vent is meant to be the answer to that risk, not just a nice-to-have — implies Toxin's own clouds should genuinely threaten Toxin too without this Technique equipped. Not yet decided: the actual self-damage mechanic this Technique is answering.
- **Technique 2:** still open.

**Ultimate — still open, and this is the current blocker.** First three candidates pitched (Plague Walker — a mobile aura that follows the caster instead of holding a fixed zone; Reckoning — detonates/links every cloud already on the field; Creeping Rot — a stain that autonomously crawls toward the nearest enemy) were all set aside. **Reckoning specifically was cut for a real design reason worth keeping:** if the Ultimate alone, stacked with just M1 + Primary, is already enough to kill, players won't need to pick any Techniques at all — the Ultimate can't be a self-sufficient finisher that makes the build-choice system pointless. The owner wants more, and more genuinely unique, options — asked for a small Opus 5.5 prompt to run a fresh brainstorm on this specific problem, since the design bar (works within the fixed-4-slots-plus-shared-Technique-pool system, must earn its slot with a distinct verb from every other Ultimate in the game, and can't replace the need for Techniques) is now clear enough to hand off.

Build prompt: `Opus55_Toxin_Ultimate_Brainstorm.md`.

## 2026-09-26 — Toxin rework, locked (manual v0.15) — Ultimate found, self-damage rule, VFX, build prompt written

Picks up straight from the entry above. The owner supplied the Ultimate idea directly rather than running the brainstorm prompt, and the rest of the kit's open questions got settled in the same pass. Manual bumped to v0.15 with the full writeup (Section 2, new `### Toxin — reworked (v0.15)` subsection); this entry is the "why," not a restate of the "what."

**Ultimate — Patient Zero (found).** The owner's own pitch: mark a target with a visibly growing, leaking aura; after a few seconds it explodes into a big poison cloud centered on wherever they currently are, worse the more of their team is near them when it pops. Checked against the standing Reckoning lesson (an Ultimate can't be so strong alone that Techniques stop mattering) and it clears it — the payoff is delayed and telegraphed, not an instant self-combo finisher. Two scaling variants proposed, neither locked: radius scaling (Variant A) vs. damage/duration scaling with fixed radius (Variant B, recommended for legibility). Flagged and *not* resolved: the "worse near his team" hook has nothing to scale off in core 1v1, so the unscaled base version has to be worth casting on its own merits — team-scaling is a group-mode bonus on top, not the whole point. Working name only; "Outbreak" was also floated.

**Base kit gets a real self-damage rule.** Corrected a misread along the way: the reduction isn't something Antitoxin Vent grants — it's baseline. With nothing equipped, Toxin already takes *reduced* (not zero) damage from its own poison, by default, no Technique required. Antitoxin Vent's actual job is dropping that down to *zero* while it's active, on top of the always-on reduction. This is what makes "Toxin needs a self-damage risk" (from the last entry) an honest baseline risk rather than something that only exists if the player forgets to equip the answer to it.

**Technique 2 found: Acid Rain.** Calls down a poison downpour over a chosen area. Recommended default (not confirmed): a stacking vulnerability debuff that amplifies Toxin's *other* poison damage rather than dealing its own direct damage — deliberately picked to avoid overlapping with Corrosive Cloud's own damage-cloud, not a second damage source doing the same job. A straight-damage version was the alternative considered and set aside for now.

**VFX direction locked, sticking to the new grounded look, not the old comic track.** Track 1 (opaque MeshParts, `SmoothPlastic`, baked vertex color, real shadows) stays the base recipe. Two calls made specifically for Toxin:
- **A second deliberate, scoped exception to "no transparency anywhere"** (first was Aqua's Leviathan's Maw glass, v0.14): the owner wants Toxin's poison substance — bubbles, cloud puffs, Acid Rain's droplets — and the Antitoxin Vent mask's lenses **somewhat translucent, not opaque** ("i dont want it opaque, somewhat translucent should be fine"). Scoped to those surfaces only; the mask's body/straps/canister and everything else stays opaque. Not a general rule change.
- **Antitoxin Vent is a gas mask**, per the owner directly ("make it a gas mask lol. with green glowy stuff") — opaque rubber/metal body and straps, translucent green lenses that glow while the Technique is active and sit dark otherwise, visible to everyone as a read on "this Toxin can't be poisoned right now," not just the caster's own screen.
- **New signature accent: Virulence**, the fourth in the per-Element accent family (after Terra's crack = intensity, Cryo's Frost Line = position, Aqua's Tideline = motion). Virulence reads by **time**: brighter/faster pulsing the closer something is to detonating or expiring. Meant to pay off hardest on Patient Zero's mark (should visibly accelerate toward detonation — that's the actual gameplay tell). A steady non-accelerating glow is used instead for a plain duration-buff like Antitoxin Vent, since it isn't counting down to anything.

**Still open, flagged in the manual, not silently decided:** M1 bubble pierce-vs-single-target; Ultimate scaling Variant A vs. B; Patient Zero's 1v1 baseline strength; Acid Rain's exact effect (debuff vs. direct damage); whether Antitoxin Vent's immunity extends to enemy poison in a mirror match; and whether Antitoxin Vent/Acid Rain stay in the shared Technique pool or go Toxin-exclusive like Aqua's post-launch pair.

Build prompt written and delivered: `Opus55_Toxin_Rework_Build.md` — mirrors the Aqua build prompt's structure, adapted for a kit *replacement*: old Toxin assets (Spore Burst, the old point-blank Corrosive Cloud, Bloom, Overgrowth Vault, Antidote Cloak) move to `ServerStorage.ToxinKitSuperseded` rather than being deleted, same as `AquaKitSuperseded`. Nothing built in Studio yet.

## 2026-09-26 — Cryo social clips, build prompt written (`Opus55_Cryo_Social_Clips.md`)

Not a game build — a content task. The owner wants Cryo's current 6-ability kit (Icicle Shard, Flash Freeze, Passive, Mirror Cage, Deep Freeze, Blizzard) turned into 6 individual short-form clips for TikTok/YouTube, using Blender-rendered footage the owner already has, plus a suggested title and description per clip for uploading.

**A real gap surfaced while checking this, worth recording:** the shared OneDrive project folder has no actual video footage of Cryo's abilities — only single-frame concept stills in `cryo_grounded_2026_09_24/` and the grounded-VFX direction note, which is itself still an unconfirmed proposal ("not a locked spec," "Not touched yet: Studio"). Asked the owner directly rather than guessing; confirmed the real footage exists locally on their machine, just not synced to this folder. The build prompt's first phase is locating it there before touching anything, and it flags explicitly that if the only footage found turns out to be the *old*, retired comic-era kit (Cryo Beam / Frost Slide / Chill Aura), that's a different-looking, differently-named kit than what's actually current and shouldn't be quietly presented as Mirror Cage/Deep Freeze/Blizzard footage.

**Content style, established in chat, not obvious from anything on file before now:** these clips are meant to read as raw/leaked footage, not produced marketing — no logo-bump intro, straight into the ability. Two deliberate exceptions to that rawness the owner asked for directly: a small corner-anchored caption naming the move (unlike a fully unlabeled leak), and a quick scrappy end-card advertising the Discord and asking for a follow. The end-card reuses the established SPELLSHOT wordmark treatment from the marketing hero-shot work rather than any pop-art Element logo, since those are still being held back from public use pending the Element logo rework. Also flagged in the prompt: the actual Discord invite link needs to come from the owner's own records, not be invented.

Build prompt written and delivered: `Opus55_Cryo_Social_Clips.md`. Nothing rendered yet — waiting on that session's own footage-location audit.

## 2026-09-27 — Umbra reworked, locked (manual v0.16) — Mobility formalized, Primary/Ultimate replaced, Techniques reshuffled

Design-only, worked out in chat across several rounds, nothing built in Studio. Umbra is the third Element touched this way (after Aqua's fresh build and Toxin's rework) — this one keeps M1 and the Passive untouched and rebuilds around a single standing rule the owner stated directly: **Shadow Dart (M1) is the real damage source; everything else in the kit is a buff, a setup tool, or minor damage at most, never a competing damage instance.** Every piece below was checked against that rule before being accepted.

**Archetype formalized: Mobility.** Old tag was "Assassin/Playmaker, less damage more mobile." The owner's own framing, worth keeping verbatim: Umbra is mobility, "but not as quick as zephyr. That comprimisation is brought up by the damage." Zephyr already sits in Mobility too under the old tags, so this was flagged directly rather than assumed compatible — resolved because Shadow Dart (already the slowest-firing, highest-damage M1 in the game) was already the mechanical proof of the trade-off; formalizing the archetype just named what was already true.

**Primary replaced: Shadow Step** — a short reposition through shadows that also briefly breaks line-of-sight/target-lock. This retires Mark for Death from the Primary slot. Reason, not just preference: Mark for Death's old wording ("next hit from *anyone on your team*") was dead weight in the core 1v1 Duel mode, the same category of flaw flagged for Patient Zero's team-scaling during Toxin's rework — asking "does this even do anything in 1v1?" is now a standing check for every kit change, not just Toxin's.

**Ultimate replaced: Eclipse** *(working name — "Nightfall" no longer fits, nothing better locked yet)*. The owner's own pitch, evolved over a few rounds: not a structure, a domain-expansion-style effect where "it rather covers like not structure but visually your whole environment, and which gives u buffs." Three buffs locked: every enemy counts as unaware (feeds the Passive), enemies revealed to Umbra only (absorbs Nightfall's old job), and Shadow Dart's fire rate temporarily increases. **Checked directly against the existing roster before locking:** both Mirror Cage (Cryo) and Leviathan's Maw (Aqua) already use "enclose the target in a bounded space" as their Ultimate's verb — a third one would have blurred together, so Eclipse was deliberately built as a personal buff window with no physical structure at all, specifically to dodge that overlap.

**Technique 1: Mark**, replacing Fade Step in the pool (Decoy Double is unaffected). This is where Mark for Death's identity actually landed, fixed: self-only ("should only benefit you," the owner's words), stacking the longer it's held, expiring if left too long, and paying off as a flat 150 bonus on a headshot against the marked target — Umbra's own hit only. **This introduces the game's first hit-location (head vs. body) system.** Confirmed directly, not assumed: nothing else in the game currently distinguishes where a shot lands, and the owner wants it scoped to just this one Technique for now, not built as a general system.

**Technique 2: Decoy Double, kept.** A sharp, correct critique came up in chat: a stationary decoy is an obvious tell against anyone already watching Umbra move — true, and not a flaw to engineer around. Resolved by reframing its actual use case rather than trying to fix the mechanic: it's meant to win the *first* glance (ambush recognition, or the moment right after a Shadow Step), not survive sustained scrutiny mid-fight. A cheap idle "ready stance" loop instead of a dead T-pose was suggested to help sell that first half-second, nothing more elaborate.

**Cleanup this rework forced, worth recording so it isn't rediscovered as a bug later:** the old "Mark" status-table entry in Elemental Application, and its "universal amplifier" classification in Elemental Reactions, are both removed rather than edited — the new Mark is self-only and Technique-gated, so it no longer functions as an innate, always-on per-Element status the way Burn/Chill/Poison do. This was caught by auditing the manual before editing it, not flagged by the owner — worth noting since it's exactly the kind of drift this project's "always audit fresh" habit exists to catch.

**Still open, flagged in the manual, not silently decided:** Eclipse's final name; Mark's exact stack-count/timing numbers; Shadow Step's exact distance/cooldown; the optional stretch idea of a headshot during Eclipse refreshing Mark's stacks (flagged as a nice-to-have, not committed); and the whole VFX/signature-accent pass, which hasn't been discussed for this rework at all yet — unlike Toxin, no visual direction conversation has happened for Umbra.

No Opus 5.5 build prompt written yet — design lock only, at the owner's request ("finalise it and present to me"), same two-step pattern as Aqua and Toxin.

## 2026-09-27 — Umbra's VFX and animation direction locked (manual v0.17), build prompt written

Follows straight on from the kit lock above. The owner asked to brainstorm VFX and color scheme next, then character animation, then to write the build prompt — all in the same sitting.

**Palette anchored on something that already existed, not invented fresh:** Umbra's Discord role color (`#B58CF0`) turned out to be the right starting point, since it's already checked against every other Element's accent and nothing collides. The owner's one clear note: **darker, and a lot of effects happening.** Resolved as two separate calls rather than one — palette gets pushed hard toward void/dusk dominance with the lighter tones demoted to rare accents (confirmed, unambiguous), but "a lot of effects" got a genuine question back before locking it, since constant ambient density risked the exact problem Blizzard's own direction note already flagged (its Frost Line getting lost in its own haze). The owner picked **concentrated bursts at payoff moments** over constant chaos, keeping Umbra quiet at rest and loud only when it matters — Eclipse's activation, a Mark headshot.

**Material: obsidian, not smoke, for anything solid** — Cryo's crystal-shard family recolored dark rather than icy. **A third scoped transparency exception was needed anyway**, alongside Aqua's tank (v0.14) and Toxin's poison/mask (v0.15): Shadow Step's dissolve/reform trail specifically, since smoke needs some translucency to read as ephemeral. Kept narrow on purpose — nothing else in the kit gets it.

**A fifth signature accent, the Tell**, reading by *exposure* rather than time, position, motion, or intensity (the four already in use) — dark until concealment breaks, then lights up. Deliberately kept separate from Mark's stack-timer, which would have overlapped with Virulence's own "counts down to a payoff" read.

**Character animation given directly, ability by ability, Blender-authored per the project's standing pipeline (not Roblox's native animation editor):**
- Shadow Dart: arm tucks in and tilts up, a small shadow ball forms, the stance shifts into a two-armed precision brace, then release — the brace beat doubles as the shot's own telegraph.
- Shadow Step: no physical dash — the character dissolves into shadow at the origin and reforms at the destination.
- Eclipse: arms gather a shadow mass between them first (a held beat that also serves as this game's required Ultimate telegraph, same pattern as Ring of Fire and Cryo Beam), then spread outward to "open" the domain. Revealed enemies get a light-purple outline visible to Umbra only.
- Decoy Double: the cast peels a shadow copy directly off Umbra's own body rather than summoning one from nothing; the decoy gets a cheap idle "ready stance" loop instead of a dead T-pose.
- **Mark's headshot-payoff animation is the one piece left genuinely open** — whether it gets its own bespoke execution effect or routes through the game's existing skin-based kill-effect system was raised as a real question, not decided, and carries into the build prompt as something to confirm with the owner rather than pick silently.

**New instruction for how this build prompt works, different from every prior one:** the owner wants the build agent to **present the finished designs — animation and VFX both — and get explicit confirmation before importing anything into Roblox Studio**, not just stop-and-report the way Aqua's and Toxin's shape-stage checkpoints did. Given how specific the animation direction was (particular arm gestures, a particular reveal-outline effect), a wrong read translated into Blender is a real risk worth gating explicitly rather than assuming a general "stop and report" phase covers it.

Build prompt written and delivered: `Opus55_Umbra_Rework_Build.md`. Nothing built in Studio yet.

---

## 2026-09-28 — Radiant reworked, locked (manual v0.19) — Ultimate replaced, both Techniques replaced, Passive deliberately left broken

Radiant was the one launch kit nobody had touched since v0.1 — no VFX pass, no rework subsection, nothing. Opened with a plain recap of its current state and the manual's own admission that it's "intentionally weaker in a straight 1v1 Duel and stronger in Squad Clash."

**Applying the standing 1v1-baseline check (the same one that flagged Patient Zero's team-scaling and the old Mark for Death) found the asymmetry wasn't the problem — the asymmetry is doctrine, other kits get to lean hard one way too (Voltaic's snowball, Terra's aggression). The real problem was that two specific pieces did *literally nothing* solo, not just "less":**
- The **Passive** ("allies near Radiant also regen out-of-combat health slowly") excludes Radiant itself as written, and "out of combat" is undefined anywhere in the project — no existing system tracks a combat-state timer. First-of-its-kind gap, same category as Mark needing hit-location detection.
- **Cleansing Ring** (Technique) had no self-clause at all — checked against all other 11 pool entries, and it was the only one that does nothing for a solo caster. Even niche picks like Bulwark Wall still block for yourself.

M1 (Light Lance) and Primary (Blessing, already self-targetable) both cleared the check fine and were never touched.

**The Ultimate was the owner's own proposal, not mine:** activate for a duration, and whatever damage you deal during that window also converts into team healing (self-only if solo). I'd initially sized this wrong — flagged it as too strong *as a Technique* (Light Lance is already Radiant's real damage engine; converting 100% of that into free team healing on a short Technique cooldown breaks the game's whole "no passive regen, only healing abilities heal" scarcity model) but said it was actually well-sized *as an Ultimate*, where the charge-gate is the natural brake a Technique doesn't have. The owner agreed and it replaces Radiant Judgment (the old beam), which was mechanically just a second beam anyway — this is a real new verb (damage-as-a-resource) nothing else in the game has. **Left open, not decided:** whether it's additive (enemy takes full damage AND the team gets healed the same amount) or a redirect (enemy takes less damage, the difference becomes the heal). I argued for redirect as the safer, more thematically-support version; the owner kept it as originally proposed (additive) for now. Standing concern on record, not resolved.

**Both Technique picks took two wrong turns each before landing right, worth keeping since they're exactly the kind of near-miss a version note would compress away:**
- First mobility pitch, "Beacon" (plant a sigil, recall to it within a window): passed the letter of the distinct-verb rule against Shadow Step (two-phase precommit vs. instant point-and-go) but the owner caught that it's the same "vanish and reappear, used to save yourself" fantasy Fade Step just got killed for — scrapped on the fantasy-overlap alone, not the mechanism.
- Second mobility pitch, "Guiding Rush" (a dash leaving a friendly speed-trail): the owner caught this one too — Aqua's own Passive (Riding the Current) already does "your movement leaves a trail, something happens to whoever's in it" (self-speed + enemy-slip); swapping who benefits from self to ally doesn't make it a different verb. Scrapped.
- Landed on **Position Trade** — instant swap with any target, ally or enemy. A mutual exchange is genuinely new to the pool (not a dash, not a teleport, not a pull-toward-a-point like Cyclone/Undertow), and it needs no self-fallback since your opponent is always a valid solo target.
- The utility/defense slot went through a "dual-purpose pulse" (heal allies / damage enemies by target, echoing Judgment) before the owner proposed **Benediction** directly — rays from the palm healing every ally in radius, falling back to self-heal when solo. Once Benediction existed as the pool's clean unconditional heal, the pulse's ally-heal side was redundant, and the owner dropped it rather than keeping a narrowed version. **Real gap this leaves, caught during the edit, not before:** Cleansing Ring was the only cleanse in the entire Technique pool (Chill stacks, roots, Toxin's DoT); Benediction doesn't cleanse anything, so nothing currently removes a lingering status. Flagged in the manual's counter-web section, not resolved.

**The Passive is the one piece kept exactly as it shipped at launch — a deliberate choice, raised and re-raised, not a miss.** Owner's instruction was explicit ("passive same, and m1 too"). It's flagged prominently in the manual as still genuinely dead in 1v1, with the leading fix discussed on record if it's ever revisited: tie it to Blessing instead of inventing a combat-timer — a shield that survives its full duration converts its leftover absorb into a real heal. Not built, not decided, just not lost.

Locked into manual v0.19. No build prompt written — the owner asked to "present" the final kit, not to prompt it yet.

**Same-day correction (manual v0.20):** "passive same" in the finalize message was a miscommunication, not a final call to keep the launch Passive — the owner meant Overflow Light, the favorite option from earlier in the conversation, not "same as launch." Good thing this got flagged explicitly rather than assumed; it would have re-locked the exact dead-in-1v1 problem this whole rework existed to fix. Also added: Benediction roots the caster for its channel duration, a real exposure cost the original pitch didn't have. Both fixed in the manual same day, no diary rewrite of the original entry above — see the v0.20 change note in the manual for what changed and why.

---

## 2026-09-29 — Radiant's visual direction and animations locked (manual v0.21), build prompt written

Straight follow-on from the mechanics lock. Opened with a color/material pitch (anchor on the existing `#FFF7D6` Discord color, pattern-not-substance shape grammar since every other Element already owns a physical material, quiet-baseline density matching the project standard) and a new signature-accent proposal, **the Bond** — reads by *direction* rather than the five axes already in use, a visible thread connecting caster to whoever's receiving an effect. None of this is confirmed by the owner yet; it's carried into the build prompt as a first-checkpoint item rather than assumed locked.

**The owner introduced a held weapon mid-conversation that reshaped several pieces at once: a staff.** First mentioned for the Ultimate's windup (a two-handed spiral that starts tight and grows outward, locking into a ring that fires the ability) and Benediction's cast (staff planted into the ground) — then confirmed directly for M1 too ("the staff is held by both arms and the tip of the staff is shooting the beam"), which settled it as a permanently-carried weapon rather than a per-ability summon. This superseded an earlier M1 animation pitch (one-handed "conducting" gesture) that no longer made sense once the staff was in the picture — worth noting since it's exactly the kind of thing a version-note summary would silently drop rather than explain why it changed.

**Two things flagged rather than assumed, both carried into the build prompt:**
- Whether Blessing (Primary) also involves the staff in the off-hand, or sets it aside — the owner only corrected the gesture itself (dropped a "two fingers extended" detail, no fingers at all now) and never addressed the staff for this piece specifically.
- Halo's windup timing. "Small to small to big rotation radius" reads as a possibly longer sequence than this project's usual telegraph beat (Eclipse's 1.0s, Ring of Fire's trace-and-snap), and the Ultimate's whole value depends on landing Light Lance hits *during* the active window — a long windup competes with that. Recommended keeping it short by default, flagged for the owner to confirm rather than picking silently.

**New build-prompt convention, front-loaded even further than Umbra's:** the owner asked for three Blender staff-design variations as Phase 1, presented before anything else moves forward — not just before Studio import (Umbra's gate), before any other design or mechanics work happens at all. Makes sense given the staff underpins animation work across at least three of the six kit pieces (M1, Halo, Benediction) — picking it wrong would mean redoing that work.

Build prompt written and delivered: `Opus55_Radiant_Rework_Build.md`. Nothing built, nothing rendered yet — Phase 1 hasn't run.

---

**Gap on the record, not backfilled:** nothing below this line until 2026-10-06, but Studio/project work clearly continued in between — `Opus55_Pyro_VFX_Rework_Build.md` (Oct 3), `Opus55_HUD_Compass_Build.md` (Oct 4), and `Opus55_Ability_Logos_Build.md` (Oct 6) all exist as build prompts with no matching diary entry. This session only has those prompts, not their outcomes (what Studio actually has now, what got decided, what's still open), so they aren't backfilled here rather than guessed at. Worth getting whoever ran those sessions to add their own entries, or starting a Studio audit to reconstruct outcomes if that's not possible.

## 2026-10-06 — Rivals launch-day scope pulled as a benchmark for SPELLSHOT's own launch content

Prompted by a direct question: what should SPELLSHOT launch with, map- and content-wise. Chrome wasn't connected this session, so this was text research (NamuWiki's update-history table, cross-checked against a rowatcher retrospective), not the video approach originally planned.

**Rivals launched (June 28, 2024) with 19 weapons** (10 primary, 3 secondary, 6 melee) **+ 6 utility items, across 8 maps**, standard team matches only — ranked, parties, and special modes all came later (Update 1–2). Now at 52 weapons / 30 maps / 21 modes after 19 updates over ~21 months, so launch content was roughly a third of today's.

**Flagged directly:** Rivals' weapon count isn't the right thing to compare against SPELLSHOT's *Element* count — a weapon is one interchangeable pick, an Element is a fixed 4-piece kit. The closer apples-to-apples number is maps (recommended SPELLSHOT target: 6–8, matching Rivals' 8) and the shared Technique pool (the actual lever for build-variety content, same job Rivals' weapon catalog does). Not a locked decision, just the comparison and a recommendation — nobody's signed off on a map count yet.

## 2026-10-06 — Technique pool size-checked against that benchmark (manual only, Studio unreachable this session)

Follow-on from the above: is the shared Technique pool (Section 2) big enough. Pulled straight from manual v0.21 since no Roblox Studio instance was connected to check live.

**Pool is 12 total, pick 3, from 6 of the 8 launch Elements (2 each — Cryo, Terra, Zephyr, Umbra, Radiant, Toxin); Pyro and Voltaic contribute 0 by design** (damage-only Elements, per the v0.7 rule). Math-wise this isn't thin — cross-Element mixing means every player draws from the same 12, so C(12,3) = 220 combinations per Element already. The real soft spot isn't the count:
- 2 of the 12 are still open in the manual itself (Acid Rain's exact effect unconfirmed; Antitoxin Vent's enemy-poison interaction unresolved).
- Toxin's two contributions (Antitoxin Vent, Acid Rain) have a standing flag on whether they stay in the **shared** pool or go **Toxin-exclusive** like Aqua's post-launch Techniques — if that flips, shared pool drops to 10. Manual's default assumption is "stays shared," not confirmed built.
- Bigger-picture risk flagged, not resolved: the whole point of the Technique-pool system (per the manual's own stated reasoning) is that it scales content faster than "new Element every season." Pyro and Voltaic opting out at launch is fine as a one-time asymmetry — it only becomes a real problem if future Elements keep doing the same and the pool's growth rate stalls. Nothing to act on yet, just worth watching each time a new Element locks.

## 2026-10-06 — M1 ammo/reload system (Marvel Rivals precedent) — raised, discussed, not decided

Owner asked whether SPELLSHOT's M1s should get a Marvel-Rivals-style depletable-ammo-plus-short-reload system to curb spam (pointed to Human Torch, ~8 charges by memory, and an unnamed "ice" character at ~52). Checked real numbers rather than going on memory: **Human Torch's Fire Cluster is 6 charges, not 8** (0.5s delay before regen starts, then 0.33s/charge); **Emma Frost's Telepathic Pulse is a 70-capacity continuous-drain gauge** (10/sec while firing), not discrete bullets — closest confirmed match to the "~52" recollection, though the exact ice-themed character the owner meant was never pinned down (a couple of wiki fetches got blocked mid-session; not worth re-chasing for a hedged number). Luna Snow (confirmed ice-themed) has no ammo cap at all — fire-rate pacing only.

**Important correction to the premise:** neither Marvel example is actually a hard "stop and play a reload animation" system — both are soft, auto-regenerating charges with a short delay before regen starts. That's a different feel than the 1.5–2s hard reload the owner described.

**My read, given directly, not yet confirmed either way by the owner:** don't apply this game-wide. Every SPELLSHOT M1 already has its own bespoke spam-control lever baked into its identity (Wind Blade's sustained high fire rate, Shadow Dart's slow fire rate, Boulder Shot's charge-up) — a universal ammo gauge on top would be a second system fighting the first, plus a new HUD element and balance axis for every Element. If it happens at all, it should be scoped to one Element as a flavor mechanic (Human-Torch-style soft regen, not a hard reload), the same way Marvel itself doesn't apply ammo to every hero. **Open, not locked** — no Element has been picked for this, and the owner hasn't said yes or no to doing it at all.

## 2026-10-07 — Rivals' lobby/map structure researched in depth; Hub ideas floated

Owner asked for an in-depth analysis of Rivals' lobby and maps before giving Hub ideas. Worth stating plainly: **this turned out to not be new ground** — Section 1 already says the Hub was built "mirroring RIVALS' lobby rather than a queue screen," and the research confirmed that borrowing was accurate, not missing anything structural. Rivals' real lobby: low-poly neon sci-fi, red/blue team-coded central arena + lounge + shooting range + hallways, with a two-tier matchmaking split (local **Duel Zone pads** for instant no-queue matches against whoever's physically in that lobby, vs. a global **Play Menu** for real cross-lobby matchmaking) plus in-lobby loadout customization and tracked daily tasks. SPELLSHOT's Hub already has the equivalent of all of it (Duel Pads / Quick Play split, target dummies, Loadout altar) — confirmed accurate, not a gap to fix.

**Two things worth carrying forward:**
- **The aesthetic divergence (Open Academy floating island vs. Rivals' neon sci-fi) is correct and deliberate** — flagging only so nobody mistakes "mirrors Rivals' lobby" in Section 1 as a license to pull the *look* toward Rivals too.
- **Map count re-flagged with harder numbers:** SPELLSHOT's manual (Section 4) locks exactly **4 ranked-voted maps** (Shattered Neon City, Ascendant Bastion, Skyline, The Elemental Quarry) + the non-voted Training Ground. Rivals launched with 8 (now 30). This directly re-opens the "6–8 at launch" recommendation from the 10-06 entry above — SPELLSHOT is currently locked at half that. Not actioned, just re-surfaced with the real in-manual count instead of an estimate.

**Hub ideas given, all proposed not decided:** a spectator perch over the Duel Pad cluster (Rivals' lobby has a distinct lounge zone; SPELLSHOT's Hub currently has nowhere to just watch an ongoing duel); per-Element shrines/plinths ringing the island (pure flavor, ties to each Element's existing signature accent); small map dioramas near the Quick Play altar (keeps the map-vote system physically present in the walkable space, Rivals-style, rather than purely a popup); a physical Contract/rank concourse instead of a UI-only tracker; and reserving a Hub corner now for Rift Royale (Season 2+) before it ships. None of these are built, named in the manual, or confirmed by the owner — first pass only.

## 2026-10-07 — Hub reshaped into a circular segmented layout; visual theme locked (Arcane Rune Observatory)

Owner's own layout proposal, not mine: circular base, spawn at center, right segment = Loadout, left = Store, front = Duels, with each segment allowed to bulge outward independently rather than growing the whole ring, and featured items displayed around the perimeter. Translated "featured weapons" (Rivals vocabulary) to **featured Technique Looks / Element skin bundles**, since SPELLSHOT has no interchangeable weapons — worth remembering if this phrasing comes up again.

**Slotted the existing pieces into the new layout rather than inventing new ones:** spectator perch → rings the Duels segment; map diorama alcove → moved into the Loadout segment (you're about to vote right as you gear up, so preview belongs there, not a separate wing); Contract/rank concourse → runs along the spawn→Duels walk instead of getting its own segment; Training Grounds portal + target dummies → assigned to the unclaimed fourth (back) wedge, deliberately the quietest segment since it's the "practice alone" zone. Perimeter ring does double duty: alternates Element shrines with the featured-cosmetic pedestals rather than running two separate rings.

**Visual theme was explicitly undecided by the owner — asked directly via a 4-option multiple choice rather than picking one silently**, since a whole-Hub art direction is expensive to redo once anyone starts building. Options given: Arcane Rune Observatory (recommended), Classical Floating Academy, Gothic Spire Academy, Living Academy/Floating Garden. **Owner picked Arcane Rune Observatory.**

**Locked direction:** the circular Hub isn't built *on* a rune, it *is* one — dark obsidian-family stone base inlaid with glowing channel-lines running from spawn (the rune's core) out to each segment and on to the perimeter shrine ring. **Color hierarchy solves the "9 Element colors on one neutral Hub" problem directly:** core and the three main segment-lines stay neutral warm white-gold; all per-Element color variety is pushed out to the perimeter shrines, each lighting its own line in that Element's already-locked accent (Terra gold, Cryo frost-blue, Umbra violet, etc.) — clean center, rainbow rim from a distance, not a muddled mix up close. Segments get distinct silhouettes (Loadout's single standing obelisk/mirror-stone vs. Store's asymmetric floating vendor-stalls) so they're readable before anyone reads a sign. Training Grounds (back) gets deliberately dimmer line-glow and darker stone — the quiet zone, visually as well as functionally. Permanent dusk/twilight sky, open overhead (true to "Observatory"), other floating islands visible at a distance.

**Checked against the locked rule, not an exception to it:** Section 0's maps/environments direction (stylized and heightened, not comic, semi-realistic — Skyline is the reference) still applies; this is an extension of that rule, not a new visual track.

**Not yet done:** no build prompt written, nothing in Studio, manual not updated with this Hub redesign — still at the ideation/theme-lock stage.

## 2026-10-07 — Hub centerpiece resolved to flat-plus-staircase; build prompt written

Owner had actually pictured a spiral staircase from the start, which the previous entry's flat-disc description missed — asked directly which of two readings was meant (the whole Hub as a climbable vertical tower, vs. the flat layout staying and the staircase becoming just the central centerpiece) rather than guessing after already building out the wrong picture once. Owner deferred to a recommendation rather than picking.

**Recommended and the owner went with: flat layout stays, staircase is the spawn centerpiece only** (climbs to a small lookout spire above the rune-disc) — reasoning given directly: a climbable tower adds real navigation friction to a loop that's supposed to be fast (spawn → warm up → queue → duel → repeat, mobile-first per the game's own stated identity), and it breaks the "each segment bulges outward independently" scaling trick from the layout itself, since bulges only make sense on a flat plan. The staircase isn't wasted by staying non-functional — it becomes the one landmark visible from every segment, and a natural home for the best vantage point in the space.

**Build prompt written and delivered: `Opus55_Hub_Observatory_Build.md`.** Phased deliberately (audit → centerpiece-only Blender variations, gated → the rest), same reasoning as Radiant's staff gate: the centerpiece is what every segment's rune-line network visually connects to, so it's the one piece worth getting approved before anything else is built. Explicitly flagged in the prompt itself, not just here: maps/environments follow the manual's own separate, already-locked "semi-realistic, not comic, Skyline is the reference" direction (Section 0) — **not** the flat pop-art comic baseline most other current build prompts use for ability VFX. Also flagged honestly rather than invented: Pyro and Zephyr have no locked accent color anywhere in the project, unlike the other 7 Elements (Terra gold/tan, Cryo icy-blue, Umbra `#B58CF0` violet, Radiant `#FFF7D6` pale yellow, Voltaic a distinct yellow, Toxin acid-green, Aqua teal-white) — the prompt proposes placeholders for those two and says so, rather than presenting a full 9-color table as settled fact. Aqua's shrine is specced dormant/unlit in the ring, same treatment as the already-logged Rift Royale reserved-corner idea, since Aqua isn't built in Studio yet either.

**Not yet done:** Phase 1 (audit) hasn't run. Nothing built, nothing in Studio, manual still not updated with any of this Hub work.

## 2026-10-08 — Hub build prompt simplified after Phase 2's actual output; staircase/spire cut, execution-discipline rules added

The owner ran Phase 2 of the staircase-centerpiece build prompt (above) in a separate Opus 5.5 / Blender session and sent back a render comparing three centerpiece variations ("Armillary," "Needle," "Gallery"). None of them landed — all three came out as thin, uniform-width tube/pipe geometry on a flat single-color disc with lines overlaid on top rather than carved into it, under a photoreal cloud skybox that clashed with the rest of the low-poly scene. Owner's own read, unprompted: it was sliding back toward "the novelty look the first-ever map had," and asked directly how Rivals avoids this.

**First pass at the answer was an execution diagnosis, not a concept change:** Rivals reads as "simple" through three concrete things the failed render got wrong — mass over wireframe (chunky solid forms, not thin tubes), a tight capped material palette with one deliberate accent rather than many competing materials, and backdrop/foreground fidelity matching (a low-poly scene needs a low-poly-appropriate sky, not a photoreal one). Recommended against letting Phase 3 proceed on top of this.

**Owner's follow-up ("I want simplicity like Rivals, not a crazy thing") escalated this from "fix the execution" to "the concept itself is too ornate."** Agreed, and revised **`Opus55_Hub_Observatory_Build.md`** directly rather than just giving verbal notes, since that's the file any future build session will actually read:
- **Centerpiece changed:** spiral staircase + lookout spire → a plain flat-topped raised dais, no stairs, no climbable structure, rune-circle carved into its flat top. The "flat layout, fast mobile navigation" reasoning that was already applied to the segments now applies to the center too.
- **Perimeter markers simplified:** the 9 Element shrines are now explicitly one repeated plain pylon shape, differing only by accent color (and Aqua's being unlit) — the prompt now says directly not to individually sculpt or theme each one, closing off the exact kind of per-piece ornamentation that produced the failed render's inconsistent look.
- **New "Execution discipline" block added to the prompt itself** (not just this diary): a hard two-materials-plus-one-emissive-accent cap, a "carved not painted" rule for every rune-line, and a requirement to match the Hub's sky/backdrop to Skyline's actual construction rather than a default asset — written as direct countermeasures to the three specific things the failed render got wrong, so the next build session is working from the diagnosis, not just a vaguer "make it simpler" instruction.
- **Phases collapsed from 3 to 2:** audit, then one build pass with a single blockout/silhouette checkpoint before final detail. The centerpiece no longer needs its own dedicated design-variation gate now that it's deliberately plain — the old 3-phase structure existed specifically because the staircase was load-bearing; it isn't anymore.

Revised file sent to the owner. **Supersedes, not replaces,** the 10-07 "flat-plus-staircase" entry above — that entry's reasoning for a flat layout over a climbable tower still stands, only the centerpiece's own shape changed. Phase 1 still hasn't run under either version of the prompt; nothing is built in Studio yet.

## 2026-10-08 — Staircase reintroduced, scoped to one segment pair: Store and Training Grounds go two-story

Same day as the simplification above, the owner sketched a different idea, unprompted by anything in the build prompt: the circle still holds all 4 segments, but 2 are shown flat in the diagram and 2 are drawn stacked — one "on the 2nd floor," one "below the 2nd floor area" — connected by a staircase whose railing shows featured items. Worth being explicit about this: it's not a reversal of the 10-07 "no climbable tower" call, it's a narrower version of it — verticality comes back, but only for a part of the Hub that was already flagged as safe to spend extra geometry on.

**Clarified via a quick multiple-choice round before touching the file again** (expensive to get wrong a third time): what the 2nd floor is for, where it sits, and whether it replaces or adds to the already-planned perimeter featured-item displays. Owner's answer resolved the first cleanly — all 4 segments stay, 2 shown flat in the circle, 1 up, 1 down — and left the other two ("where" and "replace vs. add") to a recommendation.

**Recommendation given and accepted:** stack Store and Training Grounds into one combined footprint — **Training Grounds on the ground floor, Store on the 2nd floor above it** — and leave Loadout and Duels exactly as they were, permanently flat. The reasoning: Loadout and Duels are the two segments every match cycle actually touches (spawn → gear up → duel → repeat), which is the entire reason the flat layout exists in the first place; Store and Training Grounds are both optional, occasional visits, so they're the only two segments that can absorb stairs without touching loop speed. Store-on-top also gives the staircase railing's featured-item display a real mechanical tie-in — you browse the featured cosmetics on the way up, then you're standing in the shop that sells them — instead of being a disconnected decoration. The featured-item display **replaces** the perimeter ring's old featured-cosmetic platforms rather than duplicating them; the ring now just carries the 9 plain Element markers.

**Owner added two more constraints when confirming:** the structure should be **enclosed** (real walls + roof — the one piece of the Hub built that way, everything else stays open-sky), and it should stay **plain, not "headache novel,"** with a feel closer to RIVALS' own lobby lounge — a space worth standing around in, not just a thoroughfare. Folded both into the prompt directly: a single-flight staircase only (no spiral, no multiple landings), a plain gabled/shed roof in the same material family as the rest of the Hub, and a built-in-bench-only interior (no new materials, no separate furniture props) so the "cozy" note doesn't become a loophole for added detail. The existing material cap, mass-over-wireframe, and carved-not-painted rules from the 10-08 simplification above apply to this structure too, no exceptions.

Revised file sent to the owner again. **Builds on, doesn't contradict,** both 10-08 entries above — the dais, the material cap, and the "plain over novel" discipline all carry forward unchanged; this just adds one enclosed, two-story exception to the "flat and open" rule, scoped tightly enough that it shouldn't reopen the problems either earlier revision was written to fix. Phase 1 still hasn't run; nothing is built in Studio yet.

## 2026-10-08 — Phase 2 blockout run; Store/Training building came out detached and undersized — traced to my own ambiguous wording, not a build error

Owner ran Phase 2 of the stacked-Store-over-Training prompt and sent back the blockout render. Most of it matched the brief — disc, ring with pylons, Loadout and Duels bulges, the dais, solid plain shapes in two stone tones, nothing thin — the Execution discipline rules from the two prior revisions held up fine on their own. **The Store/Training building didn't:** it rendered as a small, one-room-per-floor shed, perched up on its own separate raised foundation off to the side of the main disc and reached only by a thin bridge — reading as a disconnected little outcrop, not a wing of the Hub.

**This wasn't a case of the Blender agent ignoring the brief — it followed it exactly as written, and that's the problem.** The build prompt's own layout rule says "each segment is a **separate piece of geometry** that **bulges outward** from the base disc," written to mean *separate mesh/object* (so one segment can be edited later without touching its neighbors) — a modeling instruction. Read the plainer way, it says *physically separate*, and the agent's own self-check report confirms that's the reading it used: it explicitly measured and passed on "12 pieces stick out from the disc, closest two 3.8 studs apart" as a success criterion. The wording was genuinely ambiguous, and the build is a faithful, literal execution of the ambiguous version — worth being direct about that rather than treating it as the build session's mistake.

**Fixed directly in the prompt, not just explained back:**
- A new rule spelled out in plain terms: "separate piece of geometry" means separate mesh only — physically, every segment, the ring, and the Store/Training structure must sit flush against the main disc, zero gap, no plinth, no stilts, no bridge required to reach anything.
- Explicit grounding and sizing added to the Store/Training bullet itself: its ground floor sits flush with the Hub's own floor, and its footprint must read at least as large as Loadout's or Duels' — the rendered version was undersized to the point it couldn't plausibly hold a portal gate, target dummies, a shop counter, and a Cache vendor across its two floors.
- Added a note at the top of Phase 2 telling the build session not to patch the existing blockout, but to rebuild the Store/Training structure's placement and scale from scratch against the corrected wording, then re-run the checkpoint.

Revised file sent back to the owner. The checkpoint itself did its job here — it caught a real problem before any final materials, carving, or color got spent on a wrong shape, which is exactly why Phase 2 has a gate before final detail. Phase 1 still hasn't run; nothing is built in Studio yet; this is the second blockout attempt under the stacked-building layout.

## 2026-10-08 — The "stacked Store-over-Training" reading was wrong from the start; corrected to a cantilever off Training Grounds, confirmed with diagrams

After sending the gap/sizing fix above, the owner's next message ("I meant the 2nd floor one... I dont think you understood anything") made clear the problem went deeper than placement and scale — the whole "Store and Training share one combined two-story footprint" interpretation, going all the way back to the original sketch, was a misread. The real intent, confirmed step by step rather than guessed at again:

- **Not** two segments merged into one stacked building (the 10-08 "staircase reintroduced" entry above). **Not** a fourth wedge with nothing underneath it either (my first correction attempt). The actual design: Loadout, Duels, and **Training Grounds** are three ordinary ground-floor segments, same as the original plan — Training never left the ground. **Store** is a single enclosed room that **cantilevers directly out of Training Grounds' own structure**, overhanging part of it and projecting out past the main disc's rim, so in top-down plan view it reads as its own distinct shape rather than a copy of the wedge underneath it. The staircase up to it **hugs the circular edge of the disc as it climbs** (a curved single flight, not a straight interior run), with the featured-item railing on it, same as before.

**Given three straight misses reconstructing a hand sketch from text alone, this round was resolved with actual diagrams instead of more prose** — rendered two top-down SVG/PNG plans of competing readings, sent each for a direct confirm/correct, and only wrote the third one (the cantilever) once the owner confirmed it matched. Worth remembering for next time a layout gets described only in a quick sketch: draw it back before spending another Blender pass on a guess.

**Rewrote `Opus55_Hub_Observatory_Build.md` a third time** to match, replacing the "Store-over-Training combined structure" framing entirely:
- Training Grounds confirmed as a normal ground segment (quiet-zone treatment unchanged); Loadout, Duels, and Training are explicitly free-form bulge shapes, not equal pie wedges — an equal-wedge diagram was only ever a simplified placeholder.
- Store's room is specced as rising **directly and continuously out of Training Grounds** — no gap, no separate foundation, no bridge — with the one deliberate exception that it's allowed to project past the disc's rim as a cantilever, the same way a real balcony or bay window is one piece with the building it extends from. The "Separate mesh, not separate location" rule from the previous entry got an explicit carve-out added for this, so the next build session doesn't read "it pokes past the rim" as license to detach it again.
- Staircase changed from a straight interior flight to a single continuous curved flight hugging the disc's edge.
- Rune-line network and color-hierarchy bullets corrected to name Loadout/Duels/Training as the three neutral ground-segment lines (Store no longer being a ground segment, it doesn't get its own spoke from the core — just the glow along its own staircase railing).

Revised file sent to the owner. This supersedes the "Store-over-Training, one enclosed two-story structure" framing in both entries above — the enclosed-room, material-cap, and "plain over novel" discipline all carry forward unchanged, only the physical relationship between Store and Training Grounds changed (cantilever off one ground segment, not a shared two-story box). Phase 1 still hasn't run; nothing is built in Studio yet; this is the third rewrite of the Store/Training piece specifically, and worth flagging as the clearest example yet of why a sketch this important should be drawn back and confirmed before committing it to a build prompt.

## 2026-10-09 — Elemental Reactions get a health-bar treatment; full pairwise audit catches a missed Pyro × Voltaic pairing; manual hits v0.22; Reaction Bar Showdown build prompt written

Owner asked, apropos of the Status Bar Showdown work: should a reaction (e.g. Pyro into Chill = Melt) get its own bar effect, distinct from a normal status, to show a reaction actually happened? Answer given directly: yes, and it's a real gap — Status Bar Showdown's payoffs are all same-Element events (Chill's own root-timeout, Charged's own discharge); nothing in it represents a *different* Element's hit landing on an existing status, which is exactly what a Reaction is.

**First pass at an answer was wrong in a way worth keeping on record rather than quietly fixing.** Only quoted three of the six already-confirmed reactions (Melt, Combustion, Wildfire) from `SPELLSHOT_Design_Manual.md`'s own locked table, despite having the full table available — no excuse, just an incomplete read. Owner caught it (Shatter, Windchill, Toxic Squall were the three missed) and the correction covered all six, plus a first attempt at bucketing them by whether a reaction should **reset** the bar (true consumption: Melt, Combustion, Shatter) or **not reset it** (Wildfire, Windchill extend/pump the status instead) or **skip the bar entirely** (Toxic Squall, a world-space-only effect).

**Owner then caught a second, bigger miss: Pyro × Voltaic had never been evaluated at all** — not confirmed, not cut, not flagged, genuinely absent from the manual. Rather than patch in one more row, did a full pairwise pass across every remaining Element combination. Result: **five new reactions confirmed** — **Overload** (Pyro × Voltaic, burst + knockback/stagger), **Frozen** (Cryo × Aqua, upgrades Wet+Chill into a longer/guaranteed Root), and three pairings that extend the already-confirmed Zephyr-amplifier pattern (Wildfire, Windchill) to the Elements it had been missed for when their statuses shipped — **Storm Surge** (Voltaic × Zephyr), **Dust Storm** (Terra × Zephyr), **Windswept** (Aqua × Zephyr). The last three are working names only, not confirmed by the owner. Four more pairings were evaluated and explicitly rejected (Pyro × Terra, Cryo × Terra, Terra × Aqua, Toxin × Aqua) — kept on record in the manual so they aren't re-litigated. **`SPELLSHOT_Design_Manual.md` updated to v0.22** with the full table, the rejections, and a new "Reaction payoff shape" classification (Consumes / Consumes-but-produces-a-new-status / Extends / Doesn't touch a status) that generalizes the reset-vs-no-reset distinction from the first pass into something every current and future reaction gets classified against.

**Two flags surfaced during this pass, neither resolved, both now on record in the manual itself:**
- **"Overload" (the new reaction) and "Overload Battery" (Charged's leading, not-fully-locked status-bar skin name from the Status Bar Showdown vote) are easy to confuse** — same word, two different UI contexts.
- **Terra's Cracked status still has no bar-skin design anywhere in the project** — not in `Status_Bar_Showdown.html`, not in its results doc. Dust Storm amplifies a status that has no visual yet, which is a real sequencing gap, not something fixable from inside a reactions-table edit.

**Owner's actual ask once the table was right: build this as a visual comparison page, same format as Status Bar Showdown's A/B/C options.** Wrote `Opus55_ReactionBar_Showdown_Build.md` for it (via `/opus-5-5-prompt-writer`, per this project's standing convention for anything headed to a separate Opus 5.5 build session). Covers all 10 reactions that touch the health bar (Toxic Squall is explicitly excluded — world-space only) in a reinterpreted A/B/C split for one-shot clash events rather than persistent loops (A — Consume & Flare, reads from inside the existing status skin; B — Clash Strike, the incoming Element visibly attacks from outside; C — Hybrid Skin, a distinct blended-Element skin unique to that reaction), each resolved per its payoff shape rather than one universal ending. Both open flags above are carried into the prompt rather than silently decided, plus the three unconfirmed working names and the fact that Charged's and Wet's own base bar skins aren't fully locked yet (leading picks used, marked provisional). **Phased with a checkpoint:** build Melt and Windchill fully first (one Consumes, one Extends, both already-familiar), present, and stop before the other eight — same insurance-against-a-bad-unreviewed-assumption logic as the Hub centerpiece's repeated rewrites above, just applied before the expensive part happens instead of after.

**Not yet done:** the build prompt hasn't been run by anyone yet; no Reaction Bar Showdown page exists; the three working names and the two base-skin provisionality flags are unresolved; manual is at v0.22.

## 2026-10-1x (exact date uncertain — logged retroactively after a context compaction) — Duel Pad cluster critiqued; Umbra "Bloodmoon" wrap designed and prompted

Logging two threads together that happened after the Reaction Bar entry above but before this session's context was compacted, so the exact date within the gap isn't certain.

**Duel Pad cluster critique, still open.** Owner shared renders of the in-progress Duels segment (the ring of pads on its own base disc). First round of feedback was abstract ("raise the collars, add rune-glow, fix the color hierarchy") and the owner correctly rejected it as too vague for a model the owner described as still "simple" — asked directly for literal objects/geometry to add, not polish principles. Second round gave concrete physical additions instead. **No build prompt was written for this.** It's still an open thread — nothing here has been formalized into a revision of `Opus55_Hub_Observatory_Build.md` yet, and it may end up folded into the Ley Duality work below rather than staying separate, since both eventually touch the same disc.

**Umbra "Bloodmoon," closed.** Owner asked for wrap/skin ideas for Umbra. First pass over-elaborated (multi-tier rarity ladder, bespoke lore names) and the owner pushed back — a "wrap" in this project means one simple, kit-wide recolor, same category as Azure Pyro or Magma Terra, not a new cosmetic tier. Re-pitched as six one-line wrap concepts; owner picked **Bloodmoon**. Confirmed it should be a Spell VFX wrap (not a Full Element skin bundle) given it's a pure palette swap on Umbra's existing kit, gave a per-move breakdown, owner approved, prompt written: `Opus55_Umbra_Bloodmoon_Wrap_Build.md`. Palette: glint→pale rose-white, shade→crimson, dusk→deep blood-red, void→oxblood. Carries the same "no meshes, Beams/images/lights only" construction note Umbra's base kit already established (v0.18), framed explicitly as a recolor job, not a material rebuild. **Not yet run by anyone.**

## 2026-10-12 — Hub's neutral palette reworked into "the Ley Duality" (black/white, 50/50, no gold); first real use of the lore codex; dais becomes a signature taijitu piece

**Started from a research upload, not a request.** Owner uploaded `RIVALS_HUB_DETAILS_REPORT.html` — a 60-photo walkthrough analysis of RIVALS' actual hub, pre-filtered against SPELLSHOT's own locked rules (it already used this project's own vocabulary — "one-accent rule," "no loose clutter" — so it was built with manual awareness, not generic). 13 prioritized ideas for the Hub, each checked against what SPELLSHOT's rules would allow as-is vs. what they'd require relaxing. Asked the owner which direction to take it in (narrow to the Duel Pad cluster, whole-Hub pass, or talk it through first) rather than guessing scope on a file with no accompanying text — owner chose to talk it through.

**Sorted the 13 into tiers** (core trio worth doing first: doorway name signs, live-data wall tablets, duel-pad waiting-count markers; cheap wins with no rule conflict; two real decisions — niche lighting color, loose-vs-built-in furniture — that bend a locked rule either way; one item, the "eye-catcher view," that doesn't actually port since it depends on contrast against a dark hub RIVALS has and SPELLSHOT doesn't).

**Owner raised the real concern directly: even with RIVALS' specific skin filtered out, would this still read as a copy, since every idea came from literal screenshots of their hub?** Correct call — the actual RIVALS fingerprint left in the list wasn't the mechanisms (signage, boards, floor lines — near-universal hub-game grammar), it was specifically *how you tell rooms apart by color*. Owner's fix: SPELLSHOT's own lore has a concept — the Ley — that could replace it, and proposed a black/white/grey "yin and yang" treatment instead of any RIVALS-style per-zone hue, tied to the Ley being presented as a unified, undivided force before the Elements existed.

**Owner then uploaded the actual lore source** (`spellshot_lore.pdf`, a 3-page "Sundering of the Ley" codex) rather than leaving this as a loose idea. Read it directly (text layer didn't extract cleanly; rasterized and read the pages as images) and transcribed a persistent copy to `SPELLSHOT_Lore_Ley_Sundering.md`, since it lived only in a temporary upload before this. **Correcting an assumption made before reading it:** guessed the Ley might directly explain Aqua's place in the 9-Element roster; the doc actually names only 8 founding Cores (no Aqua) and has a separate "Unfound Cores" mechanism (two Echoes fusing over time into a new, complete Core) that's the obvious but *unconfirmed* in-fiction slot for Aqua and future Elements — flagged in the lore file rather than stated as settled, since the owner hasn't actually confirmed that's Aqua's origin.

**Also worth being plain about: the black/white/yin-yang color idea is not in the lore document itself.** The source text has zero color language — it's the owner's own extension of "unbroken, undivided, before it had cause to divide" into a visual system, confirmed directly by the owner, not something the lore doc already specified.

**Three decisions locked directly with the owner, in order:**
1. Yin = black, yang = white (the traditional pairing — owner's first instinct had them backwards and corrected to the standard mapping once it was named).
2. Gold is fully retired, not kept as a secondary accent alongside black/white — owner's reasoning: keeping any one accent hue, even a new one, still repeats RIVALS' "a color tells you where to look" logic. Interactive/signal reads via brightness-contrast instead (a stark glow in the opposite tone), no hue at all.
3. The split is a true, balanced 50/50, not white-dominant. This was raised as a real tension against two existing facts — the Hub's locked "light and airy" character, and Umbra's kit already owning a dark-dominant/pale-rare ratio — and the owner overrode both concerns directly ("who cares about element being confused with hub") rather than it being quietly resolved either way. Logging the tradeoff here since it was a deliberate call, not an oversight.

**Build prompt written:** `Opus55_Hub_LeyDuality_Build.md` — a revision prompt against `Opus55_Hub_Observatory_Build.md`'s Execution Discipline and Color Hierarchy sections specifically, not a new Hub build. Locks: the whole disc (not per-room) reads as a yin-yang shape via a single S-curve boundary through the dais, continuing the already-established "the Hub IS a rune, not built on one" logic one step further; the dais becomes the signature piece — a literal split taijitu top with reciprocal seed-dot inlays in each half; per-Element perimeter marker colors are explicitly untouched; a Step 2 checkpoint gates the dais retrofit alone before the duality extends across the rest of the disc. Flagged edge cases rather than silently deciding them: whether a plain white base material and a white emissive glow will actually read as visually distinct once built, and whether the existing per-Element marker colors (especially the cooler ones) might read as washed out against a true-white half where they previously sat against a warmer neutral.

**Deliberately excluded from this prompt, flagged as a separate open thread:** the rest of the RIVALS report's 13 ideas (doorway signage, live tablets, duel-pad markers, niches, furniture, honour alcove) and the still-open Duel Pad cluster critique from the entry above — both remain undecided, not folded in just because they touch the same disc.

**Not yet done:** this build prompt hasn't been run by anyone yet; no Studio changes exist from it; whether Aqua is actually an Unfound Core is unconfirmed; the rest of the RIVALS report's ideas and the Duel Pad cluster critique are both still open; manual is still at v0.22 (no manual edit was made for this — the Hub's material/color rules live entirely in the build-prompt files, not the manual, so none of the manual's sections needed changing).

## 2026-10-13 — Lore codex rewritten: Yin and Yang are now two of the Ley's primary fragments, not just a Hub color scheme; the 8-founding-Cores structure is retired

**Owner pointed out the gap directly:** the Ley Duality work above only used the lore's "unbroken, undivided" framing as inspiration for a color choice — the actual lore document never mentioned yin/yang at all. Asked to update the lore itself so the concept actually lives there, and to ask questions first rather than guess at a creative-canon change.

**Asked three questions before touching the file** (via AskUserQuestion): whether the duality should just describe the Ley's nature or actually explain why the Sundering happened and why there are 8 Cores; whether "yin and yang" should be the literal in-world term or get an invented name to match the rest of the doc's voice; and whether to expand Section I in place or give it a new dedicated section.

**The owner's answer was bigger than any of the three options offered, and changed the Cores' structure itself:** only four Elements descend directly from the Ley as classical Cores — Pyro, Zephyr, Aqua, Terra. Everything else in the 9-Element roster is "the combination thing," not founding fragments on equal footing. This also resolves the open Aqua flag from the previous entry, the other direction from what was guessed — Aqua is a classical primary, not an Unfound Core. "Yin and yang" stays as the literal term (owner's explicit call, not an invented coinage), and the change lives in Section I as asked.

**Construction needed to reconcile the owner's directive with the existing nine-Element roster and with Section V's "Unfound Cores" mechanism (which assumes slow, centuries-later fusion, not something that already produced most of launch's roster).** Proposed, not dictated by the owner: Yin and Yang themselves are two more primary Cores (not classical, but the Ley's own two faces, unmixed) — Radiant is Yang worn directly, Umbra is Yin worn directly, explaining why neither reads as a classical element. The three remaining Elements (Cryo, Voltaic, Toxin) are compounds of a classical Core and a polarity, but formed quickly in the Sundering's own original violence — not the slow drift Section V describes — which is what keeps Section V's actual subject (future, still-undiscovered Unfound Cores) from contradicting itself against Elements that are already known and shipped. Six primary Cores (four classical, two polarity) plus three known compounds = nine, matching the live roster exactly.

**The specific compound pairings are flagged as this session's proposal, explicitly not locked:** Cryo = Aqua+Yin, Voltaic = Zephyr+Yang, Toxin = Terra+Yin. The owner confirmed the shape of the structure, not these three specific pairings — said so plainly in the file itself rather than presenting a guess as settled.

**One light touch, not asked for but low-risk:** gave "yin" and "yang" an in-fiction home by attributing the terms to the doc's own pre-existing "eastern chronicles" (Section I already distinguished eastern/western/Hub-priesthood accounts of the Sundering before this revision), so the real-world term doesn't sit in the text with no in-world source.

**Rewrote:** `SPELLSHOT_Lore_Ley_Sundering.md` — Section I's Cores paragraph and two new paragraphs (Radiant/Umbra as unmixed polarities; Cryo/Voltaic/Toxin as compounds), Section V's opening and internal "eight" references, the closing loading-screen blurb, and the file's own cross-reference notes. Original "eight Cores, eight alone" source text preserved verbatim as a labeled historical editorial note rather than silently overwritten, with a revision note explaining what changed and why directly beneath it.

**Not yet done:** the specific compound pairings (Cryo/Voltaic/Toxin's parentage) are unconfirmed by the owner; no manual edit was made — Section 2 of `SPELLSHOT_Design_Manual.md` still has no lore content at all, and the source doc's own editorial note has always suggested this material belongs there eventually; Radiant's and Umbra's locked accent colors are untouched and this revision doesn't propose changing them, but both kits now carry lore weight (Yang/Yin unmixed) they didn't have before, worth knowing about if either kit is revisited; manual is still at v0.22.

## 2026-10-13 — Hub centerpiece revised again: the yin-yang split dais was premature; replaced with a whole, non-foreshadowing "Ley Crystal," plus four new inner pillars for the four classical Cores

**The Ley Duality build prompt from earlier today was already run** — owner confirmed "Claude made the hub," reacting to the actual built result rather than the prompt text. Two changes came back from that review.

**The split-taijitu dais was wrong, and for a sharp reason:** the owner pointed out that in SPELLSHOT's current story, the Ley hasn't actually split into Yin and Yang yet — that's a future narrative event. A centerpiece already showing the post-split duality tells players something that hasn't happened. Replacing it with a **Ley Crystal** instead: the Ley itself, physically present in the Hub, currently whole, built from the same two true colors (black and white) but explicitly *not* arranged as a legible split — no seam, no two-colored halves, nothing a screenshot could caption as "cut in half." As the story progresses in later content, the crystal is meant to visibly crack and eventually resolve into Yin and Yang — not built in this prompt (that's a future systems/narrative task), but the reason the current crystal has to avoid foreshadowing it now.

**This also surfaces a real tension in the lore file itself, flagged rather than resolved:** the codex's five sections narrate the Sundering as complete, ancient history, matching the live game (nine Cores already known and playable). A crystal that's currently whole and will split "as the story progresses" describes something still in motion. Two unconfirmed readings were logged in the lore file rather than picking one: either the Hub's crystal is a smaller, separate echo of the original Sundering (consistent with Section V's "the Ley has not stopped becoming, it has only slowed"), or the five sections describe the Cores' origin in a general sense while the crystal dramatizes one further specific event still to come. Left open for the owner.

**Four new pillars, settled (not exploratory like the crystal):** one each for the four classical Cores — Pyro, Zephyr, Aqua, Terra — in a small inner ring around the dais, inside the existing outer 9-marker ring (which is untouched). Spatial logic proposed by this session, not stated by the owner in those words: standing closer to the crystal than the five polarity/compound Cores reflects that these four are made of the Ley's substance directly. Flagged as a reading of "pillars in the middle" that could be wrong, not as confirmed intent.

**Build prompt written:** `Opus55_Hub_LeyCrystal_Build.md`, chained after `Opus55_Hub_LeyDuality_Build.md` the same way that one chained after the original Hub Observatory prompt. The crystal part is explicitly exploratory and gated — three distinct starting directions proposed (marbled monolith, faceted cluster, opal core — each solving "both colors, no legible split" with a different technique: veining, facet randomization, angle-dependent shimmer), build all three, present, do not install any as final, wait for a pick. The pillar part is settled and just gets built.

**Not yet done:** none of this has been run in Studio yet; which of the three crystal variations (if any) the owner wants is unresolved by design — that's the whole point of the checkpoint; whether "four pillars around the dais" is the right spatial reading of what the owner meant is unconfirmed; the lore tension between "Sundering already complete" and "crystal still whole, splits later" is logged but not resolved; whether the rest of the Hub's black/white 50/50 split (the floor, the segments, the outer ring — built by the Ley Duality prompt) should also be dialed back under the same "don't foreshadow" logic that killed the split dais was raised back to the owner, not decided here.

## 2026-10-13 — Hub aesthetic pivot: a reference image asks for a much richer whole-Hub look; reconciled against the material cap, not against layout or the duality system

**Started from a reference image, not a direct answer to the open question above.** The still-open question from the previous entry (should the rest of the Hub's black/white 50/50 split also pull back under the "don't foreshadow" logic?) was asked directly and the owner's next message didn't answer it — instead a composite 8-panel render arrived: a warm, torch-lit, gold-trimmed, fully enclosed stone hall with statues, banners, ivy, richly dressed single-Element-themed gate archways, and a domed ceiling with an oculus, plus a floating centerpiece orb showing a visible yin-yang symbol. Owner's instruction: "I need the designs to look like this."

**Checked three things before writing anything, since the image contradicted several already-locked facts at once (open-sky layout, no-gold material rule, the don't-foreshadow rule, segments being Element-neutral) and guessing which of those were meant to actually change on a build this size would be expensive to get wrong:** asked via AskUserQuestion whether this is a reference image or something already built, how far the richness should reach (just the centerpiece vs. the whole Hub), and whether the standing rules the image visibly breaks should still hold.

**Owner's answers:** it's a reference image, not anything built yet. The richer look should reach **the whole Hub**, not just the centerpiece — confirmed directly as a real rewrite of the locked Execution Discipline material cap, not a narrow ask. And: ignore the image's visible yin-yang symbol, ignore its per-Element gate naming, and ignore "the things this img contradicts" generally — meaning the don't-foreshadow rule and the segments-are-neutral rule both stand; the image is reference for material/ornament/mood only, not a literal spec.

**Two conflicts the owner's answer didn't explicitly address, so a judgment call was made rather than guessed silently — both flagged plainly in the build prompt itself rather than decided and left unstated:**
- **Open-sky "Observatory" roof vs. the reference's enclosed domed hall.** Kept open-sky as the default, since the owner's "ignore what it contradicts" instruction came specifically in response to the symbol/gate-naming question, not this one. The build prompt still allows a flagged, contained exception (a partial canopy or exposed beams over one zone) if the torchlit mood genuinely can't be sold without any overhead structure at all — but a full enclosed roof is out by default.
- **No-gold Ley Duality rule vs. the reference being gold-trimmed throughout.** Kept no-gold as the default too, for the same reason the Ley Duality prompt gave it in the first place: keeping any one accent color, even a different one, still repeats the "a color tells you where to look" logic that rule exists to avoid. Gold trim/banners/metal in the reference get rebuilt in pale/silver/warm-white metal instead; actual torch and brazier firelight stays allowed as a lighting layer (a light color, not a structural material), with an explicit flagged-exception path if pale metal reads visibly flatter or cheaper once actually built.

**Everything else from the chain carries forward untouched:** the open disc/bulge-segment layout, Store's cantilever and staircase, the black/white 50/50 structural split and its S-curve logic, every locked and proposed per-Element accent color, and the still-pending four-pillar and three-Ley-Crystal-variation tasks from the previous entry — which this prompt re-scopes to be *built* in the new richer style (dressed archway treatment, icon, glowing nameplate) rather than adding a third task on top of them.

**Build prompt written:** `Opus55_Hub_Aesthetic_Revision_Build.md`, a third chained follow-up (`Opus55_Hub_Observatory_Build.md` → `Opus55_Hub_LeyDuality_Build.md` → `Opus55_Hub_LeyCrystal_Build.md` → this one). Unlike the other two follow-ups, it doesn't add a feature — it loosens the original prompt's own material-cap rule, so its Context section spends most of its length on exactly what's being kept vs. overridden, flagged as worth reading carefully for that reason. Edge cases carry both judgment calls forward explicitly (flag if pale-metal reads cheap; flag if any overhead structure is genuinely needed) plus a clutter guard (ivy/statues/banners can't be allowed to fight the still-standing "mass over wireframe"/"carved not painted" discipline just because the brief asked for "more") and an Element-bleed guard (stop and flag if any segment archway starts reading as belonging to one Element through icon/color/signage choice).

**Not yet done:** this build prompt hasn't been run by anyone yet; none of the previous entry's four-pillar/three-crystal tasks have been attempted in this richer style yet; the open question of whether the Hub-wide 50/50 split itself should pull back under the foreshadowing logic is still not explicitly re-confirmed by the owner — it's implicitly carried forward as "stays locked, out of scope" in this new prompt, but that's this session's reading of silence on the point, not a direct answer; the two judgment calls above (open-sky default, no-gold default) are flagged to the owner in this diary entry and in the prompt itself, not yet confirmed as the right calls.

## 2026-10-13 — Cosmetic hierarchy rebuilt: five systems replace the old flat skin/wrap list, Skin Ascension retired, manual hits v0.23

Separate thread from the Hub work above — worked out entirely in chat, no build prompt yet, straight into the manual once settled. Started from the owner wanting to design a rarity-tier stretch for cosmetics ("mythical skin would be like the whole element different model but additionally the visuals of the UI... character avatar have a cool effect"), and went through several real misunderstandings on my part that are worth keeping on record so they aren't repeated.

**Rarity tiers locked: Uncommon → Rare → Epic → Mythic.** Drops Common from the old v0.6-era list on purpose — there's no rung below Uncommon, the stock/default look simply isn't a cosmetic, not a bottom tier of one.

**Skin Ascension is retired outright, owner's explicit instruction ("no more feature of the merging thing").** Nothing in the game merges duplicate drops into a better cosmetic anymore. This was load-bearing in three places that needed a real answer, not a silent delete: the Elemental Cache's old reason for excluding Mythic ("earned only via Ascension"), the Sinks list (Section 6), and the Season 3 roadmap line ("Add Mythic Ascension system," Section 13). Resolved by folding Mythic into the Cache's own disclosed odds at a small weight instead of gating it behind a grind-to-evolve loop, and by replacing the Season 3 roadmap slot with "introduce per-Element Mastery name cards/banners" — flagged in the manual itself as this session's placement guess, not confirmed by the owner.

**First attempt at the tier ladder was wrong, and the owner corrected it plainly.** I had Uncommon as a bare recolor and "remodel" as something that gets added at a higher tier. Backwards: **a full Blender remodel of the ability kit — new geometry, not a recolor — is the floor for every tier of an Element Skin, including Uncommon.** That remodel is what separates an Element Skin from a Wrap in the first place, not something tiers unlock partway up. What actually scales with rarity is what gets layered on top of that constant remodel: Rare adds richer/animated particle VFX, Epic adds ability-icon and health-bar-accent reskins, Mythic adds a kill effect and — the one tier that reaches past the kit and onto the player's own body — a matching character-avatar change.

**Five systems now cover the whole cosmetic economy, replacing the old flat list (Section 7, manual v0.23):**
1. **Element Skins** — the tiered ladder above, per Element, direct purchase only (an Uncommon Element Skin is already a bigger asset than anything a Cache should sell, same reasoning that already kept New Technique Looks out of the Cache).
2. **Wraps** — same four tiers, same stacking logic, one absolute rule: geometry never changes, at any tier, ever. This directly answered the owner's own open question ("not sure if wraps should get a character avatar thing") — no, Wrap-Mythic can't get the avatar swap without breaking the one thing that defines a Wrap, so its top payoff is an aura/trail effect on the *existing* avatar instead.
3. **Character skins** — off the ladder entirely. Flat, themed, one-off bundles (Halloween Pyro, Santa Cryo) bundling a themed kit remodel + a themed avatar + a themed kill effect as one purchase, Element-locked by default. **Flagged, not decided:** a second, Element-agnostic "Outfit" line (avatar-only, no kit remodel, wearable regardless of active Element, same logic as Accessories) is a real candidate the owner floated but didn't commit to — written into the manual as an open idea, nothing built against it.
4. **Accessory boxes** — a new, separate Cache from the Elemental Cache, same four tiers, drops attachable items (hat/held charm/etc.) that layer onto whatever Skin or Wrap is equipped, not tied to any Element.
5. **Name cards / profile banners** — earned via per-Element Mastery, never bought or boxed. **Second misunderstanding, also corrected directly:** I first proposed three separate card designs per Element (reusing the Rare/Epic/Mythic names). Wrong — it's **one card per Element that gains progressively more visual effects at three mastery milestones** (bare at the first, partial effects at the second, full effects at the max), not three different cards. Shown when another player clicks your profile — confirms a clickable player-profile surface exists/is planned, which wasn't in the manual before this.

**Manual updated to v0.23** (Section 7 rewritten in full, Section 8's pricing table rebuilt with per-tier Wrap/Element Skin pricing and the new Accessory Cache, Section 6's Sinks line and wording, Section 13's Season 3 slot, Section 14's metrics wording). The old "Full Element skin bundle" (Character skin + all VFX skins at a discount) is retired — it bundled two things that are deliberately separate systems now, and no replacement bundle exists yet, flagged as an open idea rather than solved here.

**Not yet done:** no build prompt written for any of this yet; exact Mastery-rank numbers for the name-card milestones aren't set (the owner's 10/15/20 was explicitly an example, not a lock); whether the Element-agnostic "Outfit" line actually gets built is still open; the Season 3 roadmap placement for name cards is this session's guess, not the owner's; none of the new price points have been tuned against anything.
