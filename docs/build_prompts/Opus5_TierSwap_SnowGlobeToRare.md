<role>
You are doing a small registry cleanup for SPELLSHOT, a Roblox PvP elemental-duel FPS, for the solo developer. Cryo's Frost Lotus and Snow Globe skins are swapping tiers: Frost Lotus becomes the Epic skin and Snow Globe takes Lotus's old Rare slot. You are done when both skins carry the new rarity, Snow Globe no longer swaps in HUD icons, and you have reported what else is keyed to rarity.
</role>

<token_budget>
Be efficient with tokens. One agent, no subagents. Use targeted searches (Lotus, SnowGlobe, Rarity, Epic, Icon) and read only the functions you need, never whole files or the whole repo. No images. Keep progress notes to a line and the final report to a few lines.
</token_budget>

<context>
The tier ladder is Uncommon, Rare, Epic, Mythic (no Common). Rare adds richer animated particles. Epic = everything Rare has plus HUD ability icons plus a health-bar accent. A teammate is doing the health-bar accent, so do not touch it or anything that implements it.

Today Snow Globe is registered as Epic and swaps the HUD ability icons (the F, Q, E and R slots) when equipped. Frost Lotus is registered as Rare. `CryoFX.lua` is at Luau's 200 top-level-locals limit: add no new top-level locals.
</context>

<instructions>
1. Find where skin rarity is defined (the registry or data table, and anything the shop or loadout reads for badges or sorting). Set Frost Lotus to Epic and Snow Globe to Rare, in the one place the data lives.
2. Remove Snow Globe's HUD icon mapping, so that with Snow Globe equipped the HUD shows the Default Cryo icons in all four slots. Leave the icon PNG files and their asset ids exactly as they are. Do not delete them, because the developer keeps the sources. Name their paths or ids in your report.
3. Find everything else gated by rarity or by these two skin ids (the HUD icon swap logic, the health-bar accent hook, shop ordering, any VFX tier flag). Do not edit the health-bar accent or add anything new. Report where each is keyed, and whether it flips automatically with the rarity value or needs a separate change because it is keyed to a skin id.
4. In Studio, equip each of the two skins once in the loadout and confirm that Snow Globe shows as Rare with Default icons, Frost Lotus shows as Epic, and there are no errors.
</instructions>

<scope>
Only the rarity values and the Snow Globe icon mapping. Do not change any visuals, prices, other skins, wraps, or Frost Lotus's HUD icons (a separate prompt makes those). Make routine judgment calls yourself and list them. Check in only if the rarity data is spread across several places that disagree.
</scope>

<output_format>
Final report in a few lines: files changed, the Snow Globe icon paths or ids you left in place, and the list of rarity-gated things from step 3.
</output_format>
