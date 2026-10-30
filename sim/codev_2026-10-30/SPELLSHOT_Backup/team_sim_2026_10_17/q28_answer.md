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
- **Technique swap (P25's lever):** {{SWAP}}

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
6. **{{SWAP_SUGGESTION}}**
7. **The bigger lever is still Terra's own protection.** In v3, Bulwark Wall absorbs about 306 HP per Terra per round,
   six to seven times the standing Twin Tide. A natural next test pulls v3's wall (400 HP, held up to 6 s, 0.5 s between
   holds) back toward the sim's default (200 HP, 2.5 s holds, 2 s apart), together with a standing Twin Tide, so the
   protection is shared rather than added.
