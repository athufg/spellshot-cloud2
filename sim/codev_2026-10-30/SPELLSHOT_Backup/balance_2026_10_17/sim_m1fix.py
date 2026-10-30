"""SPELLSHOT balance sim, re-run for the 2026-10-17 balance pass (copied from balance_2026_10_16/sim.py).
PASS "before" = the live kit of 2026-10-16; PASS "after" = the kit after CHANGES_2026-10-17_balance_pass.md.
Both passes share two model corrections over the first run: the 3rd Chill stack holds a cap of 10 for its window
(it stopped rooting on 2026-10-08), and a dash (Cross-Slash, Bulwark Charge, Overcharge) is refused under DASH_MINCAP.
The BEHAVIOUR model (aim error, dodging, reaction, policies, arena) is an assumption, set out in the block below.
Run:  python sim.py [runs_per_pair] [before|after]   -> sim_results_<pass>.json and tables_<pass>.md next to this file."""
import math, random, sys, json, os
random.seed(7)

PASS = sys.argv[2] if len(sys.argv) > 2 else "after"
AFTER = PASS == "after"
OV = json.loads(os.environ.get("SIM_OVERRIDES", "{}"))     # test values, e.g. {"FB_DIRECT": 15, "HITBOX": 1.3}
TAG = os.environ.get("SIM_TAG", PASS)
def P(name, default): return OV.get(name, default)
def PS(default): return float(OV.get("PROJ_SPEED", default))   # one speed for every M1 projectile, when set

# ---------------------------------------------------------------- assumptions (change and re-run)
HP, MANA, REGEN, DT = 150.0, 100.0, 7.0, 0.1          # live: MaxHealth, MaxMana, ManaRegenPerSecond
# sustained slide -> slide-jump -> double-jump chain, studs/s: 59 measured in Play 2026-10-16. After: ESTIMATED, not
# measured -- 59 scaled by the slide-jump cap (70 -> 52) gives 44-46
CHAIN = float(P("CHAIN", 45.0 if AFTER else 59.0))   # 25 = running only (no slide, slide-jump or wall-run)
DASH_MINCAP = 16.0 if AFTER else 12.0     # a slow cap under this refuses a dash
TMAX = 90.0 if AFTER else 60.0            # after: the 90 s round clock (the larger health share takes the round)
PTICK = 6.0 if AFTER else 4.0             # Poisoned, per second (preset A)
FIGHT_LAT = 25.0        # lateral strafe in a close fight, studs/s
SIG_ANG, TRACK, LEAD_K = 0.018, 0.04, 0.45   # aim: 1 deg spread, 40 ms tracking lag, 45% of lead unpredictable
HITBOX = float(P("HITBOX", 1.0))              # Config.Hitbox.Scale: 1.3 since 2026-10-17 (every body part 30% bigger)
BODY, BODY_H = 1.1 * HITBOX, 2.6 * HITBOX     # half-width and half-height of the body a shot has to touch
SELF_ANG = 0.009                              # aim jitter from the shooter's own movement: 0.5 deg at a full 25 studs/s strafe
VERT = tuple(P("VERT", (12.0, 6.0)))                            # target's vertical speed, studs/s: chaining (slide-jumps), jump-strafing in a fight
CUR = {"vs": 0.0, "vv": 0.0}                  # the shooter's lateral speed and the target's vertical speed, set each turn
REACT = (0.15, 0.45)    # reaction to a telegraph, s
ARENA_R = 120.0                   # open disc; NO cover modelled
START_D = 160.0 if AFTER else 220.0   # spawn to spawn. After: each spawn 40 studs inside the edge (recommendation 4)
ULT_FIRST = 30.0        # Ultimate assumed charged after ~30 s of fighting (1/260 per damage + 0.06 a cast)
HEADSHOT = 0.25         # share of Shadow Dart hits that are headshots (Mark payout)

def p_hit(d, vp, w, vlat):
    """Chance one shot touches the body. Sideways: aim spread, the shooter's own movement, the unpredictable share of
    the target's sideways motion over the flight, and tracking lag on the RELATIVE motion of both. Up and down: the same
    for the target's jumps against the body's height. Both have to land."""
    tf = 0.0 if vp is None else d / vp
    vs, vv = CUR["vs"], CUR["vv"]
    s = math.sqrt((SIG_ANG * d) ** 2 + (SELF_ANG * d * vs / 25.0) ** 2 + (LEAD_K * vlat * tf) ** 2
                  + (math.hypot(vlat, vs) * TRACK) ** 2) + 1e-6
    sv = math.sqrt((SIG_ANG * d) ** 2 + (LEAD_K * vv * tf) ** 2 + (vv * TRACK) ** 2) + 1e-6
    wv = BODY_H + max(0.0, w - BODY)
    return math.erf(w / (math.sqrt(2) * s)) * math.erf(wv / (math.sqrt(2) * sv))

