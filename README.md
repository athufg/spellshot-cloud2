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
| `sim/` | Simulation scripts and their results. Empty for now: see `sim/README.md`. |
| `tools/` | The refresh scripts (Windows, need Studio). A cloud session does not run them. |

## Read first

- **For open questions:** the Problem Sheet. **It is not in this repo yet.**
- **For what is ready to build:** the most recent Implementation Handoff. **It is not in this repo yet.**
- Until they arrive, `docs/SPELLSHOT_Design_Manual.md` says what the game should be, and the latest entries of
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
