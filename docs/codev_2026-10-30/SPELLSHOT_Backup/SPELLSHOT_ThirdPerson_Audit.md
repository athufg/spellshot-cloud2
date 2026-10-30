# SPELLSHOT — third-person coverage audit + V-key toggle (Build Prompt #31)

*2026-09-21.*

**What this was read from.** Roblox Studio was closed for this pass, so the audit was run against a
reconstructed snapshot of the live place: the 2026-09-17 full place export (52 scripts) with the
2026-09-17/18 patch rounds r3-r6 overlaid on top, 50 files, at
`%TEMP%\vmarm\tp_audit\src`. That matches the live place closely but is not the live place.
Two things follow from that and are called out again where they matter: **TerraFX is missing from
the snapshot** (it was added to the place after the export, so it probably exists live - but it has
to be checked), and every anchor in the patch below has to be re-matched against live text before
anything is written.

**The referenced prompt documents** - `Opus5_Pyro_FullKit_Blender.md`,
`Opus5_Pyro_Animation_Direction.md`, `Opus5_Zephyr_M1Dash_Fix.md`, `Opus5_RoundLoop.md`,
`Opus5_FlashFreeze_CrystalFix.md` - are not on this machine; a search of OneDrive, Documents,
Downloads and Desktop finds none of them. The audit was done against the code itself instead, which
is the more authoritative source anyway.

**Part 1 (the V toggle) is built and compiling**, patched into five scripts, not yet pushed to
Studio. See the end of this document.

**Part 2 was audited, not built** - which is what the prompt asked for at this stage. The finding
that matters: third-person coverage is far better than the prompt assumed. Pyro, Cryo and Zephyr all
have real third-person body clips today.

---

# SPELLSHOT third-person animation — merged audit

Verified against `C:\Users\work\AppData\Local\Temp\vmarm\tp_audit\src` (50 files). Every claim below that came from a single auditor and carries weight was re-checked by me at the source line; contradictions between auditors are resolved with the line, not averaged.

---

## 1. Headline

**Not "there is no third-person animation layer" — there is a substantial one. The headline is that a single missing module, required at top level in two LocalScripts, would disable the entire thing plus all player input, and it is sitting in the snapshot right now.**

`ReplicatedStorage.IceMagic.TerraFX` **does not exist in this export**, and it is required without a timeout at module scope in two places:

- `SpellshotInput.client.lua:51` — `local TerraFX = require(iceFolder:WaitForChild("TerraFX"))`, a top-level hard require. If it never resolves, SpellshotInput never reaches its bind table and **no ability, M1 or Technique is castable by anybody, in any Element**.
- `AbilityFX.client.lua:592-596` — a top-level `do ... end` block doing `require(iceFolder:WaitForChild("TerraFX")); TF.WatchBedrock()`. The script's `remote.OnClientEvent:Connect` is at **`AbilityFX.client.lua:628`, after that block**. Every `CastPose.Play` call in the game (23 of them, `AbilityFX.client.lua:69`–`:535`) lives in handlers behind that connect. So a missing TerraFX silently kills **all third-person cast animation for Pyro, Cryo and Zephyr too**.

I verified this mechanically: extracting every `WaitForChild("X")` require name across all 50 files and diffing against the file list, **TerraFX is the only required module with no file**. Every other Terra require uses the defensive lazy pattern `TerraFX = TerraFX or require(...)` (`AbilityFX.client.lua:571, 603, 610, 619`) — the Bedrock block at `:592` is the one eager exception, and it is the one that does the damage.

**Caveat, stated plainly:** this is a reconstructed snapshot. TerraFX may exist in the live place and simply have been missed by the export. But it is the first thing to check when Studio opens, before any build decision, because if it is genuinely absent the game does not function at all — and that would explain symptoms that look nothing like an animation problem.

**Second-order headline, once that is cleared:** the third-person layer covers the ground completely and the air not at all. CastPose has four stances plus a Heat Rush blend (`CastPose.lua:187-206`) and 31 clips. It has **zero** jump, fall, land, climb or swim poses — grep for `jump|fall|freefall|climb|swim|landed|StateChanged|FloorMaterial` across `CastPose.lua` returns only the Gust Jump *ability* clips and unrelated prose. And the stride gate is `moving = (v.X * v.X + v.Z * v.Z) > 4` (`CastPose.lua:805`) with no ground test, so **every airborne player with forward speed keeps running in mid-air at full stride**, and one falling straight down freezes. That is not a missing feature, it is a visible bug on every jump in the game, and it is a ~1-line fix.

---

## 2. Merged coverage table

`1P` = Viewmodel (arms, local only). `3P` = CastPose (real body, everyone else). "none" means nothing exists, not "thin".

### Cryo

