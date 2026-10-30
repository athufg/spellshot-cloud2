# SPELLSHOT — SKYLINE STYLE SPEC
### Decoded from Roblox Rivals + Marvel Rivals. Decisions, not options.

---

## 1. THE ANSWER IN ONE PARAGRAPH

The register both reference games use is **stylised-real**: continuous (not banded) shading over a *compressed* value range, no lines of any kind, simplified-but-consistently-scaled geometry, real specular highlights, and an invented, tightly curated palette. It is not "realism with the outlines off" — that is exactly what your semi-real pass produced, and it failed because deleting the inverted hulls deleted the only local contrast in the image and nothing replaced it. **The one mechanism that makes "bright everywhere" compatible with "looks solid" is this: contrast is moved off the value axis and onto the hue/temperature and saturation axes.** A shadow becomes a *hue rotation at near-constant brightness* (top face warm, side face cool-violet, underside warm-bounced — all within ~0.10 luminance of each other), distance becomes a *lightening* hue shift toward the sky rather than a darkening, and enemy readability is bought with a *saturation reserve* instead of with dark corners. Measured in the references: Rivals' Arena has no pixel below 0.52 luminance and reads as a place; Marvel's Yggdrasill Path has ground and sky at the identical 0.56/0.57 median; Digital Duel Grounds is median 0.576 with only 21.7% of pixels below 0.3 and is still a competitive arena.

**The tension you need to hear before you read on.** Your three demands are *not* in conflict with each other — bright, solid, and non-comic all coexist in Construction, Yggdrasill Path, Hall of Djalia and Digital Duel Grounds. The conflict is with **time**. Two of the three comic signals in your maps are mesh data, not settings: the inverted hulls are real geometry and the tonal bands are baked vertex colours that multiply `Part.Color`. No Lighting property removes either. The lighting profile alone will get you roughly 60% of the way and is worth doing first because it is an hour's work — but the relief pass (mullions, floor bands, cornices) is what actually *replaces* the outline, and skipping it puts you straight back in the washed-out grey result you already rejected. **Removing the hulls without adding relief and rim will read *worse* at range than the comic build.** Those two ship together or not at all.

Second, smaller tension: Skyline is monochrome blue **and** blue is its sky. Rivals' Arena and Marvel's Yggdrasill Path prove monochrome is survivable — but they survive by running the hue at 0.4–0.5 saturation, which a PvP map cannot do without competing with players (Rivals keeps map saturation under 0.15 for exactly this reason). So for Skyline the cheap route to the same result is to **take the architecture off blue and let the sky keep it.**

---

## 2. THE RULES

Every one of these is checkable from a screenshot histogram in under five minutes. The previous two failed passes both landed outside these bands in ways a measurement would have caught before render.

**Value**

1. **No large surface below 0.40 luminance. Ever.** "Large" = anything bigger than a door. Measured reference: Rivals Arena p2 = 0.52; Big Arena p2 = 0.58; Marvel's bright maps clamp the darkest 5% at 0.26–0.32.
2. **Whole-frame targets:** p5 ≥ 0.32, p25 ≥ 0.45, median 0.55–0.65, p95 ≈ 0.90, p99 ≤ 0.97. **Under 5% of pixels below 0.25.**
3. **Total on-screen value range ≈ 0.30**, clipped hard at the bottom, left open at the top. Brightness is achieved by compressing into the top half of the scale, not by adding light.
4. **The top third and bottom third of the frame must be within 0.05 of each other in median value, and the deck/walkable plane should be the brighter of the two.** Rivals' Bridge (0.758 sky over 0.502 deck) is the single map in the whole study that reads as "having dark parts," and it is the one you are currently imitating. Marvel's Digital Duel Grounds: 0.486 / 0.576 / 0.576 top-to-bottom.
5. **Key-to-fill ratio 1.6:1 to 2.2:1** (0.7–1.1 stops). Photoreal sun is 6:1–10:1 (the raking-sun attempt). Comic flat light is 1:1 (the current build). Concretely: sun-facing face 0.82–0.88, sky-facing 0.68–0.74, turned-away 0.52–0.58.
6. **Three to four committed value plateaus per material family, spaced 0.10–0.14 apart.** Arena quantises to 0.57 / 0.72 / 0.85. There is no continuous ramp and no cast shadow in the reference; form is *assigned*, not lit.

