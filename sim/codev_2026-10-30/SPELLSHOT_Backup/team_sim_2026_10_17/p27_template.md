# SPELLSHOT P27: Voltaic and Umbra self-sufficiency, tested in the 3v3 sim

18 October 2026. The owner's P27 spec, run on top of team package v3 (see `SPELLSHOT_TEAM_MODE_PACKAGES.md`). The
numbers were fact-checked against the raw results and the sim's code by independent checkers, and one missing control
was run because of that check.

## Answer

**Self-escape tools don't fix Voltaic or Umbra. Making Umbra's dive pay off helps a little.**

- **Static Discharge leaves Voltaic slightly worse** in every variant (−0.7 to −1.4 points), and the bigger the tool, the worse it gets. Its death rate doesn't improve (71% → 72%), while its damage drops: the retreat carries it out of its 45-stud Chain Bolt range.
- **Umbra's defensive Shadow Step options stay within noise:** the 0.3 s vanish, a 1 s vanish, and the half cooldown on its own.
- **Dive play** (blinking in on a low target) is worth +1.2 on its own. It takes one of Umbra's three bottom-6 comps (Cryo + Umbra + Voltaic) out of the bottom 6.
- **The half cooldown on top of dive play adds +0.9** against a matching control, which is above noise. Umbra rises +2.3 in total, 42.3% → 44.6%.
  - Most of the extra Shadow Steps are dive-ins (1.18 → 1.56 a round). Under-fire blink-outs also rise (0.22 → 0.39 a round). Without dive play, extra blink-outs alone did nothing (+0.0), so the gain most likely comes from diving more often.
  - Umbra's bottom-6 count stays at 2. One Umbra comp (Cryo + Terra + Umbra) edges into the top 6, a one-comp move that can be noise.
- **Together** (either Static Discharge plus dive play and the half cooldown):
  - Umbra 44.7–44.8% (+2.4 to +2.5).
  - Voltaic back where it started, 44.4% (+0.2): Static Discharge cancels the small lift a diving Umbra gives it.
  - Terra 70.8% → 68.6%, and the spread between comps 20.1 → 19.2 points.
  - It doesn't relocate the gap: Umbra enters the top 6 once (alongside Terra), and Voltaic's bottom-6 count goes 5 → 4. Single-comp moves like these can be noise (see Caveats).
- **In the sim, Umbra can't blink out mid-dive.**
  - The dive-in spends Shadow Step, and even halved (5 s), its cooldown outlasts the bot's 4 s dive. So Umbra starts walking back out, and can blink again only once the step returns, about 1 s after the dive.
  - A player who stays in for 5 s or more could blink out under the halved cooldown; that wasn't tested.
- **The gap isn't about Voltaic and Umbra surviving on their own.** In every run, every bottom-6 comp has neither Terra nor Pyro, and every top-6 comp has Terra. The weak comps lack the team's protection and its damage; an escape tool fixes neither.

## Setup

