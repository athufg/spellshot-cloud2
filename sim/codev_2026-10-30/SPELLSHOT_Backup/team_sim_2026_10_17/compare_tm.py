"""Current game vs the team-mode package, dataset L. Writes tm_compare.md.
105-matchup runs: results_main.json (L, current AI), results_pkg_basetp.json (current stats + team play),
results_pkg_tm1tp.json (package + team play), results_pkg_tm1.json (package, current AI).
Round-robins of the 84 no-duplicate comps (Variant A, lowest-HP): results_rr84_basetp.json, results_rr84_tm1tp.json."""
import json, os, statistics as stt
HERE = os.path.dirname(os.path.abspath(__file__))
MONO = ["Aqua", "Cryo", "Pyro", "Radiant", "Terra", "Toxin", "Umbra", "Voltaic", "Zephyr"]
STRAT = ["S1", "S2", "S3", "S4", "S5"]
COMP = {"S1": ["Terra", "Radiant", "Pyro"], "S2": ["Terra", "Radiant", "Voltaic"], "S3": ["Terra", "Cryo", "Pyro"],
        "S4": ["Radiant", "Umbra", "Pyro"], "S5": ["Cryo", "Aqua", "Terra"], "W1": ["Aqua", "Toxin", "Zephyr"],
        "W2": ["Pyro", "Pyro", "Voltaic"]}
out = []
P = out.append


def load(f, prefix=None):
    p = os.path.join(HERE, f)
    if not os.path.exists(p): return None
    R = json.load(open(p))["jobs"]
    return {k: v for k, v in R.items() if prefix is None or k.startswith(prefix)}


def mean(x): x = list(x); return sum(x) / len(x) if x else float("nan")


def set105(R, var):
    """Headline numbers for one 105-matchup run and one variant (both policies pooled)."""
    J = {k: o for k, o in R.items() if k.split("|")[2] == var}

    def wr(a, b):
        vals = []
        for pol in ("low", "soft"):
            k = f"L|1|{var}|{pol}|{a}|{b}"
            if k in J: vals.append(J[k]["win"] / J[k]["n"])
            else:
                k = f"L|1|{var}|{pol}|{b}|{a}"
                vals.append(1 - J[k]["win"] / J[k]["n"])
        return mean(vals)
    h = {"wipe": mean(o["wipe_dur"] / max(1, o["wipe_n"]) for o in J.values()),
         "clock": mean(o["timeout"] / o["n"] for o in J.values()),
         "strat": mean(1 - wr(m, s) for m in MONO for s in STRAT),
         "strat60": sum(1 for m in MONO for s in STRAT if 1 - wr(m, s) >= 0.6),
         "per_strat": {s: mean(1 - wr(m, s) for m in MONO) for s in STRAT},
         "pyro": mean(wr("Pyro", s) for s in STRAT), "w2": mean(wr("W2", s) for s in STRAT),
         "w1": mean(wr("W1", s) for s in STRAT)}
    st = {}
    for o in J.values():
        for cat in ("dmg", "heal", "absorb", "alive"):
            for kk, v in o["st"].get(cat, {}).items(): st.setdefault(cat, {})[kk[2:]] = st.get(cat, {}).get(kk[2:], 0) + v
    dmg = sum(st["dmg"].values()); heal = sum(st.get("heal", {}).values()); absorb = sum(st.get("absorb", {}).values())
    h["heal_share"] = heal / dmg
    h["protect_share"] = (heal + absorb) / (dmg + absorb)
    alive = st["alive"]
    eld = {el: sum(v for k, v in st["dmg"].items() if k.split("|")[0] == el) / alive[el] for el in MONO}
    rad = sum(v for k, v in st.get("heal", {}).items() if k.split("|")[0] == "Radiant" and k.split("|")[1] in ("BN", "LanceHeal", "Overflow"))
    rad += st.get("absorb", {}).get("Radiant|BL", 0)
    h["radiant_protect"] = rad / alive["Radiant"]
    h["terra_wall"] = st.get("absorb", {}).get("Terra|BW", 0) / alive["Terra"]
    h["eld"] = eld
    srt = sorted(eld.values(), reverse=True)
    h["pyro_ratio"] = eld["Pyro"] / max(v for el, v in eld.items() if el != "Pyro")
    h["top_ratio"] = srt[0] / srt[1]
    return h


runs = [("Current game, current AI", load("results_main.json", "L|1|")), ("Current game + team play", load("results_pkg_basetp.json")),
        ("Package v1 + team play", load("results_pkg_tm1tp.json")), ("Package v1, current AI", load("results_pkg_tm1.json")),
        ("Package v2 + team play", load("results_pkg_tm2tp.json")), ("Package v3 + team play", load("results_pkg_tm3tp.json"))]
