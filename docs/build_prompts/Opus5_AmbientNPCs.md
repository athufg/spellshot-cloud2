<role>
You work for SPELLSHOT's solo owner-developer, building in Roblox Studio. The hub already has two interactable NPCs (Shop Merchant – Pyro, Loadout Keeper – Terra) built as standard Roblox mannequins (regular avatar proportions, custom clothing/accessory pieces, no sculpted creature bodies) with idle and greet animations. This task adds a separate set of purely ambient background NPCs across three hub wings — Training, Duels, and Store — to make the hub feel populated. Done means all seven NPCs below exist, modeled and animated in Blender first then imported with their animations, each looping its idle in place with no interaction logic at all.
</role>

<context>
These are flavor only — no ProximityPrompt, no dialogue, no interact state, nothing that reacts to the player. Don't build any interaction scaffolding for them; that would be wasted effort for background characters. Spend the effort instead on the modeling and animation quality, since these are meant to look genuinely cool, not placeholder.

Build all seven on the same standard-mannequin basis as the Merchant and Keeper, for visual consistency across every NPC in the hub. The dev referenced a human leaning-pose photo for NPC 7 below — use it only for the leg placement (one leg bent, sole against the wall), not for clothing or styling, which should stay in SPELLSHOT's own visual language.

Wing-to-element accent colors (use for each NPC's outfit, not full recolors — subtle accent/trim): Training→Aqua (pull Aqua's real color from `AquaWrap.lua`, don't guess), Duels→Zephyr (Base #4FD1C5 / Light #FFFFFF / Dark #125C59), Store→Pyro (Base #F25C0D / Light #FFC74D / Dark #6B1708).

Build pipeline: model each NPC's custom accessories and author its idle animation(s) in Blender, rigged to the same skeleton/bone structure as the Roblox avatar rig — same pipeline already used for Shop Merchant and Loadout Keeper. Export accessories as meshes and animations as FBX with the rig, then import into Roblox Studio: accessory meshes as MeshParts/accessories fitted to the rig, animations via Studio's animation import.
</context>

<instructions>
Build these seven NPCs:

**Training (2):**
1. One NPC occupying a currently-unused practice lane, looping a practice-swing/ready-stance idle, as if mid-drill.
2. One NPC leaning near the entrance pillar by the waterfall, idle loop of casually watching the lanes.

**Duels (2):**
3–4. Two NPCs positioned near the sideline rail by the duel pads, arms-crossed spectating idle, as if waiting to queue or watching a match. Stagger their loops so they're not in sync with each other.

**Store (3):**
5–6. Two NPCs facing each other near the open floor area in front of the display shelf — a talking/gesturing duo. One loops an animated talking/gesturing idle (hand motion, occasional glance toward the shelf), the other loops a listening/reacting idle (nodding, arm gestures). Stagger the two loops so they don't move in sync; aim for roughly 8–15 seconds before either repeats.
7. One NPC leaning against the staircase wall: left leg planted, right leg bent with the sole flat against the wall, weight resting back into the wall. Arms loose — one crossed over the chest, the other resting on the bent knee (not a stiff clasped-hands pose). Idle loop is a slow head turn scanning side to side, with a small fidget (recross arms or shift weight) worked in every loop or two so it doesn't read as a frozen pose.

For every NPC: bold, simple silhouettes consistent with SPELLSHOT's existing pop-art character style — no fussy detail that won't read at hub scale. Loops should feel alive (secondary motion, weight shifts) rather than a single static frame with faint movement.
</instructions>

<output_format>
One line before starting. When done, a clip or screenshots showing each of the seven NPCs in place with their idle loop running, grouped by wing. Note which skeleton/pipeline details matched the existing Merchant/Keeper setup vs needed adjustment for humanoid rigs.
</output_format>

<edge_cases>
If a practice lane or sideline spot is already occupied by required gameplay geometry (a target, a queue trigger), shift that NPC to the nearest open spot that keeps the same intent (mid-lane practice, sideline spectating) rather than skipping it. Don't add an NPC to the Loadout wing — it already has the Keeper and showcase pedestal and doesn't need one.
</edge_cases>

<tone_preference>
Be efficient — don't build anything beyond what's asked (no interaction systems, no extra NPCs). Within that scope, put real care into the modeling and animation quality; these should look as considered as the Merchant and Keeper, not like filler.
</tone_preference>
