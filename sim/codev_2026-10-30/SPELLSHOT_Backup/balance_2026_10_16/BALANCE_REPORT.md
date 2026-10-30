# SPELLSHOT balance sheet — 2026-10-16/17

Source: the live place (PlaceVersion of 2026-10-16), read in Edit, nothing changed. Every kit value was printed from the
running modules (`VFXLibrary.AbilityById`, `CryoTuning`, `AquaTuning`, `VoltaicTuning`, `ToxinTuning`, `RadiantTuning`,
`UmbraTuning`, `PyroFX.Tuning`, `TerraFX.Tuning`, `ZephyrFX.Tuning`, `ZephyrSkyrider/GustPad/Updraft.Tuning`,
`SpellshotConfig.Movement`) except where the Flag column says **src** (read from source text: `StatusEffects` preset A,
`AbilityHandler.Tune`, `TerraHandler`). **doc** = only in IMPLEMENTED.md. **PROP** = marked proposal / ASSUMED /
provisional / awaiting sign-off. Loadouts are each Element's live `ElementDefaults`. Status numbers are preset A (live default).

Shared: HP 150, mana 100, regen 7/s, gravity 64, Ultimate charge 1/260 per point of damage dealt or taken (+0.06 a cast).

## 1. Ability stats (54 castable rows; retired Frost Slide / Chill Aura / Cryo Beam excluded)

