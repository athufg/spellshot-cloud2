# Build prompt — Toxin Mythic wrap: pH Indicator

Target: `roblox/SkinCatalog.lua`, `roblox/ToxinWrap.lua`, `roblox/ToxinTuning.lua`, `roblox/ToxinFX.lua` (SPELLSHOT, Roblox)

<role>
You are building a cosmetic wrap for SPELLSHOT, a Roblox ranked-duel game, working directly in the owner's **live
Roblox Studio place** through Studio's own MCP connection (Assistant → ... → Manage MCP Servers → "Enable Studio as
MCP server" must be on; if it isn't, stop and ask the owner to turn it on rather than editing files blind). This is
Studio work, not a text edit against the project's GitHub snapshot repo (`spellshot-cloud`) — that snapshot is a
read-only export for a different, cloud-only audit task and has nothing to do with this build. You push real changes
into the Edit-mode place, build and verify them there (EditableMesh builds, particle counts, Play-testing where it
matters), and take your checkpoint screenshots from Studio itself. You work for the game's solo developer, who
reviews every checkpoint before anything ships. Your job is to take the Toxin element's gas/poison VFX through a
Mythic-tier colour-and-material wrap called **pH Indicator**, build it to a reviewable checkpoint, and stop. You are
not done when the code compiles — you are done when a checkpoint sheet exists, built and captured in Studio, that the
owner can approve or send back. Do not wire the wrap into the game (the catalog's selectable list, any menu) until
that approval happens; building it and shipping it are two different steps, and only the owner clears the second one.
</role>

<context>
**The game and the element.** SPELLSHOT is a Roblox elemental PvP duel game (RIVALS-style ranked match structure,
elemental kits instead of guns). Toxin is one of nine Elements: a Control/Zone poison-gas kit built around a
bubble-into-cloud loop. Its fixed kit (read `SkinCatalog.Offer`/`ToxinTuning.lua` to confirm, don't take this as
exhaustive): M1 **Toxic Bubbles** (fires a bubble that pops into a poison tick on a direct hit), Primary **Corrosive
Cloud** (pressing Primary while a bubble is in flight converts it into a lingering toxic cloud instead), Passive
**Symbiosis** (your own poison DoT heals you back), Ultimate **Patient Zero** (marks a target with a growing,
telegraphed aura that detonates into a cloud, worse the more allies are nearby). Toxin's visual baseline is murky,
desaturated swamp-olive gas and liquid (`ToxinTuning.T.Color`: gas family around `#4B5A2A`/`#5E6F35`/`#2E3A1A`/
`#1C2410`, liquid `#6B7A1E`/`#3D4610`, membrane `#8FA83E`/`#C9E077`), rendered in the game's muted, physically-grounded
style — real lighting response, no self-lit glow anywhere except the one deliberate accent. That accent is
**Virulence**, a signature colour-family variant that reads by *time*: it glows brighter and pulses faster the closer
something is to detonating or expiring, paying off hardest on Patient Zero's mark. Toxin's three shipped identity
colours — Base `#80D421`, Light `#CCF570`, Dark `#4A1A6B` — are HUD/uniform-only; `ToxinFX.lua` refuses to draw any
3D colour within 12/255 of them on every channel, and this wrap has to clear that guard too
(`.claude/skills/spellshot-wrap-tiers/scripts/guard_check.py`).

**Wrap vs skin — a hard boundary, not a style choice.** A wrap only recolours and re-materials Default's existing
shapes; it never adds new geometry, never changes a kill effect, HUD icon set, or avatar body/aura — those are skin
features, ruled out for a wrap by the project's own tier contract. This matters concretely for pH Indicator: no new
3D objects, no kill effect on detonation, no HUD reskin, and critically, **no live or dynamic on-screen readout** —
anything that updates in real time needs a GUI/TextLabel object, which Default doesn't have and a wrap can't add. A
**static, baked-in texture detail** that merely looks like printed chart markings (the way real pH indicator paper
ships with a printed colour-to-number reference chart) is fine, because it's just more detail on a texture that
already exists — it doesn't track or display a real value, it just has to read as "a scientific chart" visually.
Keep that line sharp: static print-styled detail in a texture, yes; anything that live-updates, no.

**Toxin's wrap ladder so far**, read these catalog entries and their `ToxinFX.lua`/`ToxinWrap.lua` hooks before
starting — they're the plumbing you extend, not something to reinvent: **Nightshade** (Uncommon, flat violet-plum
palette), **Coral Snake** (Uncommon, flat red/yellow/black bands, `Bands.Light`/`Bands.Glow` only), **Poison Dart
Frog** (Rare, cobalt core-to-edge gradient via `Bands.Radial`, gloss, black mottling, painted bubble mesh via
`Bands.Skin`), and **Octopus** (Epic, rust-red body with painted peach sucker-spot blotches/dots via
`Bands.LobeSkin`/`Bands.Skin`, luminous pulse, gloss). All four share one swap mechanism: `ToxinWrap.Run` (in
`roblox/ToxinWrap.lua`) swaps a wrap's `Palette.Color`/`Palette.Display` into `ToxinTuning` for the duration of one
broadcast, plus `T.Hard`, `T.Bands`, `T.Finish`, then restores them. Build pH Indicator the same way: a
`SkinCatalog.Skins.PHIndicator` entry with `Rarity = "Mythic"`, `Wrap = "Toxin"`, and a `Palette` table that extends
the same `Bands`/`Finish`/`Color`/`Display` shape the other four already use — don't invent a parallel system.

