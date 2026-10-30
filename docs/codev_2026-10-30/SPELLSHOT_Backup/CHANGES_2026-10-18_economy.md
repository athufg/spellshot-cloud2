# 2026-10-18 — the player economy (Sparks, owned Elements, Sparks packs)

The owner's locked decision, built: the 9 base Elements are earned with Sparks (from playing, or from Sparks bought with
Robux). Every player owns the **starter kit** (Pyro, Zephyr, Cryo, Terra, Radiant) from the first join; Aqua, Toxin,
Umbra and Voltaic stay locked until bought with Sparks. Skins and wraps are untouched (Robux-only, shop logic as it was).

Edited live in Studio over Team Create (Roblox keeps its own versions). No manual save, no publish, **no Play run by
me** (the orchestrator runs Play tests). Every new block is marked `(2026-10-18, economy)`.

## Backup inside the place

`ServerStorage.EconomySuperseded_2026_10_18` holds an untouched copy of each of the 5 existing scripts this pass edited,
taken just before the first edit. Each copy has an `OriginalPath` attribute, has no children, and is disabled.

**Warning:** the team-mode session edited `HubServer` (about 6 KB of team-mode work) AFTER this backup was taken. Never
swap the `HubServer` or `SpellshotService` backups in wholesale: use the hunk revert below, which takes out only this
pass's lines.

## What changed

### New scripts (copies in `economy_2026_10_18\src\`)

| Script | What it is |
|---|---|
| `ReplicatedStorage.Spellshot.EconomyConfig` (ModuleScript) | Every economy number: the starter kit, Element prices, match rewards, Sparks packs. Helpers both sides use: `PriceOf`, `IsStarter`, `MatchSparks`, `PackByProductId`, `ParseOwned`. No state. |
| `ServerScriptService.PlayerData` (ModuleScript) | Persistence and the API: the save, the session cache, the starter grant, the Sparks and owned set, `ProcessReceipt`. |
| `ServerScriptService.EconomyService` (Script) | Calls `PlayerData.Start()` once, and answers the new RemoteFunction `ReplicatedStorage.Spellshot.EconomyRequest` (`"UnlockElement", element`), made at startup. |

**PlayerData API** (the team-mode session calls `AwardMatch` at match end):

- `PlayerData.AwardMatch(player, result, roundsWon)`
  - `result` is `"win"`, `"loss"` or `"draw"`.
  - Returns the Sparks paid, or 0 when refused.
- `PlayerData.Owns(player, element)`
  - Before the save has loaded, it answers with the starter kit, never less.
- `PlayerData.AddSparks(player, n, reason)`
  - Returns the new balance. The balance never goes below 0.
- `PlayerData.Unlock(player, element)`
  - Gives an Element for free (dev, and later events).
- `PlayerData.BuyElement(player, element)`
  - The Sparks path. Returns `ok, code, info`.
- `PlayerData.Ready(player, timeout)` and `PlayerData.IsLoaded(player)`
  - For callers that need to wait for the load.
- `PlayerData.ResetToStarter(player)`
  - Dev only.

**What the client sees:** player attributes, never a table.
- `Sparks` (a number).
- `OwnedElements` (the owned names, sorted and comma-separated, e.g. `"Cryo,Pyro,Radiant,Terra,Zephyr"`).
- `DataLoaded` (true once the save is in).
- `DataError` (true only if a live server could not load the save).

### Edited scripts