| Element | Ability | Slot | Mana | Cooldown | Cast / charge | Speed | Space | Damage | DoT / CC / utility | Flag |
|---|---|---|---|---|---|---|---|---|---|---|
| Aqua | Riptide | M1 | 4 | 0.667 interval | — | 70 ground wave | range 70, 7 wide, 3.5 high, pierce 4 | 12 | jumpable | |
| Aqua | Undertow | Primary | 25 | 9 | snap 0.6 | pull ≤125 for 0.28 s | cone 35°, reach 36 | 0 | pulls enemy to 4.2 studs, 0.5 s no-cast | row Range 30 vs Tuning Reach 36 |
| Aqua | Riding the Current | Passive | — | — | — | — | own wet ground 3 s | — | +25% own speed; enemy slips 0.8 s | |
| Aqua | Twin Tide | Technique (Aqua only) | 40 | 16 | walls meet 1.1 s | — | lane 24, seam ±3.5, range 40 | 35 + lift 30 | walls block bodies | row says Defense, defaults to T1 |
| Aqua | Sidearm | Technique (Aqua only, held) | 6 a bullet | 0.9 | first shot 0.14 s | 160 | range 110 | 8 a bullet, 1.6/s | knock 38 + 0.55 s airborne | 9.6 mana/s > regen |
| Aqua | Leviathan's Maw | Ultimate | charge | — | closes 1.2 s, bite 4.05 s | — | r22, range 45, ≤6 sharks | 65 bite, 25 surge | trapped to 4.6 s | |
| Cryo | Icicle Shard | M1 | 2 | 0.333 interval | — | 170 | range 120 | 8 | Chill: caps 22 / 15, 3rd stack roots 0.8 s then 1.2 s immune, 5 s window | src; `AbilityHandler.Tune.ShardChillWindow` 3.0 is stale (preset 5.0); preset has a 3rd cap 10 the doc omits |
| Cryo | Flash Freeze | Primary | 30 | 14 | lead-in 0.38 + 1.0 expand | — | r20 around caster | 10 contact + 34 shatter | slow to 5 for 1.2 s; 1 s inside → root to zone end (FrozenDuration 4) | src |
| Cryo | Cold Momentum | Passive | — | — | — | — | — | — | +10% speed 2 s after any hit | doc (config row, not printed) |
| Cryo | Blizzard | Technique | 28 | 18 | form 0.6 | — | r32, h24, 8 s | 0 | speed cap 14, re-applied every 0.3 s | PROP |
| Cryo | Deep Freeze | Technique | 22 | 16 | arms 0.5 | — | trap reach 4, lasts 20 s | 10 | root 2.5 s, 1.5 s immunity after | PROP |
| Cryo | Mirror Cage | Ultimate | on catch | — | form 0.7 + emerge 0.5, volley 1.6 | — | lock 4.5 off aim, range 60 (+2), trap r≈19–20, ≤6 | 12 × 6 = 72 | root 3.13 s | PROP |
| Pyro | Fireball | M1 | 3 | 0.6 interval | release 0.42 | 65 | row Range 110; flight 2.5 s = 162 | 18 direct, 9 splash (r6) | carries Immolate's burn | range mismatch 110 vs 162 |
| Pyro | Immolate | Primary | 25 | 12 | 0.22 | — | next 3 hurting throws | burn 10 × 1.2 each | — | src preset; `PyroFX.Tuning` 3 × 4 superseded |
| Pyro | Ember Refund | Passive | — | — | — | — | — | — | a kill cuts 30% of Immolate's cooldown | dead in a duel (round ends on the kill) |
| Pyro | Detonate | Technique (Pyro only) | 20 | 14 | 0.27 + 1.5 fuse | — | last-hit target ≤4 s, ≤120, no line of sight | 12 + 36 × (missing / 75%) | — | PROP (not owner-played) |
| Pyro | Scorching Lash | Technique (held) | 12 | 2.5 from release | crack 0.22 | — | sweep −110°→40°, reach 35, ≤5 | 12 | +1 burn stack: 1.6 per 0.5 s × 10, ≤3 | src preset; PROP |
| Pyro | Ring of Fire | Ultimate | charge | — | 0.93 (steered to 0.83) | — | r17.5 (hot 21), range 60 | 55 (75 hot) | burn 10 × 1.5 | |
| Radiant | Light Lance | M1 (held) | 2 + 7.5/s | tick 0.25 | — | beam | range 60 | 16 → 32 dps over 2 s | — | |
| Radiant | Blessing | Primary | 25 | 12 | instant | — | range 45, lock 3.5 | — | shield 35 for 8 s (self if no ally) | |
| Radiant | Overflow Light | Passive | — | — | — | — | — | — | unspent shield heals 0.6 × leftover | |
| Radiant | Position Trade | Technique | 18 | 14 | 0.12 | — | range 45 | — | swap places | no distance effect 1v1 |
| Radiant | Benediction | Technique (held) | 20 + 10/s | 17 from end | wind-up 0.5 | — | r25 | — | heal 7.5 per 0.5 s for up to 30 s; caster rooted | |
| Radiant | Halo | Ultimate | charge | — | 0.9 | — | team r40, 6 s | — | damage to players heals, cap 60; float 0.5 g | PROP |
| Terra | Boulder Shot | M1 (charged) | 4 | 0.85 + 1.1 charge | 1.1 | 108 uncharged → 86 full | range 120, arc g 26 | 24 → 48 | — | full charge flies SLOWER (Min 108 > Max 86) |
| Terra | Bulwark Charge | Primary | 30 | 9 | 0.62 travel | 42 | 26 | 35 | knock 30 + lift 14, stagger 1.2, 40% DR during | doc lacked these |
| Terra | Bedrock | Passive | — | — | — | — | — | — | 4% DR a stack every 0.22 s, ≤5 (20%) while charging | |
| Terra | Aftershock | Technique | 20 | 12 | hit 0.68 + ring 0.7 | — | r24, ±3 vertical | 20 | knock 36 out / 22 up, 0.5 s no-cast; caster held ~1 s | mana PROP |
| Terra | Bulwark Wall | Technique (held) | 10 + 20/s | 0 | — | — | 5.5 ahead | — | blocks shots and sight, 200 HP | |
| Terra | Earthen Tomb | Ultimate | on catch | — | fissure 60 studs/s for ≤1.6 s | — | lock range 40 | 50 × 1.5 = 75 | — | src (TerraHandler); look PROP |
| Toxin | Toxic Bubbles | M1 | 3 | 0.55 interval | — | 60 lob (g 14) | range 120 | 9 | Poisoned 4/s for 5 s (1 stack); a miss rests 4.5 s (≤6) | PROP |
| Toxin | Corrosive Cloud | Primary | 25 | 9 | form 0.6 | — | r9 on the newest bubble, 6 s | 3 per 0.5 s | refreshes poison; self ×0.4 | PROP |
| Toxin | Symbiosis | Passive | — | — | — | — | — | — | heals 30% of DoT dealt; own poison hurts you ×0.4 | PROP |
| Toxin | Antitoxin Vent | Technique | 20 | 16 | 0.35 | — | self, 6 s | — | cleanses own poison only | does nothing vs a non-Toxin |
| Toxin | Acid Rain | Technique | 30 | 14 | gather 0.7 | — | r10, range 50, 4 s | 4 per 1 s | Corroded +12% poison a stack, ≤4, 6 s | PROP |
| Toxin | Patient Zero | Ultimate | on catch | — | 3.5 s telegraph | — | lock 7 off aim, range 60, burst r20 | 18 + cloud 4 per 0.5 s for 5 s | ally scaling n/a in 1v1 | name PROP |
| Umbra | Shadow Dart | M1 | 5 | 2.6 cycle | 2.3 charge | 240 | range 160 | 65 | — | PROP (stand-ins) |
| Umbra | Shadow Step | Primary | 20 | 10 | 0.12 dissolve | blink | 4–22 (aim reach 60) | — | veiled 0.6 s | row Range 60 = aim reach |
| Umbra | Unseen | Passive | — | — | — | — | target >60° off facing | +25% | — | |
| Umbra | Mark | Technique | 18 | 14 | — | — | range 120, lock 7 | +10/20/30 body, +50/100/150 head | 1 stack a second to 3; expires 5 s after full | |
| Umbra | Decoy Double | Technique | 18 | 20 | — | — | 3.8 aside, 8 s | — | breaks on first damage | |
| Umbra | Eclipse | Ultimate | charge | — | 1.0 windup (held) | — | reveal 250 | — | 7 s: dart cycle ×1.5, all enemies unaware | name PROP |
| Voltaic | Chain Bolt | M1 | 2 | 0.32 interval | — | hitscan | range 30 | 8 | chain 5 to a 2nd enemy (r16); Charged stacks, alone 0 | 2026-10-13 range edit unlogged |
| Voltaic | Overcharge | Primary | 18 | 9 | 0.16 | 69 | 11 | — | primes next M1 (3 legs) 6 s | prime needs a 2nd enemy |
| Voltaic | Chain Reaction | Passive | — | — | — | — | — | — | a kill cuts 30% of Overcharge's cooldown | dead in a duel |
| Voltaic | Railspike | Technique | 20 | 10 | 0.55 windup | hitscan | range 90, pierce 6 | 30 | — | |
| Voltaic | Volt Orb | Technique | 20 | 12 | release 0.12, fuse 1.25 | 48 (g 72) | range 60, r7.5 | 28 → 14, +8 direct | — | |
| Voltaic | Cascade | Ultimate | charge | — | 0.5 + strikes 1.23–1.53 | — | r11, range 60 | 5 × 14 = 70 | — | "never run in Play" flag in CascadeFX |
| Zephyr | Wind Blade | M1 | 0.8 | 0.12 interval | — | 240 | range 80, pierce 3 | 3 | — | |
| Zephyr | Cross-Slash Dash | Primary (held) | 25 | 10 from release | charge 0.3–1.0 + 0.5 dash | 15–27 effective | 12–40 | 30 a body (≤4) | through bodies | PROP: Min/MaxDistance ASSUMED; stray `DashDistance = 55` |
| Zephyr | Updraft | Passive | — | — | — | — | — | ×1.25 airborne | knockback ×1.5 | PROP |
| Zephyr | Skyrider | Technique (held) | 15 + 12/s, flap 10 | 12 from end | summon 0.44 | 42 (55 boost) | ride ≤10 s; gust cone 28°, 22 | gust 12 | knock 55 out / 20 up | PROP; slower than the shared chain |
| Zephyr | Gust Pad | Technique | 20 | 14 | arm 0.26 | — | range 40, r3.4, 10 s / 8 launches | — | launch 19 up | PROP |
| Zephyr | Cyclone | Ultimate | charge | — | form 1.2 (steered) | pull 22 | r26, range 70 | 6 per 0.5 s × 4 s = 48 | juggle | |
| (pool) | Heat Rush | Technique (held) | 12 | 8 from release | — | — | ≤4 s | — | ×1.4 speed; ≥60% Heat: ranged hits −40% | on no default loadout |
| (pool) | Cinder Shield | Technique | 22 | 15 | 0.17 | — | 5 s | haze 20 | soaks 60 | on no default loadout |

