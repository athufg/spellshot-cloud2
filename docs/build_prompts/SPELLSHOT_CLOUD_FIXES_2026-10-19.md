# SPELLSHOT cloud — fixes applied (2026-10-19)

## Status after all fix waves

This section is the per-finding status for the whole audit, after every fix wave. The sections further down are the
first batch's own write-up (commit `981173e`), kept as they were except for the not-fixed list, which is updated.

**Nothing has been run in Roblox Studio.** All checks were static: `luau-compile` on every changed script (re-run at
HEAD `7a473d3` over all 133 scripts the fixes changed: all compile), and a no-new-globals check with `luau-analyze`
after each wave. Every code edit is marked `(2026-10-19, audit <ID>)`. The Studio checks below are still to do.

The waves:
- `981173e`: the first batch (the "lead with these" items, saves, dev mode, Bulwark Wall, Cryo and Devil skins).
- `7615bc3`: wave 1, every remaining Medium and Low finding, worked by eight groups (logs `fixlog_G1..G8`).
- wave 2: commits `d015432` to `50aa555`, plus `7a473d3`. This covers the handoffs between groups, the movement guard
  (P1-03), the coordinator's follow-ups and the P5F-06 sweep for Aqua, Radiant and Umbra (logs `fix2log_G1..G8`,
  `residual_wave2.md`, `fix3log_P5F06.md`).

### Counts

The report has **297 finding entries**. After merging duplicates, that is **253 distinct findings** (15 High, 65
Medium, 173 Low). A duplicate entry takes the status of the finding it duplicates.

| Status | Entries (297) | Distinct (253) | Distinct by severity |
|---|---|---|---|
| FIXED | 231 | 192 | 15 High / 50 Medium / 127 Low |
| FIXED (doc/errata only) | 28 | 28 | 2 Medium / 26 Low |
| DESIGN (owner decision needed) | 23 | 22 | 10 Medium / 12 Low |
| DECIDED-BY-AUDIT (GC-07, P5E-10, P4-11) | 3 | 3 | 1 Medium / 2 Low |
| NOT-A-BUG / already fine | 2 | 2 | 2 Low |
| UNVERIFIABLE | 2 | 2 | 1 Medium / 1 Low |
| NOT FIXED, other reason | 8 | 4 | 1 Medium / 3 Low |
| **Total** | **297** | **253** | 15 High / 65 Medium / 173 Low |

What the buckets mean:
- **FIXED**: the code now does what the finding asked for. Some rows also say "open choice below". In those rows the
  bug is fixed, but a smaller rule question is left for the owner, listed under "Owner decisions still open".
- **FIXED (doc/errata only)**: the finding was stale text, and only text changed. Code comments and player-facing
  strings were corrected in place. Text in the manual, Dev Diary, HANDOFF.md, README and SFX plan is written as
  ready-to-paste items in `docs/build_prompts/SPELLSHOT_DOC_ERRATA_2026-10-19.md`, and its section 6 indexes them by
  finding. **Those documents themselves were not edited**: `tools/refresh.ps1` re-copies `docs/` from the owner's
  machine, so the owner has to paste the items.
- **DESIGN**: an owner decision is needed. The open part was not changed. A few of these rows had a harmless comment or
  one safe sub-item fixed, and the Where column names it.
- **DECIDED-BY-AUDIT**: the coordinator made these three calls, not the owner, and the owner may reverse them. The code
  comments say "an audit call the owner may reverse".
  - GC-07: roots beat Shadow Step, so a rooted, caged, Deep-Frozen or Entombed body is refused before it is paid.
  - P5E-10: the Skyrider gust is `NoUpdraft`.
  - P4-11: the Ring of Fire Desc now says the hotter ring needs Heat built with Heat Rush. Text only.
- **NOT-A-BUG**:
  - P5E-12: since P5F-10, Zephyr's uniform stays teal under Colourblind-Safe, so the body and the effects match.
  - P5F-27: restyling other players' cosmetics is client-local only, and the report itself asks for no fix.
- **UNVERIFIABLE** (Studio decides):
  - P5B-08: does the Obsidian Magma boulder's Highlight rim drop when about 31 Highlights are on screen? Bake a hull
    rim only if it does.
  - P5E-18: with 100-200 ms emulated ping and jitter, read `ShotStats.rej_early` against `hit_char`. If it stays near
    0, tighten Wind Blade's early-hit slack from 0.25 s to 0.12 s in ZephyrHandler.
- **NOT FIXED, other reason**:
  - P2-06 (and its duplicates P1-15, P5A-20, P6B-08): every cosmetic is free. This is feature work: cosmetic
    ownership in the save and Robux products. Do it before any skin is sold.
  - P5F-26: Aqua shares Zephyr's logo and role glyphs. This is an art task.
  - P6A-21: leftover instances in the place. This is a Studio edit: move or delete both `Workspace/Lighting` folders,
    `ViewmodelArm3`, the visible SpawnLocation slab and `OpenAcademyHub`; clear the `StageWrap`, `TGBuild`,
    `StashCamPos`, `StashCamLook` and `CapView` attributes; then re-export `manifest.json`.
  - P6A-10 (and its duplicate P6B-15): the ServerStorage "ReviewFix" folders hold pre-fix copies. There is no live bug.
    Rename them `_before_<fix>` or merge them into the Superseded backups in Studio.

**Cross-check passed.** A script (`scratchpad/status/check.py`) does three things:
- It reads every `#### <ID>:` heading in `SPELLSHOT_CLOUD_BUG_REPORT_2026-10-18.md`: 297 IDs, no repeats.
- It reads the ID column of the table below.
- It confirms that the two sets are equal, that each ID appears exactly once, and that each row's status is one of the
  seven buckets. The bucket counts it prints are the ones above.

### Every finding

Severity is the report's consolidated severity. A duplicate row shows its own entry's severity, marked "(entry)". "M1
handlers" means the Ability, Pyro, Zephyr, Terra, Aqua and Voltaic handlers. Errata items (OD-, M-, D-, E-, H-, R-,
S-) are in `SPELLSHOT_DOC_ERRATA_2026-10-19.md`.

