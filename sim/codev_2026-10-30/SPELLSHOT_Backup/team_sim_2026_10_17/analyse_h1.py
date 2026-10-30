"""Handoff (2026-10-18) runs: tank-role rule, Voltaic reach/damage, Umbra escape charge. Writes h1_compare.md.
Two spread metrics, never mixed: ELEMENT RANGE = best - worst Element win % (9 Elements; the Marvel Rivals hero-range
analogue) and COMP SD = standard deviation of the comps' win % (84 comps, or fewer under a role rule)."""
import json, os, pickle, statistics as stt
HERE = os.path.dirname(os.path.abspath(__file__))
MONO = ["Aqua", "Cryo", "Pyro", "Radiant", "Terra", "Toxin", "Umbra", "Voltaic", "Zephyr"]
ROLE = {"Pyro": "dps", "Toxin": "dps", "Aqua": "dps", "Radiant": "support", "Cryo": "support", "Umbra": "flank",
        "Voltaic": "flank", "Terra": "tank", "Zephyr": "disrupt"}
CACHE = os.path.join(HERE, "_h1_cache.pkl")
try: _C = pickle.load(open(CACHE, "rb"))
except Exception: _C = {}


def mean(x): x = list(x); return sum(x) / len(x) if x else float("nan")


def summarise(f):
    J = json.load(open(f)); R = J["jobs"]
    score, games = {}, {}
    per = {e: {"rounds": 0, "deaths": 0.0, "alive": 0.0, "dmg": 0.0, "casts": {}} for e in MONO}
    for k, o in R.items():
        _, var, a, b = k.split("|")
        w = o["win"] / o["n"]
        score[a] = score.get(a, 0) + w; games[a] = games.get(a, 0) + 1
        score[b] = score.get(b, 0) + 1 - w; games[b] = games.get(b, 0) + 1
        st = o["st"]
        for side, comp in (("A", a), ("B", b)):
            for e in comp.split("+"):
                d = per[e]; d["rounds"] += o["n"]
                d["deaths"] += st.get("deaths", {}).get(f"{side}|{e}", 0); d["alive"] += st.get("alive", {}).get(f"{side}|{e}", 0)
                d["dmg"] += sum(v for kk, v in st.get("dmg", {}).items() if kk.startswith(f"{side}|{e}|"))
                for kk, v in st.get("casts", {}).items():
                    if kk.startswith(f"{side}|{e}|"): ab = kk.split("|")[2]; d["casts"][ab] = d["casts"].get(ab, 0) + v
    wr = {c: score[c] / games[c] for c in score}
    el = {e: mean(v for c, v in wr.items() if e in c.split("+")) for e in MONO}
    return {"N": J["meta"]["N"], "wr": wr, "el": el, "ranked": sorted(wr.items(), key=lambda kv: -kv[1]),
            "sd": stt.pstdev(wr.values()), "per": per}


def summ(f):
    m = os.path.getmtime(f)
    if f not in _C or _C[f][0] != m: _C[f] = (m, summarise(f))
    return _C[f][1]


def rng(s, drop=()):
    v = [s["el"][e] for e in MONO if e not in drop and s["el"][e] == s["el"][e]]
    return 100 * (max(v) - min(v))


def fp(tag): return os.path.join(HERE, f"results_rr84_{tag}.json")


S = {}
for tag in ["q28_base", "q28_base_b", "h1_K", "h1_K_b", "h1_T1_v3", "h1_T1", "h1_TA1_v3", "h1_TA1", "h1_T1_bz32", "h1_TA1_bz32",
            "h1_cb55", "h1_cb65", "h1_dmg10", "h1_dmg12", "h1_cb55d10", "h1_dive", "h1_exit10", "h1_exit6", "h1_all", "h1_all_T1"]:
    if os.path.exists(fp(tag)): S[tag] = summ(fp(tag))