**Shadow and temperature**

7. **A turned-away face drops at most 0.10 in value and never loses saturation.** Measured: in every Marvel map, the darkest 30% of pixels carry *equal or higher* saturation than the frame mean (Sanctum 0.305 vs 0.282; Hell's Heaven 0.372 vs 0.291). Nothing desaturates toward grey as it turns away. **This single rule is the whole brief.**
8. **Within one hue family, the shadow face rotates 20–30°. Across the warm/cool divide (what Skyline will do), rotate freely but hold ΔV ≤ 0.10 and ΔS ≥ 0.** Iceberg's ice: near-white pink top → periwinkle face → violet undercut, all within 0.15 of each other.
9. **Three orientation treatments, none of them dark:** up-faces warm and +0.10 value; side faces cool-violet at near-equal value; undersides warm-bounced at −0.05. Undersides must never be the darkest thing in frame.

**Colour**

10. **Architecture saturation clamped to HSV S ≤ 0.45; map median saturation 0.18–0.25; p95 ≤ 0.50.** Reserve **S ≥ 0.60 for players, spell VFX and pickups only.** This is a linter rule on `Part.Color`, not a guideline. Rivals Arena's own p95 saturation is 0.144, which makes a team-coloured player 4–5× more saturated than anything in the map.
11. **Three to five hue families on screen at once, plus exactly one complementary accent.** No map in either study is truly monochrome; the closest (Westown) compensates with a wide value range inside its hue, which you are forbidden.
12. **The accent occupies 8–12% of screen area. Never above 15%, never below 6%.** Below 6% it reads as an accident; above 15% it becomes a second theme.
13. **Do not vary one hue by value. Use three hues ≥ 12° apart at similar values.** Four values of one blue is monochrome; three blues at three values is a palette.
14. **Saturation and value rise together, never traded.** Legacy Sandbox sits at median value 0.752 *and* median saturation 0.24. Washed-out happens when value goes up while chroma goes down — which is precisely what "+48% saturated, −24% contrast" was actually reporting.

**Dark, line and relief**

15. **Dark (< 0.30) is permitted only on thin geometry and must total ≤ 5% of screen pixels.** Trim strips, mullions, railings, antenna masts, seams, window recesses. Dark as a *region* is the only kind of dark the owner actually rejected.
16. **Zero outlines.** Measured hard-edge density in Rivals is 0.02–0.7% of adjacent pixel pairs. Outlines are simply not part of this register.
17. **Local contrast target: mean |ΔL| at 4px = 7–9 value points.** Marvel's solid-reading maps measure 7.6–9.2; the softest measures 5.0. That is a dense field of *small* edges — pilasters, cornices, panel lines, mullions — not big tonal shapes. **This number is the direct replacement for the outline and it is the acceptance test for the relief pass.**
18. **Baked AO: floor at 0.72 (never more than 28% below base), ray distance 2–6 studs.** Contact occlusion is small-area and omnidirectional; cast shadow is large-area and directional. You want the first and not the second.
19. **Roughness quantised to exactly three values across the whole map** (0.25 glass/metal, 0.55 panel, 0.85 stone). Metalness is only ever 0 or 1. A continuous roughness gradient is photoreal; a drawn white blob is cartoon; three clean plateaus with real highlights inside each is the middle.
20. **Chamfer ≥ 0.15 studs on every primary silhouette edge** so it catches a specular line. A raw 90° box edge produces a one-pixel aliasing line instead.

**Atmosphere and post**

21. **Atmosphere Density ≤ 0.28, Haze ≤ 1.8.** Set fog from the map's *longest* sightline and verify enemy contrast at that exact distance. Big Backrooms and Big Graveyard are the same art as their small versions and read worse purely because fog tax scales with sightline length. Skyline has the longest sightlines of any SPELLSHOT map.
22. **Distance goes lighter, not darker: +0.10 to +0.22 value, ×0.45 saturation, hue drifting toward the sky.** Nothing in either reference recedes into darkness. But **paint this into the part colours as three distance planes** — Roblox's Atmosphere is a single global volume and cannot do a per-distance curve.
23. **ColorCorrection Contrast capped at +0.18.** Roblox's contrast pivots on mid-grey and deepens darks symmetrically; above +0.20 you re-create the dark corners. Saturation +0.12 to +0.20. **No DepthOfField in a PvP game.**
24. **Bloom Threshold 1.6, not the 2.0 default and never below 1.2.** Only genuinely emissive things bloom; the map itself must not haze over.

---

## 3. THE PALETTE — SKYLINE

**The strategic decision: the towers come off blue entirely. Blue is demoted to three jobs — the sky, the glass bands, and the cloud sea.** Westown is as hue-limited as Skyline and works because its one hue is *not* the sky's hue; that is the difference. Doing this also buys the near/far depth ladder for free (warm and saturated near, pale and cool far) and means nothing has to go dark to read as solid.

| Role | Hex | HSV (H / S / V) | Why this value |
|---|---|---|---|
| **Tower body — main mass** | `#BEB29A` | 40° / 0.19 / 0.745 | Warm bone-sand. Sits at Legacy Sandbox's proven median value (0.752) with real chroma retained — the map that proves you can be this bright without washing out. Off-blue, so the sky stops swallowing it. |
| **Tower body — up-faces / parapet tops** | `#DED3B8` | 43° / 0.17 / 0.871 | +0.126, the Crossroads "plane ladder" step. Top face lightest, always. |
| **Tower body — turned-away faces** | `#A294B8` | 263° / 0.20 / 0.722 | Only **−0.023** in value, saturation *equal* to the lit face, rotated to cool violet. This is rule 7 made literal — the Iceberg mechanic. The face reads as turned away because it is a different temperature, not because it is dark. |
| **Tower body — mid-distance** | `#CCC3B2` | 41° / 0.13 / 0.800 | Distance plane 2: lighter, less saturated. |
| **Tower body — far** | `#D8D4CE` | 40° / 0.05 / 0.847 | Distance plane 3. Big Crossroads' far skyline is the lightest thing in frame; copy that exactly. Furthest skyline layer gets baked into the skybox at `#DEE2E8`. |
| **Tower trim** (mullions, floor bands, cornices, corner pilasters, railings, masts) | `#6E6A78` | 257° / 0.12 / 0.471 | The slate-violet that replaces the black hull. 0.27 below the body — genuinely darker, but **only ever on geometry 0.2–0.4 studs wide**, capped at 5% of screen. Cool, not neutral, so it never reads as a hole. |
| **Edge rim / parapet cap** | `#F2ECDC` | 42° / 0.09 / 0.949 | The *positive* outline. Thin Neon-ish caps on roof lines, ledge lips and parapet tops only, ~1.15× base value. Contrast added upward, never downward. |
| **Bridge deck / walkable surfaces** | `#DCD2BC` | 41° / 0.145 / 0.863 | **The brightest large surface in the map.** Central Park is a *night* map that reads bright because the ground is 0.60–0.70 while everything vertical is darker. Hell's Heaven, Digital Duel Grounds, Zombies Midtown: floor is the brightest band in all three. This single choice answers "all parts of map need to be bright" at the only place the player actually stands. |
| **Glass / window bands** | `#5E9AA0` | 185° / 0.41 / 0.627 | The architecture's cool note, deliberately **30° off the sky's hue** so it does not merge with it. Under the 0.45 architecture clamp. The one place blue-family colour is allowed on a tower. |
| **Accent / landmark** | `#C9905A` | 29° / 0.55 / 0.788 | Amber-terracotta. Ninomaru's vermilion and Construction's signal-red: one saturated, *mid-value* structural colour injects a whole hue family at zero cost in brightness. 8–12% of screen: signage boxes, banner cloth, fins, objective markers, landmark trim. Emissive variant `#FFC178` (Neon) for lamps and signage. **⚠ See §6(e) — verify against Pyro's hue before committing; fallback is gold `#D6B057` at 42°.** |
| **Sky zenith** | `#3F6FB8` | 216° / 0.66 / 0.722 | Saturated cartoon blue. Legacy Crossroads proves a pale low-contrast map does *not* read washed out under a strongly saturated sky — the sky is the anchor. It sits above the play space where nobody fights, so its chroma costs no readability. |
| **Sky horizon** | `#AFCBE4` | 208° / 0.23 / 0.894 | Pale and quiet, **lighter than every piece of architecture**, so a player at 200 studs always has a bright plane behind them. This is the Splash/Docks rule applied where it matters (behind players) while the zenith keeps the Legacy Crossroads anchor. |
| **Cloud lit** | `#F4F0E6` | 42° / 0.06 / 0.957 | Warm near-white. This is not scenery — it is the **bounce card**. Painted into the lower skybox faces it becomes the ambient arriving from below, and every tower underside and bridge soffit gets lit for free (K'un-Lun's cloud sea, Hell's Heaven's snow). |
| **Cloud shadow** | `#C8C6D6` | 247° / 0.075 / 0.839 | −0.118, rotated cool lavender. Still brighter than any tower face. |
| **Fatal drop — lower band** | `#6E93C4` | 214° / 0.44 / 0.769 | The drop reads as fatal by **hue and saturation break plus a haze ramp**, never by going dark. Onyx and Dimension both prove a hazard announces itself by out-*saturating* the map, not by out-darkening it. |

**How this set kills the monochrome problem, explicitly:** five hue families on screen (warm bone architecture / cool-violet shadow faces / teal glass / amber accent / blue sky-and-drop); three genuinely different blues (185° glass, 208° horizon, 216° zenith) instead of one blue at four brightnesses; the warm/cool divide runs *through every single object* via the orientation rule; and the largest surface (deck, 0.863) and the second largest (tower body, 0.745) are separated by 0.12 of value, so albedo does the separating that light is no longer doing.

---

## 4. THE BUILD LIST

Ordered cheapest-and-highest-impact first. **Items 0–4 are all reversible property/texture work and should be done and screenshotted before a single mesh is touched** — they will tell you how much of the problem was lighting versus mesh data, which nobody currently knows.

### ⓪ BLOCKER — `[lighting-only, code]`
The runtime forces `Brightness = 0` / `Ambient = pure white` on every map because shading is baked in. **Replace that override with a per-map lighting-profile table.** Nothing below is testable until this lands. Half an hour of Lua; it gates the entire direction.

### ① Lighting profile `[lighting-only — cheap, highest impact per minute]`
Apply to the **current comic Skyline** first and screenshot it.

```
Lighting.Technology              = Future
Lighting.GlobalShadows           = true
Lighting.Brightness              = 1.4
Lighting.Ambient                 = (108,104,124)   -- cool violet, NOT grey, NOT white
Lighting.OutdoorAmbient          = (168,160,186)   -- warm-violet, lighter than Ambient
Lighting.ColorShift_Top          = (46,36,16)      -- ADDITIVE from (0,0,0); step up cautiously
Lighting.ColorShift_Bottom       = (34,28,20)      -- warm: the cloud sea is the bounce
Lighting.EnvironmentDiffuseScale = 1               -- ⚠ CHECK: often 0 on converted places
Lighting.EnvironmentSpecularScale= 0.85
Lighting.ExposureCompensation    = 0.20
Lighting.ClockTime               = 14.2            -- sun high, behind the main sightlines
Lighting.ShadowSoftness          = 0.75

Atmosphere.Density = 0.25   Offset = 0.25   Haze = 1.5   Glare = 0.15
Atmosphere.Color   = (224,222,210)   -- WARM pale: distance must stop getting bluer
Atmosphere.Decay   = (126,136,162)

ColorCorrection.Contrast = 0.14 (hard cap 0.18)  Saturation = 0.16
ColorCorrection.Brightness = 0.02   TintColor = (255,253,250)
Bloom.Intensity = 0.65   Size = 20   Threshold = 1.6
SunRays: OFF.   DepthOfField: NONE.
```
The `Ambient` / `OutdoorAmbient` / `ColorShift` quartet is the single most under-used thing in Roblox and it *is* rule 7 — it gives you warm-lit tops, cool-violet sides and warm-bounced undersides with zero mesh work. Also verify no legacy `FogStart` / `FogEnd` are set; they fight Atmosphere.

### ② Palette module `[lighting-only — cheap]`
One locked module: 12–16 committed hexes from §3, the three distance planes, the `S ≤ 0.45` clamp as an actual assert, and a recorded list of the hues the Elements and the Sparks mark already own so no map can steal one. Every `Part.Color` in Skyline re-assigned from it. **Ten to sixteen hexes for a whole map, not forty eyedropped tints.**

### ③ Distance planes painted into part colour `[lighting-only — cheap]`
Near / mid / far tower colours from §3 assigned by actual distance band. Do not wait for Atmosphere to do this; it cannot (one global volume, no per-distance curve). This is the fix for "distant towers are the same blue as near towers."

### ④ Skybox v8 `[material — medium; pipeline already exists]`
Re-render in Blender as a **light rig, not a backdrop**: bright warm quadrant where the sun is, mid-value zenith band at `#3F6FB8`, pale horizon at `#AFCBE4`, and a **warm near-white lower band at `#F4F0E6`** — because `EnvironmentDiffuseScale = 1` makes the skybox the ambient source, that lower band *is* the light hitting every underside in the map. Bake the furthest skyline layer in at `#DEE2E8`. Upload at 2048/face (4096 gave no benefit at Windows scaling >100% anyway, per the half-res finding).

### ⑤ Mesh pass — go LITE `[geometry / re-export — expensive]`
One Blender pass, four jobs, **keeping every approved vertex position exactly where it is**:
- **Strip the inverted hulls.** Keep a light-rim subset: scale 1.015, Neon, colour ≈1.15× base and shifted cool, applied **only** to roof lines, parapet caps and ledge lips — never as a full contour. Weight must vary with orientation, or it becomes a line style and you are back to comic.
- **Rebake the vertex colours.** Hard comic bands out. In: short-ray AO (floor 0.72, ray 2–6 studs) multiplied with a face-orientation tint — up +0.10 value warmed, sides interpolated toward violet, down −0.05 warmed. Vertex colours multiply `Part.Color`, so keep them near 1.0. *You already own this pipeline; you are changing what it bakes, not building a tool.*
- **Delete the halftone decals.**
- **Chamfer 0.15–0.25 studs** on primary silhouette edges.

### ⑥ Relief pass `[geometry / re-export — expensive, and NOT optional]`
Mullion grids, spandrel panels, floor-slab bands, corner pilasters, vertical fins, ribbed service cores, bridge truss members — at the low-amplitude high-frequency scale of Docks' container corrugation. **Acceptance test: mean |ΔL| at 4px = 7–9.** This is what replaces the outline. Ship it in the same release as ⑤ or the map reads worse at range than the comic build does.

### ⑦ SurfaceAppearance / material pass `[material — medium]`
Roughness quantised to 0.25 / 0.55 / 0.85. Metalness only 0 or 1. NormalMap at 0.3–0.5 strength as the single permitted level of surface detail. `Reflectance = 0.03` on architecture, `0.12` on glass — the broad travelling sky specular is what makes a flat-lit plane read solid (the Chess and Celestial Husk lesson). Keep big surfaces `SmoothPlastic`; Roblox's Concrete/Slate/Brick grain eats 10–15% of a compressed value range and pulls chroma toward grey. Desaturate the lowest-roughness surfaces ~10% or their speculars punch white holes.

### ⑧ Post tuning `[lighting-only]` — last, and it can only finish the job. If post is doing more than ~10% of the result, something upstream is wrong.

### ⑨ Readability verification `[free]`
Enemy at 20 / 80 / 200 studs against the three most common backdrops, confirming separation in **both** value and saturation at each range. Plus the standing check: drop a plain white sphere and a mid-grey cube into the live profile and screenshot them. The sphere shows the terminator (soft and hue-shifting = right; banded = cartoon; broad and dark = photoreal). The cube shows the real key-to-fill on three faces at once.

---

## 5. WHAT TO COPY FROM WHICH MAP

| SPELLSHOT's problem | Map that solved it | What it did |
|---|---|---|
| Parts of the map go dark | **Rivals: Arena** | p2 value 0.52 — no pixel below half. Value range compressed to 0.29 in the *top* of the scale. Brightness by authored albedo, not by added light. |
| Bright sky over a dark deck | **Marvel: Central Park** / **Hydra: Hell's Heaven** | The floor is the brightest surface in the map. Central Park is a *night* map that reads bright for this reason alone. Hell's Heaven measures 0.412 / 0.306 / 0.439 top-to-bottom. |
| Shadows make it dark | **Marvel: Hall of Djalia** / **Rivals: Iceberg** | Zero cast shadow as a form-giver. Warm up-faces vs cool-violet down-faces at near-constant value. Djalia has no black in frame at all and still reads 3D. |
| Removing outlines left it empty | **Marvel: Yggdrasill Path** / **Rivals: Docks** | Form from high-frequency trim, not tonal masses: local contrast 7.6–9.2 per 4px. Docks does it with container corrugation and panel lines — micro-relief that self-shades under flat light. |
| Monochrome blue | **Rivals: Westown** | As hue-limited as Skyline and works — because its one hue is *not* the sky's hue, and it keeps one complementary escape. The lesson: blue is the wrong monochrome to pick when blue is also your sky. |
| Distant towers = near towers | **Rivals: Big Crossroads** / **Marvel: Birnin T'Challa** | Distance goes **lighter and desaturated toward the sky**, never darker. Far towers read 20–25 value points *brighter* than near ones. |
| Pale map looks washed out | **Rivals: Legacy Crossroads** | A pale low-contrast map under a *strongly saturated* cartoon sky is not washed out. The sky is the anchor. |
| Enemies must stay readable | **Rivals: Construction** / **Marvel: any bright map** | Pale near-neutral field (median sat 0.064), all chroma spent on small props. Players own the loudest colour in frame by 4–5×. |
| Fatal drop without a black void | **Rivals: Onyx** / **Marvel: K'un-Lun** | Hazard announces itself by out-saturating the map, and the bright floor/cloud sea lights every underside from below. Big Onyx got *brighter* when scaled up, while fog-lit Big Backrooms got worse — same studio, same operation, opposite result. |
| "Bright but not cute" | **Marvel: Krakoa vs Jeffland** | Nearly identical brightness and saturation; one is cute and one is not. The separators: angular asymmetric silhouettes, visible surface grain, and a preserved ~45-point value spread. You may go as bright as you like if you hold all three. |

---

## 6. DISAGREEMENTS AND GAPS

**(a) Brightness 0 vs Brightness ~2. The agents split and it matters most.** Agent 1 (numeric measurement of Rivals) concluded the flat-light rig "does not need to change much" — keep Brightness 0 / Ambient white and author everything into albedo. Six other agents said Brightness must be ~1.2–2.6. **Verdict: non-zero, 1.4.** Agent 1 inferred "no directional light exists" from a flat measured image, but a flat image is equally the signature of a *soft key with a very high ambient floor*, which is what Rivals actually runs. More decisively: at Brightness 0 the engine gives you zero face-orientation information, so every plane cue must be hand-baked forever, and you lose `ColorShift_Top`/`ColorShift_Bottom` — the two properties that deliver rule 7 for free. Agent 1's *positive* recommendation (author three plateaus into part colour) is correct and is in the spec; its lighting conclusion is not.

**(b) "Monochrome is fine" vs "get off blue."** Agents 1, 3 and 5 measured that monochrome works (Arena is 100% one 30° bin; Yggdrasill Path is 85%; Backrooms is one ochre). Agents 2 and 6 said move the towers off blue. **Verdict: off blue, for Skyline specifically.** Monochrome survives on three conditions — the hue spans ~60°, saturation sits near 0.4–0.5, and there is a real value ladder. Condition two is unavailable to you: a PvP map at 0.45 saturation competes with player silhouettes, which is why Rivals' own maps sit at 0.06–0.12. Yggdrasill Path gets away with it at 0.21 because Marvel puts a team-colour outline in the UI layer. Moving the architecture to warm bone reaches the same destination without spending the saturation budget, and it fixes the distance ladder at the same time.

**(c) Bright cloud sea vs dark drop.** Iceberg's fatal sea is *darker and more saturated* than the play surface, which makes the play space read luminous. K'un-Lun and Hellfire Bay use a *bright* cloud/sand floor as a bounce card. **Verdict: bright.** Two reasons: the drop sits directly below the play space, so a dark version puts a large dark region exactly where players look down — banned by rule 15 — and a bright cloud floor is the only free source of underside fill, which is precisely where your current build goes dark. Legibility of the drop is bought back with the saturated cold band `#6E93C4` and a haze ramp (rule: hazards out-saturate, they don't out-darken).

**(d) "Make the sky the quietest surface" vs "a saturated sky is the anchor."** Direct contradiction between the Splash/Docks agent and the Legacy Crossroads agent. **Verdict: both, split by altitude.** Saturated zenith (`#3F6FB8`, S 0.66) above the play space where nobody fights; pale quiet horizon (`#AFCBE4`, S 0.23) behind players at range. You get the anchor and the silhouette plane at once.

**(e) The accent hue is the one real open risk.** Every agent converged on "one warm complementary accent at 8–12%," and amber/vermilion is the obvious pairing against a blue sky. **But Pyro already owns saturated orange-red.** A map accent that collides with an ability colour is a competitive bug, not a taste question. My accent is deliberately pulled to S 0.55 / V 0.79 (muted terracotta, well below the S ≥ 0.60 character band), which should separate — **but check it against the live Element logo palette before the mesh pass, and if Pyro's orange sits within ~15° of 29°, switch to gold `#D6B057` (42°).**

**(f) Atmosphere Density.** Proposals ranged 0.25 to 0.40 (Roblox's own default is ~0.395). **Verdict: 0.25, Haze 1.5, and paint the rest.** Big Backrooms and Big Graveyard are the proof that fog tax scales with sightline length, and Skyline has the longest sightlines of any SPELLSHOT map. Marvel gets its far-tower fade from a per-distance fog curve Roblox does not expose, so relying on Atmosphere for the depth ladder will dissolve your mid-ground exactly as the earlier haze pass did.

**(g) Method reliability, where the sources conflict on absolute darkness.** Agent 1 measured real pixels from the wiki media store; Agent 2 measured promo *icons*, several of which are cinematic renders with vignette and bloom. Where they disagree on how dark a map is, trust Agent 1. Agent 2's own honest caveat — "do not cite Museum as the brightness model even though it sounded like the obvious one" — is the right call and Museum is excluded here.

**(h) Gaps that do not change anything.** The "unsure" rows cluster in Legacy variants (Legacy Docks/Splash), Rivals' Obby/Spleef/Boss Arena, and Marvel's Times Square / Lower Manhattan / Alchemax / Avengers Tower / Thebes / Museum of Contemplation. None is load-bearing: every rule above is supported by at least three independently measured maps. The one genuinely interesting unseen pair is **Legacy Docks vs current Docks** — a controlled before/after of exactly the change you are about to make (same palette, more surface relief). Worth twenty minutes of someone's time *after* the pilot, not before.

**(i) Two engine facts to verify on Cool VFX before trusting this spec.** `EnvironmentDiffuseScale` and `EnvironmentSpecularScale` default to 1 in new places but are frequently **0** on places converted from legacy lighting — at 0, the entire sky-as-light approach silently does nothing and item ④ is wasted work. And `ColorShift_Top`/`ColorShift_Bottom` are **additive** tints from a `(0,0,0)` default, not multipliers; the values in ① are deliberately conservative — step one channel at a time and watch a white sphere rather than trusting the number.

**(j) Finally, re-measure correctly next time.** "+48% saturation, −24% contrast" was reporting *"the pure blacks are gone"*, not *"the image got flatter"* — removing the hulls removed the only black in the frame, and global contrast metrics are dominated by that. After the rebuild, measure **hue delta and saturation delta between adjacent surfaces**, plus the nine histogram targets in rules 2/4/10/17, or the metric will keep pointing the wrong way.