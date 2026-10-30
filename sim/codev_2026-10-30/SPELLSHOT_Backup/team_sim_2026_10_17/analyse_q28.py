"""P28 (Twin Tide cover) and P29 (cursor-targeting) round-robins against the live-Cryo v3 baseline. Writes q28_compare.md.
All runs: 84 comps, 3,486 pairings, no jump, lowest-HP focus, teamwork on, package v3 + SIM_CRYO_LIVE, N per pairing."""
import json, os, statistics as stt
HERE = os.path.dirname(os.path.abspath(__file__))
MONO = ["Aqua", "Cryo", "Pyro", "Radiant", "Terra", "Toxin", "Umbra", "Voltaic", "Zephyr"]
# (label, tag, rule-only control for the blocking effect)
P28 = [("v3, live Cryo (baseline)", "base", None), ("baseline, second seed set (noise)", "base_b", None),
       ("control: cover rule on, no blocking (for a, b)", "tt_rule", None),
       ("control: cover rule for allies only, no blocking (for c)", "tt_rule_c", None),
       ("(a) one wall, 150", "tt_a150", "tt_rule"), ("(a) one wall, 200", "tt_a200", "tt_rule"),
       ("(a) one wall, 250", "tt_a250", "tt_rule"),
       ("(b) twin walls, 100 + 100", "tt_b100", "tt_rule"), ("(b) twin walls, 125 + 125", "tt_b125", "tt_rule"),
       ("(c) allies only, 150", "tt_c150", "tt_rule_c"), ("(c) allies only, 200", "tt_c200", "tt_rule_c"),
       ("(c) allies only, 250", "tt_c250", "tt_rule_c"),
       ("added: (a) 150, met walls stand 3 s (up ~3.9 s)", "tt_a150_h3", "tt_rule"),
       ("added: (a) 200, stand 3 s", "tt_a200_h3", "tt_rule"), ("added: (a) 250, stand 3 s", "tt_a250_h3", "tt_rule"),
       ("added: (b) 100 + 100, stand 3 s", "tt_b100_h3", "tt_rule"),
       ("added: (c) 200, stand 3 s", "tt_c200_h3", "tt_rule_c"),
       ("added: (a) 200, stand 6 s (up ~6.9 s)", "tt_a200_h6", "tt_rule"),
       ("added: together, (a) 200 stand 3 s + Flash Freeze 25 + Blizzard 32", "combo", None)]
P29 = [("Flash Freeze at the cursor, range 15", "ff15", "Cryo", "FF"), ("Flash Freeze, range 20", "ff20", "Cryo", "FF"),
       ("Flash Freeze, range 25", "ff25", "Cryo", "FF"),
       ("(b) Flash Freeze 20, radius 20 -> 14", "ff20_r14", "Cryo", "FF"),
       ("(b) Flash Freeze 20, wind-up 0.38 -> 0.78 s", "ff20_wind", "Cryo", "FF"),
       ("(b) Flash Freeze 20, freeze 4 -> 2.5 s", "ff20_frz25", "Cryo", "FF"),
       ("Blizzard at the cursor, range 20", "bz20", "Cryo", "BZ"), ("Blizzard, range 32", "bz32", "Cryo", "BZ"),
       ("Blizzard, range 45", "bz45", "Cryo", "BZ"), ("(b) Blizzard 32, radius 32 -> 24", "bz32_r24", "Cryo", "BZ"),
       ("(b) Blizzard 32, 4 s (sim: 6.6 -> 4.6 s)", "bz32_dur4", "Cryo", "BZ"),
       ("Deep Freeze at the cursor, range 10", "df10", "Cryo", "DF"), ("Deep Freeze, range 20", "df20", "Cryo", "DF"),
       ("Deep Freeze, range 30", "df30", "Cryo", "DF"),
       ("All three Cryo (FF 20, BZ 32, DF 20)", "cryo_all", "Cryo", "FF"),
       ("Aftershock at the cursor, range 15", "as15", "Terra", "AS"), ("Aftershock, range 24", "as24", "Terra", "AS"),
       ("Aftershock, range 35", "as35", "Terra", "AS"),
       ("Benediction at the cursor, range 20", "bn20", "Radiant", "BN"), ("Benediction, range 35", "bn35", "Radiant", "BN"),
       ("Benediction, range 50", "bn50", "Radiant", "BN"),
       ("added: together, Twin Tide (a) 200 stand 3 s + Flash Freeze 25 + Blizzard 32", "combo", "Cryo", "FF")]
