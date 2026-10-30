# SPELLSHOT — Build Prompt: spellshot-cloud Deep Bug Test (code-only, unattended, cloud credits)

Target: the `spellshot-cloud` repo (https://github.com/athufg/spellshot-cloud), a read-only text snapshot of the
SPELLSHOT Roblox place. This run is paid for on cloud credits with no budget ceiling: depth and coverage are the
point, not economy. Deliverable is a single findings report; **no file under `game/` is edited.**

<role>
You are auditing `spellshot-cloud` for bugs, for its solo developer, at effectively unlimited depth. You have full
read access to the whole repo and plenty of time and budget — the developer's own words were "no budget," so an
incomplete or shallow pass is the one failure mode that matters here, not cost. This repo's own `README.md` states
its own limits and you must respect them: it is a text snapshot with no live Studio and no way to press Play, so
this is a **code-only** audit — static reading and logical reasoning about what the code does, never execution,
simulation, or a claim that something "works" because it looks right. Done means: every file under `game/` has been
read at least once, each of the six audit passes below has an explicit record in your checklist (findings, or an
explicit "checked, nothing found"), and the report file is written.
</role>

<context>
**What SPELLSHOT is.** A Roblox ranked PvP duel game: 9 Elements (Pyro, Cryo, Voltaic, Terra, Zephyr, Umbra,
Radiant, Toxin, Aqua), each fixing a player's M1, Primary Ability, Passive and Ultimate. Every player also equips up
to 3 **Techniques from one shared pool** — so a Pyro player can run a Technique another Element's kit was built for.
This is a deliberate design pillar, not an edge case, and it is the single largest combinatorial surface in the
codebase: a Technique's code can easily assume "the caster is my own Element" in a way that's only false when a
*different* Element borrows it.

**Cosmetics layer on top of the kit, and can change behavior-adjacent code paths even though they must never change
gameplay.** A **wrap** (`Wrap = "<Element>"` on a `SkinCatalog.Skins` entry) recolours the Default shapes; a **skin**
(`Rework = true`, no palette) remodels them, gated by a Kit module's `On(character)`. Composite ids
(`"<Skin>+<Wrap>"`) let a gradient wrap paint a skin's own pieces. Several modules are at or near Luau's 200-top-
level-local-per-ModuleScript limit (`CryoFX` is the clearest case) and route new functionality through a per-skin
table instead of a new local — get this pattern wrong and it's a hard compile/runtime failure, not just a visual
bug. A `StudioSkin` / `WrapStudio` character attribute stands in for a caster in Studio-only preview paths; this
must never be reachable from a live server.

**Settings that must be honoured uniformly everywhere an effect is drawn:** Graphics Quality (high/medium/low),
Reduce Enemy VFX (an opponent's effects thinned), Reduce Flashing (pulses/flashes dampened), Colourblind-Safe (a
palette swap that must never be the only way a hazard reads). A gap in any one of these, for any Element, wrap, or
skin, is a finding.

**Modes:** Duel (1v1), 2v2, Squad Clash — team-scoped logic (who counts as an ally, who a status effect should or
shouldn't hit, team-size-dependent balance knobs) is its own source of bugs distinct from 1v1 logic.

**Persistence and economy have real stakes.** Sparks is the persistent currency (earned or bought with Robux).
`PlayerData.lua`, `EconomyService.server.lua`, and `SettingsStore.server.lua` are the DataStore-backed modules.
A duplication, loss, or negative-balance bug here is as serious as a competitive-integrity bug, not merely cosmetic.

**Repo layout (191 scripts total, per `game/manifest.json`'s own `scripts` count):**
- `game/ServerScriptService/` — ~30 files, the authoritative server logic: one handler per Element
  (`<Element>Handler.server.lua`), plus `CombatCore.lua`, `DuelMatch.lua`, `PlayerData.lua`,
  `EconomyService.server.lua`, `SettingsStore.server.lua`, `StatusEffects.lua`, `ElementalReactions.server.lua`,
  `HitboxScale.server.lua`, `HubServer.server.lua`, `MovementModeServer.server.lua`, `TrainingGround.server.lua`,
  `UniformAvatar.server.lua`, `AllyDummies.server.lua`, `CombatFeedback.server.lua`,
  `FrostDragonKillHook.server.lua` — plus leftover stage/test scripts whose names start with `_` or end in
  `TestServer` (`_AuroraStage.server.lua`, `_BROStage.server.lua`, `TerraTestServer.server.lua`): read these as live
  code (they are deployed), but their presence in a shipping place is itself worth a finding (see pass 6).
- `game/ReplicatedStorage/Spellshot/` — shared config and tuning: `SpellshotConfig.lua`, `SkinCatalog.lua`,
  `EconomyConfig.lua`, `SpellshotSettings.lua`, `MapRegistry.lua`, and per-ability kit-data modules.
- `game/ReplicatedStorage/IceMagic/` — ~75 files, the client-side VFX/kit modules for every Element, wrap and skin
  (`<Element>FX.lua`, `<Element>Tuning.lua`, `<Element>Wrap.lua`, `<Skin>Kit.lua`, `<Skin>FX.lua`, `VFXLibrary.lua`,
  `CastPose.lua`, `Viewmodel.lua`).
- `game/StarterPlayer/StarterPlayerScripts/` — ~32 client files: `SpellshotInput.client.lua`,
  `MovementController.client.lua`, `AbilityFX.client.lua`, `LoadoutMenu.client.lua`, `SettingsMenu.client.lua`,
  `SettingsRuntime.client.lua`, `StatusReactions.client.lua`, HUD and hub-decoration scripts, and several
  `*TestHarness.client.lua` / `DeflectGustPractice.client.lua` files (same "live but shouldn't be" note as above).
- `game/StarterGui/` — the shop UI, and `MatchHUD_RETIRED.client.lua` — a file literally named retired, still
  present: confirm whether it is actually disabled/unreferenced or could still run.
- `game/ServerStorage/` — three folders that read as staged, not-yet-confirmed-merged fixes:
  `MovementSwitchReviewFix_2026_10_18`, `UmbraReviewFix_2026_10_18`, `_superseded_everfrost_2026_10_14`. Check
  whether the fix each one describes is actually present in the live script it's meant to fix, or whether it's
  sitting unapplied.
- `game/manifest.json` — the rest of the Explorer tree (classes, attributes, key properties) without script source;
  useful for confirming an instance exists, its properties, or that nothing references a script you're about to call
  dead.
- `docs/SPELLSHOT_Design_Manual.md` and `docs/SPELLSHOT_Dev_Diary.md` — what the game should do, and what was built
  when. The repo's own rule: **where code and the manual disagree, the code is what ships** — but a disagreement is
  still worth reporting as its own finding type (pass 6), because it usually means one side is stale, not that one
  side is simply right.
- `sim/` is empty and `tools/` is export tooling, not game logic — out of scope.

**This snapshot can be stale relative to the live Studio place** (the repo's own README says so). You have no way
to check the live place from here. Where a finding's correctness depends on something you cannot see in this
snapshot, say so in the finding rather than asserting it as fact.
</context>

<instructions>
**Read broadly before concluding anything.** Open every file listed above before you start writing findings — not
a sample, not "the ones that sound relevant." A caster-identity assumption bug in a Technique module is invisible
until you've also read the Element handler that calls it and the Element whose Technique it borrowed. Keep a
checklist (a to-do list, or a running markdown scratch file) of every file and every pass below, and update it as
you go, so a later review of your own work (by you or the developer) can see what's been covered.

**Combination is about code paths that depend on more than one axis, not literal enumeration.** Do not try to
"run" every literal cartesian product of Element × Technique × skin × wrap × setting × mode — at this codebase's
size that is many tens of thousands of cells and almost all of them share one code path. Instead: for every piece of
code whose behavior branches on more than one of {Element, equipped Technique, equipped skin, equipped wrap, a
settings toggle, game mode, team}, trace what happens at every value that axis can actually take, in the game's own
data (`SkinCatalog.lua`'s `Offer`/`ElementSkins`/`ElementWraps` tables, the shared Technique pool's membership, the
mode list). That is a finite, enumerable set of real code paths, and finding all of them is the actual job. A
Technique module that only ever reads `self.Owner.Element` is not a priori buggy; one that reads a value from its
*own* Element's tuning table while drawing for a caster of a *different* Element is the shape of bug you're
looking for.

**Six passes.** Treat each as a first-class section of your checklist, not a box to tick quickly:

1. **Server authority / exploit surface.** Every RemoteEvent/RemoteFunction handler in `ServerScriptService`: does
   the server independently derive or clamp what the client claims (damage, position, Element, cooldown remaining,
   mana cost, hit validity), or does it trust a client-sent value outright? Flag every place a client-controlled
   number or boolean reaches a damage calculation, a DataStore write, or a win condition without a server-side
   check. This is the highest-value pass on a competitive Roblox game — treat it that way.
2. **Economy and persistence.** `PlayerData.lua`, `EconomyService.server.lua`, `SettingsStore.server.lua`: read-
   modify-write races (two saves racing on rejoin, a disconnect mid-write), paths that could duplicate or silently
   drop Sparks, default-value fallbacks that could reset progress, session-lock handling.
3. **Combat-state correctness.** `CombatCore.lua`, `DuelMatch.lua`, `StatusEffects.lua`,
   `ElementalReactions.server.lua`, `HitboxScale.server.lua`: ordering and stacking when more than one status or
   reaction applies at once, cooldown/mana edge cases (zero, negative, simultaneous casts), death/respawn racing a
   cast or a status tick, team-mode scoping (ally vs. enemy) for every status and reaction.
4. **The cross-Element combination surface.** The shared Technique pool: for each Technique, read every Element
   handler/FX module that can draw it and confirm it never assumes a caster Element it doesn't actually check. Also
   check Ultimate/Passive interactions that read global match or player state another Element's kit also touches.
5. **Skins and wraps layering.** The Luau-200-local workaround tables (`FBX` and siblings), lazy EditableMesh builds
   and their Default-fallback-on-failure path, `StudioSkin`/`WrapStudio` reachability from a live server, composite
   `"<Skin>+<Wrap>"` id resolution, and whether Graphics Quality / Reduce Enemy VFX / Reduce Flashing /
   Colourblind-Safe are honoured for every skin and wrap, not just the Default look.
6. **Dead code, stale fixes, and code-vs-doc drift.** The `_`-prefixed and `*TestHarness`/`*TestServer` scripts and
   `MatchHUD_RETIRED.client.lua`: confirm what, if anything, could still execute them in a live server/client, and
   flag their mere presence even if provably inert. The three `ServerStorage` review-fix folders: confirm whether
   each described fix is actually present in the live script, or staged and unapplied. Anywhere the Design Manual or
   Dev Diary clearly describes a behavior the code doesn't match, note it (code still wins; note it as a
   documentation-drift finding, not a bug in the code, unless you can't tell which side is stale).

**Delegate by pass, not by file, if your harness supports subagents.** The six passes above are close to
independent and each needs to hold a lot of cross-file context at once (especially pass 4), so one subagent per
pass is a reasonable split; delegating file-by-file would fragment exactly the cross-file reasoning this audit is
for. If you delegate, give each subagent this whole prompt's `<context>` section plus its own pass, and have it
return findings in the format below rather than prose for you to re-parse. Consolidate all subagent output into one
report yourself; do not let a subagent write the final file.

**Report everything you find, with severity attached; do not pre-filter.** Sort out what matters to the developer
at the end, as a separate step (a short "if you only read one section" summary at the top of the report), not by
quietly skipping anything that seems minor while you work.
</instructions>

<output_format>
Write one file: `docs/build_prompts/SPELLSHOT_CLOUD_BUG_REPORT_<today's date, YYYY-MM-DD>.md`, in this repo. Do not
edit, rename, or delete any other file — this is an audit, not a patch; if you prototype a fix to confirm a bug is
real, state the fix in the finding's text, do not leave it in the codebase.

The report:
- A short summary at the top: counts by severity, and the handful of findings you'd lead with if the developer only
  has five minutes.
- Then one entry per finding, grouped by the six passes above, each with: file path(s) and line(s); severity
  (Critical / High / Medium / Low — Critical and High reserved for exploit, economy, and competitive-integrity
  bugs); the exact scenario or combination that triggers it, stated concretely (which Element, which Technique,
  which skin/wrap, which setting, which mode — whatever actually matters for that finding, not a generic
  description); why it's a bug, in the code's own terms; a suggested fix in prose, not a diff.
- A closing section: every file you read, and any file or pass you could not fully complete and why (so the
  developer knows what to re-run, not just what you found).
</output_format>

<edge_cases>
- If a file references something outside this snapshot (an asset id, a DataStore key, a live server's actual
  state) that you cannot verify, say so in the finding rather than guessing either way.
- If you find a real correctness bug that is also described, unfixed, in the Dev Diary or a `ServerStorage` review-
  fix folder, still report it — the developer needs to know it reached `game/` regardless of whether it was already
  known.
- If a pass turns up nothing after a genuinely complete read, write that explicitly in the report ("Pass 3: no
  findings; files read: ...") rather than omitting the section — an unattended reader of this report needs to be
  able to tell "checked, clean" apart from "not checked."
</edge_cases>

A standing instruction from the developer, the person you are working for. It is about how your turns end. A
message with no tool call in it ends your turn, and the work stops there until someone asks you to continue — and
this run has no one watching to do that. You have seen yourself end turns in four ways while work you were asked
for was still owed, and the developer does not want any of them here: a long summary that closes by announcing the
next step and has no tool call, so the next thing never starts; an offer to carry on with something unless the
developer would prefer otherwise, which stops to wait for an answer nobody is there to give; a list of decisions for
the developer when, by your own account, none of them blocks the rest of the audit; deciding that this is a good
place to report because the run has been long or a pass is done. Status notes in your checklist are welcome and so
are flags inside a finding, but put them in the same message as your next tool call and carry on with whatever does
not depend on an answer. The only stops this instruction allows are ones where nothing can move without the
developer, or where something you need is deliberately protected from you (a credential, a path outside this repo).
Finishing all six passes, writing the report, and confirming the checklist is complete is the actual finish line —
treat anything short of that as mid-task, not a stopping point.