## 2. Movement stats (shared; `SpellshotConfig.Movement`, live)

| Mechanic | Live values | Terrain | Flag |
|---|---|---|---|
| Run | auto-sprint 25 (walk 16 only when standing), crouch 8 | anywhere | |
| Slide | 35 → 28 (curve t^2.5), up to 1.6 s while held, min speed 12, 0.1 s regap, no cooldown | floor | |
| Slide-jump | +32 earned over 0.25 s of slide, clamped 56–70, apex 4.0 from standing, speed held to landing, 0.35 s bleed. Measured 66.8 studs/s, 0.76 s, 50 studs | floor | `SlideJumpHeight` only works since 2026-10-05 |
| Plain jump | apex 7.2, 0.93 s in the air; air speed held unless steering against travel | anywhere | |
| Double jump | 1 air jump, 4.5 studs, re-aims carried speed; back on landing or a wall catch. Slide + double measured 1.46 s, 97 studs | anywhere | |
| **Sustained chain** | **~59 studs/s** (slide → slide-jump → double jump, repeated) | open floor | measured |
| Wall-run catch | airborne, ≥16 studs/s, wall at waist AND head within 2.6, ≥1.2 air; one catch per wall face per airtime, never higher than the last (2026-10-16 fix) | true wall | |
| Wall-run ride | ≥30 (or entry speed, cap 70), ≤1.4 s, 0.3 gravity, lift 4, fall ≤10, bank 10° | true wall | |
| Wall jump | 8.6 up, push 22 + along-wall speed (measured ~37 studs/s) | true wall | |
| Dash threshold | DashMotor `MinCap` 12 (Overcharge, Bulwark Charge, Cross-Slash) | — | |
| Cross-Slash (Zephyr) | 12–40 studs, charge 0.3–1.0 s + 0.5 s → 15–27 studs/s | anywhere | PROP (ASSUMED) |
| Bulwark Charge (Terra) | 26 in 0.62 s → 42 studs/s | anywhere | |
| Overcharge (Voltaic) | 11 in 0.16 s → 69 studs/s burst | anywhere | |
| Shadow Step (Umbra) | 4–22 blink in 0.12 s → ~183 studs/s | needs floor at the end | |
| Skyrider (Zephyr) | 42 cruise / 55 boost / 24 brake, ≤10 s, 12 mana/s | anywhere | slower than the chain |
| Gust Pad (Zephyr) | launch 19 up, keeps a third of flat speed (≤8) | floor | |
| Undertow (Aqua) | pulls the TARGET up to 36 studs in ~0.9 s | — | |
| Position Trade (Radiant) | swap within 45 | floor at both ends | no net closing |
| Halo float (Radiant) | 0.5 gravity, fall cap 12 | — | |
| Riding the Current (Aqua) | +25% on own wet ground | wet ground | |

