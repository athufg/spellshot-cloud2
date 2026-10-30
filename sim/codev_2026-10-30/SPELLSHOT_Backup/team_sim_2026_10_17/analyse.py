"""Builds the report tables from results_main.json (and results_cover / results_swaps* when present).
python analyse.py P   -> tables_P.md, matchups_P.csv, headline_P.json   (same for L)"""
import json, os, sys, csv, math

HERE = os.path.dirname(os.path.abspath(__file__))
DS = sys.argv[1] if len(sys.argv) > 1 else "P"
R = json.load(open(os.path.join(HERE, "results_main.json")))["jobs"]
MONO = ["Aqua", "Cryo", "Pyro", "Radiant", "Terra", "Toxin", "Umbra", "Voltaic", "Zephyr"]
STRAT, WEAK = ["S1", "S2", "S3", "S4", "S5"], ["W1", "W2"]
COMP = {"S1": ["Terra", "Radiant", "Pyro"], "S2": ["Terra", "Radiant", "Voltaic"], "S3": ["Terra", "Cryo", "Pyro"],
        "S4": ["Radiant", "Umbra", "Pyro"], "S5": ["Cryo", "Aqua", "Terra"], "W1": ["Aqua", "Toxin", "Zephyr"],
        "W2": ["Pyro", "Pyro", "Voltaic"]}
CFGS = [("1", "A"), ("1", "B"), ("2", "A"), ("2", "B")]
POLS = ("low", "soft")
NAME = {"1": "Pass 1", "2": "Pass 2", "A": "Variant A (no jump)", "B": "Variant B (jump + double jump)"}
out = []
H = {}


def o_(hp, var, pol, a, b, ds=DS): return R[f"{ds}|{hp}|{var}|{pol}|{a}|{b}"]


def win(o): return o["win"] / o["n"]


def wipe(o): return o["wipe_dur"] / o["wipe_n"] if o["wipe_n"] else float("nan")


def wr(hp, var, pol, a, b):
    """Win rate of a against b, whichever order the matchup was run in."""
    k = f"{DS}|{hp}|{var}|{pol}|{a}|{b}"
    if k in R: return win(R[k])
    return 1 - win(R[f"{DS}|{hp}|{var}|{pol}|{b}|{a}"])


def pc(x): return f"{100 * x:.0f}"


def mean(xs): xs = list(xs); return sum(xs) / len(xs) if xs else float("nan")


def P(s=""): out.append(s)


def sides_of(name):
    """Every (job, side letter) where comp `name` fought, for one dataset."""
    for k, o in R.items():
        ds, hp, var, pol, a, b = k.split("|")
        if ds != DS: continue
        if a == name: yield (hp, var, pol, a, b), o, "A"
        if b == name: yield (hp, var, pol, a, b), o, "B"


