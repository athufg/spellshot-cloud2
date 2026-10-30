# Changes 2026-10-18: Umbra's Shadow Step, handoff #8

The owner chose "same key, second charge". This change builds two things.

- **(a) The dive reward.** It works exactly as the 3v3 sim's P27 "half cooldown" modelled it.
- **(b) The escape blink.** It is a second charge on the same key, with its own independent cooldown.

All edits are live in the Team Create place. Nothing was saved, published or Play-tested. New code is marked `(2026-10-18, umbra)`. Where a line was replaced, the old line is kept in a `--[[... until 2026-10-18]]` note.

Backups of every edited script, as they were before this change: `ServerStorage.UmbraSuperseded_2026_10_18`. Each backup is disabled and carries an `OriginalPath` attribute.

## Behaviour

**Dive reward.** Shadow Step's 10 s cooldown becomes 5 s in either of two cases:
- **(a) A hit before the cast.** Shadow Step is cast within 2 s after Umbra landed a hit on an enemy. The cooldown is stamped as 5 s at the cast, and `CDTotal_Primary` is set to 5, so the slot's sweep runs from full.
- **(b) A hit after the cast.** Umbra lands a hit within 2 s after casting Shadow Step. The running cooldown is cut to end at the cast time + 5 s. This happens once per cast. `CDTotal_` is left alone, so the sweep jumps forward the way Ember Refund's does.

These rules hold in both cases:
- The cooldown never goes below 5 s, because both cases anchor on the same cast time.
- The reward applies to the normal Shadow Step only.
- A "hit" is any of the Umbra player's damage that lands (`Core.OnHitLanded`), including a hit a shield soaked.
- These do not count: burn/DoT ticks, a Bulwark Wall, a Decoy, and Umbra's own body.
- A training dummy counts.

**Escape blink.** This is a second, independent charge on the Primary key.
- **Main cooldown running, escape ready:** the press is the same aimed 22-stud blink. It uses the same `stepDestination` rules, the same VFX, the same 0.6 s veil and the same 20 mana, and it gives the same small Ultimate charge. It starts only the escape's own cooldown (6 s).
- **Both ready:** the press is the normal Shadow Step and starts the normal cooldown.
- **Independent:** the two cooldowns never touch each other, and the escape never earns the dive reward.
- **Server-authoritative:** SpellshotService decides which charge a press uses and tells UmbraHandler through `payload.Escape`. It sets this field on every generic cast, so a client's own `Escape` field is always overwritten.
- **Refunds:** if the escape is given back (nowhere to step, or a third press inside the dissolve), the escape's own charge and the mana come back. The main cooldown keeps running.
- **Double-tap queue** (review fix, see below; was a refusal): a press that arrives while a step is still dissolving (0.12 s) is queued and steps from the new spot when the first re-forms, so two charges buy two blinks. Only one press waits; a further press in that window is given back whole. The second step never replaces the first step's record, so the old double spend stays fixed.

## Script by script

### ReplicatedStorage.IceMagic.UmbraTuning
New fields in `T.ShadowStep`:
- `DiveWindow = 2` (seconds)
- `DiveCooldown = 5`
- `EscapeCooldown = 6`

### ReplicatedStorage.IceMagic.VFXLibrary
One line in the ShadowStep row: `EscapeCooldown = UMBRA.ShadowStep.EscapeCooldown`. Any row with an `EscapeCooldown` above 0 gets an escape charge, generically. Only this row has one.

### ServerScriptService.SpellshotService
- **Header:** documents the new `CDEscape_<role>` / `CDEscapeTotal_<role>` attributes (server time).
- **Generic cast path:** the cooldown gate now allows the escape. When `CD_` is running, the row's `EscapeCooldown > 0` and `CDEscape_` is ready, the press is the escape: `escape = true`, and it stamps `CDEscape_` / `CDEscapeTotal_` instead of `CD_` / `CDTotal_`. `payload.Escape = escape or nil`. The old single-line gate is kept in a note.
- **`GiveBack`:** takes an optional 4th argument, `escape`. When it is true, it clears `CDEscape_<role>` instead of `CD_<role>`. The mana and Ultimate give-back are unchanged.
- **Dev `ClearCooldowns` and a new life's reset:** both also set `CDEscape_<role> = 0`.