pickle.dump(_C, open(CACHE, "wb"))
out = []; P = out.append
NAMES = {"q28_base": "v3, live Cryo (P28/P29 baseline)", "q28_base_b": "  same, second seed set",
         "h1_K": "K = v3 + standing Twin Tide (a, 200, +3 s) + Flash Freeze 25 + Blizzard 20", "h1_K_b": "  K, second seed set",
         "h1_T1_v3": "Role rule T1 (exactly one Terra) on v3", "h1_T1": "Role rule T1 on K",
         "h1_TA1_v3": "Role rule TA1 (exactly one of Terra / Aqua) on v3", "h1_TA1": "Role rule TA1 on K",
         "h1_T1_bz32": "T1 on K, Blizzard 32 instead of 20", "h1_TA1_bz32": "TA1 on K, Blizzard 32 instead of 20",
         "h1_cb55": "K + Chain Bolt range 45 -> 55", "h1_cb65": "K + Chain Bolt range 65", "h1_dmg10": "K + Chain Bolt 8 -> 10 a bolt",
         "h1_dmg12": "K + Chain Bolt 12 a bolt", "h1_cb55d10": "K + Chain Bolt range 55 and 10 a bolt",
         "h1_dive": "K + Umbra dive play + half cooldown (P27's best; control)", "h1_exit10": "  + separate escape blink, 10 s cooldown",
         "h1_exit6": "  + separate escape blink, 6 s cooldown",
         "h1_all": "All together: K + Chain Bolt 55 / 10 + Umbra dive, half cooldown, escape blink 6 s",
         "h1_all_T1": "All together, under role rule T1"}
P("Two spread metrics, kept apart. **Element range** = best minus worst Element win % (the Marvel Rivals hero-range "
  "analogue: 12.5 points there). **Comp SD** = standard deviation of the comps' win % (84 comps, fewer under a role rule). "
  "Under rule T1 every comp has Terra, so Terra is 50% by construction and is left out of that run's range.")
P("")
P("| Run | Comps · rounds per pairing | Element range (all) | Element range without Terra | Comp SD | Pyro − Voltaic | Within-role ranges (dps: Pyro/Toxin/Aqua · support: Radiant/Cryo · flank: Umbra/Voltaic) |")
P("|---|---|---|---|---|---|---|")
for t, s in S.items():
    t1 = "T1" in t and "TA1" not in t
    roles = []
    for r in ("dps", "support", "flank"):
        v = [s["el"][e] for e in MONO if ROLE[e] == r]
        roles.append(f"{100 * (max(v) - min(v)):.1f}")
    P(f"| {NAMES[t]} | {len(s['wr'])} · {s['N']} | " + ("—" if t1 else f"{rng(s):.1f}") + f" | {rng(s, ('Terra',)):.1f} | "
      f"{100 * s['sd']:.1f} | {100 * (s['el']['Pyro'] - s['el']['Voltaic']):.1f} | " + " · ".join(roles) + " |")
P("")
P("## Element win % per run")
P("")
P("| Run | " + " | ".join(MONO) + " |")
P("|---|" + "---|" * len(MONO))
for t, s in S.items():
    P(f"| {NAMES[t]} | " + " | ".join(f"{100 * s['el'][e]:.1f}" for e in MONO) + " |")
P("")
P("## Changes against their control")
P("")
P("| Run | Control | Voltaic | Umbra | Pyro | Terra | Voltaic: dies % · damage/s alive | Umbra: dies % · Shadow Steps per round (out) |")
P("|---|---|---|---|---|---|---|---|")
CTL = {"h1_K": "q28_base", "h1_cb55": "h1_K", "h1_cb65": "h1_K", "h1_dmg10": "h1_K", "h1_dmg12": "h1_K", "h1_cb55d10": "h1_K",
       "h1_dive": "h1_K", "h1_exit10": "h1_dive", "h1_exit6": "h1_dive", "h1_all": "h1_K", "h1_K_b": "h1_K", "q28_base_b": "q28_base"}
for t, c in CTL.items():
    if t not in S or c not in S: continue
    s, b = S[t], S[c]
    d = lambda e: f"{100 * s['el'][e]:.1f} ({100 * (s['el'][e] - b['el'][e]):+.1f})"
    v, u = s["per"]["Voltaic"], s["per"]["Umbra"]
    P(f"| {NAMES[t].strip()} | {NAMES[c].split(' (')[0].split(' =')[0].strip()} | {d('Voltaic')} | {d('Umbra')} | {d('Pyro')} | {d('Terra')} | "
      f"{100 * v['deaths'] / v['rounds']:.0f}% · {v['dmg'] / max(1e-9, v['alive']):.1f} | "
      f"{100 * u['deaths'] / u['rounds']:.0f}% · {u['casts'].get('SS_out', 0) / u['rounds']:.2f} |")
P("")
for t, s in S.items():
    P(f"**{NAMES[t].strip()}** — bottom 6: " + ", ".join(f"{c.replace('+', ' + ')} {100 * v:.0f}" for c, v in s["ranked"][-6:]) +
      " | top 6: " + ", ".join(f"{c.replace('+', ' + ')} {100 * v:.0f}" for c, v in s["ranked"][:6]))
open(os.path.join(HERE, "h1_compare.md"), "w", encoding="utf-8").write("\n".join(out))
print("\n".join(out))
