"""Cover sensitivity: P1/A on the open floor (results_main.json) vs 40% of aimed shots blocked (results_cover.json)."""
import json, os
HERE = os.path.dirname(os.path.abspath(__file__))
M = json.load(open(os.path.join(HERE, "results_main.json")))["jobs"]
C = json.load(open(os.path.join(HERE, "results_cover.json")))["jobs"]
MONO = ["Aqua", "Cryo", "Pyro", "Radiant", "Terra", "Toxin", "Umbra", "Voltaic", "Zephyr"]
STRAT = ["S1", "S2", "S3", "S4", "S5"]


def wr(R, pol, a, b):
    k = f"P|1|A|{pol}|{a}|{b}"
    return R[k]["win"] / R[k]["n"] if k in R else 1 - R[f"P|1|A|{pol}|{b}|{a}"]["win"] / R[f"P|1|A|{pol}|{b}|{a}"]["n"]


def mean(x): x = list(x); return sum(x) / len(x)


for name, R in (("open floor", M), ("40% cover", C)):
    keys = [k for k in R if k.startswith("P|1|A|")]
    wipe = mean(R[k]["wipe_dur"] / max(1, R[k]["wipe_n"]) for k in keys)
    to = mean(R[k]["timeout"] / R[k]["n"] for k in keys)
    st = {pol: mean(1 - wr(R, pol, m, s) for m in MONO for s in STRAT) for pol in ("low", "soft")}
    c60 = {pol: sum(1 for m in MONO for s in STRAT if 1 - wr(R, pol, m, s) >= 0.6) for pol in ("low", "soft")}
    per = {s: mean(1 - wr(R, pol, m, s) for m in MONO for pol in ("low", "soft")) for s in STRAT}
    pm = {m: mean(wr(R, pol, m, s) for s in STRAT for pol in ("low", "soft")) for m in MONO}
    heal = dmg = 0.0
    for k in keys:
        o = R[k]
        heal += sum(v for kk, v in o["st"].get("heal", {}).items())
        dmg += sum(v for kk, v in o["st"].get("dmg", {}).items())
    print(f"{name}: wipe {wipe:.1f} s, clock-outs {100 * to:.1f}%, strategy mean vs monos {100 * st['low']:.0f} / {100 * st['soft']:.0f}, "
          f"strategy >=60%: {c60['low']} / {c60['soft']} of 45, healing as % of damage {100 * heal / dmg:.1f}")
    print("   per strategy:", {s: round(100 * v) for s, v in per.items()})
    print("   per mono vs strategy:", {m: round(100 * v) for m, v in pm.items()})
