# SPELLSHOT — ElevenLabs SFX review (164 files, 41 sounds x 4 variants)

**How this was reviewed:** I can't listen to audio. Everything below comes from decoding every file and measuring it (length, peak and loudness, clipping, lead-in silence, tail, number of separate hits, stereo/mono behaviour, spectral balance), plus spectrograms of all 164 (three contact sheets). Treat the picks as a shortlist to audition, not a final call. In particular I can't tell you if a brass stinger sounds musical or a splash sounds like water.

## Findings that affect every sound

1. **Nothing is trimmed yet.** Every file is the exact generation length (0.48 s for the 0.5 s ones, etc.). Most sounds have their real energy finish well before that, so trimming is needed (targets are in the prompts file).
2. **Loudness is all over the place.** Peaks run from -44 dB to +4 dB, even between variants of the same sound. Every file needs normalising to -3 dBFS peak (and Kill, Hit and Dmg then set to the mix levels in the plan). Very quiet variants (marked weak below) would need +20 dB or more and will be noisy.
3. **Clipping at source.** Kill_Confirm clips in all 4 variants (14 to 114 samples), Match_Win v2 has 763 clipped samples, Heal_Received v2 has 107, Cryo_Fire v2 has 24. Normalising down hides the overs but not the distortion, so avoid those variants.
4. **Dead air at the start of Umbra_Windup.** All 4 variants have 0.52 to 0.76 s of silence before the sound begins. Trim it, or the charge-up will feel delayed. Smaller lead-ins: Round_Tick v2/v3 (0.1 s), UltReady v2 (0.34 s), Heal_Received v4 (0.16 s), LowHealth v4 (0.54 s).
5. **Tails are clean.** Most files end near silence (-55 to -80 dB), so there are no hard cut-offs. Exceptions that never decay and need a fade when trimmed: Heal_Received v1/v3/v4, UltReady v1/v4 (that one is a riser, fine), LowHealth v1/v3 (a loop issue, see below).
6. **Mono-safe.** Downmixing to mono (needed for 3D sounds) loses under 2 dB for nearly everything, worst case Dmg_Light v3 at 3.7 dB (it's a 2D sound, so no issue).
7. **Format:** 44.1 kHz stereo MP3 at 128 kbps. Roblox takes MP3, but convert to WAV or OGG for editing and don't re-encode MP3 to MP3.

## Suggested pick per sound

Alt = the second choice if the first doesn't sound right. "Eff" = measured length where the sound is within 30 dB of its peak. The prompts file's "Trim to" is the target.

| Sound | Pick | Alt | Eff vs target | Notes |
|---|---|---|---|---|
| Hit_Normal | v1 | v4 | 0.16 vs 0.10 | v2 is almost silent (-44 dB peak), skip it |
| Hit_Strong | v2 | v1 | 0.16 vs 0.20 | v1/v4 hit 0 dB, v2 has cleaner level |
| Hit_Headshot | v4 | v2 | 0.04 vs 0.20 | Bright crack plus low thud on the spectrogram, but very short; may feel thin, audition first |
| Kill_Confirm | v4 | v2 | 0.43 vs 0.60 | **Weak.** All variants clip and are squashed to about -8 dB RMS (about 12 dB louder than everything else) with 5 to 8 separate hits, so the tail is rattly. Worth one regeneration |
| Dmg_Light | v3 | v1 | 0.16 vs 0.14 | v1, v2, v4 peak at about -30 dB, weak |
| Dmg_Medium | v1 | v2 | 0.13 vs 0.22 | |
| Dmg_Heavy | v2 | v4 | 0.31 vs 0.40 | 0.1 s lead-in, trim |
| LowHealth | v2 | v3 | 2.22 s | Loop. Check the seam when you loop it: v1/v3 end loud (-14/-18 dB), v4 starts 0.54 s late |
| UltReady | v1 | v3 | 1.41 vs 1.20 | Only variant with a clear rise into the end on the spectrogram, which is what the prompt asked for |
| Pyro_Fire | v2 | v4 | 0.28 vs 0.25 | v4 clips |
| Pyro_Impact | v4 | v3 | 0.31 vs 0.35 | |
| Zephyr_Fire | v3 | v2 | 0.22 vs 0.25 | v4 clips |
| Zephyr_Impact | v1 | v2 | 0.24 vs 0.30 | |
| Terra_Fire | v2 | v3 | 0.14 vs 0.25 | **Weak set.** v1 peaks at -19 dB. v2 has the low thud |
| Terra_Impact | v2 | v3 | 0.52 vs 0.50 | |
| Aqua_Fire | v4 | v1 | 0.19 vs 0.25 | |
| Aqua_Impact | v1 | v3 | 0.36 vs 0.35 | v4 is quiet and thin |
| Cryo_Fire | v1 | v3 | 0.10 vs 0.16 | v2 clips, v4 is very quiet. Two close hits in v1 (crack and echo), check it still reads as one shot at fast fire |
| Cryo_Impact | v4 | v1 | 0.42 vs 0.35 | Several separate pieces (shatter), as intended |
| Voltaic_Fire | v4 | v3 | 0.28 vs 0.25 | Flat white-noise character; the decaying v3/v4 are more zap-like |
| Voltaic_Impact | v1 | v3 | 0.44 vs 0.35 | |
| Toxin_Fire | v1 | v2 | 0.30 vs 0.25 | |
| Toxin_Impact | v2 | v3 | 0.38 vs 0.45 | |
| Umbra_Windup | v1 | v4 | 2.38 vs 2.30 | **Cut the first 0.5 s of silence** |
| Umbra_Fire | v4 | v1 | 0.24 vs 0.30 | |
| Umbra_Impact | v1 | v3 | 0.58 vs 0.40 | Quiet (-12 dB), fine after normalising |
| Radiant_Fire | v4 | v1 | 0.23 vs 0.25 | |
| Radiant_Impact | v2 | v1 | 0.16 vs 0.40 | **Inconsistent set.** v2 is loud and short with a low thump; v1/v3/v4 are very quiet and tonal (bell-like bands, may sound musical) |
| KO_Impact | v3 | v4 | 0.52 vs 0.75 | v1 clips |
| Ragdoll_Light | v3 | v1 | 0.19 vs 0.30 | v2/v4 are quiet |
| Ragdoll_Heavy | v1 | v3 | 0.55 vs 0.60 | |
| Death_Sting | v2 | v4 | 0.81 vs 0.80 | Clean low boom. v1 has a bright click on the front, v3 is sub-only (may vanish on laptop speakers) |
| Body_Exit | v4 | v1 | 0.64 vs 0.50 | v1 is only the low pop, v2-v4 are only the airy hiss. Layer v1's pop under v4 to get what the prompt asked for |
| Heal_Received | v4 | v1 | 0.96 vs 0.70 | v1 is a very clean smooth sweep (could sound synthetic), v4 is breathier. Fade out when trimming, trim 0.16 s lead-in. v2 clips |
| Heal_Lifesteal | v3 | v2 | 0.28 vs 0.30 | |
| Round_Tick | v3 | v4 | 0.14 vs 0.10 | v1/v2 are double clicks (two hits) |
| Round_Go | v4 | v1 | 0.57 vs 0.80 | Only low content on the spectrogram, no obvious metallic clang |
| Round_Win | v1 | v4 | 1.11 vs 1.80 | One hit with a long decay, not a swell. v4 is brighter but clips |
| Round_Lose | v1 | v4 | 1.38 vs 1.60 | |
| Match_Win | v1 | v4 | 2.50 vs 3.50 | v2 clips heavily, v3 clips. The swell cuts off at about 2.5 s, then a decay. Fine as a riser plus hit |
| Match_Lose | v1 | v3 | 2.50 vs 2.50 | |

## Regenerate or redo (in order of value)

1. **Kill_Confirm.** The most important sound in the game and all four are clipped and compressed. Regenerate once, with "no reverb, short tail" in the prompt, and keep the generation length at 1.0 s.
2. **Terra_Fire, Dmg_Light, Radiant_Impact.** The pick is usable, but the best variant is quiet (Terra, Dmg_Light) or the set doesn't agree with itself (Radiant).
3. **Body_Exit and Round_Win.** Probably fine after layering or trimming, but you may want to regenerate if they don't sound right when you audition them.

Don't spend credits on anything else until you've auditioned the picks: the metrics can't tell me whether it sounds right.