runs = [(n, R) for n, R in runs if R]
P("## The 105 matchups: current game vs the package (live values)\n")
for var in ("A", "B"):
    H = [(n, set105(R, var)) for n, R in runs]
    P(f"### Variant {var} ({'no jump' if var == 'A' else 'jump + double jump'})\n")
    P("| Measure | " + " | ".join(n for n, _ in H) + " |"); P("|---|" + "---|" * len(H))
    rows = [("Mean round to a wipe (s)", lambda h: f"{h['wipe']:.1f}"), ("Rounds to the 90 s clock", lambda h: f"{100 * h['clock']:.0f}%"),
            ("Healing as a share of all damage", lambda h: f"{100 * h['heal_share']:.0f}%"),
            ("Healing + shields + wall, share of incoming", lambda h: f"{100 * h['protect_share']:.0f}%"),
            ("Radiant: heals + shields per second alive", lambda h: f"{h['radiant_protect']:.1f}"),
            ("Terra: wall absorbed per second alive", lambda h: f"{h['terra_wall']:.1f}"),
            ("Terra: own damage per second alive", lambda h: f"{h['eld']['Terra']:.1f}"),
            ("Pyro damage/s per player ÷ next Element", lambda h: f"{h['pyro_ratio']:.2f}"),
            ("Strategy comps' mean win % vs monos", lambda h: f"{100 * h['strat']:.0f}"),
            ("Of 45, strategy wins ≥ 60%", lambda h: f"{h['strat60']}"),
            ("S1 / S2 / S3 / S4 / S5 vs monos", lambda h: " / ".join(f"{100 * h['per_strat'][s]:.0f}" for s in STRAT)),
            ("Mono-Pyro vs strategy comps", lambda h: f"{100 * h['pyro']:.0f}"),
            ("W2 (Pyro, Pyro, Voltaic) vs strategy comps", lambda h: f"{100 * h['w2']:.0f}"),
            ("W1 (Aqua, Toxin, Zephyr) vs strategy comps", lambda h: f"{100 * h['w1']:.0f}")]
    for label, f in rows: P(f"| {label} | " + " | ".join(f(h) for _, h in H) + " |")
    P("")
    P("Damage per player per second alive: " + "; ".join(f"{n}: " + ", ".join(f"{el[:3]} {h['eld'][el]:.0f}" for el in MONO) for n, h in H))
    P("")

# ---------------------------------------------------------------- the 84-comp round-robin
def rr(f):
    R = load(f)
    if not R: return None
    score = {}; games = {}; wipe = []
    for k, o in R.items():
        _, var, a, b = k.split("|")
        w = o["win"] / o["n"]
        score[a] = score.get(a, 0) + w; games[a] = games.get(a, 0) + 1
        score[b] = score.get(b, 0) + 1 - w; games[b] = games.get(b, 0) + 1
        wipe.append(o["wipe_dur"] / max(1, o["wipe_n"]))
    wr = {c: score[c] / games[c] for c in score}
    el = {e: mean(v for c, v in wr.items() if e in c.split("+")) for e in MONO}
    grp = {"Terra + Radiant (tank + support)": [v for c, v in wr.items() if "Terra" in c and "Radiant" in c],
           "Terra, no Radiant": [v for c, v in wr.items() if "Terra" in c and "Radiant" not in c],
           "Radiant, no Terra": [v for c, v in wr.items() if "Radiant" in c and "Terra" not in c],
           "Neither": [v for c, v in wr.items() if "Terra" not in c and "Radiant" not in c]}
    return wr, el, grp, mean(wipe)


RRS = [(n, rr(f)) for n, f in (("Current game", "results_rr84_basetp.json"), ("Package v1", "results_rr84_tm1tp.json"),
                                 ("Package v2", "results_rr84_tm2tp.json"), ("Package v3", "results_rr84_tm3tp.json"))]
RRS = [(n, x) for n, x in RRS if x]
if RRS:
    P("## Round-robin of the 84 comps with no Element twice (Variant A, lowest-HP, team play)\n")
    P("| Measure | " + " | ".join(n for n, _ in RRS) + " |"); P("|---|" + "---|" * len(RRS))
    for label, f in (("Mean round to a wipe (s)", lambda x: f"{x[3]:.1f}"),
                     ("Best comp's win %", lambda x: f"{100 * max(x[0].values()):.0f} ({max(x[0], key=x[0].get)})"),
                     ("Worst comp's win %", lambda x: f"{100 * min(x[0].values()):.0f} ({min(x[0], key=x[0].get)})"),
                     ("Spread of comp win % (standard deviation)", lambda x: f"{100 * stt.pstdev(x[0].values()):.0f} points"),
                     ("Comps between 35% and 65%", lambda x: f"{sum(1 for v in x[0].values() if 0.35 <= v <= 0.65)} of 84"),
                     ("Spread of Element win % (best − worst)", lambda x: f"{100 * (max(x[1].values()) - min(x[1].values())):.0f} points")):
        P(f"| {label} | " + " | ".join(f(x) for _, x in RRS) + " |")
    P("")
    P("| Element (mean win % of the 28 comps it is in) | " + " | ".join(n for n, _ in RRS) + " |"); P("|---|" + "---|" * len(RRS))
    for e in sorted(MONO, key=lambda e: -RRS[-1][1][1][e]):
        P(f"| {e} | " + " | ".join(f"{100 * x[1][e]:.0f}" for _, x in RRS) + " |")
    P("")
    P("| Comp structure (mean win %) | " + " | ".join(n for n, _ in RRS) + " |"); P("|---|" + "---|" * len(RRS))
    for g in RRS[0][1][2]:
        P(f"| {g} ({len(RRS[0][1][2][g])} comps) | " + " | ".join(f"{100 * mean(x[2][g]):.0f}" for _, x in RRS) + " |")
    P("")
    for name, x in RRS:
        top = sorted(x[0].items(), key=lambda kv: -kv[1])
        P(f"**{name}, top 6:** " + ", ".join(f"{c.replace('+', ' + ')} {100 * v:.0f}" for c, v in top[:6]))
        P(f"**{name}, bottom 6:** " + ", ".join(f"{c.replace('+', ' + ')} {100 * v:.0f}" for c, v in top[-6:]))
        P("")
open(os.path.join(HERE, "tm_compare.md"), "w", encoding="utf-8").write("\n".join(out))
print("\n".join(out))
