import json, sys
R = json.load(open(sys.argv[1]))["jobs"]
cfg = sys.argv[2] if len(sys.argv) > 2 else "P|1|A|low"
MONO = ["Aqua","Cryo","Pyro","Radiant","Terra","Toxin","Umbra","Voltaic","Zephyr"]
for m in MONO:
    agg = {}; n = 0; alive = 0; full = 0; dry = 0
    for k, o in R.items():
        if not k.startswith(cfg + "|" + m + "|"): continue
        if k.split("|")[5] == m: continue
        n += o["n"]
        for cat in ("dmg", "casts", "mana", "lasthit"):
            for kk, v in o["st"].get(cat, {}).items():
                if kk.startswith("A|" + m + "|"): agg.setdefault(cat, {})[kk.split("|")[2]] = agg.get(cat, {}).get(kk.split("|")[2], 0) + v
        alive += o["st"].get("alive", {}).get("A|" + m, 0); full += o["st"].get("full", {}).get("A|" + m, 0); dry += o["st"].get("dry", {}).get("A|" + m, 0)
    tot = sum(agg.get("dmg", {}).values())
    print(f"{m:8s} n={n} dmg/round {tot/n:5.0f}  alive/round {alive/n:4.1f}s (3 players)  dps/player {tot/max(alive,1e-9):4.1f}  full {full/alive:.2f} dry {dry/alive:.2f}")
    print("   dmg:", ", ".join(f"{a} {v/n:.0f}" for a, v in sorted(agg.get("dmg", {}).items(), key=lambda kv: -kv[1])))
    print("   casts:", ", ".join(f"{a} {v/n:.1f}" for a, v in sorted(agg.get("casts", {}).items(), key=lambda kv: -kv[1])))
print()
for m in ["Radiant", "Terra", "Toxin", "S1", "S2", "S4"]:
    n = 0; agg = {}
    for k, o in R.items():
        parts = k.split("|")
        if not k.startswith(cfg + "|"): continue
        side = "A" if parts[4] == m else ("B" if parts[5] == m else None)
        if side is None or parts[4] == parts[5]: continue
        n += o["n"]
        for cat in ("heal", "absorb", "peel", "peel_ok"):
            for kk, v in o["st"].get(cat, {}).items():
                if kk.startswith(side + "|"): agg.setdefault(cat, {})[kk[2:]] = agg.get(cat, {}).get(kk[2:], 0) + v
    print(m, "n", n, {c: {a: round(v / n, 1) for a, v in d.items()} for c, d in agg.items()})
