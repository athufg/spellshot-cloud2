<role>
You work for SPELLSHOT's solo owner-developer, building in Roblox Studio. The Store wing's display cases currently show invented props (a slot-machine panel, hourglass cases, apothecary potion shelves, a trophy dome, a hat-stand-style piece) that aren't real purchasable items — nothing happens if a player buys them because they don't map to anything in the game. Fix this and three other issues. Done means every display case shows a real Wrap, Accessory, or Outfit, the entrance is actually clear to walk through, Outfit cases show the full modeled look, and every case's text is readable.
</role>

<context>
SPELLSHOT has exactly four real cosmetic categories: Wraps (what Daily Deals already rotates), Accessories (masks/pendants/hair/glasses/hats), and Outfits (the full premium looks like Frostbound Sovereign). Every display case in this wing must represent one of these, pulling from the same item data the Shop UI and Daily Deals board already use — don't invent new product types or filler props to fill space.
</context>

<instructions>
1. The Stormcaller hero display still blocks the entrance walking path — move it fully clear of the walk-in lane, not just angled. Confirm by checking the player can walk straight in without colliding with or stepping around it.
2. Remove every display case showing something that isn't a real in-game item: the slot-machine panel, the hourglass cases, the potion/apothecary shelving, the trophy dome, and any other invented prop. Replace each cleared spot with a case for a real Wrap, Accessory, or Outfit instead of leaving it empty.
3. Outfit display cases specifically: make the case larger, and show the full outfit modeled on a blocky avatar figure inside it (same block-rig style already used in the Wardrobe room), not an icon or abstract prop.
4. Enlarge the name/price text on every display case across all categories so it reads clearly at normal walking distance — this has been a recurring legibility problem, fix it everywhere, not just on the Outfit cases.
</instructions>

<output_format>
One line before starting. Shot of the clear entrance path, before/after of the replaced display cases, and a close-up of one Outfit case showing the full modeled look with legible text. One confirmation line.
</output_format>

<edge_cases>
If there are more real items than display slots, pick a representative or rotating subset — never invent a new item or prop to fill a gap.
</edge_cases>

<tone_preference>
Be efficient with tokens — this is corrections to existing work, not new design exploration.
</tone_preference>
