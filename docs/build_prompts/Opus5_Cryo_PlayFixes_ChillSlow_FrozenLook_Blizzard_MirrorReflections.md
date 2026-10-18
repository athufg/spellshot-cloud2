# SPELLSHOT — Build Prompt #[N]: Cryo play-test fixes (Chill 3 slow, frozen look, Blizzard box, Mirror Cage reflections)

Continuation of the Opus 5 / Claude Code build sequence (previous: the Cryo v2 kit prompts; [N] is unknown, so keep the placeholder and ask where the sequence lives if it matters).
This is visual and gameplay-tuning work on abilities that are already built and playing in Roblox. Four fixes, each its own sub-task with its own checkpoint. Do them in order, one at a time. Everything below the "Current state" section was seen by the user in play and is real; everything marked PROPOSAL is mine, not decided.

## Current state (confirmed from a play-test video and a screenshot, NOT from code — read the code before trusting this)

- **Icicle Shard / Chill:** Chill caps move speed to 22 at 1 stack and 15 at 2; stacks lapse after 3.0 s; the **3rd stack currently roots for 0.8 s then gives 1.2 s immunity**, and the existing `FROZEN!` callout appears on the target (held while an `IceFrozenState` child exists, created by `VFXLibrary.ApplyFrozenState`).
- **Frozen look:** a frozen target (dummy or player) reads as a **flat dark slate-blue silhouette** with a thin white outline. In the Flash Freeze video the ice spikes stand around the dummies, but the bodies themselves look black-grey, not icy. The engine notes say a `Highlight` is used for the frozen-state tint, so the dark fill very likely comes from that tint's colour/transparency or from something multiplying it. Find the actual cause first.
- **Blizzard (Technique):** seen from inside **someone else's** Blizzard, the storm reads as a **box**: straight vertical white strips and flat walls instead of a round storm. Not yet checked from outside or as the caster. The cause is unknown (a box-shaped emitter, wall parts, or a rectangular region effect are all possible).
- **Mirror Cage (Ultimate):** hexagonal translucent ice-mirror panels with cyan edges form a hemisphere around the target and fire bolts. The user likes the cage and wants **no change to its shape, size, timing or layout**. The panels are currently empty glass: there is nothing reflected in them.
- Good and to be kept as it is: the Flash Freeze zone, the shatter wave, the FROZEN! comic burst art, the Frost Line.

## Reference before styling

- **Mirror Cage reflections.** The user supplied one reference frame (attach it to this run if you can; if it is not attached, work from the words below). It is an anime still of a ring of tall ice-mirror panes around two fighters. Each pane is a pale blue-white sheet with a ragged frosted white border and icicle drips along the bottom edge. Two or three hard-edged white diagonal glare streaks cross every pane at the same angle. **Inside every pane is a reflection of the same person, at a different angle and pose in each pane**, so the target is surrounded by copies of the attacker. This is inspiration for the idea, not an asset: the reflections must be the **caster** of Mirror Cage, never any anime character, and nothing is copied.
- **Frozen look and Blizzard.** No reference supplied. Use the user's play-test screenshot (dark silhouette + FROZEN! burst) as the "before". For the target look, use the Cryo toon bands that already ship. Before styling the frozen look, render the **before and after side by side on a dummy at on-screen size**.

## Fix 1 — Chill stack 3 = slow, not root (gameplay + callout)