def react(): return random.uniform(*REACT)

def _nx(a, t, X):
    """M1 timing fix (2026-10-17): keep the remainder so a 0.12 s interval really fires 8.3 times a second on the 0.1 s step."""
    return (a.next_m1 if a.next_m1 > t - X else t) + X

class F:
    def __init__(s, el, pos):
        s.el, s.pos = el, list(pos)
        s.hp, s.mana = HP, MANA
        s.cd = {"ULT": ULT_FIRST}; s.next_m1 = 0.0
        s.shields, s.caps = [], []
        s.root = s.intr = s.dr_until = 0.0; s.dr = 0.0
        s.burn = [0.0, 0.0]; s.lash = [0, 0.0]; s.poison = [0.0, 0.0]; s.corrode = [0, 0.0]
        s.chill = [0, -9.0]; s.chill_imm = 0.0
        s.mark = None; s.immolate = 0; s.lasthit = -9.0
        s.channel = False; s.halo = (0.0, 0.0); s.decoy = 0.0; s.wall = 0.0
        s.boulder_t = 0.0; s.lance_t = 0.0; s.eclipse = 0.0; s.mode = "move"
        s.dealt = 0.0; s.dealt_far = 0.0
        s.charged = [0, 0.0]; s.vent = 0.0; s.chan_t0 = 0.0
    def cap(s, t):
        if s.root > t: return 0.0
        c = [x for x, e in s.caps if e > t]
        return min(c) if c else 999.0
    def speed(s, t, moving=True): return min(s.cap(t), CHAIN if moving else 35.0)
    def vlat(s, t):
        return min(s.cap(t), FIGHT_LAT) if s.mode == "fight" else 0.5 * s.speed(t, True)
    def vvert(s, t):
        if s.root > t: return 0.0
        return (VERT[0] if s.mode == "move" else VERT[1]) * min(1.0, s.cap(t) / 25.0)
    def ready(s, k, t, mana): return s.cd.get(k, -1) <= t and s.mana >= mana and s.intr <= t and not s.channel
    def use(s, k, t, cd, mana): s.cd[k] = t + cd; s.mana -= mana

def dist(a, b): return math.hypot(a.pos[0] - b.pos[0], a.pos[1] - b.pos[1])

def deal(src, tgt, amt, t, kind="hit", far=False):
    if amt <= 0 or tgt.hp <= 0: return 0.0
    if kind == "shot" and tgt.wall > t: return 0.0                       # Bulwark Wall eats shots
    if kind in ("shot", "single") and tgt.decoy > t and random.random() < 0.5:
        tgt.decoy = 0.0; return 0.0                                       # Decoy Double soaks one aimed hit (assumed 50%)
    if src.el == "Zephyr": amt *= 1.25 if src.mode == "move" else 1.08   # Updraft x1.25 airborne (chain = airborne)
    if src.el == "Umbra" and src.eclipse > t and kind in ("shot", "single"): amt *= 1.25   # Unseen under Eclipse
    if tgt.el == "Terra" and tgt.boulder_t > 0: amt *= 0.80              # Bedrock 5 x 4% while charging the M1
    if tgt.dr_until > t: amt *= (1 - tgt.dr)
    if kind == "dot" and tgt.vent > t: amt *= 0.7                         # after: Antitoxin Vent's DoT shield
    for sh in tgt.shields:
        if sh[1] > t and sh[0] > 0:
            take = min(sh[0], amt); sh[0] -= take; amt -= take
    before = tgt.hp
    tgt.hp -= amt; src.dealt += amt
    if AFTER and src.el == "Pyro" and before >= 0.3 * HP > tgt.hp > 0 and src.cd.get("IM", -1) > t:
        src.cd["IM"] = max(t, src.cd["IM"] - 0.3 * 12)                    # after: Ember Refund, under 30% health
    if far: src.dealt_far += amt
    if src.halo[1] > t and src.halo[0] < 60:
        h = min(amt, 60 - src.halo[0]); src.hp = min(HP, src.hp + h); src.halo = (src.halo[0] + h, src.halo[1])
    if amt > 0: src.lasthit = t
    return amt

def escapes(tgt, t, need, window):
    if need <= 0: return False
    return tgt.speed(t, True) * max(0.0, window - react()) >= need