# ---------------------------------------------------------------- 3. matchup results per configuration
for hp, var in CFGS:
    P(f"### {NAME[hp]} / {NAME[var]}"); P()
    P("**Mono vs strategy** (mono win %, lowest-HP focus / softest-role focus; 200 rounds each)"); P()
    P("| Mono | " + " | ".join(f"vs {s}" for s in STRAT) + " | Mono mean |"); P("|---|" + "---|" * 6)
    for m in MONO:
        cells = [f"{pc(wr(hp, var, 'low', m, s))} / {pc(wr(hp, var, 'soft', m, s))}" for s in STRAT]
        ml = mean(wr(hp, var, 'low', m, s) for s in STRAT); ms = mean(wr(hp, var, 'soft', m, s) for s in STRAT)
        P(f"| {m} | " + " | ".join(cells) + f" | {pc(ml)} / {pc(ms)} |")
    sl = [mean(1 - wr(hp, var, 'low', m, s) for m in MONO) for s in STRAT]
    ss = [mean(1 - wr(hp, var, 'soft', m, s) for m in MONO) for s in STRAT]
    P("| **Strategy comp's mean win %** | " + " | ".join(f"**{pc(a)} / {pc(b)}**" for a, b in zip(sl, ss)) +
      f" | **{pc(mean(sl))} / {pc(mean(ss))}** |")
    P()
    cnt = {pol: sum(1 for m in MONO for s in STRAT if 1 - wr(hp, var, pol, m, s) >= 0.6) for pol in POLS}
    cntm = {pol: sum(1 for m in MONO for s in STRAT if wr(hp, var, pol, m, s) >= 0.5) for pol in POLS}
    P(f"Strategy comp wins 60% or more in **{cnt['low']} / 45** (lowest-HP) and **{cnt['soft']} / 45** (softest-role) "
      f"matchups; the mono wins half or more in {cntm['low']} and {cntm['soft']}.")
    H[f"{hp}{var}"] = {"strat_mean": {"low": mean(sl), "soft": mean(ss)}, "strat60": cnt, "mono50": cntm,
                      "per_strat": {s: (a, b) for s, a, b in zip(STRAT, sl, ss)},
                      "per_mono": {m: (mean(wr(hp, var, 'low', m, s) for s in STRAT), mean(wr(hp, var, 'soft', m, s) for s in STRAT)) for m in MONO}}
    P()
    P("Time to team wipe (s, both policies pooled; the lowest-HP / softest-role split is in the CSV):"); P()
    P("| Mono | " + " | ".join(f"vs {s}" for s in STRAT) + " |"); P("|---|" + "---|" * 5)
    for m in MONO:
        P(f"| {m} | " + " | ".join(f"{mean(wipe(o_(hp, var, pol, m, s)) for pol in POLS):.1f}" for s in STRAT) + " |")
    P()
    # mono vs mono ranking
    P("**Mono vs mono ranking** (mean win % against the other eight monos)"); P()
    P("| Rank | Mono | Lowest-HP | Softest-role | Best against | Worst against | Mean wipe (s) |"); P("|---|---|---|---|---|---|---|")
    rows = []
    for m in MONO:
        ot = [x for x in MONO if x != m]
        l = mean(wr(hp, var, 'low', m, x) for x in ot); s_ = mean(wr(hp, var, 'soft', m, x) for x in ot)
        both = {x: (wr(hp, var, 'low', m, x) + wr(hp, var, 'soft', m, x)) / 2 for x in ot}
        b = max(both, key=both.get); w_ = min(both, key=both.get)
        wt = []
        for x in ot:
            for pol in POLS:
                k = f"{DS}|{hp}|{var}|{pol}|{m}|{x}"
                wt.append(wipe(R[k] if k in R else R[f"{DS}|{hp}|{var}|{pol}|{x}|{m}"]))
        rows.append((l + s_, m, l, s_, f"{b} ({pc(both[b])})", f"{w_} ({pc(both[w_])})", mean(wt)))
    for i, r in enumerate(sorted(rows, reverse=True)):
        P(f"| {i + 1} | {r[1]} | {pc(r[2])} | {pc(r[3])} | {r[4]} | {r[5]} | {r[6]:.1f} |")
    H[f"{hp}{var}"]["mono_rank"] = [(r[1], (r[2] + r[3]) / 2) for r in sorted(rows, reverse=True)]
    P()
    # strategy vs strategy
    P("**Strategy vs strategy** (first-named win %, lowest-HP / softest-role; wipe time pooled)"); P()
    P("| Matchup | Win % | Wipe (s) |"); P("|---|---|---|")
    for i, a in enumerate(STRAT):
        for b in STRAT[i + 1:]:
            P(f"| {a} vs {b} | {pc(wr(hp, var, 'low', a, b))} / {pc(wr(hp, var, 'soft', a, b))} | "
              f"{mean(wipe(o_(hp, var, pol, a, b)) for pol in POLS):.1f} |")
    P()
    rk = sorted(((mean(wr(hp, var, pol, a, b) for pol in POLS for b in STRAT if b != a), a) for a in STRAT), reverse=True)
    P("Ranking (mean of both policies vs the other four): " + ", ".join(f"{a} {pc(v)}" for v, a in rk))
    H[f"{hp}{var}"]["strat_rank"] = [(a, v) for v, a in rk]
    P()
    P("**Weak comps** (weak comp's win %, lowest-HP / softest-role; wipe time pooled)"); P()
    P("| Weak comp | " + " | ".join(f"vs {x}" for x in STRAT + ["Pyro", "Aqua"]) + " |"); P("|---|" + "---|" * 7)
    for wk in WEAK:
        P(f"| {wk} | " + " | ".join(f"{pc(wr(hp, var, 'low', wk, x))} / {pc(wr(hp, var, 'soft', wk, x))} ({mean(wipe(o_(hp, var, pol, wk, x)) for pol in POLS):.0f} s)"
                                   for x in STRAT + ["Pyro", "Aqua"]) + " |")
    H[f"{hp}{var}"]["weak"] = {wk: mean(wr(hp, var, pol, wk, x) for pol in POLS for x in STRAT) for wk in WEAK}
    P()
    tos = [o["timeout"] / o["n"] for k, o in R.items() if k.startswith(f"{DS}|{hp}|{var}|")]
    allw = [wipe(o) for k, o in R.items() if k.startswith(f"{DS}|{hp}|{var}|")]
    H[f"{hp}{var}"]["timeout"] = mean(tos); H[f"{hp}{var}"]["wipe"] = mean(allw)
    P(f"All 105 matchups: mean time to wipe {mean(allw):.1f} s; rounds that ran to the 90 s clock: {100 * mean(tos):.1f}%.")
    P()

