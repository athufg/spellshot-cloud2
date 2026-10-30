# SPELLSHOT Ability Roster

**What this is.** Every ability in SPELLSHOT, one row each, written for the artist who will design one icon per ability. It is the result of a read-only audit on 2026-10-06; nothing in the game or the manual was changed.

**Sources.** The live Roblox Studio project is the source for what exists and what each ability really does; the design manual (v0.21, last change note 2026-09-29) is the source for intent. Where they disagree, the Studio piece gets the row, the piece it replaced goes under "Retired / superseded", and the disagreement is numbered under "Discrepancies" (37 of them, grouped by how much they matter to the icon list).

**Totals.** 56 abilities across nine Elements: Pyro has 8, the other eight have 6 each (no tenth Element exists). 55 are live in Studio, one of them only partly built (Deflect Gust); 1 is locked but not built (Zephyr's Updraft). Three more pieces the manual still prints as locked (Thunderclap, Tremor Vault, Seismic Slam) have been replaced in Studio and are listed as superseded (D1 to D3).

**Slots.** Each Element has four fixed pieces: M1 (the basic attack on the fire button), Primary, Passive (always on, nothing to press) and Ultimate (needs a full charge). Techniques fill two extra slots: a shared-pool Technique can be equipped by any Element, an exclusive one only by its own, and each is listed under the Element it comes from.

**Status key.** Live = works in Studio today. Locked, not built = named, but no working code. Working name = the name is not final. Differs from manual (Dn) = see that numbered discrepancy. Unverified = the auditors could not confirm it from what they read.

**One caution.** Every description comes from reading the game's code; no ability was watched in play, so on-screen looks are unconfirmed where flagged (D16, D17).

## Pyro

| Slot | Name | What it does | Status |
| --- | --- | --- | --- |
| M1 | Fireball | Punches a ball of fire straight down the crosshair, one per click. It bursts on whatever it hits and splashes anyone standing close to the impact. | Live, differs from manual (D22) |
| Primary | Immolate | Lights three flame charges on yourself with a tap. Each of your next Fireballs that actually hurts someone spends one charge and sets everyone it hurt on fire for a short burn. | Live |
| Passive | Ember Refund | Shortens the remaining wait on Immolate every time you kill an enemy, by any means. Works by itself; nothing to press. | Live, differs from manual (D10: unnamed there) |
| Ultimate | Ring of Fire | Traces a large circle of fire on the ground where you point; it follows your crosshair for about a second, then a finger-snap erupts it into a column of flame that hurts and ignites every enemy inside. Spends the full Ultimate charge, and is wider and stronger when your Heat meter is high. | Live, differs from manual (D4, D37) |
| Technique (Pyro-exclusive) | Detonate | Plants a mark, with a tap and no aiming, on the enemy you most recently hit with a Fireball or an Immolate burn. After a short fuse it explodes on that one enemy, harder the less health they have left. | Live, differs from manual (D5: not in manual) |
| Technique (shared pool) | Scorching Lash | Hold to carry a burning whip, then let go to swing it in a wide flat sweep across your front, striking several enemies within long reach. Each enemy struck gains a stack of burn, up to three. | Live, differs from manual (D5: not in manual) |
| Technique (shared pool) | Heat Rush | Hold to run faster and fill a Heat meter while you keep moving; once Heat is high, ranged hits against you are weakened for as long as you hold. Heat is also what powers up Ring of Fire. | Live, differs from manual (D4: retired there) |
| Technique (shared pool) | Cinder Shield | Raises a see-through fire shield in front of you for a few seconds with a tap; it soaks incoming damage and glows hotter as it fills. If it absorbs its full amount it bursts into a wave of heat the way you face; if it simply runs out, nothing is released. | Live, differs from manual (D4: retired there) |

Pyro is the only Element with four Techniques; a Pyro starts with Detonate and Scorching Lash equipped.

## Cryo

| Slot | Name | What it does | Status |
| --- | --- | --- | --- |
| M1 | Icicle Shard | Fires a fast, straight ice shard where you aim, one per click. Each hit adds a stack of Chill that slows the target, and the third stack freezes them in place for a moment. | Live |
| Primary | Flash Freeze | Slams the ground with a tap: frost spreads out from your own feet into a wide frozen zone that lasts a few seconds. Enemies who linger inside are frozen in place, then shattered for heavy damage when the zone ends. | Live |
| Passive | Cold Momentum | Gives you a short burst of extra movement speed every time you land a hit, restarted by each new hit. Nothing to press. | Live, differs from manual (D10: unnamed there) |
| Ultimate | Mirror Cage | Locks onto the enemy nearest your crosshair and raises a large dome of ice mirror panels around them, rooting every enemy caught inside. Ice reflections of each trapped player step out of the mirrors and fire a volley of bolts at them, then the cage breaks. | Live, differs from manual (D8); look unverified (D17) |
| Technique (shared pool) | Blizzard | Drops a wide snowstorm on the spot where you are standing with a tap; it stays there for several seconds and does not follow you. Enemies inside are slowed and can barely see; it deals no damage and leaves you untouched. | Live, differs from manual (D8); look unverified (D17) |
| Technique (shared pool) | Deep Freeze | Plants an invisible ice trap in the ground under your feet with a tap; only you can see it. The first enemy to step on it is sealed, rooted, inside a crystal prison for a couple of seconds; one trap at a time. | Live, differs from manual (D8); look unverified (D17) |

## Voltaic

| Slot | Name | What it does | Status |
| --- | --- | --- | --- |
| M1 | Chain Bolt | Fires an instant lightning bolt from alternating hands at whatever is under the crosshair at very close range; a hit jumps on to the nearest other enemy. Every enemy it touches gains a stack of Charged, which at full stacks bursts out of them as one more bolt. | Live |
| Primary | Overcharge | Dashes a short way in the direction you are looking with a tap, then leaves you primed for a few seconds: the next Chain Bolt you fire jumps through three enemies in a row instead of one. That next shot spends the prime whether it hits or not. | Live |
| Passive | Chain Reaction | Shortens the remaining wait on Overcharge every time you kill someone, by any means. Nothing to press. | Live, differs from manual (D2) |
| Ultimate | Cascade | Marks the ground spot under the crosshair with a tap: a storm cloud gathers over it and, a moment later, five lightning bolts fall in quick succession on enemies still inside the circle, each going to whoever has been struck least. Spends the full Ultimate charge. | Live, differs from manual (D2) |
| Technique (shared pool) | Railspike | Winds up briefly with both arms after a tap, then fires a long straight beam along the crosshair by itself. The beam passes through every enemy in the line and stops at the first wall. | Live, differs from manual (D5: not in manual) |
| Technique (shared pool) | Volt Orb | Throws a ball of lightning in an arc toward the crosshair; it bursts on the first thing it touches or when a short fuse runs out, hurting every enemy near the burst. Only one can be out at a time. | Live, differs from manual (D5: not in manual) |

## Terra

| Slot | Name | What it does | Status |
| --- | --- | --- | --- |
| M1 | Boulder Shot | Hold the fire button to gather a rock in the hand that grows the longer you hold, then release to throw it in a dropping arc that has to be led. A longer charge makes the rock bigger, harder-hitting and slower; a quick tap still throws a small one. | Live |
| Primary | Bulwark Charge | Shoulder-charges a long way straight ahead with a tap, no target needed. You take reduced damage while it runs, and anyone you run into is hurt once, thrown forward and up, and marked Staggered. | Live, differs from manual (D23) |
| Passive | Bedrock | Cuts all damage you take a little, always, simply for being Terra. While you commit to an attack (charging a Boulder Shot, mid Bulwark Charge, or casting Earthen Tomb) stone plates stack up around the chest, each cutting damage further, and all fall away a moment after you stop. | Live, differs from manual (D10, D23) |
| Ultimate | Earthen Tomb | Locks onto the enemy nearest the crosshair and sends a crack racing along the ground that homes on them while you kneel gripping the floor; a target in the air when it arrives dodges it and nothing is spent. A caught target is encased in rock, lifted on a stone pillar and crushed at the top, unless they break out on the way up by pressing a Technique that counts as an escape. | Live, working name, differs from manual (D1); look unverified (D16) |
| Technique (shared pool) | Aftershock | Slams both fists into the ground just in front of you after a short windup that holds you in place. A ring of erupting rock races outward in every direction; everyone it reaches with their feet on the ground is hurt, thrown back and interrupted, and it can be jumped over. | Live, differs from manual (D3) |
| Technique (shared pool) | Bulwark Wall | Hold to raise a wide wall of stone slabs a few steps in front of you; it stops bodies and every shot. It stands only while the key is held, drains Mana the whole time, and shatters once it has soaked up enough damage. | Live |

## Zephyr

| Slot | Name | What it does | Status |
| --- | --- | --- | --- |
| M1 | Wind Blade | Flicks a small blade of wind straight down the crosshair on each click, the hands taking turns. It is a very rapid, light shot that cuts through up to three enemies standing in a line and stops at the first wall. | Live |
| Primary | Cross-Slash Dash | Hold to cross the forearms and charge (a longer hold means a longer dash), then let go to fly in a straight line toward the crosshair, in any direction, cutting every enemy you pass through. At the end the arms fling open and stamp an X that hits whoever is just ahead. | Live (see D15) |
| Passive | Updraft | Does nothing yet: no code applies it and the slot is locked. Studio's text promises no fall damage and quicker steering in the air; the manual instead describes bonus damage and knockback while airborne. | Locked, not built; differs from manual (D6) |
| Ultimate | Cyclone | Places a tornado on the ground where the crosshair points; it follows the crosshair while it forms, then stands in place for a few seconds. Enemies inside its wide column are dragged to the middle, lifted off the ground and spun around it while taking repeated small hits; spends the full Ultimate charge. | Live |
| Technique (shared pool) | Gust Jump | Press while already in the air to be thrown upward again by a gust and then glide down; aiming at a nearby spot carries you onto it, and a second press gives one more jump before landing. Holding the key after a jump makes you hover in place for a moment. | Live |
| Technique (shared pool) | Deflect Gust | Swings one hand in a timed parry, a tap with no aiming, meant to turn a projectile about to hit you around and send it back at whoever threw it. Today it only catches the training range's practice ball; in a duel every press is a miss. | Live, differs from manual (D7: only partly built) |

## Umbra

| Slot | Name | What it does | Status |
| --- | --- | --- | --- |
| M1 | Shadow Dart | Gathers a ball of shadow in the fist for a couple of seconds after a single click, then fires one heavy dart by itself down the crosshair: a slow, long-range sniper shot. Charging, firing and hitting each set off a giveaway flash on the shooter's own body. | Live |
| Primary | Shadow Step | Vanishes on the spot and reappears a short distance away toward where you are aiming, with no travel in between. For a moment afterwards, abilities that lock onto a target cannot pick you and ones already chasing you lose you; it deals no damage. | Live |
| Passive | Unseen | Makes Shadow Dart hit harder when the target is not facing you. Always on, nothing to press; during Eclipse every enemy counts as not looking. | Live (name: see D10) |
| Ultimate | Eclipse | Holds you in place for a beat while you press a mass of darkness together, then darkens the whole arena for everyone for several seconds. While it lasts every enemy is outlined through walls for you alone and counts as not looking, and your Shadow Dart charges and fires faster; it does no damage itself. | Live, working name (D9) |
| Technique (shared pool) | Mark | Tags the enemy nearest your crosshair with a mark that grows from one to three stacks over a couple of seconds and fades if left unused. Your own next direct hit on them spends it for bonus damage, by far the most for a Shadow Dart to the head; nobody else's hit can use it. | Live (see D25) |
| Technique (shared pool) | Decoy Double | Leaves a motionless copy of your own body standing beside you, facing the way you were facing. It lasts several seconds or until the first hit it takes, which shatters it and sets off a giveaway flash on you; it deals no damage. | Live |

## Radiant

| Slot | Name | What it does | Status |
| --- | --- | --- | --- |
| M1 | Light Lance | Hold the fire button to pour a continuous beam of light where you aim; it hurts more the longer it stays on the same target and drains Mana for as long as it is on. Looking off the target for more than a moment restarts the build-up. | Live |
| Primary | Blessing | Puts a protective shield, with a tap, on the ally nearest your crosshair, or on yourself when no ally is there. The shield soaks incoming damage until it is used up or runs out of time. | Live (see D26) |
| Passive | Overflow Light | Heals whoever was wearing a Blessing shield when that shield lasts its full time without being broken, turning part of the unused shield into health. A shield emptied by damage gives nothing. | Live (see D11) |
| Ultimate | Halo | Raises the staff through a short wind-up with a tap; then for a few seconds the health your attacks take from enemy players is also given back as healing, shared between you and nearby allies (all of it to you when alone). While it is up you fall slowly, gliding down. | Live, working name (D9) |
| Technique (shared pool) | Position Trade | Swaps places, with a tap, with whoever you are aiming at (an ally, an enemy or a training dummy) after a brief flash; each keeps the direction they were facing. With nobody under the crosshair the press costs nothing. | Live |
| Technique (shared pool) | Benediction | Hold to plant the staff in the ground and stay rooted while it sends out healing pulses to every ally around you, or to yourself when no ally is near, draining Mana for as long as you hold. A tap gives a single pulse. | Live (see D26) |

## Toxin

| Slot | Name | What it does | Status |
| --- | --- | --- | --- |
| M1 | Toxic Bubbles | Lobs a slow, arcing bubble of poison where you aim with a tap. It pops on the first enemy it touches, hurting and poisoning them; a miss settles on the ground and sits there for a few seconds. | Live |
| Primary | Corrosive Cloud | Bursts your most recent bubble, whether still flying or resting on the ground, into a lingering poison cloud at that exact spot; it is not aimed. Everyone standing in the cloud, you included, keeps taking damage and being poisoned. | Live, differs from manual (D24) |
| Passive | Symbiosis | Heals you a little each time your lingering poison takes health off someone else; nothing to press. Its other half softens a drawback: your own clouds and poison still hurt you, but much less. | Live, differs from manual (D10: unnamed there) |
| Ultimate | Patient Zero | Marks the enemy you are aiming at with an aura that grows and pulses faster; a few seconds later it detonates wherever they are standing, as a burst of damage plus a large lingering poison cloud. Both are stronger for each other enemy near the target. | Live, working name (D9) |
| Technique (shared pool) | Antitoxin Vent | Puts on a gas mask with a tap: it instantly removes poison you have put on yourself, and while the mask is on your own poison and clouds do nothing to you. It never removes poison an enemy put on you. | Live, differs from manual (D24) |
| Technique (shared pool) | Acid Rain | Calls a poison downpour over the ground area you aim at with a tap. After a short gathering, enemies under it take a light hit every second and gain stacks of Corroded, which make Toxin's poison hit them harder for a few seconds. | Live (see D24) |

## Aqua

| Slot | Name | What it does | Status |
| --- | --- | --- | --- |
| M1 | Riptide | Sends a low crescent wave racing along the ground in the direction you face with a tap. It passes through and hurts several enemies in a line, can be jumped over, and leaves a wet streak behind it. | Live (see D14) |
| Primary | Undertow | Draws a whirlpool disc in the air just in front of you with a tap; a moment later every enemy in a wide cone ahead is yanked to the ground right in front of you and cannot cast for a moment. It deals no damage and leaves a wet puddle there. | Live, differs from manual (D14) |
| Passive | Riding the Current | Leaves wet ground wherever your Aqua abilities land. You move faster on your own wet ground; an enemy on it slips, sliding on with very little steering for a moment. | Live |
| Ultimate | Leviathan's Maw | Raises a flood at the ground spot you aim at, and a ring of see-through wave-walls closes overhead into a tank that enemies inside cannot leave. One shark circles under the water for each trapped enemy, then each lunges up and bites its own target, throwing them into the air. | Live, differs from manual (D14) |
| Technique (Aqua-exclusive) | Twin Tide | Raises two wave-walls on either side of a lane at the ground spot you aim at with a tap. They rush together, and anyone caught where they meet is crushed and thrown upward. | Live |
| Technique (Aqua-exclusive) | Sidearm | Draws a water-pistol and fires one shot where you aim; keep holding to keep firing steady shots, each one costing Mana, until you let go or run dry. Every bullet that hits knocks its target back. | Live, differs from manual (D13) |

## Retired / superseded: no icon needed

| Name | Element and slot | Replaced by | Where it was found |
| --- | --- | --- | --- |
| Ember Trail | Pyro, Technique | Heat Rush | Manual v0.4 change note only; no description survives and no copy exists in Studio. |
| Meteor Storm | Pyro, Ultimate | Ring of Fire | Manual v0.4 change note, plus a live script comment (VFXLibrary); no copy of the ability exists in Studio. |
| Cryo Beam | Cryo, Ultimate | Mirror Cage | ServerStorage.CryoBackup_2026_09_24; retired in manual v0.11 but still printed in its launch table. Dead code remains in live scripts (D29). |
| Frost Slide | Cryo, Technique | Blizzard | Same backup; retired in manual v0.11 but still printed in its pool table. Dead code remains (D29). |
| Chill Aura | Cryo, Technique | Deep Freeze | Same backup; retired in manual v0.11 but still printed in its pool table. Dead code remains (D29). |
| Absolute Zero | Cryo, earlier name of the Primary's effect | Flash Freeze (same piece, renamed) | Manual launch table, plus live script comments (VFXLibrary, CastPose); never a separate ability. |
| Glacial Spikes | Cryo, pre-v0.2 kit | none (cut) | Header comments in VFXLibrary and AbilityHandler only; code deleted. Not in the manual. |
| Diamond Skin | Cryo, pre-v0.2 kit | none (cut) | Header comments in VFXLibrary and AbilityHandler only; code deleted. Not in the manual. |
| Thunderclap | Voltaic, Ultimate | Cascade | Backup configs in ServerStorage (Cryo, Aftershock and Voltaic backups); also named in live SpellshotConfig comments; never had code. The manual still prints it as locked (D2). |
| Static Charge | Voltaic, Passive | Chain Reaction | Same backup configs. The manual still describes its mechanic, unnamed (D2). |
| Chain Lurch | Voltaic, Technique | Railspike in Studio; nothing in the manual | Same backup configs; also named in live SpellshotConfig comments; retired in manual v0.7; never had code. |
| Static Field | Voltaic, Technique | Volt Orb in Studio; nothing in the manual | Same backup configs; also named in live SpellshotConfig comments; retired in manual v0.7; never had code. Still named as a status source in the live config (D31). |
| Ground Surge | Voltaic, Technique | Volt Orb | Live module VoltaicFX still holds its whole effect, marked kept but unwired; nothing can cast it; Volt Orb reuses its particle helpers. Not in the manual. |
| Seismic Slam | Terra, Ultimate | Earthen Tomb | Comments in live scripts only, in no backup; never had code. The manual still prints it as locked (D1). |
| Tremor Vault | Terra, Technique | Aftershock | ServerStorage Cryo and Aftershock backups; it was built once and an unused mesh remains. The manual still lists it as locked (D3). |
| Blade Cyclone | Zephyr, Primary | Cross-Slash Dash | Manual v0.5 note and launch table only; in no live script and no backup. |
| Mark for Death | Umbra, Primary | Shadow Step (the marking idea moved to the Technique Mark) | ServerStorage.UmbraKitSuperseded.old_kit_2026_09_27 and older backup configs; retired in manual v0.16; never had a cast path; its team-primed Marked status once ran in StatusEffects. |
| Fade Step | Umbra, Technique | Mark | Same folders; retired in manual v0.16; never had code. |
| Nightfall | Umbra, Ultimate | Eclipse | Same folders; retired in manual v0.16; never had code. |
| Radiant Judgment | Radiant, Ultimate | Halo | ServerStorage.RadiantKitSuperseded.old_kit_2026_09_29; retired in manual v0.19; never had code. |
| Afterglow | Radiant, Passive | Overflow Light | Same folder; retired in manual v0.20, where it has no name. |
| Lightstep | Radiant, Technique | Position Trade | Same folder; retired in manual v0.19; never had code. |
| Cleansing Ring | Radiant, Technique | Benediction | Same folder; retired in manual v0.19; never had code. |
| Spore Burst | Toxin, M1 | Toxic Bubbles | ServerStorage.ToxinKitSuperseded.old_kit_2026_09_30; retired in manual v0.15; text only, never built. |
| Corrosive Cloud (old self-centred version) | Toxin, Primary | Corrosive Cloud (same name, new mechanic) | Same folder; retired in manual v0.15; text only. |
| Overgrowth Vault | Toxin, Technique | Antitoxin Vent | Same folder; retired in manual v0.15; text only. |
| Antidote Cloak | Toxin, Technique | Acid Rain | Same folder; retired in manual v0.15; text only. |
| Bloom | Toxin, Ultimate | Patient Zero | Same folder; retired in manual v0.15; text only. |

- Not in this list: Heat Rush and Cinder Shield. The manual retires both, but they are live in Studio, so they keep their rows under Pyro (D4).
- Dropped drafts named only in the manual, never built and never locked: Geyser and Riverbed (Aqua), Reckoning (Toxin), Beacon and Guiding Rush (Radiant).
- Pyro, Zephyr and Aqua have no retired ability in any Studio backup; their Superseded folders hold only older meshes and scripts of the same abilities.
- Retired status names, for completeness: Shocked (became Charged), Blinded and Purified (removed).

## Discrepancies

Numbered so the tables above can point at them, and grouped by how much they matter to the icon list. "L" is a line in the design manual; "l." is a line in a Studio script.

### These decide which icons get made, or what an ability is called (D1 to D15)

- **D1. Terra's Ultimate has three names.** Studio: Earthen Tomb, live, flagged a working name. Manual: Seismic Slam in the launch table and the ragdoll example, Fault Line as Terra's "new Ultimate" in the Reactions section, and no mention of Earthen Tomb; neither manual name has any code. (Manual L233, L519, L470; SpellshotConfig l.367.)
- **D2. Voltaic's Ultimate and Passive.** Studio: Cascade and Chain Reaction, live since 2026-09-25. Manual: still locks Thunderclap (one instant burst) and an unnamed Passive (bonus damage against stationary targets, which its Shatter reaction builds on), with no change note for any Voltaic rework. (Manual L232, L482; Static Charge survives only in ServerStorage backup configs; Thunderclap is also named in a live SpellshotConfig comment, l.365.)
- **D3. Terra's Technique: Aftershock or Tremor Vault.** Studio: Aftershock, live since 2026-09-25. Manual: still lists Tremor Vault (burrow, pop up nearby) as a locked pool Technique and never mentions Aftershock. (Manual L246; besides the ServerStorage backups, Tremor Vault survives in live comments and as the unused EarthMagicMeshes.TerraVault mesh; its code is deleted from the live scripts.)
- **D4. Heat Rush, Cinder Shield and Heat.** Studio: both Techniques are live and open to every Element, and Heat still makes Ring of Fire bigger. Manual: v0.7 retires all three with no replacement and says the Heat bonus is gone. Only Heat Rush builds Heat and a Pyro starts without it, so a default Pyro never gets the bigger ring. (Manual L49-50, L262-267; PyroHandler; SpellshotConfig l.394.)
- **D5. Five live Techniques the manual does not contain.** Detonate, Scorching Lash, Railspike, Volt Orb and Aftershock are live in Studio. None of the names is in the manual, which says in five places that Pyro and Voltaic contribute no Techniques. (Manual L49, L289, L302, L558, L746.)
- **D6. Zephyr's Passive, Updraft, is not built.** Studio: a name and one line of text ("No fall damage, faster air control"), no code, slot locked. An effect kit for it is imported but unused (WindMagicMeshes.ZephyrUpdraft_Kit and ZephyrInkData's Halo piece, noted as shown only while airborne); no script draws it. Nobody takes fall damage anyway. Manual: bonus damage and knockback while airborne, with the fall-damage and air-control parts left as an open question. (SpellshotConfig l.255, l.619; ZephyrInkData l.1363, l.13164; manual L31, L234, L511.)
- **D7. Zephyr's second Technique, Deflect Gust, is only partly built.** Studio: castable and costs its cooldown, but it can only reflect the training range's practice ball; no player projectile can be parried, it borrows Wind Blade's arm swing and other players do not see it. Manual: a locked parry that reflects one projectile at its owner. (ZephyrHandler l.22-25; CombatCore l.237-255; manual L253.)
- **D8. Cryo's Ultimate and Techniques.** Studio: Mirror Cage (Cryo's fixed Ultimate) is live, and Blizzard and Deep Freeze are live shared-pool Techniques; Cryo Beam, Frost Slide and Chill Aura cannot be cast. Manual: its v0.11 note agrees (calling the two Techniques "Cryo's own"), but the launch table still prints Cryo Beam and the pool table still lists Frost Slide and Chill Aura. It also has the cage's panels firing at one target, where live the cage roots everyone inside and reflections of the trapped players fire. (Manual L74-79, L231, L245, L251; AbilityHandler l.1210-1322.)
- **D9. Working names.** Studio flags four Ultimates as working names: Earthen Tomb (D1), Eclipse, Halo and Patient Zero. Manual: Eclipse and Halo are working names (the launch table prints no name at all for Halo); Patient Zero is stated plainly in two places and called a working name, with "Outbreak" also floated, in a third. (SpellshotConfig l.367-374; manual L117, L236, L404, L105, L331.)
- **D10. Passive names.** Ember Refund (Pyro), Cold Momentum (Cryo), Bedrock (Terra) and Symbiosis (Toxin) are named only in Studio; the manual has the same mechanics unnamed. Umbra's Unseen is named in the manual's v0.18 note and Appendix but unnamed in its launch table and Umbra subsection. (Manual L230-237, L134, L355, L757.)
- **D11. Radiant's Passive.** Studio: Overflow Light, live, returning part of the leftover shield as health (60%). Manual: v0.20 locks Overflow Light, but the v0.19 note saying the old Passive was deliberately kept is still in the file; the manual and Studio's own one-liner both read as if all of the leftover is healed. (Manual L163, L167; RadiantHandler l.495-509.)
- **D12. Aqua is built; the manual and the art tables have not caught up.** Studio: all six Aqua abilities are live. Manual: still calls Aqua "not yet built" (and says the same of Toxin, Radiant and the status system, all live) and in one section still lists the ninth Element as a community-voted theme. Every Aqua logo and glyph in Studio's art tables is a placeholder copy of Zephyr's. (Manual L101, L306, L698; IconAssets; PopArtAssets.)
- **D13. Aqua's Sidearm.** Studio: tap for one shot, hold for steady repeat fire paid per bullet, every hit knocking the target back. Manual: tap for a quick shot, hold to charge one denser slug that knocks back or up. (AquaHandler l.613-772; manual L315.)
- **D14. Undertow, Leviathan's Maw and Wet.** Undertow: the manual pulls enemies to the vortex's own centre; live it drags everyone in a long cone to the ground at the caster's feet. Leviathan's Maw: the manual and Studio's one-liner describe one shark; live each trapped enemy gets its own, up to six. Wet: the manual assumes Riptide applies it; in Studio no such status exists and Riptide's hook has no listener. (AquaHandler l.511-552, l.805-835, l.67-72; manual L311, L313, L450.)
- **D15. Zephyr's Primary.** Studio and manual agree on Cross-Slash Dash: held to charge, released toward the crosshair, no target lock; its predecessor Blade Cyclone appears in no live script. Only Studio's own one-liner is stale, still saying it "dashes at a target". (ZephyrHandler l.341-361; ZephyrFX l.159-160; manual L31, L234.)
### The live ability behaves differently from its written description (D16 to D26, and D37)

