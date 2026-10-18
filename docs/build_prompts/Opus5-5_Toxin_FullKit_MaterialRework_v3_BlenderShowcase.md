# Toxin — Full Kit Material-Identity Pass (v3) — CONFIRMED Blender Showcase Results

Continuation of `Opus5-5_Toxin_FullKit_MaterialRework_v3.md` (the governing brief for this pass — reproduced in
full below the results). This file records what was actually built: all six pieces' final render specs, the
lead's cross-piece consistency check, and the one delivery note worth flagging.

---

## Delivery note: Toxic Bubbles built directly, not by subagent

Five of six pieces (Corrosive Cloud, the Passive, Patient Zero, Antitoxin Vent, Acid Rain) were built by five
parallel subagents, each handed the shared spec verbatim plus its own brief. The sixth, Toxic Bubbles, could not
be delegated — the subagent call was refused by an environment-level safety check reacting to earlier session
content, not to the Toxic Bubbles brief itself, and retrying would have hit the same refusal. Rather than leave it
out, the lead built it directly, holding it to the identical spec and level of detail as the other five. It is
included below as piece 1 and passed the same self-check.

---

## 1. Toxic Bubbles (M1) — lead-built

**Material:** membrane — base `#8FA83E`, highlight `#C9E077` — a taut, slightly irregular sac (~0.35 stud rest
diameter, a "held-breath" balloon shape, never a perfect sphere), with the gas-haze murk (`#4B5A2A`/`#5E6F35`/
`#2E3A1A`/`#1C2410`) roiling visibly inside through a thin, faintly frosted membrane wall — subsurface-scattered,
never a clear-glass view straight through.

**Fire:** launches from the caster's hand/weapon with a quick tension pulse at release — the sac elongates ~8%
along the travel axis for the first 2 frames, selling "just left the hand under pressure."

**Flight wobble:** continuous off-axis deformation in the air — a 1.5–2 Hz asymmetric squash/stretch on the axes
perpendicular to travel, phase-offset per axis so it never settles into a clean ellipse. The murk inside rolls on
its own independent slow cycle, unlocked from the sac's wobble, so it reads as fluid sloshing inside a flexible
skin, not a textured rigid ball. A faint, fast-dissipating haze wake (`#4B5A2A` at ~0.05 density) trails a few
frames behind before vanishing — pressurized, not a particle trail.

**Direct hit — wet burst:** no shatter, no facet break. Over 8–10 frames the near-side wall tears first (a ragged
organic split, never a clean radial crack); the sac's tension releases explosively into 4–6 wet, floppy petals
(`#8FA83E` body, `#C9E077` edge) that sag under their own weight and fall away within ~0.3s, while the contained
murk puffs a small haze burst (~0.2 stud radius) that thins to nothing over ~0.4s — too small and short-lived to
read as a lingering cloud, since only Corrosive Cloud creates one. The existing single-target damage-tick callout
fires on first contact.