EXACT = [("robustness baseline", "ex_base"), ("robustness: Flash Freeze, range 20", "ex_ff20"),
         ("robustness: Flash Freeze, range 25", "ex_ff25"), ("robustness: Blizzard, range 32", "ex_bz32")]


def fpath(tag, mode="rr84"): return os.path.join(HERE, f"results_{mode}_q28_{tag}.json")


def mean(x): x = list(x); return sum(x) / len(x) if x else float("nan")


def summarise(f):
    J = json.load(open(f)); R = J["jobs"]
    score, games = {}, {}
    per = {el: {"rounds": 0, "deaths": 0.0, "cn": 0.0, "clost": 0.0, "cwon": 0.0, "casts": {}, "absorb": 0.0, "dmg": {}}
           for el in MONO}
    for k, o in R.items():
        _, var, a, b = k.split("|")
        w = o["win"] / o["n"]
        score[a] = score.get(a, 0) + w; games[a] = games.get(a, 0) + 1
        score[b] = score.get(b, 0) + 1 - w; games[b] = games.get(b, 0) + 1
        st = o["st"]
        for side, comp in (("A", a), ("B", b)):
            for el in comp.split("+"):
                d = per[el]; d["rounds"] += o["n"]
                d["deaths"] += st.get("deaths", {}).get(f"{side}|{el}", 0)
                c = st.get("contact", {})
                d["cn"] += c.get(f"{side}|{el}|n", 0); d["clost"] += c.get(f"{side}|{el}|lost", 0); d["cwon"] += c.get(f"{side}|{el}|won", 0)
                for kk, v in st.get("casts", {}).items():
                    if kk.startswith(f"{side}|{el}|"): ab = kk.split("|")[2]; d["casts"][ab] = d["casts"].get(ab, 0) + v
                for kk, v in st.get("dmg", {}).items():
                    if kk.startswith(f"{side}|{el}|"): ab = kk.split("|")[2]; d["dmg"][ab] = d["dmg"].get(ab, 0) + v
                d["absorb"] += st.get("absorb", {}).get(f"{side}|{el}|TTwall", 0)
    wr = {c: score[c] / games[c] for c in score}
    el = {e: mean(v for c, v in wr.items() if e in c.split("+")) for e in MONO}
    ranked = sorted(wr.items(), key=lambda kv: -kv[1])

    def grp(f_): return mean(v for c, v in wr.items() if f_(set(c.split("+"))))
    return {"N": J["meta"]["N"], "wr": wr, "el": el, "ranked": ranked, "sd": stt.pstdev(wr.values()),
            "spread": max(el.values()) - min(el.values()), "per": per,
            "TA": grp(lambda s: {"Terra", "Aqua"} <= s), "T_": grp(lambda s: "Terra" in s and "Aqua" not in s),
            "A_": grp(lambda s: "Aqua" in s and "Terra" not in s), "__": grp(lambda s: not ({"Terra", "Aqua"} & s))}


def cnt(lst, f_): return sum(1 for c, _ in lst if f_(set(c.split("+"))))


def split(s, b, e):
    """e's comps with Terra / without Terra: change against b."""
    w = [s["wr"][c] - b["wr"][c] for c in s["wr"] if e in c.split("+") and "Terra" in c.split("+")]
    o = [s["wr"][c] - b["wr"][c] for c in s["wr"] if e in c.split("+") and "Terra" not in c.split("+")]
    return 100 * mean(w), 100 * mean(o)


import pickle
CACHE = os.path.join(HERE, "_q28_cache.pkl")              # summaries keyed by file, rebuilt when a file's mtime changes
try: _C = pickle.load(open(CACHE, "rb"))
except Exception: _C = {}


def summ(f):
    m = os.path.getmtime(f)
    if f not in _C or _C[f][0] != m: _C[f] = (m, summarise(f))
    return _C[f][1]


S = {}
for _, tag, *rest in P28 + P29 + EXACT:
    if tag not in S and os.path.exists(fpath(tag)): S[tag] = summ(fpath(tag))
