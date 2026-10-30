"""SPELLSHOT status-effect balance model: the three rework presets against the live kit numbers (2026-09-24).
Monte Carlo over 60-second pressure windows. Live numbers: MaxHealth 150; Icicle Shard 8 per hit every 0.333 s; Fireball
18 (+9 splash) every 0.6 s; Immolate buffs 3 Fireballs; Scorching Lash 12 per strike every 2.5 s; walk 16, sprint 25.
Hypothetical (kits not built): Chain Bolt 9 per hit every 0.45 s; Spore Burst / Corrosive Cloud keeps Poison applied;
Mark for Death every 12 s; Blessing every 14 s. python balance_sim.py -> balance_results.json + printed table"""
import json
import os
import random

HERE = os.path.dirname(os.path.abspath(__file__))
HP, SPRINT = 150.0, 25.0

PRESETS = {
    "A": dict(label="SPEC  (manual v0.13 durations, today's effects)",
              chill=dict(window=5.0, caps=[22, 15], root=0.8, immune=1.2, maxs=3),
              burn=dict(interval=0.5, imm=(10, 1.2), lash=(10, 1.6, 3)),
              poison=dict(dur=5.0, interval=1.0, tick=4.0, maxs=1),
              charged=dict(dur=5.0, maxs=4, dmg=16, alone=0),
              mark=dict(dur=8.0, bonus=0.30), bless=dict(dur=8.0, absorb=35)),
    "B": dict(label="THRESHOLD  (M1 hits only build stacks; the payoff is at max)",
              chill=dict(window=4.0, caps=[None, None], root=0.7, immune=2.0, maxs=3),
              burn=dict(interval=0.5, imm=(6, 2.0), lash=(6, 2.0, 3)),
              poison=dict(dur=4.0, interval=1.0, tick=3.0, maxs=1),
              charged=dict(dur=4.0, maxs=3, dmg=14, alone=10),
              mark=dict(dur=6.0, bonus=0.25), bless=dict(dur=6.0, absorb=30)),
    "C": dict(label="SOFT PRESSURE  (manual durations, lighter per-stack effects)",
              chill=dict(window=5.0, caps=[22, 19], root=0.5, immune=2.5, maxs=3),
              burn=dict(interval=0.5, imm=(10, 0.9), lash=(10, 1.2, 3)),
              poison=dict(dur=5.0, interval=1.0, tick=2.5, maxs=2),
              charged=dict(dur=5.0, maxs=3, dmg=12, alone=8),
              mark=dict(dur=8.0, bonus=0.20), bless=dict(dur=8.0, absorb=25)),
}
TODAY = dict(chill=dict(window=3.0, caps=[22, 15], root=0.8, immune=1.2, maxs=3))


def cryo_lock(ch, acc, T=60.0, rate=1 / 0.333, trials=400):
    """share of time rooted, slowed hard (<= 16), slowed at all, under a Cryo tapping at full rate with `acc` accuracy"""
    dt = 0.01
    rooted = slowed = hard = 0.0
    for _ in range(trials):
        t, nxt, stacks, stack_until, root_until, immune_until, cap = 0.0, 0.0, 0, 0.0, 0.0, 0.0, None
        while t < T:
            if t >= nxt:
                nxt += 1 / rate
                if random.random() < acc and t >= immune_until:
                    stacks += 1
                    if stacks >= ch["maxs"]:
                        stacks, root_until = 0, t + ch["root"]
                        immune_until = root_until + ch["immune"]
                        stack_until = 0.0
                    else:
                        stack_until = t + ch["window"]
            if t >= stack_until and stacks:
                stacks = 0
            cap = None
            if t < root_until:
                rooted += dt
            elif stacks and ch["caps"][stacks - 1] is not None:
                cap = ch["caps"][stacks - 1]
                slowed += dt
                if cap <= 16:
                    hard += dt
            t += dt
    n = trials * T
    return dict(rooted=rooted / n, slowed=slowed / n, hard_slow=hard / n)


def immolate_extra(b, acc=0.75):
    """extra damage from one Immolate (3 buffed Fireballs, 0.6 s apart), burns refreshed not extended"""
    ticks, dmg = b["imm"]
    hits = [i * 0.6 for i in range(3) if random.random() < acc]
    if not hits:
        return 0.0
    end = hits[-1] + ticks * b["interval"]
    return (int((end - hits[0]) / b["interval"]) ) * dmg


def lash_extra(b, strikes=3):
    ticks, per, maxs = b["lash"]
    # one strike every 2.5 s: stacks build, each strike resets the ticks; count tick damage until it runs out
    t, stacks, left, total = 0.0, 0, 0, 0.0
    strike_at = [i * 2.5 for i in range(strikes)]
    while t < 40:
        if strike_at and t >= strike_at[0]:
            strike_at.pop(0)
            stacks, left = min(maxs, stacks + 1), ticks
        if left > 0 and t > 0 and abs((t / b["interval"]) - round(t / b["interval"])) < 1e-6:
            total += per * stacks
            left -= 1
        t = round(t + 0.05, 2)
        if left <= 0 and not strike_at:
            break
    return total


def charged_dps(c, acc=0.7, bolt=9.0, rate=1 / 0.45, duel=True):
    """extra DPS from Charged discharges on a Voltaic M1 of `bolt` damage (hypothetical), in a duel (no other enemy)"""
    hits_per_s = rate * acc
    per_discharge = c["alone"] if duel else c["dmg"]
    return hits_per_s / c["maxs"] * per_discharge, hits_per_s * bolt


def main():
    random.seed(7)
    out = {}
    rows = []
    for key, p in list(PRESETS.items()) + [("TODAY", dict(label="TODAY (live build)", chill=TODAY["chill"]))]:
        r = {}
        for acc in (0.6, 0.9):
            r["cryo_%d" % int(acc * 100)] = cryo_lock(p["chill"], acc)
        if key != "TODAY":
            imm = sum(immolate_extra(p["burn"]) for _ in range(2000)) / 2000
            r["immolate_extra"] = imm
            r["lash_3_strikes"] = lash_extra(p["burn"])
            po = p["poison"]
            r["poison_full"] = po["tick"] * po["dur"] / po["interval"] * po["maxs"]
            cd, base = charged_dps(p["charged"])
            r["charged_duel_dps"], r["voltaic_base_dps"] = cd, base
            cd2, _ = charged_dps(p["charged"], duel=False)
            r["charged_team_dps"] = cd2
            m = p["mark"]
            r["mark_on_boulder48"] = 48 * m["bonus"]
            r["mark_on_shard8"] = 8 * m["bonus"]
            r["bless_seconds_vs_25dps"] = p["bless"]["absorb"] / 25.0
        out[key] = r
    json.dump(out, open(os.path.join(HERE, "balance_results.json"), "w"), indent=1)
    for key, r in out.items():
        print(key, json.dumps({k: (round(v, 3) if isinstance(v, float) else {kk: round(vv, 3) for kk, vv in v.items()})
                               for k, v in r.items()}))


if __name__ == "__main__":
    main()
