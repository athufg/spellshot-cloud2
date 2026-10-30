# SPELLSHOT P28 + P29: a second protector (Twin Tide) and cursor-targeting, tested in the 3v3 sim

18 October 2026. The owner's P28 and P29 specs, run in one round on top of team package v3. Each spec got its own toggles
on the same base. The draft was fact-checked by independent checkers against the raw results, the sim's code and the
live game in Studio. That check found the live Twin Tide walls stand for less time than first modelled, and found two
missing controls. Everything affected was re-run.

## Answer

### P28: a second protector (Twin Tide's walls blocking shots)

**As specced, on today's walls, it barely matters. Walls that stand longer make Aqua a real second protector. They take
a little off Terra, but leave the comps that have no protector further behind.**

- **Live Twin Tide is a crush with walls that are solid for about 0.94 s,** not a standing wall. To protect anyone, Aqua
  has to give up the crush: casting it as cover drops her crush damage from 13.0 to 3.6 a round, which on its own costs
  Aqua comps 0.9 points.
- **On the live walls, blocking walls cast as cover are worth +1.4 to +1.6 net for Aqua comps against today's Twin
  Tide** ((a) and (b); +0.8 for (c)), after giving up most of the crush.
  - Against the matching rule-only control, the blocking itself is worth +2.3 / +2.5 (+1.5 for (c)).
  - Nothing else moves beyond noise (±0.8): Voltaic −0.8, Zephyr −0.4 to −0.5, Terra about 0 (−0.1 to +0.1). The
    comp spread stays at 20.1.
  - The walls absorb only 9 to 14 HP per Aqua per round.
  - The three variants are close: (a) and (b) are within noise of each other. (b) as modelled is (a) plus the far-side
    wall, not the spec's smaller walls.
- **The HP doses made no difference: the walls almost never break.** 150, 200 and 250 gave identical win rates, and
  100 + 100 against 125 + 125 differ by under 0.02 points. Even on walls that stand 3 s longer, 150 and 250 differ by only 0.3
  points for Aqua. The lever is how long the walls stand, not how much they soak.
- **When the met walls stand longer (my addition), Aqua becomes a protector:**
  - Standing 3 s more (about 3.9 s up): Aqua 43.7 → 49.5 (+5.9) for (a), 50.3 (+6.6) for (b) and 48.0 (+4.4) for (c).
    Against the rule-only control that is +6.8, +7.5 and +5.1.
  - Standing 6 s more: Aqua 51.8 (+8.1).
  - They still absorb far less than Bulwark Wall: 30 to 60 HP a round against about 306. The spec wanted Twin Tide
    weaker than Terra's wall, and it is.
- **The spec's checks, for the 3 s version (a):**
  1. **Is Aqua viable?** Yes. 49.5%, third of nine Elements (from seventh), in the pack behind Terra and Pyro. The gain
     lands mostly in comps *without* Terra (37.9 → 44.5, +6.6) rather than with it (60.9 → 64.7, +3.8).
  2. **Does Terra drop, or does Terra + Aqua become the new must-pick?** Terra drops a little: 70.6 → 69.3 (−1.3;
     −2.0 for (b), −2.3 at 6 s). Terra + Aqua comps rise to 64.7%, still below Terra without Aqua (70.9%), so there is
     no new must-pick pair. Every top-6 comp still has Terra; with (b), Aqua + Pyro + Terra becomes the 6th. Voltaic and Zephyr lose about as
     much as Terra (−1.7 and −1.3 for (a); −1.9 and −1.5 at 6 s).
  3. **Does the spread narrow?** Slightly: 20.1 → 19.6 (19.4 for (b), 19.3 at 6 s), against ±0.4 noise in the spread.
     Best − worst Element 29 → 28 (27).
- **The bottom-6 check.** The bottom 6 already lacked both Terra and Pyro in every run (P27's finding), and 5 of 6 also
  lacked Aqua. With blocking walls, the last Aqua comp climbs out, so all 6 lack Terra and Aqua.
  - The clearer signal is the group with neither Terra nor Aqua, which falls: 40.7 → 37.8 at 3 s and 37.0 at 6 s
    (seed noise 0.2).
  - So a second protector helps its own comps and leaves the unprotected ones further behind. This is a milder form of
    the shape problem the spec warned about: Aqua isn't a must-pick (Aqua without Terra is still below average), but
    "no protector" stays a losing comp.
- **Technique swap (P25's lever):** each Element's Defense Technique was replaced by Twin Tide and played against the 83 other comps, against a control on the same seeds and wall settings without the swap.
  - **On the live walls, a blocking Twin Tide swap is worth +5.0 for Cryo and +4.0 for Zephyr,** with the other non-Terra Elements within about ±2 (Terra, which loses its own Bulwark Wall, is below). That is smaller than the standing version or Bulwark Wall, but larger than any P29 change. The run includes the crush and cover-casting, and no swap without blocking was run, so the sim can't say how much comes from the walls.
  - **With the standing walls it grows:** Cryo +10.9, Zephyr +7.6, Umbra +4.5, Toxin +2.8 and Voltaic +2.4. Pyro and Radiant don't change.
  - Cryo probably gives up little by losing Deep Freeze. This is an inference: it deals 0.4 damage a round, moving it changed nothing in P29, and no run removes it. So Cryo's swap gain is probably close to Twin Tide's full value for Cryo.
  - **For comparison, Bulwark Wall at v3's strength (400 HP) as a swap lifts 7 of the 8 other Elements by 11.5 to 26.5 points** (Cryo 48.6 → 75.2); only Umbra gains just 2.1. P25's exploit is far bigger at v3's wall strength than anything a standing Twin Tide adds.
  - **Terra swapping its own Bulwark Wall out for Twin Tide drops 14.5 to 17 points.** Terra's edge is its wall.

### P29: cursor-targeting for self-centred abilities

**Cursor-targeting Flash Freeze or Blizzard makes Cryo win more of the fights where an enemy closes in. But those fights
are a small part of why Cryo loses, and each Cryo comp with Terra gains several times as much as one without.**

- **Step 0:** five abilities land where the caster stands: Flash Freeze, Blizzard and Deep Freeze (Cryo), Aftershock
  (Terra) and Benediction (Radiant). Mirror Cage and the rest are aimed, or are shields, sweeps, decoys and self buffs
  rather than placed zones. My earlier sims aimed Blizzard and Deep Freeze, which overstated Cryo (by 1.9 points in
  v3); that is corrected here.
- **Flash Freeze has a clean dose curve:** +0.6, +1.4 and +2.2 points for Cryo at ranges 15, 20 and 25.
  - At 25 the close-range effect is clear: Cryo loses 38% of contacts instead of 44%, wins 39% instead of 30%, and lost
    contacts per round fall 0.124 → 0.102.
  - At 20 Cryo loses no fewer close fights (lost share 44% → 42%, seed noise about 1; lost contacts per round 0.122
    against 0.124), but wins clearly more of them (won share 30% → 34%, seed noise about 1.5). My reading, not
    measured: some of the +1.4 comes from outside close fights.
  - Terra doesn't move with Flash Freeze (−0.1 to −0.2).
- **Blizzard** gives +0.9, +1.6 and +1.8 at 20, 32 and 45. It is the strongest anti-chase change: lost contacts per
  round fall about 30% at every range (0.124 → 0.087–0.089). At 32 and 45 it also lifts Terra by 1.5 and 2.1; the spread
  moves to 20.4 (within noise) and 20.6 (marginal). At 20 it does neither (Terra +0.2, spread 20.0).
- **Deep Freeze does nothing at any range** (−0.1 to +0.1). My reading, not measured: its 1.5 s root on one diver is too
  small to matter here.
- **All three Cryo abilities together** give Cryo +2.8. It loses 33% of contacts and wins 45%, and lost contacts per
  round fall 38% (0.124 → 0.077). Terra also rises 1.7, and the spread moves to 20.6 (marginal against ±0.4 noise).
- **The hypothesis holds, but close fights aren't Cryo's main problem.**
  - In the baseline, Cryo has about 0.12 lost contacts a round against 0.84 deaths a round; even every contact (0.28 a
    round) would be about a third of its deaths.
  - So most Cryo deaths come without an enemy having just closed to 16 studs, and its death rate only moves 84% → 82%.
    My reading, not measured: in team fights Cryo mostly dies to focus fire from mid or long range.
- **Where the gain lands:**
  - Each Cryo comp *with* Terra gains far more than one without: +4.8 against +1.3 (Flash Freeze 25), +5.6 against
    +0.5 (Blizzard 45), and +7.0 against +1.4 (all three).
  - There are 7 Cryo + Terra comps and 21 without. For Flash Freeze 20 and 25 and Blizzard 20 and 32, the total gain
    splits about evenly (40–55% in Terra comps). It tilts to Terra comps at Blizzard 45 (79%), in both Blizzard 32
    trade-offs, with all three (62%), and with Blizzard 32 on the robustness timing (73%).
  - With all three converted, Cryo has 3 comps in the top 6 instead of 1, all with Terra.
- **(b) trade-offs:**
  - **Flash Freeze, tested only at 20:**
    - A 0.78 s wind-up brings it back to +0.6, within noise of both the baseline and the straight +1.4, and the contact
      numbers stay at the baseline.
    - Radius 14: +0.9. Freeze 2.5 s: +1.6, so the freeze's length barely matters.
    - No trade-off was tested at 25, the only range with a clear close-range gain.
  - **Blizzard at 32:**
    - Radius 24: +0.9.
    - 4 s instead of 6 is the power-neutral version: Cryo +0.3. It keeps most of the anti-chase effect: 39% lost, 37%
      won, 0.095 lost contacts a round against 0.124. In the sim this storm slows for 4.6 s, as the main runs' storm
      slows for 6.6 s rather than the live 6. On the robustness timing, straight Blizzard 32 gains 0.5 less, so a live
      4 s version may land slightly below +0.3, still within noise of neutral.
    - The cost is elsewhere: Terra still rises 1.6, and Cryo's gain sits in Cryo + Terra comps (+2.5, against −0.4
      without Terra).
- **Robustness runs (my addition):** with Blizzard's live 6 s, and a Flash Freeze closer to live (the live front speed,
  about 5 studs of escape at the edge, and the root held to the zone's end), the results hold. Flash Freeze 20 gives
  +1.4, Flash Freeze 25 +1.9 (against +2.2), Blizzard 32 +1.1 (against +1.6), and Terra still rises 1.7 with Blizzard.
  This Flash Freeze still roots a caught body from the cast, for longer than live (see the Robustness table).
- **Aftershock at the cursor** stays within noise for Terra (−0.2 to −0.5), even though it lands much more: 7 → 15–26
  damage a round, and 11 → 18–22 per cast. Terra's total damage hardly moves (148 → 150–152), so the extra ring damage
  mostly replaces other damage. It neither helps nor widens the Terra gap.
- **Benediction at the cursor** is within noise for Radiant (−0.6 to −0.8). The three ranges are nearly the same run:
  0.68 casts a round at each, and only 374 of 3,486 pairings differ between 20 and 50. The live game's planted, rooted
  Benediction wasn't tested; v3's is mobile.

### Together (my addition)

The standing Twin Tide ((a), +3 s) with Flash Freeze 25 and Blizzard 32:
- **Aqua +5.8,** about the same as the walls alone (+5.9).
- **Cryo +2.8,** below the sum of its two parts (+2.2 and +1.6). Without a Flash Freeze 25 + Blizzard 32 run without
  walls, the sim can't say whether the walls cost Cryo anything.
- **They pull the comp spread in opposite directions** and end at 20.2 (from 20.1):
  - Terra +0.0, because the walls take off what Blizzard adds;
  - Voltaic and Zephyr lose most;
  - Cryo has 3 comps in the top 6 (all with Terra) and 3 in the bottom 6.

## Suggestions from this round

1. **If you want Aqua as the second protector, Twin Tide has to stand longer, not soak more.**
   - Blocking walls cast as cover on today's walls (solid for about 0.94 s) are worth only +1.4 to +1.6 net. The
     blocking itself is worth +2.3 / +2.5, but casting it as cover gives up most of the crush (−0.9).
   - With the met walls standing about 3 s more, Aqua is a viable pick and gains most without Terra.
   - Pick (a) or (b), which the sim can't tell apart; (b) matches the name and today's two walls. Avoid (c): with
     standing walls it gains clearly less (+4.4 against +5.9 / +6.6).
   - HP barely matters in the 150–250 range tested.
   - **Confidence: medium:** a clear dose response, but the standing version is my addition, not the spec's.
   - **What it would mean in the game:** today the walls are replaced by the crash flipbook at 1.1 s. A protector
     version would keep the met walls standing about 3 s, and the crash or crush would need to work with that. The
     server would also need its own copy of the walls (today only clients have them, with `CanQuery` off). And you would
     need to decide whether the walls block your own team's shots (the sim assumes not, like Bulwark Wall).
   - Live walls are solid to bodies and the sim's aren't, so a 4-second body-blocking wall pair is untested. Check it
     in a playtest.
2. **Don't expect it to fix the bottom of the ladder.** With standing walls, comps with neither Terra nor Aqua fall
   about 3 points (seed noise 0.2), and all 6 bottom comps are now in that group. A second protector shrinks Terra's
   share without fixing comps that have no protector. **Confidence: medium-high.**
3. **Flash Freeze at the cursor: only at 25 does it cut lost close fights,** and it doesn't move Terra. Each
   Cryo + Terra comp gains about 3.6 times as much as other Cryo comps (+4.8 against +1.3). Test a trade-off at 25
   before deciding; at 20 the power-neutral wind-up leaves nothing. **Confidence: medium.**
4. **Blizzard at the cursor is the best anti-chase change:** lost contacts per round fall about 30% at every range.
   **Try range 20 first:** it does that without lifting Terra or widening the spread (Cryo +0.9, Terra +0.2, spread
   20.0, lost contacts −28%). It was not re-run on the robustness timing. At 32–45, and in both trade-offs at 32
   (including the power-neutral 4 s version), Terra rises 1.3 to 2.1, so ship those only alongside a Terra fix.
   **Confidence: medium.**
5. **Don't convert Deep Freeze, Aftershock or Benediction.** No effect, or a slightly negative one, at every range
   tested. **Confidence: medium-high.**
6. **Lock Bulwark Wall to Terra before any team mode ships, and decide the same for a blocking Twin Tide.** In v3, Bulwark Wall on another kit is worth 11.5 to 26.5 points for 7 of 8 Elements, the biggest lever tested this round. Decide the same for Twin Tide if it gets any shot-blocking: as a swap it is worth +5.0 for Cryo on today's wall timing, and up to +10.9 standing. Options: make both Origin-only, as Detonate and Sidearm already are, or keep v3's wall strength for Terra alone. **Confidence: medium-high:** large, paired effects.**
7. **The bigger lever is still Terra's own protection.** In v3, Bulwark Wall absorbs about 306 HP per Terra per round,
   six to seven times the standing Twin Tide. A natural next test pulls v3's wall (400 HP, held up to 6 s, 0.5 s between
   holds) back toward the sim's default (200 HP, 2.5 s holds, 2 s apart), together with a standing Twin Tide, so the
   protection is shared rather than added.

