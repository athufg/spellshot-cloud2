<role>
You work for SPELLSHOT's solo owner-developer, building in Roblox Studio. Several Store-economy corrections need to land together: Accessories stop being sold directly, the Blood Moon Bundle needs a real info panel, the hub's showcase mannequin needs fixing and relocating, Stormcaller comes out, and the dev panel's Unlock All needs to cover everything current. Done means all five land as described below.
</role>

<context>
Accessories are no longer Robux/Sparks purchases in the Store — they come from crates, with only the current season's newest accessory kept on display. The Blood Moon Bundle (Mythic, 2 Skins + 2 Wraps, already showing 2,999 Sparks, was 5,200, from existing data) is confirmed as: the existing Umbra "Blood Moon" Wrap, an Umbra Mythic Skin that hasn't been designed yet, a new Cryo Wrap called "Void Flame" (build this one — simple reskin, same pipeline as the game's other Wraps, cold ghostly-flame palette), and a Cryo Mythic Skin called "Frostblade" that also hasn't been designed yet (a full Element Skin kit rework is its own separate project — don't attempt it here). Stormcaller's featured display isn't a confirmed real item and is being removed; the showcase mannequin from hub spawn is taking its spot in the Store. The dev panel already has an Unlock All button under Economy that currently only covers Elements.
</context>

<instructions>
1. Remove all Robux/price text from every Accessory display case. Keep each case's Inspect button, but it now only previews the item on the player's avatar in the Wardrobe — no buy button, no price shown anywhere for Accessories.
2. Build a proximity-triggered panel for the Blood Moon Bundle that animates smoothly upward above the display when a player approaches, listing all four contents: Blood Moon Wrap (Umbra, available), Umbra Mythic Skin (Coming Soon), Void Flame Wrap (Cryo, available — build this wrap now), Frostblade Skin (Cryo, Coming Soon). Don't invent content for the two Coming Soon entries — a clear "Coming Soon" state only, matching the honest empty-state tone already used elsewhere (Longest Streak, Live Duels).
3. Remove the Stormcaller featured display entirely.
4. Move the showcase mannequin from hub spawn into the Store, into the cleared Stormcaller spot. Fix its bug where an old item stays stuck visible instead of cycling out properly. Expand its rotation to pull from every Wrap currently in the game plus every Outfit, in fully random order rather than a fixed sequence.
5. Expand the dev panel's Unlock All to also cover Outfits and all Wraps, and add a way to grant every Accessory for testing, since Accessories no longer come from direct purchase.
</instructions>

<output_format>
One line before starting. Screenshots: an Accessory case with no price and working Inspect, the Blood Moon panel open showing all 4 items (2 marked Coming Soon), the relocated mannequin cycling correctly with no stuck item, confirmation Stormcaller is gone, and the expanded dev panel. One confirmation line.
</output_format>

<edge_cases>
Never invent content for the Umbra Mythic Skin or Frostblade — Coming Soon only, until each gets its own dedicated build pass.
</edge_cases>

<tone_preference>
Be very token efficient — don't spend unnecessary exploration or reporting. The Blood Moon panel and the mannequin fix are the most visible pieces here, so those two should still look genuinely amazing even with tight token use elsewhere.
</tone_preference>
