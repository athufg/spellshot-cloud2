<role>
You work for SPELLSHOT's solo owner-developer, building in Roblox Studio. The Store wing corridor currently reads as vacant — a few strong finished pieces (the Daily Deals ruby pedestal, the braziers, the Wardrobe archway) sitting in an otherwise bare hallway, plus one prop cluster (telescope, brass orrery, star chart, book piles, wall clock) that has nothing to do with a shop. Rework the whole wing into a real storefront. Done means the astronomer clutter is gone, the wing has a hero display at its entrance and a second featured-item stage at the old clutter spot, every bare corridor stretch is dressed with display cases and category banners, and the corridor has a deliberate light/dark rhythm instead of flat lighting — all built in Blender first, matching this project's pipeline.
</role>

<context>
The wing already has pieces that work: the Daily Deals ruby pedestal (glowing gem, orbiting ring, premium particle layer), the reworked braziers, and the Wardrobe archway. Leave all three exactly as they are — this pass fills in everything around them, it doesn't redo them. The established visual language across all of it is gold trim, warm glow, and neon-yellow ceiling accent lines on a stone-and-navy base; everything new in this pass should extend that language, not introduce a new palette.

Two different kinds of new displays here, treat them differently:

**Functional (live data):** the entrance hero display and the featured-item stage replacing the clutter spot both pull from the game's actual featured-item data, the same way the Daily Deals screen already shows real current deals. If that data source is reachable for other categories (a featured Wrap, a featured Accessory), use real current data; if not, build the display to the same visual standard but note in your summary that it's currently showing a placeholder item pending real data.

**Atmospheric (static):** the smaller display cases that dress the bare corridor stretches between these anchor pieces are representative props only, not wired to live data — a case showing a Wrap-shaped or Accessory-shaped item with a price plaque is enough. Don't build backend wiring for these; the goal is visual density, not a second functional shop.

Build pipeline: model every new piece in Blender fitted to this project's established scale and material conventions, matching the pipeline already used for the Daily Deals pedestal, the braziers, and the Wardrobe room, then import into Roblox Studio.
</context>

<instructions>
1. Remove the telescope, orrery, star chart, book piles, and wall clock entirely.
2. Build a hero display at the wing's entrance: a raised, dramatically lit display showing the single most premium item currently available (pull real data if reachable), so the wing announces itself as a shop immediately rather than after a walk down bare corridor.
3. Replace the cleared clutter spot with a second featured-item stage, using the same premium pedestal language as the Daily Deals ruby (glow, a slow orbit or rotation, particle layer) but for a different featured category than Daily Deals shows, so the two stages don't duplicate each other.
4. Walk the full corridor and fill every stretch of bare floor/wall between existing set pieces with atmospheric glass display cases (varied items, not the same case repeated) and hanging category banners (ACCESSORIES / WRAPS / OUTFITS, matching the bold comic lettering style already used for "SHOP" and "WARDROBE").
5. Extend the gold-trim/warm-glow/neon-yellow-ceiling-line language to every new piece, and use lighting specifically to create rhythm down the corridor — a pool of warm light at each display, dimmer in between — rather than even lighting throughout.
</instructions>

<output_format>
One line before starting. Before/after of the former clutter spot, a shot of the new entrance hero display, and a wide shot of the dressed corridor showing the light/dark rhythm. One confirmation line noting which displays use real data versus representative props.
</output_format>

<edge_cases>
If live data isn't reachable for the hero display or the second featured stage, build them to full visual quality anyway with a placeholder item, and say so plainly rather than leaving the spot empty or skipping it.
</edge_cases>

<tone_preference>
This needs to look genuinely amazing — it's the player's first impression of the shop. Push for real craft on every new piece. Be efficient with tokens on exploration and reporting, never on the modeling or lighting quality itself.
</tone_preference>
