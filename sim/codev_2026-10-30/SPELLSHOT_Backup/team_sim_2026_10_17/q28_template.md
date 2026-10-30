# SPELLSHOT P28 + P29: a second protector (Twin Tide) and cursor-targeting, tested in the 3v3 sim

18 October 2026. The owner's P28 and P29 specs, run in one round on top of team package v3. Each spec got its own toggles
on the same base. The draft was fact-checked by independent checkers against the raw results, the sim's code and the
live game in Studio. That check found the live Twin Tide walls stand for less time than first modelled, and found two
missing controls. Everything affected was re-run.

{{ANSWER}}

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

{{TABLES}}

## Caveats

- **These are bot fights on an open floor,** with rules for aim, dodging and teamwork, not measurements from players.
- **Where the bots cast each new version is my rule** (see "How it was modelled"). A better or worse player gets more
  or less out of it. In particular, the bots always pick cover over a crush when a teammate is under fire.
- **Neither wall stops movement in the sim:** Bulwark Wall doesn't, and neither does Twin Tide. Live Twin Tide walls are
  solid to bodies, which matters more for the standing versions: two 24-stud walls that block movement for 4 to 7 s
  could help or hurt either team.
- **6 rounds per pairing.** See the noise line above the tables: single-comp moves of one or two places in the bottom
  6 and top 6 can be noise.