## 3. Slows and roots against the movement thresholds (pass d, part 1)

| Effect | Cap / effect | Stops dashes (<12)? | Stops wall-run catch (<16)? | Stops the chain? | Source |
|---|---|---|---|---|---|
| Chill, 1 stack | cap 22 for 5 s | no | no | yes: chain 59 → 22 | Icicle |
| Chill, 2 stacks | cap 15 | no | **yes** | yes → 15 | Icicle |
| Chill, 3rd stack | root 0.8 s | yes | yes | yes | Icicle |
| Blizzard | cap 14 in r32 for 8 s | **no** | yes | yes → 14 | Cryo T (pool) |
| Flash Freeze contact | cap 5 for 1.2 s, then root | yes | yes | yes | Cryo F (r20 around caster) |
| Deep Freeze | root 2.5 s | yes | yes | yes | trap, 4 studs |
| Mirror Cage | root 3.13 s | yes | yes | yes | Ultimate |
| Leviathan's Maw | trapped 4.6 s | yes | yes | yes | Ultimate |
| Aftershock | knock 36 + 0.5 s no-cast | no (movement free) | no | no | Terra T |
| Undertow | 0.5 s no-cast | no | no | pulls you IN | Aqua F |
| Sidearm | knock 38 for 0.25 s (~9.5 studs a hit) | no | no | no | Aqua T |
| Bulwark Charge | stagger 1.2 s | — | — | — | Terra F |
| Slip (Riding the Current) | low traction 0.8 s | no | no | partly | Aqua passive |

Caps bind the slide, the slide-jump and the held air speed (`cap(c)` in MovementController), so a slow does cut the chain.
Dashes ignore any cap of 12 or more.


## 4. Gap closers against the shared chain (pass d, part 2)

