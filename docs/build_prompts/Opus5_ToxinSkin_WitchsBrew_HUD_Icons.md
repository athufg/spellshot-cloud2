<role>
You are designing and building Witch's Brew's four HUD ability icons — Toxin's Epic skin for SPELLSHOT, a Roblox PvP elemental-duel game — in the game's established pop-art comic icon style. You work for the game's solo owner-developer. This is the same kind of task as Hydra's icon-art build earlier in this sequence: an earlier Witch's Brew HUD task only checked/wired `SkinCatalog.Hud.WitchsBrew` / `IconAssets.Ability.Skins.WitchsBrew` with placeholder `rbxassetid://...` strings — that was correct as far as it went, but the owner wants the actual icon pictures, not just the wired table. Done means: four finished icon images built (shape-checkpointed before colour, same process as every other icon pass on this project), saved as real files, with the catalog's placeholder entries annotated to say which file each one corresponds to — the owner still uploads the final art to Roblox themselves, same standing rule as every other asset on this project.
</role>

<context>
**Reference, direct from the owner — read before designing anything.** The owner attached a fresh in-game checkpoint clip (`witchbrew.mp4`, 20s) showing the skin's actual current look. Frame-sample it yourself (`ffprobe` + `ffmpeg -vf fps=3`, same technique used throughout this build sequence) before drawing anything. What it actually shows, confirmed by frame sampling:
- The worn cauldron-backpack: a dark navy/near-black cauldron body with a **glowing violet-purple brew** inside (not olive-green — this settles the open palette flag from the original build prompt in favour of the purple-accent option), tan/pink leather shoulder straps, and a wooden ladle standing in the brew (the ladle fix from an earlier checkpoint is confirmed landed).
- Primary (Corrosive Cloud): a glowing violet steam tether arcs from the ladle/cauldron straight to the target, then blooms into a cluster of large, glossy violet bubbles ("CORRODED x2", "x4" stacking) around the target — this is the ability's actual current look and the strongest, most distinctive read for its icon.
- Passive (Symbiosis) is visible in the same clip (the thread, the glow, the "GLUG!" heal tick) but **gets no icon** — same established pattern as every other Toxin skin (only Primary, both Techniques, and Ultimate get HUD icons).
- This clip does **not** show Antitoxin Vent, Acid Rain, or the Ultimate's detach/fly/stir/erupt sequence. For those three icons, use the locked design description and any earlier checkpoint media already in this project from Witch's Brew's main build pass (the `witchsbrew.mp4` referenced earlier in this sequence, if you have access to it) rather than this clip. If you can't locate usable reference for one of them, say so explicitly and propose your best-guess icon flagged as unconfirmed, rather than inventing a design that contradicts what was actually approved.

