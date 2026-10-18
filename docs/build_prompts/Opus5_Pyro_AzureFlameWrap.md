# SPELLSHOT — Build Prompt #[N]: Pyro "Azure Flame" wrap + a new wrap logo in the Loadout

Continuation of the Opus 5 / Claude Code build sequence (previous: the Terra Obsidian Magma wrap prompt; keep [N] as a placeholder).
**Vocabulary (the developer's):** a **wrap** is a recolour and re-material of an ability's existing shapes. A **skin** is a full rework and is not part of this pass. Pyro's shapes, timings and behaviour do not change, and nothing here touches damage, burn, range, cooldowns or hitboxes. Colour only, and only when the player equips it. The developer has approved the name **Azure Flame** and the look below.

## Current state (from notes and the developer, NOT from code — read the code before trusting this)

- **Pyro's shipped colours:** Base `#F25C0D`, Light `#FFC74D`, Dark `#6B1708`. Logo: a flame drop. Shape grammar: teardrop flame-lick silhouettes at rest, jagged spike-bursts on impact. The **Burning** status is a flame crest whose shape is fixed and only its accent colour changes per Element.
- **Pyro abilities in the notes:** Fireball (M1, slow arcing lob with splash), Immolate (Primary, the next 3 M1s carry bonus burn), Ember Refund (Passive), plus Techniques such as Ember Trail and Detonate. **Enumerate what is actually built and has a visual from the code and use the real names.** Do not invent or build anything. A numeric-only ability gets no change.
- **The wrap system already exists** from the Radiant Rainbow pass and was extended by the Terra pass (a catalog, a `Resolve(element, ability, id)` lookup, one chosen id per ability stored with the loadout and validated by the server through an `OwnsSkin`-style stub that returns true, the id on the existing broadcast, and a WRAPS button and view inside the Loadout panel). **Check first. If it exists, extend it with data only. If it does not exist, stop and tell the user to run the Radiant prompt first. Do not build a second system.**
- **Loadout today:** the WRAPS card sits in the Element grid beside AQUA and carries a small flat **six-stripe rainbow mark** as its icon. That mark is Radiant's wrap colour and now reads as "rainbow only", which is wrong for a button that serves every Element.

## Reference before styling

No reference image was supplied. In words: a flat comic gas-flame in blue, a deep azure edge, a light-blue body, a pale inner band and a white-hot core, with yellow-orange sparks flying off it. Do not build from adjectives. First post a **swatch sheet** (below) for approval before it goes on any ability. Flat pop-art comic style, hard colour bands, ink outline, no smooth gradients on the flame.

## Design direction — Azure Flame (all values are PROPOSALS, flag them)

**Flame body (the existing toon-band method, remapped):** outer shell **Azure** `#1E5BD8` (takes the role of Pyro's Dark), body **Sky** `#4DB8FF` (takes the role of Base), inner band **Pale** `#BFEBFF` (takes the role of Light), core **White** `#FFFFFF`. Ink outline `#080E1A` stays on outlined meshes. The white core is the brightest thing in the effect.
- **One glowing element only:** the core. If Default already has a light on an ability, recolour it to Sky `#7FD0FF` at the same intensity. Add no new lights, no halo, no inner-glow wash, no bloom blowout.
- **Intensity link:** wherever Default scales intensity (Fireball size or charge, Immolate stacks, Detonate), the wrap uses the same signal. Low intensity shows more Azure, high intensity shows more Pale and White. Static per step, never a flicker or pulse.
- **Particles and trails:** keep Default's emitters and counts. Recolour flame particles with hard-stepped `ColorSequence` keypoints (Azure, Sky, Pale), no smooth blends. Smoke and embers stay as they are in shape.

**Identity anchor (PROPOSAL, flag it).** Azure Flame must not read as Cryo (`#40B5F0`, `#DEF7FF`), and a blue-heavy effect must not read as the cyan team colour. So:
1. **Shape stays Pyro's.** Keep the teardrop flame-licks and the jagged spike-bursts exactly. Never use prisms, crystal shards, or any translucency on the flame. Opaque flat meshes only.
2. **Warm accent stays.** The **hit-flash and the small ember flecks stay in Pyro's own Light `#FFC74D`** (like Terra keeps its tan hit-flash). Blue flame throwing yellow-orange sparks reads as fire, never as ice.
3. **Hue.** The outer shell leans royal azure, not cyan. Do not use `#00FFFF`-like values anywhere.

**Not in the wrap:** the Burning status crest (shape and accent colour unchanged), the viewmodel arms (bare skin, always), the third-person Element uniform colours, the hotbar icons, and any magenta or hot pink (`#E91E8C` is the Sparks mark).

## Build

1. **Wrap data only.** Add a `Pyro / AzureFlame` entry to the catalog for each built Pyro ability with a visual: the palette above plus whatever the band resolver needs. Pyro effect code gets only the same single lookup used for Radiant and Terra. `Default` must render exactly as today.
2. **Where colour lives (find out first):** if Pyro's meshes have baked vertex-colour tone bands, `MeshPart.Color` multiplies the baked orange, so a blue tint goes muddy. Reuse whichever approach the Radiant and Terra passes chose (neutral-grey bake tinted per wrap, a second baked set, or non-mesh parts). Report which in one line. Keep the white `SmoothPlastic`, opaque, `DoubleSided = false` rule for outlined meshes. Never make an outlined mesh transparent.
3. **Others see it.** The caster's wrap id rides on the existing broadcast and every client resolves it. No server-side visual objects.
4. **Loadout rows.** Azure Flame appears as a selectable wrap on each built Pyro ability row in the existing WRAPS view, with `< >` stepping Default and Azure Flame. Everything is unlocked for now (the stub returns true). Borrowed Techniques keep their origin colour; only offer a wrap on an ability that belongs to the caster's own Element.
5. **New wrap logo (requested by the developer).** Replace the rainbow six-stripe mark on the WRAPS card with a new mark that is not Radiant-specific.
   - **PROPOSAL (flag the choice you make):** the WRAPS card icon follows the **equipped Element**. Add one small `WrapIcon` entry per Element in the catalog, so Pyro shows a flat azure flame-drop mark (Azure body, Sky inner, White core, ink outline, the same flame-drop silhouette as Pyro's logo), Radiant keeps its rainbow mark, and every Element with no wraps yet shows one neutral generic mark (a flat cream-and-ink paintbrush or palette mark, no colour band). If a per-Element icon is more work than it should be, fall back to one new neutral mark for everyone and say so.
   - Same size, border and position as today; flat, comic style, ink outline, no gradients, no magenta. It stays inside the card. Keep the label "WRAPS" and everything else on the card unchanged.

## Integration and rules

- **Budget:** zero new emitters and zero new parts compared with Default. Colour only. State the cost if it is not zero. It must hold on low-end mobile.
- Respect Reduce Flashing, Graphics Quality and Reduce Enemy VFX exactly as Default does. No flicker.
- **Colourblind-Safe:** identity comes from the flame shape and the warm flecks, not from the blue. Check with the toggle on and report in one line what happens to the wrap colours (FLAG, do not decide: whether the wrap should defer to the toggle).
- Cosmetic only: no gameplay value, no burn or hit-feedback timing changes.

## Checkpoints (stop and post, in this order)

1. **Swatch sheet:** the four flame bands on a flat panel, the warm flecks beside them, and one Fireball in Azure Flame next to a Cryo Icicle Shard at on-screen size, to prove they do not read alike. Approval before any ability.
2. **One ability first:** Fireball in Default and Azure Flame side by side at on-screen size, first and third person, including the splash impact.
3. **The rest:** every other built Pyro ability, Default vs wrap, one contact sheet, plus one Loadout screenshot of the WRAPS card with the new logo (Pyro equipped) and one of the WRAPS view for Pyro.

## Scope

Not in this pass: any other Element or any other Pyro wrap, a Mythic or animated tier, Sparks or rarity gating, a shop, new shapes, retiming, the Burning crest, hotbar icons, the uniform, other menu changes beyond the WRAPS logo, and the open ❓ items (Aqua above all). Add nothing unrequested.

## Efficiency (the developer asked for this to be very token efficient)

One agent, no subagents. Read only Pyro's ability code, the wrap catalog, the broadcast path and the Loadout WRAPS card, and nothing else. No re-reading files you just edited and no extra verification loops beyond the checkpoints. At most **4 screenshots in total**, each one combining several views where you can. Do not narrate; post only at the checkpoints. Flag anything ambiguous in one line instead of deciding it. Finish with a short report: where colour lives, the approach used, the cost numbers, which logo approach you picked, and anything flagged.