| Closer | Effective closing speed | vs chain 59 | Works through a cap of 14–15? |
|---|---|---|---|
| Shared chain (every Element) | ~59 sustained, 66.8 peak | — | no: capped |
| Shadow Step (Umbra) | ~183 over 22 studs | faster | not verified |
| Overcharge (Voltaic) | 69 over 11 studs | faster, tiny | yes (MinCap 12) |
| Bulwark Charge (Terra) | 42 over 26 | slower | yes |
| Undertow (Aqua) | ~41 (moves the target 36) | slower | yes |
| Skyrider (Zephyr) | 42 / 55 | slower | not verified |
| Cross-Slash (Zephyr) | 15–27 | much slower | yes |

**Closing always wins once it starts**, except against Cryo: only Chill (cap 22, then 15) and Blizzard (14) drop the
chain below the kiter's own 59, and both are Cryo's (Blizzard is in the shared pool). Every dash still works under every
cap except Flash Freeze's 5 and roots, because the dash threshold is 12.

## 5. Mana economy (pass c; every hit lands, DoTs run full)

| M1 | Damage/s | Mana/s | Damage per mana | Sustainable on 7/s regen? |
|---|---|---|---|---|
| Icicle Shard | 24 | 6.0 | 4.0 | yes |
| Fireball | 30 (+9 splash) | 5.0 | 6.0 | yes |
| Wind Blade | 25 | 6.7 | 3.75 | yes |
| Boulder Shot | 24.6 | 2.05 | 12.0 | yes |
| Chain Bolt | 25 (range 30) | 6.25 | 4.0 | yes |
| Shadow Dart | 25 | 1.9 | 13.0 | yes |
| Light Lance | 16 → 32 | 7.5 | ~3.7 | net −0.5/s |
| Riptide | 18 | 6.0 | 3.0 | yes |
| Toxic Bubbles | 16.4 + 4 poison | 5.45 | 3.7 | yes |

Every M1 except Light Lance costs less than the regen, so firing never costs a decision.

| Ability | Damage (or heal) a cast | Per mana | Per second of cooldown | Note |
|---|---|---|---|---|
| **Scorching Lash** | 12 + 16 burn a stack (3 stacks: 14 dps sustained) | 2.3 | **10.3–14** | 2.5 s cooldown, 4.4 mana/s: a second M1 at close range |
| Detonate | 12–48, no line of sight | 0.6–2.4 | 0.9–3.4 | |
| Immolate | +36 | 1.4 | 3.0 | |
| Flash Freeze | 44 + ~4 s root | 1.5 | 3.1 | the root is worth ~12 free Icicle hits |
| Railspike | 30 | 1.5 | 3.0 | |
| Volt Orb | 14–36 | 0.7–1.8 | 1.2–3.0 | |
| Bulwark Charge | 35 + stagger | 1.2 | 3.9 | |
| Aftershock | 20 + knock | 1.0 | 1.7 | |
| Cross-Slash | 30 | 1.2 | 3.0 | |
| Mark | +10 to +150 | 0.6–8.3 | 0.7–10.7 | headshot-dependent |
| Twin Tide | 35 | **0.9** | 2.2 | worst damage per mana |
| Sidearm | 8 a bullet, 12.8 dps | 1.3 | — | 9.6 mana/s: cannot be sustained |
| Corrosive Cloud | ≤36 + poison | 1.4 | 4.0 | only if they stand in it |
| Acid Rain | ≤16 + Corroded | **0.5** | 1.1 | |
| Benediction | 15 HP/s for up to 30 s (~450 HP) | 1.5 HP/mana | — | no real cap on sustain |
| Blessing | 35 shield | 1.4 HP/mana | 2.9 | |

## 6. Simulation (passes a and b)

**Model** (assumptions, all in `sim.py`): open disc arena r120, spawns 220 apart near the edge, no cover, no walls;
aim spread 1°, 40 ms tracking lag, 45% of a target's lead unpredictable; telegraph reaction 0.15–0.45 s; Ultimates ready
after 30 s; default loadouts; preset A. Rusher: closes with the chain, fights at its close range with its best
close kit. Kiter: holds its longest range, uses slows and roots on cooldown, escapes with its tools. 60 runs a pairing.
The mixed/adaptive policy was not run.

Headline numbers:
- **Contact comes in ~4 s in 75 of 81 pairings** (mean 5.6 s). Only a Cryo kiter holds a rusher off for longer
  (12–34 s), through Chill and Blizzard.
- **A kiter deals 22 HP on average from beyond 40 studs before the fight closes** (15% of a life).
- **Point-blank is the best range for nearly every kit:** the TTK search picked 8 studs for most attacker–target pairs
  and 20 for the rest; no kit's best range was 45 or 90.
