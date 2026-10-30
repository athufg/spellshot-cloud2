"""q28_template.md + q28_answer.md (+ q28_swap.md) + q28_compare.md -> SPELLSHOT_Backup/SPELLSHOT_P28_P29_RESULTS.md"""
import os, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
subprocess.check_call([sys.executable, "analyse_q28.py"], cwd=HERE, stdout=subprocess.DEVNULL)
rd = lambda f: open(os.path.join(HERE, f), encoding="utf-8").read().strip()
ans = rd("q28_answer.md")
sw = rd("q28_swap.md") if os.path.exists(os.path.join(HERE, "q28_swap.md")) else "still running."
sg = rd("q28_swap_sugg.md")
out = rd("q28_template.md").replace("{{ANSWER}}", ans.replace("{{SWAP}}", sw).replace("{{SWAP_SUGGESTION}}", sg)).replace("{{TABLES}}", "## Results\n\n" + rd("q28_compare.md"))
assert "{{" not in out, "unfilled placeholder"
open(os.path.join(HERE, "..", "SPELLSHOT_P28_P29_RESULTS.md"), "w", encoding="utf-8").write(out + "\n")
print(len(out), "chars")