# ---------------------------------------------------------------- M1s (live numbers)
def m1(a, b, d, t):
    if a.intr > t or a.channel or t < a.next_m1: return
    e, vl, far = a.el, b.vlat(t), d > 40
    def roll(vp, w): return random.random() < p_hit(d, vp, w, vl)
    if e == "Cryo":                                   # Icicle Shard 8, 0.333 s, 2 mana, 170 studs/s, 120
        if d > 120 or a.mana < 2: return
        a.mana -= 2; a.next_m1 = _nx(a, t, 0.333)
        if roll(PS(220 if AFTER else 170), BODY + 0.2):
            deal(a, b, P("ICE_DMG", 8), t, "shot", far)
            if b.chill_imm <= t:                      # preset A: window 5, caps 22 / 15 / 10; the 3rd holds 10 for its
                n = b.chill[0] + 1 if t - b.chill[1] < 5.0 else 1     # window, then 1.2 s with no new stack (no root)
                b.chill = [n, t]
                b.caps.append([(22.0, 15.0, 10.0)[min(n, 3) - 1], t + 5.0])
                if n >= 3: b.chill = [0, t]; b.chill_imm = t + 5.0 + 1.2
    elif e == "Pyro":                                 # Fireball 18 / 9 splash (6), 0.6 s, 3 mana, 65 studs/s, row range 110
        if d > 110 or a.mana < 3: return
        a.mana -= 3; a.next_m1 = _nx(a, t, P("FB_RATE", 0.6))
        fs = PS(110 if AFTER else 65)
        if roll(fs, BODY + 1.0): deal(a, b, P("FB_DIRECT", 18), t, "shot", far)
        elif roll(fs, P("FB_SPLASH_R", 6) + BODY): deal(a, b, P("FB_SPLASH", 9), t, "shot", far)   # splash r6 around a near miss
        else: return
        if a.immolate > 0: a.immolate -= 1; b.burn = [P("IMM_BURN", 2.4), t + 5.0]   # preset A Immolate burn 10 x 1.2 per 0.5 s
    elif e == "Zephyr":                               # Wind Blade 3, 0.12 s, 0.8 mana, 240 studs/s, 80
        if d > 80 or a.mana < 0.8: return
        a.mana -= 0.8; a.next_m1 = _nx(a, t, 0.12)
        if roll(PS(240), BODY + 1.1): deal(a, b, P("WB_DMG", 3), t, "shot", far)
    elif e == "Terra":                                # Boulder Shot: 1.1 s charge to 48, 0.85 s between, 86 studs/s
        if d > 120 or a.mana < 4: return
        a.boulder_t += DT
        if a.boulder_t < 1.1: return
        a.boulder_t = 0.0; a.mana -= 4; a.next_m1 = _nx(a, t, 0.85)
        if roll(PS(86), BODY + 1.1): deal(a, b, P("BOULDER_DMG", 48), t, "shot", far)
    elif e == "Voltaic":                              # Chain Bolt hitscan 8, 0.32 s, 2 mana, range 30 (chain needs a 2nd enemy)
        if d > 30 or a.mana < 2: return
        a.mana -= 2; a.next_m1 = _nx(a, t, 0.32)
        if roll(None, BODY + 0.865):
            deal(a, b, P("CB_DMG", 8), t, "shot", far)
            if AFTER:                                 # Charged: 4 stacks (5 s) go off into a lone target for 7, and
                n = b.charged[0] + 1 if b.charged[1] > t else 1      # Chain Reaction takes 2 s off Overcharge
                b.charged = [n, t + 5.0]
                if n >= 4:
                    b.charged = [0, 0.0]; deal(a, b, 7, t, "hit", far)
                    if a.cd.get("OC", -1) > t: a.cd["OC"] = max(t, a.cd["OC"] - 2.0)
    elif e == "Umbra":                                # Shadow Dart 65, 2.3 s charge in a 2.6 s cycle, 240 studs/s, 160
        if d > 160 or a.mana < 5: return
        a.mana -= 5; a.next_m1 = _nx(a, t, 2.6 / (1.5 if a.eclipse > t else 1.0))
        if roll(PS(240), BODY + 0.35):
            dmg = float(P("DART_DMG", 65))
            if b.mark is not None:
                st = min(3, int(t - b.mark))
                if st >= 1: dmg += (50 if random.random() < HEADSHOT else 10) * st
                b.mark = None
            deal(a, b, dmg, t, "shot", far)
    elif e == "Radiant":                              # Light Lance: 0.25 s ticks, 16 -> 32 dps over 2 s, 7.5 mana/s, 60
        if d > 60 or a.mana < 2: a.lance_t = 0.0; return
        a.mana -= 7.5 * DT
        if roll(None, BODY + 0.75):
            deal(a, b, (16 + (P("LANCE_MAX", 32) - 16) * min(1.0, a.lance_t / 2.0)) * DT, t, "shot", far); a.lance_t += DT
        else: a.lance_t = max(0.0, a.lance_t - 0.4)
    elif e == "Aqua":                                 # Riptide 12, 0.667 s, 4 mana, 70 studs/s ground wave, 7 wide, jumpable
        if d > P("RIP_RANGE", 70) or a.mana < 4: return
        a.mana -= 4; a.next_m1 = _nx(a, t, 0.667)
        if random.random() < p_hit(d, PS(100 if AFTER else 70), 3.5 + BODY, vl) * (1 - (0.35 if d > 15 else 0.1)): deal(a, b, P("RIP_DMG", 12), t, "shot", far)
    elif e == "Toxin":                                # Toxic Bubbles 9 + Poisoned (4/s 5 s), 0.55 s, 3 mana, 60 studs/s lob
        if d > 120 or a.mana < 3: return
        a.mana -= 3; a.next_m1 = _nx(a, t, 0.55)
        if roll(PS(90 if AFTER else 60), BODY + 1.0): deal(a, b, P("BUB_DMG", 9), t, "shot", far); b.poison = [PTICK * (1 + 0.12 * b.corrode[0]), t + 5.0]