old = os.path.join(HERE, "results_rr84_q27_base6.json")
OLD = summ(old) if os.path.exists(old) else None
pickle.dump(_C, open(CACHE, "wb"))
base = S["base"]
assert len({s["N"] for s in S.values()}) == 1, "mixed N: " + str({k: s["N"] for k, s in S.items()})
out = []; P = out.append
nb = S.get("base_b")
P(f"All runs: {base['N']} rounds per pairing, 3,486 pairings, no jump, lowest-HP focus, teamwork on, package v3, live Cryo.")
P("")
if nb:
    cb, cn_ = base["per"]["Cryo"], nb["per"]["Cryo"]
    P(f"Noise: the baseline on a second seed set moves every Element by at most "
      f"{max(abs(100 * (nb['el'][e] - base['el'][e])) for e in MONO):.1f} points (Aqua {100 * (nb['el']['Aqua'] - base['el']['Aqua']):+.1f}, "
      f"Cryo {100 * (nb['el']['Cryo'] - base['el']['Cryo']):+.1f}, Terra {100 * (nb['el']['Terra'] - base['el']['Terra']):+.1f}); "
      f"single comps by an SD of {100 * stt.pstdev(nb['wr'][c] - base['wr'][c] for c in base['wr']):.1f} "
      f"(largest {100 * max(abs(nb['wr'][c] - base['wr'][c]) for c in base['wr']):.1f}); the comp spread by "
      f"{100 * (nb['sd'] - base['sd']):+.1f}; the 'neither Terra nor Aqua' group by {100 * (nb['__'] - base['__']):+.1f}. "
      f"Cryo's contacts: lost {100 * cb['clost'] / cb['cn']:.0f}% -> {100 * cn_['clost'] / cn_['cn']:.0f}%, won "
      f"{100 * cb['cwon'] / cb['cn']:.0f}% -> {100 * cn_['cwon'] / cn_['cn']:.0f}%, lost per round {cb['clost'] / cb['rounds']:.3f} -> "
      f"{cn_['clost'] / cn_['rounds']:.3f}.")
    P("")
if OLD:
    P("Step 0 correction (P27's v3 baseline, which aimed Blizzard and Deep Freeze, -> live Cryo, same seeds): " +
      ", ".join(f"{e[:3]} {100 * OLD['el'][e]:.1f} -> {100 * base['el'][e]:.1f}" for e in MONO) +
      f"; comp spread {100 * OLD['sd']:.1f} -> {100 * base['sd']:.1f}. Cryo casts per round: Blizzard "
      f"{OLD['per']['Cryo']['casts'].get('BZ', 0) / OLD['per']['Cryo']['rounds']:.2f} -> {base['per']['Cryo']['casts'].get('BZ', 0) / base['per']['Cryo']['rounds']:.2f}, "
      f"Deep Freeze {OLD['per']['Cryo']['casts'].get('DF', 0) / OLD['per']['Cryo']['rounds']:.2f} -> {base['per']['Cryo']['casts'].get('DF', 0) / base['per']['Cryo']['rounds']:.2f}.")
    P("")
