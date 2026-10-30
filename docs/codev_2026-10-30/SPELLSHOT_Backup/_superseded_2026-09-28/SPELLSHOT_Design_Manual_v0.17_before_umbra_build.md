# SPELLSHOT — Elemental Duels
## Full Design Manual v0.17

**One-line pitch:** RIVALS' precise, mobile-first, ranked duel structure — with elemental spellcasting kits instead of guns.

**Position relative to existing top games:** Adjacent to RIVALS (ranked ladder, mobile-first matchmaking, cosmetic monetization, duel-pad challenge), Blox Fruits (elemental theme, trading economy), Elemental Battlegrounds (spellcasting fantasy, mix-and-match abilities), and Jujutsu Shenanigans (ability-kit combat). Structurally different from all four: it pairs an aim-skill-first M1 with a ranked ladder and mobile-first matchmaking (which Elemental Battlegrounds lacks), a shared cross-Element Technique pool for build variety and scalable content (similar in spirit to Elemental Battlegrounds' spell-mixing, but layered onto a competitive structure instead of a leveling sandbox), and a cosmetic-only trading economy none of the four have.

**v0.2 change note:** the kit structure now separates M1 (left-click basic attack) from Primary Ability (a distinct battle ability slot) — earlier versions of this doc conflated the two under "Primary." Every Element's kit and the shared Technique pools were also redesigned so each entry is a genuinely different mechanic, not a re-skinned copy of another entry (the old pool had multiple near-identical "wall" abilities, for example — down to exactly one now, on purpose).

**v0.3 change note (2026-09-13):** brings the manual back in line with decisions made since v0.2, and adds two new systems.
- **Added — ragdolls and kill effects.** Every elimination ragdolls (Section 3). Every kill plays a kill effect: a basic one everyone has, and a special one that comes with a few skins, which gives those skins something extra to sell (Sections 7, 8, 14, 15 and the Appendix).
- **One persistent currency.** Prisms is dropped. Sparks is the only persistent currency and can also be bought with Robux; what Prisms used to buy is bought with Robux directly (Sections 1, 2, 6, 8 and the Appendix).
- **M1 has a small Mana cost** that can never empty the bar on its own (Sections 1 and 3).
- **Health regenerates** after a 2-second pause (Section 3). *Withdrawn on 2026-09-16: health no longer regenerates (see the update below).*
- **Shared movement** — sprint, crouch, slide and slide-jump — is written in (Section 3).
- **Quick Play** is how queued matches are joined from the Hub (Section 1).
- **Still open, not changed here: max health.** This manual says 100 HP; the current build runs 150. One of the two has to move.

**v0.4 change note (2026-09-14) — Pyro kit build:** Pyro's Techniques are being rebuilt one at a time; each is written in here once approved.
- **Heat Rush replaces Ember Trail** as Pyro's Mobility Technique (Section 2) and as the starter Mobility Technique (Section 11): a held sprint that builds Heat and, above a threshold, reduces incoming ranged damage. Heat is a new per-player resource with a visible meter; its rates, the threshold and the reduction are not set yet. *(Retired in v0.7 — see below.)*
- **Cinder Shield changes** (Section 2): it is now a see-through shield held up in one hand that glows hotter the more damage it absorbs. Only a burst releases its heatwave, sent toward where you are facing; letting it expire releases nothing. Shield strength, duration and the heatwave's range are not set yet. *(Retired in v0.7 — see below.)*
- **Ring of Fire replaces Meteor Storm** as Pyro's Ultimate Technique (Section 2) and as the starter Ultimate Technique (Section 11): trace a circle with your aim, closing it arms it, and a snap erupts fire filling the circle, bigger and hotter at high Heat. Cryo Beam's comparison now points to it. Circle size, trace and snap inputs, the Heat bonus and damage are not set yet.

**Update (2026-09-16) — health:**
- **No passive health regeneration.** Health never comes back on its own; only healing abilities heal (Section 3).
- **Full health after every fight.** Returning to the Hub or starting a Solo Test restores it, just as each duel round starts on a fresh body.
- **No health in the Hub.** Nobody can be damaged there.
- **No player damage in the Training Grounds.** Players keep their health bar, but in a Solo Test they can't damage each other; only the training dummies take hits.

**v0.5 change note (2026-09-18) — Zephyr kit build, Pyro's Ultimate, maps, and combat feel.** Numbers below are playtest starting points, not final.
- **Zephyr's kit, as built** (Section 2). Its Primary Ability is now **Cross-Slash Dash**, not Blade Cyclone: hold to charge the distance, release to dash toward the point under your crosshair — in any direction, up or down included — passing through everyone in the way and slashing each of them. **Wind Blade** alternates hands in a fixed slash pattern. **Gust Jump** now gives two air jumps that keep your momentum, then a quick glide, and holding the key floats you in place for a moment. **Cyclone** forms at your crosshair and follows it while it forms, then pulls enemies from a wide radius into the funnel. **Deflect Gust** is unchanged. The Passive is only partly settled (see Section 2).
- **Ring of Fire is bigger and faster** (Section 2): a much wider circle, a quicker trace-to-eruption, and a far taller column of fire in the middle.
- **Hits count where the shot visibly passes** (Section 3). A shot is tested as wide as it is drawn, not as a hairline down the crosshair.
- **A slide-jump spends the crouch press** (Section 3): you land running, and crouching again needs a fresh press.
- **Maps are written in** (Section 4): four arena maps plus the Training Ground, a map vote before each match, and the Open Academy Hub with its Training Grounds island.
- **Still open, not changed here:** max health (100 here, 150 in the build).

**v0.6 change note (2026-09-21) — visual identity split, 2v2, ranked toggle, loadout lock, monetization tiers.**
- **Visual identity policy** (Section 0): full pop-art comic treatment is being scaled back to UI/HUD only. Maps move to a stylized-but-not-comic direction. Ability VFX is still being tested both ways, undecided.
- **2v2 mode added** (Section 4): same round structure as Duel, team-based, no objective.
- **Ranked toggle** (Section 1): Ranked is entered via a toggle on Quick Play for Duel/2v2 rather than as a fully separate locked entry, once it opens.
- **Loadout lock clarified** (Section 1): loadout changes are Hub/Training-Grounds-only; a match in progress locks the loadout for its duration.
- **New Technique Looks, a Robux-only cosmetic tier** (Sections 7–8): a bigger, bespoke redesign of a Technique's effect, one tier above a reskin, sold Robux-only rather than through the Cache. A full Element skin bundle tier is also added.

**v0.7 change note (2026-09-21) — kit structure restructure: Ultimate becomes fixed, Techniques become one flat interchangeable pool.** This resolves the "under discussion" note from v0.6.
- **Ultimate is now a fixed kit piece**, bundled with M1, Primary Ability, and Passive when you pick an Element — like those three, it's never drawn from a shared pool and nobody can equip another Element's Ultimate. This is a real change from v0.2–v0.6, where Ultimate was one of the three shared Technique categories.
- **Mobility and Defense collapse into one flat, uncategorized Technique pool.** There's no more "exactly 1 Mobility + 1 Defense" quota — a loadout picks up to 3 Techniques from one shared list, in any mix. A Technique's original Mobility/Defense flavor is kept as descriptive flair, not a selection rule.
- **Every Element's kit is now 4 fixed pieces (M1, Primary Ability, Passive, Ultimate) + up to 3 interchangeable Techniques** — up from 3 fixed + 3 pooled. Total pieces per full loadout stays about the same (6–7), since Ultimate simply moved from the pooled side to the fixed side.
- **Pyro and Voltaic, as damage-only Elements, no longer contribute to the Technique pool at all.** Cinder Shield and Heat Rush (Pyro) and Static Field and Chain Lurch (Voltaic) are retired — none of the four is a damage ability, so none fits a damage-only kit's own identity, and under the new rule an Element's pool contribution has to match its role rather than fill a category quota. The other 6 Elements' pool contributions are unchanged (12 Techniques total, down from 16 Mobility+Defense).
- **Heat is retired as a resource.** It was built exclusively by holding Heat Rush, which is now gone; nothing else builds Heat. Ring of Fire still works exactly as before at its base values — it never depended on Heat to function, so nothing about Pyro's own kit is weaker, but the Heat-bonus scaling on Ring of Fire no longer has anything to trigger it.
- **Voltaic's Static Field is retired**, so its counter-web listing (Section 2) — "punishes teams that lean on sustained ranged pressure by feeding the Voltaic user's Ultimate faster" — no longer applies and has been removed.

**v0.8 change note (2026-09-23) — Ability VFX visual-identity baseline resolved, exception model documented.** Section 0's "still being tested both ways, undecided" note is closed out.
- **Flat pop-art comic-toon is now the confirmed default for Ability VFX**, not one of two options under test — opaque materials, no transparency, no glow shaders, baked flat tone bands, hard inked outlines, on every ability unless a specific exception is granted. This matches how Cryo's four finished pieces (Flash Freeze, Frost Slide, Chill Aura, Cryo Beam) were actually built, and it's now the stated policy going forward, not just an inferred-from-precedent default.
- **Exceptions are per-piece, not project-wide**, granted when the flat treatment isn't landing as impactful on a specific effect after real attempts — not a general license to go non-comic.
- **Two exception directions exist and don't resemble each other**: vivid/stylized/glowing (real transparency + lighting, leaned deliberately away from photorealism) vs. muted/physically-grounded (soft realistic shading, desaturated, real physics motion, no glow). Any future prompt working under a granted exception must state which of the two it means, rather than leaving it to be inferred.
- **Full physical realism was tried once, on the project's single most prominent effect, and reverted** — translucent/volumetric realism read as weak and insubstantial rather than impactful. It's not a direction to try again anywhere in the project.

**v0.9 change note (2026-09-23) — Ability VFX baseline flips from flat-comic-default to muted/grounded-default; several downstream questions opened, not yet resolved.** Prompted by a reference render of Terra's Boulder Shot (M1) built outside this session, in the muted/physically-grounded style v0.8 had only documented as an occasional exception.
- **Ability VFX's default is now the muted/physically-grounded direction** (real lighting response, desaturated/grounded palette, one deliberate glow accent per ability), not flat pop-art comic. UI/HUD and Maps policy are unchanged.
- **Open, unresolved — flagging rather than guessing:**
  - **Cryo's four finished pieces** (Flash Freeze, Frost Slide, Chill Aura, Cryo Beam) were built under the old flat-comic-default and are now visually inconsistent with the new baseline. Whether they get redone, or stand as a documented legacy exception, hasn't been decided.
  - **The actual Roblox technical construction method behind the new style isn't documented yet.** The flat-comic approach had a confirmed, code-audited technique (inverted-hull outline shell, vertex-color-baked `SmoothPlastic` materials). The grounded style's equivalent — what materials, lighting setup, and geometry pipeline actually produced the Terra render — needs the same kind of direct confirmation before it can be written into the VFX skill as a hard constraint; right now it's known only from watching a render, not from an audit.
  - **The Technique-reskin and Technique Look cosmetic tiers (Sections 7–8)** were designed around flat-comic's cheap vertex-color-swap reskinning. Under real-lighting-dependent material response, a reskin likely requires real per-asset re-tuning rather than a palette swap — this may need rework, not just re-documentation, and hasn't been addressed.

**v0.10 change note (2026-09-24) — project owner confirms this is a full scrap-and-remake, not a one-render precedent; two of v0.9's open questions resolved, two still open.**
- **Confirmed directly by the project owner: comic is off for the whole ability-VFX/character/cosmetics layer**, not a Terra-specific one-off. Every Element's kit gets rebuilt in the muted/physically-grounded direction over time, not just new work going forward.
- **UI/HUD and kill-effect callouts (the "KO!" burst) stay full comic** — confirmed explicitly, matching what v0.9 already assumed. This split is now settled, not an assumption.
- **Cryo's four finished pieces (Flash Freeze, Frost Slide, Chill Aura, Cryo Beam) are flagged for a redo pass**, read as included under "scrap and remake" rather than kept as a standing legacy exception. If that reading turns out wrong, correct it before any Cryo rebuild work starts.
- **Visual read on Terra's Boulder Shot is now confirmed by direct frame inspection**, not just secondhand description: chunky voxel/cube-built character and boulder, soft directional shading with visible ambient occlusion in creases, no outline anywhere, muted tan/brown/slate palette, and exactly one glow accent (the crack lines, which visibly brighten/branch through the charge windup — a charge-level tell, not decoration). This matches v0.9's description. **Still not confirmed: the actual Roblox technical construction** (materials, lighting setup, whether real transparency is involved anywhere) — that still needs a direct audit of the built asset, not another look at a render.
- **Still open, unresolved:** whether Maps/environments get reconciled into this same visual language or stay their own parallel non-comic track; whether a vivid/stylized/glowing lane still exists as a further exception on top of this new default; the Technique-reskin/Technique Look economy rework (Sections 7–8).

**v0.11 change note (2026-09-24) — Cryo kit build, confirmed ahead of Section 2's tables being rewritten for the new 6-ability-per-Element structure (same pattern v0.4 used for Pyro).**
- **Ultimate — Mirror Cage replaces Cryo Beam** (Cryo Beam retired): traps the target inside a dome/hemisphere of ice-mirror panels arranged around them; the panels fire rapid ice bolts at the target from all directions at once. Based directly on a reference the project owner gave — ice rectangular panels surrounding the target, ice bullets firing from all of them simultaneously (reflections and characters in that reference are not part of the design). A faint reflective tell in the panels at the moment of the kill is a nice-to-have, not a requirement.
- **Technique (Cryo's own) — Deep Freeze:** an invisible proximity trap. Nothing is visible until it triggers, at which point it deep-freezes/roots whoever set it off.
- **Technique (Cryo's own) — Blizzard:** a persistent snowstorm drops over a large area; everyone caught inside is slowed and has reduced visibility for its duration. Territory/zone-control, not a hard-lock — holding ground over time rather than punishing one target, matching Cryo's Control/Zone archetype directly.
- **Retired alongside this:** Frost Slide, Chill Aura, Cryo Beam — cut when Cryo moved to the new structure; none of the three need a VFX pass or further design work.
- **M1 (Icicle Shard), Primary (Flash Freeze), and Passive (+10% move speed for 2s after any hit) are unchanged** from Section 2's existing table — only the Ultimate and the two Technique slots changed here.
- **Cryo's full kit is now locked under the new 6-ability structure.** Section 2's tables still show the old shared-pool model and haven't been rewritten yet — that's a separate, larger pass, deferred until more Elements are finalized (Terra is next).

**v0.12 change note (2026-09-24) — Elemental Reactions system added (Section 2).**
- New cross-Element bonus-effect layer built on top of the existing Technique-mixing system: certain Element pairs trigger a named reaction when one Element's lingering status is hit by a qualifying second Element. Six reactions confirmed at launch: **Melt** (Pyro×Cryo), **Combustion** (Pyro×Toxin), **Wildfire** (Pyro×Zephyr), **Windchill** (Cryo×Zephyr), **Toxic Squall** (Toxin×Zephyr), **Shatter** (Cryo×Voltaic). Full mechanics, the four-bucket classification (status-applier / status-consumer / universal-amplifier / non-combat) used to decide which Elements belong in this system at all, and the repeatable process for adding reactions when future Elements (Aqua, Flora, Love, etc.) launch are all in Section 2's new "Elemental Reactions" subsection.
- Two weaker candidates (Toxin×Voltaic, Umbra×Toxin) and two that actively don't make sense (Terra×Voltaic, Toxin×Cryo) were considered and deliberately cut — kept on record in the manual so they aren't re-litigated from scratch later.
- **Still open:** whether reactions trigger identically for a teammate's Element in 2v2/Squad Clash as for a self-mixed Technique loadout in Duel — not resolved here.
- **Flagged for later:** reactions are a real damage layer sitting on top of the Technique pool, and Section 0's no-pay-to-win pillar says Robux never buys stat power, only faster access. Whatever a player currently has equipped should be what determines available reactions, not how much of the roster they've unlocked — needs stating explicitly wherever this gets built.

**v0.13 change note (2026-09-24) — Elemental Application (status effects) system added and HUD indicator resolved (Section 2); both were the explicitly-flagged blocker left open across v0.9–v0.12.**
- **Every Element with a real lingering effect now has a formally named status**, in a new "Elemental Application" subsection ahead of Elemental Reactions (which depends on it). Burn (Pyro), Chill (Cryo), and Poison (Toxin) are unchanged. Umbra's Mark and Radiant's Blessing already functioned as statuses and are folded in with no mechanic change. **Voltaic gets a new status, Charged** (stacks from hits; at max stacks, auto-discharges a small chain to the nearest enemy — ties into Voltaic's existing chain identity). **Terra gets a new status, Cracked** (stacks increase damage the target takes from its next hit — a "brittle rock" trope, and Terra's first real applier role). **Zephyr stays without one, on purpose** — confirmed directly rather than left to guess, to avoid forcing a "nonsense combination" the way an unwanted Reaction pair would.
- **Durations are playtest starting points, not final:** ~5s, refreshed (not extended) on reapplication, for the five stacking/DoT-style statuses (Burn, Chill, Poison, Charged, Cracked); ~8s expiring-unused for the two one-shot "primed" statuses (Marked, Blessed).
- **HUD indicator system confirmed:** a world-space icon cluster floats above a character's head, visible to anyone looking at them, showing every status currently on that character. Separately, a screen-space HUD element in the top third of the screen shows **both** the player's own active statuses and their current target's — resolving the "whose screen, showing what" question left open since the interrupted session. **Visual style is full comic pop-art for both**, matching the UI/HUD/kill-effect-callout precedent (Section 0) rather than the new muted/grounded ability-VFX baseline — these read as informational HUD, not ability VFX, even though the abilities causing them are grounded.
- **Reactions-table consequence, flagged not resolved:** confirming Charged and Cracked moves Voltaic and Terra partway out of their old Reactions buckets (Voltaic was a pure status-consumer; Terra's Fault Line was a universal amplifier needing no bespoke pairs). Both classifications are still accurate for those specific abilities, but neither Charged nor Cracked has a confirmed Reaction pairing of its own yet — whether they need one is a new open question, not decided here. See the updated bucket list in "Elemental Reactions" below.
- **Not yet built:** mechanics and HUD layout are locked here; no Opus 5.5 build prompt has been written for this yet, and nothing is implemented in Studio.

**v0.14 change note (2026-09-24) — Aqua, the first post-launch Element, kit locked; Wet status added to Elemental Application; one flagged exception to the no-transparency rule.**
- **Aqua's full 6-ability kit is locked** (Section 2, new subsection after "Intentional asymmetry"): **Riptide** (M1), **Undertow** (Primary), **Riding the Current** (Passive), **Leviathan's Maw** (Ultimate), and two Aqua-pure Techniques, **Twin Tide** and **Sidearm**. Archetype: **Control/Zone**, joining Cryo and Toxin. This is the Element named as "coming after" in v0.12's Reactions section and Section 13's Season 1 "9th Element" slot — first one actually designed, not yet built in Studio.
- **Aqua's ability VFX uses the Track 1 muted/grounded direction** (Section 0's post-v0.9 baseline, the same construction family as Terra's Boulder Shot and Cryo's finished pieces), not the comic track — confirmed explicitly by the project owner for this Element.
- **Aqua's signature accent is the Tideline:** a bright teal-white glow that rides the leading edge of whatever water is currently moving, and dies the instant that motion stops — a third variant in the per-Element accent family alongside Terra's crack (reads by *intensity*) and Cryo's Frost Line (reads by *position*); Tideline reads by *motion*. Full per-ability treatment is in the Aqua build prompt, not duplicated here.
- **One flagged, deliberate exception to the no-transparency rule (Section 0, locked since v0.8):** Leviathan's Maw's wave-wall tank uses real transparency so the shark and floodwater inside stay visible from outside throughout the ability, confirmed directly by the project owner after weighing it against the project's standing "reads weak and insubstantial" concern. This is scoped to this one asset only — it does not reopen the no-transparency rule anywhere else, and any future request to use real transparency elsewhere still needs its own explicit exception, not a precedent read off this one.
- **Wet status added to Elemental Application** (Section 2, status table): stacks from Riptide (M1) hits, same assumed pattern as Charged/Cracked — flagged for confirmation, not stated as fact. Standalone climax at max stacks (proposed, not locked): a brief loss of turn/steering control, directly reusing the "slip" flavor already established in Riding the Current rather than inventing an unrelated effect. Same 5s-refresh duration model as the other four stacking statuses.
- **Aqua joins the status-applier bucket** in Elemental Reactions (below), via Wet. Two candidate reaction pairs are flagged for a future pass, **not confirmed, not added to the reactions table**: Aqua × Voltaic ("Conductor" — water conducts electricity) and Aqua × Pyro ("Steam" — extinguishes Burn, vision-denial cloud). Per this section's own process rule, these need the one-pair-at-a-time "does this make sense" gate before they're real, not before.
- **Not yet built:** none of this is in Studio yet. Two Opus 5.5 build prompts exist for it — one for the full Element, one for the Wet status extension — see the project folder.

**v0.15 change note (2026-09-26) — Toxin reworked: archetype categories formalized, kit rebuilt around a bubble-into-cloud loop, Track 1 grounded VFX with a second flagged transparency exception.**
- **Archetype categories formalized for the first time:** Offense (Aggro), Mobility, Control/Zone, Tank, Support. Toxin stays **Control/Zone** — unchanged from its launch-era tag, just now named against a real fixed list instead of ad hoc per-Element text.
- **Toxin's full kit is reworked** (Section 2, new subsection after Aqua): M1 becomes **Toxic Bubbles**, Primary is reworked into a bubble-to-cloud conversion (keeping the name **Corrosive Cloud** for the resulting effect), Passive is unchanged (lifesteal-on-DoT), Ultimate becomes **Patient Zero** (a delayed, telegraphed mark that erupts into a cloud, worse the more allies are near the target when it pops). Nature/plant flavor (Spore Burst, Bloom, Overgrowth Vault) is dropped entirely in favor of a pure toxic/poison-gas identity. Spore Burst, the old point-blank Corrosive Cloud, Bloom, Overgrowth Vault, and Antidote Cloak are retired — see the retired-Technique table and the new Toxin subsection for what replaces them.
- **A new baseline self-damage rule:** Toxin now takes reduced (not zero) damage from its own poison by default, with no Technique required — deliberate, since a kit this strong needs a real self-risk built in.
- **Two new Technique-pool contributions replace Overgrowth Vault and Antidote Cloak:** **Antitoxin Vent** (summons a gas mask; while active, self-damage from your own poison drops to zero) and **Acid Rain** (an area-targeted poison downpour). Placement assumption, not confirmed: kept in the shared cross-Element Technique pool like their predecessors, rather than made Toxin-exclusive the way Aqua's post-launch Techniques are — flag before building if that's wrong.
- **A second flagged, deliberate exception to the no-transparency rule** (alongside Leviathan's Maw's tank, v0.14): Toxin's poison substance (bubbles, cloud puffs, Acid Rain's droplets) and the Antitoxin Vent mask's lenses use moderate, hazy translucency rather than full opacity. Scoped to these surfaces only — does not reopen the rule anywhere else.
- **A fourth signature-accent variant, Virulence:** reads by *time* — glows brighter/pulses faster the closer something is to detonating or expiring. Joins Terra's crack (*intensity*), Cryo's Frost Line (*position*), and Aqua's Tideline (*motion*) as the fourth axis in the per-Element accent family.
- **Several details flagged, not locked — confirm before or during the build:** whether the M1's bubbles pierce or are single-target; which of two scaling variants Patient Zero uses (cloud radius grows with nearby allies, vs. cloud damage/duration grows instead, recommended default: the latter, for legibility); that Patient Zero's *unscaled* base version is still worth casting in 1v1, where there are no allies to scale off; Acid Rain's exact effect (recommended default: a stacking vulnerability debuff that amplifies Toxin's other poison damage, rather than dealing direct damage itself, to avoid redundancy with Corrosive Cloud).
- **Not yet built:** none of this is in Studio yet. See the Toxin build prompt in the project folder.

**v0.16 change note (2026-09-27) — Umbra reworked: archetype formalized as Mobility, Primary and Ultimate rebuilt around "M1 is the only real damage, everything else buffs or sets it up," Techniques reshuffled.**
- **Archetype confirmed: Mobility** — slower/less kinetic than Zephyr, with that gap deliberately compensated by damage. Old tag ("Assassin/Playmaker, less damage more mobile") retired in favor of the real taxonomy.
- **Standing design law for this kit, stated directly and worth keeping on record:** Shadow Dart (M1) is Umbra's actual damage source. Every other piece — Primary, Ultimate, both Techniques — is a buff, a setup tool, or at most a minor/conditional damage source, never a competing damage instance. Check any future addition to this kit against that rule before it ships.
- **Primary replaced: Shadow Step.** A short reposition through the shadows that also briefly breaks line-of-sight/target-lock. Replaces Mark for Death, whose old wording ("next hit from anyone on your team") was genuinely dead weight in the core 1v1 Duel mode — that identity moves to a Technique instead (below), fixed to be self-only.
- **Ultimate replaced: Eclipse** *(working name, not finalized — open to a better one)*. Not a structure or trap — the whole visible environment shifts into a shadow-domain for its duration, and it deals no direct damage. Instead it grants three buffs: every enemy counts as "unaware" for the Passive's bonus-damage condition; enemies are revealed to Umbra only, through walls/fog (absorbing Nightfall's old job); and Shadow Dart's fire rate temporarily increases — the one moment the game's slowest M1 gets to feel fast. Deliberately checked against Mirror Cage (Cryo) and Leviathan's Maw (Aqua), which both already use "enclose the target in a bounded space" as their verb — Eclipse avoids that overlap by not building any structure at all.
- **Technique 1 — Mark** (replaces Fade Step in the pool, not Decoy Double): marks a target; stacks build the longer it's held, up to a cap, but the mark expires if left too long uncapitalized. A headshot on the marked target — Umbra's own hit only — deals a flat 150 bonus at full stacks. **Introduces the game's first hit-location (head vs. body) detection**, confirmed as deliberately scoped to this one Technique, not a general system to be extended elsewhere yet.
- **Technique 2 — Decoy Double, kept, clarified not changed:** a stationary illusion was flagged as an obvious tell against anyone already watching Umbra move, which is true and not a flaw to fix — its real job is winning the *first* glance (ambush recognition, or covering the moment right after a Shadow Step), not surviving sustained scrutiny.
- **Fade Step retired.** Once Shadow Step existed as Umbra's own real reposition tool, Fade Step's job read as a lighter version of something already in the kit.
- **The old "Mark" status-table entry (Elemental Application) and its "universal amplifier" classification (Elemental Reactions) are both removed**, not just edited — the reworked Mark is self-only and Technique-gated rather than an innate always-on kit status, so it no longer fits either system the way Burn/Chill/Poison do.
- **Not yet built:** none of this is in Studio yet. No Opus 5.5 build prompt written for Umbra yet.