# ---------------------------------------------------------------- abilities (default loadouts, live numbers)
def abilities(a, b, d, t, role):
    """returns (self_move, target_move): studs toward the other body (negative = away)"""
    e, me, them = a.el, 0.0, 0.0
    hpf, vl, far = a.hp / HP, b.vlat(t), d > 40
    rush = role == "rush"
    if e == "Cryo":
        if d <= 18 and a.ready("FF", t, 30):                  # Flash Freeze r20, lead 0.38, expands 1.0 s, contact slow 5
            a.use("FF", t, 14, 30)
            if not escapes(b, t, 20 - d, 0.38 + d / 20.0):
                deal(a, b, 10 + 34, t); b.caps.append([5.0, t + 1.2]); b.root = max(b.root, t + 4.0)
        if not rush and d <= 45 and a.ready("BZ", t, 28):     # Blizzard r32, cap 14, 8 s: dropped between them
            a.use("BZ", t, 18, 28); b.caps.append([11.0, t + 3.0] if AFTER else [14.0, t + 4.0])   # after: cap 11, 6 s
        if not rush and d <= 30 and a.ready("DF", t, 22):     # Deep Freeze: trap on own path, 10 + root (2.5, after 1.5)
            a.use("DF", t, 16, 22)
            if role == "kite" and random.random() < 0.6: deal(a, b, 10, t); b.root = max(b.root, t + (1.5 if AFTER else 2.5))
        if d <= 60 and a.ready("ULT", t, 0) and random.random() < p_hit(d, None, 4.5, vl):   # Mirror Cage
            a.use("ULT", t, 60, 0)
            if b.root > t or not escapes(b, t, 19, 0.7): deal(a, b, 72, t); b.root = max(b.root, t + (2.30 if AFTER else 3.13))
    elif e == "Pyro":
        if d <= 110 and a.ready("IM", t, 25): a.use("IM", t, 12, 25); a.immolate = 3
        if t - a.lasthit < 4 and d <= 120 and a.ready("DT", t, 20):          # Detonate, no line of sight needed
            a.use("DT", t, 14, 20); deal(a, b, 12 + P("DET_SCALE", 36) * min(1.0, (HP - b.hp) / HP / 0.75), t, far=far)
        if d <= 35 and a.ready("LS", t, 12):                                # Scorching Lash 12 + burn stack, 35 sweep
            a.use("LS", t, 5.22 if AFTER else 2.72, 12)                    # cooldown from the release (5, was 2.5) + crack
            if random.random() < 0.85:
                deal(a, b, 12, t); b.lash = [min(3, (b.lash[0] if b.lash[1] > t else 0) + 1), t + 5.0]
        if d <= 60 and a.ready("ULT", t, 0) and random.random() < 0.92:    # Ring of Fire r17.5, steered to 0.83 s
            a.use("ULT", t, 60, 0); deal(a, b, 55, t, far=far); b.burn = [3.0, t + 5.0]
    elif e == "Zephyr":
        dash = a.cap(t) >= DASH_MINCAP
        if 12 < d <= 42 and dash and a.ready("CS", t, 25) and role in ("rush", "stand"):   # Cross-Slash 12-40 (ASSUMED), 30
            a.use("CS", t, 10, 25)
            if rush: me = min(40.0, d - 3.5)
            if random.random() < p_hit(d, None, 4.5, vl): deal(a, b, 30, t)
        elif role == "kite" and d <= 10 and dash and a.ready("CS", t, 25): a.use("CS", t, 10, 25); me = -40.0
        if a.ready("SK", t, 51) and ((rush and d > 60) or (role == "kite" and d < 25)):   # Skyrider 3 s at boost (55, after 75)
            a.use("SK", t, 12, 51); me += ((75 if AFTER else 55) - CHAIN) * 3 * (1 if rush else -1)
        if d <= 70 and a.ready("ULT", t, 0):                                # Cyclone r26, 6 per 0.5 s, 4 s
            a.use("ULT", t, 60, 0)
            inside = 4.0 if b.cap(t) < 12 else min(4.0, react() + 26 / max(1.0, b.speed(t)))
            deal(a, b, 6 * int(inside / 0.5 + 1), t, far=far)
    elif e == "Terra":
        if 8 < d <= 30 and a.cap(t) >= DASH_MINCAP and a.ready("BC", t, 30) and role in ("rush", "stand"):   # Bulwark Charge 26 in 0.62, 35, DR 40%
            a.use("BC", t, 9, 30); a.dr, a.dr_until = 0.4, t + 0.62
            if rush: me = min(26.0, d - 3)
            if random.random() < p_hit(min(d, 26), None, 3.6, vl): deal(a, b, 35, t); b.intr = max(b.intr, t + 1.2)
        if d <= 24 and a.ready("AS", t, 20):                                # Aftershock r24, 20 + knock + 0.5 s interrupt
            a.use("AS", t, 12, 20)
            if random.random() < 0.7: deal(a, b, 20, t); b.intr = max(b.intr, t + 0.5); them -= 8.0
        if d > 15 and hpf < 0.6 and a.mana > 40 and a.ready("BW", t, 10): a.use("BW", t, 0.5, 50); a.wall = t + 2.0
        if d <= 40 and a.ready("ULT", t, 0):                                # Earthen Tomb 50 x 1.5, fissure 60 studs/s for 1.6 s
            v = b.speed(t, b.mode == "move") * 0.87
            if v < 1 or d / max(1e-3, 60 - min(59.9, v)) <= 1.6:
                a.use("ULT", t, 60, 0); deal(a, b, 75, t, far=far)
    elif e == "Voltaic":
        if rush and 8 < d <= 25 and a.cap(t) >= DASH_MINCAP and a.ready("OC", t, 18): a.use("OC", t, 9, 18); me = 11.0   # Overcharge 11 in 0.16
        if d <= 90 and a.ready("RS", t, 20):                                # Railspike 30, hitscan after 0.55 s
            a.use("RS", t, 10, 20)
            if random.random() < p_hit(d, None, BODY + 0.9, vl): deal(a, b, 30, t, "single", far)
        if d <= 60 and a.ready("VO", t, 20):                                # Volt Orb 28 -> 14 at 7.5, +8 direct, 48 studs/s
            a.use("VO", t, 12, 20)
            if random.random() < p_hit(d, 48, 7.5, vl): deal(a, b, 21 + (8 if random.random() < 0.2 else 0), t, far=far)
        if d <= 60 and a.ready("ULT", t, 0):                                # Cascade r11, 5 x 14 at 1.23-1.53 s (+0.5 windup)
            a.use("ULT", t, 60, 0)
            if b.cap(t) < 1: deal(a, b, 70, t, far=far)
            else:
                out = react() + 11 / max(1.0, b.speed(t)) * 0.7
                deal(a, b, 14 * sum(1 for s_ in (1.23, 1.30, 1.37, 1.47, 1.53) if s_ < out), t, far=far)
    elif e == "Umbra":
        if d <= 120 and b.mark is None and a.ready("MK", t, 18): a.use("MK", t, 14, 18); b.mark = t
        if rush and 25 < d <= 60 and a.ready("SS", t, 20): a.use("SS", t, 10, 20); me = 22.0      # Shadow Step 22, instant
        if role == "kite" and d <= 20 and a.ready("SS", t, 20): a.use("SS", t, 10, 20); me = -22.0
        if d <= 40 and a.ready("DD", t, 18): a.use("DD", t, 20, 18); a.decoy = t + 8
        if d <= 160 and a.ready("ULT", t, 0): a.use("ULT", t, 60, 0); a.eclipse = t + 8.0         # Eclipse 1 s + 7 s
    elif e == "Radiant":
        if hpf < 0.85 and a.ready("BL", t, 25): a.use("BL", t, 12, 25); a.shields.append([35.0, t + 8.0])
        if role == "kite" and hpf < 0.7 and d > 55 and a.ready("BN", t, 20): a.use("BN", t, 17, 20); a.channel = True; a.chan_t0 = t
        if a.channel:                                                       # Benediction 7.5 per 0.5 s, 10 mana/s, rooted
            if d < 35 or a.mana < 2 or a.hp >= HP or (AFTER and t - a.chan_t0 >= 8.0): a.channel = False   # after: 8 s cap
            else: a.hp = min(HP, a.hp + 15 * DT); a.mana -= 10 * DT; a.root = t + DT
        if d <= 60 and a.ready("ULT", t, 0): a.use("ULT", t, 60, 0); a.halo = (0.0, t + 6.9)      # Halo
    elif e == "Aqua":
        if 8 < d <= 36 and a.ready("UT", t, 25):                            # Undertow cone 35 deg to 36: pulls TARGET in
            a.use("UT", t, 9, 25)
            if random.random() < p_hit(d, None, d * math.tan(math.radians(17.5)), vl):
                them = d - 4.2; b.intr = max(b.intr, t + 0.5)
        tt_mana = 30 if AFTER else 40
        if d <= 40 and a.ready("TT", t, tt_mana):                           # Twin Tide: crush within 3.5 (after 5) of the seam at 1.1 s, 35
            a.use("TT", t, 16, tt_mana)
            if b.intr > t + 0.6 or b.root > t + 1.1 or not escapes(b, t, 5.0 if AFTER else 3.5, 1.1): deal(a, b, 35, t)
        sa_mana = 12 if AFTER else 18
        if d <= 60 and a.mana > 55 and a.ready("SA", t, sa_mana):           # Sidearm: 3 bullets of 8 (6 mana each, after 4), knock 38
            a.use("SA", t, 2.8, sa_mana)
            for _ in range(3):
                if random.random() < p_hit(d, 160, BODY + 0.5, vl):
                    deal(a, b, 8, t, "single", far)
                    if role == "kite": them -= 9.5
        if d <= 45 and a.ready("ULT", t, 0):                                # Leviathan's Maw r22 by 1.2 s, bite 65
            a.use("ULT", t, 60, 0)
            if b.intr > t + 0.8 or b.root > t + 1.2 or not escapes(b, t, 22 * random.uniform(0.4, 1.0), 1.2):
                deal(a, b, 65, t, far=far); b.root = max(b.root, t + 4.6)
    elif e == "Toxin":
        if d <= 60 and a.ready("CC", t, 25) and random.random() < 0.6:      # Corrosive Cloud r9, 6 dps, on a nearby bubble
            a.use("CC", t, 9, 25)
            stay = 6.0 if b.cap(t) < 1 else min(6.0, react() + 9 / max(1.0, b.speed(t)))
            deal(a, b, 6 * stay, t, far=far); b.poison = [PTICK * (1 + 0.12 * b.corrode[0]), t + 5.0]
        if d <= 50 and a.ready("AR", t, 30):                                # Acid Rain r10 after 0.7 s, 4/s (after 6/s), Corroded
            a.use("AR", t, 14, 30)
            stay = 4.0 if b.cap(t) < 1 else min(4.0, max(0.0, react() + 10 / max(1.0, b.speed(t)) - 0.7))
            deal(a, b, (6 if AFTER else 4) * int(stay), t, far=far); b.corrode = [min(4, int(stay)), t + 6.0]
        if AFTER and (a.burn[1] > t or a.lash[1] > t or a.poison[1] > t) and a.ready("AV", t, 20):
            a.use("AV", t, 16, 20); a.vent = t + 6.0                        # after: Antitoxin Vent, DoTs 30% lighter for 6 s
        if d <= 60 and a.ready("ULT", t, 0) and random.random() < p_hit(d, None, 7, vl):   # Patient Zero
            a.use("ULT", t, 60, 0)
            stay = 5.0 if b.cap(t) < 1 else min(5.0, react() + 20 / max(1.0, b.speed(t)))
            deal(a, b, 18 + 8 * stay, t, far=far)
    return me, them