- Rusher wins: 37 of 81 pairings above 55%, 41 below 45%. The outcome is set by close-range strength, not by the
  approach.
- **Kill time spread is 2.8×:** Pyro kills in 3.6 s on average, Toxin in 10.1 s. Terra is the hardest to kill (9.5 s).


### TTK (s), attacker row vs target column, attacker at its best range [range]

| | Aqua | Cryo | Pyro | Radiant | Terra | Toxin | Umbra | Voltaic | Zephyr | mean |
|---|---|---|---|---|---|---|---|---|---|---|
| **Aqua** | 8.2 [8] | 8.1 [8] | 8.3 [8] | 10.1 [8] | 11.2 [8] | 8.4 [8] | 8.5 [8] | 8.5 [8] | 8.2 [8] | 8.8 |
| **Cryo** | 7.5 [8] | 7.7 [8] | 7.6 [8] | 9.6 [8] | 11.8 [8] | 7.5 [8] | 8.0 [8] | 7.4 [8] | 7.5 [8] | 8.3 |
| **Pyro** | 3.2 [8] | 3.1 [8] | 3.0 [8] | 4.5 [8] | 5.4 [8] | 3.1 [8] | 3.4 [8] | 3.4 [8] | 3.1 [8] | 3.6 |
| **Radiant** | 5.7 [20] | 5.6 [8] | 5.9 [8] | 6.9 [8] | 10.3 [20] | 6.0 [8] | 5.9 [8] | 5.9 [20] | 5.8 [8] | 6.4 |
| **Terra** | 6.6 [8] | 6.7 [8] | 7.0 [8] | 8.0 [8] | 8.0 [20] | 6.0 [8] | 8.6 [8] | 5.4 [20] | 7.2 [8] | 7.1 |
| **Toxin** | 9.2 [8] | 9.5 [8] | 9.2 [8] | 12.3 [8] | 12.7 [8] | 9.4 [8] | 9.8 [8] | 9.3 [8] | 9.8 [8] | 10.1 |
| **Umbra** | 6.2 [8] | 5.5 [8] | 6.7 [8] | 6.2 [8] | 5.7 [8] | 5.8 [8] | 8.9 [20] | 6.2 [8] | 5.3 [8] | 6.3 |
| **Voltaic** | 5.5 [20] | 5.0 [8] | 5.1 [8] | 6.8 [8] | 9.5 [8] | 5.2 [8] | 5.8 [8] | 5.1 [20] | 5.1 [8] | 5.9 |
| **Zephyr** | 8.3 [20] | 8.3 [20] | 8.3 [20] | 10.1 [20] | 10.7 [20] | 8.2 [20] | 8.5 [20] | 8.2 [20] | 8.2 [20] | 8.8 |

### Rusher (row) win rate vs kiter (column)

| | Aqua | Cryo | Pyro | Radiant | Terra | Toxin | Umbra | Voltaic | Zephyr | mean |
|---|---|---|---|---|---|---|---|---|---|---|
| **Aqua** | 0.30 | 0.00 | 0.00 | 0.00 | 0.07 | 0.17 | 0.00 | 0.00 | 0.00 | 0.06 |
| **Cryo** | 0.97 | 0.32 | 0.08 | 0.02 | 0.38 | 1.00 | 0.18 | 0.58 | 0.88 | 0.49 |
| **Pyro** | 1.00 | 0.80 | 0.55 | 0.22 | 0.92 | 1.00 | 0.65 | 0.95 | 0.98 | 0.79 |
| **Radiant** | 1.00 | 0.78 | 0.12 | 0.25 | 0.78 | 1.00 | 0.60 | 0.77 | 1.00 | 0.70 |
| **Terra** | 0.97 | 0.67 | 0.63 | 0.45 | 0.73 | 1.00 | 0.43 | 0.80 | 0.95 | 0.74 |
| **Toxin** | 0.22 | 0.00 | 0.00 | 0.00 | 0.10 | 0.35 | 0.00 | 0.00 | 0.00 | 0.07 |
| **Umbra** | 0.97 | 0.72 | 0.42 | 0.27 | 0.73 | 0.85 | 0.35 | 0.97 | 0.73 | 0.67 |
| **Voltaic** | 1.00 | 0.22 | 0.00 | 0.00 | 0.42 | 1.00 | 0.27 | 0.45 | 0.70 | 0.45 |
| **Zephyr** | 0.92 | 0.03 | 0.00 | 0.00 | 0.13 | 0.92 | 0.12 | 0.43 | 0.78 | 0.37 |

