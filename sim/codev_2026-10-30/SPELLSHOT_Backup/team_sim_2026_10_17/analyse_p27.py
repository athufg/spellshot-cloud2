"""P27 (Voltaic / Umbra self-sufficiency) round-robins vs plain v3. All: 84 comps, no jump, lowest-HP, teamwork on,
10 rounds per pairing. Writes p27_compare.md."""
import json, os, statistics as stt
HERE = os.path.dirname(os.path.abspath(__file__))
MONO = ["Aqua", "Cryo", "Pyro", "Radiant", "Terra", "Toxin", "Umbra", "Voltaic", "Zephyr"]
RUNS = [("v3 baseline", "results_rr84_q27_base6.json"), ("v3 baseline, second seed set (noise check)", "results_rr84_q27_base6b.json"),
        ("Voltaic: Static Discharge, reactive", "results_rr84_q27_vr.json"),
        ("Voltaic: Static Discharge, manual", "results_rr84_q27_vm.json"),
        ("Voltaic: manual, oversized (r10, push 16, 2x speed 1.5 s, 8 s)", "results_rr84_q27_vm_strong.json"),
        ("Umbra control: blink out under fire, no P27 mechanic", "results_rr84_q27_press.json"),
        ("Umbra: 0.3 s vanish", "results_rr84_q27_uv.json"),
        ("Umbra: 1.0 s vanish (oversized)", "results_rr84_q27_uv_strong.json"),
        ("Umbra: half cooldown after a hit", "results_rr84_q27_ud.json"),
        ("Umbra dive play, control", "results_rr84_q27_dive.json"),
        ("Umbra dive play + under-fire step-out, control", "results_rr84_q27_dive_press.json"),
        ("Umbra dive play + half cooldown", "results_rr84_q27_dive_ud.json"),
        ("Together: reactive Static Discharge + dive play + half cooldown", "results_rr84_q27_combo1.json"),
        ("Together: manual Static Discharge + dive play + half cooldown", "results_rr84_q27_combo2.json")]
CONTROL = {"Umbra: 0.3 s vanish": "Umbra control: blink out under fire, no P27 mechanic",
           "Umbra: 1.0 s vanish (oversized)": "Umbra control: blink out under fire, no P27 mechanic",
           "Umbra: half cooldown after a hit": "Umbra control: blink out under fire, no P27 mechanic",
           "Umbra dive play + under-fire step-out, control": "Umbra dive play, control",
           "Umbra dive play + half cooldown": "Umbra dive play + under-fire step-out, control",
           "Together: reactive Static Discharge + dive play + half cooldown": "Umbra dive play + under-fire step-out, control",
           "Together: manual Static Discharge + dive play + half cooldown": "Umbra dive play + under-fire step-out, control"}


def mean(x): x = list(x); return sum(x) / len(x) if x else float("nan")


def summarise(f):
    J = json.load(open(os.path.join(HERE, f))); R = J["jobs"]
    score, games = {}, {}
    per = {el: {"rounds": 0, "alive": 0.0, "deaths": 0.0, "dmg": 0.0} for el in MONO}
    sd = ss = ssin = 0.0; rounds = 0
    for k, o in R.items():
        _, var, a, b = k.split("|")
        w = o["win"] / o["n"]
        score[a] = score.get(a, 0) + w; games[a] = games.get(a, 0) + 1
        score[b] = score.get(b, 0) + 1 - w; games[b] = games.get(b, 0) + 1
        rounds += o["n"]
        for side, comp in (("A", a), ("B", b)):
            for el in comp.split("+"):
                d = per[el]; d["rounds"] += o["n"]
                d["alive"] += o["st"]["alive"].get(f"{side}|{el}", 0); d["deaths"] += o["st"].get("deaths", {}).get(f"{side}|{el}", 0)
                d["dmg"] += sum(v for kk, v in o["st"]["dmg"].items() if kk.startswith(f"{side}|{el}|"))
            sd += o["st"]["casts"].get(f"{side}|Voltaic|SD", 0); ss += o["st"]["casts"].get(f"{side}|Umbra|SS", 0)
            ssin += o["st"]["casts"].get(f"{side}|Umbra|SS_in", 0)
    wr = {c: score[c] / games[c] for c in score}
    el = {e: mean(v for c, v in wr.items() if e in c.split("+")) for e in MONO}
    ranked = sorted(wr.items(), key=lambda kv: -kv[1])
    def count(lst, e): return sum(1 for c, _ in lst if e in c.split("+"))
    return {"N": J["meta"]["N"], "wr": wr, "el": el, "ranked": ranked, "sd": stt.pstdev(wr.values()), "spread": max(el.values()) - min(el.values()),
            "bot6": {e: count(ranked[-6:], e) for e in ("Voltaic", "Umbra")}, "top6": {e: count(ranked[:6], e) for e in ("Voltaic", "Umbra")},
            "bot10": {e: count(ranked[-10:], e) for e in ("Voltaic", "Umbra")}, "top10": {e: count(ranked[:10], e) for e in ("Voltaic", "Umbra")},
            "per": per, "sd_casts": sd / max(1, per["Voltaic"]["rounds"]), "ss_casts": ss / max(1, per["Umbra"]["rounds"]),
            "ssin": ssin / max(1, per["Umbra"]["rounds"])}


