<role>
You work for SPELLSHOT's solo owner-developer, building in Roblox Studio. The first 4 Outfits (Magma Warlord, Frostbound Sovereign, War-Forged Knight, Crimson Carnival Jester) are built but stop at the neck. Build a matching head-piece for each so "Outfit" actually means head-to-toe. Done means all 4 head-pieces exist, equip into the existing Hat accessory slot, and auto-equip when their matching Outfit is worn while staying swappable like any other hat.
</role>

<context>
SPELLSHOT already has a Hat/Hair accessory slot system (Hat and Hair are mutually exclusive — one or the other). Don't create a second head-slot system for this: each Outfit head-piece is a normal Hat-slot item that happens to auto-equip when its Outfit is equipped. A player can still swap it for a different owned Hat or for Hair afterward — the Outfit doesn't lock their head choice.

Same fairness rules as the outfits themselves: no head-piece may add collision or extend the hitbox past the default rig, and no glow/particle effect on any of them may be bright or dense enough to obscure the wearer's own face/eyes readability or an opponent's view.

Pyro's identity colors: Base #F25C0D / Light #FFC74D / Dark #6B1708. Cryo isn't in that table — pull its real identity color from the game's existing element data/scripts.

Build pipeline: model each piece in Blender fitted to the rig's head attachment point, matching the pipeline already used for the Outfits and Accessories, then import as a proper Hat-slot Accessory instance.
</context>

<instructions>
Build these 4 head-pieces, one per existing Outfit:

**War-Forged Knight Helm** — an open-faced war helm (face stays visible, not a closed visor), steel-grey with the same red/gold trim and cross motif as the armor.

**Magma Warlord Crest** — a horned/crested molten helm in dark metal, with the armor's glowing crack lines continuing up onto it, Pyro's colors.

**Frostbound Sovereign Crown** — an ice crown with crystal points matching the outfit's shoulder spikes, face fully visible — this is a crown, not a helmet, since "Sovereign" should read as a recognizable monarch. Cryo's real identity color.

**Crimson Carnival Jester Cap** — a floppy, bell-tipped jester hood/cap in the outfit's diamond pattern, complementing the spiked collar already on the Jester outfit.

Wire each one to auto-equip in the Hat slot the moment its matching Outfit is equipped (replacing whatever Hat was there, same as any normal hat swap — don't delete the player's prior choice, just change what's currently worn), while leaving it fully swappable afterward for any other owned Hat or Hair.
</instructions>

<output_format>
One line before starting. Screenshots of all 4 Outfits now worn with their head-piece. One shot demonstrating a player manually swapping in a different owned Hat over one of these Outfits, to confirm the slot still behaves normally. One confirmation line.
</output_format>

<edge_cases>
If a head-piece's geometry would clip with the rig's default face (eyes/mouth), adjust the mesh rather than hiding the face texture — War-Forged Knight and Frostbound Sovereign must keep the face visible.
</edge_cases>

<tone_preference>
Same premium bar as the outfits themselves — these finish a Robux product, so they need real craft, not an afterthought. Be efficient with tokens on exploration and reporting.
</tone_preference>