**Design decision (the user's):** three Icicle Shard stacks no longer root. A root is too strong for a basic attack. Rooting stays with Flash Freeze, Deep Freeze and the Mirror Cage.

**Gameplay.**
- Remove the 3rd-stack root. At 3 stacks, apply a deeper slow instead.
- **PROPOSAL (flag it as a tuning decision):** cap move speed at 10 while 3 stacks are held (Chill Aura slows to 8, Cryo Beam to 9, Chill 2 stacks is 15). Stacks still lapse after 3.0 s as today. Keep every other Chill rule as it is.
- The 1.2 s post-root immunity existed to stop a root chain. Decide whether it still needs to exist for a slow. Do not guess: flag it, say what you did, and leave it a single number in the tuning table.
- Do not let the 3rd stack create `IceFrozenState`. That is what triggers `FROZEN!`, and it must stay reserved for real freezes (Flash Freeze root, Deep Freeze, Mirror Cage kill, shatter).

**Callout and status.** Do not invent a new word or a new callout path.
- Extend the existing `chill` style from CHILL x1 / x2 to also show **CHILL x3**, read from `RX_Chilled_Stacks`.
- Make the existing Chilled status reaction visibly heavier at 3 stacks (it already reads `RX_Chilled_Stacks`).
- **PROPOSAL, small:** a thin rime of ice on the target's feet and lower legs at 3 stacks, using the existing `RimeCrust_*` meshes, plus slightly bigger frost puffs on footsteps. It must read `RX_Chilled_Stacks`, not a new counter. Skip it if it clutters at ten studs.
- **FLAG, do not decide:** whether the user wants a word like "SLOWED" at stack 3. The default is no new word.

**Docs.** The design manual still says "3 stacks briefly roots". Do not edit the manual. Tell the user the line needs changing.

## Fix 2 — Frozen target must look like ice, not a black silhouette

**Goal.** A frozen target is still readable as a body (players must see who is frozen) but reads clearly as frozen in pale ice, not as a dark cut-out. It applies to every freeze source: Flash Freeze, Deep Freeze, Mirror Cage, on players and on dummies.

**Direction.**
1. Find what makes it dark: the Highlight fill colour/transparency, a tint multiplying the body colour, or both. Report the cause in one sentence before you change it.
2. Recolour with the shipped Cryo bands, flat, no gradient: a pale **IceLight `#D6F6FF`** body fill with the **IceMid `#3FB6F0`** only in shadow areas, a thin white rim, and the existing Outline `#080E1A` where outlines exist. A Highlight fill is acceptable for the tint; pick a fill transparency that keeps the body readable and keeps the player's identity (a headshot target must not change shape).
3. Add frost on the body so it reads as "frozen" even without the tint: white frost caps on the shoulders and head and a frost crust that climbs from the feet to the waist (the Frost Line direction). Reuse `RimeCrust_01/02` and `NovaCrust_01–04` first; only author new meshes if nothing fits. All crystal and crust meshes stay **opaque, white SmoothPlastic, `DoubleSided = false`**. Do not make crust meshes transparent, because the inverted hull shows black through transparency.
4. Do **not** wrap the whole body in an opaque block (it would hide the target). Cover at most the legs to the waist.
5. Keep the `FROZEN!` burst and its hold behaviour exactly as they are.

**Colourblind-Safe.** Frozen is identified by shape: the frost crust, the crystal cluster and the burst. Colour is secondary.

**Checkpoint (required).** Before you apply it everywhere, post one screenshot at on-screen size (about ten studs away, third person) of a frozen dummy **before and after**. Wait for approval.

## Fix 3 — Blizzard must be round, not a box

**Goal.** A Blizzard looks like a round storm from every vantage: as the caster, as a bystander outside, and **inside someone else's**. There are no straight walls or corners.

**Direction.**
1. Test and report what each of the three vantages shows before you change anything.
2. Find the cause. Likely suspects: a `ParticleEmitter` with `Shape = Box`; wall or panel parts; a rectangular region used to drive a fog or Atmosphere effect. A fix must remove the box at its source, not hide it.
3. Rebuild the volume as a **cylinder or dome**. For particles, use the emitter's `Shape = Cylinder` (or `Disc` for the floor swirl) with `ShapeStyle` and `ShapeInOut` set so the snow sits inside the radius. The boundary must be soft: density falls off toward the edge instead of ending at a hard line.
4. The "reduced visibility inside" effect should be a **screen-space whiteout** on the local client, not world geometry. The existing `RX_VisionDenial` status reaction is the obvious hook. Use it before building anything new.
5. The caster's own storm may use `VFXLibrary.RegisterProximityFade`. Do not extend it to other players' storms.
6. Keep the storm's main read hard-edged where it is a silhouette (angular snow flecks, the existing `Shard` sprite). Soft sprites only as short, small support.

**Budget.** Emitters through `emitter()` (honours Graphics Quality and Reduce Enemy VFX). Set a maximum particle count and say what it is. Must hold on low-end mobile with several storms and status reactions on screen.

**Checkpoint.** Three screenshots (outside, inside someone else's, the caster's own) before you call it done.

## Fix 4 — Mirror Cage panels show reflections of the caster

**Goal.** Every panel looks like a real mirror: it shows the caster, at a different angle and pose in each panel, with hard white glare streaks. The target inside is surrounded by copies of the attacker.

**Do not change** the panel shape, count, size, timing or the bolt behaviour.

**Direction (all PROPOSAL, flag the choice you make):**
1. **Reflection content.** Default approach, cheapest on mobile: a flat **caster silhouette card** per panel, drawn in the third-person body colours (torso Base, arms Dark, hands Light, head and legs neutral) in 4 to 5 poses (front, three-quarter left, three-quarter right, back, and the cast pose). A card is one ImageLabel/Decal on a plane just inside each panel, ice-tinted, never any other character. Each panel picks a different pose and a small random tilt.
2. **Alternative, only if the cards look flat:** a live clone of the caster's avatar placed just behind a panel, strictly limited to the panels nearest the camera (say at most six) and measured. Do not use a `ViewportFrame` per panel.
3. **Glare.** Two or three flat, hard-edged white diagonal streaks per panel, the same angle on every panel, as in the reference. No gradients, no soft glow. When a bolt fires, the glare on that panel flashes once, and the reflection snaps to the cast pose.
4. **Cast sync.** On the volley, every reflection takes the cast pose with a short stagger (0.05 to 0.10 s between panels), so the copies "throw" with the real caster. The beat is the existing Mirror Cage lead-in.
5. Respect **Reduce Flashing** for the glare flash. Respect Graphics Quality by dropping reflections on the far panels first.
6. The art is an uploaded asset, so it is fragile: keep the source files, record every asset id where the code reads it, and verify it by rendering it on screen (`IsLoaded` and `PreloadAsync` can report success for art that never draws). Cryo's palette stays the shipped palette; no magenta.

**Checkpoint.** A silhouette-first pass: the pose cards alone, on a flat panel, at the size they render on screen (about 15 studs away). Approval, then the glare and the sync.

## Polish ideas (PROPOSALS ONLY: describe them, do not build them until the user says yes)

1. A short crack-and-shiver on frozen targets during the last second of the freeze, as a warning that the shatter is coming (Flash Freeze already shatters if still frozen when it ends).
2. A frost vignette on the edges of a frozen **player's** screen, routed through the existing overlay and status art, and subject to Reduce Flashing and Status Intensity.
3. A ragged frosted white border and icicle drips on the Mirror Cage panels, like the reference frame.

## Animation

No new motion clips in this pass. If a fix needs one, flag it. Any future clip needs both a `Viewmodel` clip and a `CastPose` clip on the same `Trigger = VFXLibrary.Tuning.<Ability>.LeadIn` beat.

## Scope reminder

Not in this pass: the rest of the Cryo kit, Flash Freeze's shape, Deep Freeze's trigger, the Icicle Shard throw animation, cosmetic tiers, any other Element, and anything on the ❓ open-questions list (Aqua above all). Do not edit the design manual.

Flag anything ambiguous instead of deciding it, and add nothing that was not asked for. Report at the end: what changed per fix, the numbers you used for the Chill 3 slow, the particle budget for Blizzard, and which Mirror Cage reflection approach you picked.
