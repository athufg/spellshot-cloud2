<role>
You work for SPELLSHOT's solo owner-developer, building in Roblox Studio. This is the second accessory batch (bought with Sparks, no rarity tiers), following the same pipeline as the first 30-item batch. Build these 15 new accessories fitted to the standard Roblox avatar rig shown in the reference. Done means all 15 exist as equippable accessories, correctly fitted and attached, following SPELLSHOT's pop-art/comic visual style.
</role>

<context>
Base rig: standard Roblox avatar proportions (block head/torso/limbs) — the reference shows the default blue zip-up jacket with white trim, but accessories attach to the rig itself (head, neck, hair attachment point), not to this specific jacket, so they sit correctly regardless of what outfit is equipped.

Equip rule (system-level, not a modeling concern): Hats and Hair stay mutually exclusive — one or the other, never both.

This batch exists for two reasons: the first hair batch skewed toward one style direction, so this batch adds feminine-coded hairstyles to give real range; and several elements (Zephyr, Toxin, Radiant, Aqua, Cryo, Voltaic) had zero element-tied cosmetics after batch one, so this batch closes that gap across masks, pendants, glasses, and hats.

Element identity colors for the pieces tied to a specific element:
- Radiant — Base #F5C230 / Light #FFF7D6 / Dark #70520A
- Voltaic — Base #F5C70F / Light #FFF573 / Dark #4A1A8C
- Zephyr — Base #4FD1C5 / Light #FFFFFF / Dark #125C59
- Aqua, Toxin, Cryo aren't in this table — pull their real identity colors from the game's existing element data/scripts, don't guess.

Build pipeline: model each accessory in Blender fitted to this rig's proportions and attachment points, same pipeline as batch one and the project's NPCs, then import into Roblox Studio as proper equippable Accessory instances (correct attachment type per slot: Hat/Hair for head-top items, Face for masks/glasses, Neck for pendants).

No rarity tiers — keep all 15 visually consistent in production quality with each other and with batch one, not escalating in complexity. Flagship-quality catalog, not a placeholder set.
</context>

<instructions>
Build these 15 accessories:

**Hair (6, feminine-coded, expanding the category's range):** Long Wavy Hair, High Ponytail, Twin Pigtails, Braided Crown, Space Buns, Side-Swept Bob.

**Masks (2, element-tied):** Zephyr Gust Mask (wind-swept silhouette, light teal/white, Zephyr colors), Toxin Vial Mask (cracked glass vial shape over the mouth, sickly green glow, pull Toxin's real color from game data).

**Pendants (2, element-tied, sized/centered to clear the jacket collar without assuming any future Skin's collar shape):** Radiant Sunray Pendant, Aqua Droplet Charm (pull Aqua's real color from game data).

**Glasses (2):** Cryo Frost Lens (icy glowing lens, color-matched to Cryo's real identity color from game data, same color-match approach as the Cyber Visor from batch one), Heart-Shaped Shades (generic, bold comic-pop silhouette, not element-tied).

**Hats (3):** Flower Crown (generic, feminine-coded), Tiara (generic, regal comic style), Voltaic Spike Crown (element-tied, Voltaic colors).

Keep every silhouette bold and simple, consistent with SPELLSHOT's pop-art character style — avoid fussy detail that won't read at gameplay camera distance. For element-tied pieces, pull real identity colors from established element data rather than guessing.
</instructions>

<output_format>
One line before starting. Screenshots of the default character wearing a representative sample (two hairstyles, one mask, one pendant, one glasses, one hat). Confirm all 15 are built and correctly attach/fit on the base rig.
</output_format>

<edge_cases>
If an item conflicts with the default jacket's collar/hood geometry, adjust the accessory's fit rather than modifying the jacket. If an item can't be worn with another in the same slot (e.g. two hats), that's expected — don't build multi-slot workarounds.
</edge_cases>

<tone_preference>
Real flagship cosmetic catalog — push for genuine visual craft across all 15 items, not a minimal version. Keep exploration and reporting efficient, but don't trade that off against modeling quality.
</tone_preference>
