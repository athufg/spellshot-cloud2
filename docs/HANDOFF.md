# SPELLSHOT — Project Handoff Summary

This document exists to bring a new agent/session up to speed with zero prior context. Read this fully before acting on any individual prompt file below — several early documents were later corrected or fully superseded, and this summary flags exactly which ones.

---

## 1. What SPELLSHOT is

A Roblox PvP shooter: RIVALS' precise, mobile-first, ranked duel structure, with elemental spellcasting kits instead of guns. Targets mobile/tablet as well as PC. Art direction is pop-art comic (flat saturated color blocks, Ben-Day halftone dots, jagged impact bursts, bold outlined lettering) — RIVALS-adjacent, not realistic.

**`SPELLSHOT_Design_Manual.md` (attached with this handoff) is the single source of truth** for every mechanic, kit, currency, and system. Nothing in this summary overrides it — if this summary and the manual ever disagree, trust the manual, and flag the discrepancy.

---

## 2. Core design, in brief

- **Kit structure per Element:** M1 (left-click basic attack, tied to Element) + Primary Ability (a battle ability slot, tied to Element) + Passive (tied to Element) — these three are a bundle, unlocked together. Plus up to 3 freely-mixed Techniques (1 Mobility, 1 Defense, 1 Ultimate) drawn from shared pools of 8 each, sourced one from each of the 8 Elements. This hybrid system exists specifically so post-launch content can ship as cheap standalone Techniques instead of requiring a full new Element every time.
- **8 launch Elements:** Pyro, Cryo, Voltaic, Terra, Zephyr, Umbra, Radiant, Toxin. Full ability tables are in Manual Section 2.
- **Monetization:** cosmetic/roster-access only, never stat power. Currencies: Mana Shards (in-match), Sparks (soft/persistent), Prisms (hard/Robux).
- **Visual identity (Manual Section 16):** pop-art comic formula, locked HUD layout (health/mana stacked bottom-left, ability row bottom-right — Primary/Mobility/Defense small + Ultimate large, Passive smaller above), per-Element color table.

---

## 3. Narrative history (condensed)

