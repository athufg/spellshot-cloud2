"""Step 8: which single Technique swap gives each mono-comp a reaction it cannot reach with its default loadout, how
the best of those does against the best strategy comp, and (for the four with no single swap) a two-swap ceiling.
python analyse_swaps.py <best> [confirm]  -> prints the table; with 'confirm' it reads results_swapconfirm_<best>.json"""
import json, os, sys
import team_sim as T

HERE = os.path.dirname(os.path.abspath(__file__))
best = sys.argv[1]
SRC = {"burn": {"Pyro"}, "chill": {"Cryo"}, "root": {"Cryo"}, "poison": {"Toxin"}, "charged": {"Voltaic"}}
TECH_STATUS = {"LS": "burn", "DF": "root"}
HITTECH = {"LS", "DT", "DF", "RS", "VO", "AR", "TT", "SA", "GP", "SK", "AS"}   # Techniques that land a damaging hit           # the only Techniques that put a reactable status on an enemy


def reactions(el, tech):
    """Reactions a team of three `el` with this loadout can set off on its own. No Element reacts to a status it applies
    itself, so a reaction exists whenever some hit Element has a rule for some status the team can apply."""
    statuses = {s for s, els in SRC.items() if el in els}
    for k in tech:
        if k in TECH_STATUS: statuses.add(TECH_STATUS[k])
    hits = {el} | {T.HOME[k] for k in tech if k in HITTECH}
    return {rx for h in hits for s, rx in T.RULES.get(h, ()) if s in statuses}


def load(tag):
    p = os.path.join(HERE, f"results_{tag}.json")
    return json.load(open(p))["jobs"] if os.path.exists(p) else {}


R = load(f"swaps_{best}")
R2 = load(f"swaps2_{best}")
C = load(f"swapconfirm_{best}")


def wr(Rx, el, tech, suffix=""):
    ks = [f"P|1|A|{pol}|{el}|{best}|{'+'.join(tech)}{suffix}" for pol in ("low", "soft")]
    os_ = [Rx[k] for k in ks if k in Rx]
    if len(os_) < 2: return None
    rx = sum(v for o in os_ for kk, v in o["st"].get("rx", {}).items() if kk.startswith("A|")) / sum(o["n"] for o in os_)
    return sum(o["win"] for o in os_) / sum(o["n"] for o in os_), rx, [o["win"] / o["n"] for o in os_]


rows = []
for el in T.ELS:
    base = T.TECH[el]
    b = wr(R, el, base)
    have = reactions(el, base)
    cands = []
    for k in sorted(set(T.HOME) - set(base)):
        for slot in (0, 1):
            tech = list(base); tech[slot] = k; tech = tuple(tech)
            new = reactions(el, tech) - have
            r = wr(R, el, tech)
            if r is None: continue
            cands.append((r[0], tech, new, r))
    react_c = [c for c in cands if c[2]]
    top_react = max(react_c, key=lambda c: c[0]) if react_c else None
    top_any = max(cands, key=lambda c: c[0]) if cands else None
    rows.append((el, b, have, top_react, top_any))

if not C:
    json.dump({el: list(tr[1]) for el, b, have, tr, ta in rows if tr}, open(os.path.join(HERE, f"swap_picks_{best}.json"), "w"))
print(f"Best strategy comp: {best}" + ("  (default and chosen swap re-run on fresh seeds)" if C else "") + "\n")
print("| Mono | Default win % vs best (L/S) | Best reaction-enabling swap | New reactions | Win % (L/S) | Reactions/round | Best swap of any kind |")
print("|---|---|---|---|---|---|---|")
for el, b, have, tr, ta in rows:
    bc = wr(C, el, T.TECH[el], "|confirm") if C else None
    b = bc or b
    bs = f"{100 * b[0]:.0f} ({100 * b[2][0]:.0f}/{100 * b[2][1]:.0f})" if b else "—"
    if tr:
        conf = wr(C, el, tr[1], "|confirm") if C else None
        r = conf or tr[3]
        out = (" + ".join(tr[1]), ", ".join(sorted(tr[2])), f"{100 * r[0]:.0f} ({100 * r[2][0]:.0f}/{100 * r[2][1]:.0f})", f"{r[1]:.1f}")
    else:
        out = ("none available", "—", "—", "—")
    ta_s = f"{' + '.join(ta[1])} {100 * ta[0]:.0f}" if ta else "—"
    print(f"| {el} | {bs} | {out[0]} | {out[1]} | {out[2]} | {out[3]} | {ta_s} |")

if R2:
    print("\nTwo-swap ceiling for the Elements with no single swap (both Technique slots replaced):\n")
    print("| Mono | Loadout | Reactions | Win % vs best (L/S) | Reactions/round |"); print("|---|---|---|---|---|")
    for el in ("Aqua", "Terra", "Radiant", "Umbra"):
        best_row = None
        for k in R2:
            parts = k.split("|")
            if parts[4] != el or parts[3] != "low": continue
            tech = tuple(parts[6].split("+"))
            r = wr(R2, el, tech)
            if r and (best_row is None or r[0] > best_row[0]): best_row = (r[0], tech, r)
        d = wr(R2, el, T.TECH[el])
        if best_row:
            r = best_row[2]
            print(f"| {el} | default | — | {100 * d[0]:.0f} | {d[1]:.1f} |")
            print(f"| {el} | {' + '.join(best_row[1])} | {', '.join(sorted(reactions(el, best_row[1])))} | "
                  f"{100 * r[0]:.0f} ({100 * r[2][0]:.0f}/{100 * r[2][1]:.0f}) | {r[1]:.1f} |")
json.dump([(el, b, sorted(have), (tr[1], sorted(tr[2]), tr[3]) if tr else None, (ta[1], ta[0]) if ta else None)
           for el, b, have, tr, ta in rows], open(os.path.join(HERE, f"swaps_summary_{best}.json"), "w"), default=str)
