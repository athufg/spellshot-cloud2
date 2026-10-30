# Movement switch for team mode (2026-10-18)

The owner's decision on 2026-10-18 was: "switch only, keep full, but keep jumping by default, one jump only".

This adds a movement switch with two modes:

- **Full** is the default. It is the game as it was before, untouched.
- **RunningOnly** is for team fights. It keeps walking, sprinting, crouching and **one** ordinary ground jump. It removes these moves:
  - the slide (the crouch/slide key only crouches);
  - the slide-jump;
  - the wall run;
  - the wall jump;
  - the double jump (air jumps).

Walk speed (16), sprint speed (25) and crouch speed (8) are the same in both modes. Kit mobility is also unchanged: Shadow Step, Skyrider, Bulwark Charge, Cross-Slash, Overcharge, Position Trade, Gust Pad, Frost Slide and the rest. None of those live in MovementController.

All of this was edited in Studio's Edit datamodel on the Team Create place. It replicates live. Nothing was saved, published or Play-tested.

## Where the mode comes from

1. The **workspace attribute `MovementMode`** is read first, if it holds `"Full"` or `"RunningOnly"`. A dev sets it live through the dev panel, because Config edits made from the command bar during Play never reach the game.
2. Otherwise **`Config.Movement.Mode`** is used. It is `"Full"` by default.
3. Anything else counts as `"Full"`.

Clients read the attribute live through `GetAttributeChangedSignal`, so a switch mid-match takes effect within one frame.

## Script by script

### ReplicatedStorage.Spellshot.SpellshotConfig (only the Config.Movement block)
These two keys were added at the end of `Config.Movement`, with a dated comment:
- `Mode = "Full"`: the default mode.
- `RunningOnlyTouchCrouch = true`: in RunningOnly, the touch SLIDE / CROUCH button stays and works as a crouch-only button. Set it to `false` to hide the button in RunningOnly.

No existing value changed.

### StarterPlayer.StarterPlayerScripts.MovementController
Each mechanic is gated at its entry point. The mechanics themselves were not rewritten. Every gate is marked `(2026-10-18, movement switch)`.
- **Header:** a new "MOVEMENT MODE" paragraph.
- **After `local MOVE = Config.Movement`:**
  - `readMovementMode()` reads the attribute, then Config, and caches the result in `movementMode`.
  - It is connected to `workspace:GetAttributeChangedSignal("MovementMode")`.
  - `runningOnly()` is the cached check, so the per-frame calls cost nothing.
- **`slideRefusal()`:** returns `"No"` first in RunningOnly. This one gate covers three cases:
  - A crouch-key press while moving falls through to the ordinary crouch.
  - `startSlide()` is refused, because it asks `slideRefusal`.
  - An armed slide (one pressed in the air) gives up and becomes the crouch it would have been, because the refusal is no longer `"Wait"`.
- **`watchJumps` StateChanged:** a Jumping state during a slide is not turned into a slide-jump in RunningOnly. This is belt and braces, because a slide cannot exist in RunningOnly past one frame.
- **`tryWallRun()`:** returns at once in RunningOnly (no wall to catch).
- **`stepWallRun()`:** RunningOnly is one more end condition. A wall run in progress when the switch lands ends through `endWallRun`, exactly as running out of time does: it sets `lastWall`, restores the stance's WalkSpeed and lets the Radiant float hold go.
- **`onJumpPress()`:** the wall-jump branch and the double-jump branch both require `not runningOnly()`. The ground-jump branch is unchanged: `jumpWanted` and the dropped-jump rescue still back up the one normal jump.
- **Slide impulse Heartbeat:** a slide in progress when the switch lands ends through `endSlide()`. It also **spends the crouch key** (`held.Crouch = false`), the same way a slide that leaves the ground does. You go back to the run instead of dropping from about 34 studs/s into an 8 studs/s crawl. A crouch takes a fresh press. With Toggle Crouch, `endSlide` already gives the press back.
- **Left alone on purpose:**
  - A slide-jump leap or a wall jump's push that is **already in flight** when the switch lands finishes normally. The leap ends on landing plus 0.35 s; the push lasts 0.2 s. Neither can start again.
  - The "speed is kept in the air" keeper, the camera bank and dip, and the viewmodel feed are unchanged. They follow `slide` and `wallRun`, which simply stay nil.

