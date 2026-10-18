# Pyro — Developer Correction Pass (from pyro1-4.mp4 review) — CONFIRMED Blender Showcase Results

Continuation of `Opus5-5_Pyro_FullKit_BlenderShowcase.md` and `Opus5-5_Pyro_FullKit_FirestormVortex_Finalize.md`.
The developer reviewed real rendered clips of that build (pyro1.mp4 = Fireball, pyro2.mp4 = the old "Immolate"
count-based buff, pyro3.mp4 = Ember Refund, pyro4.mp4 = Firestorm Vortex) and gave direct correction feedback.
Confirmed with the developer: **Primary** and **Immolate** are now two separate abilities — Primary keeps the
"press it, next 3 M1s hit harder" mechanic (previously mislabeled Immolate), and Immolate becomes a brand-new
mark-and-detonate ability with a fire crown on the enemy. Five pieces were rebuilt in parallel; Ember Refund
(Passive) was not touched — it wasn't part of the feedback.

---

## 1. Fireball (M1) — reworked

Cast now visibly ignites at the caster's hand (a ~0.2s windup: knuckle fissures snap lit, then 4-6 charcoal shell
fragments snap together into the ball in the palm — nothing appears pre-formed mid-air). Thrown on a **tightened,
faster-reading lob** rather than the old high floaty arc: apex cut from ~4-5 studs to ~1.0-1.3 studs (a ~70%
reduction), total flight time cut from ~1.1-1.3s to ~0.35-0.45s (a ~65% reduction) — it still technically arcs
(so "must be led" isn't silently deleted) but throws almost like a fastball with shallow loft. Impact is a hard,
sudden fracture-splash (debris with real gravity/bounce), not a soft "embers settle."

**Open question for you:** the subagent built this as a tighter lob, not a fully flat/arc-free throw, reasoning
that the manual ties Fireball's "must be led" identity to having *some* arc. If "throw it straight like js old"
meant genuinely flat/hitscan-style, say so and I'll flatten the trajectory further — but flagging that doing so
would mean dropping "must be led" as this M1's identity, since a flat throw is trivially led.

## 2. Primary (the buff — was mislabeled "Immolate," mechanic unchanged) — polished

The three-chip vambrace cast and crack-and-consume read stays exactly as built. New: a clear, measured gap between
a normal and an empowered M1, both in flight and on impact —

| | Normal M1 | Empowered M1 |
|---|---|---|
| Fracture radius | 0.35m | 0.85m (2.4x) |
| Debris chunks | 7 | 20 (~2.9x) |
| Flare diameter | 0.40m | 0.90m (2.25x) |
| Secondary flare-up + ember ring | none | yes (new) |
| Total impact event | 0.15s | ~0.65s (~4.3x) |
| In-flight tell | 3 static fissures | 5 pulsing fissures + pale-cream hot-core lines (`#FFE9CC`, bespoke) + ember trail |

A buffed throw is now readable as buffed *before* it lands, not just at impact.

## 3. Immolate (NEW — mark, detonate, fire crown on the enemy)

Built from scratch, three beats: a quick snap-throw embeds a small faceted knot at the base of the target's nape;
over ~1.8s it visibly telegraphs (Stoke brightens on a smooth ramp, hairline cracks spread across the target's
neck/shoulders); it detonates into a **crown of 8 chunky flame-chunk spikes** rooted in a band at brow-to-ear
height around the target's head — held for ~0.5s (the reel's hero shot, slowed to 25%) before breaking apart into
scattering embers. The caster's own body never glows or changes — this is entirely about the target, which is
what separates it from Primary.

**Assumptions to confirm:** detonation fires automatically ~1.8s after the mark lands (not a second button press);
the mark sits at the nape, not the shoulder or chest. Both are easy to change if you had something else in mind.

## 4. Scorching Lash (NEW build)

Hold: a loose cloud of ember motes gathers and snaps together into a 16-link jointed charcoal whip in ~0.8s, then
Stoke brightens on a smooth charge ramp (plateauing at full brightness at ~1.8s held — flagged as an assumption on
how long a full charge takes) with idle coil, heat-shimmer, and sparking that concentrates toward the tip as it
charges. Release: real whip-crack physics — a bend travels from grip to tip, accelerating as it goes, snapping
through a 120° horizontal arc and leaving a dotted trail of cooling embers along the swept path so the strike's
line is legible even in a fast cut. The crack itself (full extension) is the piece's slow-motion hero beat.

## 5. Firestorm Vortex — redesigned so it does not read as Ring of Fire

This was the priority fix. The old build (two concentric expanding rings) is gone entirely. New: Firestorm Vortex
ignites as a **tall, narrow, spinning fire tornado at the caster** (reaching ~10-12m height almost instantly),
then **travels forward** along your aim for ~13.5m, tearing a straight scorched trail into the ground as it goes —
base tight and controlled (1.2m radius), crown wide and chaotic (~4.5m across), corkscrewing the whole way. At max
range it collapses into itself and erupts in one massive radial burst (6-7m radius — bigger than Fireball's impact
and bigger than Primary's empowered hits), then settles, leaving the scorched trail visible as the last thing on
screen. Checked explicitly from directly overhead: the silhouette is a comet/lance shape — a line with a churn at
the tip — with open ground on every side and no enclosed ring anywhere, at any point in the sequence.

---

## Cross-piece consistency check (lead)

All five stay inside the locked Pyro material system — charcoal body (`#2E1D14`/`#3C2A1E`/`#241611`/`#17100B`) and
Stoke (`#FF9933`, used only in its established COUNT/STEADY/INTENSITY behaviors, no new named behavior invented
anywhere, including Firestorm Vortex's spin, which stays a geometry property). No shipped identity hex
(`#F25C0D`/`#FFC74D`/`#6B1708`) leaked onto any geometry in any of the five, including gradients — every subagent
self-checked this explicitly, since it's the exact mistake this kit already caught once. Bespoke non-identity hexes
introduced by different subagents don't collide: Primary's hot-core cream (`#FFE9CC`) and Firestorm Vortex's scorch/
smoke/ember set (`#1B120C`/`#5A554E`/`#FFB25C`) are each unique to their own piece. All five stage on the same
neutral floor/grid/sky (`#C9C2B8`/`#A9A196`/`#B9C4CC`). No corrections were needed on any of the five builds.

**Every specific complaint checked:**
- "I don't want it to change abilities" — Fireball keeps its lob identity (tightened, not removed, pending your
  answer above); Primary keeps its exact cast/consume mechanic; nothing's silhouette or material family changed.
- Fireball cast-from-hands + straighter throw — done, with the arc-vs-flat interpretation flagged above.
- Primary's empowered hits now visibly bigger than normal M1 — done, with real multipliers.
- Immolate decoupled from Primary, now a mark+detonate with a fire crown on the enemy — done, built fresh.
- Scorching Lash built — done, hold-to-charge whip, release to strike horizontally.
- Firestorm Vortex no longer reads as Ring of Fire — done; confirmed via an explicit top-down check that it's a
  moving trail-and-crown, never a closed ring.