rows = [(n, summarise(f)) for n, f in RUNS if os.path.exists(os.path.join(HERE, f))]
S = dict(rows)
base = rows[0][1]
assert len({s["N"] for _, s in rows}) == 1, "mixed rounds per pairing: " + str({n: s["N"] for n, s in rows})
out = []
P = out.append
nb = S.get("v3 baseline, second seed set (noise check)")
if nb:
    P(f"Noise check: the same v3 run on a second set of seeds moves Voltaic by {100 * (nb['el']['Voltaic'] - base['el']['Voltaic']):+.1f}, "
      f"Umbra by {100 * (nb['el']['Umbra'] - base['el']['Umbra']):+.1f}, and every Element by at most "
      f"{max(abs(100 * (nb['el'][e] - base['el'][e])) for e in MONO):.1f} points. Changes smaller than that are noise. "
      f"Single comps move more: the run-to-run difference per comp has an SD of {100 * stt.pstdev(nb['wr'][c] - base['wr'][c] for c in base['wr']):.1f} points "
      f"(largest {100 * max(abs(nb['wr'][c] - base['wr'][c]) for c in base['wr']):.1f}), so a one-comp change in the bottom-6 or top-6 counts can be noise.")
    P("")
P(f"All runs: {rows[0][1]['N']} rounds per pairing, 3,486 pairings, no jump, lowest-HP focus, teamwork on, package v3.")
P("")
P("| Run | Voltaic comps (vs baseline) | Umbra comps (vs its control) | Voltaic in bottom 6 / top 6 | Umbra in bottom 6 / top 6 | Bottom 10 / top 10 (V, U) | Comp spread (SD) | Best − worst Element |")
P("|---|---|---|---|---|---|---|---|")
for n, s in rows:
    ctl = S.get(CONTROL.get(n, ""), base)
    dv = 100 * (s["el"]["Voltaic"] - base["el"]["Voltaic"]); du = 100 * (s["el"]["Umbra"] - ctl["el"]["Umbra"])
    P(f"| {n} | {100 * s['el']['Voltaic']:.1f}%" + (f" ({dv:+.1f})" if s is not base else "") + f" | {100 * s['el']['Umbra']:.1f}%" +
      (f" ({du:+.1f})" if s is not base else "") +
      f" | {s['bot6']['Voltaic']} / {s['top6']['Voltaic']} | {s['bot6']['Umbra']} / {s['top6']['Umbra']} | "
      f"V {s['bot10']['Voltaic']}/{s['top10']['Voltaic']}, U {s['bot10']['Umbra']}/{s['top10']['Umbra']} | {100 * s['sd']:.1f} | {100 * s['spread']:.0f} |")
P("")
P("| Run | Voltaic dies % · damage/s alive · Static Discharges per round | Umbra dies % · damage/s alive · Shadow Steps per round (of which dive-ins) |")
P("|---|---|---|")
for n, s in rows:
    v, u = s["per"]["Voltaic"], s["per"]["Umbra"]
    P(f"| {n} | {100 * v['deaths'] / v['rounds']:.0f}% · {v['dmg'] / v['alive']:.1f} · {s['sd_casts']:.2f} | "
      f"{100 * u['deaths'] / u['rounds']:.0f}% · {u['dmg'] / u['alive']:.1f} · {s['ss_casts']:.2f} ({s['ssin']:.2f}) |")
P("")
P("Element win % per run: " + " ; ".join(f"{n}: " + ", ".join(f"{e[:3]} {100 * s['el'][e]:.1f}" for e in MONO) for n, s in rows))
P("")
for n, s in rows:
    P(f"**{n}** — bottom 6: " + ", ".join(f"{c.replace('+', ' + ')} {100 * v:.0f}" for c, v in s["ranked"][-6:]) +
      " | top 6: " + ", ".join(f"{c.replace('+', ' + ')} {100 * v:.0f}" for c, v in s["ranked"][:6]))
open(os.path.join(HERE, "p27_compare.md"), "w", encoding="utf-8").write("\n".join(out))
print("\n".join(out))
