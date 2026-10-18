<role>
You are the UI builder for SPELLSHOT, a Roblox PvP elemental-duel game, working for its solo developer. Task: give the Radiant "Devil" skin a matching HUD look. The skin's world assets (staff, Halo wings, Blessing, Benediction and so on) are already reworked in Blender, but the HUD art still looks angelic. Change it from angel to demon as a LIGHT reskin, not a redesign. Done means: the Devil HUD has the same elements, sizes, layout, animations and effect intensity as today, only demonic in look, and the developer has approved a before/after sheet.
</role>

<context>
What exists today (see the attached screenshots): the hotbar has four icon tiles with a key tab above each. F is a shield with a four-point star, Q is two circular arrows, E is a staff with signal arcs, and R is an angel with a halo and wings carrying the READY! tag (the Ultimate). Above the hotbar is a passive pill reading OVERFLOW LIGHT with a yellow dot. The Blessed status has a health-bar look: a gold bar with a heart badge, a BLESSED! burst banner, a small shield badge and spiked end caps. Confirm in code which ability each icon stands for, and say so in one line if it differs.

Skin vocabulary: a skin reworks the look only. The Default look must stay exactly as it is. The art style is flat saturated fills with thick ink outlines. Magenta #E91E8C is reserved for Sparks. Teams read red and cyan in this game, and the Colourblind-Safe toggle swaps Element colours, so shape carries identity: horns, bat wings and barbs must read in a flat silhouette.
</context>

<instructions>
1. Find the code first with grep, then read only those ranges: IconAssets, PopArtAssets, BarFX (the blessed_a/f/t looks), StatusReactions, the hotbar and passive-pill code, and how SkinCatalog.lua resolves a skin id. Say in one line how the icons are made (uploaded images, or UI shapes).

2. Reskin lightly. Keep each icon's silhouette idea, tile, outline weight, key tab, READY and cooldown states, layout, sizes, animations and timings. Change only the art:
   - R (Ultimate): the halo becomes small horns or a broken thorned crown, and the feathered wings become bat wings. The figure and pose stay. The READY! tag stays.
   - F (shield): add two small horns on top, and make the star a barbed four-point star.
   - Q (arrows): the arrowheads become barbed devil-tail tips. The circular motion stays.
   - E (staff): the head becomes a small trident head. The signal arcs stay.
   - Passive pill: the yellow dot becomes a small crimson ember dot with tiny thorns. Keep the text OVERFLOW LIGHT as is, and flag in one line if you think it should be renamed.
   - Blessed look: the heart badge gets small horns, the BLESSED! burst and the end spikes become barbed, and the bar fill changes colour as described below. Burst size, pulse and timing stay.

3. Colour: red and black only for the art (black iron #1A1416, #2E2326, #4D3A3C; crimson #7A0C14, #C8141C, hot edge #FF4A3A). Keep the white icon tiles and the existing text colours so the HUD stays readable and matches the other skins. Flag this: this replaces the gold with crimson and black, as you decided for the skin. Because the normal health bar is red with white stripes, the Blessed bar must NOT be plain red or it can be mistaken for it. Make its fill black iron with crimson diagonal stripes and a crimson edge, and show it next to the normal health bar in the checkpoint sheet.

4. Same effect intensity: keep every tween, pulse size, duration, glow strength and flash exactly as they are, neither brighter nor dimmer. Reduce Flashing, Graphics Quality and the Colourblind-Safe toggle behave as they do now.

5. Wiring: add the Devil HUD set as data under the Devil skin's existing id, through the same SkinCatalog Resolve path the staff and wraps use, so the Default HUD is untouched unless Devil is equipped. Do not build a skin selector or touch the Loadout menu. If there is currently no way to equip Devil, make it testable through the dev panel or the harness and say in one line how to switch it.

6. Assets: prefer no new uploads. If the current icons are uploaded images and you cannot upload from here, build the Devil icons from UI shapes (Frame, UICorner, UIStroke, rotated squares) or list exactly which images need uploading. Do not guess asset ids.

7. Checkpoint (stop and post one image, wait for approval before wiring): Default and Devil side by side for R (ready and on cooldown), F, Q, E, the passive pill, and the Blessed bar at full and at half next to the normal health bar, plus the BLESSED! burst. Also include a flat black silhouette strip of the four icons at their real on-screen size, to show the horns and wings read. After approval, wire it and post one in-game screenshot with the Devil HUD showing.
</instructions>

<scope>
Do not change layout, text, sizes, timings, mechanics, the world assets, ability VFX, sound, other Elements, the skin catalog's price, tier or name, or the Loadout menu. Flag anything ambiguous in one line instead of deciding it, and add nothing unrequested.
</scope>

<efficiency>
Be very token efficient. One agent, no subagents. Grep first and read ranges, not whole files, and do not re-read a file after editing it. Make small targeted edits, not rewrites. At most two images in total (the checkpoint sheet and the final screenshot). One line before your first tool call and no narration between steps. Finish with a short report: what changed per element, where the Devil HUD data lives, how to equip it for testing, and anything flagged.
</efficiency>
