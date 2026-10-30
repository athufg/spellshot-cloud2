# SPELLSHOT (cloud copy)

SPELLSHOT is a Roblox ranked duel game: RIVALS' precise, mobile-first, ranked match structure (Duel, 2v2,
Squad Clash), with elemental spellcasting kits instead of guns. Each player picks an Element (Pyro, Cryo, Voltaic,
Terra, Zephyr, Umbra, Radiant, Toxin, Aqua), which fixes their M1, Primary Ability, Passive and Ultimate, and adds
up to 3 Techniques from a shared pool; Robux buys looks and roster access, never power.

This repo is a read-only snapshot for Claude sessions that run in the cloud, away from the machine with Studio on
it. The live game is the Studio place, not this repo.

## Layout

| Path | What it is |
|---|---|
| `game/` | Every script in the place, at its Explorer path: `Script` = `Name.server.lua`, `LocalScript` = `Name.client.lua`, `ModuleScript` = `Name.lua`. A script's own children sit in a folder of the same name beside it. |
| `game/manifest.json` | The rest of the Explorer tree, without script sources: each instance's class, attributes and key properties (values, asset ids, sizes, materials, colours). Large piles of parts are counted, not listed. `skipped` names what was left out; `renamed` maps any file whose name had to change back to its real Explorer path. |
| `docs/` | The design docs, copied as-is: `SPELLSHOT_Design_Manual.md` (the spec), `SPELLSHOT_Dev_Diary.md` (what was built, when), the SFX plans, and `HANDOFF.md` (an old 2026-09-12 project handoff). |
| `docs/build_prompts/` | The build prompts each VFX kit was made from. |
| `docs/vfx_handoffs/` | Per-kit VFX handoff specs from the Blender stage, named by their folder path. |
| `docs/codev_2026-10-30/` | The co-developer's paper trail, copied as-is (2026-10-30), in its source folders: the Problem Sheet, the suggestions list, the Balance Sheet dashboard (`claude_artifacts/SPELLSHOT_Balance_Sheet_dashboard/page.html` + its `data/`), the Implementation Handoffs (`claude_chat_extracts/`), the CHANGES notes, the 3v3 / P27-P29 sim reports, lore and season docs, and older design-manual / dev-diary copies. `FILE_LIST.csv` gives each file's original path, date and sha256. |
| `sim/codev_2026-10-30/` | The simulation scripts (`team_sim_2026_10_17/`, `balance_2026_10_16/`, `balance_2026_10_17/`, ...) and their results. Result files over 5 MB are gzipped (`*.json.gz`: `gzip.open(path, "rt")`). The two `.pkl` caches were left out (pickles run code when loaded; rebuild them by rerunning the sim). |
| `sim/` (top) | See `sim/README.md`. |
| `tools/` | The refresh scripts (Windows, need Studio). A cloud session does not run them. |

## Read first

- **For open questions:** the Problem Sheet: `docs/codev_2026-10-30/SPELLSHOT_Backup/SPELLSHOT_Problem_Sheet.md` (the newest
  copy, 2026-10-29; an older 10-18 one is under `SPELLSHOT_Repo/docs/`).
- **For what is ready to build:** the most recent Implementation Handoff:
  `docs/codev_2026-10-30/claude_chat_extracts/Implementation_Handoff_2026-10-18_current.txt`.
- Balance: the Balance Sheet dashboard (`docs/codev_2026-10-30/claude_artifacts/SPELLSHOT_Balance_Sheet_dashboard/`) and
  the suggestions list (`docs/codev_2026-10-30/SPELLSHOT_Backup/SPELLSHOT_SUGGESTIONS_LIST.md`).
- These came from the co-developer's machine and are dated; `docs/SPELLSHOT_Design_Manual.md` says what the game should be, and the latest entries of
  `docs/SPELLSHOT_Dev_Diary.md` say what was built last. If the code and the manual disagree, the code is what ships.
  Ask before treating the manual as correct.

## What a cloud session cannot do

- It cannot press Play, see the render, run Luau against the live Studio place, or check that a change works.
- Every change made here is a text edit, and it does nothing until someone pulls it back into Studio.
- Rojo is not set up. The return trip is manual: the owner copies each changed script into Studio by hand, or has a
  local Claude session with Studio access apply it.
- So keep changes small and list every file touched, with its Explorer path, so they can be carried across.
- This snapshot can be out of date. `game/manifest.json` says when and where it was exported. The git log shows each
  refresh.

## Refreshing (on the Studio machine)

Open Studio on the SPELLSHOT place with "Enable Studio as MCP server" on (Assistant, then ..., then Manage MCP Servers),
then run:

```
powershell -ExecutionPolicy Bypass -File tools\refresh.ps1
```

This re-exports `game/` from Studio, re-copies `docs/` and the files listed in `tools/sim_sources.txt`, commits, and
pushes (never with force). Add `-NoPush` to stop after the local commit.