### Mean time until the rusher reaches its fighting range (s; 60 = never)

| | Aqua | Cryo | Pyro | Radiant | Terra | Toxin | Umbra | Voltaic | Zephyr | mean |
|---|---|---|---|---|---|---|---|---|---|---|
| **Aqua** | 4.0 | 7.0 | 3.8 | 3.8 | 3.8 | 3.8 | 3.8 | 3.8 | 3.8 | 4.2 |
| **Cryo** | 3.6 | 33.8 | 3.9 | 3.4 | 4.0 | 3.9 | 5.0 | 3.7 | 3.4 | 7.2 |
| **Pyro** | 3.9 | 30.3 | 3.9 | 3.8 | 3.8 | 3.8 | 3.8 | 3.9 | 3.9 | 6.8 |
| **Radiant** | 4.0 | 7.5 | 3.8 | 3.8 | 3.8 | 3.8 | 3.8 | 3.8 | 3.8 | 4.2 |
| **Terra** | 3.9 | 8.6 | 3.9 | 3.9 | 3.9 | 3.9 | 3.9 | 3.9 | 3.9 | 4.4 |
| **Toxin** | 3.9 | 25.8 | 4.0 | 3.9 | 3.9 | 3.9 | 3.9 | 4.0 | 4.0 | 6.4 |
| **Umbra** | 12.8 | 14.6 | 9.9 | 1.8 | 3.3 | 5.2 | 4.2 | 6.1 | 9.0 | 7.4 |
| **Voltaic** | 3.9 | 14.5 | 3.9 | 3.9 | 3.9 | 3.9 | 4.8 | 3.9 | 3.9 | 5.2 |
| **Zephyr** | 4.0 | 7.6 | 3.8 | 3.8 | 3.8 | 3.8 | 3.8 | 3.8 | 3.8 | 4.2 |

### Damage the kiter dealt from beyond 40 studs

| | Aqua | Cryo | Pyro | Radiant | Terra | Toxin | Umbra | Voltaic | Zephyr | mean |
|---|---|---|---|---|---|---|---|---|---|---|
| **Aqua** | 11 | 30 | 38 | 29 | 8 | 6 | 21 | 30 | 19 | 21 |
| **Cryo** | 10 | 58 | 34 | 18 | 3 | 7 | 33 | 30 | 13 | 23 |
| **Pyro** | 7 | 46 | 34 | 30 | 2 | 6 | 36 | 27 | 19 | 23 |
| **Radiant** | 10 | 25 | 27 | 24 | 5 | 8 | 29 | 26 | 19 | 19 |
| **Terra** | 9 | 34 | 30 | 25 | 6 | 6 | 28 | 24 | 16 | 20 |
| **Toxin** | 11 | 55 | 36 | 29 | 7 | 7 | 48 | 28 | 20 | 27 |
| **Umbra** | 5 | 24 | 32 | 1 | 6 | 4 | 30 | 25 | 15 | 16 |
| **Voltaic** | 9 | 40 | 38 | 30 | 4 | 6 | 34 | 26 | 37 | 25 |
| **Zephyr** | 11 | 52 | 36 | 30 | 6 | 6 | 37 | 26 | 18 | 25 |


### Why the rusher wins where it wins (above 55%)

| Rusher | Pairings above 55% | Mechanical cause |
|---|---|---|
| Cryo | Aqua, Toxin, Voltaic, Zephyr | equal-speed chase + stronger close kit than these kiters |
| Pyro | Aqua, Cryo, Terra, Toxin, Umbra, Voltaic, Zephyr | close-range burst: Scorching Lash every 2.7 s stacking burn + Fireball + Detonate (TTK 3.6 s); contact in ~4 s |
| Radiant | Aqua, Cryo, Terra, Toxin, Umbra, Voltaic, Zephyr | hitscan beam lands ~90% at close range, Blessing 35 shield, Halo lifesteal; contact in ~4 s |
| Terra | Aqua, Cryo, Pyro, Terra, Toxin, Voltaic, Zephyr | Bulwark Charge 35 + stagger, Aftershock, 20% Bedrock DR, Earthen Tomb 75 on a slowed/close target |
| Umbra | Aqua, Cryo, Terra, Toxin, Voltaic, Zephyr | Shadow Step blink (183 studs/s) ignores the chase; Mark + 65 dart burst |
| Voltaic | Aqua, Toxin, Zephyr | equal-speed chase + stronger close kit than these kiters |
| Zephyr | Aqua, Toxin, Zephyr | equal-speed chase + stronger close kit than these kiters |

