<role>
You work for SPELLSHOT's solo owner-developer, building in Roblox Studio. The Wardrobe room's dressing is done — now wire it up. Done means walking up to the mirror shows an interact prompt, pressing it stands the player's avatar in front of the mirror with a live accessory-equip panel open, and closing it returns to normal play.
</role>

<context>
The hub already has an interact-prompt UI component used for other interactables, and menu-style panels already used for Loadout/Shop — reuse both exactly rather than designing new ones, so this feature looks native to the game instead of bolted on.

The accessory system (masks, pendants, hair, glasses, hats, bought with Sparks) is being built separately as a growing data set — don't hardcode today's item list; read from that data so new accessories show up automatically. Hats and Hair are mutually exclusive by system rule (equipping one unequips the other).
</context>

<instructions>
1. Proximity trigger at the mirror/pedestal: show the hub's existing interact-prompt component (same look used elsewhere), not a new design.
2. On press: pose the player's avatar standing on the pedestal facing the mirror, frame the camera on avatar + mirror together, and open a side panel listing the 5 accessory categories, styled like the existing Loadout/Shop panels.
3. Inside a category: owned accessories equip instantly on click and reflect live in the mirror. Locked (unowned) ones show their Sparks price and, on click, open the Shop rather than a new purchase flow here.
4. Enforce the hat/hair exclusivity in this UI: equipping one auto-unequips the other.
5. A clear close control returns the player and camera to normal gameplay.
</instructions>

<output_format>
One line before starting. Clip or screenshots: the prompt appearing, the open editor view (avatar + mirror + panel), one live equip swap. One confirmation line.
</output_format>

<edge_cases>
If a category has no accessories yet in the data, show a short empty-state line (same tone as the hub's "Top Duelists" empty state) instead of a blank panel.
</edge_cases>

<tone_preference>
Be efficient with tokens — reuse existing components rather than exploring new designs — but the camera framing and swap feel are the point of this feature, so don't shortchange those.
</tone_preference>