- **D16. Earthen Tomb's look is unconfirmed.** Studio's one-liner and older effect comments say the target is raised in a stone fist; newer comments in the same effect script say a heap of rocks on a rising plinth replaced the claw. The drawing code itself was not read. (SpellshotConfig l.368; TerraFX l.14, l.201, l.229.)
- **D17. Nothing was watched in play.** Every description comes from reading code; Play mode was never started. The effect-drawing scripts were not read for Mirror Cage, Blizzard and Deep Freeze and only partly read for Terra and Voltaic, so how those look on screen is unconfirmed.
- **D18. Shared or exclusive.** Studio: Detonate (Pyro), Twin Tide and Sidearm (Aqua) are exclusive; the other 17 Techniques fit any Element in either slot. Manual: agrees on Aqua's two, leaves Toxin's two "flagged, not resolved", does not say for Cryo's two, and does not have Detonate. Zephyr has no default Techniques in Studio, so a new Zephyr keeps whatever was equipped. (SpellshotConfig l.393-431; manual L337, L107, L75-76.)
- **D19. Kit shape and counts.** Studio: nine Elements, 20 Techniques, two Technique slots, Ultimate fixed to the Element. Manual: repeats "8 Elements" and "12 Techniques" (a count that only works with the retired Frost Slide and Chill Aura) and describes both "up to 3 Techniques from one shared pool" and a newer six-ability-per-Element kit without settling which. (Manual L46-48, L73-79, L239, L289, L745.)
- **D20. "Technique 1" and "Technique 2" do not describe behaviour.** Studio still files each Technique in a "Mobility" or "Defense" half, but since v0.7 that is a label, apart from two things it still decides: the HUD glyph and which Techniques break Earthen Tomb's hold (Heat Rush, Gust Jump, Position Trade, Mark and Antitoxin Vent do). Detonate, Blizzard, Railspike, Aftershock, Mark and Antitoxin Vent are in the Mobility half and do not move the caster; Volt Orb, Scorching Lash, Acid Rain, Twin Tide and Sidearm are in the Defense half and are attacks. Aqua's Twin Tide sits on the Technique 1 key by default. (SpellshotConfig l.304-316, l.397; PopArtHUD l.696-707; TerraHandler l.1001-1012.)
- **D21. Studio's own one-liners that misdescribe the live ability.** Scorching Lash ("crack it where you aim"; it is a wide flat sweep), Eclipse ("darts fly faster"; they charge and fire faster, as the manual says), Gust Jump ("the only vertical option"; everyone has a double jump, and it works only in the air), Cyclone ("sets teammates up"; nothing in code), and Bulwark Wall and Benediction (nothing says they are held and drain Mana). See also D8, D14, D15, D16, D23. (SpellshotConfig Desc fields.)
- **D22. Fireball.** Studio: a straight shot down the crosshair. Manual: a slow arcing lob that must be led. (PyroHandler l.241-437; manual L230.)
- **D23. Bulwark Charge and Bedrock.** Bulwark Charge: the manual says it knocks down what it hits; live it hurts, launches and labels the target Staggered, the label takes no control away, and on a real player the launch reads as a shove. Bedrock: the manual and Studio's one-liner say a stacking shield; live it is a cut to all damage taken, always on at a low level, with plates that also build while casting Earthen Tomb. (TerraHandler l.379-432, l.1386-1433; manual L233.)
- **D24. Toxin details.** Corrosive Cloud: the manual converts a bubble in flight; live also a resting one, and the cloud hurts its caster too. Antitoxin Vent: live adds an instant self-cleanse the manual lacks. Toxic Bubbles pops on the first enemy, a point the manual leaves open. Acid Rain's stacking weakness is built as the manual's proposed, unconfirmed default, but Studio also gives it a light direct hit each second, which that default ruled out; Patient Zero's scaling is built as the manual's proposed, unconfirmed default. Both Techniques are shared-pool but do little without Toxin's own poison. (ToxinHandler; manual L105-110, L327-337.)
- **D25. Umbra's Mark.** Studio: a small bonus on a body hit, a large one on a Shadow Dart headshot; head and body are told apart only for Shadow Dart, so any other Element holding Mark gets only the small bonus. Manual: its tables say headshot only, its v0.18 note adds the body bonus. The on-target marker is a temporary placeholder in Studio and "still open" in the manual. (UmbraHandler l.319-453; UmbraClient l.248-273; manual L139, L248, L357.)
- **D26. Abilities with an ally half.** Blessing, Benediction, Halo's shared healing and Patient Zero's scaling assume more than two players, but Studio has no teams: in a duel they fall back to the caster or never scale, and the ally side works only with the training range's ally dummies. (CombatCore l.154-175; ServerScriptService.AllyDummies.)
- **D37. Ring of Fire's input.** Studio: one press at a ground spot; the hand draws the circle by itself in about a second, the crosshair can still move it, then it erupts. Manual: the launch table and the v0.4 note have the player trace the circle with their aim and close it to arm it, while its Appendix gives a fixed press-to-eruption time. (PyroHandler l.623-624, l.698-720; manual L22, L230, L762.)