**A fresh, hard-won lesson from Octopus, worth applying from the start here rather than re-discovering it.** Octopus's
painted spot pattern (`Bands.Skin`/`Bands.LobeSkin`, built from vertex-coloured EditableMesh geometry) hit a real
ceiling: raising its resolution enough to read crisp blew the shared mesh-memory budget and broke painting on most
pieces, while the old resolution read blurry no matter how sharp the spot-edge falloff was pushed. The fix that
actually worked was switching the painted pattern from vertex colours to a small painted *image* on each sphere/puff
instead — crisp at any distance, and far lighter on mesh memory (about 1 MB of image memory bought what tens of
thousands of extra triangles couldn't). pH Indicator's own detail work — the litmus-strip mark, the printed chart
markings, the fizz-mote boundaries — should default to this image-texture approach rather than vertex-painted
geometry, specifically because it needs to stay crisp under Mythic's self-lit glow (confirm an image still displays
correctly on a glowing/`SelfLit` surface before committing the whole wrap to it, the same check Octopus needed).

**The Mythic wrap tier contract** (`.claude/skills/spellshot-wrap-tiers/references/tier-contract.md`), cumulative
with every tier below it:
- **Required:** at least two of — flowing colour (one shared, slow, continuous field moving through the bodies, not
  per-piece noise), light layers (curtains/ribbons), twinkles (sparse glints), a sheen (a calm glossy surface). The
  treatment is the wrap's signature and must never look dull.
- **Budget:** extra particles **+25–30%** of each effect's Default rate; frame cost measured (the existing Mythic
  model, Cryo's Aurora, costs about 3 ms/frame on desktop — treat that as the rough ceiling, not a target to beat by
  cutting corners); any EditableMesh/image copies capped and scaled by Graphics Quality.
- **Acceptance:** fastest 1-second colour change at most 25%; no frame-to-frame step above about 6% (slow and
  continuous, not jumpy); neighbouring pieces correlate as one field, never independent per-piece noise; every colour
  stays inside the design's own palette (report any off-palette share); cost and memory reported; and — this is the
  owner's own bar, stated directly — **this wrap has to read as clearly, unambiguously the best-looking wrap in
  Toxin's whole ladder**, richer than Octopus (Epic) at 30% sheet scale the same way every tier is required to beat
  the one below it, with no corner cut on quality anywhere in the piece.