# ---------------------------------------------------------------- 4/5. pass and variant comparisons
P("### Pass and variant comparison"); P()
P("| Config | Policy | Strategy mean win vs monos | Strategy ≥60% (of 45) | Mono ≥50% (of 45) | Mean wipe (s) | Clock-outs |")
P("|---|---|---|---|---|---|---|")
for hp, var in CFGS:
    h = H[f"{hp}{var}"]
    for pol in POLS:
        P(f"| P{hp}/{var} | {pol} | {pc(h['strat_mean'][pol])}% | {h['strat60'][pol]} | {h['mono50'][pol]} | {h['wipe']:.1f} | {100 * h['timeout']:.1f}% |")
P()
P("Per strategy comp, mean win % vs the nine monos (both policies pooled):"); P()
P("| Comp | P1/A | P1/B | P2/A | P2/B |"); P("|---|---|---|---|---|")
for s in STRAT:
    P(f"| {s} | " + " | ".join(pc(mean(H[f'{hp}{var}']['per_strat'][s])) for hp, var in CFGS) + " |")
P()
P("Per mono, mean win % vs the five strategy comps (both policies pooled):"); P()
P("| Mono | P1/A | P1/B | P2/A | P2/B |"); P("|---|---|---|---|---|")
for m in MONO:
    P(f"| {m} | " + " | ".join(pc(mean(H[f'{hp}{var}']['per_mono'][m])) for hp, var in CFGS) + " |")
P()

# deaths / survival by Element, per configuration (who dies, how late)
P("Deaths per round and mean time of death, by Element (all comps, both policies):"); P()
P("| Element | " + " | ".join(f"P{hp}/{var} dies % · at s" for hp, var in CFGS) + " |"); P("|---|" + "---|" * 4)
for el in MONO:
    cells = []
    for hp, var in CFGS:
        dn = dt = ap = 0.0
        for k, o in R.items():
            ds, h_, v_, pol, a, b = k.split("|")
            if ds != DS or h_ != hp or v_ != var: continue
            for side, name in (("A", a), ("B", b)):
                comp = COMP.get(name, [name] * 3)
                c = comp.count(el)
                if not c: continue
                ap += c * o["n"]
                dn += o["st"].get("deaths", {}).get(f"{side}|{el}", 0); dt += o["st"].get("death_t", {}).get(f"{side}|{el}", 0)
        cells.append(f"{pc(dn / ap)} · {dt / max(dn, 1):.1f}" if ap else "—")
    P(f"| {el} | " + " | ".join(cells) + " |")
