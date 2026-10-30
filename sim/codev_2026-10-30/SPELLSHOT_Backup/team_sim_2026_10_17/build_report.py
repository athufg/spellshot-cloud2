"""Stitches report_template.md + report_static.md + generated tables into SPELLSHOT_3V3_SIM_REPORT.md."""
import os, re, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(HERE), "SPELLSHOT_3V3_SIM_REPORT.md")
tpl = open(os.path.join(HERE, "report_template.md"), encoding="utf-8").read()
static = open(os.path.join(HERE, "report_static.md"), encoding="utf-8").read()
tables = open(os.path.join(HERE, "tables_P.md"), encoding="utf-8").read()
sections = {}
for chunk in re.split(r"(?m)^### ", tables)[1:]:
    head, _, body = chunk.partition("\n")
    sections[head.strip()] = body.strip()
cfg_names = ["Pass 1 / Variant A (no jump)", "Pass 1 / Variant B (jump + double jump)",
             "Pass 2 / Variant A (no jump)", "Pass 2 / Variant B (jump + double jump)"]
configs = "\n\n".join(f"### 3.{i + 1} {n}\n\n{sections[n]}" for i, n in enumerate(cfg_names))
env = dict(os.environ, PYTHONIOENCODING="utf-8")
run = lambda *a: subprocess.run([sys.executable, *a], cwd=HERE, capture_output=True, text=True, env=env, encoding="utf-8").stdout.strip()
swaps = run("final_swaps.py")
whatif = run("analyse_whatif.py")
recs = open(os.path.join(HERE, "report_recs.md"), encoding="utf-8").read().strip()
openq = open(os.path.join(HERE, "report_open.md"), encoding="utf-8").read().strip()
whatif_block = ("## What-if checks behind the recommendations\n\nPass 1 / Variant A, prompt numbers, 200 rounds per matchup "
                "per policy, one change at a time. Strategy, S1–S5 and W2 columns are mean win % against the nine monos; "
                "mono columns are mean win % against the five strategy comps.\n\n" + whatif.split("\n\nPer mono")[0])
out = (tpl.replace("{{STATIC}}", static.strip()).replace("{{CONFIGS}}", configs).replace("{{SWAPS}}", swaps)
          .replace("{{WHATIF}}", whatif_block).replace("{{RECS}}", recs).replace("{{OPEN}}", openq)
          .replace("{{ABILITY}}", sections["Ability economy in team play (P1/A, both policies, every comp)"]))
assert "{{" not in out, re.findall(r"\{\{[A-Z]+\}\}", out)
open(OUT, "w", encoding="utf-8").write(out)
print("wrote", OUT, len(out.splitlines()), "lines", len(out), "chars")