### Found on the way; no effect on the icon list (D27 to D36)

- **D27. Borrowed arm animations.** World effects and gameplay are complete, but these have no first-person arm clip of their own: Blizzard, Deep Freeze, Mirror Cage, Chain Bolt, Overcharge, Volt Orb, Deflect Gust and Toxic Bubbles reuse another ability's, and Corrosive Cloud, Antitoxin Vent, Acid Rain and Patient Zero have none. (SpellshotInput l.352-359; VoltaicClient l.42-43; ToxinClient l.7-13.)
- **D28. Mechanics in code with no ability row.** These are not abilities; the registry names none of them and the manual covers only some.
  - Pyro: the Heat meter and Detonate's "Primed" mark.
  - Voltaic: Charged stacks.
  - Terra: Bedrock's always-on layer, Aftershock's interrupt, the Staggered and Entombed labels, and Earthen Tomb's escape, which only some Mobility-half Techniques trigger (D20).
  - Zephyr: Gust Jump's hover and second jump, and Cyclone's Airborne label.
  - Umbra: the giveaway flash and the untargetable moment after Shadow Step.
  - Radiant: Halo's glide and healing cap.
  - Toxin: Corroded stacks and reduced self-poisoning.
  - Aqua: wet-ground slip, Undertow's interrupt and knock-ups.