| ID | Severity | Short title | Status | Where (files) | Commit wave |
|---|---|---|---|---|---|
| P1-01 | High | Shot origin check trusts client speed and ping (fire from anywhere) | FIXED | CombatCore; all nine Element handlers | 981173e |
| P1-02 | High | Dev mode live in ranked: free Ultimate, unlimited Sparks | FIXED | SpellshotService | 981173e |
| P1-03 | High | The server enforced no movement at all | FIXED | CombatCore, SpellshotConfig, SpellshotService, HubServer, AbilityHandler, TerraHandler, RadiantHandler, UmbraHandler, AquaHandler, ElementalReactions | wave 2 |
| P1-04 | High | Training Ground in the ranked map vote | FIXED | MapRegistry, HubServer, TrainingGround | 981173e |
| P1-05 | High | Temporary stage scripts ship ungated | FIXED | _AuroraStage, _BROStage, _AuroraStageClient, _BROStageClient | 981173e |
| P1-06 | Medium (entry) | Forfeit pays the full win reward | FIXED (dup of P2-05) | see P2-05 | 981173e |
| P1-07 | Medium | No rate limit on CastRequest / IceAbilityRemote | FIXED | SpellshotService, CombatCore, MovementModeServer, TerraHandler, RadiantHandler, SettingsStore | 7615bc3 + wave 2 |
| P1-08 | Medium | Patient Zero double-cast under Deferred signals | FIXED | SpellshotService, ToxinHandler | 7615bc3 + wave 2 |
| P1-09 | Medium | Aimed areas placed through walls (no line of sight) | FIXED | AbilityHandler, PyroHandler, ZephyrHandler, ZephyrGustPadServer, AquaHandler, ToxinHandler, VoltaicHandler | 7615bc3 + wave 2 |
| P1-10 | Medium | Bulwark Charge runs its full window; accepted while rooted | FIXED | TerraHandler, SpellshotInput | 7615bc3 + wave 2 |
| P1-11 | Low | NaN shot Id errors in release handlers | FIXED | AbilityHandler, PyroHandler, ZephyrHandler, AquaHandler, UmbraHandler | 7615bc3 + wave 2 |
| P1-12 | Medium | M1 hit remotes never pay mana | FIXED | SpellshotService, CombatCore, M1 handlers, VoltaicClient | 981173e |
| P1-13 | Low | Sidearm drawn shot / Cross-Slash strike ignore interrupts | FIXED | AquaHandler, ZephyrHandler | 7615bc3 + wave 2 |
| P1-14 | Low | Gust Pad / Position Trade act on Solo strangers | FIXED | ZephyrGustPadServer, RadiantHandler, SpellshotConfig (Desc) | 7615bc3 + wave 2 |
| P1-15 | Low (entry) | Skin/wrap ownership gate is a stub | NOT FIXED (dup of P2-06) | see P2-06 | 7615bc3 |
| P1-16 | Low | Relays forward NaN-unsafe client numbers | FIXED | TerraHandler | 7615bc3 |
| P1-17 | Low (entry) | GiveBack refunds whatever is in the slot now | FIXED (dup of P4-08) | see P4-08 | 7615bc3 |
| P1-18 | Low (entry) | Hitting a Decoy or Bulwark Wall charges Ultimate | DESIGN (dup of P3-09) | see P3-09 | 7615bc3 |
| P1-19 | Low | Hub shrine could change Element mid-match (dormant) | FIXED | HubServer | 7615bc3 |
| P2-01 | High | Same-server rejoin races the leave save | FIXED | PlayerData | 981173e |
| P2-02 | Medium | Server keeps writing after its lock was taken | FIXED | PlayerData | 981173e |
| P2-03 | Low | Writes after the leave save re-lock the record | FIXED | PlayerData | 981173e |
| P2-04 | Medium | Live server without its DataStore runs memory-only | FIXED | PlayerData | 981173e |
| P2-05 | Medium | Forfeit wins pay with no participation minimum | FIXED | DuelMatch | 981173e |
| P2-06 | Medium | Every cosmetic is free (OwnsSkin always true) | NOT FIXED: feature work (cosmetic ownership + Robux products) | EconomyConfig (header note only) | 7615bc3 |
| P2-07 | Medium (entry) | Dev economy tools live on public servers | FIXED (dup of P1-02) | see P1-02 | 981173e |
| P2-08 | Medium | Failed settings load saves defaults over real settings | FIXED | SettingsStore | 7615bc3 |
| P2-09 | Low | Settings changed before the load arrives are lost | FIXED | SettingsStore, SpellshotSettings, SettingsRuntime | 7615bc3 |
| P2-10 | Low | Settings leave/close writes single-shot, can double-write | FIXED | SettingsStore | 7615bc3 |
| P2-11 | Low | Stage scripts push partial settings tables | FIXED | _AuroraStage, _BROStage (P1-05's Studio gate) | 981173e |
| P2-12 | Low (entry) | Colourblind palette: no Aqua, moves too many Elements | FIXED (dup of P5F-10) | see P5F-10 | 981173e |
| P2-13 | Low | Shop sells Sparks packs while the save is unavailable | FIXED | ShopController, PlayerData | 7615bc3 |
| P2-14 | Low | Failed-profile Sparks shown as earned; AwardMatch misreports | FIXED | PlayerData, LoadoutMenu | 7615bc3 |
| P2-15 | Low (entry) | All-draw team matches never end | FIXED (dup of P3-13) | see P3-13 | 7615bc3 + wave 2 |
| P2-16 | Low | Unknown save fields dropped; no version check | FIXED | PlayerData | 7615bc3 |
| P2-17 | Low | Autosave piles up writers during an outage | FIXED | PlayerData | 7615bc3 |
| P2-18 | Low | Economy doc drift (manual vs code vs shop data) | FIXED (doc/errata only); open choice below | errata OD-5, M-44, M-52, M-54, M-65, M-66, M-69, M-79-M-81; EconomyConfig, HubServer | 7615bc3 + wave 2 |
| P3-01 | Medium | A reaction kill fires OnKill twice | FIXED | CombatCore, PyroHandler | 7615bc3 + wave 2 |
| P3-02 | High (entry) | Training Ground in the match vote | FIXED (dup of P1-04) | see P1-04 | 981173e |
| P3-03 | Medium | Toxin's own cloud takes over an enemy's poison | FIXED | StatusEffects | 7615bc3 |
| P3-04 | Medium | Flash Freeze shatters everyone it ever rooted | FIXED | AbilityHandler | 7615bc3 |
| P3-05 | Medium | BreakRoot ends Cryo prison/cage silently | FIXED; open choice below | AbilityHandler | 7615bc3 |
| P3-06 | Low | Two writers of RX_Staggered cut each other short | FIXED | TerraHandler, ElementalReactions | 7615bc3 + wave 2 |
| P3-07 | Medium | A leaver's effects keep landing in their name | FIXED | CombatCore, DuelMatch, SpellshotService, PyroHandler | 7615bc3 + wave 2 |
| P3-08 | Medium (entry) | Patient Zero cast twice for one charge | FIXED (dup of P1-08) | see P1-08 | 7615bc3 + wave 2 |
| P3-09 | Low | Ultimate charge from walls, decoys, dummies, self-damage | DESIGN | CombatCore (dead Team clause only) | 7615bc3 |
| P3-10 | Low | Reactions fire on self-hits and fully soaked hits | FIXED; open choice below | ElementalReactions | 7615bc3 |
| P3-11 | Low (entry) | Sidearm / Cross-Slash accepted while interrupted | FIXED (dup of P1-13) | see P1-13 | 7615bc3 + wave 2 |
| P3-12 | Low | Undertow shortens a longer running interrupt | FIXED | AquaHandler | 7615bc3 |
| P3-13 | Low | All-draw matches never end | FIXED; open choice below | SpellshotConfig (Duel.MaxRounds), DuelMatch, HubClient | 7615bc3 + wave 2 |
| P3-14 | Low | Combat live through MatchEndHold; dead respawn into the arena | FIXED | DuelMatch, HubServer | 7615bc3 |
| P3-15 | Low | Death ordering and the 1 ms draw window | FIXED | CombatCore, DuelMatch | 7615bc3 |
| P3-16 | Low | Hitbox twins widen HumanoidsNear areas | DESIGN | HitboxScale (header note only) | 7615bc3 |
| P3-17 | Low | Derived damage spends the Mark and gets Updraft's bonus | FIXED | UmbraHandler, ZephyrUpdraftServer | 7615bc3 + wave 2 |
| P3-18 | Low (entry) | Gust Pad / Position Trade own party rule | FIXED (dup of P1-14) | see P1-14 | 7615bc3 + wave 2 |
| P3-19 | High (entry) | Dev free Ultimate in live ranked matches | FIXED (dup of P1-02) | see P1-02 | 981173e |
| P3-20 | Low | Dev Heal revives a dead humanoid | FIXED | SpellshotService | 7615bc3 |
| P3-21 | Low | Bulwark Charge knock writes velocity on client-owned roots | FIXED | TerraHandler | 7615bc3 |
| P3-22 | Low | GiveBack's Ultimate refund reads a stale CastUlt | FIXED | SpellshotService | 7615bc3 |
| P3-23 | Low | Blessed bookkeeping; zone glow ignores Reduce Flashing | FIXED | StatusReactions | 7615bc3 |
| P3-24 | Low | Combat-state doc drift | FIXED (doc/errata only) | CombatCore, StatusEffects, ElementalReactions, SpellshotConfig, TrainingGround, RadiantHandler; errata M-34 | 7615bc3 + wave 2 |
| P4-01 | High | Skyrider: free Tomb escape and Ultimate farm | FIXED | VFXLibrary, ZephyrSkyriderServer, SpellshotConfig (Entombed text) | 981173e + wave 2 |
| P4-02 | Medium | Honest Zephyr cannot Skyrider out of Earthen Tomb | DESIGN | SpellshotConfig (Entombed text records the code) | wave 2 |
| P4-03 | Medium | Tomb escape rule keys off the pool half | DESIGN | SpellshotConfig (Entombed text only) | 7615bc3 + wave 2 |
| P4-04 | Medium | Updraft bonus granted by enemy crowd control | FIXED | ZephyrUpdraftServer, ZephyrUpdraft, ZephyrHandler, TerraHandler, ZephyrGustPadServer, ZephyrSkyriderServer, AquaHandler, ElementalReactions | 7615bc3 + wave 2 |
| P4-05 | Medium | An interrupt cracks a held Scorching Lash | FIXED | AquaHandler, TerraHandler, SpellshotService, PyroHandler | 7615bc3 + wave 2 |
| P4-06 | Low | Aftershock's interrupt never reaches the victim's client | FIXED | TerraHandler | 7615bc3 |
| P4-07 | Low | Held Techniques survive a loadout change | FIXED | SpellshotService | 7615bc3 |
| P4-08 | Low | Cooldown / give-back keyed by slot, not ability | FIXED | SpellshotService | 7615bc3 |
| P4-09 | Low (entry) | Dev tools change Element mid-duel | FIXED (dup of P1-02) | see P1-02 | 981173e |
| P4-10 | Low | Loadout Technique rows inert for 8 of 9 Elements | FIXED; open choice below | LoadoutMenu | 7615bc3 |
| P4-11 | Low | Ring of Fire's Hot variant needs Heat Rush, not in Pyro's defaults | DECIDED-BY-AUDIT | SpellshotConfig (Desc) | wave 2 |
| P4-12 | Low | Decoy fools some target locks but not others | DESIGN | none | - |
| P4-13 | Low | Ring of Fire burn / Cyclone AIRBORNE land on a Bulwark Wall | FIXED | PyroHandler, ZephyrHandler | 7615bc3 |
| P4-14 | Low | Comments still describe the cross-Element pool | FIXED (doc/errata only) | SpellshotConfig, SpellshotService, AbilityHandler, PyroHandler, TerraHandler, VFXLibrary, DevPanel (code text only) | 7615bc3 + wave 2 |
| P4-15 | Low | (latent) Borrowed Acid Rain / Vent wear the Toxin wrap | FIXED | ToxinWrap | 7615bc3 |
| P4-16 | Medium | (latent) Shared SpeedCapUlt / RX_Shielded writers clash | DESIGN | none | - |
| P4-17 | Low | (latent) Borrowed Cinder Shield locks the M1 | FIXED; open choice below | SpellshotInput, ToxinClient | 7615bc3 + wave 2 |
| P4-18 | Low | (latent) Borrowed Decoy Double easy to spot | DESIGN | UmbraHandler (DecoyElement attribute only) | wave 2 |
| P4-19 | Low | (latent) Borrowed-Technique presentation gaps | FIXED; open choice below | RadiantClient | 7615bc3 |
| P4-20 | Low | Cold Momentum / Riding the Current clobber MoveSpeedMult | FIXED | AbilityHandler, AquaHandler | 7615bc3 + wave 2 |
| P5A-01 | Critical (entry) | Aurora / BRO staging scripts ungated | FIXED (dup of P1-05) | see P1-05 | 981173e |
| P5A-02 | High | Snow Globe Blizzard pines hide players | FIXED | SnowGlobeFX, SnowGlobeKit | 981173e |
| P5A-03 | High | Frost Dragon claw clearer on the caster's screen only | FIXED | FrostDragonFX | 981173e |
| P5A-04 | Medium | Frost Dragon frost-over fakes a freeze on allies | FIXED | FrostDragonFX | 7615bc3 |
| P5A-05 | Medium | Frost Dragon Blizzard thins the storm wall | FIXED | FrostDragonFX | 7615bc3 |
| P5A-06 | Medium | Snow Globe M1 hit calls `shards` before it exists | FIXED | SnowGlobeFX, CryoFX | 981173e |
| P5A-07 | Medium | Lotus / Globe shatters error | FIXED | CryoFX, FrostLotusKit | 981173e |
| P5A-08 | Medium | Skins set Built when kinds failed | FIXED | FrostbladeKit, FrostLotusKit, SnowGlobeKit | 981173e |
| P5A-09 | Medium | Cryo flashes ignore Reduce Flashing | FIXED | CryoFX, FrostDragonFX | 7615bc3 |
| P5A-10 | Medium | No Cryo effect reads Colourblind-Safe; wraps shift the zone edge | DESIGN | none | - |
| P5A-11 | Medium | Sakura Frost hides the frozen crust | FIXED | CryoWrap | 7615bc3 |
| P5A-12 | Low | Reduce Enemy VFX / quality uneven on Cryo skin pieces | FIXED | CryoFX, FrostDragonFX, FrostLotusFX, SnowGlobeFX, VFXLibrary | 7615bc3 + wave 2 |
| P5A-13 | Low | One Mirror Cage hook error freezes the cage | FIXED | CryoFX | 7615bc3 |
| P5A-14 | Low | Frost Lotus held parts leak on removal | FIXED | FrostLotusKit | 7615bc3 |
| P5A-15 | Low | Frostblade cage draws no dome for an absent caster | FIXED | CryoFX | 7615bc3 |
| P5A-16 | Low | Kill effect yields inside CryoWrap's palette swap | FIXED | FrostDragonKillFX | 7615bc3 |
| P5A-17 | Low | CryoFX 2 locals from the 200 limit | FIXED | CryoFX | 7615bc3 |
| P5A-18 | Low | Wraps/skins change shot and zone geometry (manual forbids) | DESIGN | SkinCatalog (header note); errata OD-7, M-58 | 7615bc3 + wave 2 |
| P5A-19 | Low | Black Ice gated on Roblox's own quality slider | FIXED | CryoWrap | 7615bc3 |
| P5A-20 | Low (entry) | Any client can equip the Mythic Frost Dragon | NOT FIXED (dup of P2-06) | see P2-06 | 7615bc3 |
| P5A-21 | Low | Frost Dragon kill swoop drawn for everyone | FIXED | FrostDragonKillFX | 7615bc3 |
| P5A-22 | Low | Skin zone rims sit outside the real edge | FIXED; open choice below | FrostDragonFX, CryoFX, SnowGlobeFX | 7615bc3 |
| P5A-23 | Low | Cryo cosmetics doc drift | FIXED (doc/errata only) | SkinCatalog, SnowGlobeKit, SnowGlobeFX, CryoFX, FrostLotusKit, CryoWrap; errata OD-7, M-57, M-63 | 7615bc3 + wave 2 |
| P5B-01 | Medium | Toon Ring of Fire drawn smaller than the burn | FIXED | PyroFX | 7615bc3 |
| P5B-02 | Medium | Colourblind-Safe never reaches Pyro/Terra/Toxin effects | DESIGN | none | - |
| P5B-03 | Medium | Wraps repaint hazards in other Elements' colours | DESIGN | none | - |
| P5B-04 | Medium | Toxin (and toon Pyro) ignore quality / Reduce Enemy VFX | FIXED | ToxinFX, ToxinWrap, PyroFX | 7615bc3 |
| P5B-05 | Medium | Pyro/Terra/Toxin strobes ignore Reduce Flashing | FIXED | ToxinFX, PyroDraw, PyroFX, TerraFX, TerraFX_Wall, ChargedRock | 7615bc3 |
| P5B-06 | Medium (entry) | Reduce Enemy VFX thins allies (Pyro/Terra/Toxin) | FIXED (dup of P5F-06) | see P5F-06 | 7615bc3 + wave 2 |
| P5B-07 | Medium | Tomb fissure telegraph too thin; vanishes on LOW | FIXED; open choice below | TerraFX_Tomb | 7615bc3 |
| P5B-08 | Medium | Obsidian Magma rim is a Highlight (on-screen cap) | UNVERIFIABLE | none | - |
| P5B-09 | Low | Toxin mesh build partly pcall'd and synchronous | FIXED | ToxinFX | 7615bc3 |
| P5B-10 | Low | ToxinFX keeps resizable EditableMeshes | FIXED | ToxinFX | 7615bc3 |
| P5B-11 | Low | Deferred Toxin pieces lose the wrap colours | FIXED | ToxinFX, ToxinWrap | 7615bc3 |
| P5B-12 | Low | Dead ToxinFX wrap branches; stale catalog comment | FIXED | ToxinFX, SkinCatalog | 7615bc3 + wave 2 |
| P5B-13 | Low | AzureFlame offered where nothing draws it | FIXED | SkinCatalog | 7615bc3 |
| P5B-14 | Low | Pyro wrap lights switch before the flames exist | FIXED | PyroDraw | 7615bc3 |
| P5B-15 | Medium (entry) | Wrap staging scripts ungated | FIXED (dup of P1-05) | see P1-05 | 981173e |
| P5B-16 | Low | Terra debris halved with Reduce Enemy VFX off | FIXED | TerraFX, TerraFX_Tomb | 7615bc3 |
| P5B-17 | Low | Wall hooks drop the server's T0 | FIXED | AbilityFX, TerraFX | 7615bc3 + wave 2 |
| P5B-18 | Low | Toxin / Pyro / Terra lifecycle leaks | FIXED | ToxinFX, ToxinWrap, PyroFX, TerraFX | 7615bc3 |
| P5B-19 | Low | Aftershock plate pool thrashes | FIXED | TerraFX | 7615bc3 |
| P5B-20 | Low | Settings plumbing fragility in this slice | FIXED | ToxinWrap, TerraWrap, SettingsRuntime | 7615bc3 + wave 2 |
| P5C-01 | High | Colourblind-Safe skips the Decoy Double | FIXED | SettingsRuntime | 981173e |
| P5C-02 | High | Devil skin has no fallback while forms are unbuilt | FIXED | RadiantDevilForge, RadiantFX_Staff, RadiantFX_Hand, RadiantClient | 981173e |
| P5C-03 | Medium | Devil skin makes Radiant's tells much darker | DESIGN | none | - |
| P5C-04 | Medium | Bloodmoon changes what the opponent sees | DESIGN | none | - |
| P5C-05 | Medium | Position Trade precheck detects decoys | FIXED; open choice below | RadiantHandler, UmbraHandler | 7615bc3 |
| P5C-06 | Medium (entry) | Checkpoint stage scripts ungated | FIXED (dup of P1-05) | see P1-05 | 981173e |
| P5C-07 | Medium | Radiant / Umbra ignore Reduce Flashing | FIXED | RadiantDraw, RadiantFX_Staff, RadiantFX_Hand, UmbraFX | 7615bc3 |
| P5C-08 | Medium (entry) | Graphics Quality ignored by Radiant / Umbra | FIXED (dup of P5F-05) | see P5F-05 | 7615bc3 |
| P5C-09 | Medium (entry) | Reduce Enemy VFX ignored by Radiant / Umbra | FIXED (dup of P5F-05) | see P5F-05 | 7615bc3 |
| P5C-10 | Medium (entry) | Safe palette: Zephyr ~ Radiant, Aqua gold | FIXED (dup of P5F-10) | see P5F-10 | 981173e |
| P5C-11 | Medium | Eclipse darkness can be skipped with Brightness | FIXED | UmbraFX, SettingsRuntime | 7615bc3 + wave 2 |
| P5C-12 | Low | Overflow broadcast wears the recipient's skin | FIXED | RadiantHandler | 7615bc3 |
| P5C-13 | Low | Eclipse reveal survives a respawn | FIXED | UmbraClient | 7615bc3 |
| P5C-14 | Medium | (latent) Decoy copies easy to tell for non-Umbra casters | DESIGN | UmbraHandler (DecoyElement attribute only) | wave 2 |
| P5C-15 | Low | Docs say skins are colour-only and Flat alpha-blended | FIXED (doc/errata only) | SkinCatalog, RadiantDraw, SpellshotService (code text only) | 7615bc3 + wave 2 |
| P5C-16 | Low (entry) | _BROStage partial settings payloads | FIXED (dup of P2-11) | see P2-11 | 981173e |
| P5C-17 | Low | Mark anchors table holds strong references | FIXED | UmbraClient | 7615bc3 |
| P5C-18 | Low | Devil crack-path cache thrashes | FIXED | RadiantDevilForge | 7615bc3 |
| P5C-19 | Low | RadiantFX_Hand at 192 of 200 locals | FIXED (doc/errata only) | RadiantFX_Hand (comment) | 7615bc3 |
| P5D-01 | Medium (entry) | Colourblind-Safe paints Aqua gold | FIXED (dup of P5F-09) | see P5F-09 | 981173e |
| P5D-02 | Medium | Aqua honours none of the four settings | FIXED | AquaFX, AquaClient | 7615bc3 + wave 2 |
| P5D-03 | Medium | Cascade flashes under Reduce Flashing | FIXED | CascadeFX | 7615bc3 |
| P5D-04 | Low | Chain Bolt / Overcharge / Volt Orb flicker | FIXED | ChainBoltFX, OverchargeFX, VoltOrbFX | 7615bc3 |
| P5D-05 | Low | Enemy Volt Orb bloom and punch at full strength | FIXED | VoltOrbFX | 7615bc3 |
| P5D-06 | Low (entry) | Reduce Enemy VFX thins teammates' Voltaic effects | FIXED (dup of P5F-06) | see P5F-06 | 7615bc3 + wave 2 |
| P5D-07 | Low | Own Voltaic particles halved on LOW + Reduce Enemy VFX | FIXED | VoltaicClient, VoltOrbFX, VoltaicKit | 7615bc3 |
| P5D-08 | Medium | Twin Tide / Maw collision depends on the look loading | FIXED; open choice below | AquaFX, AquaClient | wave 2 |
| P5D-09 | Medium | Maw / Twin Tide colliders never end on reset | FIXED | AquaHandler, AquaFX, AquaClient | 7615bc3 + wave 2 |
| P5D-10 | Low | Volt Orb aim arc survives death / focus loss | FIXED | VoltaicClient, SpellshotInput | 7615bc3 + wave 2 |
| P5D-11 | Low | Cascade strike prediction disagrees with the server | FIXED | CascadeFX | 7615bc3 |
| P5D-12 | Low | Cascade zone has no ground footprint | DESIGN | none | - |
| P5D-13 | High (entry) | Chain Bolt damage without the paid M1 | FIXED (dup of P1-12) | see P1-12 | 981173e |
| P5D-14 | Low | CascadeFX headroom header wrong | FIXED (doc/errata only) | CascadeFX (header) | 7615bc3 |
| P5D-15 | Low | CascadeEnd dropped during the first load | FIXED | CascadeFX, VoltaicFX | 7615bc3 |
| P5D-16 | Low | Twin Tide debug probe ships on | FIXED | AquaFX | 7615bc3 |
| P5D-17 | Low | Stuck Railspike windup on a late answer | FIXED | VoltaicClient | 7615bc3 |
| P5D-18 | Low | Voltaic / Aqua settings and kit doc drift | FIXED (doc/errata only) | VoltaicTuning, VoltOrbFX, VoltaicClient, CascadeFX; errata OD-10, M-03, M-14 | 7615bc3 + wave 2 |
| P5D-19 | Low | VoltaicTestHarness stale timings (Studio only) | FIXED | VoltaicTestHarness | wave 2 |
| P5D-20 | Low | ~940 lines of unwired Ground Surge v3 | DESIGN | none | - |
| P5E-01 | Medium | Cyclone pull area mostly invisible | FIXED | ZephyrFX_Cyclone | 7615bc3 |
| P5E-02 | Medium (entry) | Safe palette: Zephyr ~ Radiant | FIXED (dup of P5F-10) | see P5F-10 | 981173e |
| P5E-03 | Medium | Skyrider bird strobes under Reduce Flashing | FIXED | ZephyrFX_Skyrider | 7615bc3 |
| P5E-04 | Medium | Ally and enemy Gust Pads look identical; "friend or foe" text | FIXED | ZephyrGustPadServer, ZephyrGustPad, SpellshotConfig (Desc) | 7615bc3 + wave 2 |
| P5E-05 | Low (entry) | Reduce Enemy VFX thins allies (Zephyr) | FIXED (dup of P5F-06) | see P5F-06 | 7615bc3 + wave 2 |
| P5E-06 | Low | Wind Blade canvases read settings once | FIXED | ZephyrDraw | 7615bc3 |
| P5E-07 | Low | Incoming Wind Blades can go undrawn | FIXED | ZephyrFX_WindBlade | 7615bc3 |
| P5E-08 | Low | Others' Wind Blades drawn off the shot line | FIXED | AbilityFX | 7615bc3 |
| P5E-09 | Low | Skyrider gust drawn narrower than its hit cone | FIXED | ZephyrSkyrider, ZephyrFX_Skyrider | 7615bc3 |
| P5E-10 | Low | Updraft x1.25 on the Skyrider gust, tell hidden | DECIDED-BY-AUDIT | ZephyrSkyriderServer | wave 2 |
| P5E-11 | Low | Gust Pad / Cyclone flashes under Reduce Flashing | FIXED | ZephyrGustPad, ZephyrFX_Cyclone | 7615bc3 |
| P5E-12 | Low | No Zephyr VFX honours Colourblind-Safe | NOT-A-BUG | none | - |
| P5E-13 | Low | A late-loading Zephyr piece never gets broadcasts | FIXED | AbilityFX, ZephyrClient | 7615bc3 + wave 2 |
| P5E-14 | Low | ZephyrDraw at exactly 200 locals | FIXED | ZephyrDraw | 981173e |
| P5E-15 | Low | Gust Pad placed through walls / onto upper floors | FIXED | ZephyrGustPadServer | 7615bc3 |
| P5E-16 | Low | Skyrider flight client-trusted | DESIGN | none (P1-03's guard covers flat speed) | - |
| P5E-17 | Low | Updraft airborne check trusts client position | DESIGN | none | - |
| P5E-18 | Low | Wind Blade hits accepted up to 0.25 s early | UNVERIFIABLE | none | - |
| P5E-19 | Low | Late joiner never sees a live Gust Pad | FIXED | ZephyrGustPadServer, ZephyrGustPad | 7615bc3 + wave 2 |
| P5E-20 | Low | Zephyr Technique doc drift | FIXED (doc/errata only) | DeflectPractice; errata M-15, M-18, M-43, M-83 | 7615bc3 + wave 2 |
| P5E-21 | Low | CycloneActive fallback look treated as not yours | FIXED | ZephyrFX_Cyclone | 7615bc3 |
| P5E-22 | Low | Graphics Quality ignores Zephyr Beam counts | FIXED | ZephyrDraw | 7615bc3 |
| P5F-01 | High (entry) | Stage scripts ungated (settings slice) | FIXED (dup of P1-05) | see P1-05 | 981173e |
| P5F-02 | High | Third-person toggle for every player | FIXED | FirstPersonController | 981173e |
| P5F-03 | Medium | Reduce Flashing unread by Umbra/Radiant/Aqua/VFXLibrary/DeathFX/viewmodel | FIXED | UmbraFX, RadiantDraw, AquaFX, VFXLibrary, DeathFX, Viewmodel | 7615bc3 + wave 2 |
| P5F-04 | Medium | Status bars ignore Status Intensity / Reduce Flashing | FIXED | BarFX, primed_t/a/f | 7615bc3 |
| P5F-05 | Medium | Quality / Reduce Enemy VFX unread by Umbra, Aqua, Radiant | FIXED | UmbraFX, AquaFX, RadiantDraw, RadiantFX_Staff, RadiantFX_Hand | 7615bc3 |
| P5F-06 | Medium | Reduce Enemy VFX thins teammates ("enemy" = not me) | FIXED | VFXLibrary (IsEnemy); every Element's FX modules; AbilityFX, SettingsMenu | 7615bc3 + wave 2 |
| P5F-07 | Low | Shared hazards thinned as enemy | FIXED | ZephyrGustPad, CryoFX | 7615bc3 |
| P5F-08 | Medium | Colourblind-Safe repaints only uniforms | FIXED (doc/errata only) | SettingsMenu, SpellshotSettings (text) | 7615bc3 |
| P5F-09 | Medium | Aqua missing from the colourblind palette | FIXED | SpellshotSettings | 981173e |
| P5F-10 | Medium | Safe palette moves five Elements; Zephyr ~ Radiant | FIXED | SpellshotSettings | 981173e |
| P5F-11 | Low | Colourblind repaint lost after an Element change | FIXED | UniformAvatar, SettingsRuntime | 7615bc3 |
| P5F-12 | Medium (entry) | DataStore read failure resets settings | FIXED (dup of P2-08) | see P2-08 | 7615bc3 |
| P5F-13 | Medium | Hub / map forces GlobalShadows on | FIXED | SpellshotSettings, SettingsRuntime, HubClient | 7615bc3 |
| P5F-14 | Low | Graphics Quality tiers inconsistent | DESIGN | none | - |
| P5F-15 | Low | CryoWrap reads ThinEnemyVFX through Get (always nil) | FIXED | CryoWrap | 7615bc3 |
| P5F-16 | Low | Pooled looks never pick up a quality change | FIXED | VFXLibrary | 7615bc3 |
| P5F-17 | Low (entry) | Early setting change discarded by Load | FIXED (dup of P2-09) | see P2-09 | 7615bc3 |
| P5F-18 | Low | HUD key chips hard-coded F/Q/E/R | FIXED | PopArtHUD, SpellshotSettings | 7615bc3 |
| P5F-19 | Low | Text Size lost on tab switch | FIXED | SettingsMenu | 7615bc3 |
| P5F-20 | Low | Settings UI and palette doc drift | FIXED (doc/errata only) | SettingsMenu, SpellshotSettings, Callouts, SkinCatalog, IconAssets (code text only) | 7615bc3 |
| P5F-21 | Low (entry) | Partial SettingsSync resets other settings | FIXED (dup of P2-11) | see P2-11 | 981173e |
| P5F-22 | Low | SkinCatalog consistency gaps | DESIGN | SkinCatalog (Frostblade rarity, two comments) | 7615bc3 |
| P5F-23 | Low | Frost Dragon M1 look not painted by a wrap | FIXED | VFXLibrary | 7615bc3 |
| P5F-24 | Low | Wraps change hazard visibility | DESIGN | none | - |
| P5F-25 | Low | AbilityFX small leaks and races | FIXED | AbilityFX | 7615bc3 |
| P5F-26 | Low | Aqua shares Zephyr's logo and role glyphs | NOT FIXED: art task (Aqua icons) | none | - |
| P5F-27 | Low | A client can restyle others' cosmetics locally | NOT-A-BUG | none | - |
| P5F-28 | Low | FOV startup race | FIXED | FirstPersonController | 7615bc3 |
| P5F-29 | Low | VFXLibrary local headroom | FIXED | VFXLibrary (via GB-04) | 7615bc3 |
| P6A-01 | High (entry) | Stage client scripts ungated | FIXED (dup of P1-05) | see P1-05 | 981173e |
| P6A-02 | High (entry) | Stage server scripts ungated | FIXED (dup of P1-05) | see P1-05 | 981173e |
| P6A-03 | High (entry) | Dev powers in live public servers | FIXED (dup of P1-02) | see P1-02 | 981173e |
| P6A-04 | Medium | RunningOnly enforced only on the client | FIXED | SpellshotService, MovementModeServer | 7615bc3 |
| P6A-05 | High | Dashes pass through the Bulwark Wall | FIXED | DashMotor, ZephyrSkyrider, ZephyrFX_WindBlade, ZephyrFX_CrossSlash, CombatCore, ZephyrHandler, TerraHandler, ZephyrSkyriderServer | 981173e |
| P6A-06 | Medium | Retired hub's spawn never disabled | FIXED | HubServer | 7615bc3 |
| P6A-07 | Medium | Sakura Row windows never reset | FIXED | ShojiBreak | 7615bc3 |
| P6A-08 | Medium | MatchHUD_RETIRED still an active LocalScript | FIXED | MatchHUD_RETIRED | 7615bc3 |
| P6A-09 | Low | Slot flash looks up the retired HUD | FIXED | SpellshotInput | 7615bc3 |
| P6A-10 | Low | ReviewFix folders hold the pre-fix copies | NOT FIXED: Studio housekeeping, no live bug | none (ServerStorage folders, a Studio rename) | - |
| P6A-11 | Low | Hub flicker ignores Reduce Flashing / quality | FIXED | HubFireFlicker, HubLanternFlicker, HubWaterFlow, HubBannerWave | 7615bc3 |
| P6A-12 | Low | HubFireFlicker re-gathers a modulated colour | FIXED | HubFireFlicker, HubBannerWave | 7615bc3 |
| P6A-13 | Low | Lantern panes freeze after streaming | FIXED | HubLanternFlicker | 7615bc3 |
| P6A-14 | Low | Dead Ley animation in HubClient | FIXED | HubClient | 7615bc3 |
| P6A-15 | Low | TerraTestServer / TerraTestHarness ungated | FIXED | TerraTestServer, TerraTestHarness | 7615bc3 + wave 2 |
| P6A-16 | Low | Queued Shadow Step skips the CC re-check | FIXED | UmbraHandler | 7615bc3 |
| P6A-17 | Low | MapVote binds its cursor step twice | FIXED | MapVote | 7615bc3 |
| P6A-18 | Low | QuickPlay queue state desyncs under throttle | FIXED | QuickPlay | 7615bc3 |
| P6A-19 | Low (entry) | Quick Play cards drift from the manual | FIXED (dup of P6B-06) | see P6B-06 | 7615bc3 + wave 2 |
| P6A-20 | Low | Stale text in ReactionsBoard, MapRegistry, SlideAudio | FIXED; open choice below | ReactionsBoard, MapRegistry, SlideAudio, MovementController | wave 2 |
| P6A-21 | Low | Dead and leftover instances in the place | NOT FIXED: Studio housekeeping | DeflectPractice (comment only) | wave 2 |
| P6A-22 | Low | TouchBus latch; DevPanel passive buttons | FIXED; open choice below | TouchControls, TouchBus, DevPanel, SpellshotService | wave 2 |
| P6B-01 | Low | Docs describe a cross-Element pool; diary lacks P31 | FIXED (doc/errata only) | SpellshotConfig; errata OD-1, M-02 ... E2 | 7615bc3 |
| P6B-02 | Medium | Pyro alone has four Techniques | DESIGN | SpellshotConfig (Ring of Fire Desc); errata OD-2 | 7615bc3 |
| P6B-03 | Low | Manual's Technique tables behind the code | FIXED (doc/errata only) | errata M-13 ... M-39, Tables A-C | 7615bc3 + wave 2 |
| P6B-04 | Low | Diary claims manual edits that are not there | FIXED (doc/errata only) | errata M-00, M-27, M-28, D-01, D-02 | 7615bc3 |
| P6B-05 | Medium (entry) | Dev free Ultimate on by default | FIXED (dup of P1-02) | see P1-02 | 981173e |
| P6B-06 | Low | Modes drift; Quick Play advertises unbuilt modes | FIXED | QuickPlay; errata OD-4, M-05, M-07, M-50a, R-01, D-03, E3 | 7615bc3 + wave 2 |
| P6B-07 | Medium | Economy earn sources drift | FIXED (doc/errata only); open choice below | EconomyConfig; errata OD-5, M-44, M-54, M-69 | 7615bc3 + wave 2 |
| P6B-08 | Medium (entry) | Every skin and wrap free | NOT FIXED (dup of P2-06) | see P2-06 | 7615bc3 |
| P6B-09 | Low | Antitoxin Vent cuts every DoT, docs say own poison | FIXED (doc/errata only) | ToxinTuning (comment); errata M-27, D-02, E1 | 7615bc3 |
| P6B-10 | Medium | Corpses stay as cover; no ragdoll or body clear | FIXED; open choice below | HitboxScale; errata OD-6, M-49a, M-62, M-71, M-82 | 7615bc3 + wave 2 |
| P6B-11 | Low | Stale Technique / kit Descs | FIXED (doc/errata only) | SpellshotConfig, StatusEffects, CryoTuning; errata M-34, Table A | 7615bc3 + wave 2 |
| P6B-12 | Low | Manual appendix numbers out of date | FIXED (doc/errata only) | errata M-45 ... M-47, M-72 ... M-87, S-02 | 7615bc3 + wave 2 |
| P6B-13 | Low | Passive triggers changed; Shatter rationale stale | FIXED (doc/errata only) | errata M-38 ... M-40, M-42, Table A, E1 | 7615bc3 + wave 2 |
| P6B-14 | Low | Diary lacks the 2026-10-17/18 changes | FIXED (doc/errata only) | errata M-08, M-32, R-05, E1 ... E6 | 7615bc3 + wave 2 |
| P6B-15 | Low (entry) | Review-fix folders hold pre-fix copies | NOT FIXED (dup of P6A-10) | see P6A-10 | - |
| P6B-16 | Low | HANDOFF.md misleads | FIXED (doc/errata only) | errata H-00 ... H-11, R-03, R-04 | 7615bc3 |
| P6B-17 | Low | Manual systems that are spec only | FIXED (doc/errata only) | errata M-09, M-10, M-48, M-51, M-53, M-54, M-61, M-67 | 7615bc3 |
| P6B-18 | Low | Devil skin's HUD set absent | FIXED (doc/errata only); open choice below | errata OD-9, M-56, M-59 | 7615bc3 |
| P6B-19 | Low | Small UI / setting drifts (kill burst, SFX plan) | FIXED | DeathFX; errata M-50b, M-62, S-01, S-02 | wave 2 |
| P6B-20 | Low | Sidearm vs the manual's core verb | FIXED (doc/errata only) | errata M-23, M-36 | 7615bc3 |
| GA-01 | Medium | Chill bars say FROZEN/ROOTED at max stacks | FIXED; open choice below | BarFX, chill_t/a/f | 7615bc3 |
| GA-02 | Low | Shield looks always break, never register hits | FIXED | BarFX, PyroHandler, StatusEffects | 7615bc3 + wave 2 |
| GA-03 | Low | Default shield look is Terra stone for Cinder Shield | FIXED | BarFX | 7615bc3 |
| GA-04 | Low | Detonate countdown 6..1 over a 1.5 s fuse | FIXED | BarFX, primed_t/a/f | 7615bc3 |
| GA-05 | Low | Poison looks: x2 for one stack, invented numbers | FIXED | BarFX, poison_t/a/f | 7615bc3 |
| GA-06 | Low | Payoff plays when a flag drops early | FIXED | BarFX, StatusEffects, PyroHandler, TerraHandler, UmbraHandler | 7615bc3 + wave 2 |
| GA-07 | Low | Burn-tick burst for every HP loss | FIXED | PopArtHUD, StatusReactions | 7615bc3 + wave 2 |
| GA-08 | Low | Dev-only HUD paths (kill feed, READY pulse, star) | FIXED; open choice below | PopArtHUD, CombatCore, DuelMatch | 7615bc3 + wave 2 |
| GA-09 | Low | Round counter ignores Text Size | FIXED | PopArtHUD | 7615bc3 |
| GA-10 | Low | Bedrock stacks published but unread | FIXED | PopArtHUD, TerraHandler | 7615bc3 + wave 2 |
| GA-11 | Low | Zone-warning pulse ignores Reduce Flashing | FIXED; open choice below | PopArtHUD | 7615bc3 |
| GA-12 | Low | "not built yet" footer for built Elements | FIXED | LoadoutMenu | 7615bc3 |
| GA-13 | Low | LoadoutMenu header and comment drift | FIXED (doc/errata only) | LoadoutMenu (code text only) | 7615bc3 |
| GA-14 | Low | WRAPS card says "no wraps" | FIXED | LoadoutMenu, SkinCatalog | 7615bc3 |
| GA-15 | Low | Toxin payoff words reuse Voltaic art | FIXED (doc/errata only) | PopArtAssets (marked PLACEHOLDER) | 7615bc3 |
| GA-16 | Low | marked_t/f intro and payoff overlap | FIXED | marked_t, marked_f | 7615bc3 |
| GA-17 | Low | primed_f embers off-centre | FIXED | primed_t/a/f | 7615bc3 |
| GA-18 | Low | Status art covers the HP number | FIXED | BarFX | 7615bc3 |
| GA-19 | Low | Reactions board lists dormant reactions as live | FIXED (doc/errata only) | ReactionsBoard (player-facing text) | 7615bc3 |
| GA-20 | Low | ReactionsOpen read by nothing | FIXED | ShopController, SpellshotInput, MovementController, TouchControls, ZephyrSkyrider | 7615bc3 + wave 2 |
| GA-21 | Low | Shop sorts tie across currencies | FIXED | CardKit | 7615bc3 |
| GA-22 | Low | Exit restyles override another live look | FIXED | BarFX | 7615bc3 |
| GB-01 | Low | Skin kits and TerraWrap leak resizable meshes | FIXED | FrostbladeKit, FrostLotusKit, SnowGlobeKit, TerraWrap | 981173e + 7615bc3 |
| GB-02 | Low | Burn flames wear the last lasher's wrap | FIXED | PyroFX, PyroHandler | 7615bc3 + wave 2 |
| GB-03 | Low | Watcher-seen Detonate mark loses wrap and pop | FIXED | PyroHandler, PyroFX, PyroFlame_Tech | 7615bc3 + wave 2 |
| GB-04 | Low | Retired VFXLibrary renderers hold 50 locals | FIXED | VFXLibrary, SpellshotInput | 7615bc3 |
| GB-05 | Low | EmberRefund comment says caster only | FIXED (doc/errata only) | PyroFlame_Fire, PyroFX (comments) | 7615bc3 |
| GC-01 | Medium (entry) | Enemy corpse eats shots in team mode | FIXED (dup of P6B-10) | see P6B-10 | 7615bc3 + wave 2 |
| GC-02 | High (entry) | Server lets dash strikes through the wall | FIXED (dup of P6A-05) | see P6A-05 | 981173e |
| GC-03 | High | Skyrider Gust hits through a Bulwark Wall | FIXED | ZephyrSkyriderServer | 981173e |
| GC-04 | Low | Bulwark Charge staggers the wall | FIXED | TerraHandler | 981173e |
| GC-05 | Low | Other client shortcuts treat the wall as a body | FIXED | ZephyrFX_WindBlade, ZephyrFX_CrossSlash | 981173e |
| GC-06 | Low | Queued Shadow Step misses Undertow's interrupt | FIXED; open choice below | UmbraHandler | 7615bc3 |
| GC-07 | Medium | Shadow Step ignores roots and the Tomb | DECIDED-BY-AUDIT | UmbraHandler, VFXLibrary, SpellshotInput, SpellshotConfig | wave 2 |
| GC-08 | Medium (entry) | Prison / cage keep drawing after BreakRoot | FIXED (dup of P3-05) | see P3-05 | 7615bc3 |
| GC-09 | Medium (entry) | Entombed Zephyr reads as airborne | FIXED (dup of P4-04) | see P4-04 | 7615bc3 + wave 2 |
| GC-10 | Medium (entry) | PyroDraw never reads Reduce Flashing | FIXED (dup of P5B-05) | see P5B-05 | 7615bc3 |
| GC-11 | Low | ember_field geometry set only once | FIXED | PyroDraw | 7615bc3 |
| GC-12 | Low | fire_ball light threshold unscaled | FIXED | PyroDraw | 7615bc3 |
| GC-13 | High (entry) | Per-M1 table of unpaid damage | FIXED (dup of P1-12) | see P1-12 | 981173e |
| GC-14 | High | Five M1s invisible to everyone else | FIXED | SpellshotService, CombatCore, M1 handlers, VoltaicClient | 981173e |

### Owner decisions still open

**DESIGN findings.** Nothing was changed for the open part of any of these.
- **P3-09 (and P1-18): what charges the Ultimate.** Today, damage to Bulwark Walls, Decoy Doubles and dummies charges
  it (a 200 HP wall is about 77% of a meter), and so does self-damage taken. Recommended: only player and TrainingDummy
  victims charge it, and self-damage does not.
- **P3-16: hitbox twins and area attacks.** The 2x hitbox twins also widen every area that uses `HumanoidsNear`.
  Either keep that (it is now written in HitboxScale's header), or keep areas at 1x by skipping Hitbox parts in
  `HumanoidsNear`. Recommended: 1x.
- **P4-02: may Skyrider break Earthen Tomb?** The code now refuses it (P4-01's Precheck), and the Entombed text says
  so. Either confirm that and name Gust Pad as Zephyr's way out, or allow it, which means changing the Precheck and
  TerraHandler's escape list.
- **P4-03: which Techniques break the Tomb.** Recommended: an explicit `BreaksHold = true` on the Techniques that
  really move the body. The alternatives are to keep the role rule but also exclude Mark and Antitoxin Vent, or to let
  any fresh Technique press break it.
- **P4-12: may target locks pick a Decoy Double?** Earthen Tomb, Mirror Cage and Mark can. Patient Zero cannot.
  - Recommended: enemy locks may, so Patient Zero would accept decoys too.
  - The safe alternative: no lock picks a decoy.
- **P4-16 (latent): speed-cap clashes.** A token-based speed-cap API in CombatCore would stop the clash. It is needed
  only if `TechniquesOwnElementOnly` is ever turned off.
- **P4-18 and P5C-14 (latent): a borrowed Decoy Double.** Dress and pose it as the caster's Element (RadiantAnim,
  UmbraDecoyPoser). UmbraHandler already stamps `DecoyElement`. This matters only with the flag off.
- **P5A-10: Cryo and Colourblind-Safe.** Give Mint Rime a `Rest` colour (recommended: `Highlight`), and/or draw
  opponents' Cryo zone edges in the Default Frost Line colour under Colourblind-Safe.
- **P5A-18: wraps that change geometry.** Wraps and skins change shard width, opacity and zone looks, but the manual
  says a skin never changes effect intensity. Either record an exception for Rework skins (errata M-58 has the text),
  or cap wrap widths at Default.
- **P5B-02: Colourblind-Safe and effects.** Today only uniforms and decoys move. The choice is shape cues (rings,
  outlines) that help everyone, safe tints, or both. Recommended: shape cues first, and safe tints only for Terra and
  Toxin hazards.
- **P5B-03: wraps that repaint hazards.** Should a wrap always keep one boundary piece in the Element's Default colour
  (the Ring's line, the Toxin skirt, the Tomb fissure)? Recommended: yes, as a wrap-approval rule.
- **P5F-24: wraps and hazard readability.** The same question as P5B-03: should a hazard's defining layers (zone
  edge, cloud silhouette, projectile core) keep Default contrast and size under every wrap?
- **P5C-03: the Devil skin is dark.** Add a brightness floor for its core strokes (RadiantDraw), and/or refuse skin
  and wrap changes during a duel. Recommended: both.
- **P5C-04: Bloodmoon is brighter.** Match Default's luminance (a hue swap only) when the wrap is signed off. It is
  not urgent, because it disadvantages the wearer.
- **P5D-12: Cascade's strike zone.** Recommended: a faint ground ring at ZoneRadius (11) while it gathers, never
  thinned. The alternative is to shrink the cloud.
- **P5D-20: unwired Ground Surge v3.** About 940 lines in VoltaicFX are unwired. Move them to an archive module, or
  split `Tuning.Cascade` into a data module that both sides read.
- **P5E-16: Skyrider flight.** The movement guard now caps flat speed at FastSpeed (170) during a ride. Should there
  also be an altitude cap over the arena? It needs Play tuning.
- **P5E-17: Updraft and hovering.** Should the server stop counting a body as airborne if it holds a hover (|dY| <
  0.5 for over 1 s) with no fast state? It needs Play testing.
- **P5F-14: Graphics Quality tiers.** Either set MEDIUM's density to 0.7, so every `< 0.75` gate thins it, or add a
  per-tier `QualityTier()`.
- **P5F-22: SkinCatalog gaps.**
  - Rainbow, Obsidian Magma, Azure Flame, Bloodmoon and Devil need a rarity.
  - Frost Dragon is not signed off but is selectable live. Decide whether a `Released = false` flag should hide it.
- **P6B-02: Pyro has four Techniques.** Under P31, Pyro alone holds Heat Rush and Cinder Shield as well. Either retire
  them (recommended; every other Element has two) or keep four and write that into the manual.

**Calls the audit made that the owner may reverse.** GC-07 (UmbraHandler `Precheck_ShadowStep`, the ShadowStep row's
`Precheck` in VFXLibrary, SpellshotInput `canCast`), P5E-10 (`NoUpdraft` in ZephyrSkyriderServer) and P4-11 (the Ring
of Fire Desc in SpellshotConfig).

**Smaller choices left inside fixed findings.** The bug in each of these is fixed; only the stated choice is open.
- **P3-05:** may an ally's Pyro or Voltaic reaction break your own Cryo's Deep Freeze or Mirror Cage root?
  Recommended: no, so exempt prison and cage roots.
- **P3-10:** may a hit that a shield fully absorbs still use up a status and fire a reaction? Recommended: no.
- **P3-13:** `Config.Duel.MaxRounds = 15` is marked PROPOSED, and a capped level match is a draw. The alternatives
  are sudden death or a damage tiebreak.
- **P4-10:** should there be a real Q/E swap? It would need a new LoadoutRequest branch. The rows are only dimmed
  today.
- **P4-17 (latent):** should Cinder Shield's hold give way to Umbra's dart brace and Terra's Boulder windup?
- **P4-19 (latent):** on an Element pick, keep borrowed Techniques or wipe them (ElementDefaults / TechniquesFor)?
- **P5A-22:** Frost Dragon's Blizzard dragons stand at R + 3, outside the storm. Bring them inside?
- **P5B-07:** widen the Tomb fissure gap (0.10 to 0.24, as in the reference film)?
- **P5C-05:** a Position Trade aimed at a decoy now breaks the decoy and spends the cast. The alternative is to swap
  first, then break the decoy.
- **P5D-08:** should Twin Tide and Maw walls spare teammates? That needs a server `Spare` list in AquaHandler.
- **P6A-20:** SkylineConcept and SkylineRivals show identical vote cards. Keep one, or give them distinct Subs.
- **P6A-22:** build the dev panel only on a dev's first open? Low value.
- **GA-01:** art for the max-stack chill bar, and a bar look for a real root (fed by an `RX_Rooted` flag).
- **GA-08:** which Mark state should light the marked-crosshair star?
- **GA-11:** wire `ZoneWarning` to real hazards, or remove the dormant path.
- **GC-06:** should an interrupt that lands during the first ~0.12 s dissolve cancel a blink already under way?
- **P2-18 and P6B-07:**
  - The shop's placeholder data needs replacing: `Catalog.ITEMS`, and the `RobuxBalance` pill, which shows 1250 but
    reads nothing.
  - Should Hub pad duels pay Sparks?
- **P6B-10:** dead bodies no longer stop shots, but ragdolls and the ~3 s body clear are feature work.
- **P6B-18:** build the Devil skin HUD set (a build prompt exists), or paste errata M-56.

### Movement guard (P1-03)

The server now checks where each player's body goes, so a modified client can no longer teleport, out-run every
legal speed, or walk out of a root, a Mirror Cage, a Deep Freeze prison or Earthen Tomb.

**Settings.** `Config.MovementGuard` in SpellshotConfig:
- `Enabled = true`
- `Enforce = true`
- `BaseSpeed = 90` (studs/s, flat)
- `FastSpeed = 170`
- `FastAfterCast = 1.5`
- `MinStep = 10`
- `Grace = 1.0`
- `Window = 0.5`
- `MaxGap = 3`

With `Enforce = false` the guard only counts.

**What it does.** It runs in CombatCore on every Heartbeat, for living player bodies only, never dummies.
- It measures each body's flat (XZ) speed from the position where the body stood at least `Window` seconds ago.
- Each position is timed from when the server first saw it, so replication that arrives in a burst after a stall does
  not read as a sprint.
- The time used is capped at `MaxGap`.
- The limit is BaseSpeed, or FastSpeed if the body was in a fast state at any time since that reference position.
- A move of more than `MinStep` studs over the limit adds one to `ServerStorage.ShotStats.move_snap`. With `Enforce`
  on, the body is also put back where it last stood, with its rotation kept.
- Held, anchored and in-grace bodies are skipped. A new body (a respawn or a new round) starts with no history.

**Fast states.** Any one of these gives the FastSpeed limit:
- `SkyriderT0` is set (a ride).
- `KnockedUntil` is later than server time. Every server-sent knock or pull of a player writes it: Aftershock,
  Bulwark Charge, Overload, Skyrider's gust, an enemy Gust Pad, Cyclone's pull, Undertow's pull, and Aqua's knocks.
- Any `Holding_<role>` attribute is set (a held Technique).
- `CastAt` is less than `FastAfterCast` seconds old. SpellshotService stamps it on every accepted non-M1 cast, and
  again when a held press is released, so Cross-Slash's 110 studs/s glide on key-up is covered.

**API (CombatCore).**
- `Core.AllowMove(model, seconds)`: call it right before any server PivotTo of a player's body. It opens a grace
  window (default `Grace`) and resets the body's history. It is called by:
  - HubServer, with 1.5 s, before `place()` and the respawn PivotTo. This covers Hub and Arena moves, portals and
    DuelMatch's moves.
  - Radiant's Position Trade, on both bodies.
  - Umbra's Shadow Step re-form, with 1 s.
- `Core.HoldBody(model, key, on)`: one hold per (model, key), and a body is held while any key holds it.
  - While held, the server owns a player's root (`SetNetworkOwner(nil)`).
  - When the last hold ends, ownership goes back to the player and `AllowMove` opens a grace window.
  - Holds end with the model and are dropped by `Core.ClearPlayer`.
- `Core.IsHeld(model)`: whether any kit holds the body.

**Holds wired.**
- `CryoRoot` in AbilityHandler: on while the tightest slow cap is 0. That covers Flash Freeze and its frozen patches,
  Deep Freeze's prison, Mirror Cage and a reaction's root, overlapping roots included.
- `Tomb` in TerraHandler: from the catch to the release, on every way out (descent end, escape, death, clear, caster
  leaving, error path).
- Cyclone is not a hold. Its server-side network-ownership code moves only anchored training dummies, and caught
  players are pulled by their own client under `KnockedUntil`.
  - Note: the Config and CombatCore header comments still list "Cyclone" among the holds.
  - Those comments should be reworded next time those files are open. Nothing under `game/` was touched by this
    write-up.

**Known limits.**
- **Vertical movement is not judged.** Fly and hover hacks are not caught. See P5E-16 and P5E-17 above.
- **Walking through walls at a legal speed is not judged.**
- **A long stand-still lets one jump through.** The guard caps the elapsed time at MaxGap. So a body that stood still
  for up to 3 s can make one jump of up to BaseSpeed x MaxGap = 270 studs and pass.
- **A client that ignores the put-back keeps bouncing.** Each bounce counts a snap. A suggested escalation (hold the
  body for about 1 s after N snaps) is not built.
- **A server move without AllowMove gets snapped back.** Any new server move of a player's body that lacks
  `Core.AllowMove` will be snapped back. Grep for `PivotTo` whenever a kit adds one.
- **Check honest fast movement in Studio.** One open review item is to confirm in Play that no honest movement goes
  over 90 studs/s outside a fast state. The candidates are dashes, slides, Gust Pad, Updraft and Bulwark Charge; the
  coordinator's notes list Skyrider, Undertow and Shadow Step too.
  - The legal speeds the config lists: sprint 25, slide-jump at most 52, a Skyrider boost about 75, Undertow's pull
    125 (under `KnockedUntil`).
  - A caster launched by their own Gust Pad has no `KnockedUntil`, but that launch is vertical, with at most 8
    studs/s flat.

**Recommended first Studio test.**
1. Set `Config.MovementGuard.Enforce = false`.
2. Play honestly through every Element's whole kit: M1, Primary, both Techniques and the Ultimate. Include sprinting,
   slide-jump chains and wall runs, being knocked and pulled by every source, Hub and Arena moves, duel rounds and team
   rounds, and 200-300 ms of emulated lag with jitter.
3. Confirm that `ServerStorage.ShotStats.move_snap` stays at 0.
4. Then turn `Enforce` back on.

After that:
- A 60-stud teleport from the client is put back.
- A steady 120 studs/s WalkSpeed hack is put back.
- A rooted, caged, Deep-Frozen or Entombed body shows `HumanoidRootPart:GetNetworkOwner() == nil` on the server, and
  it returns to the player with no snap when released.

### Studio checks

These are taken from the wave 1, wave 2 and P5F-06 logs, one line each. The first batch's checks are under "Check in
Studio" further down. Use two clients unless a line says otherwise. Lines marked (latent) need
`TechniquesOwnElementOnly = false`.

**Server rules and exploits**
- [ ] P1-07: mash Q/E/R and M1 on every Element. Nothing is refused that was not refused before.
- [ ] P1-07: a scripted loop of CastRequests gets about 20 presses/s through.
- [ ] P1-07: spam BoulderCharge On/Off from the command bar. No BoulderChargeStart/Stop flood reaches other clients.
- [ ] P1-07: hold and throw, then hold again at once. The second throw is full strength.
- [ ] P1-07: a looped RadiantLanceStop is dropped past 15 in a burst.
- [ ] P1-07: a looped SettingsSync "request" gets at most 2 replies/s.
- [ ] P1-08: with `SignalBehavior = Deferred`, fire 5 Ultimate requests in one frame as a full-meter Toxin. You get
  one Patient Zero mark and one burst.
- [ ] P1-09 / P5E-15: aim these at a floor behind a wall and at the floor above: Flash Freeze, Blizzard, Ring of Fire
  (and its steer), Cyclone (and its steer), Gust Pad, Twin Tide, the Maw, Acid Rain, Cascade. Each lands on this side.
- [ ] P1-09: aim at an enemy behind waist-high cover. It still lands at their feet.
- [ ] P1-09: a Cascade with no floor on this side gives the meter back.
- [ ] P1-09: peeking round a corner at sprint is not pulled back noticeably.
- [ ] P5E-15: a Gust Pad aimed at the underside of a walkway lands on the floor below.
- [ ] P1-10: rooted, force a Bulwark Charge. Nothing is spent.
- [ ] P1-10: Bulwark Charge into a wall. The `BulwarkCharging` window ends when the body stops.
- [ ] P1-11: fire each release remote with `Id = 0/0`: Shard, Fireball, Wind Blade, Riptide, Sidearm, Shadow Dart. No
  "table index is NaN" appears.
- [ ] P1-13: an Undertow within 0.14 s of a Sidearm press stops the drawn shot (`rej_interrupted` goes up).
- [ ] P1-13: an Aftershock before Cross-Slash's Trigger stops the strike.
- [ ] P4-05 / P4-06: a held Scorching Lash that is interrupted ends with no crack.
- [ ] P4-06: an Aqua holding Sidearm who is Aftershocked puts the gun away, with no phantom bullets.
- [ ] P6A-16 / GC-06: double-tap Shadow Step and land an Undertow in the dissolve. One blink happens, and the second
  charge comes back.
- [ ] P1-14: in Solo Test, the pad never launches a stranger.
- [ ] P1-14: in Solo Test, Position Trade's precheck refuses a stranger at no cost.
- [ ] P1-14: in a duel and a team match, the pad and Position Trade still work.
- [ ] P1-16: honest Boulder taps and holds draw the right size for others.
- [ ] P1-16: `CastRequest("M1", {Charge=1})` with no release draws a tap.
- [ ] GC-07 (decided by audit): rooted, caged, Deep-Frozen or Entombed, press Shadow Step on either charge. There is
  no blink, the slot flashes red, and mana, `CD_` and `CDEscape_` are untouched.
- [ ] GC-07: free, both charges still blink, including during the Umbra's own Eclipse windup.
- [ ] P4-07: hold Heat Rush, then pick Cryo. The rush ends at once. Try the same with Bulwark Wall and Skyrider.
- [ ] P4-08: Pyro holds Heat Rush, switches to Cryo, casts Blizzard, then releases Q. Blizzard's 18 s cooldown is not
  cut.
- [ ] P3-22: press Benediction mid-air (refused). The Ultimate meter is back where it was.
- [ ] P6A-04: in RunningOnly mode, `MoveRequest("Slide")` gives Crouch at 8 studs/s.
- [ ] P3-20: dev HEAL on a dead body. It stays dead.
- [ ] P6A-22: dev PASSIVE ON shows on a second client.
- [ ] P1-19: rename a part `Shrine_Pyro_Monument`. The prompt refuses during a duel and works in the Hub.

**Combat rules and statuses**
- [ ] P3-01: a Melt bonus that kills fires OnKill once.
- [ ] P3-01: Ember Refund fires once when a reaction from the same hit takes the enemy lower.
- [ ] P3-03: Toxin B poisons A, and A walks into A's own cloud. B keeps the credit, and A's Vent does not cleanse it.
- [ ] P3-04: Flash Freeze roots an enemy and an ally Melts them. There is no shatter at zone end.
- [ ] P3-05: Mirror Cage an enemy, then an ally Fireballs them. The dome and reflections stop on that body for
  everyone.
- [ ] P3-06: Bulwark Charge an enemy, then Overload them 0.3 s later. The stars and Skyrider's refusal last until the
  later of the two ends.
- [ ] P3-07: in a 3-client team match, cast Ring of Fire, Twin Tide or Flash Freeze and disconnect. Nothing more
  lands in the leaver's name.
- [ ] P3-10: a Burning Toxin in its own Patient Zero burst shows no COMBUSTION.
- [ ] P3-12: Aftershock, then Undertow on the same body. Casting stays refused until the Aftershock interrupt ends.
- [ ] P3-17: a reaction credited to the marker does not spend the Mark.
- [ ] P3-17: an airborne Zephyr's reaction bonus is not x1.25.
- [ ] P3-21: Bulwark Charge a player. They are visibly thrown, like a dummy.
- [ ] P4-04: an Entombed, knocked or pulled Zephyr's Wind Blades deal base damage with no UpdraftHit pulse. A jump
  and the Zephyr's own pad still give x1.25.
- [ ] P5E-10 (decided by audit): the Skyrider gust deals exactly its Damage.
- [ ] P4-13: a Bulwark Wall in a Ring of Fire or a Cyclone gets no burn or Airborne attributes.
- [ ] P4-20: land a Cryo hit, then switch to Aqua on wet ground. Riding the Current's speed holds, and the reverse
  order keeps Cold Momentum.
- [ ] P5C-05: Position Trade aimed at a decoy is paid, the decoy breaks with the Tell, and nobody moves.
- [ ] P5C-05: aimed at the real Umbra, the swap works.
- [ ] P5C-05: Blessing never locks a decoy.
- [ ] P5C-12: a late joiner sees a Devil-skin Radiant's Overflow in Devil colours.
- [ ] P6B-10: in a team match, an enemy dies in a doorway. Wind Blade, Fireball, Shard and Boulder fired through the
  body hit whoever is behind it.
- [ ] GA-02 / GA-06: Cinder Shield registers hits and breaks on a full hit. Expiry plays a plain end.
- [ ] GA-06: Detonate's blast plays the payoff, and a fizzle plays an end.
- [ ] GA-06: Charged, Blessed or Mark carried into a round reset fades with no payoff word.
- [ ] GB-02: an Azure Flame Pyro lashes X, then a Default Pyro burns X 5 s later. The flames are Default.
- [ ] GB-03: watch a Detonate on a third client. You see the wrapped crown and the landing pop, with no re-grow.

**Movement guard (P1-03).** See the section above: first a run with `Enforce = false`, then the teleport, speed-hack
and root checks.
- [ ] P1-03: Position Trade over 30+ studs, Shadow Step and a double tap, Undertow and Cyclone pulls, and Hub and
  Arena moves all leave `move_snap` flat.

**Match flow**
- [ ] P3-13: set MaxRounds = 2 with two idle sides. The match ends as a draw, the MATCH DRAWN banner shows in cream,
  and the draw reward is paid.
- [ ] P3-14: die in the final round. You stay down on the result screen and are rebuilt in the Hub.
- [ ] P3-14: the survivors cannot cast during the 4 s hold.
- [ ] P3-15: a burst that kills the last player of both teams in one frame gives a draw.
- [ ] GA-08: a kill shows "KILLER > VICTIM" in the feed for that match's players only.
- [ ] P6A-07: a Sakura Row window broken in round 1 is whole and solid in round 2.
- [ ] P6A-06: respawn in the Hub about 10 times. You always land at the Observatory's HubSpawn.

**Saves, economy, shop**
- [ ] P2-08: with API access off, the menu works on defaults, and the output says nothing will be saved.
- [ ] P2-09: a setting changed in the first second of Play survives the load and a rejoin.
- [ ] P2-10: change a setting and leave. On rejoin it is still set.
- [ ] P2-13: with the `DataError` attribute set, pressing a pack shows a toast and no purchase prompt.
- [ ] P2-14: AwardMatch's return value equals the Sparks change.
- [ ] P2-16: a `Foo = 1` field added to a saved record survives join and leave.
- [ ] P2-17: autosave still refreshes `Session.T` every 60 s.

**Settings and accessibility**
- [ ] Reduce Flashing, Cryo (P5A-09): soft impact, shatter and cage flashes, and no cage outline flicker.
- [ ] Reduce Flashing, Pyro / Terra / Toxin (P5B-05): no strobing from the Patient Zero mark, fireball lights, Boulder
  flight or Wall hits.
- [ ] Reduce Flashing, Radiant and Umbra (P5C-07): hold Benediction 8 s, Position Trade, Eclipse, and a Mark headshot.
  Nothing strobes.
- [ ] Reduce Flashing, Voltaic (P5D-03, P5D-04): no 15 Hz Cascade flicker, and no shimmer on Chain Bolt, Overcharge
  or Volt Orb.
- [ ] Reduce Flashing, Zephyr (P5E-03, P5E-11): the Skyrider bird, pad launch and Cyclone pulses do not spike.
- [ ] Reduce Flashing, Cryo, Terra and Volt Orb flashes and the M1 (P5F-03): the Flash Freeze zone and break flashes are
  dimmer, the shatter has no white disc, there is no Boulder or Ground Surge flash, and the palm flash is faint.
- [ ] Reduce Flashing, DeathFX (P5F-03, P6B-19): the death stamp is half size and steady.
- [ ] Reduce Flashing, Aqua (P5D-02): no white muzzle or bite flash.
- [ ] Reduce Flashing, status bars (P5F-04): no casing, LED or tag flicker under Detonate, and smaller shakes.
- [ ] Reduce Flashing, Hub (P6A-11): braziers keep moving without pulsing, and lanterns are steady.
- [ ] Reduce Flashing, HUD (GA-11, P3-23): the zone-warning border and the shield ring glow hold steady.
- [ ] Reduce Enemy VFX (P5F-06 and every Element): in a 2v2, a teammate's effects draw full and an opponent's are
  thinned, for every Element and every Cryo, Pyro and Toxin wrap.
- [ ] Reduce Enemy VFX (P5F-07): an enemy's Gust Pad draws like your own.
- [ ] Reduce Enemy VFX off: nothing changes, yours included.
- [ ] Graphics Quality LOW (P5B-04, P5F-05, P5D-02): Toxin smoke, drops and rain are thinner, and so are Radiant motes,
  Umbra wisps and Aqua spray.
- [ ] Graphics Quality LOW (P5E-22): Zephyr's Beam count roughly halves.
- [ ] Graphics Quality LOW (P5A-19): Black Ice is plain black.
- [ ] Graphics Quality (P5F-16): reused Icicle Shards thin after a switch to LOW.
- [ ] Graphics Quality (P5D-07): your own Volt Orb is not double-thinned.
- [ ] Graphics Quality (P5B-16): Terra debris is full with the setting off.
- [ ] Status Intensity (P5F-04): at 0, 50 and 100 the bar looks fade to match.
- [ ] Camera Shake (P5F-04): at 0, there is no row shake.
- [ ] P5F-11: with Colourblind-Safe on, change Element in the Hub. The uniform keeps the safe colour.
- [ ] P5F-13: at LOW, go Hub, Arena, Hub. `GlobalShadows` stays false.
- [ ] P5F-18: rebind Primary to G and the HUD chip says G. Touch a gamepad and the chips show X/LB/RB/Y.
- [ ] P5F-19: Text Size 150 survives a tab switch, and 120 then 100 resize everything.
- [ ] P5F-28: set FOV 105. It holds across several rejoins.
- [ ] P5C-11: Brightness 100 and an enemy Eclipse. The world still darkens, and your brightness comes back after.
- [ ] P5F-20 / P5F-08: the ACCESS preview shows nine chips, and the row texts match the behaviour.

**Element visuals**
- [ ] Cryo skins (P5A-04): a teammate in a Frost Dragon Flash Freeze gets no spines.
- [ ] Cryo skins (P5A-04): an enemy who walks out of it loses the spines within about 0.3 s.
- [ ] Cryo skins (P5A-05): a Frost Dragon Blizzard hides bodies like the Default from outside.
- [ ] Cryo skins (P5A-11): Sakura Frost freezes show the crust plates.
- [ ] Cryo skins (P5A-13 / P5A-15): every skin's Mirror Cage plays and cleans up, and an absent caster draws the
  Default dome.
- [ ] Cryo skins (P5A-14): no Frost Lotus is left floating after a respawn.
- [ ] Cryo skins (P5A-21): a third player sees no kill swoop.
- [ ] Cryo skins (P5A-22): skin rims sit on the Frost Line.
- [ ] Cryo skins (P5F-23): the Frost Dragon M1 wears the wrap.
- [ ] Pyro (P5B-01): with the toon look, a hot Ring's line sits at 21 studs.
- [ ] Pyro (P5B-14): Azure Flame is never mixed with orange.
- [ ] Pyro (P5B-13): the Loadout greys Heat Rush and Cinder Shield wraps.
- [ ] Terra (P5B-07): an opponent's Tomb on LOW + Reduce Enemy VFX shows the head and target mark.
- [ ] Terra (P5B-17): a lagged Wall hit starts at the server's moment.
- [ ] Terra (P5B-19): no 162-plate clone per Aftershock after warm-up.
- [ ] Terra (GA-10): the Bedrock pips light while charging.
- [ ] Terra (GA-10): a Terra at 0 stacks who changes Element keeps no dark pips.
- [ ] Toxin (P5B-09, P5B-10): the first wrapped bubble does not hitch, and TerraWrap still builds alongside it.
- [ ] Toxin (P5B-11): a wrapped bubble's convert draws in wrap colours.
- [ ] Zephyr (P5E-01): an enemy at 20 studs sees the Cyclone's ground ring beyond them.
- [ ] Zephyr (P5E-04): an opponent's Gust Pad has a chevron rim, while yours and a teammate's have dashes.
- [ ] Zephyr (P5E-19): a late joiner sees a live pad, is launched by it, and sees no kneel.
- [ ] Zephyr (P5E-07 / P5E-08): incoming Wind Blades are always drawn and run on the shot line.
- [ ] Zephyr (P5E-09): a body about 25 degrees off a gust is inside the drawn cone.
- [ ] Zephyr (P5E-13): a Gust Pad re-added at runtime draws.
- [ ] Aqua (P5D-08): with AquaTTPoseTable renamed, the lane still blocks for about 1 s.
- [ ] Aqua (P5D-09): a round reset mid-Maw or mid-Twin Tide drops the colliders at once.
- [ ] Aqua (P5D-16): `TT*` attributes appear in Studio only.
- [ ] Voltaic (P5D-10): die or alt-tab while aiming Volt Orb. The arc clears, and the next press throws.
- [ ] Voltaic (P5D-11): Cascade forks skip your own decoy and ally dummies.
- [ ] Voltaic (P5D-17): a late Railspike leaves no stuck windup.
- [ ] Radiant (P5C-18): two Devil Benedictions keep stable cracks.
- [ ] Umbra (P5C-13): respawn mid-Eclipse. There are no outlines on the new body.
- [ ] Umbra (P5C-17): delete a marked dummy. Its anchor goes.

**Status bars and HUD**
- [ ] GA-01: three Icicle Shards read CHILLED! / SLOWED!, and you can still move.
- [ ] GA-03: Cinder Shield shows steel plating, not BEDROCK!
- [ ] GA-04: Detonate counts down 2, 1.
- [ ] GA-05: one poison stack in preset A shows no x2, and the numbers equal the HP lost.
- [ ] GA-07: a Shard hit shows a plain "-N" burst.
- [ ] GA-09: the round clock grows with Text Size.
- [ ] GA-16: a Mark spent within 1.2 s shows only the payoff word.
- [ ] GA-17: the primed embers are centred.
- [ ] GA-18: the HP number is readable over status art.
- [ ] GA-22: Burning + Blessed ending first leaves no colour blink.
- [ ] P6A-09: a refused press flashes the slot plate red.
- [ ] GA-12: the Loadout footer lists the full kit.
- [ ] GA-14: the WRAPS card wells are coloured for Cryo, Toxin, Terra and Umbra.
- [ ] P4-10: as Cryo the Technique arrows are dimmed, and as Pyro they cycle.
- [ ] GA-20: with the Reactions tablet open, casting, jump, slide, touch buttons and Skyrider input all stand down.
- [ ] GA-19 / P6A-20: the Reactions board lines fit their cards on PC and phone.

**Hub, menus and Studio-only tools**
- [ ] P6A-08: no "SpellshotHUD" ScreenGui in Play.
- [ ] P6A-12 / P6A-13: flames keep their colour, and lantern panes stay in step, after streaming out and back.
- [ ] P6A-17: a vote called off and refilled returns the mouse lock.
- [ ] P6A-18: QUEUE, CANCEL, QUEUE fast shows QUEUING, and the server counts you.
- [ ] P6B-06: Squad Clash and Convergence show LOCKED, and DUEL still queues.
- [ ] P6A-20: your own slide sound starts on the press at about 150 ms ping.
- [ ] P6A-20: a refused slide never leaves footsteps muted.
- [ ] P6A-22: with touch Toggle Crouch latched, switching to RunningOnly drops the crouch.
- [ ] P4-14: the dev panel Technique headers read "(your Element's own)".
- [ ] P6A-15: TerraTest works in Studio and does nothing live.
- [ ] P5D-19: VoltTest's orb leaves the hand 0.12 s in.

**Latent (`TechniquesOwnElementOnly = false`)**
- [ ] P4-15: a borrowed Acid Rain or Vent draws Default.
- [ ] P4-17: Aqua and Toxin can M1 with Cinder Shield up.
- [ ] P4-19: a second borrowed Halo does not hitch.

**Checks, once more:** nothing has been run in Roblox Studio. All checks were static: `luau-compile` on every changed script, and a no-new-globals check with `luau-analyze`.

---

## First fix batch (commit `981173e`)

These fix the findings listed in `SPELLSHOT_CLOUD_BUG_REPORT_2026-10-18.md` ("lead with these", the economy items and
the cheap hard bugs). Every edit is marked in the code with a comment of the form `(2026-10-19, audit <ID>)`.

**Checks run:** every changed script compiles under `luau-compile` 0.700, and `luau-analyze` finds no global name that
the file did not already have. **Nothing has been run in Studio or Play.** The README's rule applies: these are text
edits that do nothing until they are copied into the place. Run the Studio checks below before trusting any of them.

### Files touched (Explorer paths)

ServerScriptService: `CombatCore`, `SpellshotService`, `PlayerData`, `DuelMatch`, `HubServer`, `TrainingGround`,
`AbilityHandler`, `PyroHandler`, `ZephyrHandler`, `TerraHandler`, `VoltaicHandler`, `AquaHandler`, `UmbraHandler`,
`RadiantHandler`, `ToxinHandler`, `ZephyrSkyriderServer`, `_AuroraStage`, `_BROStage`.
ReplicatedStorage.Spellshot: `MapRegistry`, `SpellshotSettings`, `DashMotor`.
ReplicatedStorage.IceMagic: `VFXLibrary`, `VoltaicClient`, `ZephyrSkyrider`, `ZephyrDraw`, `ZephyrFX_WindBlade`,
`ZephyrFX_CrossSlash`, `CryoFX`, `SnowGlobeFX`, `SnowGlobeKit`, `FrostbladeKit`, `FrostLotusKit`, `FrostDragonFX`,
`RadiantClient`, `RadiantDevilForge`, `RadiantFX_Staff`, `RadiantFX_Hand`.
StarterPlayer.StarterPlayerScripts: `FirstPersonController`, `SettingsRuntime`, `_AuroraStageClient`, `_BROStageClient`.

Copy them as one batch. The server and client halves of P1-12 (`VoltaicClient`) and P4-01 (`VFXLibrary`'s Skyrider
row plus `ZephyrSkyriderServer`) depend on each other.

### What changed

| Finding | Fix | Where |
|---|---|---|
| P1-01 fire from anywhere | New `Core.TrailSpeed(root, floor)`: the client's claimed velocity counts only up to what the server has *seen* the body move over the last 0.25 s (×1.5 + 10 studs/s, ceiling 150). New `Core.Lag(ping)` caps ping at 0.3 s. All 12 origin checks use both; dash sites pass their own dash speed as the floor. | CombatCore; Ability/Pyro/Zephyr/Terra/Voltaic/Aqua/Umbra/Radiant/Toxin handlers |
| P1-02 / P4-09 / P2-07 dev mode live | A dev's FreeUltimate / FreeMana / NoCooldowns are set aside while they are in a match with any non-dev player and restored when it ends; a match of devs only (Team Test) keeps them. The dev panel refuses every action in such a match. +1000 Sparks, Unlock All and Reset work only in Studio. `AllowInLiveGame` is left on so Team Test keeps working. | SpellshotService |
| P4-01 Skyrider Tomb escape / Ultimate farm | The Skyrider row has `Precheck = true`, and ZephyrSkyriderServer answers `Precheck_Skyrider` (alive, not in the Hub, not stunned, rooted or Entombed, CanAct). A press the server would refuse is now refused before it is paid, so TerraHandler never sees it as an escape. | VFXLibrary, ZephyrSkyriderServer |
| P1-04 Training Ground in the ranked vote | New MapRegistry field `Practice = true` on TrainingGround: offered to a Solo Test only, never a Duel or team match. The thrower also skips anyone with a `DuelMatch`. | MapRegistry, HubServer, TrainingGround |
| P6A-05 + GC-02 + GC-03 + GC-04 + GC-05 Bulwark Wall | Client: DashMotor's and Skyrider's `characterOf`, Wind Blade's sweep and Cross-Slash's floor probe treat a `WallOwner` model as a wall. Server: new `Core.WallBetween(a, b)` (a ray that sees only Bulwark Walls); a Cross-Slash whose glide crossed a wall strikes nothing, and Bulwark Charge never hits through one (the wall itself takes the damage only, no stagger or knock). Skyrider's Gust no longer leaves the wall out of its own line of sight. | DashMotor, ZephyrSkyrider, ZephyrFX_WindBlade, ZephyrFX_CrossSlash, CombatCore, ZephyrHandler, TerraHandler, ZephyrSkyriderServer |
| P1-12 / GC-13 / GC-14 unpaid, invisible M1s | SpellshotService counts every accepted (charged) M1 CastRequest in the player attributes `M1Paid` / `M1PaidAt`. New `Core.TakePaidM1`: a shot needs one before it deals damage, asked once per shot on its first damaging hit (at most 3 banked, none after 6 s). Icicle Shard, Fireball, Wind Blade, Boulder Shot and Riptide check on the hit; Chain Bolt checks on the fire, so VoltaicClient now sends its M1 CastRequest *before* ChainBoltFire. | SpellshotService, CombatCore, Ability/Pyro/Zephyr/Terra/Aqua/Voltaic handlers, VoltaicClient |
| P5C-01 Colourblind-Safe decoy detector | SettingsRuntime paints every Decoy Double in `workspace.UmbraDecoys` as its owner, on arrival and again 0.6 s later; an Element with no palette row keeps its own colours. | SettingsRuntime |
| P5F-09 / P5F-10 colourblind palette | Aqua has a row (its own Base). Zephyr, Umbra and Radiant are back to their identity colour, as the palette's own header says "the rest" should be. Only Terra and Toxin move now. | SpellshotSettings |
| P5F-02 third-person toggle | V works only for `Config.IsDev` accounts; switching back to first person is always allowed. | FirstPersonController |
| P1-05 stage scripts | All four `_*Stage*` scripts return at once unless `RunService:IsStudio()`. | the four stage scripts |
| P2-01 / P2-02 / P2-03 save races | The session lock is a per-profile token (`Session.Token`), not the JobId. A write proceeds only while the stored lock carries its own token, so a released, taken or missing lock stops it. A rejoin to the same server also waits for its previous leave save to land. The first save after deploy waits on old JobId-only locks until they go stale or the last load try forces them (about 20 s). | PlayerData |
| P2-04 live memory-only | Memory-only is Studio's answer only. On a live server without its DataStore every load fails (and asks for the store again), so spending and Robux receipts pause instead of being granted unsaved. | PlayerData |
| P2-05 forfeit farming | A forfeit before 2 settled rounds pays nobody. | DuelMatch |
| P5A-06 Snow Globe M1 nil call | `SHARD` / `shards` moved above `HitBloom`; the hook's pcall now warns once. | SnowGlobeFX, CryoFX |
| P5A-07 Lotus / Globe shatter crash | Fragment size falls back to the layered kinds' size; chunk counts default to {8, 5, 3}; a failed skin shatter falls back to the Default heavy shatter. `FL.ShatterChunks` added. | CryoFX, FrostLotusKit |
| P5A-08 + GB-01 skin built half-way | Frostblade, Frost Lotus and Snow Globe build all-or-nothing, as Frost Dragon does: one failed kind frees everything, sets `Failed`, and the Default draws. Resizable EditableMeshes are freed on every error path. | FrostbladeKit, FrostLotusKit, SnowGlobeKit |
| P5A-03 Frost Dragon claw | The 60% clear claw is drawn so on every client, not the caster's only. | FrostDragonFX |
| P5A-02 Snow Globe pines | The Blizzard's pines and flurry get a keyhole (Frost Lotus's): any piece between a camera and a player's body ghosts to 0.82 transparency. | SnowGlobeFX, SnowGlobeKit |
| P5C-02 Devil skin with no fallback | New `Forge.Drawn(form, ...)`: false while a forged form is unbuilt or failed. The Light Lance beam, Halo ring, Benediction heaven/column, Blessing arches/floor ring, Overflow dashes and Trade cages draw the Default whenever it is false. Devil pieces prewarm when *any* player wears Devil. | RadiantDevilForge, RadiantFX_Staff, RadiantFX_Hand, RadiantClient |
| P5E-14 ZephyrDraw at the local limit | The light helpers are in a do-block: peak 200 → 197 there (198 elsewhere in the file). | ZephyrDraw |

### Check in Studio (two clients unless noted)

1. **Shots:** fire every M1 standing, sprinting, slide-jumping, mid-Skyrider and just after a knockback; every hit
   should still land, and the server's shot counters (`ServerStorage.ShotStats`) should show no new `rej_origin` or
   `rej_unpaid`. Then rapid-click every M1 on a ~150 ms ping, and confirm the other client sees every shot that
   damages it.
2. **Chain Bolt:** spam it. Each bolt should still chain and charge; mana should drain as before.
3. **Bulwark Wall:** Cross-Slash, Overcharge, Bulwark Charge and Skyrider into an enemy wall all stop at it; nobody
   behind it is hit by those or by Skyrider's Gust; the wall still takes damage from all of them.
4. **Skyrider:** an honest press works as before; Entombed or rooted, the key is refused and the Tomb holds.
5. **Dev accounts:** in a Quick Play match with a non-dev, the meter is not pinned and the panel says "Dev tools are off";
   in a Team Test with devs only, the freebies still work. Eco buttons do nothing outside Studio.
6. **Map vote:** a Quick Play or pad-duel vote never offers TRAINING GROUND; Solo Test still does.
7. **Saves:** leave and rejoin the same server quickly; Sparks and owned Elements carry over. Two servers: join one,
   then the other; the second waits (≤ ~20 s) and loads the first's last save.
8. **Colourblind-Safe:** Aqua stays blue, Zephyr teal, Radiant gold, Umbra violet; a Decoy Double looks like its owner.
9. **Cryo skins:** Snow Globe M1 hits (slabs, pile, shards); Lotus and Globe shatters; a forced kit build failure draws
   the Default; Snow Globe Blizzard pines ghost when a player stands behind them; the Frost Dragon claw looks equally
   clear to both clients.
10. **Devil skin:** an opponent's first Light Lance, Halo, Benediction, Blessing and Position Trade show the Default
    strokes until the forged forms exist, then the forged ones; watch mesh memory on mobile, since prewarm now runs for
    any Devil wearer.
11. **Zephyr lights:** look as before (ZephyrDraw only had locals moved).

### Not fixed here, and why

This list was written for the first batch. Each line carries its status after all fix waves; "Status after all fix
waves" at the top has the full table.

- **P1-03, the server never validates movement.** When the first batch was written, this needed a server-side speed
  and teleport check tuned against real play (dashes, knocks, Skyrider, lag). It is the root cause behind the remaining
  "a modified client can..." items, and it needed a design pass and Play testing, not a blind edit.
  - *Update (wave 2):* built, as a conservative guard with an `Enforce` switch. See "Movement guard (P1-03)" above.
  - The Play testing this line asked for is still to do. Start with `Enforce = false`.
- **P2-06, every cosmetic is free.** `OwnsSkin` returns true by design until skins are sold. Gating it needs a
  cosmetic-ownership field in the save and Robux products, which is feature work. Do it before any skin goes on sale.
  - *Update:* still not fixed. Wave 1 added a note in EconomyConfig's header only.
- **P4-02 (honest Zephyr can't escape Earthen Tomb) and P4-03 (which Techniques break the Tomb).** These are design
  rules, so they are left for the owner.
  - *Update:* still DESIGN. The Entombed text in SpellshotConfig now records what the code does: Skyrider and Shadow
    Step are refused while Entombed (P4-01, GC-07).
- **The rest of the report's Medium and Low findings** were untouched by this first batch unless listed above.
  - *Update:* waves 1 and 2 worked through every one of them. See the table at the top.