## 7. Recommendations (target values; nothing has been changed in Studio)

| # | Change | Target | Confidence |
|---|---|---|---|
| 1 | Let ranged damage land before contact: Fireball Speed 65 → 110, Toxic Bubble Speed 60 → 90, Riptide Speed 70 → 100, Icicle Shard Speed 170 → 220 | kiter damage before contact ≥ 40 HP (now 22) | medium |
| 2 | Lower the sustained chain: SlideJumpMinSpeed 56 → 42, SlideJumpMaxSpeed 70 → 52, SlideJumpBoost 32 → 22 | chain ≤ 45 studs/s (now 59) | medium (owner's feel call) |
| 3 | Make slows stop dashes: DashMotor MinCap 12 → 16, or Blizzard SlowCap 14 → 11 | Chill 2 stacks / Blizzard block dashes | high (mechanical) |
| 4 | Duel spawn marks ≥ 40 studs inside the map edge, with cover between | a kiter has room to retreat | medium |
| 5 | Add a round timer (`Config.Duel.RoundTime` 90 s), tiebreak on HP % | a lead can be protected | medium |
| 6 | Pyro: Scorching Lash Cooldown 2.5 → 5 s; preset A Lash PerStack 1.6 → 1.0 | Pyro mean TTK ~5 s (now 3.6) | high direction, medium numbers |
| 7 | Toxin: Poisoned TickDamage 4 → 6, Acid Rain TickDamage 4 → 6 (plus #1's bubble speed) | Toxin mean TTK ~7 s (now 10.1) | medium-low |
| 8 | Aqua: Sidearm BulletCost 6 → 4, Twin Tide ManaCost 40 → 30, CrushHalfWidth 3.5 → 5 | Aqua rows/columns within 0.35-0.65 | medium-low |
| 9 | Zephyr: Skyrider FlySpeed 42 → 60, BoostSpeed 55 → 75; confirm Cross-Slash 12/40 (ASSUMED); delete stray DashDistance 55 | Skyrider faster than the chain | low-medium |
| 10 | Give 1v1-dead pieces a duel effect: preset A Charged AloneDamage 0 → 7; rework Ember Refund, Chain Reaction (kill-triggered), Overcharge's prime and Antitoxin Vent for a 1v1 | every slot does something in a duel | high that they are dead; design open |
| 11 | Benediction MaxChannel 30 → 8 s (or HealPerPulse 7.5 → 5) | ≤ ~120 HP a cast (now ~450) | medium |
| 12 | Deep Freeze Root 2.5 → 1.5 s (open owner question) | ~4 free Icicle hits instead of ~7 | low-medium |
| 13 | Blizzard: keep Radius 32, Duration 8 → 6, SlowCap 14 → 11 (open owner question) | the one zone a rusher can't dash through | medium |
| 14 | Mirror Cage: keep the volley (12 x 6 over 1.6 s = 72, in line with Ring 70 / Tomb 75); root 3.13 → 2.3 s | root ends with the volley | low-medium |
| 15 | Data fixes: Boulder Shot MinSpeed 108 > MaxSpeed 86 (full charge flies slower); Fireball row Range 110 vs 162 flight; Undertow row Range 30 vs Reach 36; stale AbilityHandler ShardChillWindow 3.0 | sources agree | high |

## 8. Open questions
- The adaptive (switching) policy was not run; no cover, walls or wall-running in the arena model.
- The aim model is assumed; no sensitivity sweep was run. Rankings should be read as directions, not exact rates.
- Whether a slow cap or a root stops Shadow Step's blink or Skyrider's flight was not checked in live code.
- Cold Momentum's +10% for 2 s comes from the doc and a config row; it was not printed live.
- Ultimates are assumed ready after 30 s; real charge depends on damage dealt and taken.
- Deep Freeze's trigger rate on a chaser (60%) and the 25% headshot rate for Mark are guesses.
- Every number marked PROP above still needs the owner's sign-off; Cross-Slash's 12/40 is ASSUMED in live Tuning.