## Step 0: what the live game actually does (checked in Studio, read-only)

### Twin Tide (P28)

| | Live (AquaTuning, AquaHandler, AquaFX, AquaTTPose) | The spec assumed |
|---|---|---|
| Shape | Two walls, 24 long and 13 tall, either side of a 24-long lane. The lane is centred on the aimed spot, up to 40 away, and its axis follows Aqua's aim, so the walls lie **along** the aim | One wall today |
| Life | The walls rise and stand 11 off the lane's centre line until 0.3 s, then close to 3.55 at 1.1 s. A body-blocking collider stands from about 0.16 s (35% up) until 1.1 s, about **0.94 s**. At 1.1 s a water flipbook replaces the walls, with no collider. AquaTuning's HoldTime (0.35) and SinkTime (0.6) only set how long the lane stays wet | A standing wall |
| HP | None | Unconfirmed |
| Blocks shots? | No. The colliders are made on each client with `CanQuery` off, so they stop bodies but no ray or projectile. The server never sees them. | No (correct) |
| Cost | 30 mana, 16 s cooldown; the crush does 35 and throws up | — |

**So the spec's starting assumption is partly wrong.** Today's Twin Tide is a crush, not a wall. Its walls stand for
under a second, and they lie along Aqua's aim, so they only face enemy fire when Aqua aims to one side. To make it block
shots in the game, the server would need its own copy of the walls, because today only the clients have them.

### Self-centred abilities (P29)