def defend(x, t):
    """TTK target: strafes, uses only its defensive kit"""
    hpf = x.hp / HP
    if x.el == "Radiant" and hpf < 0.85 and x.ready("BL", t, 25): x.use("BL", t, 12, 25); x.shields.append([35.0, t + 8.0])
    if x.el == "Umbra" and x.ready("DD", t, 18): x.use("DD", t, 20, 18); x.decoy = t + 8
    if x.el == "Terra" and hpf < 0.7 and x.mana > 40 and x.ready("BW", t, 10): x.use("BW", t, 0.5, 50); x.wall = t + 2.0
    if AFTER and x.el == "Toxin" and (x.burn[1] > t or x.lash[1] > t or x.poison[1] > t) and x.ready("AV", t, 20):
        x.use("AV", t, 16, 20); x.vent = t + 6.0

def dots(f, t, enemy):
    if f.burn[1] > t: deal(enemy, f, f.burn[0] * DT, t, "dot")
    if f.lash[1] > t and f.lash[0] > 0: deal(enemy, f, (2.0 if AFTER else 3.2) * f.lash[0] * DT, t, "dot")   # 1.6 (after 1.0) per stack per 0.5 s
    if f.poison[1] > t:
        dmg = deal(enemy, f, f.poison[0] * DT, t, "dot")
        if enemy.el == "Toxin": enemy.hp = min(HP, enemy.hp + 0.3 * dmg)                     # Symbiosis
    f.mana = min(MANA, f.mana + REGEN * DT)

