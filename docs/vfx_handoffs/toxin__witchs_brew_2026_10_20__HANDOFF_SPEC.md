# Witch's Brew — Toxin Epic skin (HANDOFF_SPEC, checkpoint 1)

**Status:** built in Studio, at checkpoint (2026-10-20). It is NOT in `SkinCatalog.ElementSkins.Toxin`: the line is staged and commented out, as Pixel Potion's was before approval.
**Tier:** Epic (`SkinCatalog.Skins.WitchsBrew`: `Rarity = "Epic"`, `Rework = true`, no palette or wrap). It was promoted from the Rare plan, and Scorpion takes Rare.
**Modules:** `ReplicatedStorage.IceMagic.WitchsBrewKit` (forms) and `WitchsBrewFX` (pieces and particles), wired into ToxinFX through a single `BREW` table (one new top-level local). `ToxinClient` loads ToxinFX 3 s after start, so the worn cauldron is on from spawn.
**Clip:** `witchs_brew_checkpoint.mp4` (52 s, 1280 wide, game view only). **Stills:** `checkpoint_sheet.png`.

## Asset family (several related objects, each with size or variant tiers)

| Piece | Forms |
|---|---|
| Cauldron | Lathed iron pot: one EditableMesh, 486 triangles, built once per client, untinted. Has a Neon brew surface, 3 feet, 2 lugs, a ladle and a PointLight. Tiers: **Back** (worn, 1.15 studs) and **Flight** (the Ultimate's, 1.5x). Variant **Husk**: the same mesh, faded and emptied (Slate, grey, T 0.35, no brew or glow). |
| Glob | Neon core inside a see-through brew skin. Tiers: **M1** (with 2 trailing drips), **Arc** (Acid Rain's fountain) and **Drop** (one Neon part, used for the rain and the siphon droplet). |
| Satchel | Cloth pouch, tie and 3 Neon herb sprigs. Tiers: **Rim** (clipped to the cauldron) and **Face** (tied over mouth and nose for the Vent). |
| Straps | Two shoulder straps, worn with the cauldron. |
| Tether / siphon | Beams with a Neon core (LightInfluence 0, LightEmission 1) and steam. |

## Per ability (all six covered, none Default)

| Slot | Witch's Brew | Organic sequencing |
|---|---|---|
| M1 Toxic Bubbles | The brew wells out of the cauldron. Droplets cascade from the mouth to the launch point, and the glob replaces the sac. At rest it bubbles; a pop or convert splashes. | SPOUT and CASCADE |
| Primary Corrosive Cloud | A steam tether unspools from the cauldron to the landed splash while the cloud swells. It then holds the cloud to its source and fades with it. | UNFURL |
| Passive Symbiosis | Each tick a siphon line draws a droplet from the thread's end over the shoulder into the brew. The brew answers with a glow ripple. | DRIP-FEED |
| Ultimate Patient Zero | The full cauldron leaves the back (a husk stays strapped on), arcs to the target and locks on above it with a glowing lock line. It stirs itself faster and faster (0.4 to 4 turns/s, with bubbles, steam and motes rising; it shakes in the last 20%). Then it heaves and spews (the Default cloud) and flies home refilled, replacing the husk. The Default wreath's shapes are hidden; their emitters run. | LAUNCH, LOCK, STIR, ERUPT, HOMECOMING |
| Antitoxin Vent | The herb satchel leaves the rim (hidden there) and swings onto the face; its herbs glow and smoke while it works. It goes back on the rim at the end. Same welds, timings and G keys as the Default mask. | PULL AND TIE |
| Acid Rain | The cauldron tips back 55°, a fountain of 12 brew globs arcs over into the cloud, and the rain falls as glowing brew drops. | TIP AND POUR |

## Luminous core (self-lit, not an edge line)

| Piece | Core |
|---|---|
| Cauldron | Neon brew surface plus PointLight (range 5, breathing at 0.5 Hz, pulsing on siphon ticks and the refill) |
| Glob | Neon core |
| Drops | Neon |
| Tether / siphon | Beam cores (LightInfluence 0, LightEmission 1) |
| Satchel | Neon herbs |
| Flight cauldron | Brightens with the stir: light 0.6 to 2.2, 3 at eruption |

## Particles

- **BASE layer:** steam, bubbles and splash; scales with `EffectDensity`, halved for enemies under Thin Enemy VFX.
- **GLINT layer:** sparkle glints and glitter motes. It has its own switch: the `IceMagic` attribute `WitchsBrewSparkles` (absent or true is on). Halved under Reduce Flashing.
- `WitchsBrewFX.Stats` counts both; they are published as `IceMagicFX.WB_StatBase` and `WB_StatGlint`.

## HUD (mapped; art TODO, the owner uploads)

- `SkinCatalog.Hud.WitchsBrew = { Element = "Toxin" }`, with no Bar.
- `IconAssets.Ability.Skins.WitchsBrew = { Primary = { Toxin = "" }, Technique = { AntitoxinVent = "", AcidRain = "" }, Ultimate = { PatientZero = "" } }`. `""` keeps the Default icon until the art exists.
- Key names were confirmed from VFXLibrary, SpellshotConfig and IconAssets: `ToxicBubbles`, `CorrosiveCloud`, `Symbiosis`, `AntitoxinVent`, `AcidRain`, `PatientZero`.
- The preview was checked: `HudSkinPreview_Toxin = "WitchsBrew"` makes `SkinCatalog.HudSkin(p, "Toxin")` return `"WitchsBrew"`.

## Measured in Play (2026-10-20, Training Ground)

The Default emitters and lights are untouched in every slot.

| Test | Default emitters | Default lights | Default parts | WB parts | WB base particles | WB glints | glint / base |
|---|---|---|---|---|---|---|---|
| Idle, worn cauldron only (10 s) | 0 | 0 | 0 | 0 | 39 | 4 | 10% |
| M1 + Corrosive Cloud | 16 | 3 | 64 | 35 | 88 | 38 | 43% |
| Symbiosis ×3 | 0 | 0 | 0 | 9 | 52 | 15 | 29% |
| Patient Zero | 47 | 4 | 181 | 12 | 160 | 35 | 22% |
| Antitoxin Vent | 0 | 2 | 11 (satchel mask replaces the 14-part mask) | 2 | 41 | 10 | 24% |
| Acid Rain | 15 | 1 | 602 | 194 | 55 | 19 | 35% |

- **Glints overall:** 117 over 396 base, so **+30%** across the five casting slots.
- **Persistent cost per wearer:** 20 parts, 3 emitters and 1 light (the worn cauldron).
- **Mesh:** one fixed EditableMesh per client (486 tris). The temporary resizable mesh is destroyed. The build is marked MeshBudget Essential with a retry.
- **Pixel Potion, for comparison:** 9 fixed meshes. Parts per cast: Cloud 186, PZ 398, Acid Rain 904 (Default 604).
- **Memory:** the place-wide GraphicsMeshParts read 29.6–29.8 MB. That figure includes everything in the place, so I could not split out this skin's share.

## Flags for the owner

- **Palette (open):** olive-only, or purple brew-smoke accents. A Studio preview exists: IceMagic attribute `WitchsBrewPalette = "Purple"` tints the steam #7E4EA0.
- **No Toxin Rare yet:** Scorpion is unbuilt, so the "richer than the Rare at 30%" check cannot be run.
- **Acid Rain is a shared-pool Technique:** skinned only when the caster's Element is Toxin (Pixel Potion's rule). Today `TechniquesOwnElementOnly = true`, so only Toxin can hold it anyway.
- **Readability:** the locked-on cauldron hovers 2.6 studs over the target's torso and can cover their overhead health bar from some angles.
- **Herb sprigs:** they read a bit like glowing arrows; leaves would read better.
- **Vent swing:** it is the Default's 0.24 s drop-on tween, so the swing from the rim is very quick.
- **First-person hide:** the worn cauldron is hidden in its wearer's first-person view. This is in the code but was not checked by screenshot.
- **ToxinClient was touched:** it now loads ToxinFX 3 s after start (the worn cauldron needs it before any Toxin cast).

## Not in this build (Mythic-only or out of scope)

- No kill effect.
- No aura, full-body glow or bar accent.
- No avatar change beyond the one flagged exception, the worn backpack. The Vent satchel takes the Default mask's own slot.

## Round 2 (2026-10-20, owner feedback on checkpoint 1)

The owner set the Ultimate's flying cauldron as the presence bar for every other piece.

1. **Vent: the satchel, rebuilt.** It is a cloth bag with a darker flap, a brass clasp, a drawstring tie and soft corners. Leafy herbs poke out of one corner: two crooked stems with leaves at odd angles, their leaves faintly self-lit. The old Neon "sprigs", which read as a glyph, are gone.
   - It hangs from under the cauldron's rim with its flap facing out.
   - On the Vent it swings off the rim, up over the shoulder (0.22 s), then ties over mouth and nose (0.26 s). It grows from rim size to face size during that swing.
   - At the end it drops as the Default mask does. The rim satchel reappears only once the dropped one has gone, so two never show at once.
2. **Corrosive Cloud: the tether made bold, and the cloud now bubbles.**
   - The tether has a Neon core (0.16–0.3 studs wide), a glow halo and a thick steam band. Beads of brew run along it from cauldron to cloud every 0.32 s.
   - Inside the cloud, big glossy brew bubbles (1.2–2.4 studs, up to 10 at a time) well up off the floor, swell and wobble as they float up through it, then pop in a splash and glint. A stream of glowing bubble motes rises through the whole cloud.
3. **The cauldron reads at rest.**
   - **Rim:** a separate lathed rim mesh in light iron (#808670).
   - **Brew:** a glowing Neon dome that fills the mouth up to the rim's top, visible from any side, with its light raised to 0.8–1.05 (breathing).
   - **Drips:** three glowing runs of brew down the outside.
   - **Size:** worn 15% bigger (1.32 studs).
   - **Husk:** it now has an inner floor.
4. **Symbiosis: the siphon, rebuilt.** It used to run from the caster's own chest to their own backpack, a loop on their own body, which is why it could not be seen.
   - It now runs from the poisoned target up and over into the caster's cauldron: a Neon line (0.12–0.16 studs) with a glow halo.
   - It appears with the first tick and stays while the ticks come, ending 2.5 s after the last. There is one line per target.
   - Each tick, a drop of brew (0.3 × 0.4 studs) is drawn off the target, runs the line in 0.55 s, and the brew answers with a glow ripple.

**Code review (round 2):** 5 real issues found and fixed before the final push: the rim satchel faced into the pot, the husk had no floor, the satchel jumped in size, the cloud bubbles froze if the pack vanished, and two satchels showed at the Vent's end.

**Meshes:** two fixed EditableMeshes per client (body and rim), 558 triangles in total.

**Stills:** `checkpoint_sheet_round2.png` (captured before the five review fixes).

**Clip:** `witchs_brew_checkpoint_v2.mp4`, 50 s at 30 fps, 1600 wide, all six slots, with the review fixes in. It was filmed at 0.4x speed (ToxinFX's own time scale, the camera and the Vent swing all on one film clock), recorded with rec3 and sped up 2.5x, so nearly every frame is unique. The camera eases between shots.

**Size (owner, 2026-10-20):** the worn cauldron is 50% bigger: scale 1.725, 1.98 studs tall and 2.1 wide, belly just clear of the back. The Ultimate's flying cauldron matches it (was 1.5) so the same pot leaves the back. The rim satchel scales with it.

## Round 3 (2026-10-20, owner feedback)

1. **Acid Rain is reworked around bubbles; no cloud.**
   - The cauldron tips back 30° and BOILS OVER: its surface seethes with bubbles, steam pours off and it shudders.
   - It flings real bubbles (`WB.Bubble`, 1.1–1.9 studs): a translucent brew-tinted skin, a faint glowing heart and two shine highlights on the camera side. They arc out over the zone and POP on the ground in a splash, a growing Neon fizz ring and glints.
   - Each bubble is scheduled by when it lands, inside the Default rain's own radius and window (first drop at gather × 0.8, last at gather + rainTime) on ToxinFX's backdated clock. About 14 a second, scaled by Graphics Quality.
   - The Default cloud still runs unseen for timing and cleanup: its parts get LocalTransparencyModifier 1, its emitters are off, and the hold puff and teardrop rain are skipped. If the pack vanishes mid-cast, the bubbles carry on from the cauldron's last position.
2. **The cauldron has idle life.**
   - A thin steam wisp curls off it constantly: a narrow column whose drift wanders on two slow periods.
   - Lazy bubbles swell and pop on the brew surface: up to 3 at a time, each 0.5–1 s. While boiling over it's up to 7, and faster.
   - None of the pack's particles show in the wearer's own first-person view.
3. **M1 and the Primary cloud brought to the Ultimate's level.**
   - **M1 glob:** its own PointLight (range 7, a glowing heart that lights what it passes), three dark swirls of brew turning inside it (mottled), and a wet shine highlight. It trails glitter motes (14/s, the glint layer) and brew droplets in flight, with lazy motes at rest. The Default sac's diffuse glow, smoke and light are switched off.
   - **Cloud:** a glowing Neon heart low in the cloud with a breathing light (range 1.3 R). Every lobe has a Neon core and two dark brew mottles turning inside it, so it reads as brew, not a recoloured haze. Glitter motes rise through it (10/s), on top of the round-2 bubbles and tether.
4. **Confirmed live in Play.**
   - **Vent:** the satchel is worn over mouth and nose during a real cast, 0.72 studs in front of the face and 0.2 below the head's centre, with the tie round the head.
   - **HUD:** `SkinCatalog.Hud.WitchsBrew = { Element = "Toxin" }` and `IconAssets.Ability.Skins.WitchsBrew = { Primary.Toxin, Technique.AntitoxinVent, Technique.AcidRain, Ultimate.PatientZero }`, all `""` (art TODO). `HudSkinPreview_Toxin = "WitchsBrew"` makes `HudSkin` return `WitchsBrew`.

**Code review (round 3):** 5 real issues found and fixed:
- The steam wisp drifted into the wearer's own first-person view.
- Surface bubbles stayed hidden after the camera left first person.
- The cloud's new heart and cores were left behind on an early exit.
- Acid Rain bubbles landed late against the damage ticks.
- The bubbles stopped if the pack vanished mid-cast.

**Clip:** `witchs_brew_checkpoint_v3.mp4`, 50 s at 30 fps, smooth, all six slots.

**Particle counts were not re-measured this round.** The new glint sources are M1 motes and cloud motes; the base layer adds the wisp, surface bubbles and the bubble pops.

## Round 4 (2026-10-20, owner feedback: "one designed witch kit")

**Owner rulings (asked):** the whole kit is purple, with a black iron cauldron. The Vent is a witch hat with a veil (the satchel is dropped).

1. **Palette.**
   - The brew and steam colours are the kit's own. `FX.Init` no longer copies ToxinFX's green Look.
   - `WB.WrapPalette` repaints the Default gas the kit still draws (cloud lobes, the Vent's cleanse, Acid Rain's hidden cloud) through `ToxinWrap` as the composite id `#WitchsBrew`. It applies to a player wearing WitchsBrew, or a Studio dummy with `StudioSkin = "WitchsBrew"`.
   - Brew Neon is (90,45,255), measured on screen: Neon plus the place grade (SkylineGrade, saturation +0.35) push red up. (126,70,255) showed as magenta (240,48,240), and (160,78,245) was worse. The brim and rune images use (160,118,255); the wrap's Neon/Glow Virulence was pulled bluer the same way.
2. **Shared glint shapes.**
   - Every glint emitter in the kit draws a painted 5-point star or crescent moon (they alternate), never the stock sparkle.
   - Droplets, bubbles and embers draw a soft dot.
   - The textures are painted at runtime as EditableImages (`WB.Tex`: Star, Crescent, Dot, Spiral, Rune, Ward, Ring, Ribbon). Nothing is uploaded.
3. **Rune flash on every cast.**
   - A rune circle (rings, 16 marks, 4 crescents, a 4-point star) on the floor under the caster's feet blooms in over 0.13 s, turns, and fades. It lasts 0.6 s (0.4 s and smaller for the M1) and sends up glints.
   - The ground ray leaves the caster out and starts at the root, so it never lands on the caster's head or on a roof.
4. **M1.** The glob tumbles, with a turning spiral of brew inside it (a self-lit sprite), and trails embers and star/crescent motes.
5. **Primary cloud.**
   - Rebuilt from Acid Rain's bubble language: every Default lobe becomes a glowing brew bubble at the lobe's place and size.
   - The bubbles roil (drift round the lobe, breathe) and reform: each pops every 2.5–6.5 s in a splash and glints, then swells back.
   - Glowing heart, then embers and motes drifting off the top like steam.
   - The cloud bubbles are "soft": a brew-tinted skin with little reflectance, a bigger heart, and a small faint shine. They read as a lit pot, not soap bubbles.
   - Patient Zero's erupted cloud uses the same bubbles (`Big`).
6. **Passive siphon.**
   - A shimmering ribbon (a tiling bead texture) and a violet halo run from the target's torso into the cauldron.
   - Three droplets bead on the target (swelling over 0.11 s), then run the ribbon nose-first with a soft glow and glints.
   - Each landing flares the cauldron: brew light +2.6 brightness, range ×1.4.
7. **Ultimate.** The sequence is unchanged. Embers stream off the flying cauldron's vents for the whole time it's away (out, hover, home), with a body glint layer.
8. **Vent.**
   - A witch hat (lathe brim, cone, crooked tip, violet band) hangs on the cauldron's rim at rest.
   - On cast it flies to the head, growing from rim scale to head scale over 0.48 s, with a veil and cords tied round the head.
   - A small rune glows under the brim's front edge.
   - When the hat is tied on, a ward glyph flickers in front of the face, 0.46–1.0 s after the cast.
9. **Acid Rain.** The bubbles are unchanged. About 35% carry a twinkling star sprite, and each impact opens a sparkle shimmer ring over 0.4 s instead of the flat Neon fizz.

**Verified in Play** (Training Ground; dummy caster with the Studio skin copy): every piece above. One bug was found and fixed: the rune flash sat on a dummy caster's head.

**Code review (round 4):** 5 real issues found and fixed:
- During the Vent, the rim hat's rune image and light stayed lit beside the cauldron. A SurfaceGui and a Light ignore LocalTransparencyModifier, so the pack now toggles `Enabled` with the hat.
- The worn hat's rune stayed lit in the wearer's first-person view and after the hat was knocked off. An updater now turns it off.
- At Vent end, ToxinFX's `dropMask` faded the hidden rune host in as a grey slab. The host is now Glass, which dropMask skips; the filter host is sub-pixel.
- The M1 swirl sat inside the opaque Neon core. It is now drawn in front of the core with StudsOffset Z, still inside the skin.
- ToxinWrap gave the purple palette only to a Studio dummy. It now follows the kit's On rule: a Studio `StudioSkin` body, a tester included, or a player wearing WitchsBrew.

The brim rune was also moved fully below the brim (it sat half inside it).

**After the review:**
- Embers are (176,128,255) at LightEmission 0.45. Pale lavender at full additive glow washed out against the sky and the floor.
- The Ultimate's flight trail is bigger and longer-lived.
- Siphon droplets bead just clear of the target's torso.
- The rune falls back to the feet when the ground ray misses.
- A second review of these changes confirmed no defects.

**Clip:** `witchs_brew_checkpoint_v4.mp4`, about 50 s at 30 fps, all six slots, filmed at 0.4x and played back at real speed. Raw: `witchs_brew_film4d_raw.mp4`. Superseded takes are in `_scratch/`.

## Round 5 (2026-10-20, owner feedback)

**Unchanged at the owner's request:** the purple pass, the cauldron, the bubble-cloud Corrosive Cloud and the siphon.

1. **Ultimate: clamped on, not hovering.**
   - On landing, the flying cauldron's feet are pressed into the crown of the target's head: set down on its feet (measured from the foot welds), sunk 0.06 studs, and tipped 16° toward the caster.
   - It follows the head. In Play the feet sat 0.23 studs below the top of the head, so there is no gap.
   - The beam tether is removed.
   - **Landing:** a thud (it squashes 0.16 studs down over 0.22 s and settles) and a splash of brew drops and glints from under it.
   - It still stirs faster as the fuse closes, and it rattles about the contact point near the end.
   - Three brew drips ooze down the sides and back of the head, never over the face.
   - On the target's own client in first person (camera within 2.5 studs of their head), its parts, lights and particles are hidden.
   - The eruption still heaves up off the head and flies home.
2. **Vent: the ward-herb satchel, at the kit's polish.**
   - The witch hat and the veil under it ("the collar piece") are removed, and so are `WB.Hat` and its three lathes. A new SACK lathe takes their place, so the kit builds one mesh fewer.
   - The satchel is a round-bellied cloth sack, flattened front to back, with its neck cinched by a violet drawstring.
   - A glowing brew bead sits on the knot (Neon, a soft halo and a small light that breathes while worn). Two violet cord tails hang below it, each tipped with a small glowing bead.
   - A ward rune glows on its belly (a self-lit image on an unseen Glass host, which dropMask never makes opaque).
   - Three herb sprigs with glowing leaves splay sideways out of the neck, clear of the eyes.
   - It hangs from under the cauldron's rim at rest, rune and bead facing out.
   - On cast it swings over the shoulder and is tied over mouth and nose, growing from rim size on the way. The seat is 0.3 heads below the head's centre, so the neck stops under the eyes. Violet cords tie it at the ears, not the neck.
   - While worn: herb smoke on the base layer, and star and crescent motes off the herbs and the bead on the glint layer.
   - The ward glyph still flickers in front of the bag as it is tied on, and the rune flash still shows at the feet.
   - Every glow (rune, bead light and halo, particles) is off in the wearer's first-person view and goes out when the bag is knocked off.

**Verified in Play:**
- The rim satchel shows its rune, bead and herbs.
- The worn satchel covers mouth and nose with the eyes clear, and there is no hat or veil.
- The cauldron sits on the target's head from the side and from the caster's view, all three ooze drips are drawn, and there were no errors.

**Code review (round 5):** 7 real issues found and fixed (13 findings with duplicates). Each was traced against the real R15 head, a rounded cylinder about 0.58 in radius, measured in Studio.
- **Clamp:** it still perched on one front foot. The tripod is wider than a head, so the belly floated 0.16-0.27 above the crown and the rear feet hung past the edge. It now rests on its iron BELLY, sunk 0.06 and tipped 8°, with the feet coming down round the sides of the head. Measured in Play: belly 0.059 below the crown, feet 0.24-0.37 below it at r 0.55-0.61.
- **Ooze:** the drips ran inside the head, because the path assumed a sphere. They now ride the surface: over the crown's rounded edge, then straight down the side, fading only at the end.
- **Cord tails:** they and their small glowing beads were buried in the belly. They now drape over the bulge, placed from the sack profile's own radius.
- **Bead halo:** the bulging belly clipped it. It now sits in front (camera-space offset) and grows with the bag.
- **Tie:** the side cords never reached the bag, and straight cords stood off the round head. It is now one violet band round the head at the bag's neck height, so it runs into the drawstring. It stays hidden until the bag is on the face.
- **Herbs:** they crossed both eyes when worn. They now splay out nearly sideways and tip forward, below the eyes.
- One finding was rejected: the eruption letting go of the head.

**Clip:** `witchs_brew_round5.mp4` (about 20 s): the rim satchel at rest, the Ultimate clamping on and erupting, the satchel Vent.

## Round 5b (2026-10-20, owner: "still isn't a satchel -- a round orb with spikes")

**Owner ruling:** a satchel is a soft pouch: flattened, teardrop or rectangular, with a drawstring or flap closure, worn hanging from straps or tied over the lower face. Keep the glowing crescent symbol and scrap the round base.

- **Rebuilt** as two curved grid meshes (`gridMesh`, a superellipsoid generator) replacing the round SACK lathe:
  - **Pouch:** a soft rounded box, a touch wider at the bottom where it sags, fuller low and pinched at the top like a stuffed bag.
  - **Flap:** a lighter-violet fold-over flap (100,56,150) across the top front, slightly thicker so its edge steps.
  - Both are bent gently round an upright axis (radius 1.05 bag widths), so the bag hangs in front of a face rather than wrapping it.
- **On the flap:** the glowing crescent ward (kept, as the owner asked) and a glowing brew bead as its clasp (halo and light).
- **Removed:** the herb sprigs (the "spikes"), the drawstring, the cord tails and the solid head band. The herbs are now implied by herb smoke and the star/crescent motes off the flap and bead.
- **At rest:** it hangs against the cauldron's side below the rim on a short violet strap over the lip. The strap hides with the bag during the Vent.
- **On the face:** it is 0.75 of the head's width, from just under the eyes to the chin, its curved back pressed to the face.
  - The tie is a violet cord looped round the back of the head from corner to corner, made of 12 thin segments, so if it falls it's a loose loop and never a plate.
  - The cord stays Glass and unseen until the bag is seated, so it can never pop in mid-air on an early drop. (This fixes the last review's two confirmed band defects.)
- **Mesh budget:** the kit builds four meshes (Body, Rim, Pouch, Flap), about 1,900 triangles in all.

**Code review (round 5b):**
- 1 real issue fixed: FX.Mask's grow still sized the clasp's halo with the old sack's constants, so it was 56% too big, popped at the hand-off from the rim and washed over the crescent. Both files now read `WB.HaloSize` / `WB.HaloLift`. Measured in Play: 0.32 x bag width on the face and on the rim.
- 3 findings were rejected: the flap standing off the pouch top, the crescent plane leaning off the flap, and the rim strap kinking.

## Round 6 (2026-10-20, owner: scrap the face-worn satchel; the herb goes into the brew)

**Kept unchanged:** the pouch strapped to the cauldron (owner: "that part looked good").

1. **Cast.**
   - The rune flashes at the feet, and the pouch's flap pops open about its top edge, swinging 112° with a little overshoot. The bead clasp and the crescent ride on the flap.
   - A sprig of ward herb lifts out (`WB.Herb`: a brown wood stem and five green leaf planes, SmoothPlastic, no glow, six parts, static).
2. **Toss.** The herb arcs out of the pouch into the cauldron's mouth, tumbling, over 0.45 s.
3. **Reaction.**
   - The brew flares (light, and its colour toward a brighter violet (125,105,255) — toward white it bloomed pink) and briefly boils.
   - A crescent-ring ripple crosses the brew surface, bubbles pop with glints, and a puff of vapor rises. The herb sinks out of sight.
4. **Active (the Vent's whole duration).**
   - A thin trail of ward-vapor drifts up out of the brew, over the shoulder and loosely round the head and collar: two lavender smoke Beams with puffs tiling along them, ending beside the jaw on both sides.
   - Mist breaks off the trail's middle, wisps drift round the collar, and now and then a crescent glint shows.
   - Nothing is worn on the face. It is all hidden in the wearer's own first-person view.
5. **End.** The trail fades (fast on a re-cast or clear), then the flap shuts. Everything is cleaned up, including the attachment on the brew.

**ToxinFX:**
- `H.ToxinVent` asks the skin for `Vent` and returns early, with no mask.
- The Default's cleanse threads now draw into the cauldron's brew. Their arrivals flare it, but only after the herb is in.
- `dropMask` on that record calls `FX.VentEnd`. If `Vent` fails, the Default mask draws as before.
- `FX.Mask` and `FX.VentOff` are removed. The Studio copy is `studio_sources/ToxinFX_with_WitchsBrew.lua` (push 20).

**Flag for the owner:** "the hand reaches to the pouch" would animate the caster's arm. That is an avatar-body change, reserved for Mythic in the tier table. So the flap pops open and the herb lifts out on its own. Say if you want the arm reach anyway, as a flagged exception like the worn backpack.

**Code review (round 6):** 1 real issue fixed: after a long frame hitch the herb could be tossed from the map origin. It now starts in the pouch and the toss starts from the lift point. 3 findings were rejected.

**Round 6b (owner: "increase the smoke around the face so the mouth looks covered by it"):**
- The ward-vapor now gathers into a VEIL over mouth and nose, locked to the head:
  - a dense lavender smoke core (34/s, nearly opaque at its peak, less additive so it covers rather than glows);
  - a softer haze round it (10/s);
  - a near-opaque soft mist disc (the kit's Dot image, facing the camera, gently breathing) that covers the mouth from any side.
- Both vapor trails now curve round the cheeks and pour into it.
- It fades in and out with the trail and is hidden in the wearer's own first-person view.
- Verified in Play: the mouth reads as covered by mist and the eyes stay clear.

## LIVE (2026-10-20): owner approved the round 6b checkpoint

- `SkinCatalog.ElementSkins.Toxin = { "Default", "PixelPotion", "WitchsBrew" }` is set in Studio's `ReplicatedStorage.Spellshot.SkinCatalog`. The before-copy is in `ServerStorage.SkinCatalogSuperseded_2026_10_20.before_witchsbrew_live`.
- The `Skins.WitchsBrew` comment describes the final kit. Its card `Label` was the early greens and is now the kit's purples (#1E1230, #3A1F66, #7A46E0, #D9C6FF).
- **Agreement check:**
  - Catalog: Epic, Rework = true.
  - WitchsBrewKit and WitchsBrewFX headers: EPIC.
  - This spec: Epic.
  - `Hud.WitchsBrew` and `IconAssets.Ability.Skins.WitchsBrew` are present. The icons are still "" placeholders, so the HUD shows the Default icons until the owner uploads the art.
- **Verified in Play:**
  - A player with Element = Toxin and `ElementSkin_Toxin = "WitchsBrew"` passes the catalog.
  - The live client builds the cauldron backpack on their own character in 0.5 s, with no errors.
- No stage harnesses were left in the place; every stage ran from execute_luau.
- Still open, flagged to the owner: the caster's arm reaching to the pouch (an avatar-body change, Mythic-only by the tier table).
