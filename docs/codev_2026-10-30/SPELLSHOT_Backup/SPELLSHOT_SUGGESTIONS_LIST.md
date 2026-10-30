# SPELLSHOT: every suggestion made so far, and its status

18 October 2026, updated after P28 and P29 (`SPELLSHOT_P28_P29_RESULTS.md`). Collected by three agents from the
reports and both session histories, then merged and checked by a completeness critic. Status: **open** (waiting on you), **partly answered**, **in progress**, **done**, **dropped**
(superseded or withdrawn).

## A. Decisions waiting on you

1. **Team fights as the main mode** (Duel kept as a side mode, higher team HP). *Partly answered:* your 3v3 prompt adds team fights as a second mode alongside the Duel; the final pivot call is still open.
2. **Movement for team mode.** *Partly answered:* kit mobility stays (Shadow Step, Overcharge, Bulwark Charge, Cross-Slash, Skyrider). Still open:
   - keep jump and double jump?
   - give everyone a short dodge in place of the slide?
   - keep the fast RIVALS-style pace in the Duel?
3. **Match format:** rounds with no healing between fights, respawns, or an objective such as a control point. *Open.*
4. **One Element per team** (removes mono-stacks and double-Pyro; 84 legal comps). *Open:* no explicit yes, though every round-robin since uses it.
5. **The Terra must-pick.** Every package shows Terra comps winning about 70%. The options are: lock roles (one tank per team), give a second Element team protection, or accept Terra as the standard pick. *Open.* P28 tested the second protector: Twin Tide blocking on today's walls barely helps (+1.4 to +1.6 for Aqua). With the walls standing about 3 s longer, Aqua becomes viable (about 50%) and Terra drops 1.3 to 2, but comps with no protector fall further behind.
6. **HP by role.** *Partly answered:* you want HP to differ by role (Terra more than Pyro). The exact numbers are open: the sim's v1 uses 250 for everyone, Terra 450, Umbra 225.
7. **Radiant's damage versus its healing.** *Partly answered:* you said Radiant needn't deal damage like Pyro and Voltaic. The sim shows Radiant already deals the least damage in team play, so the open part is how much it should heal.
8. **Whether 2× hitboxes make focus fire too fast in team play.** *Open.*
9. **Values the sims had to assume.** *Open.* Confirm or correct:
   - Cross-Slash range 12–40 (still marked ASSUMED);
   - Patient Zero bursting on the caught enemy's teammates;
   - Leviathan's Maw bite and surge both landing;
   - Gust Pad counting as a 0-damage hit that can react;
   - only Acid Rain ticks setting off reactions;
   - Charged needing a second enemy within 16 studs;
   - Detonate applying no Burning;
   - Static Discharge costing no mana (the P27 spec gives no cost).
10. **Sign off every value still marked as an assumption (PROP).** That covers Cryo, Toxin, Umbra and Zephyr numbers such as Toxic Bubbles, Corrosive Cloud, Symbiosis, Acid Rain, Eclipse, Skyrider and Halo, not only Cross-Slash and Shadow Dart. *Open.*
11. **Make roles readable at a glance,** and make team mode work without voice chat, since many Roblox players queue solo. *Open.*

## B. Checks to do in Studio or in the game

1. **Test team package v1's core in Studio:**
   - HP 250 (Terra 450, Umbra 225); Ultimate charge × 0.6;
   - Light Lance heals hurt allies;
   - Blessing 60 shield every 8 s;
   - Benediction 25 HP/s, radius 35, no root;
   - a bigger Bulwark Wall;
   - Fireball 15 every 0.7 s, Chain Bolt range 45, Overload 2.5 s per target, Skyrider 42/55.

   *Open.*
2. **Build a movement switch** (one setting turns off slide, slide-jump and wall-run) and play running-only before committing. *Open.*
3. **Play-test the live 17 Oct balance pass:**
   - a 2-player duel that reaches the 90 s clock;
   - the slower slide chain (22/42/52; wall runs now cap at 52);
   - the dash threshold of 16;
   - the moved Bastion and Neon City spawns;
   - Skyrider 60/75 and Mirror Cage's 2.3 s root;
   - the three reworked passives in real fights.

   *Open.*
4. **Check the 2× hitboxes and the shared 200 studs/s M1 speed in game:**
   - fire each Element's real attacks through the hitboxes;
   - check moving next to another player;
   - see how Fireball, Bubble, Riptide and Boulder look at 200. Toxic Bubble barely lobs now, and charged Boulder no longer flies slower.

   *Open.*