| Ability / move | 1P | 3P | Cov | Gap |
|---|---|---|---|---|
| Icicle Shard (M1) | `Viewmodel.lua:686` | `CastPose.lua:233` / `:242` | partial | **No `StanceLegs`, no Hip/Knee keys** (`CastPose.lua:233-250`). Per `CastPose.lua:946` + the `elseif LEG[ch] or clip.Both` branch at `:966`, both legs are driven to 0 for 0.12→0.453 s. At FireInterval 0.333 s the legs never recover while firing. **Cryo is the only kit with no `StanceLegs` anywhere** (grep: all 13 hits are Pyro/Zephyr). |
| Flash Freeze (Primary) | `Viewmodel.lua:477`, `sym()` = two fists | `CastPose.lua:253` | partial | **No `Both`** → per `CastPose.lua:968` (`else target[off][ch] = rest[off][ch]`) the left arm stays on the stance. 1P slams two-fisted, 3P slams one-armed. Also Hip keyed, Knee never → straight knees through the slam. Elbow −20/−8/−6 against the positive-is-flexion convention at `CastPose.lua:79`. Timing is **fine**: 0.38 at `CastPose.lua:257` = `Viewmodel.lua:478` = `VFXLibrary.lua:110` = `FlashFreezeData.lua:10`. |
| Frost Slide (Mobility) | `Viewmodel.lua:493` | `CastPose.lua:271` (`Both`, `Repeat`, Hip/Knee keyed) | full | — |
| Chill Aura (Defense) | `Viewmodel.lua:503` | `CastPose.lua:283` | partial | Knee never keyed → locked straight knees while pressing down. Elbow −46/−42 on **both** arms (`Both=true` copies at `:967`). |
| Cryo Beam — windup | `Viewmodel.lua:517` | `CastPose.lua:299` | full | The one clip re-authored against the documented signs; every key carries float legs deliberately (`CastPose.lua:294-298`). |
| Cryo Beam — channel | `Viewmodel.lua:534` | `CastPose.lua:315` | partial | Arm is **fixed forward, does not follow aim** (stated at `CastPose.lua:314`) while the beam steers freely, AND the body cannot compensate: `AbilityHandler.server.lua:538` sets the AlignOrientation CFrame **once** and never updates it, yaw-pinning the caster for the full 4.15 s. |
| Cryo Beam — origin | viewmodel fingertip | real RightHand, `VFXLibrary.lua:2917-2920` | full (today) | Branch is **per-viewer** (`ctx.FP = h.IsLocal and LocalMuzzle ~= nil`, `VFXLibrary.lua:2900`), so remote beams are already correct. **But see §3** — that same gate breaks under a V-toggle. |
| Frozen victim | none | **none** | none | No `Frozen` stance; `STANCE_FOR_STATE` (`CastPose.lua:210-212`) is only None/Sprint/Crouch/Slide, unknown falls to Ready. A rooted player stands inside the ice in the neutral ready pose. |
| Cold Momentum | n/a | driven *by* CastPose, `AbilityFX.client.lua:157` → `CastPose.GetCycle` | full | Lays footfall marks on a stride whose legs the Icicle Shard bug is holding straight. |

### Pyro — the best-covered kit

| Ability | 1P | 3P | Cov | Gap |
|---|---|---|---|---|
| Fireball (M1) | `Viewmodel.lua:760` | `CastPose.lua:334` (R), `:435` (L mirror), `StanceLegs` | full | — |
| Fireball over shield | `Viewmodel.lua:789` | `CastPose.lua:646` | full | 3P has a variant 1P also has; asymmetry runs both ways in this kit. |
| Fireball charge on fist | `PyroFX.lua:439` (viewmodel arm) | `PyroFX.lua:442` (real hand) | partial | `ownView` is a **hardcoded literal** — `true` at `SpellshotInput.client.lua:897`, `false` at `AbilityFX.client.lua:207` — although `PyroFX.firstPerson()` (`PyroFX.lua:301-303`) exists right there. |
| Immolate (Primary) | `Viewmodel.lua:548` | `CastPose.lua:347` | full | — |
| Heat Rush (held) | blend at `Viewmodel.lua:1531` | **a live blended stance**, `CastPose.lua:202-206` + `heatStance` `:769-778` | full | Not a HUD meter: six channels, four stride amplitudes and cadence lerp by the replicated `Heat`. Gating is asymmetric — 3P applies it whenever the attribute is set (`CastPose.lua:1054-1060`), 1P requires Sprint (`Viewmodel.lua:1531`). |
| Heat Rush exhale | `Viewmodel.lua:559` | `CastPose.lua:358` | full | — |
| Cinder Shield cast/hold | `Viewmodel.lua:570` | `CastPose.lua:371` + `SetBase` at `AbilityFX.client.lua:489` | full | The most elaborate body clip in the file. |
| Cinder Shield burst | `Viewmodel.lua:577` | `CastPose.lua:386` | partial | Haze origin prefers `ctl.Centre` (`PyroFX.lua:1046`) which the FP branch wrote at `:1000` — caster's haze starts at the camera, everyone else's at the hand. Latent today. |
| Ring of Fire — trace | `Viewmodel.lua:1151` | **live IK-ish solve**, `aimPose` `CastPose.lua:858-877` | full | The arm genuinely conducts the circle as drawn, fed per-frame from `AbilityFX.client.lua:519-521`. |
| Ring of Fire — settle | `Viewmodel.lua:588` | `CastPose.lua:397` | full | — |
| Ring of Fire — point | `Viewmodel.lua:800` | `CastPose.lua:408` | partial | Angles are **baked for a circle 13 studs ahead** (`CastPose.lua:406-407`) but range is up to 60 (`VFXLibrary.lua:247`). At other ranges the body points at nothing. `aimPose` already solves this problem for the trace. |
| Ember Refund / Deflect | none | none (VFX only, body-anchored) | full | Matches 1P exactly, by design. |
| "Double-clap fallback gesture" | — | — | **does not exist** | Grep for `clap` across the kit returns one hit: `SpellshotConfig.lua:300`, "Thunderclap", an unrelated Voltaic row. The only failure path is `SpellshotInput.client.lua:826-831` — no ground under the crosshair flashes the slot red and casts nothing. |

