# SPELLSHOT: proposed new direction

**Team fights, slower movement, role-based balance.** Written 17 October 2026 for discussion and planning.

The reader may have no history with this project, so section 1 explains what SPELLSHOT is and where it stands. Section 2
explains what went wrong, section 3 states the new idea, section 4 gives what the numbers say about it, and section 9
lists the questions to work through.

---

## 1. The game today

SPELLSHOT is a first-person spell shooter on Roblox. Players pick one of nine **Elements**. Each Element is a kit of
six abilities:
- an **M1**, the basic attack;
- a **Primary**;
- a **Passive**;
- two **Techniques**;
- an **Ultimate**, which charges from damage dealt and taken.

### Core rules now

| Rule | Value |
|---|---|
| Health | 150. No health regeneration: only abilities heal. |
| Mana | 100, regenerating 7 per second. |
| Main mode | 1v1 Duel, first to 5 rounds. Each round has a 90 s clock, after which the larger share of health left wins. |
| Movement | Fast and RIVALS-inspired: auto-sprint 25 studs/s, slide, slide-jump chain, double jump, wall-run, wall jump. Chaining slides and jumps reaches about 45 studs/s. |
| Hitboxes | 2× (every body part's hit area doubled, invisible) |
| M1 projectile speed | 200 studs/s for every M1 that is a projectile. Two M1s are instant (hitscan). |
| Dashes | Blocked while slowed below 16 studs/s |

### The nine Elements and the roles the owner already sees in them

| Element | Role (owner's view) | M1 | Tools that matter in team play |
|---|---|---|---|
| **Pyro** | Damage | Fireball (18 direct, 9 splash) | Burn damage over time (Immolate, Scorching Lash), Detonate execute, Ring of Fire Ultimate (area) |
| **Voltaic** | Damage | Chain Bolt (instant, range 30, chains to a 2nd enemy) | Overcharge dash, Railspike (piercing line), Volt Orb (area), Cascade Ultimate |
| **Cryo** | Control / zone | Icicle Shard (slows that stack) | Flash Freeze (area root), Blizzard (slowing zone), Deep Freeze trap, Mirror Cage Ultimate (traps up to 6) |
| **Aqua** | Control / zone | Riptide (ground wave) | Undertow (pulls an enemy in), Twin Tide (walls that crush), Leviathan's Maw Ultimate (traps up to 6) |
| **Toxin** | Control / zone | Toxic Bubbles (poison) | Corrosive Cloud and Acid Rain (poison zones), Patient Zero Ultimate (spreading poison burst) |
| **Terra** | Defence | Boulder Shot (charged, up to 48) | Bulwark Wall (blocks shots, 200 HP), Bulwark Charge (dash with damage reduction), Aftershock knockback |
| **Radiant** | Support | Light Lance (beam, up to 32/s) | Blessing (35 shield on an ally), Benediction (area heal, 15 HP/s, up to 8 s, roots the caster), Halo Ultimate (team lifesteal), Position Trade (swap places) |
| **Umbra** | Not yet assigned (assassin?) | Shadow Dart (charged, 65) | Shadow Step blink, Mark (bonus damage, headshots), Decoy Double, Eclipse Ultimate |
| **Zephyr** | Not yet assigned (mobility / disrupt?) | Wind Blade (fast, small hits) | Cross-Slash dash, Skyrider (fly on a bird, 60–75 studs/s), Gust Pad (launch pad), Cyclone Ultimate (pull) |

---

## 2. Why this came up

A long balance effort on the 1v1 Duel kept running into the same wall:

- **Players chase non-stop.** In a simulation of every 1v1 matchup, each side picked its best approach (chase or keep
  distance). Chasing was the best play 57% of the time, and in 23 of 81 matchups both sides did best by chasing.
- **The gap between Elements will not close.** After a 15-change balance pass, 2× hitboxes and a shared projectile speed,
  win rates with best play still run from **9% (Aqua) to 87% (Pyro)**. Tuning toward 50/50 moves the problem to
  another Element instead of solving it.
- **Many kit pieces only work with teammates.** In a 1v1 they do nothing:
  - Chain Bolt and Charged chaining to a second enemy, and Overcharge's prime;
  - Radiant's ally shields and heals;
  - Terra's wall protecting others, and Gust Pad launching allies;
  - Ultimates that trap up to six enemies.
- **Roles clash with 1v1.** In a duel a support or a defender has to out-damage a damage dealer to win, which erases
  the role it was designed for.

The conclusion: the kits were designed for team play, and the 1v1 format is fighting them.

---

## 3. The new idea

1. **Team fights become the main mode.** The team size is still open (see section 9).
2. **Slower movement.** The pace sits between today's and Marvel Rivals'.
   - Remove sliding, slide-jumping and wall-running, and keep running.
   - Whether jumping and double-jumping stay is still open.
3. **Role-based balance instead of equal damage.**
   - Pyro and Voltaic deal the most damage.
   - Radiant does not need to deal damage like them; its job is keeping teammates alive.
   - Cryo, Aqua and Toxin control space.
   - Terra protects.
   - Every Element should be best at its own job, not equal at everything.

---

## 4. What the current numbers say under this idea

The simulation was re-run with running-only movement (25 studs/s, normal jumps only), today's 2× hitboxes and the shared
projectile speed. Distances are typical of team fights. Each Element fired at a target that strafes and uses its own
defences.

| Element | Damage/s at 20 studs | Damage/s at 45 studs | Damage/s it takes at 45 studs |
|---|---|---|---|
| Pyro | 41 | 30 | 17.5 |
| Voltaic | 33 | 4 | 17.3 |
| Terra | 32 | 14 | **11.8** (sturdiest) |
| Radiant | 25 | **24** | 13.9 |
| Umbra | 23 | 17 | 15.3 |
| Toxin | 20 | 16 | 17.4 |
| Zephyr | 18 | 11 | 17.6 |
| Cryo | 18 | 15 | 17.3 |
| Aqua | 12 | 16 | 17.4 |

**Focus fire:** a player targeted by two enemies dies in about 4.3 s at 45 studs and 3 s at 20. Targeted by three, it
dies in about 2–3 s.

### Role fit today

- **Pyro (damage):** fits. It is the top damage dealer at both distances.
- **Voltaic (damage):** fits up close (33/s), but deals almost nothing at mid range (4/s) because Chain Bolt reaches only
  30 studs. Without slides it will struggle to get close, so it needs more reach or a stronger way in.
- **Radiant (support):** does not fit.
  - It deals the second-most damage at mid range.
  - It heals little next to how fast people die: Benediction gives 15 HP/s for at most 8 s and roots Radiant while it
    channels, and Blessing gives a 35 shield every 12 s.
  - That averages roughly 5–8 HP/s per ally, against about 35 damage/s landing on a focused teammate.
- **Terra (defence):** half fits. It is the hardest to kill, but it also deals the third-most close-range damage.
- **Cryo, Aqua, Toxin (control):** low damage is right for the role. Their slows, though, were tuned against the old
  ~45–59 studs/s chase. Against a 25 studs/s run, Cryo's first slow stack (a cap of 22) is only a 12% slow.
- **Umbra and Zephyr:** they need roles before they can be judged.

### Problems for the whole game

1. **Fights are too short for support play.** With 150 HP, no regeneration and 2× hitboxes, a focused player dies in
   2–4 s, too fast for healing to matter.
   - Likely fixes: more health in team modes (around 250), per-role health, smaller hitboxes, or a mix of these.
2. **Mobility becomes the strongest stat.** When everyone only runs at 25:
   - Zephyr's Skyrider (60–75 studs/s) moves 2.4–3× faster than anyone. It was raised recently to keep up with the slide
     chain, which would no longer exist.
   - Blinks and dashes (Umbra, Voltaic, Terra, Zephyr) gain a lot of value.
   - Cryo, Pyro, Toxin and Aqua have no escape. In a team that is acceptable if teammates protect them.
3. **Recent tuning assumed the fast movement.** If sliding goes, these need another look:
   - the slower slide-jump;
   - the Skyrider buff;
   - the slow level that blocks dashes;
   - the duel spawn positions.

### What gets better

The team-only pieces listed in section 2 start doing their jobs: chain lightning, ally heals and shields, walls,
launch pads and multi-target Ultimates.

### Limit of this analysis

It is still a 1v1 model measuring each Element's damage. It does not simulate focus fire coordination, heals on allies
or area hits on groups, so a team-fight simulation is needed before any real tuning.

---

## 5. Draft role targets

These are starting points to argue about. None of the numbers has been tested.

| Role | Best at | Damage | Healing / protection | Control | Mobility / escape |
|---|---|---|---|---|---|
| Damage (Pyro, Voltaic) | Killing | Highest, ~30–40/s at its best range | None | Little | Some (Voltaic dash) |
| Support (Radiant) | Keeping allies alive | Lowest, ~10–15/s | Highest: ~25–40 HP/s on one ally, or ~15 HP/s to a group | Little | Repositioning (Position Trade) |
| Defence (Terra) | Absorbing damage, protecting allies | Moderate, ~15–20/s | Shields and walls for others; most damage absorbed | Knockbacks | Short charge |
| Control (Cryo, Aqua, Toxin) | Area denial, slows, roots | Low to moderate, ~12–20/s | Little | Most slow and root time; zones | Little |
| Umbra (role open) | Picking off isolated targets? | Burst | None | None | Blink |
| Zephyr (role open) | Mobility and disruption? | Low | Team mobility (Gust Pad) | Knockbacks, pull | Highest |

---

## 6. What would need to change or be built

1. **A movement switch.** One setting turns sliding, slide-jumping and wall-running off.
   - The code stays, so both paces can be tested, and the fast movement could live on in a Duel side mode.
2. **A team mode.** It needs:
   - matchmaking and queues for the chosen team size;
   - team spawns on each map;
   - a team HUD and scoreboard;
   - round or respawn rules;
   - friendly-fire rules;
   - possibly an objective, such as a control point, which would also give the control Elements a job.
3. **A team-mode tuning layer.** Health, healing strength, slow strengths, mobility speeds and role damage budgets for
   team play, separate from the Duel numbers.
4. **A team-fight simulation (3v3 or the chosen size).** It should cover focus fire, heals on allies, area damage on
   groups and role compositions, so role budgets can be set with evidence.
5. **A map check.** Current maps were built for duels, 200–480 studs across. They need checking for team play: lanes,
   cover, spawns for several players per side.

---

## 7. Risks and costs

- **Players per match.** 2v2 needs 4 players and 3v3 needs 6. With a small player base, queue times could hurt.
  Possible answers: bots, starting with 2v2, or keeping a quick 1v1 mode.
- **Losing the movement identity.** A lot of work went into RIVALS-style slides and wall-runs, and they are part of
  what makes the game feel distinct. The switch keeps that option open.
- **Coordination on Roblox.** Many players queue solo, so roles must be readable at a glance, and the game should still
  work without voice chat.
- **Scope.** A new mode plus a full retune is a large piece of work and should be planned in stages.

---

## 8. Suggested order of work

1. Add the movement switch and play running-only in Studio, to check the feel before committing.
2. Decide the team size and mode format.
3. Build the team-fight simulation and agree role targets (section 5).
4. Retune for team play: health, healing, slows, mobility and role damage.
5. Build the team mode itself: queues, spawns, HUD, rules.
6. Playtest with real players, then iterate.

---

## 9. Questions to work through

1. **Team size:** 2v2, 3v3 or 5v5? Smaller is easier to fill; larger gives roles more room.
2. **The 1v1 Duel:** keep it as a side mode with its own tuning and the fast movement, or drop it?
3. **Movement detail:** keep jump and double jump? Give everyone a short dodge to replace the slide?
4. **Match format:**
   - rounds with no healing between fights (like today's Duel);
   - respawns (team deathmatch);
   - an objective, such as a control point.
5. **Team building:** lock roles (for example at most one support per team), or allow any mix?
6. **Umbra and Zephyr:** what are their roles?
7. **Health:** uniform health for team modes, or health by role (for example defence 300, support 200, others 250)?
8. **Hitbox size:** do 2× hitboxes make focus fire too fast in team play?
9. **Radiant's damage budget:** how much damage should a support deal, versus how much it heals?