The project started as a broader Roblox market-research exercise (top games analyzed, patterns extracted), which produced this specific concept as the strongest idea. From there: full design manual written → reworked into the hybrid Element/Technique system (to solve "running out of content" concerns) → fully reworked again into the M1-vs-Primary split with every ability redesigned for mechanical uniqueness (the original draft had multiple near-identical "wall" abilities; the live version has exactly one wall in the whole game, Terra's Bulwark Wall, on purpose).

Once the design stabilized, work shifted to actually building it: VFX reshading toward a cartoony style, first-person conversion, HUD design (explored in Claude Design, then finalized in Blender via Opus 5/Claude Code), Cryo's kit finalized as the first fully-built Element, and a long iterative loop fixing the first-person viewmodel, HUD layout bugs, and movement (sprint/crouch/slide).

---

## 4. CRITICAL — corrections and superseded guidance

**Read this section before trusting any individual file's recommendations.**

- **`Opus5_FirstPerson_Architecture_Slide_Fix.md`'s core recommendation is WRONG and superseded.** It proposed a "camera-at-head, hide only the head, reuse the real body" architecture as more robust than a dedicated viewmodel. This was reversed after checking real RIVALS footage: RIVALS shows *no lower body at all* in first-person, only two dedicated arms. The correct, current guidance is in **`Opus5_TrueViewmodel_Independent_Animations.md`**: build a true dedicated viewmodel, and give first-person and third-person **completely separate, independently-authored animation sets** — they should not mirror or sync from one shared source.
- **Glacial Spikes and Diamond Skin (Cryo's original, pre-redesign abilities) are retired.** They are not part of the current kit and should not be referenced or rebuilt.
- **"Absolute Zero" as a name/asset moved slots.** It was originally an Ultimate. It's now Cryo's **Primary Ability**, renamed "Flash Freeze" (same ground-zone root-then-shatter effect, reused wholesale, just relabeled). Cryo's current Ultimate is a new ability called **"Cryo Beam"** (float up, charge, fire a beam) — built from what was originally just a placeholder icon.
- **The black border around the HUD is intentional design, not a bug.** An earlier round briefly treated it as something to investigate/possibly remove; that was corrected — the only real issue was that it wasn't stretching to fill the screen properly (a scaling/anchoring bug), not the border's existence.
- **The first-person viewmodel was reported as "no animation" in one round, then corrected** to "does animate, but very subtly, and only on the disconnected arm props themselves — not synced to real state." The fix needed was the same either way (see the architecture correction above), but don't assume zero animation work exists if you're auditing what's there.
- **Two ability-icon polish items were considered and explicitly deferred, not approved:** a wrist cuff detail and a hand/glove shape were part of a 7-item brainstorm; only bold outline, rounded taper, and 2–3 tone shading were approved. Don't add the deferred items without checking first.

---

## 5. Complete file inventory

### Design source of truth
- **`SPELLSHOT_Design_Manual.md`** — the living design doc. Attached with this handoff. Authoritative on every mechanic, kit, currency, and system.

### Claude Design briefs (2D template/style exploration only — never final assets)
- `ClaudeDesign_PopArt_Comic_Templates_Brief.md` — the original pop-art comic formula brief (solid blocks, halftone, jagged bursts, bold lettering), written from the user's own detailed spec after three other style directions were rejected. Produced the approved HUD kit PDF.
- `ClaudeDesign_Status_HUD_Reactions_Brief.md` — the ~19-item trigger/location/treatment system for status and buff HUD feedback (burning, chilled, shielded, poisoned, speed lines, stealth, marked-for-death, etc.). Produced `SPELLSHOT_Status_Reactions_standalone.html`.
- `ClaudeDesign_Cryo_Comical_Kit_Brief.md` — comical redesign concepts for all 6 Cryo pieces including M1. **Result was reported as looking bad** despite following the brief — see the Section 6 lessons below before reusing this pattern for other Elements.

### Opus 5 / Claude Code + Blender MCP build prompts, in chronological order
1. `Opus5_Handoff_VFX_FirstPerson_Animations.md` — reshade original Cryo VFX toward cartoony/toon, convert to first-person, add 2 ability animations, investigate sound feasibility, raised the (then-unconfirmed) avatar-body question.
2. `Opus5_Handoff_UI_HUD_and_Logos.md` — build the in-match HUD from a hand-drawn sketch, add the "status tag above own health bar" mechanic, produce the 8 Element logos.
3. `Opus5_Handoff_Cryo_Movement_HUD_Polish.md` — confirmed uniform avatar body (RIVALS screenshot), finalized Cryo's kit (Flash Freeze/Frost Slide/Chill Aura/Cryo Beam), redo logos in Blender, Blender-first VFX mandate, added sprint/crouch/slide, comical HUD bar redesign request.
4. `Opus5_Backup_Full_Workspace.md` — exhaustive backup checklist (Blender sources, exports, Roblox project files, asset-ID manifest, verification-by-count), written after a prior backup silently captured only a few files.
5. `Opus5_Blender_Finalize_HUD_and_Effects.md` — take the approved Claude Design PDF kit as layout/formula reference only (explicitly not a final asset to copy) and rebuild everything in Blender; fire and shield effects flagged as the weakest part of the reference.
6. `Opus5_BlenderMCP_Switch_HUD_Fix_DevPanel.md` — switch from third-party to **official** Blender MCP first; then fix specific HUD bugs (extra M1 icon, broken name tags, redundant icon labels, placeholder-looking bar texture, remove Shield 25 badge, reduce screen density); replace the always-visible dev overlay with a `;`-key dev/test panel covering every Element, Technique, and status effect.
7. `Opus5_HealthManaElement_Precision_Rebuild.md` — scoped to just the health bar/mana bar/Element-level tag, with a real reference image, a mandatory silhouette-before-shading checkpoint process, and an open question about whether Blender is even the right tool for flat 2D bars. **This one worked — confirmed good by the user.**
8. `Opus5_Screenfill_Arms_Sprint_Slide_Fix.md` — fix the HUD not stretching to fill the screen (border is intentional, only the scaling was broken — see Section 4), investigate the mystery viewmodel shape, rescale it, add a sprint animation, fix slide's speed curve.
9. `Opus5_FirstPerson_Architecture_Slide_Fix.md` — **superseded, see Section 4.** Proposed camera-at-head architecture (wrong), added third-person slide animation, removed the default Roblox health bar, direct Round-counter position fix.
10. `Opus5_TrueViewmodel_Independent_Animations.md` — **current correct guidance**, supersedes #9. True dedicated viewmodel (no lower body, matching RIVALS), plain arms as a flagged assumption (not confirmed icy-gauntlet intent), RIVALS-matched scale, independent first-/third-person animation sets.
11. `Opus5_Viewmodel_ComicPolish_Thinner.md` — add bold outline + rounded taper + 2–3 tone shading to the (now-correctly-scaled) plain arms; make them thinner (not just spaced further apart), matched to a real RIVALS proportion reference.
12. `Opus5_FirstPersonSlide_SlideJump.md` — build a first-person slide animation (reference clip was requested but never actually attached — get one before building if still missing), explicit "sliding only, no separate crouch animation" scope limit, add a slide-jump momentum tech (validated as matching RIVALS' own documented "slide jump" technique).
13. `Opus5_IcicleShard_ThrowAnimation.md` — repulsor-style (Iron Man palm-thrust) M1 throw animation for Icicle Shard, explicitly using a placeholder blue/ice rod built directly in Studio rather than a designed asset, so the pass stays focused on animation quality only.

### Reference images/assets bundled with the prompts above
- `reference_glacial_spikes_current.png`, `reference_absolute_zero_current.png` — original (retired) Cryo VFX screenshots that started the whole art-direction conversation.
- `hud_layout_reference_sketch.png` — the hand-drawn HUD layout mockup.
- `rivals_uniform_avatar_reference.png` — RIVALS shooting-range screenshot confirming the uniform locked avatar body.
- `SPELLSHOT_Pop-Art_HUD_Kit_v2.pdf` — the approved Claude Design HUD kit (layout/formula reference only, not final render quality).
- `SPELLSHOT_Status_Reactions_standalone.html` — Claude Design's status-reaction system output.
- `health_mana_element_reference.png` — cropped reference used for the single-component precision rebuild.
- `rivals_dualpistol_thin_arms_reference.png` — RIVALS dual-pistol screenshot used for viewmodel arm proportion/thinness.
- Two SVGs built directly in this chat as comparison visuals, not sent to Opus or Claude Design: `spellshot_pyro_style_directions.svg` (4 character art directions), `spellshot_comic_style_directions.svg` (3 comic style directions, all ultimately rejected in favor of the user's own written pop-art formula).

---

## 6. Established process rules — hard-won, don't relitigate

- **Real reference images beat adjectives, every time.** Every round that used a real screenshot landed close to right on the first or second try. Every round that relied on refining word choices ("more jagged," "chunkier") took multiple failed passes. Get a real reference before writing a prompt whenever one can exist.
- **Scope small. One component at a time.** Whole-kit-at-once requests (e.g., all 6 Cryo pieces redesigned together) made it hard to tell what specifically was wrong. The single-component health/mana/tag rebuild, with a real reference and a checkpoint, is the pattern that actually worked — repeat it rather than the whole-kit pattern.
- **Require a checkpoint before final output on stylized/visual work.** Silhouette/shape first, confirmed correct, before color/shading/outline. Skipping straight to a finished render is what produced multiple bad results that had to be redone.
- **Having Blender access is not the same as producing good results with it.** Procedural generation from a text brief tends to produce technically-compliant-but-generic results, especially for stylized/cartoon work, which has less room to hide bad shape language than realism does. Consider explicitly whether a given asset even needs Blender — flat 2D HUD elements were arguably better served by native Roblox UI, and asking that question directly improved the outcome.
- **Claude Design is for 2D template/style exploration. Opus 5 + Blender MCP is for final in-game builds.** Never treat a Claude Design output as a final asset — every build prompt that referenced one said so explicitly ("reference, don't reproduce").
- **This project has a recurring pattern of unrequested additions creeping in** (an extra M1 icon, a Shield 25 badge, presumably others not yet caught). Stick strictly to what's asked; don't add embellishments without flagging them first.
- **When a fix might cascade to fix something else, verify it — don't assume.** The Round counter's position was assumed to resolve once the screen-fill bug was fixed. It didn't, and needed its own direct fix next round. Prefer explicit fixes over assumed side effects when the assumption hasn't been tested yet.

---

## 7. Open / unresolved items

- **Sound effects feasibility was never confirmed one way or the other.** The very first Opus 5 prompt asked for an honest assessment of what's achievable; no follow-up ever reported back on this.
- **Whether flat 2D HUD elements should be native Roblox UI or Blender-rendered was never fully settled** — it was raised as an open question in `Opus5_HealthManaElement_Precision_Rebuild.md` and the health/mana result came back good, but which approach was actually used was never explicitly confirmed back to the user.
- **No real mobile/tablet device testing has happened.** A full discussion of why Studio testing isn't representative (server+client running on one machine, no thermal throttling, Roblox's automatic quality scaling masking real performance) is in this chat's history but not written into any file — worth creating a dedicated note if a new agent picks up performance work.
- **The official Blender MCP switch (requested in `Opus5_BlenderMCP_Switch_HUD_Fix_DevPanel.md`) was never explicitly confirmed complete** in this chat.
- **The RIVALS lobby ("The Hub") was researched in depth** (four zones: Duels, Weapons/Elements, Market, Shooting Range; NPCs; practice dummies; a hidden secret area; leaderboards) with concrete adaptation ideas for SPELLSHOT, but **no build prompt has been written for the Hub/lobby yet** — this is a natural next task.
- **Only Cryo has gone through the full kit-finalization + VFX pass.** The other 7 Elements (Pyro, Voltaic, Terra, Zephyr, Umbra, Radiant, Toxin) are fully specified in the manual but have not been individually taken through the same VFX/animation build process.
- **Of the 7 comic-polish ideas brainstormed for the viewmodel arms, only 3 were approved** (outline, taper, shading) — a wrist cuff and hand/glove shape were deferred, not rejected, and may be worth revisiting once the base arms are confirmed good.
- **The first-person slide animation prompt (`Opus5_FirstPersonSlide_SlideJump.md`) was sent without its intended reference clip actually attached** — confirm whether one was ever provided before assuming that animation was built against real footage.

---

## 8. Current confirmed state, as of the last screenshots reviewed

- Health bar, mana bar, and Element/Level tag: **confirmed good**, comic-styled, matches approved reference.
- HUD structural layout (screen-fill, ability row contents, name tags): fixes have been prompted; latest screenshots showed the Round counter and full-screen stretch still needing direct verification.
- First-person viewmodel: architecture corrected to a true dedicated viewmodel with plain arms (assumption, not fully confirmed against original intent); scale and shape corrected; comic polish (outline/taper/shading) and thinning requested but not yet confirmed back by the user as complete.
- Movement: sprint/crouch/slide implemented; slide-jump and a proper first-person slide animation requested most recently, not yet confirmed.
- Cryo kit: fully specified in the manual (M1 Icicle Shard, Primary Flash Freeze, Passive Cold Momentum, Mobility Frost Slide, Defense Chill Aura, Ultimate Cryo Beam); individual ability VFX are a mix of "confirmed good" (none fully confirmed yet, actually — Icicle Shard's animation is the most recent in-progress item) and "needs rework."

---

**Attached with this handoff: the current `SPELLSHOT_Design_Manual.md` in full.**