### StarterPlayer.StarterPlayerScripts.TouchControls
- It now requires `SpellshotConfig`.
- In `sync()`, which runs every 0.1 s and on the Zone and menu attributes: the SLIDE / CROUCH button hides only when the mode is RunningOnly **and** `Config.Movement.RunningOnlyTouchCrouch == false`.
  - Before hiding, any finger holding the button is released through `release()`. That sends TouchBus "Crouch" up, so no crouch is left held down.
  - With the default (`true`) the button stays and only crouches, because MovementController refuses the slide.

### StarterPlayer.StarterPlayerScripts.DevPanel
- A new section, **"MOVEMENT (team mode switch: every player on this server)"**, sits between MATCH STATE and SCENARIOS.
- It holds a two-button row: **MOVEMENT: FULL** and **MOVEMENT: RUNNING ONLY**.
  - Each button fires `MovementModeRequest` with `"Full"` or `"RunningOnly"`.
  - The row paints from the live attribute, falling back to Config: the active mode gets the `BtnOn` colour and a `*`.
  - A `"denied"` answer from the server is shown in the panel's status line.

### NEW ServerScriptService.MovementModeServer (Script)
- It listens on `MovementModeRequest`.
- Non-devs are refused using `Config.IsDev(player)` on the server, and get `FireClient(player, "denied", IsStudio)`.
- Only the strings `"Full"` and `"RunningOnly"` are accepted.
- An accepted request runs `workspace:SetAttribute("MovementMode", mode)` and prints one line.
- Nothing is set at startup. Clients fall back to Config, so a MovementMode attribute set on Workspace in Studio's Properties before Play is kept.

### NEW ReplicatedStorage.Spellshot.MovementModeRequest (RemoteEvent)

## Tuning knobs
| Knob | Where | Default | Effect |
|---|---|---|---|
| `Config.Movement.Mode` | SpellshotConfig | `"Full"` | The mode when no attribute is set. Set it to `"RunningOnly"` to make team mode the default. |
| `workspace` attribute `MovementMode` | Live, server-set | (unset) | Overrides Config for everyone on the server. Set it from the dev panel, or from the server command bar during Play. |
| `Config.Movement.RunningOnlyTouchCrouch` | SpellshotConfig | `true` | `false` hides the touch SLIDE / CROUCH button in RunningOnly. |

All other movement numbers (AirJumps, SlideJumpBoost, WallRunSpeed and so on) are unchanged. They only apply in Full.

## How to switch it off or revert
- **Back to the old game right now:** press MOVEMENT: FULL in the dev panel, or run `workspace:SetAttribute("MovementMode", nil)` on the server. With `Mode = "Full"`, the game behaves exactly as it did before.
- **Remove the dev control:** disable `ServerScriptService.MovementModeServer`. The panel row then does nothing and the game stays on `Config.Movement.Mode`.
- **Full revert:** clean copies of the four edited scripts are in **`ServerStorage.MovementSwitchSuperseded_2026_10_18`**: SpellshotConfig, MovementController, TouchControls and DevPanel. Each has an `OriginalPath` attribute, is disabled, and has its children stripped.
  1. Copy each backup's Source back over the live script.
  2. Delete `ServerScriptService.MovementModeServer` and `ReplicatedStorage.Spellshot.MovementModeRequest`.

  **Careful with SpellshotConfig:** other agents edit other parts of it. Restore only the `Config.Movement` block (remove the `Mode` and `RunningOnlyTouchCrouch` lines). Do not paste the whole backup.