- **D29. No hidden abilities; leftover code.** Every handler's cast list holds exactly the registry's abilities. Dead code and data remain for Cryo Beam, Chill Aura, Frost Slide, Tremor Vault and Ground Surge (VoltaicFX l.10-20); Cryo Beam's effect data is still loaded on every client at start-up, and "FrostSlide" and "ChillAura" survive as the names of clips and dash settings that live abilities borrow. (AbilityHandler l.394-699; VFXLibrary l.727-738; DashMotor l.124.)
- **D30. Test scripts are enabled in the live place.** TerraTestServer (no Studio-only guard), TerraTestHarness (marked temporary) and VoltaicTestHarness (Studio only, by its own check) are all enabled. (ServerScriptService; StarterPlayerScripts.)
- **D31. Statuses.** The manual lists Cracked (Terra) and Wet (Aqua); neither exists in Studio. Studio's status table still credits Revealed to the retired Static Field, which nothing applies, and marks Slipping and Snared as having no source. The manual's durations line still lists the Marked status it removed in v0.16. (SpellshotConfig l.501-521; manual L449-455.)
- **D32. Movement everyone has.** Studio gives every player a double jump, wall run and wall jump as well as sprint, crouch, slide and slide-jump. Manual: its shared movement list stops at slide-jump; a universal double jump is implied once, in Gust Jump's row. (MovementController; manual L247, L512, L741.)
- **D33. Attunement Phase.** Studio: nothing; no Attunement, upgrade, augment or perk code in any live script. Manual: names the phase and its Mana Shards currency but not a single upgrade. (Manual L207, L583.)
- **D34. Stale labels on screen.** The loadout menu tags Terra and Voltaic "M1 + PRIMARY + PASSIVE ONLY" and Zephyr "M1 + PRIMARY ONLY", although the only unbuilt piece among them is Zephyr's Passive. (LoadoutMenu l.301-309; Config.PartialKits.)
- **D35. Other manual lines that contradict the manual.** Benediction's pool-table row omits the root that v0.20 added (Studio roots the caster), and the Passives paragraph still cites "Zephyr's air control" as existing. (Manual L255, L168, L511.)
- **D36. Numbers.** Almost every gameplay number in Studio is marked a stand-in or proposal in its own tuning script, which is one reason this file quotes none. The manual says 100 health while noting the build runs 150. (Manual L506, L735.)

