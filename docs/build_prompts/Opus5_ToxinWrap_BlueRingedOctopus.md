# SPELLSHOT — Build Prompt #[N]: Toxin Wrap 4, "Blue-Ringed Octopus" (Epic)

Continuation of the Opus 5 / Claude Code build sequence (previous: Toxin Poison Dart Frog, approved and wired; filename unknown).
Visual/VFX work: checkpoint before final. Use the project skill `spellshot-wrap-tiers` (`.claude/skills/spellshot-wrap-tiers/`).

<role>
You are building the fourth Toxin wrap for SPELLSHOT, a Roblox PvP elemental-duel FPS, for the solo developer. A **wrap** recolours and re-dresses the Default shapes; geometry, timing, hitboxes and gameplay never change. "Blue-Ringed Octopus" is the **Epic** wrap: murky yellow-ochre gas and bubbles studded with glowing electric-blue rings, a slow glow pulse and shimmering motes. The developer's bar is that at a glance it looks clearly better than Poison Dart Frog (Rare) and the Uncommon wraps; the Frog was first judged "just a recolour", so visible glow, rings, pulse and motes are the point, not a nicety. Done = it recolours every Default Toxin visual, the user approved the checkpoint, and it is wired as a selectable wrap.
</role>

<token_budget>
One agent, no subagents. Targeted searches and function-level reads, never whole files. Read the skill's `SKILL.md`, the Epic section of `references/tier-contract.md`, the Toxin part of `references/element-adapters.md` and `references/reference-wraps.md`; skip the rest until needed. Do not re-survey Toxin colour sites: reuse the Frog's list and its wrap module (`ToxinWrap`, the `SkinCatalog.Skins` entry format, the painted-membrane pipeline). View at most four images. One-line progress notes, short report.
</token_budget>

<context>
- **The tier is fixed by the skill's contract; do not re-derive it.** Epic = luminous glow (self-lit, LightInfluence 0) on the key bodies, a slow brightness pulse (period about 2.25 s, amplitude about ±15%, never faster than 0.5 Hz), shimmer motes and a few extra small emitters totalling **+10-15% per effect over Default** (measured from Default's own emission, computed at runtime, through the project's emitter helper). It keeps the Rare levers: core-to-edge gradient, gloss finish, static patterns, painted mesh copies. Forbidden (Mythic): flowing colour fields, light curtains or ribbons, twinkle fields, anything over +15%. The Frog's +8% speckle is not added on top: the ring motes replace it inside the +10-15% total. If the skill and this prompt disagree, the skill's table wins; say so.
- **Toxin's Default 3D look:** murky desaturated swamp-olive in four families (gas `#4B5A2A` / `#5E6F35` / `#2E3A1A` / `#1C2410`, liquid `#6B7A1E` / `#3D4610` / spec `#E8F2A0`, membrane `#8FA83E` / `#C9E077`) plus **Virulence**, which reads by time (Patient Zero's mark accelerates about 0.6 Hz to 4-5 Hz). Gas keeps its depth falloff (thick core, soft indistinct edge); the membrane is never clear glass; poison keeps its scoped hazy translucency.
- **Hard guards.** Toxin's shipped identity hexes (Base `#80D421`, Light `#CCF570`, Dark `#4A1A6B`) never appear on 3D geometry, including every gradient step; run `scripts/guard_check.py` over every hex. No magenta `#E91E8C`. No hot white-yellow core (ochre-yellow can read as Pyro fire or Voltaic).
- **Lessons already paid for (apply from the start):** (1) overlapping translucent puffs smear colour structure and additive blending shifts hue, so measure the *rendered* hex on the showcase stage and the real map and report measured next to intended; (2) separate colours by site, for example one emitter per colour with the same total count; (3) the colour grade crushes very dark values and saturates, so calibrate on rendered pixels; (4) soft smoke textures blur small accents, so use a crisp texture for motes and rings; (5) a painted mesh built on first use leaves the first instance plain, so build it off the draw path.
- **Pulse trap:** Patient Zero's mark pulses 0.6 Hz and up to read *time*, close to Epic's 0.44 Hz. The Epic pulse applies to the wrap's glow pieces only; Virulence and the mark's countdown pulse stay Default's, untouched and unconfounded. Report how you separated them.
- **Textures:** you cannot upload to Roblox; the developer does. Use a built-in or existing project sprite for rings and motes. If no crisp ring sprite exists, ship a plain round glow dot now, and flag the smallest option (you generate a ring PNG file, the developer uploads it).
- The code wins on how things work today; the manual wins on what they should do. Note any disagreement.
</context>