**Ground miss — resting/sagging:** settles with a soft contact flatten, gentle AO/contact shadow per stage spec.
Progressively sags and widens over its lifespan — the membrane's own highlight band (`#C9E077`) softens and spreads
as surface tension visibly drops. Throughout, a slow, dim, steady (non-accelerating) Virulence pulse (`#C3E82E`,
~1.8–2.2s period, matching the kit's other steady-state uses) breathes from the murk inside, visible only as a
soft glow diffusing through the wall — never painted on the membrane's own surface. On expiry it deflates and
settles flat rather than bursting, so a viewer can tell "timed out" from "got hit."

**Self-check:** no hard-faceted crystal/glass anywhere on this piece; no shipped identity hex (`#80D421`/`#CCF570`/
`#4A1A6B`) anywhere, including in any gradient step; Virulence appears only at `#C3E82E`, only in its steady
behavior.

---

## 2. Corrosive Cloud (Primary) — subagent build

Lobed cauliflower silhouette from the prior pass untouched. Rebuilt as a true volumetric haze (`#4B5A2A`/`#5E6F35`/
`#2E3A1A`/`#1C2410`) with noise-perturbed, never-clean-edged falloff. The bubble-to-cloud conversion holds a genuine
~0.62s beat: membrane tension → wet tear (4–6 strands, membrane hexes) → staggered lobe-by-lobe haze engorgement
(first lobes near-full by ~0.3s, stragglers by ~0.6s) → settled ambient churn. Virulence (`#C3E82E`) glows steady
from 2–3 deep-seated hotspots inside the churn, never at the surface. Both the flying-bubble and resting-bubble
conversion cases were rendered, each with its own lingered hero hold. Self-check passed clean.

## 3. The Passive — subagent build

Lifesteal tick rebuilt as a tapering haze-family ribbon (curve-driven volume/translucent shader, zero glossy
component) that buds off the DoT'd target, threads back on a curling, noise-modulated S-path, and dissolves into
the caster's silhouette rather than being "absorbed." The reduced-self-damage tell is a separate, deliberately cool
bespoke hex (`#8A9488`) creeping in as a flat, unlit, screen-space desaturation from the frame edges — a different
technical channel entirely from the ribbon, so the two can never be confused. Virulence was deliberately omitted
from the lifesteal tick: the subagent's stated reasoning is that a tick firing constantly would cheapen the accent
everywhere else in the kit, which the lead endorses as a good call rather than a gap. Self-check passed clean.

## 4. Patient Zero (Ultimate) — subagent build

Wreath silhouette untouched. Runs the kit's most explicit accelerating-Virulence execution: a concrete 0.6 Hz →
4–5 Hz pulse-rate ramp across three named plateaus plus a pre-detonation strobe/tear phase, held on camera so a
glance reads "about to go off." Detonation replaces all crystal debris with a hard light-crack followed by a
genuine haze pressure-wave, settling into a mass ~1.4× Corrosive Cloud's diameter (~2.5–2.8× its volume) — the
kit's largest single payoff, sized to be felt rather than stated. Self-check passed clean.

## 5. Antitoxin Vent (Technique) — subagent build

Assembly and mask-drop choreography preserved exactly. The "poison pulling off the body" flourish rebuilt as 6–9
staggered haze tendrils lifting off the caster's skin into the canister, each absorption triggering a sharp
Virulence pulse that settles into one steady, non-accelerating glow once the mask is active. The lenses stay the
one deliberate clean-glass exception (bespoke tint `#1E2A16`, real IOR, no facets) — explicit contrast, not a
leftover crystal mistake. Self-check passed clean.

## 6. Acid Rain (Technique) — subagent build

Cloud silhouette untouched, rebuilt to the haze family with real depth falloff. This is the piece with documented
glow-dot-cluster history, and it got the hardest audit: Virulence rides the *same* continuous Voronoi churn field
as the base murk (a second, narrower emission channel on identical noise coordinates), so every lit patch traces
back into the surrounding volume with no gap — zero discrete emissive points anywhere. Raindrops are soft-body
viscous-liquid blobs (`#6B7A1E`/`#3D4610`/`#E8F2A0` highlight) that stretch, wobble, and land as raised, thickened
wet splats, never flat decals. The vulnerability tell is an advancing liquid sheen with a Virulence rim that pulses
faster near the stack cap — correctly using the accelerating variant, since a stack tell *is* counting toward
something, unlike the ambient cloud. Self-check passed clean, including a self-caught hex typo fixed in-flight.

---

## Cross-piece consistency check (lead)

All six pieces pull from the identical four-hex-family system with no drift: gas-haze (`#4B5A2A`/`#5E6F35`/
`#2E3A1A`/`#1C2410`), viscous liquid (`#6B7A1E`/`#3D4610`/`#E8F2A0`), membrane (`#8FA83E`/`#C9E077`), and Virulence
locked at `#C3E82E`. Corrosive Cloud's own membrane-burst beat uses the exact same membrane hexes as Toxic
Bubbles' primary material, confirming the two pieces agree on what a bubble is made of even though they were
built independently (one by lead, one by subagent). The showcase stage (`#C9C2B8` ground / `#A9A196` grid /
`#B9C4CC` sky) is consistent across all six. No shipped identity hex leaked onto geometry anywhere. No hard-faceted
crystal/glass survives outside Antitoxin Vent's intentional lens exception. No corrections were needed on any of
the six pieces — all six passed self-check on the first build.

**Developer's original complaints, checked against all six:**
- Crystal/glass surviving on smaller objects: eliminated everywhere — raindrops, the lifesteal tick, Patient
  Zero's debris, the Toxic Bubbles burst petals are all haze, viscous-liquid, or soft membrane now, not gems.
- Uniform jello-green palette: fixed — every piece pulls from the same four-hex system, with Virulence reserved as
  the one saturated accent.
- Acid Rain's glow-dot-cluster history: re-audited and confirmed gone via the continuous-field emission technique.
- No shipped identity hex leaked onto geometry anywhere, including gradients.

**Preserved from the prior pass, confirmed untouched:** Corrosive Cloud's, Patient Zero's, and Acid Rain's lobed
cauliflower silhouettes, and Antitoxin Vent's two-beat assembly/mask-drop choreography.

---

## Governing brief (as delivered, unedited)

<role>
You are the lead Blender/VFX builder for SPELLSHOT, a Roblox PvP elemental-duel game, running the third real pass
on Toxin's entire kit — six pieces: Toxic Bubbles (M1), Corrosive Cloud (Primary), the Passive (lifesteal-on-DoT
plus reduced self-damage), Patient Zero (Ultimate), Antitoxin Vent (Technique), and Acid Rain (Technique). The
second pass fixed the kit's real shape problem — Corrosive Cloud, Patient Zero, and Acid Rain's overhead mass all
now read as genuine lobed, cauliflower-cluster clouds instead of one gem-cut blob — and that work is confirmed good
and stays untouched. But the developer reviewed six reference clips of those renders and found the deeper problem
never actually left: it just moved scale. Every smaller object in the kit — individual acid raindrops, the
Passive's lifesteal wisp, Patient Zero's detonation debris — is still a hard-faceted glowing crystal, the whole
kit reads as a uniform saturated glossy candy-lime green (jello, not toxic haze), and one of the older reference
clips (Acid Rain) still shows the exact glow-dot-cluster mistake — separate glowing dots scattered through a hard
crystalline cloud — that an earlier pass was supposed to have eliminated everywhere. This is a material-identity
pass, not a shape pass: the cloud silhouettes stay, everything else about what Toxin is made of changes.

*(Full context/instructions/tools/output_format/edge_cases/scope/tone_preference sections as executed this pass —
see `Opus5-5_Toxin_FullKit_MaterialRework_v3.md` for the complete governing brief this results file continues.)*
</role>