**What this build is actually for** (confirm against the live `SkinCatalog.Hud.WitchsBrew`/`IconAssets.Ability.Skins.WitchsBrew` state — an earlier task in this sequence should have already wired the table shape with placeholder ids; don't redo that, build on it):
- Exactly four icons, same established pattern as Hydra's and every other Toxin skin: **Primary, both Technique slots, and Ultimate — never M1 or Passive.**
  - Primary → Corrosive Cloud (the ladle/steam-tether-into-violet-bubble-cluster, grounded directly in the attached clip)
  - Technique → Antitoxin Vent (the locked design: an herb plucked from the satchel on the cauldron's rim and tossed into the brew, triggering a ward-vapor trail — a woody stick-with-leaves herb, not purple-colored, per the owner's own earlier note on this ability)
  - Technique → Acid Rain (the locked design: the backpack tips back, brew arcs up and out overhead, then rains down as droplets — same splash language as the M1, inverted skyward)
  - Ultimate → Patient Zero (the locked design: the full cauldron detaches and flies to the target, stirring faster as it locks on, then erupts into the cloud; a faded husk stays strapped to the caster's back the whole time)
- These replace Default Toxin's four icons for this skin only, same selective pattern as every other HUD-skinned ability on this project.

**The pop-art HUD icon formula** (same formula used for Hydra's icons, confirmed against the shipped Default Toxin icon set and the SPELLSHOT Pop-Art HUD Kit v2): flat, saturated colour fills, no gradients or soft realistic shading; a bold black outline around the whole badge and around each internal shape; rounded-square tile format matching the existing HUD slots exactly; Ben-Day halftone used sparingly, not over the whole image; single clear subject per icon, readable at actual on-screen HUD size, not just at full zoom. Witch's Brew's established shape/material language (from its own build prompt) is the cauldron-and-brew object family — lean into that directly rather than reinventing a new motif: the ladle, the glowing violet brew surface, and the cauldron's own silhouette are this skin's version of what Hydra's heads/fangs are to that skin. No magenta. Check each icon's read with the shipped Colourblind-Safe palette swap on.

**How the finished art actually gets made.** Same standing project rule as Hydra's icon pass: "Claude Design is 2D style exploration only, never a final asset; final in-game builds go through Opus 5 + Blender MCP or native Roblox tools." The most consistent, token-efficient path is almost certainly rendering from the Witch's Brew assets that already exist (`WitchsBrewKit.lua`/`WitchsBrewFX.lua`) — pose the cauldron/ladle/steam/brew elements for each ability's composition, capture a still, then apply the flat pop-art post-process over it, the same pipeline used for Hydra's icons (check how that pass actually did it before reinventing a method). If that's impractical, say so and propose a hand-illustrated fallback instead of silently picking one.

**Icon art still isn't uploaded by you.** The owner uploads final icon images to Roblox themselves. Hand over finished icon files plus clearly annotated placeholder entries in `IconAssets.Ability.Skins.WitchsBrew` saying which file each one corresponds to.
</context>

<instructions>
1. **Confirm prior HUD-wiring state first.** Read the live `SkinCatalog.Hud.WitchsBrew`/`IconAssets.Ability.Skins.WitchsBrew` (should already be wired with placeholder ids from an earlier task) and `WitchsBrewKit.lua`/`WitchsBrewFX.lua` for the assets available to render from.
2. **Frame-sample the attached `witchbrew.mp4` clip** for Primary's real look (ladle, violet brew, steam tether, bubble cluster) before designing that icon. For Vent, Acid Rain and the Ultimate, pull from the locked design table and any earlier checkpoint media in this project — flag clearly if you can't find usable reference for any of the three.
3. **Design silhouettes first, one per ability, and checkpoint them before any colour** — same process rule as every icon pass on this project. Four simple shape studies: Primary (ladle/steam-arc into a bubble cluster), Vent (a plucked herb sprig over the cauldron rim), Acid Rain (the tipped-back cauldron with brew arcing overhead), Ultimate (the full cauldron mid-flight/stirring, accelerating-pulse glow) — each distinct from the other three at a glance.
4. **Build the four finished icons** from the approved silhouettes: flat pop-art colour fills, bold outline, rounded-square badge matching the existing HUD tile format, Ben-Day halftone sparingly, single clear subject, readable at actual on-screen HUD size.
5. **Save the four finished images as real files** (PNG, matching the existing HUD icon assets' resolution/format) in a clearly-named location for this skin.
6. **Update `IconAssets.Ability.Skins.WitchsBrew`** so each entry is annotated with exactly which saved file it corresponds to.
7. **Report back** (format below), including which reference each icon was actually grounded in (the attached clip vs. the locked design description vs. earlier checkpoint media) and the method used to render/build them.
</instructions>

<output_format>
- Progress updates: one line before frame-sampling the video, one line once the four silhouettes are ready for review.
- The four finished icon image files, at both full size and a crop/preview at actual on-screen HUD size.
- A short written report: which assets/poses each icon reuses from the live Witch's Brew build; which reference grounded each of the four (the attached clip, the locked design table, or prior checkpoint media); the render-or-illustrate method used; confirmation each reads distinctly from the other three as a silhouette and from Hydra's own icon set; a Colourblind-Safe check; the exact `IconAssets.Ability.Skins.WitchsBrew` entries with file annotations; and anything you couldn't ground in real reference (likely Vent, Acid Rain, or the Ultimate, since this clip doesn't show them) flagged rather than invented.
</output_format>

<edge_cases>
- If the live HUD tables were already wired with placeholder ids but no real art, don't rebuild the table — just add file annotations.
- If you can't find usable reference for Vent, Acid Rain, or the Ultimate beyond the locked design table's plain-English description, say exactly what you searched and propose your best-guess icon flagged as unconfirmed, rather than silently inventing a design.
- If an icon reads ambiguously against another once reduced to actual HUD size, flag it and propose a differentiation rather than shipping a pair that's hard to tell apart.
- If the purple-brew palette confirmed in this clip conflicts with anything the original build prompt left as an open flag, treat this clip as the authoritative current state and note the resolution in your report rather than re-opening the question.
</edge_cases>

<tone_preference>
Keep the report plain and concrete — what was built, from what reference, and what's still open.
</tone_preference>
