# SPELLSHOT — Build Prompt #[N]: Radiant Rainbow skin + a per-ability skin selector in the Loadout menu

Continuation of the Opus 5 / Claude Code build sequence (previous: the Cryo play-test fix prompts; keep [N] as a placeholder).
This is a cosmetic wrap, not a rework. Radiant's abilities keep their shapes, timings and behaviour. Only colour changes, and only when a player picks the skin. Nothing here changes damage, healing, range, cooldowns or hitboxes.

## Current state (from a Studio screen recording, NOT from code — read the code before trusting this)

- **Radiant already plays in Studio.** In the clip: a thin gold channel beam (Light Lance), a gold halo ring around the beam top, gold hit flashes, and a four-slot hotbar with gold icons. The passive label reads "OVERFLOW LIGHT". Radiant's shipped colours are Base `#F5C230`, Light `#FFF7D6`, Dark `#70520A`; its logo is an eight-point sun with a hollow ring core. Enumerate Radiant's built abilities from the code yourself and use the real names. Do not invent any.
- **Loadout menu (newsprint style).** A cream panel with a halftone dot field and a black "X" close button. Left column "ELEMENT": a two-column grid of cream cards (name plus a small label), the equipped one with a red border and a green "EQUIPPED". Right column "TECHNIQUES": a red header band over cream rows, each row `TECHNIQUE n`, a black `<` and `>` stepper around the name, the origin Element in small text, and a green "EQUIPPED" tag; the Ultimate row's arrows are greyed because the Ultimate comes with the Element. This is the pattern to reuse for skins.
- **Three layout bugs in this panel, confirmed from a second screenshot (all to be fixed, see the Loadout section):** the VOLTAIC, ZEPHYR and TERRA cards show a small grey line ("M1 + PRIMARY + PASSIVE ONLY") that is clipped at the card edge; the long "BUILT: PYRO, CRYO, VOLTAIC (...), ..." line runs outside its dark box on both sides and overlaps the "LOADOUT" title; and the footer line ("Pick an Element: its M1, Primary, Passive and Ultimate come with it. Techniques: any two, from every Element.") prints on top of the AQUA card, which is itself clipped by the panel's bottom edge. The Element grid has an empty cell to the right of AQUA.
- **Skins today:** no skin system exists. The notes list a "Technique reskin system" as not started, and say baked vertex colours make retinting hard. Treat this as the first small slice of that system.

## Reference before styling

No rainbow reference was supplied. Do not build from adjectives. First post one **colour-band sheet** (below) for approval before it goes on any ability. The look: a flat pop-art rainbow in six hard stripes, never a smooth gradient, in the game's flat saturated comic style.

## Design direction — the Rainbow skin

**Palette (PROPOSAL, flag it):** Red `#F0383A`, Orange `#FF8A1F`, Yellow `#FFD21F`, Green `#3CC95A`, Blue `#2C8BFF`, Violet `#8A4DFF`. **No magenta or hot pink anywhere: `#E91E8C` is the Sparks currency mark and is reserved.** Keep the existing ink outline `#080E1A` on any outlined mesh.

**How the wrap reads:**
- Each effect is banded in the six colours in order: stripes along a beam's length, around a ring's circumference, across a mesh by position. Hard edges, same stripe order everywhere.
- Particles and trails pick a band colour per particle from the six. Use hard-stepped `ColorSequence` keypoints, not smooth blends.
- **Identity anchor (PROPOSAL, flag it):** opponents read an Element by colour in a fight. So keep the core and the hit-flash of every effect in Radiant's gold-white (`#FFF7D6` and white), and put the rainbow on the body and outer shell. Keep Radiant's eight-point sun and hollow-ring shapes untouched, so shape still identifies Radiant when the colours change.
- Any ability that is not an effect (for example, a purely numeric passive) gets no change.

**Static first.** Ship the Rainbow as static hard bands, with at most a cheap scroll along beams and trails. Do not add a hue cycle or any extra emitters. That kind of animation is the reserved Mythic tier and is out of scope. Flag where it could be added later.

**Rainbow is a flat-comic skin, so hard bands only.** If any piece looks smooth or glowing, replace it with bands.

## Build — how skins plug in (build the plumbing once, generically)

1. **Catalog.** One small module, for example `SkinCatalog`: for each Element and ability, a list of skins `{Id, DisplayName, palette resolver}`. Everything has `Default`. Only Radiant's abilities also get `Rainbow`. Adding a skin later must be data plus a palette, not new effect code. Do not add skins for other Elements.
2. **Resolve, don't hardcode.** Radiant effect code asks `Skins.Resolve(element, ability, skinId)` for its colours (or band function), and falls back to today's colours for `Default`. `Default` must render exactly as it does now. Do not edit effect code beyond that one lookup.
3. **Where colour lives (find out first):** if Radiant's meshes have baked vertex-colour tone bands, then `MeshPart.Color` multiplies the baked gold and a tint will go muddy. Report what you find. Pick the cheapest of: neutral-grey baked meshes tinted per skin, a second baked mesh set, or applying the banding to non-mesh parts (Beams, Trails, particles, Neon parts, lights). Do not change the existing white `SmoothPlastic`/opaque/`DoubleSided = false` rules for outlined meshes, and do not make any outlined mesh transparent.
4. **Selection data.** Store one chosen skin Id per ability alongside the existing loadout. `LoadoutRequest` (already server-validated) gains the skin Id; the server rejects an Id that does not exist or is not allowed. For now **every skin is unlocked for everyone** and the server check goes through a single `OwnsSkin(player, skinId)` function that currently returns true, so Sparks or rarity gating can be added later without touching the UI or effects.
5. **What others see.** Visuals are client-side replays of the server broadcast. Add the caster's skin Id for that ability to the existing broadcast, and have every client (the caster's included) resolve it. Do not create server-side visual objects. Do not add a new remote when the existing broadcast can carry the Id.
6. **Borrowed Techniques (FLAG, do not decide):** a Technique keeps its origin Element's colour. Decide nothing about skins on a Technique the caster borrowed from another Element. Only offer a skin when the ability belongs to the caster's own Element, and say so in the report.