ELS = ["Aqua", "Cryo", "Pyro", "Radiant", "Terra", "Toxin", "Umbra", "Voltaic", "Zephyr"]
CLOSE = {"Cryo": 12, "Pyro": 20, "Zephyr": 10, "Terra": 15, "Voltaic": 18, "Umbra": 30, "Radiant": 25, "Aqua": 15, "Toxin": 15}
LONG = {"Cryo": 110, "Pyro": 100, "Zephyr": 75, "Terra": 110, "Voltaic": 85, "Umbra": 150, "Radiant": 58, "Aqua": 65, "Toxin": 110}   # Aqua: inside Riptide's 70 (it sat at 100 and could not shoot)
LONG["Aqua"] = P("RIP_RANGE", 70) - 5

def move(x, y, role, t):
    d = dist(x, y)
    v = x.speed(t, x.mode == "move") * 0.87          # 13% of the speed is spent weaving
    if v <= 0 or role in ("stand", "def"): return
    u = [(y.pos[0] - x.pos[0]) / max(d, 1e-6), (y.pos[1] - x.pos[1]) / max(d, 1e-6)]
    want = CLOSE[x.el] if role == "rush" else LONG[x.el]
    sgn = 1 if d > want + 3 else (-1 if d < want - 3 else 0)
    if sgn == 0: return
    step = [u[0] * v * DT * sgn, u[1] * v * DT * sgn]
    nx, ny = x.pos[0] + step[0], x.pos[1] + step[1]
    r = math.hypot(nx, ny)
    if r > ARENA_R:                                     # at the edge: keep only the tangential part (circle the arena)
        rad = [nx / r, ny / r]; dot = step[0] * rad[0] + step[1] * rad[1]
        tan = [step[0] - dot * rad[0], step[1] - dot * rad[1]]; tl = math.hypot(*tan) or 1e-6
        nx, ny = x.pos[0] + tan[0] / tl * v * DT, x.pos[1] + tan[1] / tl * v * DT
        r2 = math.hypot(nx, ny)
        if r2 > ARENA_R: nx, ny = nx / r2 * ARENA_R, ny / r2 * ARENA_R
    x.pos = [nx, ny]

