# SPELLSHOT — Build Prompt #[N]: Toxin Wrap 3, "Poison Dart Frog" (Rare)

Continuation of the Opus 5 / Claude Code build sequence (previous: the Toxin Coral Snake wrap; filename unknown).
This is visual/VFX work: real reference before styling, checkpoint before final. Make it look clearly better than the two Uncommon wraps.

<role>
You are building the third Toxin wrap for SPELLSHOT, a Roblox PvP elemental-duel FPS, for the solo developer. A **wrap** is a recolour of existing shapes. It never changes geometry, timing or gameplay. "Poison Dart Frog" is the **Rare** wrap, one step above the two flat-palette Uncommon wraps (Nightshade, Coral Snake). Rare = a **gradient and material pass**: a smooth core-to-edge colour gradient, a wet glossy finish, and controlled mottling and speckle accents, with no animation and the same particle count as Default. You are done when Poison Dart Frog recolours every Default Toxin visual, the user approved the colour checkpoint, and it is wired as a selectable wrap.
</role>

<token_budget>
Be efficient with tokens. One agent, no subagents. Use targeted searches and function-level reads, never whole-file or whole-repo reads. Do not re-survey the Toxin colour sites: reuse the list and the wrap module from the Uncommon wraps. View at most four images in total. Keep progress notes to a line and the report short.
</token_budget>

<context>
- **Reuse the Uncommon wraps' work.** Find the Toxin wrap module and its data-entry format with one targeted search, and add Poison Dart Frog as another entry. Reuse the colour-site list and the same equip path. If the module is not wired yet, stop and say so.
- **Toxin's Default 3D look** is murky, desaturated swamp-olive in four material families (gas/haze `#4B5A2A` / `#5E6F35` / `#2E3A1A` / `#1C2410`, viscous liquid `#6B7A1E` / `#3D4610` / `#E8F2A0`, membrane `#8FA83E` / `#C9E077`) plus **Virulence** `#C3E82E`, which reads by time (brighter and faster-pulsing the nearer something is to detonating or expiring, with a steady variant for non-countdown states) and is the one saturated spike in the kit. Gas has depth falloff: thick and near-opaque at the core, thinning to a soft, indistinct edge. The membrane is never clear glass. The poison substance keeps its scoped hazy translucency, exactly as Default.
- **Hard guard.** Base `#80D421`, Light `#CCF570` and Dark `#4A1A6B` are HUD and uniform colours only and never appear on 3D geometry. `ToxinFX.lua` refuses any colour within 12/255 of them. Every Poison Dart Frog hex, including every step of every gradient, must clear it. Handle it the same way the Uncommon wraps did. The yellow-green accents are the risky ones.
- **Gradient mechanism.** The gradient must be done with no geometry change: colour-over-life ColorSequences for the gas puffs and liquid, and for the membrane mesh whichever mechanism the Toxin kit's mesh already supports (baked vertex-colour bands with a palette lookup, or a tint). Cryo's wraps (Black Ice, Aurora) already solved a similar core-to-edge gradient on baked meshes: look at the approach with one targeted search, and reuse the idea, not the Cryo-specific code. If the membrane cannot take a smooth gradient without a change outside the wrap module, report the smallest option and what it costs, and do not decide.
- **Lessons from the Coral Snake round (apply from the start):**
  1. Soft overlapping puffs smear hard colour structure, and additive blending, glow, lights or overlap can shift a colour's hue (a crimson red rendered orange). Measure the *rendered* colour of every key site on both the stage and the map lighting, and report the measured hex next to the intended one.
  2. Do not give the cloud a hot white-yellow core. That reads as fire and is Pyro's look.
  3. When the structure needs distinct colours (mottle patches, speckle accents), separate them properly (for example split the existing particles across one emitter per colour, same total count) so the structure is visible and not blurred.
  4. The checkpoint comparison shots must be readable at a glance: zoomed, not tiny, and including the Colourblind-Safe shots and the nearest-shipped-hex distances.
- Wraps recolour the Default Toxin shapes only. Do not touch the HUD, the callouts, the status reactions, or the screen-space desaturation tell for reduced self-damage (`#8A9488`). Do not recolour the shared-pool Techniques (the Antitoxin Vent mask and Acid Rain): whether wraps tint Techniques is unconfirmed.
- The code wins on how something works today, and the manual (v0.24) wins on what it should do. Say so in your report if they disagree.
</context>