**v0.17 change note (2026-09-27) — Umbra's VFX and character animation direction locked (Section 2, Umbra subsection updated).**
- **Track 1 confirmed for Umbra**, matching Cryo/Terra/Aqua's construction recipe. Palette anchored on Umbra's existing established color (`#B58CF0`) but weighted much darker than every other Element's ramp on purpose — void and dusk dominate, the light `glint`/`shade` tones are a rare accent rather than a base color.
- **Material grammar: obsidian** (dark glassy angular shards, Cryo's crystal family recolored) for anything solid. **A third scoped transparency exception** — after Aqua's tank (v0.14) and Toxin's poison/mask (v0.15) — for Shadow Step's dissolve/reform trail only; nothing else in the kit gets it.
- **A fifth signature-accent variant, the Tell:** reads by *exposure* — dark and inert while unseen, lights up the instant concealment breaks. Joins Terra's crack (*intensity*), Cryo's Frost Line (*position*), Aqua's Tideline (*motion*), and Toxin's Virulence (*time*) as the fifth axis.
- **Effects density confirmed as quiet-baseline, burst-at-payoff**, not constant ambient chaos — a deliberate legibility call, citing Blizzard's own Frost-Line-lost-in-haze problem as the reason to not repeat it here.
- **Full character animation direction given and locked** for Shadow Dart (tuck-and-brace precision throw), Shadow Step (dissolve/reform, no physical dash), and Eclipse (gather-between-hands, then spread to "open" the domain, plus a light-purple reveal outline on enemies). Decoy Double's cast (peels off Umbra's own body) and idle loop are set; Mark's cast is set (quick, unshowy) but **its headshot-payoff animation is explicitly flagged as unresolved** — bespoke execution effect vs. the existing skin-based kill-effect system, not decided.
- **Confirmed pipeline: animations are Blender-authored**, per this project's standing convention, not built natively in Roblox's animation editor.
- **Not yet built:** kit and VFX direction are locked here; nothing is in Studio yet. See the Umbra build prompt in the project folder.

