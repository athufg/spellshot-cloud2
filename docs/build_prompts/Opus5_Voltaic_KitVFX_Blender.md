# SPELLSHOT — Build Prompt: Voltaic Kit — Full VFX Set in Blender (M1, Primary, Passive, Ultimate, Native Techniques)

**Standalone, self-contained prompt.** This is Blender/VFX asset work only — shapes, meshes, particle looks, and their
in-engine integration. **No animation** (Viewmodel/CastPose clips are a separate, later prompt — build the assets
first, same order every other kit in this project has followed). **No mechanic changes** — the kit described below
is locked from a recent design session; build to it exactly, don't reinterpret it.

## Read this before anything else: Voltaic's kit was just redesigned, and the manual on disk is stale for it

The current `spellshot manual.pdf` (v0.7) still shows Voltaic's old Passive ("bonus damage vs. stationary targets"
only) and its old Ultimate (Thunderclap, an instant burst) — those are superseded. The locked kit below came out of
a separate design conversation and hasn't been written back into the manual file yet. **Treat this document as the
authority for Voltaic specifically, overriding what's on disk**, and don't "correct" anything below to match the
PDF. Every other Element's manual entry is still accurate; this override is Voltaic-only.

## The locked kit — build VFX to this, six pieces total

1. **Chain Bolt (M1).** Instant hitscan, very short range, auto-chains to a second nearby enemy.
2. **Overcharge (Primary Ability).** Instant short dash forward; the caster's next M1 chains to 2 extra targets
   instead of 1 (a self-empower window, not a new attack).
3. **Chain Reaction (Passive).** Landing a kill refunds a chunk of Overcharge's cooldown.
4. **Cascade (Ultimate).** Marks a ground point; dark storm clouds gather above it, then a rapid sequence of
   individual lightning strikes comes down out of the clouds onto anyone still standing near that point, over
   roughly a second.
5. **Railspike (native Technique).** A charged, longer-range piercing bolt that punches through everyone standing
   in a line — Voltaic's answer to its short-range M1, with a real windup instead of Chain Bolt's instant fire.
6. **Ground Surge (native Technique).** Thrown or placed; sits for a moment, then erupts, zapping anyone standing
   in the zone when it pops. Rewards catching a target that hasn't moved.

Exact numbers (range, damage, delay durations, cooldowns) were not finalized in the design discussion this kit came
from — only the shapes and behavior were locked. Propose reasonable placeholder numbers where the VFX timing needs
one (e.g., how long the Cascade clouds take to gather, how long Ground Surge sits before erupting), sanity-checked
against Voltaic's own fixed kit and Cryo's built abilities as the closest reference points, and report every number
you propose rather than inventing silently.

## Palette and the two collision risks to actively design around

Voltaic's shipped colors: Base `#F5C70F`, Light `#FFF573`, Dark `#4A1A8C`. That Dark tone is a real violet-purple,
not a shadow-brown — treat it as a genuine secondary color for this kit, not just a shading band, since it's the
main tool for solving the two risks below.

- **Voltaic and Radiant are both yellow** (`#F5C70F` vs. `#F5C230`, nearly identical) — shape has to separate them,
  color can't.
- **Voltaic's Base is almost exactly the game's "Ultimate ready" UI gold** (`#F5B800`) — a sloppy Voltaic effect
  risks reading as generic "ultimate is up" glow rather than a distinct Element identity.
- Voltaic does **not** change color under the Colourblind-Safe toggle (it's one of only two Elements that stay the
  same in both palettes), so there's no color-swap safety net here either. Shape and silhouette have to carry
  Voltaic's identity on their own, every time.

Shape direction to build to: forked zigzags, hard angles, short and sudden — nothing rounded or soft. Lean on the
purple Dark tone as a real secondary read (not just shadow) specifically because it's what separates Voltaic from
Radiant's warm cream-and-gold ray motif and from the neutral gold UI glow.

## Voltaic is likely status-free by design — confirm before adding one