| Script | Change |
|---|---|
| `ServerScriptService.SpellshotService` | Requires `PlayerData` and `EconomyConfig`. **LoadoutRequest "Element"** refuses an Element the player does not own and sends a Hub notice: "X is locked: unlock it in the Loadout menu for N Sparks", or "still loading" before the save is in. **Element on join:** the default (Cryo) only if owned; otherwise the first starter (Cryo always is one today). **devRemote:** three new actions, `EcoAddSparks` (+1000), `EcoUnlockAll` and `EcoReset`. The dev panel's `SetElement` still bypasses the gate. |
| `ServerScriptService.HubServer` | Requires `PlayerData`. The Element shrine's Bond refuses an unowned Element. That is 2 hunks; nothing in the match, queue or DuelMatch flow was touched. (The Observatory has no shrines today, so this path is dormant.) |
| `StarterPlayer.StarterPlayerScripts.LoadoutMenu` | **Locked cards:** a built Element you do not own shows a padlock badge on its icon, a dimmed icon, its price on the tag line (Sparks mark + amount) and a small ink **UNLOCK** button. UNLOCK's hit area is the card's whole right end, 52 px. **Browsing:** clicking the rest of a locked card does not equip it. The footer reads out its M1, Primary, Passive and Ultimate, plus "LOCKED: UNLOCK it for N Sparks". **Confirm:** UNLOCK opens an in-panel confirm (ink veil, paper slab) showing PRICE, YOU HAVE and AFTER. Its UNLOCK button invokes `EconomyRequest`, and the reply goes to the footer. **Short of Sparks:** the confirm reads "NOT ENOUGH SPARKS", shows STILL NEEDED in red, and says how many more and where to get them. Its button becomes **GET SPARKS** (gold), which opens the shop on its packs. **Balance:** the header's right end shows the balance (Sparks mark + amount + SPARKS). **Commands:** `Fire("unlock", name)` and `Fire("confirm")`. **Mark:** the Sparks mark is borrowed from the shop's `CardKit.sparksIcon`, not redrawn. |
| `StarterPlayer.StarterPlayerScripts.DevPanel` | New **ECONOMY** section: `+1000 SPARKS`, `UNLOCK ALL`, `RESET TO STARTER`, and an info line (SPARKS, LOADED, OWNED) that follows the attributes. |
| `StarterGui.SpellshotShop.ShopController` | **Balance:** the Sparks balance shows the live `Sparks` attribute, and the slab re-lays itself round the new width, keeping its right edge. **"+" button:** opens a **SPARKS PACKS** sheet with one row per pack (Sparks amount, Robux price, NOT ON SALE YET while `ProductId` is 0). A row with a `ProductId` calls `MarketplaceService:PromptProductPurchase`; otherwise a toast says "Sparks packs aren't on sale yet". **Toast:** a rise in Sparks while the shop is open shows "+N Sparks". **Command and attribute:** `Fire("sparks")`, and the `PacksOpen` attribute. The Robux balance placeholder is unchanged. |

**Not touched:**
- `SpellshotConfig` (read-only use of `Elements`, `IsBuilt`, `ApplyElement`, `DefaultLoadout`).
- `DuelMatch`, `CardKit`, `Catalog`, `ShopButton`, HUD round displays, the Cryo scripts, `Config.MayHurt`.

## The save

- **DataStore:** `SpellshotPlayerData`.
- **Key:** `p_<UserId>_v1` (versioned: a new shape gets a new key and migrates from this one).

```lua
{
  Version = 1,
  Sparks = 0,
  Owned = { [element] = true },        -- keyed by Element NAME, so event/collab Elements fit later
  Starter = { [element] = true },      -- what the starter kit has already granted, per Element
  Purchases = { [purchaseId] = { P = productId, S = sparks, T = os.time() } },
  PurchaseLog = { purchaseId, ... },   -- the last 200 receipts, oldest first
  Stats = { Wins, Losses, Draws, RoundsWon, Earned, Bought, Spent },
  Created = os.time(),
  Session = { Job = game.JobId, T = os.time() },   -- the session lock; nil once released
}
```

**Writes:**
- Always `UpdateAsync`.
- **Load:** on join, up to 5 tries, each in a `pcall`.
- **Autosave:** every 60 s. Each autosave also refreshes the lock.
- **Other saves:** on leave and in `BindToClose`.
- **At once:** an unlock, a reset and a Robux purchase each save straight away (coalesced, one write at a time per player).