## Build — the Loadout menu (all inside the existing Loadout panel, no new window)

**Layout fixes first (requested by the developer; change nothing else in the panel):**
1. **Remove the small grey sub-text under the VOLTAIC, ZEPHYR and TERRA cards** ("M1 + PRIMARY + PASSIVE ONLY"). Those cards then show the icon, the name and the EQUIPPED label like the others. Do not touch other cards' text.
2. **Fix the "BUILT: ..." line so it stays inside its box.** It must not run past the box edges or overlap the "LOADOUT" title, at desktop and at phone width. Wrap it or shrink it to fit (for example on its own line under the title, inside the dark bar). Keep its wording unless it cannot fit; if it only exists for debugging, say so and propose hiding it instead. Flag your choice.
3. **Fix the footer overlap, needed because the panel layout changes anyway:** the footer line must not print on top of the AQUA card, and the AQUA card must sit fully inside the panel. (FLAG: this one was not asked for by name. It is the same panel and the same overflow problem, so fix it, and report it as a separate line.)

**The skin button, inside this same panel:**
- Put a **SKINS button in the empty cell to the right of AQUA** in the Element grid (or the nearest free spot inside the left column if the layout moves). It looks like an Element card: cream, same ink border, the label "SKINS", and a small flat six-stripe mark (the Rainbow palette) as its icon. It sits inside the panel, not in the title bar and not outside the box.
- Pressing it **swaps the right column from TECHNIQUES to SKINS** (same panel, no popup). A red header band reads "SKINS" plus the equipped Element's name, with a small black BACK button (styled like the black X button) that returns to TECHNIQUES.
- The SKINS view lists one row per ability slot of the equipped Element: M1, Primary, Passive (only if it has a visual), Ultimate, and the two equipped Technique slots. Each row copies the existing Technique row pattern: a small slot label, the ability name, a black `<` and `>` stepper around the **skin name**, and a green "EQUIPPED" tag.
- A slot with only `Default` (every slot of every Element except Radiant, and any borrowed Technique) shows greyed arrows and "DEFAULT", exactly like the greyed Ultimate arrows today. Do not hide the row, so players can see where skins will appear.
- If the rows do not fit the panel height, make the column scrollable inside the same panel. Do not enlarge the panel. Flag what you did.
- The skins shown follow the Element that is currently equipped (the red-bordered card). Changing the equipped Element keeps the existing behaviour.
- The choice persists with the loadout and applies on the next cast, including mid-match. Tap targets must work at phone size.
- Do not change the hotbar ability icons. (FLAG: whether icons should take the skin is a later question.)

## Integration and rules

- Reuse the existing systems (VFXLibrary `emitter()`, `SpellshotSettings`, callouts, the broadcast). Build no parallel path.
- **Budget:** a skin must add **zero new emitters and zero new parts** compared with Default. It only changes colours. Say what the cost is if it is not zero.
- Respect Reduce Flashing, Graphics Quality and Reduce Enemy VFX exactly as Default does. Rainbow must never flicker.
- **Colourblind-Safe:** identity comes from shape (sun, hollow ring) and the gold-white core, not from stripe colour. Confirm with the toggle on.
- No pay-to-win: a skin changes colour only. Confirm it changes no gameplay value and no hit-feedback timing.

## Checkpoints (stop and post, in this order)

1. **Colour-band sheet:** the six bands on a flat panel and on a beam, at the size they render on screen. Approval before any ability.
2. **One ability first:** the Light Lance (the channel beam) in Default and Rainbow side by side, at on-screen size, first person and third person. Approval before the rest of Radiant.
3. **Whole Radiant kit:** one contact sheet, Default vs Rainbow for every Radiant ability, plus two Loadout screenshots at desktop size and one at phone width: the main view (the three layout fixes plus the SKINS button) and the SKINS view for Radiant.

## Scope reminder

Not in this pass: any Element other than Radiant getting a skin, a Mythic or animated tier, Sparks or rarity gating, a skin shop or any purchase flow, new effect shapes, retiming anything, the hotbar icons, any other menu change beyond the three layout fixes listed above, the open ❓ items (Aqua above all). Add nothing unrequested.

Flag anything ambiguous instead of deciding it. Be token efficient: one agent, no subagents, read only Radiant's ability code, the loadout code and the broadcast path, at most 5 screenshots in total, and finish with a short report: where colour lives, the approach chosen, the numbers (new emitters and parts, expected zero), the Loadout layout choice, and anything flagged.
