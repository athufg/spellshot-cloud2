# SPELLSHOT — Build Prompt #[N]: Voltaic lightning rework — every move uses the reference look

Continuation of the Opus 5 / Claude Code build sequence (previous: the Voltaic Cascade and Railspike passes; keep [N] as a placeholder).
Visual/VFX work, one shared lightning look applied to every Voltaic move. **Quality bar: amazing.** At 40 studs, on a phone, in one second, a player must read "that is electricity, and it is Voltaic". **Be very token efficient** (last section).
No mechanic changes: damage, range, timing, hitboxes and hit validation do not change. Only how the lightning looks.

## Reference (attached, read it first)

- `D:\Spellshot - Atharv\SPELLSHOT\voltaic_lightning_reference.mp4` (a Roblox Studio recording, 21 s, one chain strike repeated 8 times) and `voltaic_lightning_reference_sheet.png` (the same strike at 10 fps plus a 3x close-up). **Read the sheet; open the video only if the sheet is not enough.**
- What the reference shows, measured from the sheet (calibrate your numbers from it, do not build from these adjectives alone):
  1. **Bolt:** a wide soft yellow glow band around a thin bright core (glow about 4x the core width). Big angular Z-kinks (spacing about 8–12% of the link length, sideways amplitude about 4–7%) with short side sprigs, about one per three kinks. **2–3 braided strands per link**, not one clean line.
  2. **Ground-hugging chain:** bolts run close to the ground from victim to victim, and a **dark ink trace** (thin near-black jagged ribbon) sits under every kink, like a comic shadow line.
  3. **Impact:** a **spiky radial starburst** of yellow around each victim (long and short thin spikes, alternating), plus taller **spike crowns** on the ground where a bolt lands.
  4. **Motion:** the whole chain appears at once and holds about 1 s. The route stays the same but jitters about 10 times per second (crackle). The finish is short arcs wrapping the body for about 0.3 s and then a faint grey wisp.
  5. The victims flash an X-ray skeleton (thick black outline, white bones, two poses flipping). **The developer's decision: the skeleton flash stays on Cascade (already built) and also goes on Chain Bolt hits, and on no other move.** See the Chain Bolt skeleton item below.

## Current state (from the repo notes and the file list, NOT read from code: confirm in code)

Voltaic's built pieces and their files in `D:\Spellshot - Atharv\SPELLSHOT\roblox\`: **Chain Bolt** (`ChainBoltFX.lua`, `ChainBoltShapes.lua`), **Overcharge** (`OverchargeFX.lua`), **Railspike** (`RailspikeFX.lua`, braided strands, about 220–530 Beams per shot), **Cascade** (`CascadeFX.lua`, the storm and its volt() bolt spec), **Ground Surge** (`VoltaicFX.lua`), **Volt Orb** (`VoltOrbFX.lua`), with the shared helpers in `VoltaicKit.lua`, call sites in `VoltaicClient.lua`, numbers in `VoltaicTuning.lua`, and a test harness `VoltaicTestHarness.client.lua`. Notes are in `vfx_blocking\voltaic\VOLTAIC_IN_STUDIO.md`. Today's lightning is Beams with a `#FFF573` core, `#F5C70F` glow, brightness variation and per-frame re-routing. These files are large (40–220 KB): **grep for the bolt-building code (the `volt(` spec and Beam creation) and read only that and its call sites**, never whole files. If a piece does not match what is written above, say so in one line and work from the code.

## Design direction

