"""Runs the 3v3 matchups in parallel and writes results_<tag>.json.
  python run_all.py main  [N]          all 105 matchups x 4 configurations x 2 policies, datasets P and L
  python run_all.py cover [N]          Pass 1 / Variant A, dataset P, 40% of aimed shots blocked by cover
  python run_all.py swaps [N] <best>   step 8: every single-Technique swap per mono-comp vs <best> (Pass 1 / Variant A, P)"""
import json, os, sys, time, zlib
from multiprocessing import Pool
import team_sim as T

S = {"S1": ["Terra", "Radiant", "Pyro"], "S2": ["Terra", "Radiant", "Voltaic"], "S3": ["Terra", "Cryo", "Pyro"],
     "S4": ["Radiant", "Umbra", "Pyro"], "S5": ["Cryo", "Aqua", "Terra"], "W1": ["Aqua", "Toxin", "Zephyr"],
     "W2": ["Pyro", "Pyro", "Voltaic"]}
MONO, STRAT, WEAK = T.ELS, ["S1", "S2", "S3", "S4", "S5"], ["W1", "W2"]
HERE = os.path.dirname(os.path.abspath(__file__))


def comp(n):
    if n in S: return S[n]
    return n.split("+") if "+" in n else [n] * 3


def matchups():
    m = [(a, b, "mono-strat") for a in MONO for b in STRAT]
    m += [(a, b, "mono-mono") for i, a in enumerate(MONO) for b in MONO[i + 1:]]
    m += [(a, b, "strat-strat") for i, a in enumerate(STRAT) for b in STRAT[i + 1:]]
    m += [(a, b, "weak-strat") for a in WEAK for b in STRAT]
    m += [(a, b, "weak-mono") for a in WEAK for b in ("Pyro", "Aqua")]
    assert len(m) == 105
    return m


def bump(d, k, v=1.0): d[k] = d.get(k, 0.0) + v


def job(args):
    key, a, b, ds, hp, jump, pol, N, expose, tech_a, tech_b = args
    T.EXPOSE = expose
    seed0 = zlib.crc32(key.split("#")[0].encode()) * 1000 + int(os.environ.get("SIM_SEED_SALT", "0")) * 7919   # salt: independent repeat; "#..." = same seeds (paired)
    o = {"n": 0, "win": 0.0, "draw": 0, "dur": 0.0, "wipe_n": 0, "wipe_dur": 0.0, "timeout": 0, "fd": {}, "st": {},
         "ult": {"A_ready": 0, "B_ready": 0, "A_t": 0.0, "B_t": 0.0, "A_clust": 0, "B_clust": 0, "A_n3": 0, "B_n3": 0},
         "hpA": 0.0, "hpB": 0.0}
    for i in range(N):
        w, win, how, tt, fd, ul = T.fight(comp(a), comp(b), ds, hp, jump, pol, seed0 + i, tech_a, tech_b)
        o["n"] += 1; o["win"] += win; o["draw"] += win == 0.5; o["dur"] += tt
        if how == "wipe": o["wipe_n"] += 1; o["wipe_dur"] += tt
        else: o["timeout"] += 1
        if fd: bump(o["fd"], "AB"[fd[0]] + "|" + fd[2]); bump(o["fd"], "AB"[fd[0]] + "|el|" + fd[1])
        for cat, d in w.st.items():
            for k, v in d.items():
                if isinstance(k, tuple):
                    ks = "AB"[k[0]] + "|" + "|".join(str(x) for x in k[1:]) if isinstance(k[0], int) else "|".join(k)
                else: ks = str(k)
                bump(o["st"].setdefault(cat, {}), ks, v)
        for side, ts in zip("AB", ul):
            rd = sorted(x for x in ts if x is not None)
            o["ult"][side + "_ready"] += len(rd); o["ult"][side + "_t"] += sum(rd)
            if len(rd) >= 2 and any(rd[j + 1] - rd[j] <= 3.0 for j in range(len(rd) - 1)): o["ult"][side + "_clust"] += 1
            if len(rd) == 3 and rd[2] - rd[0] <= 6.0: o["ult"][side + "_n3"] += 1
        A, B = w.teams
        o["hpA"] += sum(q.hp for q in A) / sum(q.maxhp for q in A); o["hpB"] += sum(q.hp for q in B) / sum(q.maxhp for q in B)
    return key, o


