# SPELLSHOT — Elemental Duels

## Full Design Manual v0.3

**One-line pitch:** RIVALS' precise, mobile-first, ranked duel structure — with elemental spellcasting kits instead of guns.

**Position relative to existing top games:** Adjacent to RIVALS (ranked ladder, mobile-first matchmaking, cosmetic monetization, duel-pad challenge), Blox Fruits (elemental theme, trading economy), Elemental Battlegrounds (spellcasting fantasy, mix-and-match abilities), and Jujutsu Shenanigans (ability-kit combat). Structurally different from all four: it pairs an aim-skill-first M1 with a ranked ladder and mobile-first matchmaking (which Elemental Battlegrounds lacks), a shared cross-Element Technique pool for build variety and scalable content (similar in spirit to Elemental Battlegrounds' spell-mixing, but layered onto a competitive structure instead of a leveling sandbox), and a cosmetic-only trading economy none of the four have.

**v0.2 change note:** the kit structure now separates **M1** (left-click basic attack) from **Primary Ability** (a distinct battle ability slot) — earlier versions of this doc conflated the two under "Primary." Every Element's kit and the shared Technique pools were also redesigned so each entry is a genuinely different mechanic, not a re-skinned copy of another entry (the old pool had multiple near-identical "wall" abilities, for example — down to exactly one now, on purpose).

**v0.3 change note (2026-09-13):** brings the manual back in line with decisions made since v0.2, and adds two new systems.

- **Added — ragdolls and kill effects.** Every elimination ragdolls (Section 3). Every kill plays a kill effect: a basic one everyone has, and a special one that comes with a few skins, which gives those skins something extra to sell (Sections 7, 8, 14, 15 and the Appendix).
- **One persistent currency.** Prisms is dropped. Sparks is the only persistent currency and can also be bought with Robux; what Prisms used to buy is bought with Robux directly (Sections 1, 2, 6, 8 and the Appendix).
- **M1 has a small Mana cost** that can never empty the bar on its own (Sections 1 and 3).
- **Health regenerates** after a 2-second pause (Section 3).
- **Shared movement** — sprint, crouch, slide and slide-jump — is written in (Section 3).
- **Quick Play** is how queued matches are joined from the Hub (Section 1).
- **Still open, not changed here:** max health. This manual says 100 HP; the current build runs 150. One of the two has to move.

**Update (2026-09-14) — Pyro kit build:** Pyro's Techniques are being rebuilt one at a time; each is written in here once approved.

- **Heat Rush replaces Ember Trail** as Pyro's Mobility Technique (Section 2) and as the starter Mobility Technique (Section 11): a held sprint that builds Heat and, above a threshold, reduces incoming ranged damage. Heat is a new per-player resource with a visible meter; its rates, the threshold and the reduction are not set yet.
- **Cinder Shield changes** (Section 2): it is now a see-through shield held up in one hand that glows hotter the more damage it absorbs. Only a burst releases its heatwave, sent toward where you are facing; letting it expire releases nothing. Shield strength, duration and the heatwave's range are not set yet.
- **Ring of Fire replaces Meteor Storm** as Pyro's Ultimate Technique (Section 2) and as the starter Ultimate Technique (Section 11): trace a circle with your aim, closing it arms it, and a snap erupts fire filling the circle, bigger and hotter at high Heat. Cryo Beam's comparison now points to it. Circle size, trace and snap inputs, the Heat bonus and damage are not set yet.

## 0. Design Pillars

Every system below should be checked against these four rules. If a feature violates one, cut it or redesign it.

**Aim still matters.** Every Element's M1 must require aim (skillshot, hitscan, or a held channel that must be tracked onto a target), never auto-target or pure-AoE. This is what separates SPELLSHOT from Elemental Battlegrounds (leveling sandbox) and keeps the RIVALS-style skill ceiling intact. Primary Abilities and Techniques are not held to this rule — several are deliberately non-aim utility/setup tools.  
**No pay-to-win, ever.** Robux can buy looks and roster access (which Element or Technique you get to play sooner), but never stat power inside a kit — nothing is ever stronger because of a Robux purchase, only reachable faster. This is a direct lesson from the research: Grow a Garden and Steal a Brainrot took real reputational damage ("somewhat evil," pay-to-win admin powers) that a cosmetic-and-roster-only economy avoids.  
**Every system should make a friend more valuable.** Trading, party bonuses, duel challenges, and clip-sharing all exist to make "play with a friend" mechanically better than playing alone, not just socially nicer.  
**Every ability must earn its slot with a distinct verb, not a distinct color.** Before adding or approving any M1, Primary Ability, or Technique, check it against everything else in its category. If the only difference from an existing entry is damage numbers or a palette swap (two "walls," two "dashes" that behave identically), redesign it. This is a standing rule now, not a one-time cleanup — see Section 2 for what "distinct verb" means in practice.

## 1. Core Loop

**Hub loop (persistent social space, the default resting state):** Players spawn into a central Hub, not straight into combat — mirroring RIVALS' lobby rather than a queue screen. The Hub is a walkable social space with target dummies for warm-up, the cosmetic shop, a Cache vendor, scattered **Duel Pads**, and a Loadout altar where players set their Element and up to 3 Techniques before queuing (see Section 2). Stepping on a Duel Pad next to another player instantly starts a 1v1, no queue needed. Queued matches are joined from the Hub's **Quick Play** screen — Duel, Squad Clash, and the weekly Convergence mode, with Ranked and Rift Royale shown locked until they open. Closing the screen keeps you in the queue, so players can keep warming up or browsing the Hub while they wait; casual practice and spontaneous duels never require queuing at all. Players return to the Hub after every match rather than straight into another queue — this keeps it the social glue between matches, not just a menu screen.

**Round loop (once queued into a match):** Spawn into the round → hold a Mana pool (regenerates slowly; M1 costs a little Mana but can never drain the bar on its own, everything else spends real Mana) → fight with M1 as your bread-and-butter → use your Primary Ability and equipped Mobility/Defense Techniques for bigger moments → build toward your equipped Ultimate Technique's charge (earned via damage dealt/taken, not time) → win the round by eliminating the enemy team or completing the round objective.

**Match loop:** Best-of-9 rounds (first to 5 wins), same round economy as Valorant/RIVALS: everyone earns **Mana Shards** per round (win or lose, losers earn a bit more to prevent snowballing) to spend in a pre-round **Attunement Phase** on temporary in-match upgrades (see Section 6).

**Session loop:** Start in the Hub → queue → play 2–4 matches → return to Hub, check daily Contract progress → spend earned Sparks on cosmetics or the Cache → check ranked progress → (ideally) get invited to or send a **Duel Pad** challenge to a friend right there in the Hub before logging off.

**Retention loop (weekly):** New weekly Contract line → weekend "Convergence" limited Cache window → ranked ladder reward tracking → season pass progress.

## 2. The Elements & the Technique System

**The core idea:** an Element fixes three things — **M1** (your basic attack), **Primary Ability** (a signature battle ability), and **Passive** — the pieces that make a matchup readable at a glance and give each Element its own feel. Everything else in your kit — one Mobility Technique, one Defense Technique, one Ultimate Technique — is drawn from a shared pool that grows independently of how many Elements exist. This is the direct fix for the content-scaling problem a fixed 8-kit design runs into: a new standalone Technique is a fraction of the design and balance work of a new Element, so build variety and post-launch content can both ship far faster than a "new Element every season" model allows, without ever running dry.

1 Element → fixes M1, Primary Ability, and Passive (unlocked together as a bundle)  
1 Mobility Technique  
1 Defense Technique  
1 Ultimate Technique

(3 Techniques total, matching the cap. A slot can be left empty, but there's rarely a reason to.)

M1 is not separately selectable — it comes bundled with whichever Element you choose. This is a deliberate call, not a default: letting M1 mix independently would mean an opponent's basic attack no longer tells you their Element, and that legibility matters more here than the extra build flexibility would be worth.

### The 8 Launch Elements — M1, Primary Ability, and Passive

| Element | Archetype | M1 (basic attack) | Primary Ability | Passive |
|---|---|---|---|---|
| **Pyro** (Fire) | Aggro/DPS | **Fireball** — slow arcing lob, splash on impact, highest per-hit damage of any M1, must be led | **Immolate** — buffs your next 3 M1 hits with bonus burn damage (a self-empower, not a new attack) | Landing a kill refunds 30% of Immolate's cooldown |
| **Cryo** (Ice) | Control/Zone | **Icicle Shard** — fast flat-trajectory, low damage, stacks Chill; 3 stacks briefly roots the target | **Flash Freeze** — a ground-zone effect (the former "Absolute Zero" asset, reused under this name): anyone who lingers past 1s is rooted, then shattered for heavy damage if still frozen when it ends | Move speed +10% for 2s after landing any hit |
| **Voltaic** (Lightning) | High-skill snowball | **Chain Bolt** — instant hitscan, very short range, auto-chains to a second nearby enemy | **Overcharge** — instant short dash forward; your next M1 chains to 2 extra targets instead of 1 | Bonus damage vs. stationary targets |
| **Terra** (Earth) | Aggressive tank | **Boulder Shot** — hold to charge, release early for less damage; the only chargeable M1 in the game | **Bulwark Charge** — Terra charges forward, gains damage reduction, knocks down whatever it hits | Gains a stacking shield while charging M1 or mid-Bulwark Charge |
| **Zephyr** (Wind) | Mobility/Flank | **Wind Blade** — very high fire rate, low damage, pierces through multiple enemies in a line | **Blade Cyclone** — spins in place, damaging vortex around Zephyr, still mobile at reduced speed | No fall damage, faster air control |
| **Umbra** (Shadow) | Assassin/Playmaker | **Shadow Dart** — slowest fire rate of any M1, highest single-shot damage; a true sniper | **Mark for Death** — marks a target; the next hit from *anyone on your team* against them deals bonus damage | Bonus damage on unaware targets |
| **Radiant** (Light) | Support | **Light Lance** — held channel-beam, damage ramps the longer it stays on one target (the only non-discrete-shot M1) | **Blessing** — shields an ally or self for a chunk of absorb damage; Radiant's only ability that isn't self-focused | Allies near Radiant also regen out-of-combat health slowly |
| **Toxin** (Nature) | Area denial/DoT | **Spore Burst** — lobbed, tap again mid-air to detonate on command instead of on impact | **Corrosive Cloud** — instantly surrounds Toxin's own position with a lingering poison cloud (holds ground, doesn't travel) | DoT you apply heals you slightly (lifesteal-on-DoT) |

### Technique Pools (launch: 8 per pool)

Every entry below was checked against the others in its pool for the "distinct verb" rule (Pillar 4) — no two Mobility Techniques move you the same way, no two Defense Techniques protect you the same way, and only one Element in the entire game gets a blocking wall.

**Mobility Techniques:**

| Technique | Originally from | What makes it mechanically distinct |
|---|---|---|
| Heat Rush | Pyro | Held sprint that builds Heat the longer it is held; above a Heat threshold, incoming ranged hits are reduced — mobility that hardens you the longer you commit to it. Everyone can read it: the flames at your feet, the rising heat lines and your body's glow all climb with Heat, and a reduced hit sparks where it lands |
| Frost Slide | Cryo | Ground slide leaving a slick trail; enemies who cross it slip and slow — becomes a zone after you leave, not just personal movement |
| Chain Lurch | Voltaic | Short teleport directly to a nearby enemy — target-locked, not directional |
| Tremor Vault | Terra | Briefly burrows, pops up at a chosen nearby spot — ground-only, no vertical option, reads completely differently from a dash |
| Gust Jump | Zephyr | Double jump / short glide — the only vertical-mobility option in the pool |
| Fade Step | Umbra | Briefly intangible — walk through enemies and thin obstacles, no distance gained, just a window of being unstoppable |
| Lightstep | Radiant | Sustained speed + hop buff over a few seconds — a pacing outlier next to everyone else's instant burst |
| Overgrowth Vault | Toxin | Plants a vine; a second activation (by you or an ally) launches whoever uses it — the only Mobility Technique that can help a teammate |

**Defense Techniques:**

| Technique | Originally from | What makes it mechanically distinct |
|---|---|---|
| Cinder Shield | Pyro | A see-through shield held up in one hand that absorbs damage and glows hotter the more it takes; if it bursts, it releases a heatwave toward where you are facing — punishes whoever pops it. Expiring releases nothing |
| Chill Aura | Cryo | Passive slow-and-freeze zone around you — a melee deterrent, not a blockable object |
| Static Field | Voltaic | Redirects a % of incoming ranged damage into extra Ultimate charge — defense that doubles as a tempo tool |
| **Bulwark Wall** | Terra | The one wall in the entire game — full projectile/sightline block. Valuable specifically because nothing else does this anymore |
| Deflect Gust | Zephyr | Timed parry that reflects one projectile back at its owner |
| Decoy Double | Umbra | Spawns a stationary illusion enemies may mistake for you — the only misdirection tool in the game |
| Cleansing Ring | Radiant | An expanding pulse that cleanses allies it passes through — team-facing, not self-facing |
| Antidote Cloak | Toxin | Self-cleanse, and poisons anyone who melees you while it's active — punishes attackers, not just protects |

**Ultimate Techniques:**

| Technique | Originally from | What makes it mechanically distinct |
|---|---|---|
| Ring of Fire | Pyro | Trace a circle with your aim; closing it arms it, and a snap erupts fire filling the circle, bigger and hotter if your Heat is high — a visible circle enemies can read and escape, high commitment, high payoff |
| Cryo Beam | Cryo | Cryo floats briefly upward, charges through a visible windup, then fires a massive forward beam — high commitment, high payoff, same telegraphed philosophy as Ring of Fire |
| Thunderclap | Voltaic | Instant single burst, no zone, no delay — pure "right now" damage |
| Seismic Slam | Terra | Pure knockback + damage — displaces enemies rather than punishing them for standing still |
| Cyclone | Zephyr | Pulls and juggles into a cluster — sets teammates up, doesn't damage much itself |
| Nightfall | Umbra | Vision-denial + reveals enemies only to you — an intel Ultimate with near-zero direct damage |
| Radiant Judgment | Radiant | A beam that damages enemies and heals allies who pass through it — dual-purpose by target, not one-note |
| Bloom | Toxin | Delayed multi-point detonation — plants seeds that silently grow, then erupt everywhere at once; rewards pre-placement over reaction |

All three pools launch even at 8 options each by design (every Element contributed exactly one Mobility, one Defense, and one Ultimate entry). Keep it that way as new Techniques ship post-launch — an Ultimate-heavy or Mobility-starved pool is a real balance smell, not a cosmetic imperfection (see Section 15).

### Cross-Element mixing is a feature, not a bug

A player can run Pyro's kit with Frost Slide and a Voltaic Ultimate — visually and thematically that reads as "an elementalist who's borrowed power," not something to patch out. It's a distinct identity from Blox Fruits (locked to one fruit) and Jujutsu Shenanigans (locked movesets), and it gives skilled players a genuine hidden-information edge: your M1 is obvious from the first shot, but your 3 Techniques stay unknown to the opponent until used. For players who want visual coherence anyway, **Technique reskins** (Section 7) let a borrowed Technique's VFX be recolored to match your Element's palette. That's a cosmetic sale, not a balance decision.

### Intentional asymmetry (per design direction: some unevenness is fine, uniqueness matters more)

This kit set does not aim for perfect symmetry, and that's deliberate:

**Voltaic** (Chain Bolt + Overcharge) is a genuine snowball kit once it gets rolling — it should feel a little scary in skilled hands.  
**Radiant** is intentionally weaker in a straight 1v1 Duel and stronger in Squad Clash — almost everything in its kit (Blessing, Cleansing Ring, Radiant Judgment's heal side, the passive team-regen) helps a teammate rather than the caster.  
**Terra** moved further than any other kit from "turtle tank" to "aggressive tank" with the charge-and-knockdown identity — this is the single biggest swing from the original design and the one to watch closest in actual playtesting.

### Counter web (a few load-bearing examples, not exhaustive)

Bulwark Wall blocks Fireball, Chain Bolt, and Shadow Dart — the only hard counter to ranged M1 pressure, which is exactly why there's only one of it.  
Cleansing Ring and Antidote Cloak remove Chill stacks, Vine/root effects, and Toxin's DoT — support/cleanse Techniques counter control and attrition wherever they came from.  
Nightfall counters mobility-heavy loadouts built around Gust Jump or Fade Step — you can't juke what reveals your outline.  
Static Field punishes teams that lean on sustained ranged pressure (Wind Blade, Light Lance) by feeding the Voltaic user's Ultimate faster the more they're shot at.

**New player unlock path:** Start with the Pyro, Terra, and Radiant Elements (one of each archetype: aggro, tank, support), plus one starter Technique per pool (Heat Rush / Bulwark Wall / Ring of Fire) — a new player's first loadout is complete and legible from match one. Unlock the remaining 5 Elements and 21 Techniques through any of three paths: free progression (Elements via account level; Techniques via reaching Mastery rank 3 on their originating Element, see Section 5), spending Sparks (earned by playing or bought with Robux, for unlocking a specific piece sooner), or a direct Robux purchase (instant, for skipping the grind). Every path lands on the identical piece — an Element or Technique bought with Robux plays exactly like one earned for free, only faster to reach.

## 3. Combat & Movement Systems

**Health baseline:** 100 HP, tunable per element only through passives/shields, never raw HP stat differences (keeps balance legible).  
**Health regeneration:** health holds for 2 seconds after any damage, then refills on its own at a slow, steady rate (1 HP per second as a starting point) — smoothly, never in visible steps, the same way the Mana bar refills.  
**TTK target:** 1.5–2.5 seconds for a skilled duel at close-mid range — fast enough to feel punchy, slow enough that positioning and utility matter (RIVALS' target band, adjusted for ability-assisted combat).  
**Mana pool:** Regenerates passively. M1 costs a small amount of Mana, set per M1 so that firing at its maximum rate still spends less per second than the pool regenerates — M1 alone can never empty the bar, and a shot is never refused for lack of Mana. In practice it is limited by its own fire rate/charge behavior, so it always feels like a "gun," spammable within its own rhythm. Primary Ability and Mobility/Defense Techniques draw from Mana. The equipped Ultimate Technique is charge-based (built from damage dealt/taken) rather than mana-gated, so it can't be hoarded indefinitely.  
**Movement:** Uniform base move speed across all elements (modified only by passives like Cryo's post-hit speed or Zephyr's air control) — this preserves aim-focused gunfights instead of turning into a mobility-stacking contest.  
**Shared movement set:** everyone moves the same RIVALS-style way, whatever their Element: sprint is automatic (no walk key, no stamina), crouch lowers the body and hitbox rather than just the camera, a slide from speed lasts only as long as the player is actually sliding (it ends on letting go of crouch, leaving the ground, hitting a wall or another player, or slowing below slide speed), and a slide-jump carries the slide's speed into the air — so jumping early in a slide carries further than jumping late.  
**Mobile controls:** Tap-and-hold auto-fire toggle for M1, a dedicated button for Primary Ability, swipe gestures for equipped Mobility and Defense Techniques, single large button for the Ultimate Technique, camera-assist (not aim-assist) for tracking on touch input only.  
**Separate matchmaking pools for mobile and PC/console** — the single highest-confidence, most directly borrowed mechanic from RIVALS. Never mix input types in ranked.

### Eliminations & ragdolls

Every elimination ends in a ragdoll. The moment a player's health reaches 0, their character goes limp as a physics ragdoll instead of Roblox's default fall-apart death, thrown along the direction of the killing hit — harder the bigger the hit, so a Seismic Slam launches a body while an Icicle Shard tips one over. The ragdoll is what makes a kill feel landed, and it is the stage every kill effect plays on (Section 7).

**Same for everyone, never for sale.** Ragdolls are part of how combat feels, not a cosmetic — no purchase changes how a body falls.  
**A body is scenery, not cover.** A ragdoll has no hitbox and blocks nothing: projectiles, beams, sightlines, and players all pass through it. A body can never become a second wall (Bulwark Wall stays the only one, Section 2), and it can't be hit for damage or Ultimate charge.  
**Nothing depends on where it lands.** The eliminated player is already out of the round, so each player's device can simulate the ragdoll on its own — it's cheap, and no rule reads where a body lies.  
**Bodies clear quickly.** A body stays down for about 3 seconds (starting point), or until the round ends if that comes first, then leaves with its kill effect's exit beat. Squad Clash can leave ten bodies on a phone screen, so this is a performance rule as much as a clutter rule.

## 4. Game Modes

| Mode | Format | Purpose |
|---|---|---|
| **Duel** | 1v1, first to 5 rounds | Pure kit-vs-kit skill test, fast queue, main ranked mode at launch |
| **Squad Clash** | 5v5, first to 6 rounds, one life per round | Team ranked mode with an objective (channel the "Ley Line Core" to win the round outright, Valorant-plant-style) — adds macro strategy on top of aim |
| **Rift Royale** (Season 2+) | Free-for-all, continuous respawn, first to 20 kills | Casual warm-up mode, low commitment, good for new players learning kits |
| **Convergence** (weekly limited mode) | Rotating modifiers (e.g., double Ultimate charge, all-loadouts-random) | Keeps the weekly live-ops event feeling like a genuine event, not just a shop refresh |

## 5. Progression Systems

**Account Level:** Casual XP from any match, unlocks remaining Elements (see Section 2) and account-level cosmetic slots. Caps around level 30.

**Mastery per Element:** Separate XP bar per Element, built through use, not purchase. Reaching **Mastery rank 3** on an Element unlocks that Element's three original Techniques (its former Mobility/Defense/Ultimate contribution) into your Technique pool for free — this is the main free path to a full Technique collection, and it directly rewards actually playing every Element instead of only ever touching the strongest one. Further rewards: Element-specific cosmetic trims at Mastery 5/10/15, a Mastery emblem badge at Mastery 20 (pure flex, displayed on profile and pre-match lobby — the "I have 500 hours on Pyro" bragging signal).

**Ranked Ladder:**

| Tier | Sub-ranks | Reset cadence |
|---|---|---|
| Ember | I–III | — |
| Ash | I–III | — |
| Storm | I–III | — |
| Tempest | I–III | — |
| Eclipse | I–III | — |
| Ascendant | Top ~500 per region, no sub-ranks | — |

Season length: ~2 months (matches Grow a Garden/Pet Sim's cadence for "something new to chase" without season fatigue). Peak-rank-based rewards at season end: an animated cosmetic trail, a title, and a rank-specific emblem — never a power item.

## 6. Economy

**One persistent currency.** Sparks is the only currency that carries between matches — Prisms, the old separate Robux currency, is dropped as of v0.3. Sparks can be earned by playing or bought directly with Robux, and both land on the identical thing: Robux only skips the wait. What Prisms used to buy (cosmetic bundles, Cache Keys, the Season Pass, direct skin purchases, instant Element or Technique unlocks) is now bought with Robux directly (Section 8).

**Currencies:**

| Currency | Type | Earned via | Spent on |
|---|---|---|---|
| **Mana Shards** | Soft, in-match only | Round wins/losses | Attunement Phase in-round upgrades (temporary, reset each match — cosmetically visible but not power-imbalancing across a full match since both teams earn them) |
| **Sparks** | Persistent — the only persistent currency | Match completion, dailies, Contracts, or bought directly with Robux | Opening cosmetic Caches at low rarity tiers, buying specific common skins from rotating shop, unlocking a specific Element or Technique early |

**Sinks:** cosmetic shop rotation (Sparks + Robux), Cache Keys (Robux), Season Pass (Robux, one-time per season), Skin Ascension (combining duplicate skin drops + Sparks to evolve a skin to an animated "Mythic" tier — a grind-toward-something loop with no power effect), Element and Technique unlocks (Sparks or Robux — roster access only, see Section 2).

**Sources:** match completion (Sparks), daily login (small Sparks trickle), weekly Contracts (larger Sparks + occasional Keys), ranked season-end rewards (cosmetic only), party-queue bonus (bonus Sparks for playing ranked with a friend — direct mechanical reward for inviting someone), Sparks bought with Robux (identical to earned Sparks).

## 7. Cosmetics & the Trading Layer

This is the structural addition that neither RIVALS nor Elemental Battlegrounds has, and it's the piece most likely to drive session length and social pressure.

**Character skins:** full-body reskins per element (e.g., Pyro's "Inferno Reaper" recolors the base humanoid, doesn't change hitbox).  
**Spell VFX skins:** the highest-monetization surface in the game, because a spell effect is on-screen constantly during every fight, unlike a gun skin that's mostly seen by the shooter. Example: "Void Fire" recolors Pyro's Fireball into black/purple flame with a different particle trail. These should be the most numerous and most frequently released cosmetic type, and should cover M1 and Primary Ability alike.  
**Technique reskins:** a category that only exists because of the Technique system (Section 2) — since a loadout can carry a Technique from a different Element than your own, a reskin lets you retint a borrowed Technique to match your chosen Element's palette (e.g., a Pyro user's borrowed Cryo Beam Ultimate rendering in ember-orange instead of icy blue). This is pure visual coherence for players who want it, sold separately from the base Technique unlock.  
**Kill effects:** what plays on an eliminated player's body, set by whoever landed the kill — the one cosmetic every opponent is guaranteed to see, at the exact moment they lost. Every player has the basic kill effect; a few skins come with a special one (see Kill effects below).  
**Rarity tiers:** Common → Rare → Epic → Mythic (animated, particle-heavy top tier).  
**Trading:** Seasonal-event VFX skins (never re-released, following the Adopt Me/MM2 scarcity model) become tradeable **after a 3-day hold period** to prevent instant bot-market scalping. An in-client "recent trade value" tracker (not an official price list, just recent-trade transparency) reduces the scam vulnerability that historically hurt Adopt Me's trading community. A short in-game tutorial on safe trading is required before a player's first trade (an "Attunement License," functionally identical to Adopt Me's Trade License, which measurably reduced scams there).  
**Why this matters structurally:** trading is the single most repeatable social mechanic identified in the wider research (it underlies Adopt Me, Blox Fruits, MM2, Pet Sim 99). Bolting it onto RIVALS' cosmetic model, rather than onto gameplay power, gets the social/retention benefit without touching pay-to-win risk.

### Kill effects

A kill effect plays in the world, on the eliminated player's ragdoll (Section 3) — never as a screen overlay. It belongs to the player credited with the kill (the final hit), and everyone who can see the body sees it: the killer, both teams, and spectators. Every kill effect has two beats:

1. **The hit** — at the moment of the kill, on the body as it falls.
2. **The exit** — when the body clears (about 3 seconds later, or at round end), the effect takes the body away.

**Basic kill effect (everyone, free, the default).** Drawn in the game's comic style and deliberately Element-neutral, so it never misreports who landed the kill. The hit is the **KO!** callout — red lettering on a white jagged burst — over the falling body; the exit pops the body away in a puff of ink and Ben-Day halftone dots. It is short, readable at any distance, and the baseline every special effect is measured against.

**Special kill effects (a few skins only).** A small, deliberate set of skins each come with their own kill effect, themed to that skin, which replaces both beats of the basic one whenever the killer has that skin equipped — for example, a special effect on "Void Fire" could burn the body away in black/purple flame instead of the ink puff.

**Few, on purpose.** Only a few skins get one, not every skin — that scarcity is what makes a special kill worth chasing.  
**It belongs to the skin.** A special kill effect is never sold, earned, or traded on its own. It comes with its skin, and if that skin is tradeable, the effect trades with it.  
**One at a time.** If two equipped skins both come with one, the player picks which plays, in the Loadout.

**Rules for every kill effect, basic and special:**

**Cosmetic only.** It plays only after the server confirms the kill, and never changes damage, hitboxes, the ragdoll, respawn timing, or when the next round starts.  
**Short.** The hit beat is over within about 2 seconds (starting point), and a round that ends on that kill moves on regardless.  
**Readable, not blinding.** It stays on and around the body — no full-screen flash, and no smoke or darkness that hides a live fight, because Squad Clash keeps fighting around bodies. It honors the Reduce Flashing setting.  
**No killer, basic effect.** A kill with no player behind it (a fall, for example) plays the basic effect.

## 8. Monetization Plan

All Robux spend is cosmetic or convenience-to-cosmetics, never power. Suggested starting price points (tune after soft launch):

| Item | Price (Robux) | Notes |
|---|---|---|
| Single common VFX skin | 150–250 | Direct purchase, no gacha |
| Single Epic VFX skin | 400–600 | Direct purchase, no gacha |
| Cache Key | 100 | Opens a Cache with disclosed odds — cosmetic pool only |
| Elemental Cache | Earned via Sparks or bought with a Key | Weighted toward Common/Rare, small chance of Epic, no Mythic (Mythic is earned only via Ascension, never bought outright — this keeps the top cosmetic tier feeling earned, not purchased, which matters for long-term trust) |
| Sparks | Set at soft launch | The same Sparks earned by playing — Robux only skips the wait |
| Rift Pass (season battle pass) | ~950 | Free + Premium track, includes cosmetics, Sparks, and a small Sparks coin-back |
| Character skin bundle | 500–800 | Full-body reskin, standalone |
| Skin with a special kill effect | +200–400 over the same skin without one | The kill effect is what the extra buys — the one cosmetic every opponent is guaranteed to see. Never sold separately from its skin |
| Element unlock (skip the grind) | 150–350, scaling with how late it sits in the unlock order | Instant access to one of the 5 non-starter Elements' full bundle: M1, Primary Ability, and Passive. Also purchasable with Sparks alone for free-to-play players — Robux only removes the wait, not the free path |
| Technique unlock (skip the grind) | 75–150 | Roughly a third the price of an Element unlock, since it's roughly a third the content. Also purchasable with Sparks; free via reaching Mastery rank 3 on the Technique's originating Element |
| Technique reskin | 100–200 | Cosmetic retint of a borrowed Technique to match your Element's palette; no effect on the base unlock |

**Guardrails (non-negotiable):**

Odds disclosure on every Cache, clearly displayed before purchase.  
No Cache contents ever affect stats, cooldowns, or hitboxes.  
Element and Technique unlocks change *when* a player gets a piece, never how strong that piece is — a level-3 account and a level-20 account playing the same Element or Technique play it identically. This is a roster-access purchase, the same category as a League of Legends champion or a Brawl Stars brawler, not a stat purchase.  
Sparks (the progression currency, and the only persistent one) must always be earnable through play at a reasonable rate — a free player should never feel structurally blocked from cosmetic variety or the full roster, only slower.  
Kill effects are cosmetic end to end — no damage, hitbox, ragdoll, respawn, or round-timing difference between the basic effect and any special one.

## 9. Live-Ops Calendar & Retention Systems

**Daily:** login streak (small Sparks trickle), 2–3 daily Contracts (e.g., "land 15 Ultimate hits," "win 3 rounds as Cryo").  
**Weekly:** new Contract line refresh (Sunday), **Convergence event** — a 60–90 minute limited window (Saturday) with boosted Cache drop rates and a rotating gameplay modifier, deliberately modeled on Grow a Garden's and Steal a Brainrot's "admin abuse" urgency windows, but tied to a cosmetic Cache rather than a pay-to-win boost.  
**Monthly:** rotating shop refresh, a themed cosmetic set (not always seasonal-scale), plus 1–2 new standalone Techniques added to the pools — this is the cadence that answers "won't we run out of Elements": Techniques ship far more often than Elements because each one is a fraction of the design and balance work.  
**Seasonal (~2 months):** ranked reset, one new Element added (post-launch content drop — evergreen expansion), one new map, a season-exclusive tradeable cosmetic set that is retired at season end. Every new Element also seeds 3 new Technique pool entries (its own would-be Mobility/Defense/Ultimate), so each seasonal Element drop does double duty: one new M1+Primary+Passive identity, plus 3 more build options for everyone else.

## 10. Social & Virality Systems

**Duel Pad challenge:** step on a pad to instantly challenge a nearby player to a 1v1 — directly borrowed from RIVALS, proven to drive spontaneous competitive engagement.  
**Party queue bonus:** bonus Sparks for ranked matches played in a party — a direct mechanical incentive to invite friends, not just a social nicety.  
**Highlight Reel:** the client auto-captures your best moment each match (biggest multi-kill, clutch round win, best Ultimate) as a short shareable clip, ready to post — this engineers the "clip-worthy moment" pattern common across breakout games instead of leaving it to chance.  
**Trading:** as above, makes other players structurally necessary for full cosmetic collection.  
**Leaderboards:** per-element Mastery leaderboards (not just overall rank) give more players a leaderboard they can realistically top, which broadens bragging-rights participation beyond just the top 1% of ranked players.

## 11. Onboarding & New Player Experience

First 3 matches are against bots tuned to lose gracefully, teaching M1 aim, one Primary Ability use, one Technique use, and one Ultimate use per match.  
Starter set of 3 Elements (Pyro/Terra/Radiant) covering the three core archetypes, plus one starter Technique per pool (Heat Rush/Bulwark Wall/Ring of Fire), so a new player's first real matches use a complete, legible loadout instead of being overwhelmed by 8 Elements and 24 Techniques at once.  
A one-time "Attunement License" tutorial (trading safety) gates the first trade, not general play — no early-game friction.

## 12. Anti-Cheat & Fair Play

Server-authoritative hit detection on all M1 and Primary Ability casts (client-side prediction for feel, server validation for damage) — non-negotiable for a skill-based ranked mode.  
Public-facing anti-cheat messaging modeled on RIVALS' approach (they publicize blocked-cheat-attempt counts) — this is a trust signal that measurably supports ranked retention.  
Permanent bans, no appeals for confirmed exploiting, communicated clearly at signup.

## 13. Post-Launch Roadmap (first four seasons)

| Season | New Element | New Techniques (within-season, monthly) | New map | Ranked/mode change |
|---|---|---|---|---|
| Launch | 8 Elements, 24 Techniques live | — | 2 maps | Duel + Squad Clash |
| Season 1 | 9th Element (community-voted theme, e.g. "Metal") — seeds 3 more Techniques | 2–3 standalone Technique drops | 1 new map | Introduce per-Element Mastery leaderboards |
| Season 2 | 10th Element — seeds 3 more Techniques | 2–3 standalone Technique drops | 1 new map | Add Rift Royale FFA mode |
| Season 3 | No new Element — balance/rework pass instead | 2–3 standalone Technique drops, prioritized toward any pool that's fallen thin | Map rework | Add Mythic Ascension system |
| Season 4 | 11th Element — seeds 3 more Techniques | 2–3 standalone Technique drops | 1 new map + first "arena" spectator mode | Community tournament infrastructure (in-client bracket tool) |

Community-voted element themes (borrowing Grow a Garden's practice of teasing updates on the developer's own TikTok before release) double as a marketing beat each season.

## 14. Success Metrics to Track

**Day-1 retention ≥ 25%**, median session ≥ 8 minutes (soft-launch gate before any marketing spend — if this fails, the kit design or onboarding needs work, not the marketing plan).  
**Matches per session ≥ 3** (signals the round-based loop is compelling on its own).  
**Convergence event CCU lift ≥ 40%** on event days (validates the weekly FOMO cadence is working without pay-to-win).  
**Trade volume per active trader ≥ 1/week** by month 2 (validates the trading layer is actually creating social dependency, not sitting unused).  
**Cosmetic ARPDAU** tracked separately from Season Pass revenue, to see whether VFX skins are outperforming character skins as hypothesized (Section 7), and whether skins with a special kill effect outsell comparable skins without one.

## 15. Key Risks & Mitigations (condensed)

| Risk | Mitigation |
|---|---|
| M1s drift toward AoE spam, losing the "aim matters" identity | Every M1 must be aim-based by design rule (Pillar 1); playtest TTK against a pure-aim benchmark, not just "does it feel fun" |
| Whole-kit balance was the original slow, heavy dev cost of an 8-kit design | The Element/Technique split (Section 2) directly reduces this: balancing single Techniques is lighter than balancing eight five-piece kits, and most post-launch content now ships as Techniques rather than new Elements |
| Cross-Element loadouts can create combos no single kit designer planned for | Playtest specifically for pool-level combinations, not just each Technique in isolation; keep a standing "worst 3-Technique combo" review each patch, not only a review of new additions |
| Cross-Element visual mixing could read as thematically messy rather than intentional | Frame it explicitly as the core fantasy (an elementalist who borrows power) in marketing and in-game flavor text, not as a bug; sell Technique reskins (Section 7) to players who want visual coherence instead of forcing it on everyone |
| New M1/Primary Ability split and the deliberate asymmetry (Section 2) could tip from "characterful" into "actually unbalanced" | This is an accepted trade-off per design direction, but it needs a faster balance-patch cadence than a perfectly symmetric roster would — budget for more frequent number-tuning passes than the Season 3 "rework pass" alone accounts for |
| Genre is crowded (600+ FPS titles on Roblox) | Discovery hook is the elemental-kit angle itself, positioned explicitly against RIVALS in marketing/trailers, not just "another shooter" |
| Cosmetic trading invites scams (Adopt Me's early history) | Hold period + trade-value transparency + mandatory tutorial before first trade, built in from day one rather than patched in later |
| Ragdolls and kill effects clutter a live Squad Clash fight, or cost frame rate on mobile | Bodies have no hitbox and clear after about 3 seconds; kill effects stay on the body, stay short, and honor Reduce Flashing; on low-end devices, cap how many ragdolls simulate at once and clear the oldest first |
| Spellbreak's precedent (shut down 2023 despite strong initial launch) | Its failure was a distribution problem against Fortnite/Apex/Warzone as a premium multi-platform title, not a mechanic problem — Roblox's built-in discovery feed removes that specific risk, but don't assume it removes the discovery risk entirely; still needs a genuinely distinct hook to break through the FPS category page |

## Appendix: Quick-Reference Numbers (starting point for playtesting, not final)

Base HP: 100  
Health regen: 1 HP/s, after a 2 s pause since the last damage  
Mana: 100, regenerating 7/s  
M1 Mana cost: set per M1 so cost × max fire rate stays under regen (Icicle Shard: 2 per shot at up to 3 shots/s = 6/s)  
Target TTK: 1.5–2.5s  
Match format: Best of 9 (first to 5)  
Movement: automatic sprint 25 studs/s, crouch 8; slide up to 1.1 s with a 1.2 s cooldown; slide-jump +20 studs/s  
Season length: ~2 months  
Trade hold period: 3 days  
Convergence event window: 60–90 minutes, weekly  
Loadout: 1 Element (M1 + Primary Ability + Passive) + up to 3 Techniques (1 Mobility, 1 Defense, 1 Ultimate)  
Technique pools at launch: 8 Mobility / 8 Defense / 8 Ultimate (24 total)  
Technique unlock: free at Mastery rank 3 on the originating Element, or via Sparks or Robux  
Starter loadout: 3 Elements (one per archetype) + 1 starter Technique per pool  
Full roster unlock (8 Elements + 24 Techniques): by account level ~20 and Element Mastery, or earlier via Sparks or Robux (roster access only, no stat difference)  
Persistent currency: Sparks only (earned by playing, or bought with Robux)  
Ragdoll: every elimination; no hitbox; body clears after ~3 s or at round end  
Kill effect: basic for everyone, special on a few skins; hit beat ≤ ~2 s; server-confirmed kills only
