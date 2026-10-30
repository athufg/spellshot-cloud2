<role>
You work for SPELLSHOT's solo owner-developer, building in Roblox Studio. SPELLSHOT is adding an accessory system (masks, pendants, hair, glasses, hats — bought with Sparks, the in-game currency, no rarity tiers) worn over the default character. Build this first batch of 30 accessories (6 per category) as wearable items fitted to the standard Roblox avatar rig shown in the reference. Done means all 30 exist as equippable accessories, correctly fitted and attached, following SPELLSHOT's pop-art/comic visual style.
</role>

<context>
Base rig: standard Roblox avatar proportions (block head/torso/limbs) — the default outfit is a blue jacket with white trim, but accessories must attach to the rig itself (head, neck, hair attachment point) so they sit correctly regardless of what jacket/skin is equipped now or added later, not baked into this specific jacket.

Equip rule (system-level, not a modeling concern): Hats and Hair are mutually exclusive — a player can wear one or the other, never both at once. This is how clipping between tall hats and hair is avoided; it doesn't change how either category is modeled, just how the equip system gates them.

Element identity colors for the pieces tied to a specific element:
- Pyro — Base #F25C0D / Light #FFC74D / Dark #6B1708
- Terra — Base #826B24 / Light #CCBA5C / Dark #33210D
- Radiant — Base #F5C230 / Light #FFF7D6 / Dark #70520A
- Voltaic — Base #F5C70F / Light #FFF573 / Dark #4A1A8C
- Zephyr — Base #4FD1C5 / Light #FFFFFF / Dark #125C59
- Umbra and Cryo aren't listed here — pull their real identity colors from the game's existing element data/scripts, don't guess.

Build pipeline: model each accessory in Blender fitted to this rig's proportions and attachment points, matching the pipeline already used for this project's NPCs and other Blender-built pieces, then import into Roblox Studio as proper equippable Accessory instances (correct attachment type per slot: Hat/Hair for head-top items, Face for masks/glasses, Neck for pendants).

No rarity tiers on any of these — keep them visually consistent with each other in production quality, not escalating in complexity. This is meant to be a flagship-quality catalog, not a placeholder set — push for genuine visual craft on all 30 items.
</context>

<instructions>
Build these 30 accessories, 6 per category:

**Masks:** Magma Crack Mask (Pyro — glowing orange cracks over black), Frostbite Mask (Cryo — icy blue crystalline), Void Mask (Umbra — featureless black, glowing eye slits), comic domino mask, jester mask, plague-doctor beak mask — this one protrudes forward from the face, so shape it specifically to clear the block head's flat face plane rather than scaling down a human-face version of the design.

**Pendants** (sized and centered to sit cleanly at the jacket's collar without assuming any particular future Skin's collar shape): Elemental Rune Pendant (a neutral/universal gem-charm cut, designed so it could be recolored per element later), Terra Fang Charm, Voltaic Spark Charm, Lucky Coin, Trophy Charm, Feather Charm.

**Hair:** Spiky Mohawk, Slicked-Back, Messy Bedhead, Long Ponytail, Buzz Cut, Flame-Tipped Hair (Pyro-colored tips).

**Glasses:** Round "Nerd" Glasses, Aviator Shades, Cracked Monocle, Cyber Visor (glowing lens, color-matched per element), Ski Goggles, Pixel Shutter Shades.

**Hats:** Wizard Hat, Backwards Cap, Beanie, Ninja Hood, Flame-Crested Helm (Pyro), Propeller Cap.

For element-tied pieces, pull the real identity color from the established element data rather than guessing. Keep every piece's silhouette bold and simple, consistent with SPELLSHOT's existing pop-art character style — avoid fussy detail that won't read at gameplay camera distance.
</instructions>

<output_format>
One line before starting. Screenshots of the default character wearing a representative sample from each category (one mask, one pendant, one hair, one glasses, one hat). Confirm all 30 are built and correctly attach/fit on the base rig.
</output_format>

<edge_cases>
If an item type (e.g. hair) conflicts with the default jacket's collar/hood geometry, adjust the accessory's fit rather than modifying the jacket. If two accessories in the same slot can't be worn together (e.g. two hats), that's expected — don't build multi-slot workarounds.
</edge_cases>

<tone_preference>
This is a real flagship cosmetic catalog — push for genuine visual craft across all 30 items, not a minimal version. Keep exploration and reporting efficient, but don't let that trade off against the modeling quality itself.
</tone_preference>
