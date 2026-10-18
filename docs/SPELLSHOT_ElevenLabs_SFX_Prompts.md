# SPELLSHOT — ElevenLabs SFX prompts (realistic, grounded)

Model: **Sound Effects v2** (`eleven_text_to_sound_v2`). Paste each prompt into a Sound Effects generation, one prompt per sound. Names match the SFX plan (`CMB_...`), so save each result under that name.

## How to use

- **One sound per prompt.** The model blurs several sounds together, so never combine two.
- **Duration:** the minimum is 0.5 s. Very short sounds (hits, ticks, Cryo shots) should still be generated at 0.5 s, then trimmed to the target length in Audacity or any editor. Use the "Duration" column for the generation and the "Trim to" column for the final file.
- **Prompt influence:** 0.6 for precise hits and impacts, 0.4 for swells and stingers (the model has more freedom).
- **Variations:** generate 4 and keep the best 3 (or 4 for repeating sounds, like M1 fire).
- **After generating:** trim, normalise to -3 dBFS peak, export WAV (mono for 3D sounds, stereo for stingers), then upload to Roblox.
- Every prompt ends in "no music, no voice" where it matters, because the model otherwise adds them.

## A. Feedback to the player (2D)

| ID | Prompt | Duration | Trim to | Influence |
|---|---|---|---|---|
| CMB_Hit_Normal | Short dry impact tick, tight punchy thock with a crisp click, close-mic, no reverb, no music | 0.5 | 0.1 s | 0.6 |
| CMB_Hit_Strong | Heavy dry body impact, deep punchy thump with a sharp crack on top, short tail, no music | 0.5 | 0.2 s | 0.6 |
| CMB_Hit_Headshot | Sharp crisp crack impact, bright snap with a short low thud underneath, dry, close-mic | 0.5 | 0.2 s | 0.6 |
| CMB_Kill_Confirm | Heavy punchy impact with a deep sub thump and a sharp crack, short natural room tail, dry, no music | 1.0 | 0.6 s | 0.6 |
| CMB_Dmg_Light | Soft dull body hit, short low thud with muffled cloth, close-mic, no voice | 0.5 | 0.14 s | 0.6 |
| CMB_Dmg_Medium | Solid body impact thud, fuller low thump with a muffled crunch, close-mic, no voice | 0.5 | 0.22 s | 0.6 |
| CMB_Dmg_Heavy | Deep heavy body blow, low thump with a short rumble tail, no voice, no screaming | 0.8 | 0.4 s | 0.6 |
| CMB_LowHealth | Slow low heartbeat, soft deep thump, muffled, one beat pair every second | 2.0 | loop | 0.5 (turn Loop on) |
| CMB_UltReady | Rising low energy swell building into a single deep pulse, restrained, no melody, no music | 1.5 | 1.2 s | 0.4 |

## B. M1 fire and impact, per Element

| ID | Prompt | Duration | Trim to | Influence |
|---|---|---|---|---|
| CMB_Pyro_Fire | Short soft flame whump, gas igniting with a light crackle, close-mic | 0.5 | 0.25 s | 0.6 |
| CMB_Pyro_Impact | Small fire burst impact with crackling embers | 0.5 | 0.35 s | 0.6 |
| CMB_Zephyr_Fire | Quick sharp whoosh of air, fast wind slice, close-mic | 0.5 | 0.25 s | 0.6 |
| CMB_Zephyr_Impact | Wind gust puff with a sharp snap | 0.5 | 0.3 s | 0.6 |
| CMB_Terra_Fire | Dull stone launch, low thud with a short rock scrape | 0.5 | 0.25 s | 0.6 |
| CMB_Terra_Impact | Rock cracking and crumbling into gravel, solid impact | 1.0 | 0.5 s | 0.6 |
| CMB_Aqua_Fire | Wet bubble pop launch, short watery burst | 0.5 | 0.25 s | 0.6 |
| CMB_Aqua_Impact | Water splash slap, wet impact with droplets | 0.5 | 0.35 s | 0.6 |
| CMB_Cryo_Fire | Sharp ice crack whip, short crystalline snap with a fast thin air hiss, close-mic | 0.5 | 0.16 s | 0.6 |
| CMB_Cryo_Impact | Ice shattering into small pieces, crunchy glass-like break with a dull thud under it | 0.8 | 0.35 s | 0.6 |
| CMB_Voltaic_Fire | Electric zap crack, sharp arc spark, close-mic | 0.5 | 0.25 s | 0.6 |
| CMB_Voltaic_Impact | Electric snap with a short fizzling buzz | 0.5 | 0.35 s | 0.6 |
| CMB_Toxin_Fire | Wet gloopy spit, thick liquid launch | 0.5 | 0.25 s | 0.6 |
| CMB_Toxin_Impact | Acid sizzle, bubbling hissing liquid impact | 0.8 | 0.45 s | 0.6 |
| CMB_Umbra_Windup | Long low dark swell slowly rising, deep hum building tension, no music | 2.5 | 2.3 s | 0.4 |
| CMB_Umbra_Fire | Thin dark whoosh release with a muffled thump | 0.5 | 0.3 s | 0.6 |
| CMB_Umbra_Impact | Muffled dark thud with a short low rumble | 0.8 | 0.4 s | 0.6 |
| CMB_Radiant_Fire | Soft bright airy whoosh with a faint shimmer | 0.5 | 0.25 s | 0.6 |
| CMB_Radiant_Impact | Gentle light burst, soft shimmer with a small airy pop | 0.8 | 0.4 s | 0.6 |