**Session lock:**
- **On join:** if another server's fresh lock is on the save, the join waits (5 s between tries) and takes it on the last try.
- **Lock taken:** a server whose lock was taken stops writing that player.
- **In Studio:** the lock is taken at once.

**The starter kit:**
- Granted once per Element through the `Starter` record.
- A starter added to `EconomyConfig` later is given to everyone once.
- A starter removed from it is never taken back from anyone.

**Robux (`ProcessReceipt`, set only in `PlayerData`):**
- The `PurchaseId` is recorded in the same write that pays the Sparks.
- `PurchaseGranted` is returned only after that write succeeds; otherwise `NotProcessedYet`.
- A retried receipt finds its id and pays nothing.
- A product that is not a pack in `EconomyConfig` is left `NotProcessedYet` with a warning. Any future Robux product needs its own branch in `PlayerData.processReceipt`. Never set `ProcessReceipt` anywhere else, because the last writer wins.

**Studio with API access off:**
- One warning: "[PlayerData] DataStore unavailable…".
- After that, everything runs in memory: unlocks work, test purchases are granted, nothing is written.

**A live server that cannot load a save after every retry:**
- The player keeps the starter kit, with nothing saved.
- Unlocks and receipts are paused for that player, so nothing they pay for is lost.
- The player gets the `DataError` attribute.

## Placeholder numbers (all in `EconomyConfig`)

| What | Value | Note |
|---|---|---|
| Starter kit | Pyro, Zephyr, Cryo, Terra, Radiant | owner, locked |
| Aqua | 1,600 Sparks | 8 duel wins |
| Toxin | 1,800 | 9 wins |
| Umbra | 2,000 | 10 wins |
| Voltaic | 2,000 | 10 wins |
| Default price (any other Element) | 1,800 | |
| `NotForSale` | empty | the event/collab track goes here |
| Match: win / loss / draw | 150 / 50 / 75 | |
| Per round won | 10 | clamped at `MaxRoundsCounted` = 10 |
| A first-to-5 duel win | 150 + 5 × 10 = **200** | the yardstick for the prices |
| Pack: Pouch | 500 Sparks, 49 R$ | `ProductId = 0` |
| Pack: Satchel | 1,200 Sparks, 99 R$ | `ProductId = 0` |
| Pack: Chest | 2,600 Sparks, 199 R$ | `ProductId = 0` |
| Pack: Vault | 7,000 Sparks, 499 R$ | `ProductId = 0` |

`RobuxDisplay` is only what the shop prints. Roblox charges the Dashboard price and may show a player a lower regional
price.

## What the owner has to do

1. **Create the Developer Products.** Go to Creator Dashboard > the experience > Monetization > Developer Products. Make one product per pack, at the Robux price you want.
2. **Paste the ids.** Put each product's id into `EconomyConfig.SparksPacks[n].ProductId`, and set `RobuxDisplay` to the same price. A pack with `ProductId = 0` stays "not on sale yet".
3. **To test saving in Studio,** turn on Game Settings > Security > Enable Studio Access to API Services. Note that Studio then reads and writes the **real** saves (same universe): the dev panel's RESET TO STARTER resets your real save.
4. **Confirm or change the placeholder amounts above.**

## To take it out

- **Off switch, no code removed:** add `"Aqua", "Toxin", "Umbra", "Voltaic"` to `EconomyConfig.StarterElements`. Everyone then owns all nine. With saving on, this is granted into saves and stays there.
- **Everything at once:** paste `economy_2026_10_18\revert_economy_2026_10_18.luau` into the Edit command bar.
  - Run it with `DRY = true` first: it only prints what it would do. Then run it again with `false`.
  - It takes out only this pass's hunks from `SpellshotService` and `HubServer`, so the team-mode work in them stays.
  - It restores `LoadoutMenu`, `DevPanel` and `ShopController` from the backup.
  - It moves the three new scripts into the backup folder, disabled.
  - A dry run on 2026-10-18 rebuilt `SpellshotService` byte-identical to its backup, and found every `HubServer` hunk exactly once.
