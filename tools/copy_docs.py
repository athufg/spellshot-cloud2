"""Copy SPELLSHOT's design docs into <repo>/docs, as-is (byte copies, no edits).

  docs/                  SPELLSHOT/SPELLSHOT_*.md and SPELLSHOT/HANDOFF.md
  docs/build_prompts/    the Opus build prompts: SPELLSHOT/Opus5*.md, plus any in "Claude outputs/" not already there
  docs/vfx_handoffs/     every SPELLSHOT/vfx_blocking/**/*HANDOFF*.md, named by its folder path ("/" -> "__")

Files in docs/ that no longer have a source are listed, never deleted.

Usage: copy_docs.py <repo_dir> [<source_root>]      (source_root defaults to "D:/Spellshot - Atharv")
"""
import glob, os, shutil, sys

repo = os.path.abspath(sys.argv[1])
src = os.path.abspath(sys.argv[2] if len(sys.argv) > 2 else "D:/Spellshot - Atharv")
game = os.path.join(src, "SPELLSHOT")
docs = os.path.join(repo, "docs")

plan = {}  # destination (relative to docs/) -> source path
for p in sorted(glob.glob(os.path.join(game, "SPELLSHOT_*.md"))) + [os.path.join(game, "HANDOFF.md")]:
    if os.path.isfile(p):
        plan[os.path.basename(p)] = p
for folder in (game, os.path.join(src, "Claude outputs")):
    for p in sorted(glob.glob(os.path.join(folder, "Opus5*.md"))):
        plan.setdefault("build_prompts/" + os.path.basename(p), p)
# (2026-10-30) the design manual / lore PDFs and the change logs beside the design manual
for pat in ("spellshot*.pdf", "CHANGES_*.md", "IMPLEMENTED.md"):
    for p in sorted(glob.glob(os.path.join(game, pat))):
        plan.setdefault(os.path.basename(p), p)
blocking = os.path.join(game, "vfx_blocking")
for p in sorted(glob.glob(os.path.join(blocking, "**", "*HANDOFF*.md"), recursive=True)):
    plan["vfx_handoffs/" + os.path.relpath(p, blocking).replace(os.sep, "__")] = p

changed = 0
for rel, p in plan.items():
    dst = os.path.join(docs, rel)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    with open(p, "rb") as f:
        data = f.read()
    if os.path.isfile(dst):
        with open(dst, "rb") as f:
            if f.read() == data:
                continue
    shutil.copyfile(p, dst)
    changed += 1

have = {os.path.relpath(os.path.join(r, n), docs).replace(os.sep, "/") for r, _, ns in os.walk(docs) for n in ns}
stale = sorted(have - set(plan))
print(f"docs: {len(plan)} files, {changed} new or changed")
for s in stale:
    print(f"  no source any more (left in place): docs/{s}")