## C. Eliminations

| ID | Prompt | Duration | Trim to | Influence |
|---|---|---|---|---|
| CMB_KO_Impact | Heavy ground impact slam, deep thud with a short burst of dust and debris | 1.0 | 0.75 s | 0.6 |
| CMB_Ragdoll_Light | Body falling onto dirt ground, soft thud with a cloth rustle, close-mic | 0.5 | 0.3 s | 0.6 |
| CMB_Ragdoll_Heavy | Heavy body slamming onto hard ground, deep thud with a short tumbling roll | 1.0 | 0.6 s | 0.6 |
| CMB_Death_Sting | Short low muffled boom that fades away, no voice | 1.0 | 0.8 s | 0.5 |
| CMB_Body_Exit | Soft airy puff with fine dust scattering, light low pop | 0.8 | 0.5 s | 0.5 |

## D. Healing

| ID | Prompt | Duration | Trim to | Influence |
|---|---|---|---|---|
| CMB_Heal_Received | Soft warm rising airy shimmer, gentle and clean, no music | 1.0 | 0.7 s | 0.4 |
| CMB_Heal_Lifesteal | Small wet gulp, a single liquid swallow, close-mic | 0.5 | 0.3 s | 0.6 |

## E. Round and match flow

| ID | Prompt | Duration | Trim to | Influence |
|---|---|---|---|---|
| CMB_Round_Tick | Single sharp dry mechanical click, like a heavy clock tick, close-mic | 0.5 | 0.1 s | 0.6 |
| CMB_Round_Go | Deep powerful impact boom with a short metallic clang, natural echo | 1.0 | 0.8 s | 0.5 |
| CMB_Round_Win | Short brass swell with a timpani hit and a cymbal wash, triumphant but restrained | 2.0 | 1.8 s | 0.4 |
| CMB_Round_Lose | Low dark brass drone with a single deep timpani hit, short, somber | 2.0 | 1.6 s | 0.4 |
| CMB_Match_Win | Rising cymbal swell into big timpani hits and a full brass chord, triumphant, ending in a ringing cymbal | 4.0 | 3.5 s | 0.4 |
| CMB_Match_Lose | Slow low somber brass drone with a deep drum hit, fading out | 3.0 | 2.5 s | 0.4 |

## Notes and flags

1. **Credits.** Each generation spends credits, and four variations cost four times as much. The plan has about 45 sounds. Start with the sounds you'll hear most: Hit_Normal, Kill_Confirm, Dmg_Medium and Cryo_Fire/Impact.
2. **Round tick:** generate one tick, then pitch it up two steps in your editor for "2" and "1" (about +2 and +4 semitones).
3. **The stingers** (Round and Match) may come out sounding like music. If a result is too melodic, regenerate it as "timpani hit and cymbal swell only".
4. **Commercial use and Roblox upload:** check your ElevenLabs plan's commercial terms before putting the sounds in a released game. Roblox also moderates uploads.
5. **The KO sound** is named `CMB_KO_Impact` here (it replaces the comic stamp); rename it in the wiring prompt if you prefer `CMB_KO_Stamp`.