Nothing in Voltaic's kit (old or new) applies a persistent status the way Icicle Shard stacks Chill or Corrosive
Cloud applies a DoT — every piece of this kit is instant or burst damage, consistent with its "pure right-now
damage" identity. The game does have a "Shocked" status shape already built, but don't assume it's meant for
Voltaic. If you find real evidence Voltaic is supposed to apply a status, flag it and describe what you found rather
than silently wiring one in.

## Reference before styling — source these first

Nothing in the shipped shape vocabulary is a storm cloud, so Cascade especially needs a real reference before any
Blender work starts: a comic-panel storm cloud (flat-shaded, jagged scalloped silhouette, the classic thunderhead
comic shape) — not a realistic or painterly cloud reference. For the zigzag-bolt pieces (Chain Bolt, Overcharge,
Railspike, Ground Surge's eruption), the already-shipped Voltaic Element logo (`element_logos_preview.png`, an
angular lightning bolt) is the closest in-project anchor — build outward from that shape family rather than
inventing a new one. If no cloud reference exists yet, say so explicitly and name where one could come from before
proceeding.

## Per-piece design direction

**Chain Bolt (M1).** Hitscan, not a physical projectile — render as an instant forked zigzag line/tracer that
flashes and is gone, not a flying mesh. On the chain-to-second-target beat, a distinct second flash jumping from
target one to target two, so the chain reads as two connected hits, not one wide effect. Match the rendered bolt's
visible width to its actual hit-test width, per the combat rule that a shot is tested as wide as it's drawn. Impact:
an angular spark burst in Voltaic's colors — check whether a Voltaic comic burst asset already exists in
`PopArtAssets`; if not, this kit needs one made (the established pattern is one comic burst per Element, in that
Element's colors, following the same process the existing Cryo one used).

**Overcharge (Primary).** Two reads needed: the dash itself, and the post-dash "primed" state. The dash should be a
Voltaic-colored streak/afterimage — don't reuse the generic white Haste sweep verbatim, since that's a shared
cross-Element status treatment and this is Voltaic-specific. After the dash, the empowered-next-M1 state needs its
own visible tell (hands/weapon crackling with extra charge) since it's otherwise invisible until the player fires
and gets a surprise result.

**Chain Reaction (Passive).** This is a HUD-facing payoff, not a worldspace effect — there's no projectile or burst
here. Check whether this can be built entirely by reusing the existing "Ready" one-shot pulse (the ability-slot
flash used when a Technique becomes available early) rather than building new Blender assets for it at all — ask
whether Blender is even the right tool before defaulting to it, per the project's own rule on this. If the existing
Ready-slot treatment covers it, this piece may need no new geometry, just a hookup.

**Cascade (Ultimate).** Build as a real toon mesh, not a particle puff — same family as Terra's Bedrock plates or
Earthen Tomb's structure. A flat-shaded, ink-outlined cloud with a jagged scalloped bottom edge, filled in Dark
`#4A1A8C` with a Ben-Day halftone patch on its underside for texture rather than any gradient. The cloud gathering
into place above the marked point over a beat is the telegraph itself — no separate ground marker needed. Then
individual forked bolts (Base `#F5C70F` core, Light `#FFF573` hot edge) strike down out of the cloud at each hit in
the sequence, jagged and instant per strike even though the cloud's formation is comparatively slow — that contrast
(slow ominous gather, fast violent release) should read clearly. This is Voltaic's one hero-scale moment — size the
cloud meaningfully larger than a character, matching how every other kit renders its signature Ultimate beat.

**Railspike (Technique).** Needs a visible windup — a charging glow building before it fires — since it's explicitly
the long-range commitment option next to Chain Bolt's instant fire. The bolt itself should read as a thicker,
more sustained "rail" than Chain Bolt's short snap: straight, with crackling forked edges rather than a clean line.

**Ground Surge (Technique).** Structurally close to Cryo's Flash Freeze (a placed ground-zone effect with a delay
before it triggers) — reuse that engine pattern for the warning-telegraph-then-eruption pacing rather than
inventing a new one. A compact node/marker on the ground during the delay, then an upward zigzag eruption filling
the zone when it pops.

## Integration — hook these existing systems, rebuild none of them

- Chain Bolt and Railspike are both hitscan: use the same client-reported, server-validated hit pattern the rest of
  the game's M1s use — impact VFX plays at the shooter's own reported hit moment, not after a round-trip.
