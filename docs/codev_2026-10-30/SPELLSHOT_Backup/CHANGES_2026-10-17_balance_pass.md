# 2026-10-17 — Balance pass (the 15 recommendations)

Applies the recommendations in `balance_2026_10_16/BALANCE_REPORT.md` §7, as asked ("Apply all recommendations. Note the
changes so it can be reverted"). Edited live in Studio (Team Create keeps its own versions). No manual save, no publish.

## Backup inside the place

`ServerStorage.BalanceSuperseded_2026_10_17` holds an untouched copy of each of the 20 scripts this pass changed:
- Each copy has an `OriginalPath` attribute. Scripts are disabled, and child instances were not copied.
- The folder's attributes also hold the four duel marks' old CFrames.

Every edited value also carries an inline note, `--[[<old value> until the 2026-10-17 balance pass]]`. Search the
scripts for `2026-10-17 balance` to find them all.

## What changed

| # | Change | Where | Was | Now |
|---|---|---|---|---|
| 1 | Fireball speed (Life cut so the reach stays ~the same) | `IceMagic.PyroFX` Tuning.Fireball `Speed`, `Life` | 65, 2.5 (162 studs) | 110, 1.5 (165 studs) |
| 1 | Toxic Bubble speed | `IceMagic.ToxinTuning` Bubble `Speed` | 60 | 90 |
| 1 | Riptide speed | `IceMagic.AquaTuning` Riptide `Speed` | 70 | 100 |
| 1 | Icicle Shard speed | `IceMagic.VFXLibrary` Tuning.IcicleShard `Speed` | 170 | 220 |
| 2 | Slide-jump chain | `Spellshot.SpellshotConfig` Movement `SlideJumpBoost` / `MinSpeed` / `MaxSpeed` | 32 / 56 / 70 | 22 / 42 / 52 |
| 3 | Dash threshold: a cap under this refuses or ends a dash | `VFXLibrary` FrostSlide `DashMinCap` (the default), `ZephyrFX` CrossSlash `DashMinCap`, `TerraFX` BulwarkCharge `MinCap`, `VoltaicTuning` Overcharge `MinCap`, `VoltaicClient` FALLBACK Overcharge `MinCap` | 12 | 16 |
| 4 | Duel marks moved toward the middle (both marks, rotation kept) | `Map_AscendantBastion.Marks.A` / `.B` | (8092, 0.300, 0) / (7908, 0.300, 0) | (8068, −0.060, 0) / (7932, −0.060, 0) |
| 4 | | `Map_ShatteredNeonCity.Marks.A` / `.B` | (0, 0.390, −2901) / (0, 0.390, −3099) | (0, 0.090, −2933) / (0, 0.090, −3067) |
| 5 | Round clock: when it runs out, the larger share of health left wins the round; equal shares are a draw | `SpellshotConfig` Duel `RoundTime` (new), `DuelMatch`, `HubClient`, `PopArtHUD` | none | 90 s |
| 6 | Scorching Lash cooldown | `VFXLibrary` row ScorchingLash `Cooldown` | 2.5 | 5 |
| 6 | Lash burn per stack (preset A) | `ServerScriptService.StatusEffects` preset A Burning.Lash `PerStack` | 1.6 | 1.0 |
| 7 | Poisoned tick (preset A) | `StatusEffects` preset A Poisoned `TickDamage` | 4 | 6 |
| 7 | Acid Rain tick | `ToxinTuning` AcidRain `TickDamage` | 4 | 6 |
| 8 | Sidearm bullet cost | `AquaTuning` Sidearm `BulletCost` | 6 | 4 |
| 8 | Twin Tide mana | `AquaTuning` TwinTide `ManaCost` | 40 | 30 |
| 8 | Twin Tide crush width | `AquaTuning` TwinTide `CrushHalfWidth` | 3.5 | 5 |
| 9 | Skyrider flight | `IceMagic.ZephyrSkyrider` `FlySpeed` / `BoostSpeed` | 42 / 55 | 60 / 75 |
| 10 | Chain Bolt charge on a lone target (preset A) | `StatusEffects` preset A Charged `AloneDamage` | 0 | 7 |
| 10 | Ember Refund's trigger (the owner's pick): a Pyro hit that takes an enemy from 30% health or more to under it, leaving them standing. In a duel that is once a round, unless they are healed back over 30%. | `PyroFX` Tuning.EmberRefund `Trigger`, `Below`; `ServerScriptService.PyroHandler` | a kill | `"LowHealth"`, 0.30 (the refund is still 30% of the cooldown) |
| 10 | Chain Reaction (the owner's pick): every time Charged fills on a target, 2 s come off Overcharge's cooldown | `VoltaicTuning` ChainReaction `Trigger`, `MaxStackCut`; `VoltaicHandler` (`Status.OnChargedFull`); `StatusEffects` (calls that hook as Charged goes off) | a kill: 30% of the cooldown | `"MaxStacks"`, 2 s |
| 10 | Antitoxin Vent (the owner's pick): while the mask is on, every DoT tick on you hurts 30% less. Cleansing your own poison is unchanged. | `ToxinTuning` Vent `DoTReduction`; `ToxinHandler` (a damage modifier, priority −7) | none | 0.30 |
| 10 | Loadout text for those three | `SpellshotConfig` Pyro and Voltaic Passive `Desc`, AntitoxinVent `Desc` | the old wording | the new rules |
| 11 | Benediction longest channel | `IceMagic.RadiantTuning` Benediction `MaxChannel` | 30 s | 8 s |
| 12 | Deep Freeze root | `IceMagic.CryoTuning` DeepFreeze `Root` | 2.5 | 1.5 |
| 13 | Blizzard length and slow | `CryoTuning` Blizzard `Duration` / `SlowCap` | 8 / 14 | 6 / 11 |
| 14 | Mirror Cage volley: the same 12 bolts × 6 = 72, landed faster, so the root ends with it | `CryoTuning` MirrorCage `VolleyTime` | 1.6 (root 3.13 s) | 0.77 (root 2.30 s) |
| 15 | Undertow row range (only the aim direction is used) | `AquaTuning` Undertow `Range` | 30 | 36 |
| 15 | Unused key brought in line with the live Chill window | `ServerScriptService.AbilityHandler` Tune `ShardChillWindow` | 3.0 | 5.0 |

The round clock (#5) in code:
- **`DuelMatch`:**
  - `showClock` sets the player attribute `RoundEndsAt` (server time) while a round is live.
  - `timeUp` settles the round when the clock runs out (`How = "time"`).
  - `roundEnd` now carries `How`.
  - `RoundEndsAt` is cleared at the round's end, at the match's end and on release.
- **`HubClient`:** round-end banners read "TIME! ROUND TO YOU!" and so on when the clock settled the round.
- **`PopArtHUD`:** the round plate's middle shows the time left (`1:29`) instead of "ROUND" and turns red in the last 10 s.

Knock-on effects of these values:
- `SlideJumpMaxSpeed` also caps the wall-run speed and the slide's entry speed (`MovementController`). Wall runs now top out at 52, not 70.
- Scorching Lash's trail limit (`PyroHandler` `LASH_MAX_TRAIL_SPEED`) is also 52 now.
- With the dash threshold at 16:
  - Chill's 2-stack cap (15) and Blizzard (11) both stop dashes now. Before, neither did.
  - This applies to Overcharge, Bulwark Charge and Cross-Slash.
- Sidearm now costs about 6.7 mana/s held, so it can be held indefinitely on the 7/s regen.
- **Chain Reaction can run hot.** A Chain Bolt fires every 0.32 s and Charged fills at 4 stacks. With every bolt landing,
  Charged fills about every 1.3 s, so Overcharge could come back every ~3.5 s instead of every 9 s. If that is too much,
  lower `MaxStackCut`.

## Not applied, and why

- **#9, "delete the stray `DashDistance = 55`" (ZephyrFX CrossSlash):** it is not stray. It is the glide's pace, read by
  `SpellshotInput`, `AbilityFX`, `ZephyrFX_CrossSlash` and `ZephyrHandler`. Deleting it would break Cross-Slash.
- **#9, "confirm Cross-Slash 12 / 40":** that is the owner's call. The values are still marked ASSUMED.
- **#15, "Boulder Shot MinSpeed 108 > MaxSpeed 86":** this is on purpose. TerraFX's own comment says "The heavier it is
  the slower it leaves the hand."
- **#15, "Fireball row Range 110 vs 162 flight":** also on purpose. The row's Range is only how far the aim ray reaches,
  and the shot flies on until its Life runs out (VFXLibrary's comment). Only Life changed, to keep the reach at the new speed.
- **#4 on Skyline (both versions):** room behind each mark is 32–33 studs. Moving the marks 10 in opens a clear line
  between them, so they stay where they are.
- **#4 on Quarry mark B:** 20 studs of room before a drop, and no standing spot within 80 studs toward A.
- **#4 on Sakura Row:** it already has 41–44 studs of room behind each mark.
- **#10, Overcharge's prime:** left as it is (the owner's pick). It stays a team-fight tool.

## To take it out

- **One value:** put back the "Was" column above, or the value in that line's `--[[... until the 2026-10-17 balance pass]]` note.
- **Just the round clock:** set `Config.Duel.RoundTime = 0`. The clock never starts and the HUD keeps showing ROUND.
  The code can stay.
- **The three reworks:** set these. Each puts the old behaviour back, and the new code can stay.
  - `PyroFX.Tuning.EmberRefund.Trigger = "Kill"`
  - `VoltaicTuning.ChainReaction.Trigger = "Kill"`
  - `ToxinTuning.Vent.DoTReduction = 0`
- **Everything at once:** run this in the Edit command bar. It also undoes anything else changed in these 20 scripts
  after 2026-10-17, so check that first.

```lua
local folder = game.ServerStorage.BalanceSuperseded_2026_10_17
local function resolve(path)
	local inst = game
	for part in path:gmatch("[^%.]+") do inst = inst and inst:FindFirstChild(part) end
	return inst
end
for _, b in folder:GetChildren() do
	local live = resolve(b:GetAttribute("OriginalPath"))
	if live and #b.Source < 200000 then
		live.Source = b.Source
	elseif live then -- VFXLibrary and TerraFX are too long to assign: the copy takes the edited one's place
		local c = b:Clone()
		c:SetAttribute("OriginalPath", nil)
		c.Parent = live.Parent
		live:Destroy()
	end
end
for name, cf in folder:GetAttributes() do
	local map, side = name:match("^(Map_.+)_([AB])$")
	if map and workspace:FindFirstChild(map) then workspace[map].Marks[side].CFrame = cf end
end
```

Team Create's version history also has the place from before this pass.

## Checked

- **Compiles:** all 20 edited scripts compile (`loadstring`).
- **Reworks load:** a second Play run, after the reworks, gave no script errors or warnings.
- **Line diffs:** a line diff against each backup shows only the edits listed here.
- **Solo Play:**
  - No script errors in the output.
  - Values read back live: slide-jump 22 / 42 / 52, `RoundTime` 90, Icicle 220, Blizzard cap 11, Mirror Cage root 2.30.
  - The HUD clock showed `1:12`, turned red at `0:06`, and went back to ROUND when the attribute cleared.
- **Moved marks:** each has 41–42 studs of room behind it. The line between them is still blocked by cover.

## Not checked

- A real 2-player duel reaching the 90 s clock (needs a Server & Clients test).
- How the slower chain, the dash threshold and the faster projectiles feel.
- Spawning on the moved marks in a real duel.
- Skyrider at 60 / 75.
- The faster Mirror Cage volley's look.
- The three reworks in a real fight:
  - Ember Refund firing when an enemy drops under 30%.
  - Chain Reaction's refund when Charged fills.
  - The Vent's 30% DoT cut.

## Later the same day: hitboxes 30% bigger, for players and dummies

The owner asked: "increase the hitbox of the characters by 30% (increase for dummies too so i can test)".

| What | Where |
|---|---|
| `Config.Hitbox = { Scale = 1.3, ShowAlpha = 0.6 }` | `SpellshotConfig`, a new block after `Config.Duel` |
| New Script, described below | `ServerScriptService.HitboxScale` |
| New LocalScript that keeps the hitbox parts invisible on every client | `StarterPlayer.StarterPlayerScripts.HitboxGuard` |
| `REACH` 4.5 → 4.5 × Scale (5.85): how far from a character's root a claimed hit may land | `ServerScriptService.CombatCore` |
| `isHeadshot` counts the head's hitbox part as the head, at its own size | `ServerScriptService.UmbraHandler` |
| `predictHeadshot` does the same, for the client's instant look | `ReplicatedStorage.IceMagic.UmbraClient` |

What `HitboxScale` does:
- It covers every visible body part of every character and dummy, meaning any Model with a Humanoid in workspace except a Bulwark Wall.
- Each part gets an invisible twin, 1.3× its size in each direction, welded at the same centre.
- The twins are query-only: no collision, no touch, massless.
- They sit in a `Hitboxes` folder, named `<part>Hitbox`, with attribute `HitboxOf` and tag `Hitbox`.
- They are rebuilt when UniformAvatar replaces a body part.

**To see the hitboxes while testing:** set the attribute `ShowHitboxes = true` on `workspace`, or run
`workspace:SetAttribute("ShowHitboxes", true)` in the command bar during Play.
- They draw red and 60% see-through. Clear the attribute to hide them.
- Dummies far from you are streamed out, so their hitboxes appear once you walk up to them.

**Backup:** `ServerStorage.HitboxSuperseded_2026_10_17` holds SpellshotConfig, CombatCore, UmbraHandler and UmbraClient as they were just before this change.

**To take it out:** set `Config.Hitbox.Scale = 1`. Nothing is built and `REACH` goes back to 4.5. Or delete `HitboxScale` and `HitboxGuard` and put the four backups back.

**Checked in Play:**
- All 8 dummies and the player got 15 hitbox parts each, at 1.3× and centred.
- They are invisible on the server and on the client, including after a local script set every part of a dummy opaque.
- A ray passing 0.25 studs outside a dummy's torso now hits the dummy, on the server and on the client.
- The server accepts a claimed hit on the far corner of the head twin and of the foot twin.
- `ShowHitboxes` shows them.
- No script errors.

**Not checked:**
- A real shot through each kit's own hit code. The kits resolve hits with `FindFirstAncestorOfClass("Model")`, so a twin counts as the body.
- Whether any kit's client code skips invisible parts (not audited). A kit that did would ignore the bigger hitbox.

## Later still: hitboxes 2x, and one speed for every M1 projectile

The owner asked: "increase hitbox by 100% (i think this would get us around rivals)". Also: "the charging of m1 that can take time whatever, but the speed of the elements should roughly be the same (projectile)".

| What | Where | Was | Now |
|---|---|---|---|
| Hitbox scale | `SpellshotConfig` `Config.Hitbox.Scale` | 1.3 | 2.0 |
| Server hit tolerance from the root | `CombatCore` `REACH` | 4.5 × Scale (5.85) | 4.5 + (Scale − 1) = 5.5 |
| Movement rays ignore other bodies' hitbox twins | `MovementController` (`withHitboxes`, `rayParams:AddToFilter`) | a twin could read as floor, wall or ledge | never |
| Icicle Shard speed | `VFXLibrary` Tuning.IcicleShard `Speed` | 220 | 200 |
| Fireball speed, life | `PyroFX` Tuning.Fireball `Speed`, `Life` | 110, 1.5 (165 studs) | 200, 0.83 (166 studs) |
| Toxic Bubble speed | `ToxinTuning` Bubble `Speed` | 90 | 200 |
| Riptide speed | `AquaTuning` Riptide `Speed` | 100 | 200 |
| Boulder Shot speed, tap and full charge | `TerraFX` BoulderShot `MinSpeed` / `MaxSpeed` | 108 / 86 | 200 / 200 |
| Wind Blade speed | `ZephyrFX` Tuning.WindBlade `Speed` | 240 | 200 |
| Shadow Dart speed | `UmbraTuning` ShadowDart `Speed` | 240 | 200 |

Chain Bolt and Light Lance are hitscan and stay hitscan.

Why `REACH` is not doubled: parts grow about their own centres. The farthest hitbox corner of a standing body is 3.2 studs
from the root at 1×, 3.3 at 1.3× and 3.9 at 2×, so a stud more per unit of scale covers it.

**Backup:** `ServerStorage.SpeedHitboxSuperseded_2026_10_17` holds all ten scripts as they were just before this change.

**To take it out:**
- Put back the "Was" column above.
- Or put the ten backups back.
- `Config.Hitbox.Scale = 1.3` (or 1) on its own undoes the hitbox part.

**Checked in Play:**
- 135 hitbox parts (8 dummies and the player) are at 2× and invisible.
- All seven M1 speeds read 200.
- No script errors.

**Not checked:**
- How the faster Fireball, Bubble, Riptide and Boulder look in flight.
- Toxic Bubble at 200 barely lobs, so a miss now lands far behind the target, which matters for Corrosive Cloud.
- Movement next to another player with the new filter.
