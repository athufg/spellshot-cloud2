<role>
You work for SPELLSHOT's solo owner-developer, building in Roblox Studio. Frostbound Sovereign and Crimson Carnival Jester have good jackets and headwear already, but both read as incomplete because the face underneath is still the bare default avatar face. Finish both with face/neck/back accessories. Done means neither outfit shows a blank default face, Frostbound reads as a real monarch, and nothing added here touches the existing jacket, crown, or cap geometry.
</role>

<context>
Don't modify the jacket, the crown, or the jester cap — those are staying as-is. Everything in this pass is new accessories layered on top, auto-equipping with their matching Outfit the same way the crown/cap already do, and swappable afterward like any other accessory.

Same fairness rules as every other cosmetic in this game: no added collision past the default hitbox, and nothing bright or large enough to obscure an opponent's view.

Build pipeline: Blender first, matching this project's established pipeline, then import into Roblox Studio.
</context>

<instructions>
**Frostbound Sovereign:**
1. Face accessory: a frost-white groomed beard and mustache, icy/crystalline texture matching the crown — this is the main fix, replacing the bare face with something that actually reads as regal.
2. Hair: model flowing hair into the same accessory as the crown (one combined Hat-slot piece, not a separate Hair item, since Hat and Hair can't both be equipped). Position the hair strands so they're clearly visible around and beneath the crown with real separation between the two meshes — no overlapping faces, no z-fighting, both pieces fully readable at once.
3. Back accessory: a flowing fur-trimmed royal cape in the outfit's icy blue-white, clasped at the shoulders near the existing crystal spikes. Build it with Roblox's cloth/wind simulation (cage-mesh cloth physics) so it trails and billows naturally as the player moves or turns, rather than being a rigid static mesh. Non-collidable.
4. Neck accessory: a small ice-crystal collar/medallion, tying the crown's crystal language down through the face and cape to the jacket.

**Crimson Carnival Jester:**
5. Face accessory: bold harlequin face paint as a decal — diamond cheek markings and an exaggerated red smile-line.
6. Neck accessory: a ruffled, diamond-pattern jester collar.
7. Back accessory: a couple of trailing ribbon streamers or small bell-tipped tails off the shoulders, echoing the cap's bells — decorative only, not a held prop.
</instructions>

<output_format>
One line before starting. Screenshots of both finished outfits (front view showing face/neck pieces clearly). A clip or sequence showing the Frostbound cape reacting to movement, and a close-up confirming the crown and hair don't clip. One confirmation line.
</output_format>

<edge_cases>
If cloth simulation performance is a concern, fall back to a simpler scripted sway rather than dropping the effect — the cape should never be a static rigid mesh, but it also shouldn't move so wildly that it obscures the wearer or nearby players.
</edge_cases>

<tone_preference>
Push for real craft — these are the pieces that make both outfits feel finished. Be efficient with tokens on exploration and reporting.
</tone_preference>