P()

# first death role under the two policies, when the target comp has a support
P("Who dies first when the enemy comp has a Controller/Support pick (Radiant or Cryo):"); P()
P("| Config | Lowest-HP: support first | Softest-role: support first |"); P("|---|---|---|")
for hp, var in CFGS:
    cells = []
    for pol in POLS:
        n = f = 0
        for k, o in R.items():
            ds, h_, v_, p_, a, b = k.split("|")
            if ds != DS or h_ != hp or v_ != var or p_ != pol: continue
            for side, name, other in (("A", a, b), ("B", b, a)):
                comp = COMP.get(name, [name] * 3)
                if any(x in ("Radiant", "Cryo") for x in comp) and not all(x in ("Radiant", "Cryo") for x in comp):
                    tot = sum(v for kk, v in o["fd"].items() if kk.startswith(side + "|") and "|el|" not in kk)
                    n += tot; f += o["fd"].get(f"{side}|support", 0)
        cells.append(pc(f / n) + "%" if n else "—")
    P(f"| P{hp}/{var} | {cells[0]} | {cells[1]} |")
P()

# ---------------------------------------------------------------- 6. mana and spam (P1/A, both policies, all comps)
def pool(cfg_prefix):
    agg = {}
    for k, o in R.items():
        if not k.startswith(cfg_prefix): continue
        for cat in ("dmg", "mana", "casts", "lasthit", "ks_sum", "ks_n", "full", "dry", "alive", "kills", "heal"):
            for kk, v in o["st"].get(cat, {}).items():
                key = kk[2:]
                agg.setdefault(cat, {})[key] = agg.get(cat, {}).get(key, 0.0) + v
    return agg


for hp, var in (("1", "A"), ("2", "A"), ("1", "B")):
    A = pool(f"{DS}|{hp}|{var}|")
    if hp == "1" and var == "A": A1 = A
    H[f"mana{hp}{var}"] = {el: (A["full"].get(el, 0) / A["alive"][el], A["dry"].get(el, 0) / A["alive"][el]) for el in MONO}
P("### Mana by Element (share of alive time at full mana / under 10 mana)"); P()
P("| Element | P1/A full | P1/A dry | P2/A full | P2/A dry | P1/B full | P1/B dry |"); P("|---|---|---|---|---|---|---|")
for el in MONO:
    P(f"| {el} | " + " | ".join(f"{pc(H[f'mana{c}'][el][0])}% | {pc(H[f'mana{c}'][el][1])}%" for c in ("1A", "2A", "1B")) + " |")
P()
CD = {"IM": 12, "DT": 14, "LS": None, "FF": 14, "BZ": 18, "DF": 16, "UT": 9, "TT": 16, "SA": None, "BL": 12, "PT": 14,
      "BN": 17, "BC": 9, "AS": 12, "BW": None, "CC": 9, "AV": 16, "AR": 14, "SS": 10, "MK": 14, "DD": 20, "OC": 9,
      "RS": 10, "VO": 12, "CS": 10, "SK": 12, "GP": 14}
