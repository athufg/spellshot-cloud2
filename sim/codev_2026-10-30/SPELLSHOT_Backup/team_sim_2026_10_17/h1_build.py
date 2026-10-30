"""h1_template.md + the sections below + h1_compare.md -> SPELLSHOT_Backup/SPELLSHOT_HANDOFF_TESTS.md"""
import os, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
subprocess.check_call([sys.executable, "analyse_h1.py"], cwd=HERE, stdout=subprocess.DEVNULL)
VOLT = """**Both levers work, with a clean dose curve. Range and damage together bring Voltaic to average.** Voltaic's change
against K, on the same seeds; the Pyro − Voltaic gap starts at 17.5:

| Change | Voltaic | Pyro − Voltaic | Voltaic dies |
|---|---|---|---|
| K (Chain Bolt range 45, 8 a bolt) | 42.0% | 17.5 | 73% |
| Range 55 | +4.1 | 12.6 | 69% |
| Range 65 | +6.5 | 9.4 | 66% |
| 10 a bolt | +3.5 | 13.5 | 70% |
| 12 a bolt | +7.6 | 8.3 | 66% |
| **Range 55 and 10 a bolt** | **+8.2 (50.2%)** | **7.5** | **65%** |

- **More reach and damage also keep Voltaic alive:** its death rate falls from 73% to 65%. It kills before it is
  killed, which escape tools (P27) never managed.
- **The gain is spread across the others:** Pyro, Zephyr, Umbra, Radiant and Cryo lose 0.4 to 1.8 each. Terra
  doesn't move beyond noise (+0.3 to +0.8).
- **The overall spread doesn't move:** Element range 28.0 → 29.1–30.4, because Zephyr drops to 39.6–40.6 at the
  bottom; without Terra, 18.1–18.6; comp SD 19.3–19.6. Fixing Voltaic just hands "worst" to Zephyr and Umbra.
- **Suggested dose:** range 55 with 10 a bolt (+8.2), or 12 a bolt alone (+7.6) if you'd rather keep the range."""
UMBRA = """**A separate escape charge finally works, and adds a little on top of dive play.** Measured against K with P27's dive
play and half cooldown, so only the new charge differs:

| Change | Umbra | Umbra dies | Blink-outs per round |
|---|---|---|---|
| K | 42.2% | 65% | 0.16 |
| K + dive play + half cooldown (control) | +1.9 (44.1%) | 67% | 0.38 |
| + escape blink, own 10 s cooldown | +1.1 more (45.2%) | 63% | 1.54 |
| + escape blink, own 6 s cooldown | +1.5 more (45.6%) | 63% | 1.98 |

- **The exit now fires:** blink-outs go from 0.38 to 1.5–2.0 a round, and Umbra's death rate drops from 67% to 63%.
- **The gain is small** (+1.1 / +1.5 on paired seeds, against ±0.8 noise), for +3.0 to +3.4 in total with dive play.
  Umbra stays below average (45.6%).
- **Dive play is a bot behaviour I added in P27.** The escape charge only pays off for players who dive.
- **The overall spread doesn't move** (Element range 27.4–27.7, comp SD 18.7–18.8)."""
HEAD = """## Headline: everything together

K plus Chain Bolt range 55 and 10 a bolt, plus Umbra's dive play, half cooldown and a 6 s escape blink:

| | Element range | Without Terra | Comp SD | Worst Elements |
|---|---|---|---|---|
| v3, live Cryo | 28.5 | 18.5 | 20.1 | Umbra 42.1, Zephyr 43.2, Aqua 43.7 |
| K | 28.0 | 18.3 | 19.6 | Zephyr 41.2, Voltaic 42.0, Umbra 42.2 |
| All together, 84 comps | 29.7 | 19.7 | 18.2 | Zephyr 38.5, Umbra 44.9, Radiant 45.7 |
| All together, one-Terra rule | — (Terra 50% by rule) | 22.0 | 14.6 | Zephyr 38.8, Radiant 42.8, Aqua 43.7 |

Marvel Rivals' 12.5 is still far off. The fixes so far lift the Elements they target: Voltaic to 50%, Aqua to 47–49, Cryo
to 50–51, Umbra to 45%. Comp SD falls 20.1 → 18.2 (14.6 under the role rule). But the Element range is pinned by
Terra at the top (about 68–70%, or by its role-rule partners Pyro and Cryo at about 60%) and **Zephyr at the bottom (about
39% once the other fixes are in)**. Zephyr is the next Element to look at, then Radiant.

## Suggestions

1. **Adopt the one-tank rule (T1) if team mode ships, with Terra as the only tank for now.** It removes the Terra /
   no-Terra split (comp SD about 20 → 15) and turns balance into the cleaner question of who partners Terra. Don't make
   Aqua an alternative tank: Aqua comps lose 63–37 to Terra comps even with standing walls. **Confidence:
   medium-high.**
2. **Give Voltaic Chain Bolt range 55 and 10 a bolt** (+8.2, Voltaic to 50%, death rate 73% → 65%). **Confidence:
   medium-high:** clean dose curve.
3. **Give Umbra's escape its own charge** (a 6 s blink separate from Shadow Step): +1.5 on top of dive play. Small, but
   it is the first escape change that works. **Confidence: medium.**
4. **Keep Blizzard at 20,** including under the role rule: 32 makes Cryo the top Terra partner and widens the range.
5. **Next:** Zephyr (about 39% with the other fixes in, now the worst), then Radiant (43% as a Terra partner). Then re-run
   everything under the role rule, the only setting where the Element range means "which Element is good", not "which
   comps have Terra"."""
rd = lambda f: open(os.path.join(HERE, f), encoding="utf-8").read().strip()
out = rd("h1_template.md").replace("{{VOLT}}", VOLT).replace("{{UMBRA}}", UMBRA)
out = out.replace("## Answer\n", HEAD + "\n\n## Answer by priority\n", 1)
out = out.replace("{{TABLES}}", "## Results\n\n" + rd("h1_compare.md"))
assert "{{" not in out
open(os.path.join(HERE, "..", "SPELLSHOT_HANDOFF_TESTS.md"), "w", encoding="utf-8").write(out + "\n")
print(len(out), "chars")
