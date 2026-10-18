# SPELLSHOT — Build Prompt: Voltaic Ultimate — Cascade Corrective Pass #4

**Standalone, self-contained prompt.** Fourth pass on Cascade. Everything in pass #3
(`Opus5_Voltaic_Cascade_Corrective_v3.md`) still applies — this document adds one more confirmed decision and
one new dimension (animation energy/impact) on top of it. Read pass #3 in full; this is additive, not a
replacement.

## Confirmed from pass #3: lightning stays yellow

Pass #3 flagged a design call rather than deciding it silently: keep the cloud's mood dark and purple-toned like
the mood reference, but keep the lightning itself in Voltaic's actual yellow rather than switching to the
reference's purple-white, so Cascade stays consistent with Chain Bolt, Railspike, Overcharge, and Ground Surge.
**This is now confirmed — build the lightning in Base `#F5C70F` / Light `#FFF573`, full stop, not purple-white.**
The cloud body itself still follows the near-black/purple-glow treatment from pass #3.

## New: animation energy and impact

A third reference now exists: `cascade_animation_energy_reference.png` (saved in the project folder), a captured
frame from another game's lightning ultimate. This is **not** a style reference — that game's VFX is bright,
glowing, bloom-heavy anime style, which is not this game's visual language and should not be copied directly.
It's an **energy and staging** reference: use it to judge how much visual weight and screen presence a hero-scale
lightning Ultimate should have, then translate that weight into SPELLSHOT's flat comic-toon rules. Specifically,
three things from it that Cascade is currently missing:

1. **The release radiates, it doesn't just strike downward.** In the reference, the payoff moment fills the
   screen with bolts radiating outward from the impact point in multiple directions, not just a few lines hitting
   the ground. Cascade's strike sequence (the 4–5 bolts from pass #3) should keep landing on the ground as
   already specified, but add one additional flourish at the exact trigger instant: a burst of shorter forked
   energy lines radiating outward from the cloud itself in multiple directions (up, sideways, not just down) —
   built as flat angular burst shapes in the same Base/Light yellow, existing for a few frames only. This is a
   climax flourish separate from the ground-hitting bolts, not a replacement for them.
2. **The charge-up should show visible circling energy, not just static crackle.** The reference orbits glowing
   charge elements around the caster while building up. Translate that (not copy it) into Cascade's charged-hold
   beat: in addition to the mini-arcs already specified in pass #3, add a small number of bright yellow spark
   motes that circle or orbit around the assembled cloud during the hold, tightening or speeding up as the hold
   approaches the strike. Build these as simple hard-edged particles through the existing `emitter()` helper —
   this is a particle detail, not new geometry.
3. **The release needs to hit the screen, not just the ground.** The reference pairs its strike with a camera
   reaction and a full white flash. Cascade can't use bloom or a screen-wide flash (that fights Reduce Flashing
   and the flat-shading rule), but it can and should pair the strike with the camera shake pass #3 already asks
   for, made a little more pronounced specifically on the first bolt of the sequence — that's the frame that
   should feel like the hit landed on the *player's* screen, not just on the target.

None of this changes the mechanic, the bolt count, the timing beats, or the cloud's color treatment from pass
#3 — it's additional polish on top of an already-specified sequence.

## Reminder: the translation rule still applies

Every mesh is opaque `SmoothPlastic` with flat baked 3-tone vertex-color bands, `DoubleSided = false`, and a real
inverted-hull outline. No material tint, no transparency, no bloom, no gradient. The new radiating burst and the
orbiting motes both need to be built as flat, hard-edged shapes/particles like everything else in this kit — the
"energy" being translated from the reference is about staging, timing, and visual weight, not literal rendering
technique.

## Scope reminder

This pass adds: the confirmed yellow-lightning decision (no longer flagged, just build it), the radiating burst
flourish at the strike trigger, orbiting charge motes during the hold, and a stronger camera punch on the first
strike bolt specifically. **Everything else stays exactly as specified in pass #3** — cloud color and depth
layering, halftone, strike spread/stagger, the base camera shake, the assembly motion, and the dissolve. Not in
scope: the other five Voltaic pieces, any mechanic or number change beyond what pass #3 and this pass explicitly
ask for, and any new status effect.

Flag anything ambiguous rather than deciding it silently, and add nothing that wasn't asked for here.

---

Say one sentence before your first tool call. When done, lead your report with the cloud at its release moment
(radiating burst + ground strikes together) rendered at actual on-screen scale, confirm the lightning is yellow
throughout, and describe how the orbiting charge motes read during the hold.