- **One shared bolt builder.** Put the reference look in a single function in `VoltaicKit.lua` (extend the existing `volt()` spec if it is already shared) and make every piece call it with parameters (link length, strand count, intensity, owner). A piece's own code changes only where it builds its bolts. If one piece builds its own lightning separately, point it at the shared builder.
- **Palette (shipped):** core `#FFF573`, glow `#F5C70F`, ink trace `#080E1A`. Keep Railspike's existing cooling toward violet `#4A1A8C` at the very end of a bolt's life, and no more violet than that. No magenta. Voltaic and Radiant are both yellow, so shape separates them: Voltaic is zigzags, spikes and angles, never rays or hollow rings.
- **Bursts:** reuse the existing impact burst art in `PopArtAssets` and the angular `Shard` sprite, tinted yellow, before drawing or uploading anything new. Bursts are hard-edged. Soft glow stays a small support under the core.
- **Per move (look only, same beats and timing as today):** Chain Bolt: braided, ground-hugging link to the second target, starburst on both. Overcharge: dash streak and primed tendrils get the glow-plus-core-plus-ink treatment, and the chained shot to the extra targets is a full braided chain. Railspike: strands use the new kink shape and ink trace, pierce flashes use the starburst. Ground Surge: the eruption crowns the ground with spike crowns and the zaps are braided bolts. Cascade: only its bolts and impacts change, **the cloud, hitpause, camera shake, light and skeleton flash stay exactly as they are**. Volt Orb: its arcs and impacts use the same builder.
- **Chain Bolt skeleton flash (new, confirmed by the developer, build it):** reuse Cascade's existing skeleton-and-burst overlay (do not rebuild it) on each Chain Bolt victim, including the second chained target and any extra targets an Overcharge-primed shot reaches. Chain Bolt is the M1 and fires often, so use the **short fan-style version**: about 0.12–0.15 s, no hitpause, no camera shake, no freeze, and it must never hide the target's body or crosshair line. It is on by default for everyone. Keep one tuning constant (for example `VoltaicTuning.ChainBoltSkeleton`) so its look can be tuned later, and report where it is. It respects Reduce Flashing (shorter and dimmer) and Reduce Enemy VFX. Cascade's own flash and timing are unchanged. Overcharge, Railspike, Ground Surge and Volt Orb get no skeleton.
- **Colourblind-Safe:** identity comes from the zigzag-and-spike shape. Confirm with the toggle on.

## Integration and budgets

- Create emitters and Beams the way the kit does today, honouring Graphics Quality, Reduce Enemy VFX and Reduce Flashing (the 10 Hz crackle drops to about 4 Hz and the glow dims under Reduce Flashing). Camera Shake and Status Intensity stay as they are.
- **No more Beams than today for any piece.** The ink trace and the braid cost Beams, so pay for them by removing glow layers you no longer need. Report each piece's Beam count before and after, and what you cut. It must hold on a low-end phone with several chains on screen.
- The caster's own bolts must not blind first person: thin near the camera, and use `VFXLibrary.RegisterProximityFade` for the caster's own near segments only.
- **A visual may jitter around a hit but never lie about it:** endpoints sit exactly on the validated hit points; kinks stay within a small corridor around the true line.
- Visuals stay client-side replays of the existing broadcast. Add no remote and no server-side visual objects.
- Cosmetic only. Do not touch damage, range, cooldowns, hit validation or hit-feedback timing.

## Checkpoints (stop and post, in this order)

1. **Match the reference:** recreate the reference scene in the harness (four dummies, a chain between them, same camera angle) with the new shared bolt and impact, as ONE image: the reference frame beside yours at 10 fps (6 frames), plus a 3x close-up. Approval before any piece changes.
2. **All six moves in one contact sheet** (Chain Bolt shown with its new skeleton flash on both targets): Chain Bolt, Overcharge, Railspike, Ground Surge, Cascade (bolts only), Volt Orb, third person at game distance, plus one first-person frame for Chain Bolt and one for Railspike. Include the Beam count table (before and after).

## Polish ideas (PROPOSALS ONLY, do not build until the developer says yes)

1. A short yellow shock bubble shell around each victim (the reference shows thin round rim shells on some victims).
2. Thunder-crack flash on the chain's first link (subject to Reduce Flashing).

## Scope reminder

Not in this pass: any gameplay or timing change, Cascade's cloud, hitpause, camera shake, light and skeleton flash (unchanged), a skeleton flash on any move other than Chain Bolt, new abilities, other Elements, the skin and wrap catalog, the arms (bare skin), sound, new uploads unless nothing existing fits. Flag anything ambiguous in one line instead of deciding, and add nothing unrequested.

## Efficiency (the developer asked for this to be very token efficient)

One agent, no subagents. Read the reference sheet, `VoltaicKit.lua`'s bolt code, and only the bolt-building lines and call sites of each piece (grep first, then read ranges). Do not read whole FX files and do not re-read a file after you edit it. Make targeted edits, not rewrites. Use the existing harness for testing. At most 4 images in total (checkpoint 1, checkpoint 2, and at most two extras). One line before your first tool call and no narration between steps. Finish with a short report: where the shared builder lives, the Beam counts before and after, what you cut to pay for them, and anything flagged.
