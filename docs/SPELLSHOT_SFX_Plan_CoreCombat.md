# SPELLSHOT — SFX Plan, pass 1: Core Combat

Status: plan only, no sound files yet. Style: mixed (comic pop-art for HUD, callouts and the KO!, grounded for ability effects). Source: original sounds synthesised by Claude, uploaded to Roblox by the developer. The manual (v0.24) has no audio section, so everything here is new and is a starting point for playtesting, not final.

## 1. What this pass covers

M1 fire and impact for every Element, hit feedback, damage taken, kills and the KO!, ragdoll and body-clear sounds, healing, and round and match flow. Not in this pass: ability sounds beyond M1 (Primary, Ultimate, Techniques, passives, status effects), Hub and menu UI, music, ambience, and skin-specific kill-effect audio.

## 2. Sound design language

**Comic layer (the game's "voice"):** the KO! stamp, hit confirms, round stingers, countdown and any callout. Short, bright, punchy, a little synthetic: stamp thunks, pitched pops, rubbery blips, snare-style snaps. These sounds are the same for every Element, because the basic kill effect is deliberately Element-neutral so it never misreports who landed the kill.

**Grounded layer (Elements):** M1 fire and impacts use the real material of each Element (ice crack, fire whump, rock crunch, water splash, electric snap, and so on), layered as a sharp transient, a body and a short tail. They stay short so a 3-per-second M1 never becomes mush.

**Two rules for everything:** a sound must say what happened before it says how cool it is (hit, hurt, kill and round state are always instantly distinguishable), and nothing may be fatiguing when heard hundreds of times in a match.

## 3. Mix hierarchy and rules

Loudest to quietest, as relative starting levels (0 dB = normal hit confirm; true peak never above -3 dBFS):

| Group | Level | Notes |
|---|---|---|
| Kill confirm (killer only) | +2 dB | The payoff moment |
| Hit confirm (attacker only) | 0 dB | Bright ping around 3 to 5 kHz so it cuts through any fight |
| Damage taken (victim only) | -2 dB | Clear, never harsh |
| Round win/lose stingers | -4 dB | 2D, over a quiet moment |
| KO! stamp (world, everyone) | -4 dB | 3D |
| Countdown ticks | -6 dB | 2D |
| Own M1 fire | -8 dB | 2D, first person |
| Ragdoll thud | -8 dB | 3D |
| Impacts | -9 dB | 3D |
| Enemy and ally M1 fire | -10 dB at 8 studs | 3D with falloff |
| Body-clear pop | -10 dB | 3D |
| Heal sounds | -12 dB | Soft, never confusable with damage |

**Priority when the mix is full:** own hit confirm and kill, then damage taken, then own fire, then nearby enemies, then allies, then distant sounds.

**Voice caps (starting points):** enemy and ally M1 fire 6 at once, impacts 8, body-clear pops 3 per second (Squad Clash can leave ten bodies), own hit confirm retriggers at most every 60 ms. On mobile, halve the caps.

**Fatigue control for fast M1s:** keep M1 fire under about 0.25 s, with 3 to 4 variants and random pitch of plus or minus 6%, and avoid strong 2 to 4 kHz energy.

## 4. The core-combat sound list

Naming: `CMB_<Group>_<Name>`. "2D" means heard by one player in their own ears, "3D" means positioned in the world with falloff.

### A. Feedback to the player (2D, server-confirmed only)

| ID | Trigger | Who hears | Brief | Length |
|---|---|---|---|---|
| CMB_Hit_Normal | You damage an enemy | Attacker | Bright short ping, 3 variants | 0.08 s |
| CMB_Hit_Strong | A big hit (set by % of the target's max HP, not absolute) | Attacker | Same ping with a deeper punch under it | 0.15 s |
| CMB_Hit_Headshot | Umbra Mark's headshot payoff | Attacker | Higher, crisper ping with a tiny flare | 0.2 s |
| CMB_Kill_Confirm | You land the final hit | Attacker | Punchy comic "ding-thunk", synced with the KO! stamp | 0.4 s |
| CMB_Dmg_Light | You take a small hit | Victim | Soft thud with a short high tick | 0.12 s |
| CMB_Dmg_Medium | A medium hit | Victim | Fuller thud | 0.18 s |
| CMB_Dmg_Heavy | A big hit | Victim | Deep thump with a short ring, never a scream | 0.3 s |
| CMB_LowHealth | Dropping below a low-health threshold (about 25%) | Victim | Soft low pulse, optional, off after healing | 0.5 s loop |
| CMB_UltReady | The Ultimate reaches full charge | Owner | Rising two-note chime, once | 0.6 s |

### B. M1 fire and impact, per Element

Each Element gets one fire sound (3 to 4 variants) and one impact sound (3 variants). Own fire is 2D, other players' fire is 3D. Confirm each M1's exact name and fire rate from the code; the manual's appendix gives Cryo's Icicle Shard as up to 3 shots per second, and Umbra's Shadow Dart as a shot every 2.6 s with a 2.3 s windup.

| Element | Fire sound | Impact sound |
|---|---|---|
| Pyro | Soft flame whump with a crackle | Short fireburst pop |
| Zephyr | Quick airy whoosh | Wind puff and snap |
| Terra | Dull stone launch | Rock crack and crumble |
| Aqua | Wet bubble-pop launch | Splash slap |
| Cryo | Crisp icy flick, very short (it fires fastest) | Glassy shatter tick |
| Voltaic | Electric zap | Electric snap and fizzle |
| Toxin | Gloopy spit | Wet acid sizzle |
| Umbra | A long, low windup swell (about 2.3 s) then a thin dark release | Muffled dark thud |
| Radiant | Soft bright chime-whoosh | Gentle light burst |

Total for B: 18 sounds, about 54 files with variants.

### C. Eliminations

| ID | Trigger | Who hears | Brief |
|---|---|---|---|
| CMB_KO_Stamp | The KO! callout appears over the falling body | Everyone near the body (3D) | Comic stamp thunk with a snappy tail, Element-neutral |
| CMB_Ragdoll_Light | Body tips over | Nearby (3D) | Soft thud, 2 variants |
| CMB_Ragdoll_Heavy | Body is launched by a big hit | Nearby (3D) | Heavier body slam, 2 variants |
| CMB_Death_Sting | You are eliminated | Victim (2D) | Short falling comic sting, not distressing |
| CMB_Body_Exit | The body clears in a puff of ink and halftone dots | Nearby (3D) | Light "pop" with soft dots patter |

A kill with no killer plays the same basic sounds. A skin's special kill effect replaces both beats, and its own audio will come with the skin later (the KO! stamp and the body-clear pop are the two slots it overrides).

### D. Healing

| ID | Trigger | Who hears | Brief |
|---|---|---|---|
| CMB_Heal_Received | Health restored by a healer | Receiver (2D) | Soft rising shimmer, never a damage-like thud |
| CMB_Heal_Lifesteal | Toxin's lifesteal heal | Toxin player (2D) | Small gloopy "gulp" tick, quieter |

### E. Round and match flow

| ID | Trigger | Who hears | Brief |
|---|---|---|---|
| CMB_Round_Tick | Countdown, 3 then 2 then 1 | All (2D) | Sharp, clean tick with rising pitch |
| CMB_Round_Go | Round starts | All (2D) | Punchy comic "GO" stab |
| CMB_Round_Win | Your team wins the round | Winners (2D) | Short bright win stinger |
| CMB_Round_Lose | Your team loses the round | Losers (2D) | Short low, gentle lose stinger, not punishing |
| CMB_Match_Win | Match won | Winners (2D) | Longer fanfare, about 2 s |
| CMB_Match_Lose | Match lost | Losers (2D) | Short sober sting, about 1.5 s |

## 5. Totals

About 42 distinct sounds and roughly 90 files with variants. The Cryo M1 is the hardest case (fastest fire rate), so it is the right first test of the style.

## 6. Roblox implementation notes (for the later wiring prompt)

- **Sound groups:** one SoundGroup tree (Master, Combat, UI and Stingers) so volume sliders and mix rules apply in one place.
- **Positioning:** 3D sounds use a RollOff with a min of about 8 studs and a max of 90 studs for M1 (about 120 for the KO! stamp); 2D sounds play straight into the listener.
- **Server-confirmed:** hit confirm, kill confirm and the KO! stamp play only after the server confirms the hit or kill, matching the kill-effect rule. Never play a hit confirm on a predicted hit.
- **Variation:** several variants per repeating sound with random pitch (plus or minus 6%, plus or minus 4% for hit confirms so they stay recognisable).
- **Pooling and preloading:** pool Sound instances and preload the combat set, so the first shot of a match has no delay.
- **Format:** mono WAV for 3D sounds, stereo for stingers; Roblox accepts several formats, and uploads are moderated, which original synthesised sounds avoid copyright problems for. Check your account's monthly audio upload allowance before a large batch.

## 7. Open questions and flags

1. **No audio settings exist in the manual.** Volume sliders (Master, SFX, UI) are needed; decide whether to add them to the manual's settings.
2. **M1 fire rate mismatch:** the appendix says Icicle Shard fires up to 3 per second, while the working figure used in design talks is about 2 per second (0.5 s). Sounds are designed for the faster rate (3 per second) so both work.
3. **HP is still open (100 in the manual, 150 in the build).** Damage-taken and strong-hit tiers are defined as percentages of max HP so they hold either way.
4. **Reduce Enemy VFX** is a visual setting; I would not apply it to audio, since sound is combat information. Flag if you want it to quieten enemy sounds.
5. **Skin kill-effect audio** (Devil, Frost Drake and others) comes with each skin later; this pass only reserves the two override slots.
6. **Music and ambience** are out of this pass.

## 8. Proposed next step

Synthesise a first test batch: the universal feedback set (hit confirms, kill confirm, damage taken, KO! stamp, round ticks and stingers) plus the Cryo M1 fire and impact, as WAV files for you to hear and upload. If the style is right, extend to the other Elements.
