<role>
You work for SPELLSHOT's solo owner-developer, building in Roblox Studio. This is the second Outfits batch — 4 full outfits plus matching headwear, same premium Robux-cosmetic system as the first batch (Magma Warlord, Frostbound Sovereign, War-Forged Knight, Crimson Carnival Jester). Done means all 4 outfits and their headwear exist, fitted to the rig, fairness-safe, and matching the production quality of the first batch.
</role>

<context>
Each outfit is a set of armor/garment shells built over the rig's block body parts (Torso, Left/Right Arm, Left/Right Leg) — model each shell slightly oversized around its corresponding part so it fully encases it with no gaps or z-fighting, same technique that made the first batch read cleanly. Bevel for the faceted comic look, same outline treatment as every other asset, flat color-block materials rather than painted texture, emission only where the design actually calls for glow.

An Outfit replaces the base jacket/pants layer only — Hair/Hat/Mask/Glasses/Pendant from the Wardrobe/Accessories system still equip on top normally. Each outfit's headwear is a Hat-slot accessory that auto-equips when its Outfit is worn and stays swappable afterward, same system as the first batch's helms/crown/cap.

Same fairness rules as every other cosmetic: no added collision past the default hitbox, and nothing bright or dense enough to obscure the wearer's own readability or an opponent's view.

Voltaic's identity colors: Base #F5C70F / Light #FFF573 / Dark #4A1A8C. Terra's: Base #826B24 / Light #CCBA5C / Dark #33210D.

Build pipeline: Blender first, matching this project's established pipeline, then import into Roblox Studio.
</context>

<instructions>
**Thunder Regalia (Voltaic)** — sleek jacket and short cape, thinner bevels and a tighter shell offset than the heavy-armor sets so it reads sleek rather than bulky. Bolt-shaped glowing seams are inset grooves with thin emissive strips inlaid into them, not surface decals. The cape uses the same cloth-sim cage physics as Frostbound Sovereign's. Headwear: a lightning-crown circlet with jagged bolt-shaped points — one spike hand-modeled, radial-arrayed around the ring — glowing in Voltaic's colors. Face stays visible.

**Verdant Warden (Terra)** — bulky tank armor: wider, chunkier shell offset than Thunder Regalia for broad pauldrons, a thick chest plate, and wide leg guards. Moss/crystal growth is a handful of hand-placed low-poly clusters continuing from the body up onto the helm, not a particle scatter. No glow on the armor itself — reserve emission for the helm's eye-slit only, so it reads as a grounded wall of armor, not a light show. Headwear: a full enclosed stone/bark helm (low-subdivision icosphere base, not smooth) with a boolean-cut eye-slit backfilled with emissive green-crystal.

**Shadowblade Assassin (standalone)** — tightest shell offset of the four, hugging the rig rather than bulking it out. Minimal to no glow anywhere — this outfit should not light itself up. Add a utility belt with pouches across the torso/legs for a real concealment-kit read, not just a fitted cut. The cloak is asymmetrical (one side cut shorter) and angled to read as something the wearer can sweep across the body for cover, same cloth-sim cage technique, matte near-black material with minimal shine. Headwear: a fitted hood with deep overhang (face sits in a shadowed recess) plus a lower face wrap, leaving only the eyes visible — no glow, no full helm.

**Starfall Voyager (standalone)** — sci-fi flight-suit: moderate shell offset, sturdier than Shadowblade but not bulky, subtle raised panel seams rather than deep grooves, a few small greeble details at chest/forearms. No cape. Headwear: a glass-domed space helm (UV sphere cut at the neckline) with a baked star-speckle texture painted onto the glass UVs so the face reads faintly through it — outline treatment applies to the metal collar, skipped or lightened on the glass itself.
</instructions>

<output_format>
One line before starting. Screenshots of all 4 finished outfits with their headwear worn. One confirmation line.
</output_format>

<edge_cases>
If a design element on any outfit would need actual collision to look right, scale or reposition the mesh instead — the collision capsule must stay identical to the default rig regardless of visual silhouette.
</edge_cases>

<tone_preference>
Be efficient with tokens on exploration and reporting — this reuses an already-proven technique, not new R&D. The modeling itself still needs to match the first batch's premium quality.
</tone_preference>