- **Just the three client scripts** (harmless alone, because the server still gates):

```lua
local folder = game.ServerStorage.EconomySuperseded_2026_10_18
local function resolve(path)
	local inst = game
	for part in path:gmatch("[^%.]+") do inst = inst and inst:FindFirstChild(part) end
	return inst
end
for _, name in { "LoadoutMenu", "DevPanel", "ShopController" } do
	local b = folder:FindFirstChild(name)
	local live = b and resolve(b:GetAttribute("OriginalPath"))
	if live then live.Source = b.Source end
end
```

Team Create's version history also has the place from before this pass.

## Checked

- **Compiles:** all 8 scripts (3 new, 5 edited) compile (wrapped-function `require`). `luau-analyze` found no unknown globals in any of them.
- **The modules load:** a fresh clone of `EconomyConfig` and of `PlayerData` each `require`s cleanly.
- **Headless harness** (luau CLI, a stubbed DataStore, Players and MarketplaceService, and a virtual clock): **48 / 48 checks pass**. They cover:
  - Starters before the load, and a match reward that arrives before the save merging into it.
  - Short / ok / owned / unknown buys.
  - Receipts:
    - paid once;
    - a retry pays nothing;
    - a failed save gives `NotProcessedYet`, then the retry is granted without paying twice;
    - an unknown product and an absent player are refused.
  - UNLOCK ALL is one coalesced write. Reset keeps the purchase records.
  - Leave saves and releases the lock, and a rejoin reloads.
  - A held lock: the join waits, then loads once released. A dead server's lock is taken on the last try.
  - A taken lock stops this server's writes and pauses spending.
  - A failed live load: starter kit, spending and receipts paused.
  - `BindToClose` releases every lock.
  - Studio with API off: memory only, exactly one warning.
- **Edit-mode build smoke tests with a stand-in player:**
  - **LoadoutMenu** builds without errors. With no attributes, Aqua is locked (1,600) and Cryo is not. With `OwnedElements` + Toxin, Toxin unlocks and Umbra shows 2,000. The header reads 500 with the Sparks mark drawn.
  - **The confirm:**
    - At 500 Sparks it shows NOT ENOUGH SPARKS, 1,100 still needed, and GET SPARKS.
    - When Sparks rise to 2,000 it refills to UNLOCK AQUA?, 400 after.
    - Confirming with no remote says so and closes.
    - With all owned, no locks remain.
  - **ShopController** builds. The balance follows the attribute (2,450 → 3,450) with the slab's right edge fixed. `Fire("sparks")` opens the sheet with 4 rows. The sheet survives a theme switch and closes with the shop.

## Not checked

- **Anything in Play.**
- **A real DataStore round trip.** I don't know whether Studio API access is on in this place.
- **Real Robux:** `PromptProductPurchase` and `ProcessReceipt` with real product ids (none exist yet).
- **Session locking** between two real servers.
- **`AwardMatch` from a real match end.** The team-mode session wires it. The command bar cannot test it: `require` there gets its own empty copy of `PlayerData`. Use a temporary Script in ServerScriptService instead.
- **The Hub notice** a refused LoadoutRequest sends. The menu never sends one for a locked Element, so it is only reachable by a forged request.
- **The shrine gate.** No shrines exist in the Observatory.
- **The look:**
  - the locked cards' 9–10 px text and small UNLOCK button at real scale and on touch;
  - the confirm and the packs sheet next to Quick Play.
- **`VoltaicTestHarness`** (`VoltTest = "loadout"`) now needs Voltaic owned. Set `VoltTest = "dev:EcoUnlockAll"` first.

## Review fixes on top of this build (18 October)

After this build, a review workflow confirmed defects in it, and the orchestrator fixed them in place. Each fixed line is marked "(2026-10-18 review)". `CHANGES_2026-10-18_handoff.md` lists every fix (the "Review fixes" table) and the Play-test results. Reverting from this build's backup folder also removes those fixes.