def main():
    mode = sys.argv[1]
    N = int(sys.argv[2]) if len(sys.argv) > 2 else 200
    jobs = []
    if mode == "main":
        for ds in ("P", "L"):
            for hp in (1, 2):
                for jump in (False, True):
                    for pol in ("low", "soft"):
                        for a, b, g in matchups():
                            key = f"{ds}|{hp}|{'B' if jump else 'A'}|{pol}|{a}|{b}"
                            jobs.append((key, a, b, ds, hp, jump, pol, N, 1.0, None, None))
    elif mode == "rxoff":                      # Pass 1 / Variant A, dataset P, reactions switched off (env SIM_RX_OFF=1)
        assert os.environ.get("SIM_RX_OFF"), "set SIM_RX_OFF=1"
        for pol in ("low", "soft"):
            for a, b, g in matchups():
                jobs.append((f"P|1|A|{pol}|{a}|{b}", a, b, "P", 1, False, pol, N, 1.0, None, None))
    elif mode == "whatif":                     # P1/A, dataset P, with the SIM_* knobs set in the environment
        for pol in ("low", "soft"):
            for a, b, g in matchups():
                jobs.append((f"P|1|A|{pol}|{a}|{b}", a, b, "P", 1, False, pol, N, 1.0, None, None))
    elif mode == "pkg":                        # a team-mode package (SIM_* knobs) on dataset L: 105 matchups, A and B, both policies
        for var in ("A", "B"):
            for pol in ("low", "soft"):
                for a_, b_, g in matchups():
                    jobs.append((f"L|1|{var}|{pol}|{a_}|{b_}", a_, b_, "L", 1, var == "B", pol, N, 1.0, None, None))
    elif mode == "rr84":                       # every comp with no Element twice, round-robin, dataset L, lowest-HP
        import itertools
        var = os.environ.get("SIM_VAR", "A")
        combos = ["+".join(c) for c in itertools.combinations(T.ELS, 3)]
        rule = os.environ.get("SIM_COMP_RULE", "")     # handoff B: tank-role rule. T1 = exactly one Terra per team,
        prot = {"T1": {"Terra"}, "TA1": {"Terra", "Aqua"}}.get(rule)   # TA1 = exactly one of Terra / Aqua
        if prot: combos = [c for c in combos if len(prot & set(c.split("+"))) == 1]
        for i, a_ in enumerate(combos):
            for b_ in combos[i + 1:]:
                jobs.append((f"rr|{var}|{a_}|{b_}", a_, b_, "L", 1, var == "B", "low", N, 1.0, None, None))
    elif mode == "swaprr":                     # P28 swap check: one Element's Defense slot swapped, vs the 83 other comps
        import itertools                       # SIM_SWAP = TT | BW | none (the paired control: same seeds, no swap)
        sw = os.environ.get("SIM_SWAP", "none")
        combos = ["+".join(c) for c in itertools.combinations(T.ELS, 3)]
        for c_ in combos:
            els = c_.split("+")
            for x in (els if sw != "none" else ["-"]):
                if sw != "none" and T.HOME[sw] == x: continue
                techs = None
                if sw != "none":
                    techs = [T.TECH[e] if e != x else (T.TECH[e][0], sw) for e in els]
                for d_ in combos:
                    if d_ == c_: continue
                    jobs.append((f"sw|{c_}|{d_}#{sw}|{x}", c_, d_, "L", 1, False, "low", N, 1.0, techs, None))
    elif mode == "cover":
        for pol in ("low", "soft"):
            for a, b, g in matchups():
                jobs.append((f"P|1|A|{pol}|{a}|{b}", a, b, "P", 1, False, pol, N, 0.6, None, None))
    elif mode == "swaps":
        best = sys.argv[3]
        for el in MONO:
            for k in [None] + sorted(set(T.HOME) - set(T.TECH[el])):
                for slot in ((0, 1) if k else (None,)):
                    if k:
                        tech = list(T.TECH[el]); tech[slot] = k; tech = tuple(tech)
                    else:
                        tech = T.TECH[el]
                    for pol in ("low", "soft"):
                        key = f"P|1|A|{pol}|{el}|{best}|{'+'.join(tech)}"
                        jobs.append((key, el, best, "P", 1, False, pol, N, 1.0, [tech] * 3, None))
    elif mode == "swaps2":                      # both Technique slots, for the Elements with no single-swap reaction
        best = sys.argv[3]
        pairs = [("LS", "VO"), ("LS", "RS"), ("LS", "AR"), ("DF", "LS"), ("DF", "RS"), ("DT", "VO")]
        for el in ("Aqua", "Terra", "Radiant", "Umbra"):
            for tech in [T.TECH[el]] + pairs:
                for pol in ("low", "soft"):
                    key = f"P|1|A|{pol}|{el}|{best}|{'+'.join(tech)}"
                    jobs.append((key, el, best, "P", 1, False, pol, N, 1.0, [tuple(tech)] * 3, None))
    elif mode == "swapconfirm":                 # the chosen loadouts again on fresh seeds (the pick itself is biased up)
        best = sys.argv[3]
        picks = json.load(open(os.path.join(HERE, f"swap_picks_{best}.json")))
        suffix = "|confirm_np" if os.environ.get("SIM_NO_PATIENCE") else "|confirm"
        for el, techs in picks.items():
            for t_ in [T.TECH[el]] + [tuple(x) for x in techs]:
                for pol in ("low", "soft"):
                    key = f"P|1|A|{pol}|{el}|{best}|{'+'.join(t_)}{suffix}"
                    jobs.append((key, el, best, "P", 1, False, pol, N, 1.0, [tuple(t_)] * 3, None))
    t0 = time.time()
    res = {}
    with Pool(18) as pool:
        for i, (key, o) in enumerate(pool.imap_unordered(job, jobs, chunksize=2)):
            res[key] = o
            if (i + 1) % 200 == 0: print(f"{i + 1}/{len(jobs)} {time.time() - t0:.0f}s", flush=True)
    tag = (mode + "_" + os.environ.get("SIM_TAG", "x")) if mode in ("whatif", "pkg", "rr84", "swaprr") else mode + ("_" + sys.argv[3] if len(sys.argv) > 3 else "") + ("_np" if mode == "swapconfirm" and os.environ.get("SIM_NO_PATIENCE") else "")
    json.dump({"meta": {"mode": mode, "N": N, "jobs": len(jobs)}, "jobs": res},
              open(os.path.join(HERE, f"results_{tag}.json"), "w"))
    print("done", len(jobs), "jobs", f"{time.time() - t0:.0f}s")


if __name__ == "__main__":
    main()