---

## 0. Design Pillars

Every system below should be checked against these four rules. If a feature violates one, cut it or redesign it.

**Aim still matters.** Every Element's M1 must require aim (skillshot, hitscan, or a held channel that must be tracked onto a target), never auto-target or pure-AoE. This is what separates SPELLSHOT from Elemental Battlegrounds (leveling sandbox) and keeps the RIVALS-style skill ceiling intact. Primary Abilities and Techniques are not held to this rule — several are deliberately non-aim utility/setup tools.
**No pay-to-win, ever.** Robux can buy looks and roster access (which Element or Technique you get to play sooner), but never stat power inside a kit — nothing is ever stronger because of a Robux purchase, only reachable faster. This is a direct lesson from the research: Grow a Garden and Steal a Brainrot took real reputational damage ("somewhat evil," pay-to-win admin powers) that a cosmetic-and-roster-only economy avoids.
**Every system should make a friend more valuable.** Trading, party bonuses, duel challenges, and clip-sharing all exist to make "play with a friend" mechanically better than playing alone, not just socially nicer.
**Every ability must earn its slot with a distinct verb, not a distinct color.** Before adding or approving any M1, Primary Ability, Ultimate, or Technique, check it against everything else in its category. If the only difference from an existing entry is damage numbers or a palette swap (two "walls," two "dashes" that behave identically), redesign it. This is a standing rule now, not a one-time cleanup — see Section 2 for what "distinct verb" means in practice.

**Visual Identity (added v0.6, 2026-09-21; VFX baseline resolved to flat-comic-default v0.8; superseded v0.9, 2026-09-23 — Ability VFX moves off comic as the new default).** The full pop-art comic treatment (flat color-block surfaces, bold black outlines, Ben-Day halftone accents) stays locked in for **UI/HUD only** — menus, HUD, and other core interface pieces. **Maps/environments** stay on their own v0.6 direction: somewhat stylized and heightened, but explicitly *not* comic (the Skyline semi-realistic variant is the reference).

**Ability VFX (the Elements) — new default as of v0.9, replacing v0.8's flat-comic-default:** the muted/physically-grounded direction (see v0.8's exception framework — this is that same direction, now promoted from "occasional per-piece exception" to "the default for every ability going forward") is the new baseline: chunky, low-poly faceted geometry that responds to **real scene lighting** — soft gradient shading across facets, ambient-occlusion contact shadows, physics-driven debris/motion on impact — instead of flat baked tone bands and an inked outline shell. Palette per ability is desaturated and grounded/earthy, matched to the Element's real-world material (stone, ice, fire, etc.), with **one deliberate saturated accent** carrying the "this is magic" read (e.g., Terra's Boulder Shot: a glowing yellow crack through an otherwise dark, matte rock) rather than glow or saturation spread across the whole effect. Terra's Boulder Shot (M1) rework is the reference implementation for this baseline going forward, the way Cryo's finished pieces were the reference for the old flat-comic approach.

This is a real reversal, not a refinement, and it leaves genuine open questions the manual doesn't resolve yet — see the v0.9 and v0.10 change notes below. **As of v0.10, this is a confirmed full scrap-and-remake of the whole ability-VFX/character/cosmetics layer** (the project owner confirmed this directly, not just an extrapolation from one render), with UI/HUD and kill-effect callouts confirmed as the one remaining comic holdout. Cryo's four finished pieces are flagged for a redo under this reading. Still not settled: whether Maps reconciles into this same look, whether a vivid/stylized lane still exists as a further exception, the reskin-economy rework, and the exact Roblox technical construction behind the Terra reference (visually confirmed by direct inspection; not yet code-audited).

---

## 1. Core Loop

**Hub loop (persistent social space, the default resting state):** Players spawn into a central Hub, not straight into combat — mirroring RIVALS' lobby rather than a queue screen. The Hub is a walkable social space with target dummies for warm-up, the cosmetic shop, a Cache vendor, scattered **Duel Pads**, and a Loadout altar where players set their Element and up to 3 Techniques before queuing (see Section 2). Stepping on a Duel Pad next to another player instantly starts a 1v1, no queue needed. Queued matches are joined from the Hub's **Quick Play** screen — Duel, Squad Clash, and the weekly Convergence mode, with Ranked and Rift Royale shown locked until they open. Closing the screen keeps you in the queue, so players can keep warming up or browsing the Hub while they wait; casual practice and spontaneous duels never require queuing at all. Players return to the Hub after every match rather than straight into another queue — this keeps the social glue between matches, not just a menu screen.

**Loadout lock (added v0.6):** loadout changes — swapping Element or any of the up to 3 Techniques at the altar — are only accepted while in the Hub or the Training Grounds. Once a match (Duel, 2v2, Squad Clash, or any other mode) is active, the loadout is locked for its duration; a change request during a live match is rejected outright, not queued for next round.

**Ranked toggle (added v0.6):** once Ranked opens (per the Section 13 roadmap), it's entered via a toggle on the Quick Play screen for Duel/2v2, switched on before queuing, rather than existing as a fully separate always-locked entry point.

**Round loop (once queued into a match):** Spawn into the round → hold a Mana pool (regenerates slowly; M1 costs a little Mana but can never drain the bar on its own, everything else spends real Mana) → fight with M1 as your bread-and-butter → use your Primary Ability and equipped Techniques for bigger moments → build toward your Ultimate's charge (earned via damage dealt/taken, not time) → win the round by eliminating the enemy team or completing the round objective.

**Match loop:** Best-of-9 rounds (first to 5 wins), same round economy as Valorant/RIVALS: everyone earns **Mana Shards** per round (win or lose, losers earn a bit more to prevent snowballing) to spend in a pre-round **Attunement Phase** on temporary in-match upgrades (see Section 6).

**Session loop:** Start in the Hub → queue → play 2–4 matches → return to Hub, check daily Contract progress → spend earned Sparks on cosmetics or the Cache → check ranked progress → (ideally) get invited to or send a **Duel Pad** challenge to a friend right there in the Hub before logging off.

**Retention loop (weekly):** New weekly Contract line → weekend "Convergence" limited Cache window → ranked ladder reward tracking → season pass progress.

---

## 2. The Elements & the Technique System

**The core idea:** an Element fixes four things — **M1** (your basic attack), **Primary Ability** (a signature battle ability), **Passive**, and **Ultimate** — the pieces that make a matchup readable at a glance and give each Element its own feel and identity. None of these four are ever drawn from a shared pool, and nobody can equip another Element's version of any of them. Everything else in your kit — up to 3 **Techniques** — is drawn from one shared, uncategorized pool that grows independently of how many Elements exist. This is the direct fix for the content-scaling problem a fixed 8-kit design runs into: a new standalone Technique is a fraction of the design and balance work of a new Element, so build variety and post-launch content can both ship far faster than a "new Element every season" model, without ever running dry.

