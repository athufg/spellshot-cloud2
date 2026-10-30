"""How much of each comp's P1/A record comes from reactions: results_main.json vs results_rxoff.json (dataset P)."""
import json, os
HERE = os.path.dirname(os.path.abspath(__file__))
M = json.load(open(os.path.join(HERE, "results_main.json")))["jobs"]
X = json.load(open(os.path.join(HERE, "results_rxoff.json")))["jobs"]
MONO = ["Aqua", "Cryo", "Pyro", "Radiant", "Terra", "Toxin", "Umbra", "Voltaic", "Zephyr"]
OTHER = ["S1", "S2", "S3", "S4", "S5", "W1", "W2"]


def wr(R, pol, a, b):
    k = f"P|1|A|{pol}|{a}|{b}"
    if k in R: return R[k]["win"] / R[k]["n"]
    k = f"P|1|A|{pol}|{b}|{a}"
    return 1 - R[k]["win"] / R[k]["n"] if k in R else None


def mean(x): x = [v for v in x if v is not None]; return sum(x) / len(x) if x else float("nan")


print("| Comp | Reactions it uses | Mean win % vs the 9 monos, reactions on | Reactions off | Change |")
print("|---|---|---|---|---|")
RXN = {"S3": "Melt", "S5": "Frozen", "W2": "Overload", "W1": "Toxic Squall", "S1": "none", "S2": "none", "S4": "none"}
for c in OTHER:
    on = mean(wr(M, pol, c, m) for m in MONO for pol in ("low", "soft") if wr(M, pol, c, m) is not None)
    off = mean(wr(X, pol, c, m) for m in MONO for pol in ("low", "soft") if wr(X, pol, c, m) is not None)
    if on != on: continue
    print(f"| {c} | {RXN[c]} | {100 * on:.0f} | {100 * off:.0f} | {100 * (off - on):+.0f} |")
print()
print("Strategy comps head to head, mean win % vs the other four (on / off):",
      ", ".join(f"{s} {100 * mean(wr(M, p, s, t) for t in OTHER[:5] if t != s for p in ('low', 'soft')):.0f}/"
                f"{100 * mean(wr(X, p, s, t) for t in OTHER[:5] if t != s for p in ('low', 'soft')):.0f}" for s in OTHER[:5]))
print("W2 vs strategy (on / off):", f"{100 * mean(wr(M, p, 'W2', s) for s in OTHER[:5] for p in ('low', 'soft')):.0f} / "
      f"{100 * mean(wr(X, p, 'W2', s) for s in OTHER[:5] for p in ('low', 'soft')):.0f}")