P("### Ability economy in team play (P1/A, both policies, every comp)"); P()
P("| Element | Ability | Damage per mana | Casts/min per player | Cooldown cap /min | Share of Element's damage | Share of Element's kills | Killer's own share of a kill |")
P("|---|---|---|---|---|---|---|---|")
rows = []
for el in MONO:
    dm = {k.split("|")[1]: v for k, v in A1["dmg"].items() if k.split("|")[0] == el}
    lh = {k.split("|")[1]: v for k, v in A1["lasthit"].items() if k.split("|")[0] == el}
    mn = {k.split("|")[1]: v for k, v in A1["mana"].items() if k.split("|")[0] == el}
    cs = {k.split("|")[1]: v for k, v in A1["casts"].items() if k.split("|")[0] == el}
    ks = {k.split("|")[1]: v for k, v in A1["ks_sum"].items() if k.split("|")[0] == el}
    kn = {k.split("|")[1]: v for k, v in A1["ks_n"].items() if k.split("|")[0] == el}
    alive = A1["alive"][el]
    td, tl = sum(dm.values()) or 1, sum(lh.values()) or 1
    for ab in sorted(set(dm) | set(cs), key=lambda x: -dm.get(x, 0)):
        if ab in ("SA_b", "SKg"): continue
        dpm = dm.get(ab, 0) / mn[ab] if mn.get(ab) else float("nan")
        cpm = cs.get(ab, 0) / alive * 60 if ab in CD or ab in ("Maw", "Cage", "RoF", "Halo", "Tomb", "PZ", "Eclipse", "Cascade", "Cyclone") else float("nan")
        cap = (60 / CD[ab]) if CD.get(ab) else float("nan")
        kshare = ks.get(ab, 0) / kn[ab] if kn.get(ab) else float("nan")
        rows.append((el, ab, dpm, cpm, cap, dm.get(ab, 0) / td, lh.get(ab, 0) / tl, kshare, kn.get(ab, 0)))
        f = lambda x, d=1: "—" if x != x else f"{x:.{d}f}"
        P(f"| {el} | {ab} | {f(dpm)} | {f(cpm)} | {f(cap)} | {pc(dm.get(ab, 0) / td)}% | {pc(lh.get(ab, 0) / tl)}% | "
          f"{'—' if kshare != kshare else pc(kshare) + '%'} |")
H["abil"] = rows
P()

P("### Damage per player per second alive, by Element (all comps, both policies)"); P()
P("| Element | P1/A | P1/B | P2/A | P2/B |"); P("|---|---|---|---|---|")
pools = {c: pool(f"{DS}|{c[0]}|{c[1]}|") for c in CFGS}
for el in MONO:
    P(f"| {el} | " + " | ".join(f"{sum(v for k, v in pools[c]['dmg'].items() if k.split('|')[0] == el) / pools[c]['alive'][el]:.1f}" for c in CFGS) + " |")
H["dps"] = {el: sum(v for k, v in pools[("1", "A")]["dmg"].items() if k.split("|")[0] == el) / pools[("1", "A")]["alive"][el] for el in MONO}
P()

# ---------------------------------------------------------------- 7. reactions per comp (as the attacker)
P("### Reactions per round, by the comp that sets them off"); P()
P("| Comp | P1/A reactions/round (types) | Reaction damage/round P1/A | P1/B | P2/A | P2/B |"); P("|---|---|---|---|---|---|")
H["rx"] = {}
for name in MONO + STRAT + WEAK:
    cells = []; types = {}
    for hp, var in CFGS:
        n = c = d = 0.0
        for (h_, v_, pol, a, b), o, side in sides_of(name):
            if h_ != hp or v_ != var: continue
            n += o["n"]
            for kk, v in o["st"].get("rx", {}).items():
                if kk.startswith(side + "|"):
                    c += v
                    if hp == "1" and var == "A": types[kk[2:]] = types.get(kk[2:], 0) + v
            for kk, v in o["st"].get("rxdmg", {}).items():
                if kk.startswith(side + "|"): d += v
        cells.append((c / n, d / n, n))
    nA = cells[0][2]
    tstr = ", ".join(f"{k} {v / nA:.1f}" for k, v in sorted(types.items(), key=lambda kv: -kv[1]) if v / nA >= 0.05) or "none"
    H["rx"][name] = {"P1A": cells[0][:2], "types": {k: v / nA for k, v in types.items()}}
    P(f"| {name} | {cells[0][0]:.1f} ({tstr}) | {cells[0][1]:.0f} | {cells[1][1]:.0f} | {cells[2][1]:.0f} | {cells[3][1]:.0f} |")
P()

