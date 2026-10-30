"""python pkg_quick.py <package.json> <teamplay 0|1> <N> matchup,...   (dataset L, Variant A, lowest-HP)"""
import json, os, sys, time
env = json.load(open(sys.argv[1])); env["SIM_TEAMPLAY"] = sys.argv[2]
os.environ.update(env)
import team_sim as T, run_all as RA
N = int(sys.argv[3])
for pair in sys.argv[4].split(","):
    a, b = pair.split("-")
    t0 = time.time(); W = dur = 0.0; heal = dmg = 0.0; acc = {}
    for i in range(N):
        w, win, how, tt, fd, ul = T.fight(RA.comp(a), RA.comp(b), "L", 1, False, "low", 5000 + i)
        W += win; dur += tt
        for key in ("heal", "absorb", "dmg"):
            for k, v in w.st[key].items(): acc.setdefault(key, {})[k] = acc.get(key, {}).get(k, 0) + v / N
    hd = {k: round(v) for k, v in acc.get("heal", {}).items() if v >= 1}; ab = {k: round(v) for k, v in acc.get("absorb", {}).items() if v >= 1}
    dA = sum(v for k, v in acc["dmg"].items() if k[0] == 0); dB = sum(v for k, v in acc["dmg"].items() if k[0] == 1)
    print(f"{a} vs {b}: win {W/N:.2f}  round {dur/N:.1f}s  dmg A {dA:.0f} B {dB:.0f}  heal {hd}  absorb {ab}  [{(time.time()-t0)/N*1000:.0f} ms]")