def shove(x, y, studs):
    d = dist(x, y)
    u = [(y.pos[0] - x.pos[0]) / max(d, 1e-6), (y.pos[1] - x.pos[1]) / max(d, 1e-6)]
    x.pos = [x.pos[0] + u[0] * studs, x.pos[1] + u[1] * studs]
    r = math.hypot(*x.pos)
    if r > ARENA_R: x.pos = [x.pos[0] / r * ARENA_R, x.pos[1] / r * ARENA_R]

def duel(ea, eb, ra, rb, tmax=None, fixed_d=None):
    tmax = TMAX if tmax is None else tmax
    a = F(ea, (-START_D / 2, 0)); b = F(eb, (START_D / 2, 0))
    if fixed_d is not None: a.pos, b.pos = [0.0, 0.0], [float(fixed_d), 0.0]
    t, contact = 0.0, None
    while t < tmax:
        pair = [(a, b, ra), (b, a, rb)]
        random.shuffle(pair)
        for x, y, r in pair:
            d = dist(x, y)
            CUR["vs"], CUR["vv"] = x.vlat(t), y.vvert(t)      # this shooter moves too; the target jumps
            if r == "def": x.mode = "fight"; defend(x, t)
            else:
                x.mode = "fight" if r == "stand" or abs(d - (CLOSE[x.el] if r == "rush" else LONG[x.el])) <= 6 else "move"
                me, them = abilities(x, y, d, t, r)
                if fixed_d is None:
                    if me: shove(x, y, me)
                    if them: shove(y, x, them)
                m1(x, y, dist(x, y), t)
            dots(x, t, y)
        if fixed_d is None:
            move(a, b, ra, t); move(b, a, rb, t)
            if contact is None and dist(a, b) <= CLOSE[a.el] + 6: contact = t
        if a.hp <= 0 or b.hp <= 0: break
        t += DT
    return a, b, t, contact