**The design itself, locked from discussion with the owner — build this, don't redesign it:**
- **The scale.** Every gas, liquid, and membrane colour family continuously drifts through one shared scale: a
  red-orange "acidic" core, through amber, through a mid green, to a teal-blue "basic" edge — proposal anchors (every
  hex a *proposal*, calibrate the rendered pixel against these, not the input value, the way every prior Toxin wrap
  had to): core `#E8402A`, amber `#E89A2A`, mid green `#8CC23A` (check this one against the shipped-hex guard
  carefully — Toxin's identity green, `#80D421`, sits nearby), edge somewhere in `#2FD6B8`–`#4AE8C8` territory. Keep
  the edge a genuine teal, not another blue — Poison Dart Frog already owns cobalt/periwinkle blue
  (`#A9C6FF`/`#5F8CF2`) and Octopus owns red, so a blue-leaning edge here would collide with Frog's identity inside
  Toxin's own ladder. Stay clear of violet and pink across the whole scale — that boundary was set deliberately so
  this wrap never reads as a cousin of Radiant's Rainbow or Umbra's palette. This is the wrap's **flowing colour**
  lever: one shared phase driving every body at once (gas, liquid, membrane, bubble), not independent per-piece
  colour noise — build it the way Cryo's Aurora drives its `Flow` field, one source of truth read by every draw call.
- **The fizz (the wrap's twinkle lever, reskinned).** Fine, bright motes pop at the seams where one colour band is
  actively shading into the next — not scattered through the whole cloud, concentrated right at the transition
  boundaries, reading as a visible reaction happening at that edge rather than ambient sparkle. Use a crisp texture
  for these (soft/blurred textures have already blurred small accents into grey on this element before — Poison Dart
  Frog's speckle lesson applies here too).
- **The sheen.** The liquid and membrane get a wetter, glossier "litmus-paper" finish than Poison Dart Frog's
  Reflectance 0.15 — this reads as treated paper rather than venom, and it's the wrap's third lever alongside flowing
  colour and fizz (skip light layers/curtains deliberately — that's a sky/aurora motif and doesn't suit a gas cloud;
  three strong, deliberate levers beats four where one is forced).
- **Patient Zero's mark — the wrap's showcase moment.** Replace the plain glow-ring telegraph with a treatment that
  actually reads as a **litmus/pH test strip**: a thin banded shape, colour-graded end to end through the same red
  → amber → green → teal scale, that visually looks like a chemical indicator strip rather than an abstract glow.
  As the countdown closes in, sweep the mark's hue across that same scale — calm teal-green early, racing through
  amber, urgent red-orange in the last moment before detonation — reusing Virulence's existing "reads by time" rule
  (today it just changes brightness and pulse speed; here it also changes hue, which is new and is the point).
  **This round's addition, the signature detail that makes pH Indicator unmistakably Mythic rather than a brighter
  Epic:** bake a static, printed-chart-style detail into the mark's (and optionally the membrane's) texture —
  scale markings that read like the printed reference chart on real pH indicator paper. This is purely a texture
  detail, built once and painted on, not a live value — see the wrap/skin boundary above for why it has to stay
  static.
</context>

<instructions>
Before writing anything, read the four shipped Toxin wraps' catalog entries and their `ToxinFX.lua`/`ToxinWrap.lua`
hooks in full, plus `.claude/skills/spellshot-wrap-tiers/references/element-adapters.md`'s Toxin section — the
`Bands` fields you need (`Radial`, `Edge`, `Gloss`, `Pulse`, `Light`, `Glow`, `Skin`, `LobeSkin`) already exist and
already have working examples; your job is composing and extending them for a continuously flowing field, not
inventing a new plumbing layer. Also read `reference-wraps.md`'s "Lessons the models paid for" section — several of
those lessons (translucent puffs smearing colour into blends, the colour grade crushing near-black values, glossy
black mirroring the sky, additive accents over a saturated body turning white) apply directly to a wrap that spans
five hues across one cloud, more than any prior Toxin wrap has attempted.

Build the flowing-colour field first and get it reading as one coherent, slow-moving system before layering the fizz
and sheen on top — a correct field with no fizz is a usable checkpoint; fizz and sheen with a broken or jumpy field
is not. Measure the particle delta the same way the tier contract describes (sum ParticleEmitter `Rate` plus burst
`Emit` counts, Default vs wrapped, per effect) rather than eyeballing it, and report it per effect, not as one
aggregate number.

Run the shipped-hex guard (`scripts/guard_check.py`) before the checkpoint, not after — if the mid-scale green clips
the 12/255 boundary around Toxin's identity colour, shift it and say so in the report rather than quietly picking a
value that happens to pass.

**How changes actually get into Studio — don't skip this.** In the Edit-mode datamodel, push an updated file by
serving it from a local server in `roblox/` (`uv run --no-project python -m http.server 8768 --bind 127.0.0.1`),
`HttpService:GetAsync` it from Studio, strip CRLF, sanity-check it with `loadstring` (stop Play first — `loadstring`
isn't available in Play), then write it with `ScriptEditorService:UpdateSourceAsync`. If you use `execute_luau` to
`require` a ModuleScript for a quick check, remember it gets its own fresh copy, separate from the game's live one —
drive the actual running game through broadcasts (`CombatCore.Broadcast(kind, data)` on the Server) or attributes,
not through that second copy. Build any temporary test rig as a Script + LocalScript pair named `_PHIndicatorStage` /
`_PHIndicatorStageClient`, and delete both once the wrap is wired — don't leave stage harnesses behind. Python only
through `uv` (`uv run --no-project --with numpy --with pillow python ...`), never a bare `python`/`pip` call. Because
EditableMesh builds are lazy and per-client, confirm in Studio that a fresh client still falls back to Default
cleanly before any painted-texture build finishes, and that a build failure never errors visibly — this matters more
here than on prior wraps, given the image-texture work this design calls for.

This is cosmetic-only work: damage, hitboxes, range, timing, and cooldowns stay exactly Default's. A visible
projectile (the bubble) stays no wider than its hit width. Route every new or scaled particle through the project's
shared emitter helper so Graphics Quality and Reduce Enemy VFX still apply to it, and make sure the flowing-colour
phase, the pulse, and the fizz all steady or scale down under Reduce Flashing the same way Octopus's pulse already
does.

Scope stays exactly this one wrap. If you find a real defect in one of the four shipped wraps while reading them
(a stale header comment, a missed `Rarity` field, anything the project's own `scripts/agreement_check.py`-style
checks would catch), note it in your report rather than fixing it in passing — that's the owner's call, not
something to bundle into this build.
</instructions>

<output_format>
Produce a checkpoint, not a finished, wired feature:
1. The `SkinCatalog.Skins.PHIndicator` entry and its `Palette`, following the existing four wraps' shape.
2. Any `ToxinFX.lua`/`ToxinWrap.lua` hook additions needed to draw the flowing field, the fizz, the sheen, and the
   reworked Patient Zero mark — gated the same way the existing wraps are, so Default is untouched when no wrap is
   equipped.
3. A checkpoint sheet at the same camera and scale the other Toxin wraps used: Default next to pH Indicator, an
   overhead or wide shot of the cloud so the flowing field reads clearly, a close-up of the bubble, and Patient
   Zero's mark shown at two points in its countdown (early vs. just before detonation) so the hue-sweep is visible.
   View it at about 30% scale as well as full size, the way the owner reviews every wrap checkpoint.
4. A short written report: particle delta per effect (target +25–30%), frame cost if measurable, the image/mesh
   memory cost of any painted texture work, the guard-check result, and which two-or-more Mythic levers you built
   (flowing colour, fizz, sheen) with one line each on how. Flag anything you had to deviate from in the locked
   design, and why — don't silently fix a gap you disagree with.
5. Stop there. Do not add `PHIndicator` to `SkinCatalog.ElementWraps.Toxin` and do not remove any temporary stage
   harness until the owner has reviewed the checkpoint and approved it.
</output_format>

<edge_cases>
If the five-hue scale reads muddy or loses structure once drawn in-engine (a real risk the lessons-paid-for section
warns about — overlapping translucent puffs can blend adjacent bands into mud), don't silently narrow the scale to
fewer colours to make it easier; report exactly where it breaks down and what you tried, and let the owner decide
whether to adjust the palette or the band structure. If an image-texture approach for the litmus-strip mark or the
printed chart detail doesn't display correctly on a `SelfLit`/glowing surface, don't ship it anyway — fall back to
the vertex-painted approach for that one piece, report the fallback, and don't let it block the rest of the
checkpoint. If Toxin's existing `Bands` fields genuinely can't express the continuous flowing field without a new
mechanism, stop and describe the gap rather than inventing a parallel system that drifts from how the other four
wraps work.
</edge_cases>

<tone_preference>
Report plainly and completely — particle numbers, memory costs, and anything that deviated from the locked design
all belong in the report, not just the parts that went well. This is a checkpoint for the owner to react to, not a
pitch for approval.
</tone_preference>