1 Element → fixes M1, Primary Ability, Passive, and Ultimate (unlocked together as a bundle — same number of pieces for every Element)
Up to 3 Techniques → freely picked from one shared pool, in any mix (no category quota; a slot can be left empty, but there's rarely a reason to)

M1 is not separately selectable — it comes bundled with whichever Element you choose, same as Primary Ability, Passive, and Ultimate. This is a deliberate call, not a default: letting M1 mix independently would mean an opponent's basic attack no longer tells you their Element, and that legibility matters more here than the extra build flexibility would be worth. The same logic now extends to Ultimate — an Element's Ultimate is one of the pieces that makes it recognizably *that* Element, not a build-flexible slot.

**Why an Element's Technique contribution isn't a fixed quota anymore (added v0.7):** the old rule — every Element contributes exactly one Mobility and one Defense Technique — treated the pool as a bookkeeping exercise rather than a design one. In practice it forced damage-only Elements to also "own" a defensive or mobility piece that had nothing to do with their identity (Pyro's Cinder Shield, a shield, on an Element whose entire kit is otherwise pure damage). The new rule: an Element contributes to the Technique pool only if it has something that actually fits its role. A pure-damage Element can contribute nothing at all — its own fixed kit already is its whole identity, and it doesn't need to hand a defensive or mobility tool to the rest of the roster. A mobility- or utility-leaning Element still contributes freely, since that's exactly what it's good at.

### The 8 Launch Elements — M1, Primary Ability, Passive, and Ultimate (all fixed)

| Element | Archetype | M1 (basic attack) | Primary Ability | Passive | Ultimate |
|---|---|---|---|---|---|
| **Pyro** (Fire) | Aggro/DPS, damage only | **Fireball** — slow arcing lob, splash on impact, highest per-hit damage of any M1, must be led | **Immolate** — buffs your next 3 M1 hits with bonus burn damage (a self-empower, not a new attack) | Landing a kill refunds 30% of Immolate's cooldown | **Ring of Fire** — trace a circle with your aim; closing it arms it, and a snap erupts fire filling the circle — a wide, fast circle with a towering column of fire in the middle, visible enough that enemies can read and escape it; high commitment, high payoff |
| **Cryo** (Ice) | Control/Zone | **Icicle Shard** — fast flat-trajectory, low damage, stacks Chill; 3 stacks briefly roots the target | **Flash Freeze** — a ground-zone effect (the former "Absolute Zero" asset, reused under this name): anyone who lingers past 1s is rooted, then shattered for heavy damage if still frozen when it ends | Move speed +10% for 2s after landing any hit | **Cryo Beam** — Cryo floats briefly upward, charges through a visible windup, then fires a massive forward beam — high commitment, high payoff, same telegraphed philosophy as Ring of Fire |
| **Voltaic** (Lightning) | High-skill snowball, damage only | **Chain Bolt** — instant hitscan, very short range, auto-chains to a second nearby enemy | **Overcharge** — instant short dash forward; your next M1 chains to 2 extra targets instead of 1 | Bonus damage vs. stationary targets | **Thunderclap** — instant single burst, no zone, no delay — pure "right now" damage |
| **Terra** (Earth) | Aggressive tank | **Boulder Shot** — hold to charge, release early for less damage; the only chargeable M1 in the game | **Bulwark Charge** — Terra charges forward, gains damage reduction, knocks down whatever it hits | Gains a stacking shield while charging M1 or mid-Bulwark Charge | **Seismic Slam** — pure knockback + damage — displaces enemies rather than punishing them for standing still |
| **Zephyr** (Wind) | Mobility/Flank, less damage more mobile | **Wind Blade** — very high fire rate, low damage, pierces through multiple enemies in a line; the hands alternate in a fixed pattern — right diagonal, left diagonal, right upward, left upward — for sustained fire | **Cross-Slash Dash** — hold to charge the distance, release to dash toward the point under your crosshair in any direction (up or down included) with the hands trailing, stamping an X. It always travels the full charged distance: it passes through every character in its path and slashes each of them, and only walls and the ground stop it. Replaces Blade Cyclone (v0.5) | **Updraft** — bonus damage and bonus knockback while airborne. *Still open: whether it also means Zephyr can't be knocked out of the air, and whether v0.3's no fall damage / faster air control stay.* | **Cyclone** — a tornado forms at your crosshair and follows your aim while it forms (arms raised, twisting), then holds its spot, pulling enemies from a wide radius into the funnel and juggling them — sets teammates up, modest damage itself |
| **Umbra** (Shadow) | Mobility | **Shadow Dart** — slowest fire rate of any M1, highest single-shot damage; a true sniper — confirmed as Umbra's actual damage source, everything else in the kit buffs or deals only minor damage *(unchanged, reconfirmed v0.16)* | **Shadow Step** — a short reposition through the shadows that also briefly breaks line-of-sight/target-lock; lets Umbra relocate to a new angle or vanish right after a shot *(reworked v0.16 — see the Umbra subsection below)* | Bonus damage on unaware targets | **Eclipse** *(working name, not finalized)* — the whole visible environment visually shifts into a shadow-domain; deals no direct damage, instead buffs Umbra for its duration *(reworked v0.16)* |
| **Radiant** (Light) | Support | **Light Lance** — held channel-beam, damage ramps the longer it stays on one target (the only non-discrete-shot M1) | **Blessing** — shields an ally or self for a chunk of absorb damage; Radiant's only ability that isn't self-focused | Allies near Radiant also regen out-of-combat health slowly | **Radiant Judgment** — a beam that damages enemies and heals allies who pass through it — dual-purpose by target, not one-note |
| **Toxin** (Poison) | Control/Zone | **Toxic Bubbles** — fires bubbles that travel outward (single-target vs. piercing not yet finalized) | **Corrosive Cloud** — press Primary while a bubble is still in flight to convert it into a lingering toxic cloud at that point, instead of it landing as a normal hit *(reworked v0.15 — see the Toxin subsection below for the full picture)* | DoT you apply heals you slightly (lifesteal-on-DoT); separately, Toxin now takes reduced (not zero) damage from its own poison by default | **Patient Zero** — marks a target with a visibly growing aura; after a few seconds it detonates into a poison cloud centered on wherever they are, worse the more allies are near them *(reworked v0.15)* |

### Technique Pool (launch: 12, one shared uncategorized list)

Every entry below was checked against the others in the pool for the "distinct verb" rule (Pillar 4) — no two Techniques move or protect you the same way, and only one Element in the entire game gets a blocking wall. Each entry still carries its original Mobility- or Defense-flavor as description, but nothing enforces picking one of each anymore — pick any 3, in any mix.

| Technique | Originally from | Flavor | What makes it mechanically distinct |
|---|---|---|---|
| Frost Slide | Cryo | Mobility | Ground slide leaving a slick trail; enemies who cross it slip and slow — becomes a zone after you leave, not just personal movement |
| Tremor Vault | Terra | Mobility | Briefly burrows, pops up at a chosen nearby spot — ground-only, no vertical option, reads completely differently from a dash |
| Gust Jump | Zephyr | Mobility | Two extra air jumps on top of everyone's double jump, each keeping the momentum you already have, then a fast glide; hold the key to float in place for a moment, with wind round your legs — the only vertical-mobility option in the pool |
| Mark | Umbra | Offense/setup *(v0.16)* | Marks a target; stacks build the longer it's held (up to a cap), but the mark expires entirely if left too long uncapitalized. Landing a headshot on the marked target — your own hit only, not a teammate's — deals a flat bonus (150 at full stacks). The first ability in the game to need hit-location (head vs. body) detection, deliberately scoped to this one Technique, not a general system |
| Lightstep | Radiant | Mobility | Sustained speed + hop buff over a few seconds — a pacing outlier next to everyone else's instant burst |
| Antitoxin Vent | Toxin | Self-risk *(v0.15)* | Summons a gas mask (glowing green lenses); while active, drops your own self-damage from your own poison to zero — the whole point is giving Toxin's own base kit's self-damage risk (see Section 2's Toxin subsection) a real answer |
| Chill Aura | Cryo | Defense | Passive slow-and-freeze zone around you — a melee deterrent, not a blockable object |
| **Bulwark Wall** | Terra | Defense | The one wall in the entire game — full projectile/sightline block. Valuable specifically because nothing else does this anymore |
| Deflect Gust | Zephyr | Defense | Timed parry that reflects one projectile back at its owner |
| Decoy Double | Umbra | Defense | Spawns a stationary illusion enemies may mistake for you — the only misdirection tool in the game. Its real value window is first contact (an enemy's first glance around a corner or down a sightline) and covering an escape, not surviving sustained scrutiny — a static double can't fool someone already watching you move *(clarified v0.16)* |
| Cleansing Ring | Radiant | Defense | An expanding pulse that cleanses allies it passes through — team-facing, not self-facing |
| Acid Rain | Toxin | Offense/setup *(v0.15)* | Calls down a poison downpour over a chosen area — proposed default: a stacking vulnerability debuff that amplifies Toxin's other poison damage rather than direct damage of its own, to stay mechanically distinct from Corrosive Cloud |

**Retired in v0.7 (no longer in the pool, kept here for the record):**

| Technique | Originally from | Why it's retired |
|---|---|---|
| Heat Rush | Pyro | Pyro is a damage-only Element; a damage-reduction mobility tool didn't fit its own identity, and the pool no longer needs Pyro to fill a Mobility quota. Its retirement also retires the Heat resource (see below) |
| Cinder Shield | Pyro | Same reasoning — a shield doesn't fit a damage-only Element's own contribution, and the pool no longer needs Pyro to fill a Defense quota |
| Chain Lurch | Voltaic | Voltaic is a damage-only Element; a teleport doesn't fit its own identity |
| Static Field | Voltaic | Same reasoning — a damage-redirect shield doesn't fit a damage-only Element's own contribution |

**Heat is retired as a resource (added v0.7).** It was built exclusively by holding Heat Rush's sprint, and nothing else ever built it. With Heat Rush gone, Heat has no trigger left. Ring of Fire is unaffected in its base function — it never depended on Heat to work — it simply no longer has a bonus to scale up.

**Retired in v0.15 (Toxin rework, no longer in the pool, kept here for the record):**

| Technique | Originally from | Why it's retired |
|---|---|---|
| Overgrowth Vault | Toxin | Toxin's Nature/plant flavor (vines) is dropped entirely in favor of pure toxic/poison-gas identity; replaced by Antitoxin Vent, which also gives Toxin's kit its needed self-damage answer instead of a teammate-mobility tool |
| Antidote Cloak | Toxin | Same identity change — a self-cleanse/counter-poison effect didn't fit the reworked kit's pure-offense-hazard identity; replaced by Acid Rain |

**Retired in v0.16 (Umbra rework, no longer in the pool, kept here for the record):**

| Technique | Originally from | Why it's retired |
|---|---|---|
| Fade Step | Umbra | Once Umbra's own Primary became Shadow Step (a real reposition-and-break-line-of-sight tool), Fade Step's job (shadow-mobility, no distance, a window of passing through things) read as a lighter version of something Umbra already has; replaced by Mark, which gives the kit's damage identity a real setup piece instead of a second, weaker mobility tool |

All 12 pool entries come from the 6 Elements whose role includes a Mobility- or Defense-flavored identity (Cryo, Terra, Zephyr, Umbra, Radiant, Toxin — 2 each). Pyro and Voltaic, both damage-only, contribute none. **Exception, flagged (v0.15):** Toxin's two v0.15 replacements (Antitoxin Vent, Acid Rain) carry new flavors — Self-risk and Offense/setup — instead of the original Mobility/Defense pair, because the rework's design (a real self-damage risk baked into Toxin's own base kit, per the Toxin subsection below) didn't fit either label honestly. **Exception, flagged (v0.16):** Umbra's Mark, replacing Fade Step, is also not Mobility or Defense flavored — it's Offense/setup, same new category Toxin's Acid Rain uses, since Mark's whole point is setting up Umbra's own M1 rather than moving or protecting anyone. Toxin and Umbra both still count toward the "6 Elements, 2 each" tally above; only the flavor labels for the affected entries have changed. Keep new post-launch Techniques matched to their contributing Element's actual role rather than forced into a quota — a pool entry that doesn't fit its Element's identity is the mistake this revision fixes, not a pattern to repeat (see Section 15).

### Cross-Element mixing is a feature, not a bug

A player can run Pyro's kit with Frost Slide and Bulwark Wall — visually and thematically that reads as "an elementalist who's borrowed power," not something to patch out. It's a distinct identity from Blox Fruits (locked to one fruit) and Jujutsu Shenanigans (locked movesets), and it gives skilled players a genuine hidden-information edge: your M1, Passive, and Ultimate are all obvious from the first shot, but your Techniques stay unknown to the opponent until used. For players who want visual coherence anyway, **Technique reskins** (Section 7) let a borrowed Technique's VFX be recolored to match your Element's palette. That's a cosmetic sale, not a balance decision.

### Intentional asymmetry (per design direction: some unevenness is fine, uniqueness matters more)

This kit set does not aim for perfect symmetry, and that's deliberate:

**Voltaic** (Chain Bolt + Overcharge) is a genuine snowball kit once it gets rolling — it should feel a little scary in skilled hands.
**Radiant** is intentionally weaker in a straight 1v1 Duel and stronger in Squad Clash — almost everything in its kit (Blessing, Cleansing Ring, Radiant Judgment's heal side, the passive team-regen) helps a teammate rather than the caster.
**Terra** moved further than any other kit from "turtle tank" to "aggressive tank" with the charge-and-knockdown identity — this is the single biggest swing from the original design and the one to watch closest in actual playtesting.
**Pyro and Voltaic contribute nothing to the Technique pool (added v0.7)** — a direct, intentional trade-off of being damage-only Elements. They're stronger and more self-sufficient in their own fixed kit, at the cost of never being a source of build variety for anyone else's loadout.

### Aqua — first post-launch Element, kit locked (added v0.14)

**Archetype: Control/Zone**, joining Cryo and Toxin. Not one of the 8 launch Elements — this is the Element the Reactions and roadmap sections already pointed at ("Aqua, Flora, Love, or whatever comes after"; Section 13's Season 1 "9th Element" slot). Kit is locked; nothing is built in Studio yet — see the Aqua build prompt in the project folder.

| Piece | Name | What it does |
|---|---|---|
| M1 | **Riptide** | A crescent of whitewater surged along the ground — an aim-required skillshot wave (Pillar 0), not a channel or hitscan. |
| Primary | **Undertow** | Conjures a vortex at a point in front of you (a circular hand-motion cast); pulls enemies caught near it toward the vortex's *own center point*, not to the caster, and interrupts them. Quick — fast cast, short duration, snaps shut. (Earlier drafts pulled the enemy to the caster; changed because that's disadvantageous for a non-tank Element — see the dev diary for the full reasoning.) |
| Passive | **Riding the Current** | Move speed buff while riding your own wet trail (left behind by your abilities); an enemy who crosses that trail slips — briefly loses turn/steering control, doesn't fall. |
| Ultimate | **Leviathan's Maw** | Ground-slam: floodwater rises and a ring of wave-walls closes overhead into a glass-walled tank around the target(s). **Uses real transparency — a flagged, deliberate one-off exception to the no-transparency rule, scoped to this asset only** (see the v0.14 changelog note above). A shark-shape moves beneath the flooded floor, mostly hidden until it breaks the surface for a lunging bite finish — the one loud beat in an otherwise restrained kit. |
| Technique (Aqua-pure) | **Twin Tide** | Two lower, narrower wave-walls (same material as Riptide) close in on a lane from either side, not escapable by jumping. This was Aqua's original Ultimate concept, demoted to a Technique once Leviathan's Maw was invented. |
| Technique (Aqua-pure) | **Sidearm** | A held, constructed water-gun. Tap for a quick shot; hold to charge (costs more Mana) for a denser slug that knocks the target back/up on impact — confirmed the held/charged shot is the one that launches the target, not the tapped shot. |

**Ability-verb overlaps checked and resolved against the existing roster (Pillar 4):** Undertow's pull-vortex read too close to Zephyr's Cyclone in an early draft — fixed by making Undertow's pull target its own vortex point rather than sweeping a wide radius, and by cutting Zephyr's own overlap risk entirely rather than living with two similar pulls. An early Technique (a proximity trap, working name "Geyser") was too close to Cryo's Deep Freeze (both invisible-until-triggered traps) and was replaced outright — it does not appear in the locked kit above. An early Technique ("Riverbed," a slick-ground zone) was too close to Cryo's Blizzard — resolved by moving its slip effect onto the Passive instead (see Riding the Current above) and dropping Riverbed from the kit entirely once Twin Tide filled that Technique slot.

**Visual direction:** Track 1, the muted/physically-grounded baseline (Section 0, post-v0.9) — the same construction family as Terra's Boulder Shot and Cryo's finished pieces, not the comic track. Aqua's signature accent is the **Tideline**: a bright teal-white glow that rides the leading edge of whatever water is currently moving, and goes dark the instant that motion stops. It's the third variant in the per-Element accent family, alongside Terra's crack (reads by *intensity*, brighter = more charge) and Cryo's Frost Line (reads by *position*, shows how far a freeze has reached) — Tideline reads by *motion*, always at the front of whatever's currently surging. Full per-ability treatment is in the Aqua build prompt.

### Toxin — reworked (v0.15)

**Archetype: Control/Zone**, unchanged from launch — this is a full kit rework, not an archetype change. Toxin's identity drops Nature/plant flavor entirely (no more spores, seeds, vines, or a cloak) in favor of pure toxic/poison gas and clouds. Old assets (Spore Burst, the old point-blank Corrosive Cloud, Bloom, Overgrowth Vault, Antidote Cloak) are retired, not deleted — see the Technique Pool's "Retired in v0.15" table above for the two pool entries; the fixed-kit pieces move to `ServerStorage.ToxinKitSuperseded` in Studio (see the build prompt).

| Piece | Name | What it does |
|---|---|---|
| M1 | **Toxic Bubbles** | Fires bubbles that travel outward. *Not yet finalized: whether a bubble stops at the first enemy it hits or pierces through multiple* — a small open detail, doesn't block anything else. |
| Primary | **Corrosive Cloud** | Press Primary while a Toxic Bubble is still in flight and it converts into a lingering toxic cloud at that point in space, instead of landing as a normal hit. If Primary isn't pressed, the bubble lands as a normal on-hit poison tick. This is the kit's core hook — Primary reacts to your own M1 rather than being an unrelated second attack. |
| Passive | **(unchanged from launch)** | DoT you apply heals you slightly (lifesteal-on-DoT). Confirmed to carry over as-is — nothing about this changes in the rework. |
| Baseline rule (new, not tied to one slot) | **Self-damage from your own poison** | Toxin now takes *reduced* (not zero) damage from its own poison/clouds by default, with no Technique required — a deliberate self-risk baked into the base kit. Zero self-damage only comes from equipping Antitoxin Vent (below). |
| Ultimate | **Patient Zero** *(working name — "Outbreak" also floated, not finally chosen)* | Marks a target with a visibly growing, telegraphed aura. After a few seconds it detonates into a poison cloud centered on wherever the target currently is at that moment — worse the more of the target's allies are near them when it pops. **Two scaling variants, neither locked:** **Variant A** — the cloud's *radius* grows with nearby-ally count. **Variant B** (recommended default, for legibility) — the cloud's *damage/duration* grows instead, while radius stays constant. **Flagged, not resolved:** in the game's core 1v1 mode there's nothing nearby to scale off, so Patient Zero's *unscaled* base version (radius/damage/duration at zero nearby allies) must be strong enough to be worth casting on its own — the "worse near his team" clause is a group-mode bonus on top of that baseline, not the ability's whole reason to exist. |
| Technique 1 (shared pool) | **Antitoxin Vent** | Visually summons a **gas mask** on the caster — opaque rubber/metal body, straps, and filter canister, with tinted, translucent green lenses that glow while active and sit dark/inert otherwise, visible to everyone (not just the caster) as a readable "immune right now" tell. While active: your own self-damage from your own poison drops from the baseline "reduced" amount to **zero**, and you can pass through your own clouds without other penalties. *Flagged, not resolved:* whether this also reduces (even partially) damage from an *enemy's* poison in a Toxin mirror match, or is strictly own-poison-only as currently phrased. |
| Technique 2 (shared pool) | **Acid Rain** | Calls down a poison downpour over a chosen area. **Proposed default, not confirmed:** a stacking vulnerability debuff that amplifies Toxin's *other* poison damage rather than dealing direct damage of its own — chosen specifically to avoid mechanical redundancy with Corrosive Cloud's own damage cloud. A straight-damage version was also discussed as an alternative. |

**Design constraint this whole rework was checked against, worth keeping on record:** an earlier Ultimate candidate ("Reckoning" — detonate/link every existing cloud) was rejected specifically because the fixed kit (M1 + Primary + Ultimate alone) would already be lethal enough that picking Techniques becomes pointless. This is now a standing check for every Ultimate idea in this kit, not just the ones already tried.

**Flagged, not resolved:** whether Antitoxin Vent and Acid Rain stay in the **shared** cross-Element Technique pool (like the predecessors they replace, and like every other launch Element's pool contribution) or become **Toxin-exclusive** Techniques instead (like Aqua's post-launch Twin Tide/Sidearm, which are not shared). Default assumption carried in this manual: shared pool, since Toxin is a launch Element whose pool role predates this rework — confirm before building if that's wrong.

**Visual direction:** Track 1, the muted/physically-grounded baseline (Section 0, post-v0.9) — opaque MeshParts, `SmoothPlastic`, white base color with baked vertex color for tone/AO, real scene lighting, `CastShadow = true`, no comic outline shell. **Second deliberate, scoped exception to the no-transparency rule** (the first being Aqua's Leviathan's Maw tank, v0.14): Toxin's poison substance — bubbles, cloud puffs, and Acid Rain's falling droplets — plus the Antitoxin Vent mask's lenses use moderate, hazy translucency rather than full opacity. Scoped strictly to those surfaces; the mask's body, straps, and filter canister, and every other solid prop, stay fully opaque. This does not reopen the no-transparency rule anywhere else.

Toxin's signature accent is **Virulence**, the fourth variant in the per-Element accent family: it reads by *time* — glowing brighter and pulsing faster the closer something is to detonating or expiring. Distinct from Terra's crack (*intensity*), Cryo's Frost Line (*position*), and Aqua's Tideline (*motion*). Pays off hardest on Patient Zero's mark, which should visibly accelerate as detonation nears — that acceleration is the actual gameplay tell, not just flavor. A plain duration-buff like Antitoxin Vent instead gets a **steady** glow, not the accelerating version, since it isn't counting down to a payoff. Palette: murky, desaturated acid-green to sickly yellow-green — checked against the existing accent palette and doesn't collide (Voltaic and Radiant are both yellows, Umbra is purple, Aqua is teal, Terra is gold/tan).

**Not yet built:** kit is locked here; nothing is built in Studio yet — see the Toxin build prompt in the project folder. Old kit assets move to `ServerStorage.ToxinKitSuperseded` rather than being deleted, mirroring the `ServerStorage.AquaKitSuperseded` precedent.

### Umbra — reworked (v0.16)

**Archetype: Mobility** — formalized for the first time against the real taxonomy (Offense/Aggro, Mobility, Control/Zone, Tank, Support). Umbra's old tag was "Assassin/Playmaker, less damage more mobile"; the new read is more precise about *why* it's Mobility rather than Zephyr's flavor of it: Umbra is deliberately less kinetic than Zephyr, and that gap is compensated by damage rather than by more movement tools. Shadow Dart — the slowest-firing, highest-single-shot-damage M1 in the game — was already the mechanical proof of this; formalizing the archetype didn't require changing it.

**Standing design law for this kit:** Shadow Dart (M1) is Umbra's real damage source. Every other piece below — Primary, Ultimate, both Techniques — exists to buff it, set it up, or at most deal minor/conditional damage, never to compete with it as a second real damage instance. Any future addition to Umbra's kit should be checked against this before it ships.

| Piece | Name | What it does |
|---|---|---|
| M1 | **Shadow Dart** *(unchanged)* | Slowest fire rate of any M1, highest single-shot damage — a true sniper, and the kit's actual damage source. |
| Primary | **Shadow Step** | A short reposition through the shadows that also briefly breaks line-of-sight/target-lock. Lets Umbra relocate to a new sniping angle, or vanish right after taking a shot. Replaces Mark for Death — see below for where that identity went instead. |
| Passive | **(unchanged)** | Bonus damage on unaware targets — directly buffs the M1's hit rather than being a separate damage source; an unseen Shadow Dart hits harder. |
| Ultimate | **Eclipse** *(working name, not finalized)* | Not a structure or trap — the whole visible environment visually shifts into a shadow-domain for its duration. Deals **no direct damage**. Grants three buffs instead: (1) every enemy counts as "unaware" for the Passive's bonus-damage condition, so every Shadow Dart hit during the window gets the bonus; (2) enemies are revealed to Umbra only, through walls/fog — absorbs Nightfall's old intel function rather than dropping it; (3) Shadow Dart's fire rate temporarily increases — the one moment the game's slowest M1 gets to feel fast. **Checked against the existing roster for the "enclose the target" overlap** both Mirror Cage (Cryo) and Leviathan's Maw (Aqua) already use — Eclipse avoids it by building no structure at all; the "domain" is purely visual/buff, nothing physical. **Optional stretch idea, flagged, not committed:** landing a headshot while Eclipse is active could top off or refresh Mark's stacks (below), creating a real combo window between the Ultimate and the Technique — worth considering once the base three buffs are built and feel right on their own. |
| Technique 1 (shared pool) | **Mark** | Marks a target; stacks build the longer it's held, up to a cap, but the mark expires entirely if left too long uncapitalized — a real risk/reward timing window, not a fire-and-forget debuff. A headshot on the marked target — **Umbra's own hit only, not a teammate's** — deals a flat bonus, 150 at full stacks. This is the first ability in the game to need hit-location (head vs. body) detection; confirmed as deliberately scoped to this one Technique, not a general system being introduced game-wide. Replaces Fade Step in the pool (see "Retired in v0.16" in the Technique Pool table). |
| Technique 2 (shared pool) | **Decoy Double** *(kept, clarified, not mechanically changed)* | Spawns a stationary illusion enemies may mistake for you. A fair critique came up directly: a decoy that doesn't move is an obvious tell against anyone already watching Umbra move in real time — true, and not something to engineer around. Its real value window is winning the *first* glance (an enemy rounding a corner or scanning a sightline) or covering the moment right after a Shadow Step, not surviving sustained scrutiny mid-fight. A cheap "ready stance" idle loop instead of a dead T-pose is recommended so the first half-second glance doesn't immediately read as fake — doesn't need real movement AI. |

**Mark for Death is fully retired, not just renamed.** Its old wording ("the next hit from *anyone on your team* against them deals bonus damage") was genuinely dead weight in the game's core 1v1 Duel mode, since there's no teammate to capitalize on it. The replacement (Mark, above) fixes this by being self-only and moving to the Technique pool rather than staying a fixed Primary — Shadow Step took the Primary slot instead. The old Mark status-table entry (Elemental Application, above) and its "universal amplifier" classification (Elemental Reactions, above) are both removed for the same reason: the new Mark is Technique-gated and self-only, so it no longer functions as an innate, always-on per-Element status the way Burn/Chill/Poison do.

**Flagged, not resolved:** Eclipse's working name — "Nightfall" no longer fits since the mechanic moved well past vision-denial into a full buff-and-domain effect, but no replacement name is locked yet. Also open: Mark's exact stack-count/timing curve (how many stacks, how long to ripen, how long before it expires unused) and Shadow Step's exact distance/cooldown — all tunable, none of it decided yet.

**Visual direction:** Track 1, the same muted/physically-grounded baseline as Cryo, Terra, and Aqua — opaque MeshParts, `SmoothPlastic`, white base color with baked vertex color for tone/AO, real scene lighting, `CastShadow = true`, no comic outline shell. Confirmed directly, not assumed.

**Palette — anchored on Umbra's existing established color, `#B58CF0`** (the same hex already used for Umbra's Discord role, so this isn't a new invention, just extended into VFX), but pushed **much darker than the other Elements' ramps, on purpose.** Where Cryo's ramp is dominated by its pale/bright tones with the deep tone as the rare accent, Umbra inverts that: dark should be the default state and light the exception.

| Name | Color | Used for |
|---|---|---|
| glint | pale lavender-white | rare highlights only — an edge catching light, or the Tell activating (below). Never a dominant surface color. |
| shade | `#B58CF0` (the established base) | used sparingly — not the default body tone the way it would be on a brighter Element |
| dusk | deep violet | shadow facets, recesses — much more common than shade or glint |
| void | near-black, violet-tinted | cores, dominant surface tone for most of the kit |

**Shape/material grammar: obsidian, not smoke, for anything solid.** Dark, glassy, angular faceted geometry — the same family as Cryo's crystals (chunky, low-poly, baked vertex color) but reading as dark volcanic glass instead of ice. Fully opaque, no exception needed. This covers Shadow Dart's shot, Mark's visual tether/anchor, and Decoy Double's body.

**One scoped transparency exception, flagged the same way as the two before it** (Aqua's Leviathan's Maw tank walls, v0.14; Toxin's poison substance and mask lenses, v0.15) — **Shadow Step's dissolve/reform trail only.** A smoke/wisp effect needs some translucency to read as ephemeral rather than solid, and it's narrow enough to justify: the effect is brief and the character isn't standing still in it, so it doesn't risk the "weak and insubstantial" problem the project hit and reverted once already. Does not extend to anything else in the kit — Eclipse's environment shift, Mark, and Decoy Double all stay fully opaque per the standard rule.

**Signature accent: the Tell.** The fifth variant in the per-Element accent family — Terra's crack reads by *intensity*, Cryo's Frost Line by *position*, Aqua's Tideline by *motion*, Toxin's Virulence by *time*. The Tell reads by **exposure**: dark and completely inert while Umbra is unseen, and it only lights up the instant that concealment breaks — a shot fired, a hit landed, Decoy Double's illusion failing. Deliberately not tied to Mark's stack-timer, even though that was tempting, since "brighter as it builds toward a payoff" is already Virulence's job on Toxin; exposure is the more distinct, Umbra-specific read.

**Effects density: quiet baseline, concentrated bursts at payoff moments — not constant ambient chaos.** Confirmed directly against the alternative (effects happening all the time, even at rest): Umbra should look almost inert during normal play, fitting a stealth identity, and then genuinely erupt at the moments that matter. This is also a legibility call, not just taste — Blizzard's own direction note already flagged its Frost Line getting lost in its own haze, and the Frost Line's stated rule ("never used as decoration on idle ice") exists for exactly this reason. A busy baseline would bury the Tell's whole point.

**Character animation direction, given directly and specific — Blender-authored, matching this project's standard pipeline (not built natively in Roblox's animation editor):**
- **General carriage:** low, controlled, economical — a stalking/prowling quality, not Zephyr's kinetic energy or Terra's heavy weight. Umbra should look like it's always about to do something, never like it's performing.
- **Shadow Dart (M1):** the throwing arm tucks in close to the body and tilts up; a small shadow ball forms in the hand; the stance then shifts into a precision-aim mode where the other arm comes in to brace/support the throwing arm; then the release. The held brace beat *is* the readable tell that a shot is coming — no separate VFX cue needed to telegraph it.
- **Shadow Step (Primary):** no physical dash or run cycle. The character dissolves into loose shadow/smoke at the origin point and reforms at the destination — near-instant, no visible travel arc. This is the one place the transparency exception above applies.
- **Eclipse (Ultimate):** both arms first gather a compressed mass of shadow in the space between them — a held beat that doubles as this game's standard telegraphed-Ultimate windup (matching Ring of Fire's and Cryo Beam's own readable commit-before-payoff pattern) — then the arms spread outward, "opening" the mass into the domain. Once active, revealed enemies get a light-purple (`glint`/`shade` tone) outline/border around their silhouette, visible to Umbra only — a concrete, legible answer for the "enemies revealed to you" buff.
- **Mark (Technique):** the cast itself should stay quick and unshowy (a point, a glance) — it's a setup tool, it shouldn't cost tempo. **The headshot payoff is flagged, not committed:** whether it gets a bespoke, mechanic-triggered execution animation (distinct from the game's standard skin-based kill-effect system) or routes through that existing system as-is is an open question — raise it with the owner rather than picking one silently.
- **Decoy Double (Technique):** the cast reads as a shadow copy peeling directly off Umbra's own body, not conjured from nothing. The decoy itself gets a cheap "ready stance" idle loop rather than a dead T-pose, per the clarified use-case above.

**Not yet built:** kit is locked here; nothing is built in Studio yet — see the Umbra build prompt in the project folder. Old kit assets move to `ServerStorage.UmbraKitSuperseded`, mirroring the `AquaKitSuperseded`/`ToxinKitSuperseded` precedent.

### Elemental Application — Status Effects & HUD (added v0.13)

**The idea:** Elemental Reactions (below) needs real, consistently-defined lingering statuses to react to, and players need a way to actually see what's affecting them and their target mid-fight. This subsection locks both, resolving the two-question gate that had been open since v0.9.

**Confirmed statuses (2026-09-24):**

| Element | Status | What it does | Notes |
|---|---|---|---|
| Pyro | Burn | DoT ticking damage | Existing, unchanged |
| Cryo | Chill | Stacks; 3 stacks briefly roots the target | Existing, unchanged |
| Toxin | Poison | DoT ticking damage | Existing, unchanged |
| Umbra | *(removed, v0.16)* | — | Mark for Death (the old Primary) is retired along with this table entry. Its replacement, Mark, is now a shared-pool **Technique** (self-only, stacking, headshot-gated — see the Technique Pool table and the Umbra subsection below), not an innate per-Element status every Umbra player always applies, so it no longer belongs in this table the way Burn/Chill/Poison do |
| Radiant | Blessing | Primed: an absorb shield on the target | Already functioned as a status; folded in here, no mechanic change |
| **Voltaic** | **Charged** (new) | Stacks from hits; at max stacks, auto-discharges a small chain to the nearest enemy | Ties into Voltaic's existing chain identity (Chain Bolt, Overcharge). *Assumed, not stated explicitly:* stacks build from Chain Bolt (M1) hits, mirroring how Cryo's Icicle Shard builds Chill — confirm before building |
| **Terra** | **Cracked** (new) | Stacks; increases damage the target takes from its next hit | A "brittle rock" trope; Terra's first real status-applier role. *Assumed, not stated explicitly:* stacks build from Boulder Shot (M1) hits, same pattern as above — confirm before building |
| **Aqua** | **Wet** (new, v0.14) | Stacks; at max stacks, briefly reduces the target's turn/steering control | Reuses the "slip" flavor already established in Aqua's own Passive (Riding the Current) rather than inventing an unrelated effect. *Assumed, not stated explicitly:* stacks build from Riptide (M1) hits, same pattern as Charged/Cracked — confirm before building. Two candidate Reaction pairs flagged for a later pass, not confirmed: Aqua × Voltaic ("Conductor"), Aqua × Pyro ("Steam") |
| Zephyr | *(none, deliberate)* | — | Confirmed 2026-09-24: forcing a status here risked the same "nonsense combination" problem the reactions gate below warns against. Zephyr stays a pure status-consumer |

**Durations (playtest starting points, not final):**
- Stacking/DoT-style statuses (Burn, Chill, Poison, Charged, Cracked): ~5 seconds, **refreshed** (not extended) on reapplication.
- One-shot "primed" statuses (Marked, Blessed): ~8 seconds, expiring if unused.

**HUD indicator system (confirmed 2026-09-24):**
- **World-space:** an icon cluster floats above a character's head, visible to anyone looking at them, showing every status currently active on that character.
- **Screen-space:** a HUD element in the top third of the screen shows **both** the player's own active statuses and their current target's — not one or the other.
- **Visual style:** full comic pop-art for both the world-space cluster and the screen-space element, matching the UI/HUD/kill-effect-callout precedent (Section 0), not the new muted/grounded ability-VFX baseline. These read as informational HUD, not ability VFX, even though the abilities that cause them are grounded.
- **Not yet built:** locked here; no Studio work or build prompt exists for this yet.

### Elemental Reactions (added v0.12)

**The idea:** the Technique pool already lets a player mix a Technique from any Element into their own loadout (see "Cross-Element mixing" above). Elemental Reactions is the next layer on top of that: some Elements apply a status that lingers on a target past the initial hit, and hitting that lingering status with the right second Element triggers a bonus effect. This rewards exactly the kind of loadout diversity the Technique pool already encourages, and gives 2v2/Squad Clash a genuine "my Element plus your Element" payoff beyond just standing near each other.

**Not every Element belongs in this system, and that's by design.** Before adding any Element to the reaction table, classify it:
- **Status-applier** — leaves a real lingering effect on the target (a stack, a DoT, a debuff) that a second hit can react to. Pyro (Burn), Cryo (Chill stacks/Root), and Toxin (Poison/DoT) are the launch set. **Voltaic (Charged) and Terra (Cracked) joined this bucket in v0.13** (see "Elemental Application" above) — neither has a confirmed reaction pairing of its own yet. **Aqua (Wet) joins this bucket in v0.14** — two candidate pairs are flagged (Aqua × Voltaic "Conductor," Aqua × Pyro "Steam") but neither is confirmed or added to the table below yet; they still need the one-pair-at-a-time gate this section requires.
- **Status-consumer** — doesn't apply its own lingering status, but has a verb that plausibly interacts with someone else's (spreads it, amplifies it, detonates it). Zephyr is the launch example. **Voltaic moved out of this bucket in v0.13** — Charged is now a real applied status of its own — but Shatter (below) still works off Voltaic's Passive, not Charged, so that pairing is unaffected.
- **Universal amplifier** — already boosts the next hit from *any* Element, not a specific one, so it doesn't need bespoke pairs on top of that. Terra's Fault Line (its new Ultimate — see the in-progress kit-restructure notes) works this way. **Umbra's Mark no longer belongs in this bucket as of v0.16** — the reworked version only benefits Umbra's own hit, not "anyone," so it isn't a universal amplifier anymore; it's also Technique-gated rather than an innate kit piece, so it sits outside this per-Element system entirely now (see the removed-entry note in "Elemental Application" above). **Terra now also has an applied status (Cracked, v0.13) that does something similar at a smaller scale — flagged above, not reconciled.**
- **Non-combat** — the reaction frame (bonus damage from a follow-up hit) doesn't fit the Element's actual kit. Radiant is the launch example; if Radiant ever gets a cross-Element hook, it should be a different kind of interaction (a cleanse, a shared buff), not a reaction.

**Confirmed launch reactions (2026-09-24), kept deliberately short — only pairs that pass a real "does this make sense" test, not every possible combination:**

| Reaction | Elements | What happens | Why it makes sense |
|---|---|---|---|
| **Melt** | Pyro × Cryo | Hitting a Burning target with Cryo (or a Chilled/Rooted target with Pyro) deals bonus burst damage and consumes the status | Fire melts ice — the clearest pairing in the game |
| **Combustion** | Pyro × Toxin | A Burning target inside a poison cloud (or vice versa) ignites the cloud for a one-time AoE burst | Flammable gas plus fire |
| **Wildfire** | Pyro × Zephyr | A Zephyr hit on a Burning target extends the Burn's duration/stacks, or spreads a weaker Burn tick to nearby enemies | Wind fans flame |
| **Windchill** | Cryo × Zephyr | A Zephyr hit on a Chilled target adds bonus Chill stacks | What wind chill literally is |
| **Toxic Squall** | Toxin × Zephyr | A Zephyr ability passing through an active poison cloud enlarges its radius | Wind disperses gas |
| **Shatter** | Cryo × Voltaic | Voltaic's own Passive already deals bonus damage to stationary targets; hitting a Rooted target with Voltaic breaks the root early in exchange for that bonus damage — a real trade-off, not free value | Cryo's Root already creates the "stationary" condition Voltaic's Passive rewards; this makes that synergy explicit and gives it a cost |

**Deliberately left out at launch, for the record (so nobody re-litigates these from scratch later):** Terra × Voltaic (rock isn't a conductor — doesn't make sense), Toxin × Cryo (cold would realistically suppress poison, an anti-synergy rather than a bonus — doesn't fit what this system is for), and two weaker candidates that were cut for being plausible but not confident enough — Toxin × Voltaic and Umbra × Toxin.

**Adding reactions for a new Element (Aqua, Flora, Love, or whatever comes after):** don't design reactions before the Element's actual kit exists — a reaction is a property of what status (if any) the kit turns out to apply, not something to bolt on first. Once a new Element's kit is locked:
1. Classify it into one of the four buckets above, based on its actual abilities, not an assumption about its theme (water-themed doesn't automatically mean "status-applier" — check what the kit actually does).
2. If it's a status-applier, test it against every other status-applier one pair at a time, using the same gate every reaction above passed: does this make immediate real-world or thematic sense, not just "two elements exist, so combo them"? If a pair doesn't clearly pass, leave it out. A sparse, curated table reads as intentional; a table where every cell is filled reads as noise, and it's a balance nightmare besides — every new Element would otherwise need checking against the entire existing roster for overtuned stacking.
3. If it's a consumer or universal-amplifier type instead, it doesn't need its own row — note what it consumes or amplifies and move on.
4. Update this table additively. It's meant to stay a living reference, not something re-derived from scratch each time an Element is added.

**Flagged, not resolved:** whether a reaction triggers identically for a teammate's Element in 2v2/Squad Clash as for a self-mixed Technique loadout in Duel; and — since the no-pay-to-win pillar (Section 0) says Robux never buys stat power, only faster access — whatever a player currently has equipped should be what determines available reactions, not how much of the roster they've unlocked. Both need stating explicitly wherever this gets built, not assumed.

### Counter web (a few load-bearing examples, not exhaustive)

Bulwark Wall blocks Fireball, Chain Bolt, and Shadow Dart — the only hard counter to ranged M1 pressure, which is exactly why there's only one of it.
Cleansing Ring removes Chill stacks, root effects, and Toxin's DoT — a support/cleanse Technique that counters control and attrition wherever it came from. *(Antidote Cloak, Toxin's own cleanse/counter-poison Technique, is retired as of v0.15 — see the Technique Pool table above.)*
Eclipse (Umbra's Ultimate, working name — v0.16) counters mobility-heavy loadouts built around Gust Jump — you can't juke what reveals your position. *(This line named Fade Step alongside Gust Jump before v0.16; Fade Step is retired, see the Technique Pool table.)*

**New player unlock path:** Start with the Pyro, Terra, and Radiant Elements (one of each archetype: aggro, tank, support) — each comes complete with its own M1, Primary Ability, Passive, and Ultimate, so a new player's first loadout already includes 3 full, distinct Ultimates from turn one — plus one starter Technique (Bulwark Wall) so there's a Technique slot to learn from day one too. Unlock the remaining 5 Elements and 11 Techniques through any of three paths: free progression (Elements via account level; Techniques via reaching Mastery rank 3 on their originating Element, see Section 5), spending Sparks (earned by playing or bought with Robux, for unlocking a specific piece sooner), or a direct Robux purchase (instant, for skipping the grind). Every path lands on the identical piece — an Element or Technique bought with Robux plays exactly like one earned for free, only faster to reach.

---

## 3. Combat & Movement Systems

**Health baseline:** 100 HP, tunable per element only through passives/shields, never raw HP stat differences (keeps balance legible). *(Still open per v0.3 — the current build runs 150. One of the two has to move; not resolved by this revision.)*
**Health regeneration:** none. Health never refills on its own, and taking no damage does not heal. Only healing abilities heal (Radiant's kit, Toxin's lifesteal), and a new body starts full: each duel round, a respawn, and every return from a fight (to the Hub, or into a Solo Test).
**Where health counts:** only in the arena. The Hub is not a place to fight, so nobody can be damaged there. In the Training Grounds (a Solo Test) players keep their health bar, but they can't damage each other; only the training dummies take hits. Players damage each other only as opponents in the same match.
**TTK target:** 1.5–2.5 seconds for a skilled duel at close-mid range — fast enough to feel punchy, slow enough that positioning and utility matter (RIVALS' target band, adjusted for ability-assisted combat).
**Mana pool:** Regenerates passively. M1 costs a small amount of Mana, set per M1 so that firing at its maximum rate still spends less per second than the pool regenerates — M1 alone can never empty the bar, and a shot is never refused for lack of Mana. In practice it is limited by its own fire rate/charge behavior, so it always feels like a "gun," spammable within its own rhythm. Primary Ability and Techniques draw from Mana. Your Ultimate is charge-based (built from damage dealt/taken) rather than mana-gated, so it can't be hoarded indefinitely.
**Movement:** Uniform base move speed across all elements (modified only by passives like Cryo's post-hit speed or Zephyr's air control) — this preserves aim-focused gunfights instead of turning into a mobility-stacking contest.
**Shared movement set:** everyone moves the same RIVALS-style way, whatever their Element: sprint is automatic (no walk key, no stamina), crouch lowers the body and hitbox rather than just the camera, a slide from speed lasts only as long as the player is actually sliding (it ends on letting go of crouch, leaving the ground, hitting a wall or another player, or slowing below slide speed), and a slide-jump carries the slide's speed into the air — so jumping early in a slide carries further than jumping late. A slide-jump spends the crouch press: you land running, and crouching again needs a fresh press (with Toggle Crouch too), so a slide never quietly leaves you crouch-walking.
**Hits count where the shot visibly passes:** a shot is tested for hits as wide as it is drawn, not as a hairline down the crosshair, so a projectile that visibly cuts through an enemy damages them. What stops a shot (walls, the ground) is still tested precisely, so shots don't die on doorframes. The server still validates every reported hit (Section 12).
**Mobile controls:** Tap-and-hold auto-fire toggle for M1, a dedicated button for Primary Ability, swipe gestures for equipped Techniques, single large button for the Ultimate, camera-assist (not aim-assist) for tracking on touch input only.
**Separate matchmaking pools for mobile and PC/console** — the single highest-confidence, most directly borrowed mechanic from RIVALS. Never mix input types in ranked.

### Eliminations & ragdolls

Every elimination ends in a ragdoll. The moment a player's health reaches 0, their character goes limp as a physics ragdoll instead of Roblox's default fall-apart death, thrown along the direction of the killing hit — harder the bigger the hit, so a Seismic Slam launches a body while an Icicle Shard tips one over. The ragdoll is what makes a kill feel landed, and it is the stage every kill effect plays on (Section 7).

**Same for everyone, never for sale.** Ragdolls are part of how combat feels, not a cosmetic — no purchase changes how a body falls.
**A body is scenery, not cover.** A ragdoll has no hitbox and blocks nothing: projectiles, beams, sightlines, and players all pass through it. A body can never become a second wall (Bulwark Wall stays the only one, Section 2), and it can't be hit for damage or Ultimate charge.
**Nothing depends on where it lands.** The eliminated player is already out of the round, so each player's device can simulate the ragdoll on its own — it's cheap, and no rule reads where a body lies.
**Bodies clear quickly.** A body stays down for about 3 seconds (starting point), or until the round ends if that comes first, then leaves with its kill effect's exit beat. Squad Clash can leave ten bodies on a phone screen, so this is a performance rule as much as a clutter rule.

---

## 4. Game Modes

| Mode | Format | Purpose |
|---|---|---|
| **Duel** | 1v1, first to 5 rounds | Pure kit-vs-kit skill test, fast queue, main ranked mode at launch |
| **2v2** *(added v0.6)* | 2v2, first to 5 rounds (same round structure as Duel) | Team-based skill test one tier up from Duel — no objective, party-queue-first |
| **Squad Clash** | 5v5, first to 6 rounds, one life per round | Team ranked mode with an objective (channel the "Ley Line Core" to win the round outright, Valorant-plant-style) — adds macro strategy on top of aim |
| **Rift Royale** (Season 2+) | Free-for-all, continuous respawn, first to 20 kills | Casual warm-up mode, low commitment, good for new players learning kits |
| **Convergence** (weekly limited mode) | Rotating modifiers (e.g., double Ultimate charge, all-loadouts-random) | Keeps the weekly live-ops event feeling like a genuine event, not just a shop refresh |

### Maps

Every match starts with a **map vote**: once a match is confirmed, each player picks one of the maps on offer, and the winner is played (a tie is a coin flip).

| Map | What it is |
|---|---|
| **Training Ground** | The solo test range: target boards and training dummies, a place to try a kit, never a ranked map |
| **Shattered Neon City** | Rooftops over a neon city: two lanes, stairwells up to the roofs, and a gap only a strong jump clears |
| **Ascendant Bastion** | A fully walled arena around a central Core crystal: towers, raised platforms, and two gates |
| **Skyline** | Towers linked by bridges high above a cloud sea, with a fatal drop; spawns on the rooftops |
| **The Elemental Quarry** | A pit quarry on a floating island: a broken central pit around a Core, lava, ice falls and vines, machinery and parkour routes; laid out for Squad Clash (two plazas per team) |

**The Hub** is the Open Academy, a floating island (Section 1). A portal gate in its training yard leads to the **Training Grounds** island — a bigger practice space with a target range, a dummy field and a movement course. It isn't a voted map.

---

## 5. Progression Systems

**Account Level:** Casual XP from any match, unlocks remaining Elements (see Section 2) and account-level cosmetic slots. Caps around level 30.

**Mastery per Element:** Separate XP bar per Element, built through use, not purchase. Reaching **Mastery rank 3** on an Element unlocks that Element's own Technique pool contribution (2 Techniques for Cryo, Terra, Zephyr, Umbra, Radiant, and Toxin; none for Pyro or Voltaic, which don't contribute any) into your Technique pool for free — this is the main free path to a full Technique collection, and it directly rewards actually playing every Element instead of only ever touching the strongest one. Mastering Pyro or Voltaic still grants their cosmetic and flex rewards below, just no Technique unlock, since they have none to give. Further rewards: Element-specific cosmetic trims at Mastery 5/10/15, a Mastery emblem badge at Mastery 20 (pure flex, displayed on profile and pre-match lobby — the "I have 500 hours on Pyro" bragging signal).

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

---

## 6. Economy

**One persistent currency.** Sparks is the only currency that carries between matches — Prisms, the old separate Robux currency, is dropped as of v0.3. Sparks can be earned by playing or bought directly with Robux, and both land on the identical thing: Robux only skips the wait. What Prisms used to buy (cosmetic bundles, Cache Keys, the Season Pass, direct skin purchases, instant Element or Technique unlocks) is now bought with Robux directly (Section 8).

**Currencies:**

| Currency | Type | Earned via | Spent on |
|---|---|---|---|
| **Mana Shards** | Soft, in-match only | Round wins/losses | Attunement Phase in-round upgrades (temporary, reset each match — cosmetically visible but not power-imbalancing across a full match since both teams earn them) |
| **Sparks** | Persistent — the only persistent currency | Match completion, dailies, Contracts, or bought directly with Robux | Opening cosmetic Caches at low rarity tiers, buying specific common skins from rotating shop, unlocking a specific Element or Technique early |

**Sinks:** cosmetic shop rotation (Sparks + Robux), Cache Keys (Robux), Season Pass (Robux, one-time per season), Skin Ascension (combining duplicate skin drops + Sparks to evolve a skin to an animated "Mythic" tier — a grind-toward-something loop with no power effect), Element and Technique unlocks (Sparks or Robux — roster access only, see Section 2).

**Sources:** match completion (Sparks), daily login (small Sparks trickle), weekly Contracts (larger Sparks + occasional Keys), ranked season-end rewards (cosmetic only), party-queue bonus (bonus Sparks for playing ranked with a friend — direct mechanical reward for inviting someone), Sparks bought with Robux (identical to earned Sparks).

---

## 7. Cosmetics & the Trading Layer

This is the structural addition that neither RIVALS nor Elemental Battlegrounds has, and it's the piece most likely to drive session length and social pressure.

**Character skins:** full-body reskins per element (e.g., Pyro's "Inferno Reaper" recolors the base humanoid, doesn't change hitbox).
**Spell VFX skins:** the highest-monetization surface in the game, because a spell effect is on-screen constantly during every fight, unlike a gun skin that's mostly seen by the shooter. Example: "Void Fire" recolors Pyro's Fireball into black/purple flame with a different particle trail. These should be the most numerous and most frequently released cosmetic type, and should cover M1, Primary Ability, and Ultimate alike.
**Technique reskins:** a category that only exists because of the Technique system (Section 2) — since a loadout can carry a Technique from a different Element than your own, a reskin lets you retint a borrowed Technique to match your chosen Element's palette (e.g., a Cryo user's borrowed Bulwark Wall rendering in ice-blue instead of stone-brown). This is pure visual coherence for players who want it, sold separately from the base Technique unlock.
**New Technique Looks (added v0.6):** a bigger, bespoke tier one step above a Technique reskin — not just a retint, but a full alternate-material redesign of the Technique's effect (a genuinely different shape/material language, not a new color on the same shapes). Sold Robux-only, never through the Cache/gacha, since it's a larger asset than a reskin and earns a direct-purchase price point instead of a randomized one.
**Kill effects:** what plays on an eliminated player's body, set by whoever landed the kill — the one cosmetic every opponent is guaranteed to see, at the exact moment they lost. Every player has the basic kill effect; a few skins come with a special one (see Kill effects below).
**Rarity tiers:** Common → Rare → Epic → Mythic (animated, particle-heavy top tier).
**Trading:** Seasonal-event VFX skins (never re-released, following the Adopt Me/MM2 scarcity model) become tradeable after a 3-day hold period to prevent instant bot-market scalping. An in-client "recent trade value" tracker (not an official price list, just recent-trade transparency) reduces the scam vulnerability that historically hurt Adopt Me's trading community. A short in-game tutorial on safe trading is required before a player's first trade (an "Attunement License," functionally identical to Adopt Me's Trade License, which measurably reduced scams there).
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

---

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
| Element unlock (skip the grind) | 150–350, scaling with how late it sits in the unlock order | Instant access to one of the 5 non-starter Elements' full bundle: M1, Primary Ability, Passive, and Ultimate. Also purchasable with Sparks alone for free-to-play players — Robux only removes the wait, not the free path |
| Technique unlock (skip the grind) | 75–150 | Roughly a third the price of an Element unlock, since it's roughly a third the content. Also purchasable with Sparks; free via reaching Mastery rank 3 on the Technique's originating Element |
| Technique reskin | 100–200 | Cosmetic retint of a borrowed Technique to match your Element's palette; no effect on the base unlock |
| **New Technique Look** *(added v0.6)* | 300–500 | A full alternate-material redesign of a Technique's effect — distinct from a Technique reskin, which only retints. Robux-only, never through the Cache, since it's a larger bespoke asset than a reskin |
| **Full Element skin bundle** *(added v0.6)* | Character skin + all of that Element's VFX skins, bundled at a discount off buying separately | Bulk-sells everything cosmetic tied to one Element as a single purchase, for players who want to fully re-theme one Element rather than piece by piece |

**Guardrails (non-negotiable):**

Odds disclosure on every Cache, clearly displayed before purchase.
No Cache contents ever affect stats, cooldowns, or hitboxes.
Element and Technique unlocks change *when* a player gets a piece, never how strong that piece is — a level-3 account and a level-20 account playing the same Element or Technique play it identically. This is a roster-access purchase, the same category as a League of Legends champion or a Brawl Stars brawler, not a stat purchase.
Sparks (the progression currency, and the only persistent one) must always be earnable through play at a reasonable rate — a free player should never feel structurally blocked from cosmetic variety or the full roster, only slower.
Kill effects are cosmetic end to end — no damage, hitbox, ragdoll, respawn, or round-timing difference between the basic effect and any special one.

---

## 9. Live-Ops Calendar & Retention Systems

**Daily:** login streak (small Sparks trickle), 2–3 daily Contracts (e.g., "land 15 Ultimate hits," "win 3 rounds as Cryo").
**Weekly:** new Contract line refresh (Sunday), **Convergence event** — a 60–90 minute limited window (Saturday) with boosted Cache drop rates and a rotating gameplay modifier, deliberately modeled on Grow a Garden's and Steal a Brainrot's "admin abuse" urgency windows, but tied to a cosmetic Cache rather than a pay-to-win boost.
**Monthly:** rotating shop refresh, a themed cosmetic set (not always seasonal-scale), plus 1–2 new standalone Techniques added to the pool — this is the cadence that answers "won't we run out of Elements": Techniques ship far more often than Elements because each one is a fraction of the design and balance work.
**Seasonal (~2 months):** ranked reset, one new Element added (post-launch content drop — evergreen expansion), one new map, a season-exclusive tradeable cosmetic set that is retired at season end. If the new Element's role fits a Mobility- or Defense-flavored identity, it also seeds new Technique pool entries; a damage-only Element, per Section 2's v0.7 rule, seeds none.

---

## 10. Social & Virality Systems

**Duel Pad challenge:** step on a pad to instantly challenge a nearby player to a 1v1 — directly borrowed from RIVALS, proven to drive spontaneous competitive engagement.
**Party queue bonus:** bonus Sparks for ranked matches played in a party — a direct mechanical incentive to invite friends, not just a social nicety.
**Highlight Reel:** the client auto-captures your best moment each match (biggest multi-kill, clutch round win, best Ultimate) as a short shareable clip, ready to post — this engineers the "clip-worthy moment" pattern common across breakout games instead of leaving it to chance.
**Trading:** as above, makes other players structurally necessary for full cosmetic collection.
**Leaderboards:** per-element Mastery leaderboards (not just overall rank) give more players a leaderboard they can realistically top, which broadens bragging-rights participation beyond just the top 1% of ranked players.

---

## 11. Onboarding & New Player Experience

First 3 matches are against bots tuned to lose gracefully, teaching M1 aim, one Primary Ability use, one Technique use, and one Ultimate use per match.
Starter set of 3 Elements (Pyro/Terra/Radiant) covering the three core archetypes, each already complete with its own Ultimate as part of picking the Element, plus one starter Technique (Bulwark Wall), so a new player's first real matches use a complete, legible loadout instead of being overwhelmed by 8 Elements and 12 Techniques at once.
A one-time "Attunement License" tutorial (trading safety) gates the first trade, not general play — no early-game friction.

---

## 12. Anti-Cheat & Fair Play

Server-authoritative hit detection on all M1 and Primary Ability casts (client-side prediction for feel, server validation for damage) — non-negotiable for a skill-based ranked mode.
Public-facing anti-cheat messaging modeled on RIVALS' approach (they publicize blocked-cheat-attempt counts) — this is a trust signal that measurably supports ranked retention.
Permanent bans, no appeals for confirmed exploiting, communicated clearly at signup.

---

## 13. Post-Launch Roadmap (first four seasons)

| Season | New Element | New Techniques (within-season, monthly) | New map | Ranked/mode change |
|---|---|---|---|---|
| Launch | 8 Elements, 12 Techniques live | — | 2 maps | Duel + Squad Clash |
| Season 1 | 9th Element (community-voted theme, e.g. "Metal") — seeds new Techniques if its role fits | 2–3 standalone Technique drops | 1 new map | Introduce per-Element Mastery leaderboards |
| Season 2 | 10th Element — seeds new Techniques if its role fits | 2–3 standalone Technique drops | 1 new map | Add Rift Royale FFA mode |
| Season 3 | No new Element — balance/rework pass instead | 2–3 standalone Technique drops, prioritized toward any pool that's fallen thin | Map rework | Add Mythic Ascension system |
| Season 4 | 11th Element — seeds new Techniques if its role fits | 2–3 standalone Technique drops | 1 new map + first "arena" spectator mode | Community tournament infrastructure (in-client bracket tool) |

Community-voted element themes (borrowing Grow a Garden's practice of teasing updates on the developer's own TikTok before release) double as a marketing beat each season.

---

## 14. Success Metrics to Track

**Day-1 retention ≥ 25%**, median session ≥ 8 minutes (soft-launch gate before any marketing spend — if this fails, the kit design or onboarding needs work, not the marketing plan).
**Matches per session ≥ 3** (signals the round-based loop is compelling on its own).
**Convergence event CCU lift ≥ 40%** on event days (validates the weekly FOMO cadence is working without pay-to-win).
**Trade volume per active trader ≥ 1/week** by month 2 (validates the trading layer is actually creating social dependency).
**Cosmetic ARPDAU** tracked separately from Season Pass revenue, to see whether VFX skins are outperforming character skins as hypothesized (Section 7), and whether skins with a special kill effect outsell comparable skins without one.

---

## 15. Key Risks & Mitigations (condensed)

| Risk | Mitigation |
|---|---|
| M1s drift toward AoE spam, losing the "aim matters" identity | Every M1 must be aim-based by design rule (Pillar 1); playtest TTK against a pure-aim benchmark, not just "does it feel fun" |
| Whole-kit balance was the original slow, heavy dev cost of an 8-kit design | The Element/Technique split (Section 2) directly reduces this: balancing single Techniques is lighter than balancing eight five-piece kits, and most post-launch content now ships as Techniques rather than new Elements |
| Cross-Element loadouts can create combos no single kit designer planned for | Playtest specifically for pool-level combinations, not just each Technique in isolation; keep a standing "worst 3-Technique combo" review each patch, not only a review of new additions |
| Cross-Element visual mixing could read as thematically messy rather than intentional | Frame it explicitly as the core fantasy (an elementalist who borrows power) in marketing and in-game flavor text, not as a bug; sell Technique reskins (Section 7) to players who want visual coherence instead of forcing it on everyone |
| A damage-only Element contributing nothing to the Technique pool (Section 2, v0.7) could feel unfair to players who want that Element's own abilities available to mix into other builds | This is an accepted trade-off, not an oversight — a damage-only Element is stronger and more self-sufficient in its own fixed kit specifically because it isn't giving that power away; revisit only if playtesting shows the roster leans too hard toward "give nothing" as the strongest pattern |
| Genre is crowded (600+ FPS titles on Roblox) | Discovery hook is the elemental-kit angle itself, positioned explicitly against RIVALS in marketing/trailers, not just "another shooter" |
| Cosmetic trading invites scams (Adopt Me's early history) | Hold period + trade-value transparency + mandatory tutorial before first trade, built in from day one rather than patched in later |
| Ragdolls and kill effects clutter a live Squad Clash fight, or cost frame rate on mobile | Bodies have no hitbox and clear after about 3 seconds; kill effects stay on the body, stay short, and honor Reduce Flashing; on low-end devices, cap how many ragdolls simulate at once and clear the oldest first |
| Spellbreak's precedent (shut down 2023 despite strong initial launch) | Its failure was a distribution problem against Fortnite/Apex/Warzone as a premium multi-platform title, not a mechanic problem — Roblox's built-in discovery feed removes that specific risk, but don't assume it removes the discovery risk entirely; still needs a genuinely distinct hook to break through the FPS category page |

---

## Appendix: Quick-Reference Numbers (starting point for playtesting, not final)

Base HP: 100
Health regen: none (only healing abilities heal; full health after every fight)
Mana: 100, regenerating 7/s
M1 Mana cost: set per M1 so cost × max fire rate stays under regen (Icicle Shard: 2 per shot at up to 3 shots/s = 6/s)
Target TTK: 1.5–2.5s
Match format: Best of 9 (first to 5)
Movement: automatic sprint 25 studs/s, crouch 8; slide up to 1.1 s with a 1.2 s cooldown; slide-jump +20 studs/s
Season length: ~2 months
Trade hold period: 3 days
Convergence event window: 60–90 minutes, weekly
Loadout: 1 Element (M1 + Primary Ability + Passive + Ultimate, all fixed) + up to 3 Techniques from one shared, uncategorized pool
Technique pool at launch: 12 total (2 each from Cryo, Terra, Zephyr, Umbra, Radiant, Toxin; 0 from Pyro and Voltaic, both damage-only)
Technique unlock: free at Mastery rank 3 on the originating Element, or via Sparks or Robux
Starter loadout: 3 Elements (one per archetype, each with its own Ultimate included) + 1 starter Technique (Bulwark Wall)
Full roster unlock (8 Elements + 12 Techniques): by account level ~20 and Element Mastery, or earlier via Sparks or Robux (roster access only, no stat difference)
Persistent currency: Sparks only (earned by playing, or at round end)
Ragdoll: every elimination; no hitbox; body clears after ~3 s or at round end
Kill effect: basic for everyone, special on a few skins; hit beat ≤ ~2 s; server-confirmed kills only
Cross-Slash Dash: tap 12 studs, full charge (1 s hold) 40 studs, auto-release at 1.5 s; glide ~110 studs/s; 40% move speed while charging
Gust Jump: 2 air jumps a cast (momentum kept), then a glide of ~80 studs; float up to 2.2 s per jump; 7 s cooldown from landing
Cyclone: forms in 1.2 s at the crosshair (steerable, range 70), then 4 s; pull radius 26 studs; 6 damage every 0.5 s
Ring of Fire: radius 25 studs; press to eruption ~0.93 s; central column ~35 studs tall (the Heat-scaling variant — radius 30 at high Heat — no longer applies, since Heat is retired)