### Zephyr — **BLOCKED, excluded from §4 priority**

Recorded for completeness only. Ten clips exist and are wired: WindBlade ×4 + ×4 Solo (`CastPose.lua:460-505`), CrossSlashDash (`:517`), GustJump/Land/Hover/Glide (`:551-597`), CycloneForm/Release (`:620-648`), all played from `AbilityFX.client.lua:232, 254, 277, 295, 307, 318, 329, 349, 365`. Known holes: **Deflect Gust has no 3P pose and is never broadcast** (`ZephyrHandler.server.lua:481-488` sends nothing); a Cyclone-caught victim has no pose at all (`AbilityFX.client.lua:402-451`); the second Gust Jump is eaten by RestartGuard 0.4 s vs AgainGap 0.15 s, with `d.Again` sent (`ZephyrHandler.server.lua:561`) and ignored; CrossSlashDash has **no `StanceLegs`** (confirmed — `:517` absent from the grep) so the legs pin during a 1.5 s charge that still walks; an M1 during a float replaces the hover clip and never restores it. **Note: Gust Jump is third-person-RICHER than first-person** — CastPose has glide and landing clips the Viewmodel does not (`Viewmodel.lua:632-635` says the arms are deliberately home by 0.34 s).

### Universal movement

| Move | 1P | 3P | Cov | Gap |
|---|---|---|---|---|
| Idle | `Viewmodel.lua:456` + breathing | `CastPose.lua:188`, cycle forced to 0 (`:807`) | partial | Completely motionless body. Deliberate (`CastPose.lua:185-186`) but dead-still. |
| Walk | `Viewmodel.lua:458` | no walk stance | n/a | There is no walk by design — `MovementController.client.lua:562-569` sets Sprint from any MoveDirection. Ready's `walkCycle` therefore only ever plays when the body moves with **no input**: glide tails, knockback. |
| Sprint | `Viewmodel.lua:460` | `CastPose.lua:191` | full | Replicated properly via `SpellshotService.server.lua:221-224`. |
| Crouch | `Viewmodel.lua:461` | `CastPose.lua:193` | full | The body *drop* is `Humanoid.HipHeight` server-side (`SpellshotService.server.lua:226-228`), not a pose. |
| Slide | `Viewmodel.lua:465` + drift | `CastPose.lua:198` | full | 3P is one held pose; 1P drifts entry→late over 0.8 s. |
| **Jump / fall / land** | partial (fall lift, `Viewmodel.lua:1653-1660`) | **none** | **none** | No air stance, no land clip, no Humanoid state read anywhere in CastPose. With the gate at `CastPose.lua:805`, jumping forward = sprinting in mid-air; falling straight down = frozen statue. Killing the stock Animate (`SpellshotService.server.lua:449-460`) removed jump/fall/land and nothing replaced them. |
| Slide-jump | none | **none** | none | `MovementController.client.lua:294` sends `"SlideJump"`; `SpellshotService.server.lua:282-286` accepts it **only to convert to "Sprint"** and never broadcasts. The attribute never holds the value. Reads as Slide snapping to Sprint, striding, mid-air. |
| Double jump | none | **none** | none | `MovementController.client.lua` contains **zero `SetAttribute` calls** (verified). Nothing crosses the wire. |
| Wall run | camera bank only, `MovementController.client.lua:850-861` | **none** | none | The script says so itself at `:71-72`. Observers see an upright sprint stride travelling along a wall with no bank. |
| Wall jump | none | **none** | none | Same. |
| Climb / swim | none | **none** | none | No Climb or Swim reference in CastPose at all. |

### Voltaic, Umbra, Radiant, Toxin

**Nothing exists.** Not thin — absent. Zero mentions in `CastPose.lua` or `Viewmodel.lua`; no rows in `VFXLibrary.Abilities`; verified no `BoulderShot`/`BulwarkCharge` rows either. They are config rows (`SpellshotConfig.lua:220-263`), icon ids and palette entries. `Config.BuiltElements = { Cryo, Pyro, Zephyr }` (`SpellshotConfig.lua:399`) is enforced at `SpellshotService.server.lua:576` and `HubServer.server.lua:425`, so they cannot be equipped. All 15 of their Techniques (`SpellshotConfig.lua:278-305`) are pool rows and nothing else. The single exception is `SpellshotService.server.lua:806-808`, which implements half of Radiant's Afterglow and is unreachable.