### ServerScriptService.UmbraHandler
- **Header:** the PRIMARY entry notes the dive reward, the escape and the double-tap guard.
- **New state:** `dives[player] = { Character, HitAt, StepAt, StepRole, StepCut }`. It is cleared in `endAll` (death, leave, `Core.OnClear`).
- **New dive-reward block,** just above `castShadowStep`:
  - `diveOn()` is the switch.
  - `diveCut()` cuts `CD_<role>` to the cast time + `DiveCooldown`, writing it the way Ember Refund does.
  - `diveOnCast()` handles case (a).
  - A `Core.OnHitLanded` listener handles case (b) and records hit times.
- **`castShadowStep`:**
  - reads `payload.Escape`;
  - queues a press while a step is dissolving, and gives back a third (`giveBack` with the escape flag; review fix);
  - passes the escape flag on the "nowhere to step" give-back (old call kept in a note);
  - calls `diveOnCast` for normal casts only;
  - adds `Escape` to the `ShadowStepOut` broadcast. No client reads it yet; it is there for a future distinct look.

### StarterPlayer.StarterPlayerScripts.SpellshotInput
`canCast`'s cooldown gate: while `CD_<role>` runs, the press still goes through if the slot's row has `EscapeCooldown > 0` and `CDEscape_<role>` is ready. Touch buttons reach `tryCast` through TouchBus, so touch follows the same path. The old line is kept in a note. No other line was changed.

### StarterGui.PopArtHUD
The Primary slot's escape chip:
- **Placement:** an 18x18 hard-edged ink square over the slot's bottom-left corner, mirroring the charge badge on the bottom right.
- **Recharging:** paper (white) fills it from the bottom.
- **Ready:** solid gold, the colour READY! uses.
- **When it shows:** only while the slot's row has an `EscapeCooldown`, which is looked up in `applyLoadout` via a guarded `VFXLibrary` require and `AbilityFor`.
- **Clock:** it reads `CDEscape_` / `CDEscapeTotal_` against server time.

The main veil, countdown and glyph dim are unchanged, so the glyph still dims while the main cooldown runs even when the escape is lit.

### ReplicatedStorage.IceMagic.UmbraClient
Not changed. Nothing in the Umbra client gates the press: `UmbraAnim.LocalCast.ShadowStep` only plays the arms. A refused step already recovers through its `GiveUpAt` hold.

## Tuning knobs (UmbraTuning.ShadowStep)

| Knob | Value | Effect |
|---|---|---|
| `DiveWindow` | 2 | seconds either side of a cast in which a landed hit earns the reward |
| `DiveCooldown` | 5 | the rewarded cooldown. Setting it to `Cooldown` (10) or higher, or setting `DiveWindow` to 0, turns the reward off |
| `EscapeCooldown` | 6 | the escape charge's own cooldown. 0 disables the escape: the key behaves exactly as before, and the HUD chip hides |

## Switching off / reverting

- **Dive reward off:** set `UmbraTuning.ShadowStep.DiveCooldown = 10`.
- **Escape off:** set `UmbraTuning.ShadowStep.EscapeCooldown = 0`.
- **Full revert:** copy each script's Source back from `ServerStorage.UmbraSuperseded_2026_10_18.<Name>`; `OriginalPath` names its home. The scripts are UmbraTuning, UmbraHandler, SpellshotService, SpellshotInput, PopArtHUD and VFXLibrary.
  - **Warning for VFXLibrary:** it is shared with other units' work, so do not paste its whole backup over it. Delete the one `EscapeCooldown = ...` line from the ShadowStep row instead.
  - **SpellshotService:** other units may also have edited it since. Revert only the `(2026-10-18, umbra)` lines, using the `until 2026-10-18` notes.

## Checked

- Every edited script parses. Scripts were checked as a wrapped temporary ModuleScript; UmbraTuning by requiring a Clone, which returned `DiveWindow 2`, `DiveCooldown 5` and `EscapeCooldown 6`.
- VFXLibrary is longer than the 200k Source limit, so it could not take the wrapper check. Its Clone requires without error. In the command bar the row read `EscapeCooldown nil`, but only because the command bar's require cache still holds the pre-edit UmbraTuning; the source line itself is correct. A Play session loads the fresh module.