## Other icon-shaped things

Universal movement and combat, the same for every player:

- **M1 (basic attack)**: each Element's own shot on the fire button; it is the M1 row in each table above and has no slot on the HUD today.
- **Sprint**: automatic whenever you move; no key and no stamina.
- **Crouch**: hold to lower the body and shrink the hitbox while moving slowly.
- **Slide**: crouch while moving at speed to slide along the ground for a moment.
- **Slide-jump**: jump during a slide to carry its speed into the air.
- **Jump**: the ordinary jump.
- **Double jump**: one extra jump in the air, given back on landing or catching a wall.
- **Wall run**: ride along a wall for a moment while airborne and moving fast.
- **Wall jump**: jump off the wall during a wall run.
- **Interact**: the Hub's prompts.
- **Health**: does not regenerate by itself; only healing abilities restore it.
- **Mana**: the bar that Primaries and Techniques spend, and each M1 shot takes a little of; it refills over time.
- **Ultimate charge**: fills from damage dealt and taken; the Ultimate is ready when it is full.
- **Not universal, although they are movement**: Gust Jump, Heat Rush and the dashes and blinks (Overcharge, Cross-Slash Dash, Bulwark Charge, Shadow Step, Position Trade) are abilities listed above.

Attunement Phase:

- **In-match upgrades**: do not exist in Studio. No Attunement, upgrade, augment or perk code is in any live script, and the manual names no individual upgrade.
- **Mana Shards**: named in the manual only, as the currency for that phase; the name appears in no live script (137 scanned).

What exists today, for reference: nine Element logos and one generic glyph per slot type per Element. No ability has an icon of its own anywhere in the game, the Passive is a text label on the HUD, and Aqua's logo and glyphs are placeholder copies of Zephyr's (D12).