**Terra** has a real, coherent client layer (`SpellshotInput.client.lua:758-787, 1046-1109`; `AbilityFX.client.lua:568-626`) with **no body pose and no viewmodel arms at all** — self-documented at `SpellshotInput.client.lua:1047-1048`. It is also unreachable: no VFXLibrary row, no TerraHandler, nothing sets `Bedrock_Stacks`, and the charge ring reads `_G.SpellshotChargeRing` which nothing ever writes (the real hook is `MatchHUD.client.lua:611`, which even says so at `:140`).

**Worth saying explicitly:** stances are element-agnostic and unknown states fall back to Ready (`CastPose.lua:210-212`). A Terra player today would not T-pose — they would stand and run correctly and simply never gesture.

---

## 3. V-key toggle build plan

Ordered. Anchors verified. Two disagreements between the camera recon and the VFX-anchoring auditor are flagged inline — **the VFX auditor is right on both**.

**0. Pre-flight (blocking).** Confirm TerraFX exists in the live place. If not, nothing below matters.

**1. `SpellshotConfig.lua:125-145`** — add `AllowThirdPerson = false` inside the existing `Config.Dev` table (verified present, beside `AllowInStudio:126` / `AllowInLiveGame:131` / `UserIds:132`). Gate the V handler on it or `Config.IsDev` (`SpellshotConfig.lua:174-183`). FirstPersonController does not require SpellshotConfig yet — add it.

**2. `FirstPersonController.client.lua:41`** — `local FIRST_PERSON = true` becomes mutable `firstPerson`. (Recon cited both `:41` and `:42`; **`:41` is correct**.)

**3. `FirstPersonController.client.lua:50-54`** — extract into `applyCameraMode(fp)`. Third person needs `CameraMode = Classic` **and both zoom distances raised** — `DevPanel.client.lua:418` records that Classic alone does not release the camera because it is still at first-person distance. **Cap max zoom around 10-12, not Roblox's default 400** — see step 9.

**4. `FirstPersonController.client.lua:88-113`** — lift `hidden` (currently closure-local at `:95`) to file scope beside `hiddenConns` (`:88`, already file-scope). Add `showCharacter()`: **disconnect the RenderStepped re-assert at `:104` first** — a flag is not enough, it writes `LocalTransparencyModifier = 1` every frame — then walk `hidden` setting 0. Flip `CameraMode` at step 3 *before* clearing, or Roblox's own TransparencyController puts them back.

**5. `Viewmodel.lua`** — add `Viewmodel.SetVisible(on)` near `SetPosture` (`:1045`) plus a guard at the end of `Update`. **Hide, never Destroy.** Three reasons, all verified: (a) `Viewmodel.Play` (`:1059`) sets `state.clip` with no `IsBuilt` check, only `Update` clears it (`:1558`), and `Update` early-returns when unbuilt (`:1516`) — one cast after a Destroy leaves `IsPlaying()` true forever and permanently blocks M1 at `SpellshotInput.client.lua:886/944/991`; (b) `PlayShot` with no rig fires `onRelease` immediately (`Viewmodel.lua:1102-1105`), silently converting every M1 to instant-fire — a balance change; (c) `Humanoid.CameraOffset` is written **only** at `Viewmodel.lua:1775`, inside `Update`, so an unbuilt rig silently kills the crouch dip, slide dip, Heat Rush hunch and every cast punch. Also zero the two PointLights (`Viewmodel.lua:1743-1744`) or they light the world from the camera with no visible source.

**6. `Viewmodel.lua:1804` `GetMuzzleCFrame` — the single chokepoint.** Five callers: `FirstPersonController.client.lua:146, :150` and `SpellshotInput.client.lua:515, 900, 961, 1007`. Return the body hand's CFrame in third person and Icicle Shard, Fireball, Wind Blade, Deflect Gust and Cryo Beam are all anchored with **zero call-site edits**. **The trap, verified at `Viewmodel.lua:1807`:** the not-built fallback is `camera.CFrame * CFrame.new(0.3, -0.3, -1.4)` — so the rig being gone does not fall back to the body, it falls back to **a fixed point in mid-air in front of the camera**. That line must change in the same edit. Do the same for `GetArmCFrame` (`Viewmodel.lua:1165`), whose two PyroFX callers fail *invisibly* instead (returns nil, `PyroFX.lua:440` bails).

