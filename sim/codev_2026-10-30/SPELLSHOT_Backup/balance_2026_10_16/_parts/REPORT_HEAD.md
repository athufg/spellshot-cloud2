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
