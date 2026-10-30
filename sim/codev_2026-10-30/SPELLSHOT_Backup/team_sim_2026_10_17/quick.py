import time, sys, team_sim as T
S = {"S1": ["Terra","Radiant","Pyro"], "S2": ["Terra","Radiant","Voltaic"], "S3": ["Terra","Cryo","Pyro"],
     "S4": ["Radiant","Umbra","Pyro"], "S5": ["Cryo","Aqua","Terra"], "W1": ["Aqua","Toxin","Zephyr"], "W2": ["Pyro","Pyro","Voltaic"]}
def comp(n): return S[n] if n in S else [n]*3
pairs = [x.split("-") for x in sys.argv[1].split(",")]
ds = sys.argv[2] if len(sys.argv) > 2 else "P"; N = int(sys.argv[3]) if len(sys.argv) > 3 else 40
pol = sys.argv[4] if len(sys.argv) > 4 else "low"; jump = (sys.argv[5] == "B") if len(sys.argv) > 5 else False
hp = int(sys.argv[6]) if len(sys.argv) > 6 else 1
for a, b in pairs:
    t0 = time.time(); W = 0; dur = []; to = 0; acc = {}
    for i in range(N):
        w, win, how, tt, fd, ul = T.fight(comp(a), comp(b), ds, hp, jump, pol, 1000 + i)
        W += win; dur.append(tt); to += how == "time"
        for key in ("dmg", "rx", "heal", "absorb", "peel", "casts", "mana"):
            for k, v in w.st[key].items(): acc.setdefault(key, {})[k] = acc.get(key, {}).get(k, 0) + v / N
    el = time.time() - t0
    print(f"{a} vs {b}: win {W/N:.2f}  dur {sum(dur)/N:.1f}s  timeouts {to}  [{el/N*1000:.0f} ms/fight]")
    for side in (0, 1):
        top = sorted(((k, v) for k, v in acc.get("dmg", {}).items() if k[0] == side), key=lambda kv: -kv[1])[:10]
        print(f"   {'AB'[side]} dmg:", ", ".join(f"{k[1][:4]}.{k[2]} {v:.0f}" for k, v in top))
        for key in ("rx", "heal", "absorb", "peel"):
            d = {k[1:]: round(v, 1) for k, v in acc.get(key, {}).items() if k[0] == side}
            if d: print(f"     {key}:", d)
    if len(sys.argv) > 7:
        print("   casts:", {k: round(v, 1) for k, v in acc["casts"].items() if k[1] == sys.argv[7]})
