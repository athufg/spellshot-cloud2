"""Copy the simulation scripts and their results into <repo>/sim, as-is.

The files to copy are listed in tools/sim_sources.txt, one path per line (absolute, or relative to source_root);
"#" starts a comment. Each lands in sim/ under its own file name. A listed file that is missing stops the run.

Usage: copy_sims.py <repo_dir> [<source_root>]      (source_root defaults to "D:/Spellshot - Atharv")
"""
import os, shutil, sys

repo = os.path.abspath(sys.argv[1])
src = os.path.abspath(sys.argv[2] if len(sys.argv) > 2 else "D:/Spellshot - Atharv")
listing = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sim_sources.txt")
with open(listing, encoding="utf-8") as f:
    paths = [ln.split("#", 1)[0].strip() for ln in f]
paths = [os.path.join(src, p) if not os.path.isabs(p) else p for p in paths if p]
missing = [p for p in paths if not os.path.isfile(p)]
if missing:
    raise SystemExit("listed in sim_sources.txt but not found:\n  " + "\n  ".join(missing))
os.makedirs(os.path.join(repo, "sim"), exist_ok=True)
for p in paths:
    shutil.copyfile(p, os.path.join(repo, "sim", os.path.basename(p)))
print(f"sims: {len(paths)} files" + ("" if paths else " (sim_sources.txt lists none yet)"))