<palette>
Developer-approved concept: the animal's tan-ochre body with iridescent electric-blue rings, Virulence turned into the blue ring flash. Every value is a proposal; tune on rendered pixels and flag what you change.
- **Gas, core to edge:** core `#4A3512`, shadow `#7A5A1E`, base `#B88A2E`, lit `#D8B04A`, thin lit edge `#EBCB7A`. Murky and desaturated, never a bright yellow, edges stay lit, core stays warm umber, not black.
- **Liquid and residue:** base `#B07F28`, deep `#4A3512`, wet specular `#F5E6B8`.
- **Membrane (Toxic Bubbles):** base `#C99A3A`, highlight `#F0DCA0`, glossy, haze roiling inside, never clear glass.
- **Rings (the signature):** electric blue `#1E90FF`, ring highlight `#9AD8FF`, ring deep `#0A4FB0`, over soft dark rosette spots `#2A1E0A`. Rings are self-lit and read as glowing; they sit on the membrane (painted, reusing the Frog's painted-bubble pipeline), as ring motes drifting in the clouds, and as a few small ring marks on the Corrosive Cloud's ground stain and the Patient Zero mark.
- **Virulence:** `#D6F2FF`, a pale ice-blue flash. It stays the brightest thing in frame and keeps its time-based acceleration.

The blue is near Cryo, and the ochre near Voltaic and Radiant. The ochre body must dominate and the rings stay accents, so it reads as Toxin by shape (round bubbles, lobed clouds, drips) and soft haze.
</palette>

<instructions>
1. **Tier audit (text only, at most 10 lines, before any code).** Map each part of the design to a lever: gradient, gloss, ring pattern, self-lit glow, pulse, motes, extra emitters. Say which Default emitters carry the ring motes and shimmer within the budget, and which sites cannot take a lever as a pure recolour. Flag, do not decide, anything needing a higher tier or a change outside the wrap module. Stop and wait only if the membrane or a sprite needs a change outside the module.
2. **Implement** as another `SkinCatalog.Skins` entry (`Rarity = "Epic"`, `Wrap = "Toxin"`) plus hooks gated on fields only this tier sets, so Default and the lower wraps render exactly as before. Techniques (Antitoxin Vent, Acid Rain) stay untouched.
3. **Calibrate and guard:** measure rendered colours, set display inputs, run `guard_check.py` over every hex, display input and gradient step.
4. **Self-check before showing anyone:** build the sheet below and look at it once at about 30% scale next to Default, Nightshade and the Frog. If the rings, glow, pulse or motes do not read clearly at that size, or it still looks like a recolour, strengthen the Epic levers (not the tier above) and rebuild, at most twice.
5. **Checkpoint (at most four images; stop and show; do not wire):**
   - Sheet 1, showcase stage (ground `#C9C2B8`, sky `#B9C4CC`): Default | Nightshade | Poison Dart Frog | Blue-Ringed Octopus, for Toxic Bubbles (flight and burst), Corrosive Cloud, Patient Zero (mark early, mark late, detonation) and the Passive's ribbon.
   - Sheet 2, real map lighting: the same wrap shots, the Colourblind-Safe versions, and Cryo Default and Voltaic Default for comparison.
   - Overhead of the Corrosive Cloud (gradient, rings and motes).
   - A pulse strip: trough and peak frames, and one Reduce Flashing frame.
   - With it, a short note: does it still read as Toxin and not Cryo or Voltaic; measured vs intended hex of the key sites; nearest shipped-hex distance of every hex including gradient steps; luminance contrast against the dark map floor and the sky (Default vs wrap); particle delta per effect (extra/s over Default/s, within +10-15%); pulse period and amplitude measured from the frames; whether Virulence's acceleration still reads against the pulse; the frame-cost impact.
6. **After approval only:** add `BlueRingedOctopus` to `SkinCatalog.ElementWraps.Toxin`; remove temporary stage scripts. Add nothing else: no shop, no price, no menu, no commit.
</instructions>

<rules>
Cosmetic and hit-honest: no gameplay value, timing, geometry or hitbox change; transparency of thin and ground pieces stays Default's; the hazard is never less visible than Default and airborne puffs never end dark. Reduce Flashing holds the pulse at mid and halves the motes; Graphics Quality, Reduce Enemy VFX and Colourblind-Safe behave exactly as in Default; low quality falls back to the plain recolour. No kill effect, no avatar change or aura, no HUD, callout or status-reaction change; the self-damage desaturation tell (`#8A9488`) is untouched. No new top-level locals in the Toxin kit modules if the skill or the code flags a local limit.
</rules>

<scope>
Only the Blue-Ringed Octopus wrap on the Default Toxin shapes. Not in scope: other wraps, skins, Techniques, HUD icons, health bar, rarity or price. Deliver what was asked at this scope; make routine judgment calls yourself and list them, and flag anything ambiguous rather than deciding it.
</scope>

<output_format>
Before your first tool call, one line on what you are about to do. Step 1 as the short text note; step 5 as the images with the short note. Final report in a few lines: files and module, colour sites recoloured, what was wired, and anything flagged (the ring sprite, the pulse separation, hue collisions, the guard).
</output_format>
