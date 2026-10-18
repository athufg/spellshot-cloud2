# SPELLSHOT — Build Prompt #[N]: Toxin Wrap 2, "Coral Snake" (Uncommon)

Continuation of the Opus 5 / Claude Code build sequence (previous: the Toxin Nightshade wrap, which must be approved and wired first; filename unknown).
This is visual/VFX work: real reference before styling, checkpoint before final.

<role>
You are building the second Toxin wrap for SPELLSHOT, a Roblox PvP elemental-duel FPS, for the solo developer. A **wrap** is a recolour of existing shapes. It never changes geometry, particle counts, timing or gameplay. "Coral Snake" is the second Uncommon wrap: a flat palette of hard colour bands (red, yellow, black), no animation, and the same particle amount as Default. You are done when Coral Snake recolours every Default Toxin visual, the user approved the colour checkpoint, and it is wired as a selectable wrap next to Nightshade.
</role>

<token_budget>
Be efficient with tokens. One agent, no subagents. Use targeted searches and function-level reads, never whole-file or whole-repo reads. Do not re-survey the Toxin colour sites: reuse the list and the wrap module from Nightshade. View at most three images in total. Keep progress notes to a line and the report short.
</token_budget>

<context>
- **Reuse Nightshade's work.** Find the Toxin wrap module and its data-entry format with one targeted search, and add Coral Snake as a second entry. Reuse the colour-site list Nightshade produced, and the same equip path. If Nightshade is not wired yet, stop and say so.
- **Toxin's Default 3D look** is murky, desaturated swamp-olive in four material families (gas/haze `#4B5A2A` / `#5E6F35` / `#2E3A1A` / `#1C2410`, viscous liquid `#6B7A1E` / `#3D4610` / `#E8F2A0`, membrane `#8FA83E` / `#C9E077`) plus **Virulence** `#C3E82E`, which reads by time (brighter and faster-pulsing the nearer something is to detonating or expiring, with a steady variant for non-countdown states) and is the one saturated thing in the kit. Gas has depth falloff: thick and near-opaque at the core, thinning to a soft, indistinct edge. The membrane is never clear glass. The poison substance keeps its scoped hazy translucency, exactly as Default.
- **Hard guard.** Base `#80D421`, Light `#CCF570` and Dark `#4A1A6B` are HUD and uniform colours only and never appear on 3D geometry. `ToxinFX.lua` refuses any colour within 12/255 of them. Every Coral Snake hex must clear that guard. Handle it the same way Nightshade did.
- Wraps recolour the Default Toxin shapes only. Do not touch the HUD, the callouts, the status reactions, or the screen-space desaturation tell for reduced self-damage (`#8A9488`). Do not recolour the shared-pool Techniques (the Antitoxin Vent mask and Acid Rain): whether wraps tint Techniques is unconfirmed.
- The code wins on how something works today, and the manual (v0.24) wins on what it should do. Say so in your report if they disagree.
</context>

<palette>
Coral Snake, flat hard-edged bands (colours are proposals; flag them if they look wrong in-game):
- Red: `#D43A2F`
- Yellow: `#F0D23C`
- Black: `#1B1B22` (a soft black)
- Virulence: `#FFF6B8`, a white-hot pale yellow. It must stay the one glowing spike, clearly brighter and lighter than the yellow band, so the time-based pulse still reads against it.

**Band logic (a proposal; tune it and report what you chose).** The real snake runs red, yellow, black, yellow, red. Map that to Toxin's structure with **hard colour stops only, no blending**: for gas and haze, the core-to-edge order of a puff's colour-over-life is black at the thick core, a narrow yellow ring, the red body, then a narrow yellow lit edge. Use duplicate-keypoint ColorSequences for the hard steps, and at most five stops per sequence. For the membrane (a baked mesh), use the same bands only where the existing vertex-colour or tone-band mechanism supports them without changing geometry. Otherwise keep the membrane flat red with a yellow highlight. For viscous liquid and residue: red base, black deep core, pale yellow specular. Flag, do not decide, any site where the bands cannot be done as a pure recolour.

Red is near Pyro, and yellow is near Voltaic and Radiant, so the band pattern itself has to carry the difference. Toxin's shapes (round bubbles, lobed clouds, drips) and soft hazy edges also carry the Element. No magenta (`#E91E8C` is Sparks).
</palette>

<instructions>
1. **Reuse the Nightshade colour-site list** and confirm it is still complete (one targeted check). Do not recolour the Technique sites.
2. **Band mapping (text only, no images, at most 8 lines).** For each of the four material families, say how the red / yellow / black bands map onto it and where a site cannot take bands. Include the gas puffs' colour-over-life order, the membrane, and the liquid. Stop and wait only if a family cannot carry the bands without a geometry or texture change.
3. **Implement it as a second data entry in the same module.** Particle counts, geometry, timing, alpha and falloff, and every pulse rate and acceleration curve stay identical to Default.
4. **Colour checkpoint:** render one sheet at on-screen size from normal 1v1 distance, on the project's showcase stage (pale warm-grey ground `#C9C2B8`, flat pale blue-grey sky `#B9C4CC`) and in the real map lighting, showing Default and Coral Snake side by side for Toxic Bubbles, Corrosive Cloud, Patient Zero (the mark early and late in its pulse, and the detonation) and the Passive's ribbon. Add a Pyro Default shot and a Voltaic Default shot for comparison, and the same Coral Snake shots with the Colourblind-Safe setting on. Stop and show it with a short note: does it still read as Toxin and not Pyro or Voltaic, is the cloud at least as visible as Default, does Virulence's acceleration still read against the yellow band, and what is the nearest shipped-hex distance of every new hex. Do not wire it up until the user approves.
5. After approval, wire Coral Snake as a selectable wrap beside Nightshade through the existing plumbing. Add nothing else: no shop, no price, no new menu.
</instructions>

<rules>
Cosmetic only: no gameplay value, timing or hitbox changes, and visibility stays hit-honest. Colour only: no new shapes, no animation, no new particles, no blended gradients (Uncommon is one flat palette; the hard band steps are the only structure). The hazard must never read as less visible than Default, and airborne puffs and bubbles must never end dark: the black band sits at the core only, and cloud edges stay lit. No shipped identity hex on 3D geometry, including as a step in a band sequence. All emitters keep going through the project's emitter helper, so Graphics Quality, Reduce Enemy VFX and Reduce Flashing still apply. No kill effect, no HUD or status-reaction retint, no new callout words.
</rules>

<scope>
Only the Coral Snake wrap on the Default Toxin shapes. Not in scope: the other Toxin wraps, wraps on skins, the Techniques' visuals, and any HUD icon, health-bar or rarity change. Make routine judgment calls yourself and list them. Flag anything ambiguous instead of deciding it, and add nothing that wasn't asked for.
</scope>

<output_format>
Step 2: the short text mapping. Step 4: the checkpoint sheet with the short note. Final report in a few lines: files and module name, how many colour sites were recoloured, what was wired, and anything flagged.
</output_format>
