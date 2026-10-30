"""End-of-round Ultimate charge (carried into the next round in a Duel-style match), P1/A, dataset P."""
import json, sys
from multiprocessing import Pool
import team_sim as T, run_all as RA

def job(args):
    a, b, pol, N = args
    out = {"win_full": 0, "lose_full": 0, "win_n": 0, "lose_n": 0, "win_sum": 0.0, "lose_sum": 0.0, "lose_3full": 0, "lose_2full": 0, "rounds": 0}
    for i in range(N):
        w, win, how, tt, fd, ul = T.fight(RA.comp(a), RA.comp(b), "P", 1, False, pol, 777000 + i)
        if win == 0.5: continue
        out["rounds"] += 1
        W, L = (w.teams[0], w.teams[1]) if win == 1.0 else (w.teams[1], w.teams[0])
        for side, team in (("win", W), ("lose", L)):
            ch = [min(1.0, q.ult) for q in team]
            out[side + "_n"] += 3; out[side + "_sum"] += sum(ch); out[side + "_full"] += sum(1 for c in ch if c >= 1.0)
            if side == "lose":
                f = sum(1 for c in ch if c >= 1.0)
                out["lose_3full"] += f == 3; out["lose_2full"] += f >= 2
    return out

if __name__ == "__main__":
    jobs = [(a, b, pol, 40) for a, b, g in RA.matchups() for pol in ("low", "soft")]
    tot = {}
    with Pool(8) as p:
        for o in p.imap_unordered(job, jobs):
            for k, v in o.items(): tot[k] = tot.get(k, 0) + v
    r = tot["rounds"]
    print(f"rounds {r}: winners carry {tot['win_sum']/tot['win_n']:.2f} charge on average, {100*tot['win_full']/tot['win_n']:.0f}% full; "
          f"losers carry {tot['lose_sum']/tot['lose_n']:.2f}, {100*tot['lose_full']/tot['lose_n']:.0f}% full; "
          f"losing team starts the next round with 2+ full Ultimates {100*tot['lose_2full']/r:.0f}%, all 3 {100*tot['lose_3full']/r:.0f}%")