if __name__ == "__main__":
    N = int(sys.argv[1]) if len(sys.argv) > 1 else 40
    here = os.path.dirname(os.path.abspath(__file__))
    res = {"ttk": {}, "rush": {}, "contact": {}, "kiterfar": {}}
    for ea in ELS:                      # (a) attacker (row) at its best range vs a strafing, defending target (column)
        for eb in ELS:
            best = None
            for d in (8, 20, 45, 90):
                ts = [(lambda r: r[2] if r[1].hp <= 0 else 60.0)(duel(ea, eb, "stand", "def", 60, d)) for _ in range(max(10, N // 4))]
                m = sum(ts) / len(ts)
                if best is None or m < best[0]: best = (round(m, 1), d)
            res["ttk"][ea + ">" + eb] = best
    for ea in ELS:                      # (b) rusher (row) vs kiter (column)
        for eb in ELS:
            w, cts, far = 0.0, [], []
            for _ in range(N):
                a, b, t, c = duel(ea, eb, "rush", "kite")
                if b.hp <= 0 and a.hp > 0: w += 1
                elif a.hp > 0 and b.hp > 0: w += 0.5 if a.hp == b.hp else (1 if a.hp > b.hp else 0)
                cts.append(c if c is not None and c < 60 else 60.0); far.append(b.dealt_far)   # 60 = never, as before
            res["rush"][ea + ">" + eb] = round(w / N, 2)
            res["contact"][ea + ">" + eb] = round(sum(cts) / N, 1)
            res["kiterfar"][ea + ">" + eb] = round(sum(far) / N, 1)
    if os.environ.get("SIM_FULL"):      # (c) the other two pairings of approach, then best play by both
        def score(a, b):
            if b.hp <= 0 and a.hp > 0: return 1.0
            if a.hp <= 0 and b.hp > 0: return 0.0
            if a.hp > 0 and b.hp > 0: return 0.5 if a.hp == b.hp else (1.0 if a.hp > b.hp else 0.0)
            return 0.5                                          # both down in the same tick
        res["rr"], res["kk"], res["eq"], res["mix"] = {}, {}, {}, {}
        for ea in ELS:
            for eb in ELS:
                res["rr"][ea + ">" + eb] = round(sum(score(*duel(ea, eb, "rush", "rush")[:2]) for _ in range(N)) / N, 3)
                res["kk"][ea + ">" + eb] = round(sum(score(*duel(ea, eb, "kite", "kite")[:2]) for _ in range(N)) / N, 3)
        for ea in ELS:                  # a 2 x 2 zero-sum game per pairing: rows = A rushes / kites, columns = B rushes / kites
            for eb in ELS:
                k = ea + ">" + eb
                a_, b_ = res["rr"][k], res["rush"][k]
                c_, d_ = 1 - res["rush"][eb + ">" + ea], res["kk"][k]
                rows, cols = [min(a_, b_), min(c_, d_)], [max(a_, c_), max(b_, d_)]
                lo, hi = max(rows), min(cols)
                if lo >= hi - 1e-9:                             # a saddle: one pure approach each
                    v, p, q = lo, (1.0 if rows[0] >= rows[1] else 0.0), (1.0 if cols[0] <= cols[1] else 0.0)
                else:
                    den = a_ + d_ - b_ - c_
                    v, p, q = (a_ * d_ - b_ * c_) / den, (d_ - c_) / den, (d_ - b_) / den
                res["eq"][k] = round(v, 3)
                res["mix"][k] = [round(p, 2), round(q, 2)]       # how often each side should rush, under best play
    json.dump(res, open(os.path.join(here, f"sim_results_{TAG}.json"), "w"), indent=0)
    def grid(key, fmt):
        rows = ["| | " + " | ".join(ELS) + " | mean |", "|" + "---|" * (len(ELS) + 2)]
        for ea in ELS:
            vals = [res[key][ea + ">" + eb] for eb in ELS]
            nums = [v[0] if isinstance(v, (list, tuple)) else v for v in vals]
            rows.append("| **" + ea + "** | " + " | ".join(fmt(v) for v in vals) + " | " + fmt(sum(nums) / len(nums)) + " |")
        return "\n".join(rows)
    with open(os.path.join(here, f"tables_{TAG}.md"), "w") as f:
        f.write("## TTK (s), attacker row vs target column, attacker at its best range [range]\n\n")
        f.write(grid("ttk", lambda v: (f"{v[0]:.1f} [{v[1]}]" if isinstance(v, (list, tuple)) else f"{v:.1f}")) + "\n\n")
        f.write("## Rusher (row) win rate vs kiter (column)\n\n" + grid("rush", lambda v: f"{v:.2f}") + "\n\n")
        f.write("## Mean time until the rusher reaches its fighting range (s; 60 = never)\n\n" + grid("contact", lambda v: f"{v:.1f}") + "\n\n")
        f.write("## Damage the kiter dealt from beyond 40 studs\n\n" + grid("kiterfar", lambda v: f"{v:.0f}") + "\n")
    print("pass", PASS, "tag", TAG, "overrides", OV, "done")