## Untested (nothing was Play-tested; the orchestrator Play-tests)
All five scripts were only parse-checked: wrapped in a function and required, and Config was required from a clone. These behaviours still need a Play test:
- A RunningOnly toggle mid-slide, mid-wall-run, mid-leap and mid-double-jump: no stuck crouch, no stuck WalkSpeed, no stuck camera bank.
- The crouch key while moving gives a crouch (8 studs/s), not a slide, on keyboard, gamepad and touch.
- Only one jump: Space in the air does nothing, and running along a wall does not catch it.
- Hold-to-crouch versus Toggle Crouch when the switch lands mid-slide.
- The dev panel row in a Studio test and on a Team Test server (where `Config.IsDev` needs `AllowInLiveGame`), including the "denied" path for a non-dev.
- A touch device, or `TouchControlsPreview`, with `RunningOnlyTouchCrouch = false`.

## Known gaps (scripts outside this unit)
- **Server-side enforcement:** `SpellshotService` still accepts a `"Slide"` or `"SlideJump"` MoveRequest in RunningOnly. An honest client never sends one, but an exploiter could. Wall run and double jump were always client-only, as the existing AUTHORITY note says. Closing this needs a one-line check in SpellshotService's MoveRequest handler (not in this unit).
- **Settings label:** SettingsMenu still labels the bind "Slide". In RunningOnly that key only crouches.
- **Map ShojiBreak:** `Workspace.Map_SakuraRow.ShojiBreak` mentions WallRun. It reads the movement but does not drive it, so there is nothing to gate. It was not checked further.

## Review fixes
Two review findings were fixed on 2026-10-18. Clean copies of the three scripts as they were before these fixes (after the movement switch build) are in **`ServerStorage.MovementSwitchReviewFix_2026_10_18`**: SpellshotConfig, MovementController and TouchControls. Each one is disabled, has its children stripped, and carries an `OriginalPath`. The pre-build copies in `MovementSwitchSuperseded_2026_10_18` were not changed. All three scripts were parse-checked: the two LocalScripts were wrapped in a function and required, and Config was required from a clone, which reads `RunningOnlyTouchCrouch = false`. Nothing was Play-tested.

1. **Hiding the touch SLIDE / CROUCH button left a Toggle Crouch latch stuck.** A touch player with Toggle Crouch on who tapped into a crouch had no finger left on the button. When RunningOnly then hid the button, the release loop found nothing to let go, so the player stayed at crouch speed until they respawned.
   - `TouchControls.sync()`: on the hide edge, after the release loop, it now sends `TouchBus.Fire("CrouchClear", true)`, but only while `layerOn`, meaning touch is how the player is playing.
   - `MovementController`'s TouchBus listener has a new `"CrouchClear"` branch. If `held.Crouch` is set, no slide is running and Toggle Crouch is on, it clears `held.Crouch` and `slideArmed`, stamps `crouchLeftAt`, and calls `refreshState()`. That is the same toggle-off path a second press takes. A hold-to-crouch is left to the input holding it. A slide is left to the slide Heartbeat, whose RunningOnly branch already ends the slide and clears the flag.
   - `SpellshotInput` ignores the new action, because it only takes M1 and the role actions. `TouchBus.Down.CrouchClear` stays set after the first send; nothing reads it.
2. **The touch SLIDE / CROUCH button stayed visible in RunningOnly, against the brief.** `Config.Movement.RunningOnlyTouchCrouch` now defaults to `false` (marked `--[[true until 2026-10-18]]`), so RunningOnly hides the button as the brief asks. Fix 1 made this default safe. This supersedes the `true` default in the Tuning knobs table above. To give touch players back a crouch-only button in RunningOnly, set it to `true`. With `Mode = "Full"` (the live default), nothing changes until a dev switches to RunningOnly.

Still to Play-test: on a touch device or `TouchControlsPreview`, turn Toggle Crouch on, tap into a crouch in Full, then press MOVEMENT: RUNNING ONLY. The button should hide and the player should stand up at run speed. Then do the same with hold-to-crouch while a finger is on the button.