| Ability | Element | Live: where it lands | The sim until now |
|---|---|---|---|
| Flash Freeze (Primary) | Cryo | r20 around Cryo. After a 0.38 s wind-up the front spreads, easing out, over 1 s. A touch deals 10 and slows to 5 for 1.2 s. One second inside roots you until the zone ends (at most 3.5 s more), and then it shatters for 34 | Same place. The mechanics are approximated: one escape test on the cast, then a 4 s root and the 34 shatter. A closer-to-live version (softer catch, root held to the zone's end) was run as a robustness check |
| Blizzard (Technique) | Cryo | "A storm where you stand": r32 under Cryo, staying where it was cast, 6 s, speed cap 11 | **Aimed:** on the enemy target, up to 45 away. It also slowed for 6.6 s (the robustness runs use 6) |
| Deep Freeze (Technique) | Cryo | "An unseen trap at your feet": reach 4, armed after 0.5 s, 1.5 s root | **At the diver's feet** |
| Aftershock (Technique) | Terra | A ring out to r24, centred 2.15 studs in front of Terra | Same (around Terra) |
| Benediction (Technique) | Radiant | The staff planted at Radiant's feet, healing allies within 25 | Same (package v3 makes it mobile, r35) |
| Halo (Ultimate) | Radiant | A team aura, r40 around Radiant. A buff, not a placed zone, so not converted | Same |
| Decoy Double (Technique) | Umbra | A standing copy placed beside Umbra. A decoy with no area, so not converted; putting it at the cursor would be a design call, not a range | Same |
| Caster-anchored, not placed zones | — | Bulwark Wall and Cinder Shield (shields in front), Scorching Lash (a sweep across the front), Undertow (a cone aimed by look direction), Deflect Gust (a parry). Not converted | — |
| Everything else | — | Aimed: Mirror Cage (lock within 60), Twin Tide, Leviathan's Maw, Ring of Fire, Cyclone, Cascade, Acid Rain, Gust Pad, Volt Orb. Self buffs with no area: Immolate, Antitoxin Vent, Eclipse | — |

**This is a discrepancy in my earlier sims.** Every 3v3 result before today aimed Blizzard and Deep Freeze, which
overstated Cryo. The baseline for P28 and P29 uses the live versions. In package v3, on the same seeds, that moves Cryo
from 50.7% to 48.8%. Every other Element stays within noise, and every pairing without a Cryo comes out identical. It
also affects:
- **P27's Cryo figures,** which are about 1.9 points high.
- **The 3v3 report's Cryo peel findings** (Deep Freeze trapping divers near teammates in S3 and S5). Live, Deep Freeze
  can only trap a diver who comes to Cryo herself.
- **The 1v1 work's "Cryo's tools fight a chaser's approach"** (P23 finding 3). That came from the 1v1 sim, which was not
  re-checked here.

## How it was modelled

- **Base:** team package v3 on today's live values (`SPELLSHOT_TEAM_MODE_PACKAGES.md`), with live Blizzard and Deep
  Freeze. Every run is the 84-comp round-robin (3,486 pairings), 6 rounds per pairing, no jump, lowest-HP focus, and
  "cover each other's back" teamwork on, the same rigour as P27. The baseline was also run on a second seed set as a
  noise check.

**P28, Twin Tide as cover:**
- **When Aqua uses it:** if a teammate within reach (or Aqua herself, in (a) and (b)) is taking fire from enemies at
  least 12 studs away, Aqua aims the lane across the line of fire through that player, so the wall on the shooters' side
  stands between.
  - The lane's axis always follows Aqua's aim, so she can only turn it by aiming to one side.
  - If no aim puts the walls within 30° of square-on to the fire, she doesn't cast it as cover, and uses it to crush as
    before. Those walls block too.
- **Cover replaces most crushes.** Crush damage falls from 13.0 to 3.6 per Aqua per round. So every variant is also
  measured against a **rule-only control:** the same cover-casting, with walls that block nothing. "Blocking alone"
  in the tables is the change against that control.
- **What a wall blocks:** any aimed enemy shot whose path crosses a standing wall, while the wall has HP left. It
  doesn't stop area damage, as with Bulwark Wall in the sim. Each wall follows the live geometry and timing above:
  24 long, 11 off the centre line, closing to 3.55, and standing from 0.16 s to 1.1 s.
- **The variants:**
  - **(a)** one wall (the shooters' side) with the whole HP pool.
  - **(b)** both live walls, each with the stated HP. Note this is not the spec's "two smaller walls": it is (a) plus
    the far-side wall at the same total HP.
  - **(c)** like (a), but shots at Aqua herself go through, and Aqua never casts it for herself.
- **Added by me (not in the spec):** the met walls stand 3 s or 6 s longer before the flipbook, so they are up about
  3.9 s or 6.9 s in all. The live walls are gone too fast to show what a protector Twin Tide could do.
- **Technique-swap check (P25's lever):** every non-Aqua Element's Defense Technique replaced by Twin Tide, each comp
  played against the 83 others. The control is the same run on the same seeds without the swap, and with the same wall
  setting, because the wall rule also applies to every native Aqua. Bulwark Wall's swap was run the same way, for
  comparison.

**P29, cursor-targeting:**
- **Where the bots aim:** for each enemy in reach, a spot on it, pulled in to the cast range. The spot that catches the
  most enemies wins; ties go to a diver on a teammate, then to the nearest. Flash Freeze is cast once an enemy is within
  range + 5, Blizzard within range + 16 (half its radius), Aftershock within range + 12.
- **Deep Freeze:** aimed at a diver within range of Cryo; when the diver is further out, on its path at full range.
  Benediction goes on the hurt teammates' centre, up to its range.
- **Doses (a), straight conversion, numbers unchanged:**
  - Flash Freeze 15 / 20 / 25;
  - Blizzard 20 / 32 / 45 (its radius is 32);
  - Deep Freeze 10 / 20 / 30. Its reach is 4, so the spec's "about its own radius" rule gives nonsense, and trap
    placement ranges were used instead;
  - Aftershock 15 / 24 / 35 (radius 24);
  - Benediction 20 / 35 / 50 (radius 35 in v3).
- **(b) conversion with a trade-off:**
  - Flash Freeze at 20 with radius 20 → 14, or a 0.78 s wind-up instead of 0.38, or a 2.5 s freeze instead of 4.
  - Blizzard at 32 with radius 32 → 24, or 4 s instead of 6. In the main runs the storm slows 0.6 s longer than live:
    6.6 s, and 4.6 s in this trade-off.
  - (b) was not run for Deep Freeze, Aftershock or Benediction: their straight conversions gained nothing (−0.8 to
    +0.1) at any range, so there was no power to pull back.
- **"Contact"** is the spec's close-range metric. It counts each time an enemy closes to 16 studs on a player, and
  counts that enemy again only once it has gone past 30.
  - The contact is lost if the player dies within 6 s, before the enemy who closed; it is won if that enemy dies first.
  - Counts are per player-round, so one death after two enemies closed counts twice.
- **Checks added beyond the specs:** the rule-only controls, the matched swap controls, the Bulwark Wall swap and the
  robustness runs. The robustness runs repeat the baseline and the main Flash Freeze and Blizzard runs with Blizzard's
  live 6 s and a Flash Freeze closer to live (see the Robustness table).

## Results

All runs: 6 rounds per pairing, 3,486 pairings, no jump, lowest-HP focus, teamwork on, package v3, live Cryo.

Noise: the baseline on a second seed set moves every Element by at most 0.8 points (Aqua -0.1, Cryo +0.3, Terra +0.8); single comps by an SD of 2.3 (largest 7.6); the comp spread by +0.4; the 'neither Terra nor Aqua' group by -0.2. Cryo's contacts: lost 44% -> 43%, won 30% -> 32%, lost per round 0.124 -> 0.120.

Step 0 correction (P27's v3 baseline, which aimed Blizzard and Deep Freeze, -> live Cryo, same seeds): Aqu 43.4 -> 43.7, Cry 50.7 -> 48.8, Pyr 59.8 -> 60.6, Rad 47.7 -> 47.9, Ter 70.8 -> 70.6, Tox 48.2 -> 48.6, Umb 42.3 -> 42.1, Vol 44.2 -> 44.5, Zep 42.8 -> 43.2; comp spread 20.1 -> 20.1. Cryo casts per round: Blizzard 0.61 -> 0.32, Deep Freeze 0.81 -> 0.31.

## P28: Twin Tide walls that block shots

Changes are against the baseline; "blocking alone" is Aqua against the matching rule-only control (same cover-casting, walls that block nothing).

| Run | Aqua comps | Blocking alone (Aqua) | Terra comps | Terra + Aqua | Terra, no Aqua | Aqua, no Terra | Neither | Comp spread (SD) | Best - worst Element | Bottom 6 with neither Terra nor Aqua | Top 6 with Terra / Aqua | Twin Tide per Aqua per round: cover casts · HP absorbed · crush damage | Aqua dies % |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| v3, live Cryo (baseline) | 43.7 | — | 70.6 | 60.9 | 73.9 | 37.9 | 40.7 | 20.1 | 29 | 5 | 6 / 0 | 0.00 · 0 · 13.0 | 62% |
| baseline, second seed set (noise) | 43.6 (-0.1) | — | 71.4 (+0.8) | 62.4 (+1.5) | 74.4 (+0.5) | 37.3 (-0.6) | 40.5 (-0.2) | 20.5 | 29 | 4 | 6 / 0 | 0.00 · 0 · 13.2 | 61% |
| control: cover rule on, no blocking (for a, b) | 42.8 (-0.9) | — | 71.0 (+0.3) | 61.1 (+0.2) | 74.2 (+0.4) | 36.7 (-1.3) | 41.2 (+0.5) | 20.4 | 29 | 4 | 6 / 0 | 0.98 · 0 · 3.6 | 62% |
| control: cover rule for allies only, no blocking (for c) | 43.0 (-0.7) | — | 70.9 (+0.3) | 61.1 (+0.2) | 74.2 (+0.4) | 36.9 (-1.0) | 41.1 (+0.4) | 20.4 | 29 | 4 | 6 / 0 | 0.78 · 0 · 5.1 | 62% |
| (a) one wall, 150 | 45.1 (+1.4) | +2.3 | 70.7 (+0.1) | 62.2 (+1.3) | 73.5 (-0.4) | 39.3 (+1.4) | 39.9 (-0.9) | 20.1 | 29 | 6 | 6 / 0 | 0.99 · 13 · 3.6 | 60% |
| (a) one wall, 200 | 45.1 (+1.4) | +2.3 | 70.7 (+0.1) | 62.2 (+1.3) | 73.5 (-0.4) | 39.3 (+1.4) | 39.9 (-0.9) | 20.1 | 29 | 6 | 6 / 0 | 0.99 · 13 · 3.6 | 60% |
| (a) one wall, 250 | 45.1 (+1.4) | +2.3 | 70.7 (+0.1) | 62.2 (+1.3) | 73.5 (-0.4) | 39.3 (+1.4) | 39.9 (-0.9) | 20.1 | 29 | 6 | 6 / 0 | 0.99 · 13 · 3.6 | 60% |
| (b) twin walls, 100 + 100 | 45.3 (+1.6) | +2.5 | 70.6 (-0.1) | 62.0 (+1.1) | 73.4 (-0.5) | 39.7 (+1.8) | 39.8 (-1.0) | 20.1 | 29 | 6 | 6 / 0 | 0.99 · 14 · 3.6 | 60% |
| (b) twin walls, 125 + 125 | 45.3 (+1.6) | +2.5 | 70.5 (-0.1) | 62.0 (+1.1) | 73.4 (-0.5) | 39.7 (+1.8) | 39.8 (-1.0) | 20.1 | 29 | 6 | 6 / 0 | 0.99 · 14 · 3.6 | 60% |
| (c) allies only, 150 | 44.5 (+0.8) | +1.5 | 70.8 (+0.1) | 62.3 (+1.4) | 73.6 (-0.3) | 38.6 (+0.7) | 40.2 (-0.5) | 20.1 | 29 | 6 | 6 / 0 | 0.78 · 9 · 5.2 | 61% |
| (c) allies only, 200 | 44.5 (+0.8) | +1.5 | 70.8 (+0.1) | 62.3 (+1.4) | 73.6 (-0.3) | 38.6 (+0.7) | 40.2 (-0.5) | 20.1 | 29 | 6 | 6 / 0 | 0.78 · 9 · 5.2 | 61% |
| (c) allies only, 250 | 44.5 (+0.8) | +1.5 | 70.8 (+0.1) | 62.3 (+1.4) | 73.6 (-0.3) | 38.6 (+0.7) | 40.2 (-0.5) | 20.1 | 29 | 6 | 6 / 0 | 0.78 · 9 · 5.2 | 61% |
| added: (a) 150, met walls stand 3 s (up ~3.9 s) | 49.3 (+5.6) | +6.5 | 69.4 (-1.2) | 64.7 (+3.8) | 71.0 (-2.9) | 44.2 (+6.2) | 37.9 (-2.8) | 19.6 | 28 | 6 | 6 / 0 | 1.00 · 43 · 3.7 | 55% |
| added: (a) 200, stand 3 s | 49.5 (+5.9) | +6.8 | 69.3 (-1.3) | 64.7 (+3.8) | 70.9 (-3.0) | 44.5 (+6.6) | 37.8 (-2.9) | 19.6 | 28 | 6 | 6 / 0 | 1.00 · 45 · 3.7 | 55% |
| added: (a) 250, stand 3 s | 49.6 (+5.9) | +6.8 | 69.3 (-1.3) | 64.7 (+3.8) | 70.9 (-3.0) | 44.5 (+6.6) | 37.8 (-2.9) | 19.6 | 28 | 6 | 6 / 0 | 1.00 · 46 · 3.7 | 55% |
| added: (b) 100 + 100, stand 3 s | 50.3 (+6.6) | +7.5 | 68.7 (-2.0) | 64.5 (+3.6) | 70.1 (-3.8) | 45.5 (+7.6) | 37.7 (-3.0) | 19.4 | 27 | 6 | 6 / 1 | 1.00 · 46 · 3.7 | 54% |
| added: (c) 200, stand 3 s | 48.0 (+4.4) | +5.1 | 69.6 (-1.0) | 63.9 (+3.0) | 71.5 (-2.4) | 42.7 (+4.8) | 38.7 (-2.1) | 19.7 | 28 | 6 | 6 / 0 | 0.79 · 30 · 5.3 | 57% |
| added: (a) 200, stand 6 s (up ~6.9 s) | 51.8 (+8.1) | +9.0 | 68.3 (-2.3) | 65.4 (+4.5) | 69.3 (-4.6) | 47.2 (+9.3) | 37.0 (-3.7) | 19.3 | 27 | 6 | 6 / 0 | 1.00 · 60 · 3.7 | 53% |
| added: together, (a) 200 stand 3 s + Flash Freeze 25 + Blizzard 32 | 49.4 (+5.8) | — | 70.7 (+0.0) | 65.9 (+5.0) | 72.3 (-1.6) | 44.0 (+6.0) | 37.1 (-3.7) | 20.2 | 30 | 6 | 6 / 0 | 0.99 · 45 · 3.9 | 55% |

## P29: cursor-targeted versions of the self-centred abilities

Contact = an enemy closes to 16 studs on a player (counted again only after that enemy has gone past 30). Lost = the player dies within 6 s of it, before the enemy who closed; won = that enemy dies first. Counts are per player-round, so one death after two enemies closed counts twice.

| Run | Element | Its comps (vs baseline) | Its comps with Terra / without Terra | Dies % | Contacts per round | Contacts lost · won | Lost contacts per round | Casts per round | Terra comps | Comp spread (SD) | Best - worst | In bottom 6 / top 6 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| baseline: Cryo | Cryo | 48.8 | — | 84% | 0.28 | 44% · 30% | 0.124 | FF 0.14 / BZ 0.32 / DF 0.31 | 70.6 | 20.1 | 29 | 3 / 1 |
| baseline: Terra | Terra | 70.6 | — | 40% | 2.14 | 8% · 33% | 0.169 | AS 0.65 | 70.6 | 20.1 | 29 | 0 / 6 |
| baseline: Radiant | Radiant | 47.9 | — | 73% | 0.63 | 49% · 18% | 0.312 | BN 0.66 | 70.6 | 20.1 | 29 | 3 / 1 |
| Flash Freeze at the cursor, range 15 | Cryo | 49.5 (+0.6) | +1.7 / +0.3 | 83% | 0.29 | 41% · 33% | 0.119 | FF 0.19 / BZ 0.31 / DF 0.31 | 70.6 (-0.1) | 20.0 | 29 | 3 / 1 |
| Flash Freeze, range 20 | Cryo | 50.2 (+1.4) | +2.7 / +1.0 | 83% | 0.29 | 42% · 34% | 0.122 | FF 0.29 / BZ 0.26 / DF 0.31 | 70.4 (-0.2) | 19.9 | 28 | 2 / 2 |
| Flash Freeze, range 25 | Cryo | 51.0 (+2.2) | +4.8 / +1.3 | 82% | 0.27 | 38% · 39% | 0.102 | FF 0.42 / BZ 0.23 / DF 0.23 | 70.5 (-0.1) | 20.0 | 28 | 2 / 2 |
| (b) Flash Freeze 20, radius 20 -> 14 | Cryo | 49.7 (+0.9) | +1.5 / +0.7 | 83% | 0.29 | 44% · 32% | 0.129 | FF 0.29 / BZ 0.25 / DF 0.30 | 70.4 (-0.2) | 19.9 | 28 | 2 / 1 |
| (b) Flash Freeze 20, wind-up 0.38 -> 0.78 s | Cryo | 49.4 (+0.6) | +0.9 / +0.5 | 83% | 0.30 | 44% · 31% | 0.132 | FF 0.29 / BZ 0.22 / DF 0.28 | 70.3 (-0.3) | 19.8 | 28 | 2 / 1 |
| (b) Flash Freeze 20, freeze 4 -> 2.5 s | Cryo | 50.4 (+1.6) | +2.9 / +1.1 | 83% | 0.29 | 40% · 35% | 0.117 | FF 0.29 / BZ 0.26 / DF 0.31 | 70.4 (-0.3) | 19.9 | 28 | 2 / 1 |
| Blizzard at the cursor, range 20 | Cryo | 49.7 (+0.9) | +1.4 / +0.7 | 84% | 0.22 | 41% · 36% | 0.089 | FF 0.11 / BZ 0.51 / DF 0.26 | 70.9 (+0.2) | 20.0 | 29 | 2 / 1 |
| Blizzard, range 32 | Cryo | 50.4 (+1.6) | +3.2 / +1.1 | 83% | 0.23 | 38% · 38% | 0.087 | FF 0.11 / BZ 0.90 / DF 0.29 | 72.1 (+1.5) | 20.4 | 30 | 3 / 1 |
| Blizzard, range 45 | Cryo | 50.6 (+1.8) | +5.6 / +0.5 | 83% | 0.22 | 40% · 38% | 0.089 | FF 0.11 / BZ 1.03 / DF 0.29 | 72.7 (+2.1) | 20.6 | 31 | 2 / 1 |
| (b) Blizzard 32, radius 32 -> 24 | Cryo | 49.7 (+0.9) | +3.1 / +0.2 | 84% | 0.23 | 39% · 36% | 0.089 | FF 0.11 / BZ 0.84 / DF 0.29 | 71.9 (+1.3) | 20.4 | 30 | 2 / 1 |
| (b) Blizzard 32, 4 s (sim: 6.6 -> 4.6 s) | Cryo | 49.1 (+0.3) | +2.5 / -0.4 | 84% | 0.24 | 39% · 37% | 0.095 | FF 0.12 / BZ 0.90 / DF 0.30 | 72.3 (+1.6) | 20.4 | 30 | 3 / 1 |
| Deep Freeze at the cursor, range 10 | Cryo | 48.7 (-0.1) | +0.2 / -0.2 | 84% | 0.28 | 43% · 31% | 0.122 | FF 0.14 / BZ 0.32 / DF 0.31 | 70.8 (+0.1) | 20.0 | 29 | 3 / 1 |
| Deep Freeze, range 20 | Cryo | 48.8 (-0.0) | +0.4 / -0.2 | 84% | 0.28 | 42% · 31% | 0.118 | FF 0.14 / BZ 0.31 / DF 0.31 | 70.8 (+0.2) | 20.1 | 29 | 3 / 1 |
| Deep Freeze, range 30 | Cryo | 48.9 (+0.1) | +0.5 / -0.1 | 84% | 0.28 | 42% · 32% | 0.118 | FF 0.14 / BZ 0.31 / DF 0.35 | 70.8 (+0.1) | 20.1 | 29 | 3 / 1 |
| All three Cryo (FF 20, BZ 32, DF 20) | Cryo | 51.6 (+2.8) | +7.0 / +1.4 | 82% | 0.24 | 33% · 45% | 0.077 | FF 0.24 / BZ 0.90 / DF 0.25 | 72.4 (+1.7) | 20.6 | 30 | 3 / 3 |
| Aftershock at the cursor, range 15 | Terra | 70.5 (-0.2) | — | 41% | 2.10 | 8% · 34% | 0.173 | AS 0.85 | 70.5 (-0.2) | 20.1 | 29 | 0 / 6 |
| Aftershock, range 24 | Terra | 70.3 (-0.3) | — | 42% | 2.06 | 8% · 33% | 0.169 | AS 1.09 | 70.3 (-0.3) | 19.9 | 28 | 0 / 6 |
| Aftershock, range 35 | Terra | 70.2 (-0.5) | — | 42% | 2.04 | 8% · 32% | 0.173 | AS 1.17 | 70.2 (-0.5) | 19.8 | 28 | 0 / 6 |
| Benediction at the cursor, range 20 | Radiant | 47.2 (-0.7) | -0.2 / -0.9 | 74% | 0.64 | 50% · 18% | 0.318 | BN 0.68 | 70.7 (+0.1) | 19.9 | 28 | 3 / 1 |
| Benediction, range 35 | Radiant | 47.3 (-0.6) | -0.3 / -0.7 | 74% | 0.64 | 50% · 18% | 0.317 | BN 0.68 | 70.7 (+0.0) | 19.9 | 28 | 2 / 1 |
| Benediction, range 50 | Radiant | 47.1 (-0.8) | -0.2 / -1.0 | 74% | 0.64 | 50% · 17% | 0.318 | BN 0.68 | 70.8 (+0.1) | 20.0 | 28 | 3 / 1 |
| added: together, Twin Tide (a) 200 stand 3 s + Flash Freeze 25 + Blizzard 32 | Cryo | 51.6 (+2.8) | +5.5 / +1.9 | 81% | 0.26 | 34% · 41% | 0.087 | FF 0.33 / BZ 0.91 / DF 0.23 | 70.7 (+0.0) | 20.2 | 30 | 3 / 3 |

### Robustness (my addition): Blizzard's live 6 s and a Flash Freeze closer to live

The sim's Flash Freeze gives a caught body a 4 s root at once; live, the front eases out over 1 s, a touched body is slowed to 5 and only rooted after 1 s inside (so a body near the edge can still get out), and the root lasts to the zone's end, then shatters. The sim's Blizzard slowed for 6.6 s; live it is 6 s. These runs use the live front speed, root end, shatter time and 6 s Blizzard, baseline included. The 1 s-inside rule is approximated: a body that can't get within 5 studs of the edge before the front reaches it counts as caught, and is rooted (and takes its 10) from the cast, not from the touch, so it is held 4.88 s, against 4 s in the main runs and about 3 to 3.5 s of root live. Changes are against this baseline.

This timing vs the main baseline: Cryo 48.8 -> 48.8, Terra 70.6 -> 70.7; Cryo contacts lost 44% / won 30%, lost per round 0.125.

| Run | Cryo comps | With Terra / without Terra | Contacts lost · won | Lost contacts per round | Terra comps | Comp spread (SD) | Same run on the sim's timing |
|---|---|---|---|---|---|---|---|
| robustness baseline | 48.8 | — | 44% · 30% | 0.125 | 70.7 | 20.1 | — |
| robustness: Flash Freeze, range 20 | 50.3 (+1.4) | +2.5 / +1.1 | 42% · 33% | 0.124 | 70.3 (-0.4) | 19.9 | Cryo +1.4 |
| robustness: Flash Freeze, range 25 | 50.8 (+1.9) | +4.0 / +1.2 | 39% · 38% | 0.104 | 70.4 (-0.3) | 19.9 | Cryo +2.2 |
| robustness: Blizzard, range 32 | 50.0 (+1.1) | +3.4 / +0.4 | 40% · 36% | 0.093 | 72.4 (+1.7) | 20.5 | Cryo +1.6 |

## Element win % per run

| Run | Aqua | Cryo | Pyro | Radiant | Terra | Toxin | Umbra | Voltaic | Zephyr |
|---|---|---|---|---|---|---|---|---|---|
| P27 v3 baseline (aimed Blizzard / Deep Freeze) | 43.4 | 50.7 | 59.8 | 47.7 | 70.8 | 48.2 | 42.3 | 44.2 | 42.8 |
| v3, live Cryo (baseline) | 43.7 | 48.8 | 60.6 | 47.9 | 70.6 | 48.6 | 42.1 | 44.5 | 43.2 |
| baseline, second seed set (noise) | 43.6 | 49.1 | 59.8 | 48.1 | 71.4 | 49.0 | 42.0 | 43.8 | 43.1 |
| control: cover rule on, no blocking (for a, b) | 42.8 | 48.8 | 60.7 | 48.3 | 71.0 | 48.9 | 41.9 | 44.4 | 43.3 |
| control: cover rule for allies only, no blocking (for c) | 43.0 | 48.8 | 60.7 | 48.1 | 70.9 | 48.9 | 41.7 | 44.4 | 43.4 |
| (a) one wall, 150 | 45.1 | 48.7 | 60.5 | 48.1 | 70.7 | 48.5 | 42.0 | 43.8 | 42.8 |
| (a) one wall, 200 | 45.1 | 48.7 | 60.5 | 48.1 | 70.7 | 48.5 | 42.0 | 43.8 | 42.8 |
| (a) one wall, 250 | 45.1 | 48.7 | 60.5 | 48.1 | 70.7 | 48.5 | 42.0 | 43.8 | 42.8 |
| (b) twin walls, 100 + 100 | 45.3 | 48.7 | 60.6 | 48.0 | 70.6 | 48.5 | 42.0 | 43.8 | 42.7 |
| (b) twin walls, 125 + 125 | 45.3 | 48.7 | 60.6 | 48.0 | 70.5 | 48.5 | 42.0 | 43.8 | 42.7 |
| (c) allies only, 150 | 44.5 | 48.8 | 60.6 | 47.9 | 70.8 | 48.5 | 41.8 | 44.1 | 43.1 |
| (c) allies only, 200 | 44.5 | 48.8 | 60.6 | 47.9 | 70.8 | 48.5 | 41.8 | 44.1 | 43.1 |
| (c) allies only, 250 | 44.5 | 48.8 | 60.6 | 47.9 | 70.8 | 48.5 | 41.8 | 44.1 | 43.1 |
| added: (a) 150, met walls stand 3 s (up ~3.9 s) | 49.3 | 48.4 | 60.4 | 47.5 | 69.4 | 48.2 | 41.7 | 42.9 | 42.1 |
| added: (a) 200, stand 3 s | 49.5 | 48.3 | 60.4 | 47.6 | 69.3 | 48.2 | 41.8 | 42.9 | 41.9 |
| added: (a) 250, stand 3 s | 49.6 | 48.3 | 60.4 | 47.6 | 69.3 | 48.2 | 41.8 | 42.8 | 41.9 |
| added: (b) 100 + 100, stand 3 s | 50.3 | 48.2 | 60.6 | 47.5 | 68.7 | 48.3 | 41.9 | 42.9 | 41.7 |
| added: (c) 200, stand 3 s | 48.0 | 48.5 | 60.8 | 47.6 | 69.6 | 48.1 | 42.0 | 43.0 | 42.3 |
| added: (a) 200, stand 6 s (up ~6.9 s) | 51.8 | 48.1 | 60.4 | 47.2 | 68.3 | 47.9 | 41.9 | 42.7 | 41.7 |
| added: together, (a) 200 stand 3 s + Flash Freeze 25 + Blizzard 32 | 49.4 | 51.6 | 59.2 | 47.0 | 70.7 | 47.8 | 42.3 | 41.2 | 40.8 |
| Flash Freeze at the cursor, range 15 | 43.8 | 49.5 | 60.4 | 47.9 | 70.6 | 48.5 | 42.0 | 44.3 | 43.1 |
| Flash Freeze, range 20 | 43.6 | 50.2 | 60.2 | 48.1 | 70.4 | 48.4 | 42.1 | 44.1 | 42.9 |
| Flash Freeze, range 25 | 43.6 | 51.0 | 59.9 | 47.8 | 70.5 | 48.2 | 42.2 | 44.0 | 42.7 |
| (b) Flash Freeze 20, radius 20 -> 14 | 43.7 | 49.7 | 60.3 | 48.1 | 70.4 | 48.4 | 42.0 | 44.3 | 43.0 |
| (b) Flash Freeze 20, wind-up 0.38 -> 0.78 s | 43.9 | 49.4 | 60.2 | 48.0 | 70.3 | 48.4 | 42.0 | 44.5 | 43.2 |
| (b) Flash Freeze 20, freeze 4 -> 2.5 s | 43.9 | 50.4 | 60.2 | 47.9 | 70.4 | 48.2 | 42.0 | 44.2 | 42.9 |
| Blizzard at the cursor, range 20 | 43.8 | 49.7 | 60.1 | 47.7 | 70.9 | 48.4 | 42.3 | 44.2 | 43.0 |
| Blizzard, range 32 | 44.0 | 50.4 | 59.2 | 47.3 | 72.1 | 48.5 | 42.5 | 43.4 | 42.6 |
| Blizzard, range 45 | 44.0 | 50.6 | 58.9 | 47.1 | 72.7 | 48.3 | 42.2 | 43.5 | 42.8 |
| (b) Blizzard 32, radius 32 -> 24 | 44.3 | 49.7 | 59.6 | 47.5 | 71.9 | 48.5 | 42.4 | 43.4 | 42.7 |
| (b) Blizzard 32, 4 s (sim: 6.6 -> 4.6 s) | 44.1 | 49.1 | 59.5 | 47.6 | 72.3 | 48.5 | 42.1 | 44.1 | 42.7 |
| Deep Freeze at the cursor, range 10 | 43.7 | 48.7 | 60.4 | 47.9 | 70.8 | 48.5 | 42.1 | 44.5 | 43.2 |
| Deep Freeze, range 20 | 43.7 | 48.8 | 60.4 | 48.0 | 70.8 | 48.6 | 42.1 | 44.4 | 43.2 |
| Deep Freeze, range 30 | 43.7 | 48.9 | 60.5 | 48.1 | 70.8 | 48.4 | 42.1 | 44.5 | 43.1 |
| All three Cryo (FF 20, BZ 32, DF 20) | 44.0 | 51.6 | 58.9 | 47.1 | 72.4 | 48.4 | 42.5 | 42.9 | 42.3 |
| Aftershock at the cursor, range 15 | 44.2 | 48.9 | 60.8 | 47.8 | 70.5 | 48.7 | 41.7 | 44.2 | 43.1 |
| Aftershock, range 24 | 44.4 | 48.8 | 60.8 | 48.0 | 70.3 | 48.6 | 42.2 | 43.9 | 42.9 |
| Aftershock, range 35 | 44.8 | 49.0 | 60.7 | 48.1 | 70.2 | 48.5 | 42.1 | 43.8 | 42.8 |
| Benediction at the cursor, range 20 | 44.1 | 48.4 | 60.6 | 47.2 | 70.7 | 48.9 | 42.3 | 44.7 | 43.2 |
| Benediction, range 35 | 44.0 | 48.3 | 60.6 | 47.3 | 70.7 | 48.9 | 42.3 | 44.6 | 43.4 |
| Benediction, range 50 | 44.0 | 48.4 | 60.6 | 47.1 | 70.8 | 48.9 | 42.3 | 44.6 | 43.3 |
| robustness baseline | 43.7 | 48.8 | 60.6 | 48.1 | 70.7 | 48.5 | 41.9 | 44.5 | 43.1 |
| robustness: Flash Freeze, range 20 | 43.9 | 50.3 | 60.3 | 48.0 | 70.3 | 48.4 | 42.1 | 44.0 | 42.8 |
| robustness: Flash Freeze, range 25 | 43.8 | 50.8 | 60.0 | 47.8 | 70.4 | 48.4 | 42.2 | 43.8 | 42.8 |
| robustness: Blizzard, range 32 | 44.1 | 50.0 | 59.2 | 47.4 | 72.4 | 48.5 | 42.4 | 43.4 | 42.6 |

**v3, live Cryo (baseline)** — bottom 6: Radiant + Voltaic + Zephyr 23, Aqua + Cryo + Voltaic 21, Cryo + Toxin + Voltaic 21, Cryo + Umbra + Voltaic 19, Radiant + Umbra + Zephyr 17, Radiant + Umbra + Voltaic 14 | top 6: Pyro + Terra + Toxin 93, Cryo + Pyro + Terra 89, Pyro + Terra + Voltaic 86, Pyro + Radiant + Terra 85, Pyro + Terra + Zephyr 84, Terra + Toxin + Voltaic 83
**baseline, second seed set (noise)** — bottom 6: Toxin + Umbra + Voltaic 22, Aqua + Cryo + Voltaic 21, Aqua + Voltaic + Zephyr 21, Radiant + Umbra + Zephyr 18, Cryo + Umbra + Voltaic 17, Radiant + Umbra + Voltaic 15 | top 6: Pyro + Terra + Toxin 95, Cryo + Pyro + Terra 87, Pyro + Terra + Voltaic 86, Pyro + Radiant + Terra 85, Pyro + Terra + Zephyr 83, Terra + Toxin + Voltaic 81
**control: cover rule on, no blocking (for a, b)** — bottom 6: Cryo + Toxin + Voltaic 22, Aqua + Voltaic + Zephyr 22, Aqua + Radiant + Zephyr 21, Radiant + Umbra + Zephyr 18, Cryo + Umbra + Voltaic 16, Radiant + Umbra + Voltaic 14 | top 6: Pyro + Terra + Toxin 93, Cryo + Pyro + Terra 89, Pyro + Radiant + Terra 88, Pyro + Terra + Voltaic 84, Pyro + Terra + Zephyr 84, Terra + Toxin + Voltaic 84
**control: cover rule for allies only, no blocking (for c)** — bottom 6: Cryo + Toxin + Voltaic 22, Aqua + Cryo + Voltaic 22, Aqua + Voltaic + Zephyr 21, Radiant + Umbra + Zephyr 18, Cryo + Umbra + Voltaic 17, Radiant + Umbra + Voltaic 14 | top 6: Pyro + Terra + Toxin 93, Cryo + Pyro + Terra 89, Pyro + Radiant + Terra 87, Pyro + Terra + Voltaic 85, Pyro + Terra + Zephyr 84, Terra + Toxin + Voltaic 84
**(a) one wall, 150** — bottom 6: Toxin + Umbra + Voltaic 22, Radiant + Voltaic + Zephyr 21, Cryo + Toxin + Voltaic 20, Radiant + Umbra + Zephyr 17, Cryo + Umbra + Voltaic 16, Radiant + Umbra + Voltaic 12 | top 6: Pyro + Terra + Toxin 93, Cryo + Pyro + Terra 89, Pyro + Radiant + Terra 87, Pyro + Terra + Voltaic 84, Terra + Toxin + Voltaic 83, Pyro + Terra + Zephyr 83
**(a) one wall, 200** — bottom 6: Toxin + Umbra + Voltaic 22, Radiant + Voltaic + Zephyr 21, Cryo + Toxin + Voltaic 20, Radiant + Umbra + Zephyr 17, Cryo + Umbra + Voltaic 16, Radiant + Umbra + Voltaic 12 | top 6: Pyro + Terra + Toxin 93, Cryo + Pyro + Terra 89, Pyro + Radiant + Terra 87, Pyro + Terra + Voltaic 84, Terra + Toxin + Voltaic 83, Pyro + Terra + Zephyr 83
**(a) one wall, 250** — bottom 6: Toxin + Umbra + Voltaic 22, Radiant + Voltaic + Zephyr 21, Cryo + Toxin + Voltaic 20, Radiant + Umbra + Zephyr 17, Cryo + Umbra + Voltaic 16, Radiant + Umbra + Voltaic 12 | top 6: Pyro + Terra + Toxin 93, Cryo + Pyro + Terra 89, Pyro + Radiant + Terra 87, Pyro + Terra + Voltaic 84, Terra + Toxin + Voltaic 83, Pyro + Terra + Zephyr 83
**(b) twin walls, 100 + 100** — bottom 6: Toxin + Umbra + Voltaic 22, Cryo + Toxin + Voltaic 20, Radiant + Voltaic + Zephyr 20, Radiant + Umbra + Zephyr 17, Cryo + Umbra + Voltaic 16, Radiant + Umbra + Voltaic 12 | top 6: Pyro + Terra + Toxin 93, Cryo + Pyro + Terra 89, Pyro + Radiant + Terra 87, Pyro + Terra + Voltaic 84, Terra + Toxin + Voltaic 83, Pyro + Terra + Zephyr 83
**(b) twin walls, 125 + 125** — bottom 6: Toxin + Umbra + Voltaic 22, Cryo + Toxin + Voltaic 20, Radiant + Voltaic + Zephyr 20, Radiant + Umbra + Zephyr 17, Cryo + Umbra + Voltaic 16, Radiant + Umbra + Voltaic 12 | top 6: Pyro + Terra + Toxin 93, Cryo + Pyro + Terra 89, Pyro + Radiant + Terra 87, Pyro + Terra + Voltaic 84, Terra + Toxin + Voltaic 83, Pyro + Terra + Zephyr 83
**(c) allies only, 150** — bottom 6: Toxin + Umbra + Voltaic 23, Radiant + Voltaic + Zephyr 23, Cryo + Toxin + Voltaic 20, Radiant + Umbra + Zephyr 18, Cryo + Umbra + Voltaic 16, Radiant + Umbra + Voltaic 13 | top 6: Pyro + Terra + Toxin 93, Cryo + Pyro + Terra 89, Pyro + Radiant + Terra 87, Pyro + Terra + Voltaic 84, Pyro + Terra + Zephyr 83, Terra + Toxin + Voltaic 83
**(c) allies only, 200** — bottom 6: Toxin + Umbra + Voltaic 23, Radiant + Voltaic + Zephyr 23, Cryo + Toxin + Voltaic 20, Radiant + Umbra + Zephyr 18, Cryo + Umbra + Voltaic 16, Radiant + Umbra + Voltaic 13 | top 6: Pyro + Terra + Toxin 93, Cryo + Pyro + Terra 89, Pyro + Radiant + Terra 87, Pyro + Terra + Voltaic 84, Pyro + Terra + Zephyr 83, Terra + Toxin + Voltaic 83
**(c) allies only, 250** — bottom 6: Toxin + Umbra + Voltaic 23, Radiant + Voltaic + Zephyr 23, Cryo + Toxin + Voltaic 20, Radiant + Umbra + Zephyr 18, Cryo + Umbra + Voltaic 16, Radiant + Umbra + Voltaic 13 | top 6: Pyro + Terra + Toxin 93, Cryo + Pyro + Terra 89, Pyro + Radiant + Terra 87, Pyro + Terra + Voltaic 84, Pyro + Terra + Zephyr 83, Terra + Toxin + Voltaic 83
**added: (a) 150, met walls stand 3 s (up ~3.9 s)** — bottom 6: Radiant + Toxin + Umbra 21, Radiant + Voltaic + Zephyr 18, Cryo + Toxin + Voltaic 18, Cryo + Umbra + Voltaic 16, Radiant + Umbra + Zephyr 16, Radiant + Umbra + Voltaic 11 | top 6: Pyro + Terra + Toxin 92, Cryo + Pyro + Terra 88, Pyro + Radiant + Terra 86, Pyro + Terra + Voltaic 84, Pyro + Terra + Zephyr 81, Terra + Toxin + Voltaic 79
**added: (a) 200, stand 3 s** — bottom 6: Radiant + Toxin + Umbra 21, Cryo + Toxin + Voltaic 18, Radiant + Voltaic + Zephyr 18, Cryo + Umbra + Voltaic 16, Radiant + Umbra + Zephyr 16, Radiant + Umbra + Voltaic 11 | top 6: Pyro + Terra + Toxin 92, Cryo + Pyro + Terra 88, Pyro + Radiant + Terra 86, Pyro + Terra + Voltaic 84, Pyro + Terra + Zephyr 81, Terra + Toxin + Voltaic 79
**added: (a) 250, stand 3 s** — bottom 6: Radiant + Toxin + Umbra 21, Cryo + Toxin + Voltaic 18, Radiant + Voltaic + Zephyr 18, Cryo + Umbra + Voltaic 16, Radiant + Umbra + Zephyr 16, Radiant + Umbra + Voltaic 11 | top 6: Pyro + Terra + Toxin 92, Cryo + Pyro + Terra 88, Pyro + Radiant + Terra 86, Pyro + Terra + Voltaic 84, Pyro + Terra + Zephyr 81, Terra + Toxin + Voltaic 79
**added: (b) 100 + 100, stand 3 s** — bottom 6: Radiant + Toxin + Voltaic 21, Cryo + Toxin + Voltaic 17, Radiant + Voltaic + Zephyr 17, Cryo + Umbra + Voltaic 16, Radiant + Umbra + Zephyr 16, Radiant + Umbra + Voltaic 11 | top 6: Pyro + Terra + Toxin 92, Cryo + Pyro + Terra 88, Pyro + Radiant + Terra 86, Pyro + Terra + Voltaic 83, Pyro + Terra + Zephyr 81, Aqua + Pyro + Terra 78
**added: (c) 200, stand 3 s** — bottom 6: Radiant + Toxin + Voltaic 22, Radiant + Voltaic + Zephyr 19, Cryo + Toxin + Voltaic 18, Cryo + Umbra + Voltaic 16, Radiant + Umbra + Zephyr 16, Radiant + Umbra + Voltaic 11 | top 6: Pyro + Terra + Toxin 92, Cryo + Pyro + Terra 89, Pyro + Radiant + Terra 86, Pyro + Terra + Voltaic 84, Pyro + Terra + Zephyr 82, Terra + Toxin + Voltaic 80
**added: (a) 200, stand 6 s (up ~6.9 s)** — bottom 6: Radiant + Toxin + Umbra 21, Radiant + Voltaic + Zephyr 17, Cryo + Toxin + Voltaic 17, Cryo + Umbra + Voltaic 16, Radiant + Umbra + Zephyr 15, Radiant + Umbra + Voltaic 11 | top 6: Pyro + Terra + Toxin 92, Cryo + Pyro + Terra 86, Pyro + Radiant + Terra 86, Pyro + Terra + Voltaic 82, Pyro + Terra + Zephyr 80, Terra + Toxin + Voltaic 78
**added: together, (a) 200 stand 3 s + Flash Freeze 25 + Blizzard 32** — bottom 6: Cryo + Voltaic + Zephyr 19, Cryo + Toxin + Voltaic 17, Radiant + Voltaic + Zephyr 17, Radiant + Umbra + Zephyr 16, Cryo + Umbra + Voltaic 15, Radiant + Umbra + Voltaic 11 | top 6: Pyro + Terra + Toxin 92, Cryo + Pyro + Terra 90, Pyro + Radiant + Terra 85, Cryo + Terra + Umbra 82, Pyro + Terra + Voltaic 81, Cryo + Radiant + Terra 80
**Flash Freeze at the cursor, range 15** — bottom 6: Radiant + Voltaic + Zephyr 23, Aqua + Cryo + Voltaic 23, Cryo + Toxin + Voltaic 21, Cryo + Umbra + Voltaic 19, Radiant + Umbra + Zephyr 17, Radiant + Umbra + Voltaic 14 | top 6: Pyro + Terra + Toxin 92, Cryo + Pyro + Terra 88, Pyro + Radiant + Terra 86, Pyro + Terra + Voltaic 85, Pyro + Terra + Zephyr 84, Terra + Toxin + Voltaic 80
**Flash Freeze, range 20** — bottom 6: Toxin + Umbra + Voltaic 23, Aqua + Voltaic + Zephyr 23, Cryo + Toxin + Voltaic 22, Cryo + Umbra + Voltaic 19, Radiant + Umbra + Zephyr 17, Radiant + Umbra + Voltaic 14 | top 6: Pyro + Terra + Toxin 92, Cryo + Pyro + Terra 88, Pyro + Radiant + Terra 85, Pyro + Terra + Voltaic 85, Pyro + Terra + Zephyr 83, Cryo + Radiant + Terra 80
**Flash Freeze, range 25** — bottom 6: Radiant + Voltaic + Zephyr 23, Aqua + Voltaic + Zephyr 23, Cryo + Toxin + Voltaic 21, Cryo + Umbra + Voltaic 20, Radiant + Umbra + Zephyr 17, Radiant + Umbra + Voltaic 14 | top 6: Pyro + Terra + Toxin 92, Cryo + Pyro + Terra 88, Pyro + Terra + Voltaic 85, Pyro + Radiant + Terra 84, Pyro + Terra + Zephyr 83, Cryo + Radiant + Terra 82
**(b) Flash Freeze 20, radius 20 -> 14** — bottom 6: Toxin + Umbra + Voltaic 23, Aqua + Voltaic + Zephyr 23, Cryo + Toxin + Voltaic 21, Cryo + Umbra + Voltaic 19, Radiant + Umbra + Zephyr 17, Radiant + Umbra + Voltaic 14 | top 6: Pyro + Terra + Toxin 93, Cryo + Pyro + Terra 87, Pyro + Radiant + Terra 85, Pyro + Terra + Voltaic 85, Pyro + Terra + Zephyr 83, Terra + Toxin + Voltaic 80
**(b) Flash Freeze 20, wind-up 0.38 -> 0.78 s** — bottom 6: Aqua + Voltaic + Zephyr 24, Toxin + Umbra + Voltaic 23, Cryo + Toxin + Voltaic 20, Cryo + Umbra + Voltaic 19, Radiant + Umbra + Zephyr 17, Radiant + Umbra + Voltaic 14 | top 6: Pyro + Terra + Toxin 92, Cryo + Pyro + Terra 87, Pyro + Radiant + Terra 85, Pyro + Terra + Voltaic 85, Pyro + Terra + Zephyr 83, Terra + Toxin + Voltaic 82
**(b) Flash Freeze 20, freeze 4 -> 2.5 s** — bottom 6: Aqua + Radiant + Zephyr 24, Toxin + Umbra + Voltaic 23, Cryo + Toxin + Voltaic 22, Cryo + Umbra + Voltaic 19, Radiant + Umbra + Zephyr 17, Radiant + Umbra + Voltaic 14 | top 6: Pyro + Terra + Toxin 92, Cryo + Pyro + Terra 88, Pyro + Radiant + Terra 85, Pyro + Terra + Voltaic 85, Pyro + Terra + Zephyr 83, Terra + Toxin + Voltaic 79
**Blizzard at the cursor, range 20** — bottom 6: Radiant + Voltaic + Zephyr 24, Aqua + Voltaic + Zephyr 23, Cryo + Toxin + Voltaic 23, Cryo + Umbra + Voltaic 19, Radiant + Umbra + Zephyr 17, Radiant + Umbra + Voltaic 14 | top 6: Pyro + Terra + Toxin 92, Cryo + Pyro + Terra 88, Pyro + Terra + Voltaic 86, Pyro + Radiant + Terra 85, Pyro + Terra + Zephyr 84, Terra + Toxin + Voltaic 84
**Blizzard, range 32** — bottom 6: Cryo + Voltaic + Zephyr 21, Cryo + Toxin + Voltaic 21, Aqua + Voltaic + Zephyr 20, Cryo + Umbra + Voltaic 17, Radiant + Umbra + Zephyr 17, Radiant + Umbra + Voltaic 14 | top 6: Pyro + Terra + Toxin 94, Cryo + Pyro + Terra 90, Pyro + Terra + Voltaic 86, Pyro + Radiant + Terra 85, Terra + Toxin + Voltaic 83, Pyro + Terra + Zephyr 82
**Blizzard, range 45** — bottom 6: Radiant + Voltaic + Zephyr 23, Aqua + Voltaic + Zephyr 22, Cryo + Toxin + Voltaic 21, Radiant + Umbra + Zephyr 19, Cryo + Umbra + Voltaic 17, Radiant + Umbra + Voltaic 14 | top 6: Pyro + Terra + Toxin 93, Cryo + Pyro + Terra 93, Pyro + Terra + Voltaic 86, Pyro + Radiant + Terra 85, Terra + Toxin + Voltaic 84, Pyro + Terra + Zephyr 82
**(b) Blizzard 32, radius 32 -> 24** — bottom 6: Aqua + Voltaic + Zephyr 22, Radiant + Voltaic + Zephyr 21, Cryo + Toxin + Voltaic 19, Cryo + Umbra + Voltaic 18, Radiant + Umbra + Zephyr 17, Radiant + Umbra + Voltaic 15 | top 6: Pyro + Terra + Toxin 93, Cryo + Pyro + Terra 91, Pyro + Terra + Voltaic 87, Pyro + Radiant + Terra 86, Terra + Toxin + Voltaic 83, Pyro + Terra + Zephyr 83
**(b) Blizzard 32, 4 s (sim: 6.6 -> 4.6 s)** — bottom 6: Aqua + Voltaic + Zephyr 22, Cryo + Voltaic + Zephyr 21, Cryo + Toxin + Voltaic 20, Radiant + Umbra + Zephyr 16, Cryo + Umbra + Voltaic 16, Radiant + Umbra + Voltaic 14 | top 6: Pyro + Terra + Toxin 94, Cryo + Pyro + Terra 89, Pyro + Terra + Voltaic 86, Pyro + Radiant + Terra 85, Terra + Toxin + Voltaic 84, Pyro + Terra + Zephyr 83
**Deep Freeze at the cursor, range 10** — bottom 6: Radiant + Voltaic + Zephyr 24, Aqua + Cryo + Voltaic 21, Cryo + Toxin + Voltaic 21, Cryo + Umbra + Voltaic 19, Radiant + Umbra + Zephyr 18, Radiant + Umbra + Voltaic 14 | top 6: Pyro + Terra + Toxin 93, Cryo + Pyro + Terra 88, Pyro + Terra + Voltaic 86, Pyro + Radiant + Terra 85, Pyro + Terra + Zephyr 84, Terra + Toxin + Voltaic 83
**Deep Freeze, range 20** — bottom 6: Radiant + Voltaic + Zephyr 23, Aqua + Cryo + Voltaic 22, Cryo + Toxin + Voltaic 21, Cryo + Umbra + Voltaic 19, Radiant + Umbra + Zephyr 18, Radiant + Umbra + Voltaic 14 | top 6: Pyro + Terra + Toxin 92, Cryo + Pyro + Terra 89, Pyro + Terra + Voltaic 86, Pyro + Radiant + Terra 86, Pyro + Terra + Zephyr 83, Terra + Toxin + Voltaic 83
**Deep Freeze, range 30** — bottom 6: Radiant + Voltaic + Zephyr 24, Aqua + Cryo + Voltaic 23, Cryo + Toxin + Voltaic 20, Cryo + Umbra + Voltaic 19, Radiant + Umbra + Zephyr 18, Radiant + Umbra + Voltaic 14 | top 6: Pyro + Terra + Toxin 93, Cryo + Pyro + Terra 89, Pyro + Terra + Voltaic 86, Pyro + Radiant + Terra 86, Pyro + Terra + Zephyr 83, Terra + Toxin + Voltaic 82
**All three Cryo (FF 20, BZ 32, DF 20)** — bottom 6: Cryo + Voltaic + Zephyr 22, Cryo + Toxin + Voltaic 21, Aqua + Voltaic + Zephyr 20, Cryo + Umbra + Voltaic 17, Radiant + Umbra + Zephyr 17, Radiant + Umbra + Voltaic 14 | top 6: Pyro + Terra + Toxin 93, Cryo + Pyro + Terra 90, Pyro + Radiant + Terra 85, Pyro + Terra + Voltaic 84, Cryo + Radiant + Terra 82, Cryo + Terra + Umbra 81
**Aftershock at the cursor, range 15** — bottom 6: Radiant + Voltaic + Zephyr 23, Aqua + Cryo + Voltaic 20, Cryo + Toxin + Voltaic 20, Cryo + Umbra + Voltaic 20, Radiant + Umbra + Zephyr 17, Radiant + Umbra + Voltaic 14 | top 6: Pyro + Terra + Toxin 93, Cryo + Pyro + Terra 88, Pyro + Terra + Voltaic 85, Pyro + Radiant + Terra 84, Pyro + Terra + Zephyr 84, Terra + Toxin + Voltaic 83
**Aftershock, range 24** — bottom 6: Cryo + Voltaic + Zephyr 22, Cryo + Toxin + Voltaic 21, Aqua + Cryo + Voltaic 20, Cryo + Umbra + Voltaic 20, Radiant + Umbra + Zephyr 17, Radiant + Umbra + Voltaic 14 | top 6: Pyro + Terra + Toxin 92, Cryo + Pyro + Terra 88, Pyro + Terra + Voltaic 86, Pyro + Radiant + Terra 86, Pyro + Terra + Zephyr 83, Terra + Toxin + Voltaic 82
**Aftershock, range 35** — bottom 6: Radiant + Voltaic + Zephyr 23, Aqua + Cryo + Voltaic 21, Cryo + Toxin + Voltaic 20, Cryo + Umbra + Voltaic 20, Radiant + Umbra + Zephyr 18, Radiant + Umbra + Voltaic 14 | top 6: Pyro + Terra + Toxin 93, Cryo + Pyro + Terra 86, Terra + Toxin + Voltaic 85, Pyro + Terra + Voltaic 85, Pyro + Terra + Zephyr 84, Pyro + Radiant + Terra 83
**Benediction at the cursor, range 20** — bottom 6: Radiant + Voltaic + Zephyr 24, Aqua + Cryo + Voltaic 22, Cryo + Toxin + Voltaic 21, Cryo + Umbra + Voltaic 19, Radiant + Umbra + Zephyr 17, Radiant + Umbra + Voltaic 14 | top 6: Pyro + Terra + Toxin 93, Cryo + Pyro + Terra 88, Pyro + Terra + Voltaic 86, Pyro + Radiant + Terra 85, Terra + Toxin + Voltaic 83, Pyro + Terra + Zephyr 83
**Benediction, range 35** — bottom 6: Toxin + Umbra + Voltaic 24, Aqua + Cryo + Voltaic 22, Cryo + Toxin + Voltaic 21, Cryo + Umbra + Voltaic 19, Radiant + Umbra + Zephyr 17, Radiant + Umbra + Voltaic 14 | top 6: Pyro + Terra + Toxin 93, Cryo + Pyro + Terra 88, Pyro + Terra + Voltaic 86, Pyro + Radiant + Terra 85, Pyro + Terra + Zephyr 84, Terra + Toxin + Voltaic 83
**Benediction, range 50** — bottom 6: Aqua + Radiant + Zephyr 24, Aqua + Cryo + Voltaic 22, Cryo + Toxin + Voltaic 21, Cryo + Umbra + Voltaic 19, Radiant + Umbra + Zephyr 16, Radiant + Umbra + Voltaic 14 | top 6: Pyro + Terra + Toxin 93, Cryo + Pyro + Terra 88, Pyro + Terra + Voltaic 86, Pyro + Radiant + Terra 85, Pyro + Terra + Zephyr 84, Terra + Toxin + Voltaic 83
**robustness baseline** — bottom 6: Toxin + Umbra + Voltaic 24, Aqua + Cryo + Voltaic 22, Cryo + Toxin + Voltaic 21, Cryo + Umbra + Voltaic 19, Radiant + Umbra + Zephyr 18, Radiant + Umbra + Voltaic 14 | top 6: Pyro + Terra + Toxin 93, Cryo + Pyro + Terra 88, Pyro + Radiant + Terra 86, Pyro + Terra + Voltaic 86, Pyro + Terra + Zephyr 84, Terra + Toxin + Voltaic 83
**robustness: Flash Freeze, range 20** — bottom 6: Toxin + Umbra + Voltaic 23, Aqua + Voltaic + Zephyr 23, Cryo + Toxin + Voltaic 22, Cryo + Umbra + Voltaic 19, Radiant + Umbra + Zephyr 17, Radiant + Umbra + Voltaic 14 | top 6: Pyro + Terra + Toxin 92, Cryo + Pyro + Terra 88, Pyro + Terra + Voltaic 85, Pyro + Radiant + Terra 85, Pyro + Terra + Zephyr 83, Cryo + Radiant + Terra 78
**robustness: Flash Freeze, range 25** — bottom 6: Aqua + Radiant + Zephyr 23, Aqua + Voltaic + Zephyr 23, Cryo + Toxin + Voltaic 21, Cryo + Umbra + Voltaic 20, Radiant + Umbra + Zephyr 17, Radiant + Umbra + Voltaic 14 | top 6: Pyro + Terra + Toxin 92, Cryo + Pyro + Terra 88, Pyro + Terra + Voltaic 85, Pyro + Radiant + Terra 84, Pyro + Terra + Zephyr 83, Cryo + Terra + Umbra 80
**robustness: Blizzard, range 32** — bottom 6: Cryo + Voltaic + Zephyr 21, Aqua + Voltaic + Zephyr 20, Cryo + Toxin + Voltaic 20, Radiant + Umbra + Zephyr 17, Cryo + Umbra + Voltaic 16, Radiant + Umbra + Voltaic 14 | top 6: Pyro + Terra + Toxin 94, Cryo + Pyro + Terra 90, Pyro + Terra + Voltaic 86, Pyro + Radiant + Terra 86, Terra + Toxin + Voltaic 84, Pyro + Terra + Zephyr 82

## Technique swap: one Element's Defense Technique replaced, against the 83 other comps (paired seeds)

Each cell: that Element's comps without the swap -> with it (change). The control has the same settings as the swap run.

| Element (its Defense slot) | Twin Tide, live walls, (b) 100 + 100 | Twin Tide, standing walls, (a) 200 + 3 s | Bulwark Wall (v3: 400 HP) |
|---|---|---|---|
| Aqua (SA) | — (its own) | — (its own) | 43.8 -> 63.4 (+19.6) |
| Cryo (DF) | 48.9 -> 53.9 (+5.0) | 48.2 -> 59.1 (+10.9) | 48.6 -> 75.2 (+26.5) |
| Pyro (LS) | 60.7 -> 58.9 (-1.8) | 60.9 -> 60.8 (-0.1) | 60.8 -> 72.3 (+11.5) |
| Radiant (BN) | 47.4 -> 45.9 (-1.5) | 47.2 -> 47.9 (+0.7) | 47.9 -> 67.0 (+19.0) |
| Terra (BW) | 70.4 -> 53.4 (-17.0) | 69.1 -> 54.6 (-14.5) | — (its own) |
| Toxin (AR) | 48.5 -> 47.9 (-0.6) | 48.0 -> 50.8 (+2.8) | 48.4 -> 66.8 (+18.4) |
| Umbra (DD) | 42.3 -> 43.3 (+1.0) | 42.0 -> 46.5 (+4.5) | 42.3 -> 44.3 (+2.1) |
| Voltaic (VO) | 43.9 -> 42.9 (-0.9) | 42.9 -> 45.3 (+2.4) | 44.2 -> 61.0 (+16.7) |
| Zephyr (GP) | 43.3 -> 47.3 (+4.0) | 42.0 -> 49.5 (+7.6) | 43.2 -> 61.8 (+18.7) |

## Caveats

- **These are bot fights on an open floor,** with rules for aim, dodging and teamwork, not measurements from players.
- **Where the bots cast each new version is my rule** (see "How it was modelled"). A better or worse player gets more
  or less out of it. In particular, the bots always pick cover over a crush when a teammate is under fire.
- **Neither wall stops movement in the sim:** Bulwark Wall doesn't, and neither does Twin Tide. Live Twin Tide walls are
  solid to bodies, which matters more for the standing versions: two 24-stud walls that block movement for 4 to 7 s
  could help or hurt either team.
- **6 rounds per pairing.** See the noise line above the tables: single-comp moves of one or two places in the bottom
  6 and top 6 can be noise.