<palette>
Poison Dart Frog, a vivid cobalt-blue body with black mottling and a few yellow-green accents (colours are proposals; flag them if they look wrong in-game, and tune with the same display-compensation approach Default uses):
- **Gas/haze gradient, core to edge:** deepest core `#14267A`, shadow `#1B2F8A`, base `#2F55D6`, lit `#5F8CF2`, thin lit edge `#A9C6FF`. The core is deep cobalt, not black or navy-dark, and the edge is bright, so the cloud stays visible on dark floors.
- **Viscous liquid and residue:** base `#2A4CC8`, deep core `#111C5A`, wet specular `#E6F0FF` (a strong glossy sheen, like wet frog skin).
- **Membrane (Toxic Bubbles):** base `#3A62E0`, highlight `#CFE0FF`, a glossy wet look with the cobalt haze roiling inside, never clear glass.
- **Black mottling:** `#10101A` soft black patches, irregular, and only inside the cloud body and the membrane, never at the cloud edge.
- **Yellow-green speckle accent:** `#D4E63C`, small and sparse, dimmer and smaller than Virulence.
- **Virulence:** `#F4FFB8`, a white-hot pale lime. It must stay the one glowing spike, clearly the brightest thing in frame, so the time-based pulse still reads against the cobalt.

Cobalt (hue about 225°) is purer and darker than Cryo's cyan-leaning blue, and bluer than Umbra's purple, so check it against Cryo Default and Umbra Default. Toxin's shapes (round bubbles, lobed clouds, drips) and soft hazy edges carry the Element. No magenta (`#E91E8C` is Sparks).
</palette>

<instructions>
1. **Reuse the colour-site list** from the Uncommon wraps and confirm it is still complete (one targeted check). Do not recolour the Technique sites.
2. **How the Rare features plug in (text only, no images, at most 10 lines).** For each of the four material families, say how the gradient maps onto it, and how the mottling and speckle accents are done without changing the particle count (for example by splitting the existing particles across colour-variant emitters). If the existing particles cannot carry the speckles at the Default count, propose the smallest tiny-mote addition within a small Rare budget and flag it: the user decides. Say which sites cannot take the gradient or mottle as a pure recolour. Stop and wait only if the membrane needs a change outside the wrap module.
3. **Implement it as another data entry in the same module.** Particle counts (unless the user approved the flagged speckle option), geometry, timing, alpha and falloff, and every pulse rate and acceleration curve stay identical to Default.
4. **Colour checkpoint (at most four images):** one sheet at on-screen size from normal 1v1 distance, on the project's showcase stage (pale warm-grey ground `#C9C2B8`, flat pale blue-grey sky `#B9C4CC`) and in the real map lighting, with Default and Poison Dart Frog side by side for Toxic Bubbles (in flight and bursting, zoomed so the membrane is readable), Corrosive Cloud, Patient Zero (the mark early and late in its pulse, and the detonation) and the Passive's ribbon. One overhead of the Corrosive Cloud so the gradient and mottling can be judged. Add a Cryo Default shot and an Umbra Default shot for comparison, and the same wrap shots with the Colourblind-Safe setting on. Stop and show it with a short note: does it still read as Toxin and not Cryo or Umbra, is the cloud at least as visible as Default against the dark map floor and the sky (give a luminance-contrast number for both), does Virulence's acceleration still read, the measured versus intended hex of the key sites, and the nearest shipped-hex distance of every new hex including each gradient step. Do not wire it up until the user approves.
5. After approval, wire Poison Dart Frog as a selectable wrap beside the others through the existing plumbing. Add nothing else: no shop, no price, no new menu.
</instructions>

<rules>
Cosmetic only: no gameplay value, timing or hitbox changes, and visibility stays hit-honest. Colour and finish only: no new shapes, no animation, no new particles (unless the flagged speckle option is approved). The hazard must never read as less visible than Default, and airborne puffs and bubbles must never end dark: keep cloud edges lit and the core deep cobalt, not black. No white-hot yellow core anywhere except Virulence. No shipped identity hex on 3D geometry, including as a gradient step. All emitters keep going through the project's emitter helper, so Graphics Quality, Reduce Enemy VFX and Reduce Flashing still apply. No kill effect, no HUD or status-reaction retint, no new callout words.
</rules>

<scope>
Only the Poison Dart Frog wrap on the Default Toxin shapes. Not in scope: the other Toxin wraps, wraps on skins, the Techniques' visuals, and any HUD icon, health-bar or rarity change. Make routine judgment calls yourself and list them. Flag anything ambiguous instead of deciding it, and add nothing that wasn't asked for.
</scope>

<output_format>
Step 2: the short text note. Step 4: the checkpoint images with the short note. Final report in a few lines: files and module name, how many colour sites were recoloured, what was wired, and anything flagged (including the speckle option and the guard decision).
</output_format>