5. **Check whether each Bulwark Wall deploy starts at a fresh 200 HP.** If it does, give it a cooldown of about 6 s after release in team mode. *Open.*
6. **Check whether slows and roots stop Shadow Step's blink and Skyrider's flight.** This matters to every "slow vs escape" finding. *Open.*
7. **Confirm whether Scorching Lash's speed check rejects hits on a boosting Skyrider.** *Open.*
8. **Re-check Shadow Dart's numbers** (65 per 2.6 s at 160 studs). They decide every Umbra result. *Open.*
9. **Measure the real chase speed in Play.** The sim's 45 studs/s after the pass is an estimate. *Open.*
10. **Build a small in-game logger** (shots vs hits per M1, time to kill, ability use, dodges) so the sim's aim and reaction numbers come from real players, then playtest the top recommendations. *Open.*
11. **Check the sim's "cover each other's back" teamwork rule against real play.** It's worth up to 8 points to Terra comps. *Open.*
12. **Record RIVALS shooting-range clips at 60 fps** (run, slide, slide-jumps, wall run) so its movement can be measured. *Open.*
13. **Turn off the dev free-Ultimate setting when testing.** *Dropped:* you said you'd tested without it too.
14. **If Twin Tide becomes a protector:** playtest walls that stand about 3 s and block bodies (the sim doesn't model body-blocking), and build a server-side copy of the walls so they can stop shots (today only clients have them, with `CanQuery` off). *Open, from P28.*

## C. Balance and design proposals

**Open:**
1. **Revisit the chain-era tuning for running-only team play.** Chill's first stack (cap 22) is only a 12% slow against a 25 studs/s run. Also revisit the dash threshold, the slide-jump values and the duel spawns.
2. **Trim Terra's close-range damage** (32/s at 20 studs) or shrink the hitboxes a little, for running-only play.
3. **Give every role comp a reaction pair** (for example, switch on Terra's dormant Cracked with Pyro and Voltaic rules), and let Melt consume Chill only, never a root.
4. **Ground control and jumping.** If team mode keeps the jump, let ground attacks catch low airborne players: Riptide height 3.5 → 6, and Flash Freeze, Aftershock and Earthen Tomb reaching about 6 studs up.
5. **Technique swapping (P25):** no restriction is needed for self-combos (they add at most about 9 points). The real issue is Bulwark Wall and Scorching Lash making any kit stronger.
6. **Limit M1 spam** (cost above the 7/s regen, or overheat or reload), and add cover to Bastion (3.6% centre cover) and Quarry (0%).
7. **Recheck cheap utility mana costs** now that team rounds run 18–20 s: Undertow 25, Blizzard 28, Gust Pad 20, Mark 18, Decoy Double 18, Shadow Step 20.
8. **Anti-chase tools:** heal pickups or a first healing ability, an escape option in the shared Technique pool, a deliberate range band per Element, and knockbacks for defenders.
9. **Aqua needs a kit change for the 1v1, not just numbers:** its pulls bring enemies in, which works against its own kiting.
10. **Draft role targets** to agree on: Damage ~30–40/s; Support ~10–15/s damage with ~25–40 HP/s on one ally; Defence ~15–20/s with walls and shields; Control ~12–20/s with most of the slow and root time.
11. **Build the team mode itself:**
    - queues and team spawns;
    - a team HUD and scoreboard;
    - round or respawn rules and friendly-fire rules;
    - possibly an objective;
    - a separate team-mode tuning layer.
12. **Check the duel maps for team play** (lanes, cover, spawns for several players), and plan for queue times (bots, a 2v2 start, or a quick 1v1).

**From P28 and P29 (`SPELLSHOT_P28_P29_RESULTS.md`):**
13. **Lock Bulwark Wall to Terra before any team mode ships** (Origin-only, like Detonate and Sidearm), or keep v3's wall strength for Terra alone. In v3, Bulwark Wall swapped onto another kit is worth +11.5 to +26.5 points for 7 of 8 Elements. *Open.*
14. **Twin Tide as a second protector: make the met walls stand about 3 s, not more HP.** Pick variant (a) or (b), not (c). Decide the same swap rule for it: as a swap it is worth up to +10.9 (Cryo). *Open.*
15. **Flash Freeze at the cursor:** clear close-range help only at range 25, and it doesn't move Terra. Test a trade-off at 25 before deciding. *Open.*
16. **Blizzard at the cursor** is the best anti-chase change (−30% lost close fights). The 4 s version is power-neutral for Cryo, but it lifts Terra 1.3 to 2.1, so only with a Terra fix. *Open.*
17. **Don't convert Deep Freeze, Aftershock or Benediction** to the cursor. No effect at any range. *Open (recommendation).*

**From the handoff tests (`SPELLSHOT_HANDOFF_TESTS.md`):**
18. **Adopt a one-tank rule (exactly one Terra per team) if team mode ships.** Comp SD falls about 20 → 15, but the other Elements still spread about 22 as Terra's partners. Don't make Aqua an alternative tank: Aqua comps lose 37–63 to Terra comps. *Open.*
19. **Voltaic: Chain Bolt range 55 and 10 a bolt** (+8.2, to 50%; death rate 73% → 65%). *Open.*
20. **Umbra: give the escape its own charge** (a 6 s blink separate from Shadow Step): +1.5 on top of dive play. *Open.*
21. **Next balance targets: Zephyr** (about 39% with the other fixes in), **then Radiant** (43% as a Terra partner). *Open.*

**Done:**
- The 17 Oct live balance pass: all 15 recommendations from the 16 Oct report.
- The three passive reworks you picked: Ember Refund under 30% HP, Chain Reaction 2 s per full Charged, Antitoxin Vent cutting DoT by 30%.
- The 90 s round clock.
- The moved Bastion and Neon City spawns.
- 2× hitboxes and the single 200 studs/s M1 speed, both your own requests.

**Dropped:**
- The 1v1 tuning sets P2 and Q3, held for the team direction. They were also computed before the M1 timing fix.
- The faster-ranged-M1 set, replaced by your shared speed of 200.
- Overcharge's 1v1 rework: you said "leave it".
- Cutting Radiant's damage: withdrawn, because it is already the lowest.
- Deleting Cross-Slash's "stray" DashDistance and "fixing" Boulder's speeds: both turned out to be intentional.

## D. Simulation follow-ups

1. **P27 (Voltaic and Umbra self-sufficiency).** *Done:* see `SPELLSHOT_P27_RESULTS.md`.
   - **Static Discharge:** don't ship it. Every version left Voltaic slightly worse.
   - **Umbra:** reward diving (half cooldown after a hit, +0.9 on top of dive play, +2.3 in total) instead of a defensive vanish.
   - *Open:*
     - give Umbra's dive a separate exit charge, since one 10 s Shadow Step can never cover both the dive-in and the exit;
     - look at Voltaic's damage and reach rather than escape.
2. **Second team protector (P28).** *Done:* see `SPELLSHOT_P28_P29_RESULTS.md`, and C.13–C.14 above.
3. **Behaviour-model robustness.** Make the bots' assumptions switchable and re-run the close calls (S2, W2, mono-Pyro vs S1). *Open.* The switches:
   - reaction times that slow under load;
   - one shared notice roll per team;
   - a 0.15–0.45 s delay before peel;
   - focus that counts shields;
   - full first-to-5 matches with Ultimate carry-over;
   - a tilt rule for the team that's behind.
4. **Round-robin the 84 comps after any change you accept,** so rankings reflect the mode you'd ship. *Ongoing.*
5. **Cursor-targeting (P29).** *Done:* see `SPELLSHOT_P28_P29_RESULTS.md` and C.15–C.17. Step 0 found Blizzard and Deep Freeze land at Cryo's feet live; the earlier sims aimed them, so P27's and the 3v3 report's Cryo numbers are about 1.9 points high, and the 3v3 report's Deep Freeze peel findings don't hold live.
6. **Next tests:**
   - v3's Bulwark Wall pulled back toward the default (200 HP, short holds) together with a standing Twin Tide, so the protection is shared;
   - Flash Freeze at 25 with a trade-off;
   - Flash Freeze 25 + Blizzard 32 without Twin Tide (the control the combined run lacked).

   *Open.*

**Done:** the 1v1 re-runs, the 3v3 sim and report, the "cover each other's back" teamwork test, the Marvel Rivals-ratio packages v1–v3 and their follow-up, and the 84-comp round-robins.

## E. Housekeeping

1. **Republish the 1v1 results with the M1 timing fix** (Zephyr 16% → 62%, Radiant 66 → 52, Toxin 46 → 31, Voltaic 32 → 23). The dashboard still shows the old numbers. *Open,* offered three times.
2. **Refresh the dashboard's ability tables,** which still show 16 Oct values. Optionally add an "highlight one Element" filter. *Open.*
3. **The team-fight brief for Claude chat.** *Done.*