# ---------------------------------------------------------------- 9. peel and protection per comp (P1/A)
P("### Peel and protection per round (P1/A, both policies): uses, and the share where that ally was alive 4 s later"); P()
P("| Comp | Peel uses per round (alive 4 s later) | Healing/round | Shield or wall absorbed/round |"); P("|---|---|---|---|")
H["peel"] = {}
for name in STRAT + ["Terra", "Radiant", "Cryo", "Aqua", "W1"]:
    n = 0; pe = {}; ok = {}; he = {}; ab = {}
    for (h_, v_, pol, a, b), o, side in sides_of(name):
        if h_ != "1" or v_ != "A": continue
        n += o["n"]
        for cat, dd in (("peel", pe), ("peel_ok", ok), ("heal", he), ("absorb", ab)):
            for kk, v in o["st"].get(cat, {}).items():
                if kk.startswith(side + "|"): dd[kk[2:]] = dd.get(kk[2:], 0) + v
    ps = ", ".join(f"{k.split('|')[1]} {v / n:.1f} ({pc(ok.get(k, 0) / v) + '%' if 'Icicle' not in k else 'not tracked'})" for k, v in sorted(pe.items(), key=lambda kv: -kv[1]) if v / n >= 0.05)
    hs = ", ".join(f"{k.split('|')[1]} {v / n:.0f}" if k.split('|')[1] != "Halo" else f"Halo on {k.split('|')[0]} {v / n:.0f}"
                   for k, v in sorted(he.items(), key=lambda kv: -kv[1]) if v / n >= 1)
    as_ = ", ".join(f"{k.split('|')[1]} {v / n:.0f}" for k, v in sorted(ab.items(), key=lambda kv: -kv[1]) if v / n >= 1)
    H["peel"][name] = {"peel": {k: (v / n, ok.get(k, 0) / v) for k, v in pe.items()}, "heal": {k: v / n for k, v in he.items()},
                       "absorb": {k: v / n for k, v in ab.items()}}
    P(f"| {name} | {ps or 'none'} | {hs or '0'} | {as_ or '0'} |")
P()

# ---------------------------------------------------------------- ultimate timing
P("### Ultimates (P1/A, both policies)"); P()
P("| Comp | Ults ready per round (of 3) | Mean ready time (s) | Rounds with 2+ ready within 3 s | All 3 within 6 s |"); P("|---|---|---|---|---|")
H["ult"] = {}
for name in MONO + STRAT + WEAK:
    n = r = tt = cl = n3 = 0
    for (h_, v_, pol, a, b), o, side in sides_of(name):
        if h_ != "1" or v_ != "A": continue
        n += o["n"]; r += o["ult"][side + "_ready"]; tt += o["ult"][side + "_t"]; cl += o["ult"][side + "_clust"]; n3 += o["ult"][side + "_n3"]
    H["ult"][name] = (r / n, tt / max(r, 1), cl / n, n3 / n)
    P(f"| {name} | {r / n:.2f} | {tt / max(r, 1):.1f} | {pc(cl / n)}% | {pc(n3 / n)}% |")
P()

open(os.path.join(HERE, f"tables_{DS}.md"), "w", encoding="utf-8").write("\n".join(out))
json.dump(H, open(os.path.join(HERE, f"headline_{DS}.json"), "w"), indent=1, default=str)
with open(os.path.join(HERE, f"matchups_{DS}.csv"), "w", newline="") as f:
    wtr = csv.writer(f)
    wtr.writerow(["dataset", "pass", "variant", "policy", "first", "second", "first_win", "draws", "mean_round_s",
                  "mean_wipe_s", "clock_outs", "rounds"])
    for k, o in sorted(R.items()):
        ds, hp, var, pol, a, b = k.split("|")
        if ds != DS: continue
        wtr.writerow([ds, hp, var, "lowest-HP" if pol == "low" else "softest-role", a, b, round(win(o), 3), o["draw"],
                      round(o["dur"] / o["n"], 2), round(wipe(o), 2), o["timeout"], o["n"]])
print("wrote", f"tables_{DS}.md", len(out), "lines")
