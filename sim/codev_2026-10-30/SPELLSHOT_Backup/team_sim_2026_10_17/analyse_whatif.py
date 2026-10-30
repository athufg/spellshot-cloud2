"""Each what-if (results_whatif_<tag>.json) against the main P1/A run (dataset P)."""
import json, os
HERE = os.path.dirname(os.path.abspath(__file__))
MONO = ["Aqua", "Cryo", "Pyro", "Radiant", "Terra", "Toxin", "Umbra", "Voltaic", "Zephyr"]
STRAT = ["S1", "S2", "S3", "S4", "S5"]
RUNS = [("main P1/A", "results_main.json"), ("all HP 250", "results_whatif_hp250.json"),
        ("Fireball splash 5 in r4", "results_whatif_splash.json"), ("Chain Bolt range 45", "results_whatif_cb45.json"),
        ("Overload 2.5 s per body", "results_whatif_ovl25.json"),
        ("HP 250 + Benediction 30/s, r35, no root", "results_whatif_support.json"),
        ("Fireball 15 every 0.7 s (splash 6)", "results_whatif_fb15.json")]


def mean(x): x = list(x); return sum(x) / len(x) if x else float("nan")


rows = []
for name, f in RUNS:
    p = os.path.join(HERE, f)
    if not os.path.exists(p): continue
    R = {k: v for k, v in json.load(open(p))["jobs"].items() if k.startswith("P|1|A|")}

    def wr(pol, a, b):
        k = f"P|1|A|{pol}|{a}|{b}"
        return R[k]["win"] / R[k]["n"] if k in R else 1 - R[f"P|1|A|{pol}|{b}|{a}"]["win"] / R[f"P|1|A|{pol}|{b}|{a}"]["n"]
    both = lambda a, b: mean(wr(pol, a, b) for pol in ("low", "soft"))
    st = mean(1 - both(m, s) for m in MONO for s in STRAT)
    per = {s: mean(1 - both(m, s) for m in MONO) for s in STRAT}
    pm = {m: mean(both(m, s) for s in STRAT) for m in MONO}
    w2 = mean(both("W2", s) for s in STRAT)
    wipe = mean(o["wipe_dur"] / max(1, o["wipe_n"]) for o in R.values())
    heal = sum(v for o in R.values() for v in o["st"].get("heal", {}).values())
    dmg = sum(v for o in R.values() for v in o["st"].get("dmg", {}).values())
    alive = {}; dd = {}
    for o in R.values():
        for k, v in o["st"].get("alive", {}).items(): alive[k[2:]] = alive.get(k[2:], 0) + v
        for k, v in o["st"].get("dmg", {}).items(): dd[k.split("|")[1]] = dd.get(k.split("|")[1], 0) + v
    dps = {el: dd.get(el, 0) / alive[el] for el in MONO}
    rows.append((name, st, per, pm, w2, wipe, heal / dmg, dps))

print("| Run | Strategy mean vs monos | S1 | S2 | S3 | S4 | S5 | mono-Pyro vs strategy | mono-Voltaic | W2 vs strategy | Wipe (s) | Healing / damage | Pyro dps | Voltaic dps |")
print("|---|" + "---|" * 13)
for name, st, per, pm, w2, wipe, hd, dps in rows:
    print(f"| {name} | {100 * st:.0f} | " + " | ".join(f"{100 * per[s]:.0f}" for s in STRAT) +
          f" | {100 * pm['Pyro']:.0f} | {100 * pm['Voltaic']:.0f} | {100 * w2:.0f} | {wipe:.1f} | {100 * hd:.1f}% | {dps['Pyro']:.1f} | {dps['Voltaic']:.1f} |")
print()
print("Per mono vs strategy comps:", " ; ".join(f"{name}: " + ", ".join(f"{m[:3]} {100 * pm[m]:.0f}" for m in MONO) for name, st, per, pm, *_ in rows))