- **Base:** team package v3 on today's live values (`SPELLSHOT_TEAM_MODE_PACKAGES.md`).
- **Test:** the 84-comp round-robin (3,486 pairings), no jump, lowest-HP focus, "cover each other's back" teamwork on, 6 rounds per pairing.
- **Noise:** the baseline was run twice on different seeds. Each Element moved by at most 0.5 points, and single comps by about ±2.3 points (one SD; largest 7.8).
- **Controls:** each change is measured against a matching control.
  - The Umbra Shadow Step options are measured against a run with the same "blink out when under fire" trigger and no new mechanic.
  - Dive play with the half cooldown is measured against dive play with that trigger. (The first draft compared it with dive play alone, which mixed the trigger into the half cooldown's effect; the fact-check caught this.)

### How each option was modelled

| Option | In the sim |
|---|---|
| Static Discharge, reactive | Fires by itself once a life, the first time Voltaic drops below 30% HP. Enemies within 8 studs are knocked back 10 studs and are airborne for 0.3 s (no moving or dodging). Voltaic then runs away at 150% speed for 0.5 s, and below 40% HP keeps retreating for 2 more seconds. It keeps firing while it runs. No damage, heal or shield. |
| Static Discharge, manual | The same pulse, on a 12 s cooldown with no mana cost (the spec gives none). The bot uses it when an enemy is within 8 studs and Voltaic is under fire or below 50% HP, or just for the speed burst when it's under fire below 40%. |
| Static Discharge, oversized (dose test) | Manual, radius 10, push 16, 200% speed for 1.5 s, 8 s cooldown. The bot still triggers it at an enemy within 8 studs. |
| Vanish, 0.3 s | For 0.3 s after each Shadow Step, Umbra can't be targeted, takes no direct hits, and dodges every telegraphed attack. Damage over time and ground zones (Blizzard's slow, Deep Freeze's root, Toxin clouds) still apply. The bot may also step out when under fire below 60% HP. |
| Vanish, 1.0 s (dose test) | The same, for 1.0 s. |
| Half cooldown | Shadow Step's cooldown is halved, 10 → 5 s, when it's cast within 2 s after Umbra lands a hit, or when one of Umbra's Darts lands within 2 s after casting. Same under-fire trigger as the vanish runs. |
| Dive play (behaviour, not a stat) | When no enemy is within 30 studs and Umbra has 40 mana, it blinks 22 studs in on a target below 60% HP and fights at 18–40 studs for 4 s (a length I chose). It then walks back out to its 70–110 range, because Shadow Step is still on cooldown from the dive-in; it can blink out again once the step returns. Without dive play, the sim's Umbra kites at 70–110 studs and only blinks to escape. |

{{TABLES}}

## Why the escape tools don't work here

- **Voltaic isn't dying for want of an exit.** Three attackers focus it from range, so a 10-stud shove and a short sprint don't take it out of anyone's reach. The retreat does take it out of its own Chain Bolt range, so its damage drops from 25.6 to 24.6 per second (reactive) or 24.4 (manual), and 23.0 with the oversized version, while its death rate edges up from 71% to 72%.
- **Umbra dies to ranged focus, not to divers.** It fights from 70–110 studs, so enemies rarely close on it (0.17 blink-outs a round), yet it still dies in 65% of rounds. A vanish window covers about a quarter of a second a round (about 0.8 s for the 1.0 s version), so its death rate only moves from 64% to 63% or 62%. Without dive play, the half cooldown adds only ~0.1 Shadow Steps a round and doesn't move the win rate.
- **The worst comps lack both protection and damage.** Every bottom-6 comp has neither Terra nor Pyro, and every top-6 comp has Terra, in every run. That's the same Terra problem as in the packages report.

## Suggestions from this test

1. **Don't ship Static Discharge for team mode.** No version helped. **Confidence: medium-high:** tested at three strengths, all at or below zero.
2. **For Umbra, reward diving rather than adding a defensive Shadow Step.** The half cooldown after a hit is worth +0.9 on top of dive play, most likely because Umbra can dive more often. The vanish isn't needed. **Confidence: medium:** small, but above noise.
3. **If you want a real dive-and-exit for Umbra, the exit needs its own charge.** For example, a second Shadow Step charge, or a free return blink within ~3 s of the dive-in. With one 10 s cooldown, halved or not, the exit isn't ready within a short dive like the bot's 4 s. This is untested.
4. **For Voltaic, look at its damage and reach rather than escape,** within its Offence role. For example, more Chain Bolt range, or damage that rewards staying in. This is untested.
5. **The bigger lever is still the Terra gap.** Next in line is the second-protector test (Twin Tide's walls also blocking shots), which the P27 spec calls a separate question worth testing.

## Caveats

- **These are bot fights on an open floor,** with rules for aim, dodging and teamwork, not measured from players.
- **Dive play is a bot behaviour I added** to test the spec's idea. The sim's default Umbra doesn't dive.
- **6 rounds per pairing.** Between two identical runs, an Element's win rate moves by up to 0.5 points and a single comp's by about ±2.3 (one SD), so a one-comp change in the bottom-6 or top-6 counts can be noise.