## Untested (needs the orchestrator's Play test)

Nothing was run in Play.

**Escape blink**
- With the main cooldown running and the escape ready, does F (and the touch button) blink, and does the HUD chip turn from gold to filling?
- Does the main slot countdown keep running, untouched?
- With both ready, does the first press start only the 10 s, leaving the chip gold?
- Does a third press, with both on cooldown, flash the slot as refused and spend nothing?
- Escape given back (aim at a wall at point blank, nowhere to step): do the mana and the escape chip come back while the main cooldown keeps running?
- Double-tap F within the dissolve, both charges ready: TWO blinks, about 0.24 s apart, the second from where the first landed, in the same aimed direction? Main slot on its 10 s, escape chip filling, 40 mana spent. A triple tap: still two blinks, the third press refunded.

**Dive reward**
- Land a Shadow Dart on a dummy, then Shadow Step within 2 s: does the slot run 5 s (CDTotal 5)?
- Shadow Step, then land a dart within 2 s: does the countdown jump to end 5 s after the cast?
- Is it once per cast, never below 5?
- After an escape cast, is there no reward?

**HUD**
- Placement of the chip against the slot plate at small HUD scales, and its look against the house kit.
- No owner sign-off yet on the gold/paper chip.

**Not covered**
- No multi-client latency test. The client gate lets an escape press through on a replicated-late `CDEscape_`; the server stays authoritative.

## Review fixes

**1. A quick second press during the dissolve was refunded, not blinked** (low; `ServerScriptService.UmbraHandler`, `castShadowStep` and `endAll`). A double tap 80-110 ms apart with both charges ready gave one blink. SpellshotService had already charged the second press as the escape, then the busy guard gave it back. The arms played a second step clip with no movement, and the player had to press a third time. The spec says a press while the main cooldown runs and the escape is ready is the same blink. Fixed with the verifier's corrected fix:
- **Queue, not refund.** The busy guard stores the press as `busy.Queued = { Payload, Role, Escape }` and returns, spending nothing more. A press while one is already queued is still given back whole. The old refusal is kept in an `until 2026-10-18` note.
- **The record is kept by identity.** `castShadowStep` keeps its own `rec`. The dissolve callback checks `steps[player] == rec` instead of `s.Character == character`, and takes `rec.Queued` before any early return. This also fixes an older edge: a stale callback from the same body but an older Epoch could clear a newer step's record, so that step never re-formed.
- **The queued press steps after the re-form.** It runs after `PivotTo`, the velocity zeroing and the `ShadowStepIn` broadcast, through `pcall(castShadowStep, ...)`, because the delay is outside performCast's pcall. On an error it calls `warnOnce` and gives back. It sets its own `VeiledUntil`, broadcasts its own `ShadowStepOut` from the new spot, and earns the dive reward only if it is a normal cast. If there is nowhere to go, it gives back its own charge through the escape-aware path.
- **Aim moves with the body** (beyond the verifier's text). The queued press's `Target` is shifted by the first step's displacement, so it keeps the direction and reach it was aimed with. Without this, a point aimed 15 studs ahead would be almost underfoot after the first blink, and `stepDestination` would swing toward it at full distance in an arbitrary flat direction.
- **No paid press vanishes.** The queued press is given back if the dissolve callback returns early: record cleared or replaced, Epoch changed, body dead or gone. `endAll` (death, leave, `Core.OnClear`) gives back any queued press before it clears `steps[player]`.
- **No other script changed.** No client change was needed: the second arm clip now matches a real second step. Header and `steps` comments updated. The playtest line under Untested and the Behaviour bullet above now expect two blinks.
- **Backup:** `ServerStorage.UmbraReviewFix_2026_10_18.UmbraHandler`, the post-build, pre-fix source (disabled, `OriginalPath` set). The pre-build original stays in `UmbraSuperseded_2026_10_18`.
- **Checked:** UmbraHandler parses (wrapped temporary ModuleScript, 996 lines). Not Play-tested.
