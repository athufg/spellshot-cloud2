# SPELLSHOT — Build Prompt #[N]: Toxin Wrap 1, "Nightshade" (Uncommon)

Continuation of the Opus 5 / Claude Code build sequence (previous: the Cryo Aurora wrap; filename unknown).
This is visual/VFX work: real reference before styling, checkpoint before final.

<role>
You are building the first Toxin wrap for SPELLSHOT, a Roblox PvP elemental-duel FPS, for the solo developer. A **wrap** is a recolour of existing shapes. It never changes geometry, particle counts, timing or gameplay. "Nightshade" is the Uncommon wrap: one flat palette, no animation, and the same particle amount as Default. You are done when Nightshade recolours every Default Toxin visual, the user approved the colour checkpoint, and it is wired as a selectable wrap.
</role>

<token_budget>
Be efficient with tokens. One agent, no subagents. Use targeted searches and function-level reads, never whole-file or whole-repo reads. View at most three images in total: the checkpoint sheet, and at most two close-ups if you need them. Keep progress notes to a line and the report short.
</token_budget>

<context>
- **Toxin's Default 3D look** is four material families (the hexes are in `ToxinTuning` and used by `ToxinFX.lua`; display colours go through the measured, display-compensated `ToxinTuning.Display` table):
  - gas/haze (Corrosive Cloud, Patient Zero's mark and detonation, the Passive's ribbon): murky swamp-olive, base `#4B5A2A`, lit murk `#5E6F35`, shadow `#2E3A1A`, deepest core `#1C2410`, with depth-based falloff, thick and near-opaque at the churning core, thinning to a soft, indistinct edge that never reads as a clean line;
  - viscous liquid (residue and drips): base `#6B7A1E`, deep core `#3D4610`, wet specular `#E8F2A0`;
  - membrane (Toxic Bubbles, the kit's one solid object): base `#8FA83E`, highlight `#C9E077`, with the haze visibly roiling inside, never clear glass;
  - **Virulence** `#C3E82E`, the signature accent. It reads by *time*: brighter and faster-pulsing the closer something is to detonating or expiring (Patient Zero's mark accelerates from about 0.6 Hz to 4–5 Hz), with a steady variant for states that count down to nothing. It is the one saturated thing in an otherwise murky kit.
- **Hard guard.** Toxin's three shipped identity colours, Base `#80D421`, Light `#CCF570` and Dark `#4A1A6B`, are HUD and uniform colours only and must never appear on 3D geometry. `ToxinFX.lua` refuses any colour within 12/255 of them. Every Nightshade hex must clear that guard (the Dark `#4A1A6B` is a purple, so check the violet tones especially). Do not weaken the guard for anything outside the wrap's own palette. If the guard blocks wrap colours, report the smallest change that lets the active wrap's palette through, and make it only if the user agrees.
- The poison substance (bubbles, cloud puffs) keeps the scoped hazy translucency it already has, exactly as in Default. Nothing else becomes translucent.
- **Wrap plumbing already exists for other Elements** (Pyro "Azure Flame", Terra "Obsidian Magma", Radiant "Rainbow"; colour wraps are palette entries with `Stops`, wraps show as rows under WRAPS in the Loadout). Toxin has no wrap yet. Find with one or two targeted searches how those wraps are registered and equipped, and follow that pattern for Toxin.
- Wraps recolour the Default Toxin shapes only. Toxin has no skins. Do not touch the HUD, the callouts, the status reactions, or the screen-space desaturation tell for reduced self-damage (`#8A9488`), which is a gameplay tell, not a wrap visual.
- The code wins on how something works today, and the manual (v0.24) wins on what it should do. Say so in your report if they disagree.
</context>

<palette>
Nightshade, keyed to the same four material families so Toxin's structure stays (colours are proposals; flag them if they look wrong in-game, and tune through the same display-compensation approach Default uses):
- Gas/haze: base `#5A456E` murky plum, lit murk `#735A8A`, shadow `#3A2B4A`, deepest core `#231A30`
- Viscous liquid: base `#7A5599`, deep core `#3A2A57`, wet specular `#EBDDFA`
- Membrane: base `#9578B3`, highlight `#D9C6EE`
- Virulence: `#E39BFF`, a bright orchid-lilac. It must stay the one saturated spike, clearly lighter and more saturated than the haze around it.

Nightshade is murky, greyish plum with lighter lit tones and a pinker Virulence, so it does not read as Umbra (a saturated deep violet with obsidian shards). Toxin's shapes (round membrane bubbles, lobed cauliflower clouds, dripping residue) and the soft hazy edges carry the Element's identity. No magenta (`#E91E8C` belongs to Sparks) and no gold.
</palette>

<instructions>
1. **Find every Default Toxin visual** with targeted searches: each material-family colour, each emitter preset's ColorSequence, the membrane mesh and any vertex or hard-coded colours, ground stains and decals, lights (such as the detonation flash light), and hard-coded colours in the ability handlers (Toxic Bubbles, Corrosive Cloud, the Passive's lifesteal ribbon and residue, Patient Zero's mark, pulse and detonation). Produce a short list of colour sites. Note which sites belong to the shared-pool Techniques (the Antitoxin Vent gas mask and Acid Rain): **do not recolour those.** It is unconfirmed whether wraps tint Techniques. Just list them for the user.
2. **How Nightshade plugs in (text only, no images, at most 8 lines).** Say what the existing wrap plumbing is and how Toxin slots into it as one data entry (an id, the Uncommon tier, and the palette above). Say whether the wrap should override the `ToxinTuning` colour table or the `Display` table, and how it interacts with the 12/255 guard. If a reuse path exists, say so and continue. **Stop and wait only** if there is no equip path to reuse or the guard needs more than letting the active wrap's palette through. Flag, do not decide.
3. **Implement it in a separate module**, so Nightshade is one data entry. Recolour every site from step 1. Particle counts, geometry, timing, alpha and falloff behaviour, and every pulse rate and acceleration curve stay identical to Default.
4. **Colour checkpoint:** render one sheet at on-screen size from normal 1v1 distance, on the project's showcase stage (pale warm-grey ground `#C9C2B8`, flat pale blue-grey sky `#B9C4CC`) and in the real map lighting, showing Default and Nightshade side by side for Toxic Bubbles, Corrosive Cloud, Patient Zero (the mark early and late in its pulse, and the detonation) and the Passive's ribbon. Add an Umbra Default shot for comparison, and the same Nightshade shots with the Colourblind-Safe setting on. Stop and show it with a short note: does Nightshade still read as Toxin and not Umbra in both modes, is the cloud at least as visible as Default against sky and floor, does Virulence's acceleration still read clearly, and what is the nearest shipped-hex distance of every new hex. Do not wire it up until the user approves.
5. After approval, wire Nightshade as a selectable wrap through the existing plumbing. If a piece of that plumbing is missing for Toxin, report what is missing and add only the smallest data field needed. Do not invent a shop, a price, or a new menu.
</instructions>

<rules>
Cosmetic only: no gameplay value, timing or hitbox changes, and visibility stays hit-honest. Colour only: no new shapes, no animation, no new particles, no gradients beyond the depth falloff Default already has (Uncommon is one flat palette). The hazard must never read as less visible than Default, and airborne puffs and bubbles must never end dark: keep the cloud edges lit and the deepest core no darker, relative to its surroundings, than Default's. No shipped identity hex on 3D geometry, including as a step in a gradient. All emitters keep going through the project's emitter helper, so Graphics Quality, Reduce Enemy VFX and Reduce Flashing still apply. No kill effect, no HUD or status-reaction retint, no new callout words.
</rules>

<scope>
Only the Nightshade wrap on the Default Toxin shapes. Not in scope: the other four Toxin wraps, wraps on skins, the Techniques' visuals (Antitoxin Vent mask, Acid Rain), and any HUD icon, health-bar or rarity change. Make routine judgment calls yourself and list them. Flag anything ambiguous instead of deciding it, and add nothing that wasn't asked for.
</scope>

<output_format>
Step 2: the short text note. Step 4: the checkpoint sheet with the short note. Final report in a few lines: files and module name, how many colour sites were recoloured, what was wired, and anything flagged (including the Technique sites left untouched, and the guard decision).
</output_format>