P("## P28: Twin Tide walls that block shots")
P("")
P("Changes are against the baseline; \"blocking alone\" is Aqua against the matching rule-only control (same cover-casting, walls that block nothing).")
P("")
P("| Run | Aqua comps | Blocking alone (Aqua) | Terra comps | Terra + Aqua | Terra, no Aqua | Aqua, no Terra | Neither | Comp spread (SD) | Best - worst Element | Bottom 6 with neither Terra nor Aqua | Top 6 with Terra / Aqua | Twin Tide per Aqua per round: cover casts · HP absorbed · crush damage | Aqua dies % |")
P("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
for name, tag, ctl in P28:
    s = S.get(tag)
    if not s: continue
    d = lambda k: f" ({100 * (s['el'][k] - base['el'][k]):+.1f})" if s is not base else ""
    g = lambda k: f"{100 * s[k]:.1f}" + (f" ({100 * (s[k] - base[k]):+.1f})" if s is not base else "")
    blk = f"{100 * (s['el']['Aqua'] - S[ctl]['el']['Aqua']):+.1f}" if ctl and ctl in S else "—"
    a = s["per"]["Aqua"]
    P(f"| {name} | {100 * s['el']['Aqua']:.1f}{d('Aqua')} | {blk} | {100 * s['el']['Terra']:.1f}{d('Terra')} | {g('TA')} | {g('T_')} | {g('A_')} | {g('__')} | "
      f"{100 * s['sd']:.1f} | {100 * s['spread']:.0f} | {cnt(s['ranked'][-6:], lambda x: not ({'Terra', 'Aqua'} & x))} | "
      f"{cnt(s['ranked'][:6], lambda x: 'Terra' in x)} / {cnt(s['ranked'][:6], lambda x: 'Aqua' in x)} | "
      f"{a['casts'].get('TT_cover', 0) / a['rounds']:.2f} · {a['absorb'] / a['rounds']:.0f} · {a['dmg'].get('TT', 0) / a['rounds']:.1f} | "
      f"{100 * a['deaths'] / a['rounds']:.0f}% |")
P("")
P("## P29: cursor-targeted versions of the self-centred abilities")
P("")
P("Contact = an enemy closes to 16 studs on a player (counted again only after that enemy has gone past 30). Lost = the player "
  "dies within 6 s of it, before the enemy who closed; won = that enemy dies first. Counts are per player-round, so one death "
  "after two enemies closed counts twice.")
P("")
P("| Run | Element | Its comps (vs baseline) | Its comps with Terra / without Terra | Dies % | Contacts per round | Contacts lost · won | Lost contacts per round | Casts per round | Terra comps | Comp spread (SD) | Best - worst | In bottom 6 / top 6 |")
P("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
rows29 = [("baseline: " + e, "base", e, ab) for e, ab in (("Cryo", "FF"), ("Terra", "AS"), ("Radiant", "BN"))] + P29
for name, tag, e, ab in rows29:
    s = S.get(tag)
    if not s: continue
    q = s["per"][e]
    casts = " / ".join(f"{k} {q['casts'].get(k, 0) / q['rounds']:.2f}" for k in ((("FF", "BZ", "DF") if e == "Cryo" else (ab,))))
    dlt = f" ({100 * (s['el'][e] - base['el'][e]):+.1f})" if s is not base else ""
    sp = "—" if s is base or e == "Terra" else "{:+.1f} / {:+.1f}".format(*split(s, base, e))
    td = f"{100 * s['el']['Terra']:.1f}" + (f" ({100 * (s['el']['Terra'] - base['el']['Terra']):+.1f})" if s is not base else "")
    P(f"| {name} | {e} | {100 * s['el'][e]:.1f}{dlt} | {sp} | {100 * q['deaths'] / q['rounds']:.0f}% | {q['cn'] / q['rounds']:.2f} | "
      f"{100 * q['clost'] / max(1, q['cn']):.0f}% · {100 * q['cwon'] / max(1, q['cn']):.0f}% | {q['clost'] / q['rounds']:.3f} | {casts} | {td} | "
      f"{100 * s['sd']:.1f} | {100 * s['spread']:.0f} | {cnt(s['ranked'][-6:], lambda x: e in x)} / {cnt(s['ranked'][:6], lambda x: e in x)} |")
if "ex_base" in S:
    eb = S["ex_base"]
    P("")
    P("### Robustness (my addition): Blizzard's live 6 s and a Flash Freeze closer to live")
    P("")
    P("The sim's Flash Freeze gives a caught body a 4 s root at once; live, the front eases out over 1 s, a touched body is "
      "slowed to 5 and only rooted after 1 s inside (so a body near the edge can still get out), and the root lasts to the zone's "
      "end, then shatters. The sim's Blizzard slowed for 6.6 s; live it is 6 s. These runs use the live front speed, root end, "
      "shatter time and 6 s Blizzard, baseline included. The 1 s-inside rule is approximated: a body that can't get within 5 "
      "studs of the edge before the front reaches it counts as caught, and is rooted (and takes its 10) from the cast, not from "
      "the touch, so it is held 4.88 s, against 4 s in the main runs and about 3 to 3.5 s of root live. Changes are against "
      "this baseline.")
    P("")
    P(f"This timing vs the main baseline: Cryo {100 * base['el']['Cryo']:.1f} -> {100 * eb['el']['Cryo']:.1f}, Terra "
      f"{100 * base['el']['Terra']:.1f} -> {100 * eb['el']['Terra']:.1f}; Cryo contacts lost {100 * eb['per']['Cryo']['clost'] / eb['per']['Cryo']['cn']:.0f}% "
      f"/ won {100 * eb['per']['Cryo']['cwon'] / eb['per']['Cryo']['cn']:.0f}%, lost per round {eb['per']['Cryo']['clost'] / eb['per']['Cryo']['rounds']:.3f}.")
    P("")
    P("| Run | Cryo comps | With Terra / without Terra | Contacts lost · won | Lost contacts per round | Terra comps | Comp spread (SD) | Same run on the sim's timing |")
    P("|---|---|---|---|---|---|---|---|")
    twin = {"ex_ff20": "ff20", "ex_ff25": "ff25", "ex_bz32": "bz32"}
    for name, tag in EXACT:
        s = S.get(tag)
        if not s: continue
        q = s["per"]["Cryo"]
        sp = "—" if s is eb else "{:+.1f} / {:+.1f}".format(*split(s, eb, "Cryo"))
        same = S.get(twin.get(tag, ""))
        P(f"| {name} | {100 * s['el']['Cryo']:.1f}" + (f" ({100 * (s['el']['Cryo'] - eb['el']['Cryo']):+.1f})" if s is not eb else "") +
          f" | {sp} | {100 * q['clost'] / q['cn']:.0f}% · {100 * q['cwon'] / q['cn']:.0f}% | {q['clost'] / q['rounds']:.3f} | "
          f"{100 * s['el']['Terra']:.1f}" + (f" ({100 * (s['el']['Terra'] - eb['el']['Terra']):+.1f})" if s is not eb else "") +
          f" | {100 * s['sd']:.1f} | " + (f"Cryo {100 * (same['el']['Cryo'] - base['el']['Cryo']):+.1f}" if same else "—") + " |")
P("")
P("## Element win % per run")
P("")
P("| Run | " + " | ".join(MONO) + " |")
P("|---|" + "---|" * len(MONO))
seen_ = set()
for name, tag, *rest in ([("P27 v3 baseline (aimed Blizzard / Deep Freeze)", "OLD")] if OLD else []) + P28 + P29 + EXACT:
    s = OLD if tag == "OLD" else S.get(tag)
    if not s or tag in seen_: continue
    seen_.add(tag)
    P(f"| {name} | " + " | ".join(f"{100 * s['el'][e]:.1f}" for e in MONO) + " |")
P("")
seen_ = set()
for name, tag, *rest in P28 + P29 + EXACT:
    s = S.get(tag)
    if not s or tag in seen_: continue
    seen_.add(tag)
    P(f"**{name}** — bottom 6: " + ", ".join(f"{c.replace('+', ' + ')} {100 * v:.0f}" for c, v in s["ranked"][-6:]) +
      " | top 6: " + ", ".join(f"{c.replace('+', ' + ')} {100 * v:.0f}" for c, v in s["ranked"][:6]))
# ---- the Technique-swap check (swaprr): X's Defense slot -> Twin Tide / Bulwark Wall, each paired with a control that
# has the same global settings (the Twin Tide wall rule is global: it also changes every native Aqua) and the same seeds
SWAPS = [("Twin Tide, live walls, (b) 100 + 100", "swap_TTlive", "swap_none_TTlive"),
         ("Twin Tide, standing walls, (a) 200 + 3 s", "swap_TT", "swap_none_TT"),
         ("Bulwark Wall (v3: 400 HP)", "swap_BW", "swap_none")]
cols = [(n_, t_, c_) for n_, t_, c_ in SWAPS if os.path.exists(fpath(t_, "swaprr")) and os.path.exists(fpath(c_, "swaprr"))]
if cols:
    import team_sim as T
    P("")
    P("## Technique swap: one Element's Defense Technique replaced, against the 83 other comps (paired seeds)")
    P("")
    P("Each cell: that Element's comps without the swap -> with it (change). The control has the same settings as the swap run.")
    P("")
    P("| Element (its Defense slot) | " + " | ".join(n_ for n_, _, _ in cols) + " |")
    P("|---|" + "---|" * len(cols))
    LD = {}
    for _, t_, c_ in cols:
        sw = json.load(open(fpath(t_, "swaprr")))["jobs"]; cw = json.load(open(fpath(c_, "swaprr")))["jobs"]
        LD[t_] = ({k.split("#")[0]: o["win"] / o["n"] for k, o in cw.items()}, sw)
    for x in MONO:
        cells = []
        for _, t_, c_ in cols:
            cmap, sw = LD[t_]
            pairs = [(cmap[k.split("#")[0]], o["win"] / o["n"]) for k, o in sw.items() if k.split("#")[1].split("|")[1] == x]
            cells.append(f"{100 * mean(c for c, _ in pairs):.1f} -> {100 * mean(v for _, v in pairs):.1f} ({100 * mean(v - c for c, v in pairs):+.1f})" if pairs else "— (its own)")
        P(f"| {x} ({T.TECH[x][1]}) | " + " | ".join(cells) + " |")
open(os.path.join(HERE, "q28_compare.md"), "w", encoding="utf-8").write("\n".join(out))
print("\n".join(out))