**7. `VFXLibrary.lua:2900` — DISAGREEMENT, resolved.** The Cryo auditor said "no change needed, the branch is per-viewer." The VFX auditor said the gate is wrong. **The VFX auditor is right.** Verified: `ctx.FP = h.IsLocal and VFXLibrary.LocalMuzzle ~= nil` means "is this my character and is a muzzle function installed" — *not* "am I looking through my own eyes". Remote beams are already correct, but once step 6 makes `GetMuzzleCFrame` body-aware, `LocalMuzzle` stays non-nil and **your own beam plays the entire first-person look in a shoulder cam** — screen-edge sunburst (`VFXLibrary.lua:2365-2369`), no crystal unleash (`:2420`), slim radius (`:2623`), 0.08 muzzle push instead of 0.35 (`:2927`). One line: add a first-person term to the gate. (The recon's alternative — set `LocalMuzzle = nil` — also works and is simpler, but only if step 6 is not done.)

**8. `VFXLibrary.LocalBeamOrigin` — DISAGREEMENT, resolved. It is dead code.** Verified: assigned `FirstPersonController.client.lua:145`, cleared `:168`, declared `VFXLibrary.lua:2102`, documented `Viewmodel.lua:60`, and **read by nothing in all 50 files**. Both auditors who flagged this are right; anyone planning work around "where must LocalBeamOrigin point" should stop. Leave `LocalCharacter` set in both modes — it is an identity flag for enemy-VFX thinning (`VFXLibrary.lua:736, 1199, 1353, 1445, 1819, 2830, 3314`), not an anchor.

**9. `SpellshotInput.client.lua:1152` — the most likely thing to be missed.** Verified: `if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then return end`. **No script in the codebase ever assigns `LockCenter`** — grep returns exactly two hits, this read and a comment at `DevPanel.client.lua:416`. The lock is purely a side effect of `CameraMode = LockFirstPerson`. Go Classic and every left click is silently swallowed, no error. Fix at `FirstPersonController.client.lua:204-213`: the cursor step (Camera+9, verified it only ever writes `Default` at `:208` or toggles the icon) needs an else-branch asserting `LockCenter` in third person. Keep it at Camera+9 so the five menu steps at Camera+10 still win.

**10. Aiming — do not touch, and constrain the camera because of it.** Verified: `Mouse.Hit`, `GetMouseLocation`, `ViewportPointToRay` and `UnitRay` appear nowhere. Everything is `camera.CFrame.Position` + `LookVector` (`SpellshotInput.client.lua:105-119, 901, 962, 1008, 1101`). A pulled-back camera changes three things, one of them server-side and silent: the client ray origin; `CombatCore.Blocked` (`CombatCore.lua:391-413`) raycasting cover from the claimed origin; and **`rej_origin`** — `AbilityHandler.server.lua:743`, `ZephyrHandler.server.lua:131`, `PyroHandler.server.lua:163` each drop any shot whose origin is more than `6 + max(velocity, WalkSpeed) * (0.35 + ping)` from the Head. At a standstill with BaseWalkSpeed 16 that is **11.6 studs**. A player who scrolls out past that disarms themselves with no feedback beyond a counter. Keep the camera within a couple of studs of the head, or accept a deliberate aiming change.

**11. `SpellshotInput.client.lua:897`** — replace the hardcoded `true` with `PyroFX.firstPerson()` (`PyroFX.lua:301-303`, already exists). Same for `AbilityFX.client.lua:207`'s `false` if the local body path is wanted.

**12. `FirstPersonController.client.lua:213`** — bind V. The file has no `InputBegan` handler today. **V is completely free** (verified: zero `KeyCode.V` hits in all 50 files). Reuse the menu guards from `SpellshotInput.client.lua:1146-1149`. Do not add it to the `BINDS` table — that is ability roles only. Caveat: the rebind field accepts any KeyCode (`SettingsMenu.client.lua:786-793`), so exclude V there or make it a real `Bind_` row.

**Already correct, no work:** `PyroFX.firstPerson()` branches for the Heat Rush own-aura hide (`PyroFX.lua:703`) and the whole Cinder Shield anchor (`PyroFX.lua:946, 986-996` with matched FP/TP tuning at `:84-85`) — these self-correct the moment `CameraMode` changes. Every billboard, all six ScreenGuis, and every body/world-anchored effect (Flash Freeze, Frost Slide, Chill Aura, Cross-Slash, Immolate motes, Heat Rush glow, Ring of Fire) are camera-independent.

**Cosmetic decisions to make, not bugs:** your own Fireball would still draw at the first-person size curve (`PyroFX.lua:461` sets `own = onHit ~= nil`, feeding `:499-500`); your Wind Blade would be the only trail-less one in the match (`ZephyrFX.lua:817`, `OwnTrail = false`); your Chill Aura vortex is wiped early (`VFXLibrary.lua:1819-1827`) because in first person it is inside your face. All key off *ownership* where they mean *camera*.

---

## 4. Prioritised animation gap list

Zephyr excluded per instruction. Ordered by coverage-per-hour.

**P0 — TerraFX.** Not animation work, but nothing else can be verified until it is resolved. See §1.

**P1 — The airborne cycle gate. `CastPose.lua:800-806`. One line, ~10 minutes.** Add a ground test (`state.Humanoid.FloorMaterial`, which every client already has) to `moving`. This stops every jump, every fall, every slide-jump and every wall run in the game from looking like a man jogging through the air, for every player of every Element, with no new replication. **Highest ratio in the report by a wide margin.**

**P2 — An Air stance + a Land clip. `CastPose.lua:198` / `:779` / `:1093`.** Medium. Adds the held fall pose P1's gate now exposes, and a landing absorb. The landing clip **already exists** — `CastPose.Clips.GustJumpLand` (`CastPose.lua:567`) is currently gated behind a Zephyr broadcast (`AbilityFX.client.lua:329`); a `Humanoid.StateChanged(Landed)` hook in `Start()` can reuse it verbatim. Still no new replication needed: every client can read its own copy of every Humanoid.

**P3 — Icicle Shard `StanceLegs`. `CastPose.lua:234` and `:243`. Two words.** Stops the Cryo M1 — the most-fired animation in the kit — from snapping both legs straight on every shot, and fixes Cold Momentum's footfall marks as a side effect.

**P4 — Slide-jump broadcast. `SpellshotService.server.lua:282-286` + a clip at `CastPose.lua:198`.** The signature movement moment of the game, currently invisible. **The server round trip already exists** — `moveRemote` receives `"SlideJump"` and the server throws it away after converting to Sprint. Cheapest replication win in the set.

**P5 — Flash Freeze structure. `CastPose.lua:253`.** Add `Both = true` (a two-fisted ground slam currently reads one-armed), key Knee on `:256/:258/:260`, re-sign Elbow. Chill Aura (`CastPose.lua:283`) gets the same Knee and Elbow treatment. These two are exactly the clips `CastPose.lua:92-95` warns about as un-re-derived.

**P6 — Frozen victim stance. `CastPose.lua:187` + `:210`, attribute from `AbilityHandler.server.lua:296`.** The kit's signature crowd control currently shows the victim standing in the neutral ready pose inside an ice block.

**P7 — Cryo Beam aim. `CastPose.lua:866` via `AbilityFX.client.lua:134-136`, plus updating `orient.CFrame` at `AbilityHandler.server.lua:620-624`.** Large but high-visibility: today a rigid yaw-pinned body emits a beam at an arbitrary angle to itself for 4.15 s. The solver already exists (`aimPose`). Note the yaw pin looks accidental — the comment at `AbilityHandler.server.lua:531-534` explains the AlignOrientation exists to stop PlatformStand tumbling the camera, not to lock facing.

**P8 — Ring of Fire point. `CastPose.lua:408`.** Replace the baked 13-stud angles with `SetAim` for the duration of the point.

**P9 — Idle breathing. `CastPose.lua:188`.** Small, purely cosmetic, but a perfectly motionless standing body is noticeable.

**P10 — Terra body clips.** Blocked on TerraFX *and* a nonexistent TerraHandler *and* a VFXLibrary row. Do not start here despite it being a whole Element.

**P11 — Double jump / wall run / wall jump.** Large, and the cost is not the poses — it is that `MovementController.client.lua` publishes **nothing** (zero `SetAttribute`, verified). Wall run additionally needs a body-roll channel that `buildOffsets` does not have (`CastPose.lua:658-681` writes shoulders, elbows, wrists, waist, hips, knees and nothing else). The Gust Jump hover round trip (`SpellshotInput.client.lua:584` → `ZephyrHandler.server.lua:565-582` → `AbilityFX.client.lua:304-312`) is the template to copy.

---

## 5. Things you did not ask about

- **`CastPose.Config.RestartGuard` guards a caller that no longer exists.** `CastPose.lua:117-124` says a cast fires the clip twice — locally on the keypress from SpellshotInput, then from the broadcast. Verified false: **SpellshotInput contains no CastPose reference at all** except a comment at `:1047`; the only two requires in the codebase are `AbilityFX.client.lua:25` and `FirstPersonController.client.lua:38`. (One auditor placed `CastPose.Start()` at `SpellshotInput.client.lua:122` — that line is inside `aimPoint`'s raycast; they confused it with `FirstPersonController.client.lua:122`.) **Consequence:** every third-person body pose in the game, including the local player's own, lags the input by a full server round trip. Invisible today; on a high-ping player, other people's bodies punch after the projectile is already in the air.

- **Four exported CastPose functions are dead.** `IsPlaying` (`:1202`), `SetStance` (`:1217`), `Release` (`:1224`), `GetCameraOffset` (`:1210`) — I grepped each individually across all 50 files: zero external callers. `SetStance`'s own comment says it is "exposed for testing and for the dev panel"; DevPanel never calls it. It does still work from the command bar, which makes it the fastest way to prototype the P2 air stance.

- **Every camera punch authored in CastPose goes nowhere.** `GetCameraOffset` has no callers, `Humanoid.CameraOffset` is owned outright by `Viewmodel.lua:1775`, and `MovementController.client.lua:793` confirms the handover. So `state.Cam` is lerped every frame (`CastPose.lua:998`) and thrown away — Flash Freeze's `Cam = -1.7` (`:258`) and Chill Aura's `-0.35` (`:286`) do nothing. Anyone tuning a punch by editing a CastPose clip sees no effect. Wiring it up is nearly free; the data is already computed.

- **`VFXLibrary.LocalBeamOrigin` is dead code** (see §3 step 8). Any plan that mentions it is planning around nothing.

- **The local body is already fully posed.** `CastPose.Start()` hooks `Players:GetPlayers()` and `PlayerAdded` with **no local-player exclusion** (`CastPose.lua:1132-1138`), and nothing calls `Release`. The body is hidden only by `LocalTransparencyModifier` behind `FirstPersonController.client.lua:41`. **A third-person toggle would reveal a correctly posed body today** — one whose stance lags by a round trip, because it reads the replicated MoveState where the viewmodel reads live key flags.

- **Two independent debug time scales can desync filming.** Icicle Shard's spawn divides by `CastPoseTimeScale` (`AbilityFX.client.lua:71-73`); the Fireball spawn on the next ability divides by `VFXLibrary.ShotTimeScale()` (`:208`) while its body clip runs on `CastPoseTimeScale` (`CastPose.lua:709-713`). Both default to 1, so live play is fine — but the ShotTimeScale-0.25 filming workflow will put the third-person fireball nowhere near the punch.

- **Wind Blade shares a hand-copied constant.** `WB_UP_RISE = 0.6` (`CastPose.lua:453`) is commented "ASSUMED, = Viewmodel's UP_RISE" — a literal, not a read. Changing the viewmodel's up-stroke silently desyncs the body from the arms, in the one place the two systems are meant to agree on a number.

- **Cyclone is the only clip authored blind** — `CastPose.lua:602-603` says its arms were "authored by eye from the other clips' channel values, not measured on the rig". First candidate if the Ultimate reads wrong at distance.

- **The Cross-Slash blocking lost two channels in translation, and anything future-authored in Blender will lose them the same way, silently.** `buildOffsets` (`CastPose.lua:658-683`) has no root and no neck joint, so the approved whole-body Lean was folded into Waist and the Neck dropped (`CastPose.lua:513-515`).

- **R6 rigs silently discard every leg channel.** `CastPose.lua:658-664` writes only `"Right Shoulder"` / `"Left Shoulder"`, folds Elbow in at 0.5 and returns early. No waist, hips, knees or wrists — no stride, no slide tuck, no torso lean. Documented as intentional; whether an R6 rig can reach the game depends on UniformAvatar.

- **Roblox's stock character SOUNDS were never removed** — only Animate and Health (`SpellshotService.server.lua:457-468`). So the stock sound system is still driving footsteps off Humanoid state and speed while CastPose drives the legs off MoveState. Two unrelated systems describing the same stride; only the slide has been reconciled (`SlideAudio.client.lua:60-62`).

- **There may be two crosshairs.** `MatchHUD.client.lua:123-135` builds `"SpellshotHUD"` with a Crosshair; `PopArtHUD.client.lua:140-141` destroys `"SpellshotHUD"` at load and builds its own at `:265`. Both are StarterGui LocalScripts and both set `_G.SpellshotHUD`. Which wins is load order, which is not declared. If MatchHUD ever wins, `HubClient.client.lua:286`'s `COMBAT_GUIS` list does not include `"SpellshotHUD"`, so its crosshair would stay visible in the Hub. *(Inference — load order is not observable from source.)*

- **A comment in the new Terra code is factually wrong about the project's own architecture.** `SpellshotInput.client.lua:1047-1048` justifies the floating rock by saying it "works against the stock character animation". There is no stock character animation — `SpellshotService.server.lua:449-460` disables Animate server-side and says CastPose is the only thing that poses a body. Whoever wrote that was working from an older mental model; worth checking what else was written on the same assumption.

- **`SpellshotConfig.lua:139-144`'s `Config.Dev.Keys` table is stale.** It claims four dev binds live in SpellshotInput; `SpellshotInput.client.lua:1139-1141` says they were removed and moved to DevPanel, whose only key is Semicolon. They are dead hint strings — do not trust that table as a keybind inventory.

- **Two render steps share priority 201 (Camera+1)** — `MovementController.client.lua:858` (slide roll) and `SettingsRuntime.client.lua:248` (look step), whose comment at `:246` assumes it runs *after* the roll. Their order is script load order, undeclared. Benign today; a third-person camera makes a slide's 6.5-degree bank far more visible, so pin the order while you are in there.

- **Confirming rather than correcting the preamble:** I found zero `Animation`, `AnimationTrack`, `Animator` or `LoadAnimation` usage in all 50 files — the only textual hit is the word "Animator" inside the explanatory comment at `SpellshotService.server.lua:455`. And `CastPose.Play` returns silently for an unknown clip name (`CastPose.lua:1143-1144`), so there is no generic fallback pose an unbuilt Element could accidentally inherit.

---

## 6. Part 1 build record - the V-key toggle

Built at `%TEMP%\vmarm\tp\`. `make_final.py` applies exact-substring edits with a uniqueness
assertion on every anchor; `base/` is the text it was written against and `final/` is the result.
All five files compile with `luau-compile`.

| Script | Edits | Lines | What changes |
|---|---|---|---|
| `StarterPlayerScripts.FirstPersonController` | 7 | 213 -> 342 | the toggle itself: config + gate, `applyCameraMode`, `applyMuzzleSources`, `LocalAimCFrame`, the body hide/show, the LockCenter assert, the V binding |
| `StarterPlayerScripts.SpellshotInput` | 6 | 1234 -> 1249 | one `aimCF()` helper; six reads of `camera.CFrame.Position` go through it. Returns `camera.CFrame` unchanged in first person |
| `IceMagic.Viewmodel` | 4 | 1873 -> 1922 | `thirdPerson()` / `bodyHandCFrame()`; stop drawing the rig; `GetMuzzleCFrame` and `GetArmCFrame` return the body hand |
| `IceMagic.VFXLibrary` | 1 | 3503 -> 3507 | declares `LocalAimCFrame` beside the other two local hooks |
| `IceMagic.PyroFX` | 1 | 1211 -> 1218 | the Fireball charge picks its anchor by camera rather than by ownership |

### The three decisions inside it

**Aiming does not move with the camera.** Every shot reads `camera.CFrame`, and the servers drop any
claimed origin more than `6 + max(velocity, WalkSpeed) * (0.35 + ping)` studs from the shooter's Head
- about 11.6 studs standing still (`AbilityHandler.server.lua:743`, `ZephyrHandler.server.lua:131`,
`PyroHandler.server.lua:163`). The testing camera sits 12.5 studs back, so a camera-origin shot would
simply stop registering. `aimCF()` keeps the origin at the head and takes only the direction from the
camera; in first person it returns `camera.CFrame` itself, so first-person aiming is unchanged to the
byte. The cost is stated in the code: in third person the crosshair and the shot are no longer the
same ray, most visibly at close range.

**The viewmodel is hidden, never destroyed.** `Viewmodel.Play` sets `state.clip` with no built check
and only `Update` clears it, and `Update` returns early when the rig is gone - so one cast after a
`Destroy()` leaves `IsPlaying()` true for the rest of the round, and `SpellshotInput` gates every M1
on that (`:886`, `:944`, `:991`). `PlayShot` with no rig also fires its release callback immediately,
turning every M1 into an instant-fire. And `Humanoid.CameraOffset` is written only inside `Update`,
so an unbuilt rig kills the crouch dip, the slide dip, the Heat Rush hunch and every cast punch. The
rig therefore stays built and animating in both views and simply stops being drawn.

**The mouse is re-locked by hand.** Nothing in the codebase ever assigns `MouseBehavior =
LockCenter`; it is purely a side effect of `CameraMode = LockFirstPerson`. And
`SpellshotInput.client.lua:1152` drops every M1 press unless `MouseBehavior == LockCenter`. Going
Classic without this would silently swallow every left click, with no error. The assert goes in the
existing cursor step at Camera+9, so the menus' own steps at Camera+10 still win.

### Flagged, not decided

- **Who gets it.** `ALLOW_THIRD_PERSON_TOGGLE = true` gates the whole feature; dev-only later is
  `and player:GetAttribute("Dev") == true` on the binding, or move the boolean into the existing
  `Config.Dev` table (`SpellshotConfig.lua:125-145`). Free third person in a ranked duel sees around
  corners and over cover that first person cannot.
- **V is free today** (zero `KeyCode.V` in all 50 scripts), but the settings rebind field accepts any
  KeyCode, so a player could bind an ability to V and get both. Not guarded.


---

## 7. Round 2 (2026-09-21) - over-the-shoulder framing, and the vibration fix

Two things the owner reported after the first push, against a Marvel Rivals reference frame.

### The vibration - found, and it was not the toggle

`SettingsRuntime.client.lua`'s look step (the one that applies the sensitivity curve and invert-Y,
at RenderPriority Camera+1) re-aims the view with:

    camera.CFrame = CFrame.new(cf.Position) * CFrame.fromOrientation(pitch, yaw, rz)

It rebuilds the camera about the **camera's own position**. In first person the camera IS the head,
so spinning it on the spot is exactly right. A third-person camera orbits the character from a
distance, and spinning it on the spot points it off the subject - so Roblox's CameraModule puts it
back on the next frame, this step turns it off again, and the two fight every frame. That is the
vibration.

It fires on every mouse turn at the DEFAULT sensitivity. The step early-returns when the gain is
exactly 1, and the Sensitivity curve is exponential (`Low = 0.125, High = 5`,
`SpellshotSettings.lua:72`), so the default of 50 gives `0.125 * 40^0.5` = **0.79**, not 1. The
branch is always live.

Fixed by orbiting the focus instead, keeping the camera's existing distance. First person keeps the
original line, byte for byte, behind a `CameraMode` check.

### The framing

The stock Classic camera sits dead behind the character, which puts your own back over whoever you
are aiming at. The camera is now shifted sideways and a little up **after** the CameraModule has
placed it - a translation, never a rotation, so the look direction is untouched and there is no
feedback loop to shake against. `camera.Focus` moves with it, and the aim frame is taken from the
focus, so the crosshair and the shot stay on one line rather than a couple of studs apart.

    TP_DISTANCE = 7.0                        -- was Roblox's default 12.5
    TP_SHOULDER = Vector3.new(2.2, 0.6, 0)   -- studs right, and up

Both are one-line nudges at the top of `FirstPersonController.client.lua`. Raising X pushes the body
further into the corner; lowering TP_DISTANCE brings it closer.

### Measured in a Play session

| | Result |
|---|---|
| Camera-to-head distance over 1103 frames | 9.953 to 9.953 - zero drift, so the per-frame shift does not accumulate |
| Right arm / right leg, 120 frames idle | max frame-to-frame step 0.0000 - the body itself is not twitching |
| Body on screen | left of centre, centre of frame clear |
| Mouse | LockCenter in both views, so M1 still registers |

The turning case could not be reproduced from a script - synthetic mouse moves do not generate
camera deltas while the mouse is locked - so the vibration fix is verified by reading, not by
measurement. Worth a turn in third person to confirm.

### Six scripts now

`FirstPersonController`, `SpellshotInput`, `Viewmodel`, `VFXLibrary`, `PyroFX`, `SettingsRuntime`.
All compiling, all pushed, **none saved**.