- Ground Surge: follow Flash Freeze's ground-zone broadcast/timing pattern as the closest built precedent.
- Chain Reaction: check the "Ready" one-shot pulse before building anything new for it.
- Every emitter goes through `VFXLibrary`'s `emitter()` helper (Graphics Quality density, Reduce Enemy VFX).
  Flashes respect Reduce Flashing; camera punches respect the Camera Shake setting.
- **Both Techniques (Railspike, Ground Surge) are origin-colored, not caster-colored** — whichever Element's player
  equips them, they render in Voltaic's palette, never the caster's. There's a future Technique-reskin system (not
  built) that will want to retint a borrowed Technique into the caster's palette; baked vertex colors make that
  hard. Don't solve it now — just note in your report how each mesh's palette could be swapped later, so the future
  work has something to start from.
- No new payoff lettering beyond what the existing `Callouts` system already supports — check its style list before
  proposing new words for Cascade's kill moment.

## Engine constraints — same rules as every other kit in this game

Opaque meshes only (no transparency — fades happen via sinking/shrinking, or `VFXLibrary.RegisterProximityFade` for
the caster's own close-range VFX). `MeshPart.Color` stays white, `Material` stays `SmoothPlastic`, `DoubleSided =
false`. Color comes from baked 3-step vertex-color tone bands, not material tint. The ink outline is a real
inverted-hull mesh — there is no outline shader. Particles need a hard-edged main silhouette (the custom angular
`Shard` sprite is the established debris precedent); soft built-in sprites are fine only as brief, small support
underneath, never as the primary read — this matters most for Cascade's cloud, which must be built as real geometry
and not attempted as a soft particle cloud.

## Build order and checkpoints

Six genuinely separate pieces — treat them that way, not as one blended pass. For each: **silhouette/shape pass
first, checkpointed and reviewed (including at actual on-screen size) before any tone band, outline detail, or
color goes on** — this is a hard rule on this project after multiple redesigns got confused by skipping straight to
a colored final. Cascade's cloud especially needs this, since it's a shape nothing else in the game has attempted.

## Delegate to subagents — six independent assets, genuinely parallel work

These six pieces don't share geometry or depend on each other, which makes this a good fit for splitting across
subagents rather than working through them serially — for example, one agent per piece, or grouped as (Chain Bolt +
Overcharge + Chain Reaction) / (Railspike + Ground Surge) / (Cascade alone, since it's the one novel shape and
the largest single piece of work). Keep each subagent's scope to files/assets the others aren't touching. Have each
one checkpoint its own silhouette before color, report back in the same format, and consolidate into one final
report yourself rather than handing back six disconnected pieces.

## Go in with real effort, especially on Cascade

Five of these six pieces build on shapes and patterns this project already has plenty of precedent for. Cascade's
storm cloud does not — it's a genuinely new shape family for this game, and it's also the piece doing the most work
to solve the Voltaic/Radiant and Voltaic/Ultimate-gold collision risks. Don't shortcut that one to keep pace with
the other five. Don't generate multiple variants of any single piece for comparison, and don't launch a separate
verification round beyond the silhouette checkpoints already specified.

## Scope reminder

Blender assets, their shapes, palettes, and in-engine VFX/particle integration for the six pieces above, plus a new
Voltaic comic burst asset if one doesn't already exist. **Not in scope:** any Viewmodel/CastPose animation clips
(separate, later prompt), any mechanic or number changes to the locked kit above, the other seven Elements, any
Technique reskin implementation (note only, per above), and cosmetic skin tiers. Flag anything ambiguous — including
every proposed timing/number — rather than deciding it silently, and add nothing that wasn't asked for here.

---

Say one sentence before your first tool call, and name your subagent split before spawning them. Give a brief
update at each piece's silhouette checkpoint, not a line-by-line narration. When done, lead your report with all six
assets rendered together at actual on-screen scale, then list: whether a Voltaic comic burst asset already existed
or was newly made, every number/timing you proposed and why, how Chain Reaction was actually built (new geometry or
a Ready-slot reuse), and your reskin-palette notes for Railspike and Ground Surge.
