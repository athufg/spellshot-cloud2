"""SPELLSHOT 3v3 team-fight sim (2026-10-17), built for the owner's 3v3 prompt.

Datasets:
  P = the numbers in the prompt (the 16 Oct kit), completed with the brief's shared stats where the prompt is silent
      (2x hitboxes, M1 projectiles at 200 studs/s). Boulder keeps the prompt's 108 / 86.
  L = the live kit of 17 Oct (CHANGES_2026-10-17_balance_pass.md, hitbox 2x, one M1 projectile speed).
Movement is running only (25 studs/s); kit dashes, blinks and Skyrider stay. Variant A: no jump. Variant B: jump + double jump.
The aim model is the 1v1 sim's (1 deg spread, 40 ms tracking, 45% of lead unpredictable, own-motion jitter, reaction
0.15-0.45 s). Team-only additions, all assumptions: a telegraph is noticed 80% of the time (attention is split three
ways), teams spawn 150 apart on an open 280 x 180 floor with no cover but Bulwark Wall, and a round is the Duel round
(first team wiped, or the 90 s clock: larger share of team health wins)."""
import math, random, os

DT = 0.05
RUN = 25.0
SIG_ANG, TRACK, LEAD_K, SELF_ANG = 0.018, 0.04, 0.45, 0.009
HITBOX = 2.0
BODY, BODY_H = 1.1 * HITBOX, 2.6 * HITBOX
REACT = (0.15, 0.45)
AWARE = 0.8
FIGHT_LAT = 25.0
TMAX = 90.0
AX, AY = 140.0, 90.0
SPAWN_X = 75.0
MANA, REGEN = 100.0, 7.0
ULT_DMG, ULT_CAST = 1 / 260.0, 0.06
HEADSHOT = 0.25
PROJ = 200.0
RX_OFF = bool(os.environ.get("SIM_RX_OFF"))
NO_PATIENCE = bool(os.environ.get("SIM_NO_PATIENCE"))
# what-if knobs for the recommendations (defaults = the dataset)
HP_MULT = float(os.environ.get("SIM_HP_MULT", "1"))
FB_SPLASH = float(os.environ.get("SIM_FB_SPLASH", "9")); FB_SPLASH_R = float(os.environ.get("SIM_FB_SPLASH_R", "6"))
FB_DIRECT = float(os.environ.get("SIM_FB_DIRECT", "18")); FB_RATE = float(os.environ.get("SIM_FB_RATE", "0.6"))
CB_RANGE = float(os.environ.get("SIM_CB_RANGE", "30"))
BN_HEAL = float(os.environ.get("SIM_BN_HEAL", "15")); BN_R = float(os.environ.get("SIM_BN_R", "25"))
BN_ROOT = os.environ.get("SIM_BN_ROOT", "1") == "1"
import json as _json
HP_TABLE = _json.loads(os.environ["SIM_HP_TABLE"]) if os.environ.get("SIM_HP_TABLE") else None   # team-mode HP per Element
ULT_SCALE = float(os.environ.get("SIM_ULT_SCALE", "1"))          # Ultimate charge per point of damage, x
BL_SHIELD = float(os.environ.get("SIM_BL_SHIELD", "35")); BL_CD = float(os.environ.get("SIM_BL_CD", "12"))
BN_MAX = float(os.environ["SIM_BN_MAX"]) if os.environ.get("SIM_BN_MAX") else None; BN_CD = float(os.environ.get("SIM_BN_CD", "17"))
LANCE_HEAL = float(os.environ.get("SIM_LANCE_HEAL", "0"))        # Light Lance on a hurt ally heals up to this many HP/s
BW_HP = float(os.environ.get("SIM_BW_HP", "200")); BW_DRAIN = float(os.environ.get("SIM_BW_DRAIN", "20"))
BW_SHADOW = float(os.environ.get("SIM_BW_SHADOW", "6")); BW_HOLD = float(os.environ.get("SIM_BW_HOLD", "2.5")); BW_GAP = float(os.environ.get("SIM_BW_GAP", "2"))
SKY = tuple(float(x) for x in os.environ["SIM_SKY"].split(",")) if os.environ.get("SIM_SKY") else None
TEAMPLAY = os.environ.get("SIM_TEAMPLAY") == "1"
BW_EAGER = os.environ.get("SIM_BW_EAGER") == "1"                # Terra walls whenever the team near it is taking fire
RIP_DMG = float(os.environ.get("SIM_RIP_DMG", "12")); DART_DMG = float(os.environ.get("SIM_DART_DMG", "65"))
VOLT_SD = os.environ.get("SIM_VOLT_SD", "")       # P27 Static Discharge: "reactive" (once a life under 30% HP) or "manual" (12 s)
CB_DMG = float(os.environ.get("SIM_CB_DMG", "8"))  # handoff C: Chain Bolt damage per bolt (live 8)
UMBRA_EXIT = float(os.environ.get("SIM_UMBRA_EXIT", "0"))   # handoff D: a separate escape blink on its own cooldown (0 = none)
SD_R = float(os.environ.get("SIM_SD_R", "8")); SD_PUSH = float(os.environ.get("SIM_SD_PUSH", "10")); SD_BURST = float(os.environ.get("SIM_SD_BURST", "1.5"))
SD_DUR = float(os.environ.get("SIM_SD_DUR", "0.5")); SD_CD = float(os.environ.get("SIM_SD_CD", "12")); VANISH = float(os.environ.get("SIM_VANISH", "0.3"))
UMBRA_DIVE = os.environ.get("SIM_UMBRA_DIVE") == "1"  # P27 test: Umbra blinks in on a low target, then out
UMBRA_SS = os.environ.get("SIM_UMBRA_SS", "")     # P27 Shadow Step: "dive" (half cooldown within 2 s of a hit) or "vanish" (0.3 s untargetable)
# P29 step 0: live, Blizzard is a storm where Cryo stands and Deep Freeze a trap at Cryo's feet (the sim used to aim both)
CRYO_LIVE = os.environ.get("SIM_CRYO_LIVE") == "1"
# fact-check robustness: Flash Freeze's live timing (front eases out over 1 s; a touched body is slowed to 5 and only
# rooted after 1 s inside, so ~5 studs from the edge still get out; the root lasts to the zone's end, lead + 1 + 3.5,
# then the 34 shatter) and Blizzard's live 6 s (the sim's storm slowed 0.6 s longer)
CRYO_EXACT = os.environ.get("SIM_CRYO_EXACT") == "1"
# P29 cursor-targeting: a cast range > 0 lands the ability at the cursor, up to that far out; 0 = where the caster stands
FF_RANGE = float(os.environ.get("SIM_FF_RANGE", "0")); FF_R = float(os.environ.get("SIM_FF_R", "20"))
FF_LEAD = float(os.environ.get("SIM_FF_LEAD", "0.38")); FF_FREEZE = float(os.environ.get("SIM_FF_FREEZE", "4.0"))
BZ_RANGE = float(os.environ.get("SIM_BZ_RANGE", "0")); BZ_R = float(os.environ.get("SIM_BZ_R", "32"))
BZ_DUR = float(os.environ["SIM_BZ_DUR"]) if os.environ.get("SIM_BZ_DUR") else None
DF_RANGE = float(os.environ.get("SIM_DF_RANGE", "0")); AS_RANGE = float(os.environ.get("SIM_AS_RANGE", "0"))
BN_RANGE = float(os.environ.get("SIM_BN_RANGE", "0"))
# P28: Twin Tide's walls also block shots. "a" the wall facing the enemy (HP pool TT_HP), "b" both walls (TT_HP each),
# "c" like a but only for allies, never Aqua herself. TT_HOLD: extra seconds the met walls stand (0 = live: up ~0.94 s)
TT_WALL = os.environ.get("SIM_TT_WALL", ""); TT_HP = float(os.environ.get("SIM_TT_HP", "200"))
TT_HOLD = float(os.environ.get("SIM_TT_HOLD", "0"))
                # "cover each other": stick to the tank, turn on divers   # step 8: cast a reacting Technique on cooldown, no waiting   # like the live ReactionsOff switch: no reaction ever fires
EXPOSE = 1.0          # 1 = open floor (the default). The cover sensitivity sets 0.6: 40% of aimed shots meet cover

DATA = {
    "P": dict(chill3="root", boulder_v=86.0, fb_range=110.0, sa_mana=6.0, tt_mana=40.0, tt_seam=3.5, bz_cap=14.0,
              bz_dur=8.0, df_root=2.5, mc_root=3.13, ben_max=30.0, ls_cd=2.72, ls_dps=3.2, ptick=4.0, ar_tick=4.0,
              sky=(42.0, 55.0), ch_alone=0.0, ember="kill", chainrx="kill", vent_dr=0.0, dash_min=12.0),
    "L": dict(chill3="cap", boulder_v=200.0, fb_range=160.0, sa_mana=4.0, tt_mana=30.0, tt_seam=5.0, bz_cap=11.0,
              bz_dur=6.0, df_root=1.5, mc_root=2.30, ben_max=8.0, ls_cd=5.22, ls_dps=2.0, ptick=6.0, ar_tick=6.0,
              sky=(60.0, 75.0), ch_alone=7.0, ember="low30", chainrx="maxstack", vent_dr=0.30, dash_min=16.0),
}
HP2 = {"Terra": 230, "Radiant": 150, "Cryo": 150, "Pyro": 160, "Toxin": 160, "Aqua": 160, "Umbra": 120, "Voltaic": 120,
       "Zephyr": 150}
ROLE = {"Terra": "tank", "Radiant": "support", "Cryo": "support", "Pyro": "dps", "Toxin": "dps", "Aqua": "dps",
        "Umbra": "flank", "Voltaic": "flank", "Zephyr": "disrupt"}
ELS = ["Aqua", "Cryo", "Pyro", "Radiant", "Terra", "Toxin", "Umbra", "Voltaic", "Zephyr"]
TECH = {"Aqua": ("TT", "SA"), "Cryo": ("BZ", "DF"), "Pyro": ("DT", "LS"), "Radiant": ("PT", "BN"), "Terra": ("AS", "BW"),
        "Toxin": ("AV", "AR"), "Umbra": ("MK", "DD"), "Voltaic": ("RS", "VO"), "Zephyr": ("SK", "GP")}
HOME = {"TT": "Aqua", "SA": "Aqua", "BZ": "Cryo", "DF": "Cryo", "DT": "Pyro", "LS": "Pyro", "PT": "Radiant",
        "BN": "Radiant", "AS": "Terra", "BW": "Terra", "AV": "Toxin", "AR": "Toxin", "MK": "Umbra", "DD": "Umbra",
        "RS": "Voltaic", "VO": "Voltaic", "SK": "Zephyr", "GP": "Zephyr"}
RULES = {"Pyro": (("root", "Melt"), ("chill", "Melt"), ("charged", "Overload"), ("poison", "Combustion")),
         "Cryo": (("burn", "Melt"),),
         "Voltaic": (("root", "Shatter"), ("burn", "Overload")),
         "Toxin": (("burn", "Combustion"),),
         "Aqua": (("chill", "Frozen"),),
         "Zephyr": (("burn", "Wildfire"), ("chill", "Windchill"), ("charged", "StormSurge"))}
RX_CD = {"Melt": 0.75, "Combustion": 0.75, "Overload": 0.75, "Shatter": 0.75, "Frozen": 6.0, "Wildfire": 2.0,
         "Windchill": 2.0, "StormSurge": 2.0}
M1RANGE = {"Aqua": 70, "Cryo": 120, "Pyro": 110, "Radiant": 60, "Terra": 120, "Toxin": 120, "Umbra": 160, "Voltaic": 30,
           "Zephyr": 80}
BAND = {"Aqua": (25, 45), "Cryo": (40, 65), "Pyro": (25, 45), "Radiant": (30, 50), "Terra": (14, 28),
        "Toxin": (35, 55), "Umbra": (70, 110), "Voltaic": (12, 24), "Zephyr": (22, 42)}
LEASH = {"Umbra": 75.0}
if os.environ.get("SIM_CB_RANGE"):                     # a longer Chain Bolt fights from further out
    M1RANGE["Voltaic"] = float(os.environ["SIM_CB_RANGE"]); BAND["Voltaic"] = (0.4 * M1RANGE["Voltaic"], 0.8 * M1RANGE["Voltaic"])
if os.environ.get("SIM_OVERLOAD_CD"): RX_CD["Overload"] = float(os.environ["SIM_OVERLOAD_CD"])


def p_hit(d, vp, w, vlat, vs, vv):
    """Chance one shot touches the body (the 1v1 sim's model): sideways spread, own motion, lead and tracking on the
    relative motion; up and down the same for the target's jumps. Both have to land."""
    tf = 0.0 if vp is None else d / vp
    s = math.sqrt((SIG_ANG * d) ** 2 + (SELF_ANG * d * vs / 25.0) ** 2 + (LEAD_K * vlat * tf) ** 2
                  + (math.hypot(vlat, vs) * TRACK) ** 2) + 1e-6
    sv = math.sqrt((SIG_ANG * d) ** 2 + (LEAD_K * vv * tf) ** 2 + (vv * TRACK) ** 2) + 1e-6
    wv = BODY_H + max(0.0, w - BODY)
    return math.erf(w / (1.41421356 * s)) * math.erf(wv / (1.41421356 * sv))


def p_off(d, vp, w, off, vlat, vs, vv):
    """Same shot, a body `off` studs to the side of the aim line (pierce, chains of bodies)."""
    if off <= 0.01: return p_hit(d, vp, w, vlat, vs, vv)
    tf = 0.0 if vp is None else d / vp
    s = math.sqrt((SIG_ANG * d) ** 2 + (SELF_ANG * d * vs / 25.0) ** 2 + (LEAD_K * vlat * tf) ** 2
                  + (math.hypot(vlat, vs) * TRACK) ** 2) + 1e-6
    a = 0.5 * (math.erf((w - off) / (1.41421356 * s)) - math.erf((-w - off) / (1.41421356 * s)))
    return max(0.0, a) * (p_hit(d, vp, w, vlat, vs, vv) / max(1e-6, math.erf(w / (1.41421356 * s))))


class Zone:
    __slots__ = ("kind", "owner", "team", "x", "y", "r", "t0", "until", "next", "grown", "armed")

    def __init__(s, kind, owner, x, y, r, t0, until):
        s.kind, s.owner, s.team, s.x, s.y, s.r, s.t0, s.until = kind, owner, owner.team, x, y, r, t0, until
        s.next, s.grown, s.armed = t0, False, t0


class Pl:
    def __init__(s, w, el, team, i, x, y, tech):
        s.w, s.el, s.team, s.i = w, el, team, i
        s.role = ROLE[el]
        s.maxhp = float(HP_TABLE[el]) if HP_TABLE else float(HP2[el] if w.hp_pass == 2 else 150) * HP_MULT
        s.hp, s.mana = s.maxhp, MANA
        s.x, s.y = x, y
        s.alive = True
        s.tech = tech
        s.cd = {}
        s.next_m1 = 0.0; s.busy = 0.0; s.hold = None; s.hold_t0 = 0.0; s.hold_aux = 0.0
        s.mode = "move"; s.tgt = None; s.mtgt = None
        s.caps = []
        s.root = s.trap = s.stagger = s.nocast = s.air = 0.0
        s.burn = [0.0, 0.0, None]; s.lash = [0, 0.0, None]; s.poison = [0.0, 0.0, None]; s.corrode = [0, 0.0]
        s.chill = [0, 0.0]; s.chill_imm = 0.0; s.charged = [0, 0.0, None]; s.df_imm = 0.0
        s.shields = []
        s.wall_hp = 0.0
        s.decoy = s.eclipse = s.vent = s.sky = s.prime = s.cold = s.current = s.slip = 0.0
        s.halo = [0.0, 0.0]
        s.dr = 0.0; s.dr_until = 0.0
        s.boulder_t = 0.0; s.lance_t = 0.0; s.immolate = 0
        s.mark = None
        s.lasttgt = None; s.lasthit_t = -9.0
        s.ult = 0.0; s.ult_t = None
        s.dmg_in = 0.0
        s.rx_cd = {}
        s.last_src = None; s.last_abil = None
        s.dead_t = None
        s.dmg_by = {}
        s.lance_ally = None
        s.sd_used = False; s.burst = 0.0; s.disengage = 0.0; s.untarget = 0.0
        s.diving = 0.0; s.ss_cast_t = -9.0; s.ss_halved = False
        s.cin = {}; s.bn_c = None


def dist(a, b): return math.hypot(a.x - b.x, a.y - b.y)


def distp(a, x, y): return math.hypot(a.x - x, a.y - y)


class World:
    def __init__(s, comp_a, comp_b, ds, hp_pass, jump, policy, rng, tech_a=None, tech_b=None):
        s.D = dict(DATA[ds], **({"sky": SKY} if SKY else {}), **({"ben_max": BN_MAX} if BN_MAX else {})); s.ds = ds; s.hp_pass = hp_pass; s.jump = jump; s.policy = policy; s.rng = rng
        s.t = 0.0
        s.zones = []; s.events = []
        s.st = {"dmg": {}, "mana": {}, "casts": {}, "lasthit": {}, "rx": {}, "rxdmg": {}, "heal": {}, "absorb": {},
                "peel": {}, "peel_ok": {}, "full": {}, "dry": {}, "ult_t": {}, "ult_cast": {}, "kills": {}, "alive": {}, "ks_sum": {}, "ks_n": {},
                "deaths": {}, "death_t": {}, "contact": {}}
        s.peel_checks = []
        s.ttw = []; s.cev = []
        s.teams = [[], []]
        s.focus = [None, None]; s.next_focus = 0.0
        flip = rng.random() < 0.5
        for side, comp, techs in ((0, comp_a, tech_a), (1, comp_b, tech_b)):
            sx = (-SPAWN_X if (side == 0) != flip else SPAWN_X)
            for i, el in enumerate(comp):
                y = (-12.0, 0.0, 12.0)[i] + rng.uniform(-2, 2)
                if el == "Umbra": y *= 2.5
                tech = techs[i] if techs else TECH[el]
                s.teams[side].append(Pl(s, el, side, i, sx + rng.uniform(-3, 3), y, tech))
        s.all = s.teams[0] + s.teams[1]

    # ------------------------------------------------------------------ helpers
    def add(s, key, k, v=1.0):
        d = s.st[key]; d[k] = d.get(k, 0.0) + v

    def enemies(s, p): return [q for q in s.teams[1 - p.team] if q.alive and q.untarget <= s.t]   # untargetable = not there

    def allies(s, p, self_too=False): return [q for q in s.teams[p.team] if q.alive and (self_too or q is not p)]

    def react_t(s): return s.rng.uniform(*REACT)

    def speed(s, q):
        t = s.t
        if q.root > t or q.trap > t or q.stagger > t or q.slip > t or (q.hold == "BN" and BN_ROOT): return 0.0
        base = RUN
        if q.burst > t: base *= SD_BURST
        if q.el == "Cryo" and q.cold > t: base *= 1.10
        if q.el == "Aqua" and q.current > t and q.mode == "move": base *= 1.25
        c = 999.0
        for cap in q.caps:
            if cap[1] > t and cap[0] < c: c = cap[0]
        return min(base, c)

    def capnow(s, q):
        t = s.t
        if q.root > t or q.trap > t: return 0.0
        c = 999.0
        for cap in q.caps:
            if cap[1] > t and cap[0] < c: c = cap[0]
        return c

    def vlat(s, q):
        t = s.t
        if q.root > t or q.trap > t or q.stagger > t or (q.hold == "BN" and BN_ROOT): return 0.0
        if q.air > t: return 6.0
        if q.sky > t: return 0.6 * s.D["sky"][1]
        sp = s.speed(q)
        return min(sp, FIGHT_LAT) if q.mode == "fight" else 0.5 * sp

    def vvert(s, q):
        t = s.t
        if q.air > t: return 0.0
        if q.sky > t: return 8.0
        if not s.jump or q.root > t or q.trap > t or q.stagger > t or (q.hold == "BN" and BN_ROOT): return 0.0
        return 6.0 * min(1.0, s.speed(q) / 25.0)

    def aim(s, p, q, d, vp, w, cover=True):
        if cover and EXPOSE < 1.0 and s.rng.random() > EXPOSE: return False   # cover sensitivity only: the shot is blocked
        return s.rng.random() < p_hit(d, vp, w, s.vlat(q), s.vlat(p), s.vvert(q))

    def updraft(s, p):
        if p.sky > s.t or p.air > s.t: return 1.25
        return 1.0875 if s.jump else 1.0

    def unseen(s, p, q):
        if p.eclipse > s.t: return True
        f = q.tgt
        if f is None or f is p or not f.alive: return False
        fx, fy = f.x - q.x, f.y - q.y
        ux, uy = p.x - q.x, p.y - q.y
        n = math.hypot(fx, fy) * math.hypot(ux, uy)
        if n < 1e-6: return False
        return (fx * ux + fy * uy) / n < 0.5          # more than 60 degrees off its facing

    def escape(s, e, need, window, jump_p=0.0):
        t = s.t
        if e.untarget > t: return True
        if e.root > t or e.trap > t or e.stagger > t or e.air > t or (e.hold == "BN" and BN_ROOT): return False
        if s.rng.random() > AWARE: return False
        if s.jump and jump_p > 0 and s.rng.random() < jump_p: return True
        return s.speed(e) * max(0.0, window - s.react_t()) >= need

    def push(s, q, fx, fy, studs):
        dx, dy = q.x - fx, q.y - fy
        n = math.hypot(dx, dy) or 1.0
        q.x = max(-AX, min(AX, q.x + dx / n * studs)); q.y = max(-AY, min(AY, q.y + dy / n * studs))

    def pull_to(s, q, x, y, keep):
        dx, dy = q.x - x, q.y - y
        n = math.hypot(dx, dy)
        if n > keep: q.x, q.y = x + dx / n * keep, y + dy / n * keep

    def in_cloud(s, q, team_of_owner=None):
        for z in s.zones:
            if z.kind in ("cloud", "pz") and z.until > s.t and distp(q, z.x, z.y) <= z.r:
                if team_of_owner is None or z.team == team_of_owner: return z
        return None

    # ------------------------------------------------------------------ status
    def has(s, q, k):
        t = s.t
        if k == "burn": return q.burn[1] > t or (q.lash[0] > 0 and q.lash[1] > t)
        if k == "chill": return q.chill[0] > 0 and q.chill[1] > t
        if k == "root": return q.root > t
        if k == "charged": return q.charged[0] > 0 and q.charged[1] > t
        if k == "poison": return q.poison[1] > t
        return False

    def consume(s, q, k):
        if k == "burn": q.burn = [0.0, 0.0, None]; q.lash = [0, 0.0, None]
        elif k == "chill":
            q.chill = [0, 0.0]; q.caps = [c for c in q.caps if c[2] != "chill"]
        elif k == "root": q.root = s.t
        elif k == "charged": q.charged = [0, 0.0, None]
        elif k == "poison": q.poison = [0.0, 0.0, None]

    def add_chill(s, src, q):
        t = s.t
        if q.chill_imm > t: return
        n = q.chill[0] + 1 if q.chill[1] > t else 1
        if n >= 3 and s.D["chill3"] == "root":          # prompt: the 3rd stack roots 0.8 s, then 1.2 s immune
            q.chill = [0, 0.0]; q.caps = [c for c in q.caps if c[2] != "chill"]
            q.root = max(q.root, t + 0.8); q.chill_imm = t + 2.0
            return
        q.chill = [min(n, 3), t + 5.0]
        q.caps.append([(22.0, 15.0, 10.0)[min(n, 3) - 1], t + 5.0, "chill"])
        if n >= 3: q.chill_imm = t + 6.2                  # live: the 3rd holds 10 for its window, then 1.2 s

    def add_charged(s, src, q, owner=None):
        t = s.t
        n = q.charged[0] + 1 if q.charged[1] > t else 1
        own = owner or src
        q.charged = [n, t + 5.0, own]
        if n >= 4:
            q.charged = [0, 0.0, None]
            if s.D["ch_alone"] > 0: s.deal(own, q, s.D["ch_alone"], "ChargedPop", "Voltaic", "status")
            if s.D["chainrx"] == "maxstack" and own.el == "Voltaic" and own.cd.get("OC", -1) > t:
                own.cd["OC"] = max(t, own.cd["OC"] - 2.0)

    def add_lash(s, src, q):
        t = s.t
        n = min(3, (q.lash[0] if q.lash[1] > t else 0) + 1)
        q.lash = [n, t + 5.0, src]

    def add_burn(s, src, q, dps, dur):
        t = s.t
        if q.burn[1] > t and q.burn[0] >= dps: q.burn[1] = max(q.burn[1], t + dur); return
        q.burn = [dps, t + dur, src]

    # ------------------------------------------------------------------ damage
    def deal(s, src, q, amt, abil, elem, kind="hit"):
        """kind: hit (can react), dot, rx (reaction damage), chain, status. Returns damage dealt."""
        t = s.t
        if amt <= 0 or not q.alive: return 0.0
        if q.untarget > t and kind != "dot": return 0.0           # P27 vanish window
        if kind in ("hit", "chain"):
            if src.el == "Zephyr" and elem == "Zephyr": amt *= s.updraft(src)
            if src.el == "Umbra" and elem == "Umbra" and s.unseen(src, q): amt *= 1.25
        if q.el == "Terra" and q.boulder_t > 0: amt *= 0.80
        if q.dr_until > t: amt *= (1 - q.dr)
        if kind == "dot" and q.vent > t: amt *= (1 - s.D["vent_dr"])
        left = amt
        for sh in q.shields:
            if sh[1] > t and sh[0] > 0 and left > 0:
                take = min(sh[0], left); sh[0] -= take; left -= take
                s.add("absorb", (sh[2].team, sh[2].el, "BL"), take)
        before = q.hp
        q.hp -= left
        eff = (amt - left) + min(left, max(0.0, before))      # health and shield actually removed (no overkill)
        if src is not q:
            s.add("dmg", (src.team, src.el, abil), eff); q.dmg_by[id(src)] = q.dmg_by.get(id(src), 0.0) + eff
        src.ult += eff * ULT_DMG * ULT_SCALE; q.ult += eff * ULT_DMG * ULT_SCALE
        q.dmg_in += eff
        if src.halo[1] > t and src.halo[0] < 60 and src.alive and src is not q:
            h = min(amt, 60 - src.halo[0], src.maxhp - src.hp)
            if h > 0: src.hp += h; src.halo[0] += h; s.add("heal", (src.team, src.el, "Halo"), h)
        if kind == "hit": src.lasttgt = q; src.lasthit_t = t       # Detonate: the caster's last hit, any ability
        if (s.D["ember"] == "low30" and src.el == "Pyro" and elem == "Pyro" and before >= 0.3 * q.maxhp > q.hp > 0
                and src.cd.get("IM", -1) > t):
            src.cd["IM"] = max(t, src.cd["IM"] - 3.6)
        q.last_src, q.last_abil = src, abil
        if VOLT_SD == "reactive" and q.el == "Voltaic" and not q.sd_used and 0 < q.hp < 0.3 * q.maxhp:
            q.sd_used = True; s.static_discharge(q, True)       # P27: fires by itself, once a life
        if q.hp <= 0:
            s.kill(src, q, abil)
        elif kind == "hit":
            s.react(src, q, elem)
        if kind == "hit" and elem == "Zephyr": s.squall(src, q)
        return amt

    def static_discharge(s, p, count):
        """P27 Static Discharge: knock enemies within 8 back 10 studs, then 0.5 s at 150% speed away from them."""
        t = s.t
        if count: s.add("casts", (p.team, p.el, "SD"))
        for e in s.enemies(p):
            if dist(e, p) <= SD_R:
                s.push(e, p.x, p.y, SD_PUSH); e.air = max(e.air, t + 0.3)
        p.burst = t + SD_DUR; p.disengage = t + SD_DUR + (2.0 if p.hp / p.maxhp < 0.4 else 0.0)   # low: keep running

    def kill(s, src, q, abil):
        t = s.t
        q.alive = False; q.hp = 0.0; q.dead_t = t; q.hold = None; q.wall_hp = 0.0
        s.add("kills", (src.team, src.el)); s.add("lasthit", (src.team, src.el, abil))
        tot = sum(q.dmg_by.values())
        if tot > 0 and src.team != q.team:                     # how much of this kill the killer did itself
            s.add("ks_sum", (src.team, src.el, abil), q.dmg_by.get(id(src), 0.0) / tot); s.add("ks_n", (src.team, src.el, abil))
        s.add("deaths", (q.team, q.el)); s.add("death_t", (q.team, q.el), t)
        if src.el == "Pyro" and s.D["ember"] == "kill" and src.cd.get("IM", -1) > t:
            src.cd["IM"] = max(t, src.cd["IM"] - 3.6)
        if src.el == "Voltaic" and s.D["chainrx"] == "kill" and src.cd.get("OC", -1) > t:
            src.cd["OC"] = max(t, src.cd["OC"] - 2.7)

    def react(s, src, q, elem):
        rules = RULES.get(elem)
        if not rules or RX_OFF: return
        t = s.t
        for k, rx in rules:
            if s.has(q, k) and q.rx_cd.get(rx, -1.0) <= t:
                q.rx_cd[rx] = t + RX_CD[rx]
                s.add("rx", (src.team, rx))
                if rx == "Melt":
                    s.consume(q, k); s.add("rxdmg", (src.team, rx), s.deal(src, q, 14, rx, elem, "rx"))
                elif rx == "Combustion":
                    s.consume(q, k)
                    r = 12.0 if s.in_cloud(q) else 8.0
                    for e in s.enemies(src):
                        if dist(e, q) <= r: s.add("rxdmg", (src.team, rx), s.deal(src, e, 16, rx, elem, "rx"))
                elif rx == "Overload":
                    s.consume(q, k); s.add("rxdmg", (src.team, rx), s.deal(src, q, 12, rx, elem, "rx"))
                    if q.alive: s.push(q, src.x, src.y, 6.0); q.stagger = max(q.stagger, t + 0.6)
                elif rx == "Shatter":
                    q.root = t; s.add("rxdmg", (src.team, rx), s.deal(src, q, 10, rx, elem, "rx"))
                elif rx == "Frozen":
                    s.consume(q, k); q.root = max(q.root, t + 2.0)
                elif rx == "Wildfire":
                    s.add_lash(q.lash[2] or src, q)
                elif rx == "Windchill":
                    s.add_chill(src, q)
                elif rx == "StormSurge":
                    s.add_charged(src, q, q.charged[2])
                return

    def squall(s, src, q):
        if RX_OFF: return
        for z in s.zones:
            if z.kind == "cloud" and not z.grown and z.until > s.t and (distp(q, z.x, z.y) <= z.r or distp(src, z.x, z.y) <= z.r):
                z.r *= 1.35; z.grown = True; s.add("rx", (src.team, "ToxicSquall"))
                return

    # ------------------------------------------------------------------ casting bookkeeping
    def can_cast(s, p):
        t = s.t
        return p.alive and p.nocast <= t and p.stagger <= t and p.busy <= t and p.hold is None

    def ready(s, p, k, mana):
        return p.cd.get(k, -1.0) <= s.t and p.mana >= mana and s.can_cast(p)

    def use(s, p, k, cd, mana):
        p.cd[k] = s.t + cd; p.mana -= mana
        s.add("mana", (p.team, p.el, k), mana); s.add("casts", (p.team, p.el, k)); p.ult += ULT_CAST

    def spend(s, p, k, mana):
        p.mana = max(0.0, p.mana - mana); s.add("mana", (p.team, p.el, k), mana)

    def has_tech(s, p, k): return k in p.tech

    def ult_ready(s, p): return p.ult >= 1.0 and s.can_cast(p)

    def use_ult(s, p, k):
        p.ult = 0.0; s.add("ult_cast", (p.team, p.el)); s.add("casts", (p.team, p.el, k))

    def pressured(s, q): return q.dmg_in >= 18.0

    def diver_on(s, q, r=15.0):
        best, bd = None, r
        for e in s.enemies(q):
            d = dist(e, q)
            if d <= bd: best, bd = e, d
        return best

    def peel(s, p, kind, ally):
        s.add("peel", (p.team, p.el, kind))
        s.peel_checks.append((s.t + 4.0, ally, (p.team, p.el, kind)))

    # ------------------------------------------------------------------ targeting
    def update_focus(s):
        for side in (0, 1):
            en = [q for q in s.teams[1 - side] if q.alive and q.untarget <= s.t]
            if not en: s.focus[side] = None; continue
            cur = s.focus[side]
            if TEAMPLAY:                                       # cover each other: turn on whoever dives a teammate
                best = None
                for a in s.teams[side]:
                    if a.alive and s.pressured(a):
                        for e in en:
                            d_ = dist(a, e)
                            if d_ <= 15 and (best is None or d_ < best[0]): best = (d_, e)
                if best is not None: s.focus[side] = best[1]; continue
            if s.policy == "soft":
                sup = [q for q in en if q.role == "support"]
                if sup and len(sup) < len(en):
                    pick = min(sup, key=lambda q: q.hp)
                    if cur is None or not cur.alive or cur.role != "support": s.focus[side] = pick
                    elif pick.hp < cur.hp - 15: s.focus[side] = pick
                    continue
                pool = [q for q in en if q.role != "tank"] or en
            else:
                pool = en
            pick = min(pool, key=lambda q: q.hp)
            if cur is None or not cur.alive or cur not in pool or pick.hp < cur.hp - 15: s.focus[side] = pick

    def pick_target(s, p):
        en = s.enemies(p)
        if not en: p.tgt = p.mtgt = None; return
        f = s.focus[p.team]
        if f is None or not f.alive or f.untarget > s.t: f = min(en, key=lambda q: dist(p, q))
        p.mtgt = f
        rng = M1RANGE[p.el] if p.el != "Pyro" else s.D["fb_range"]
        if dist(p, f) <= rng: p.tgt = f
        else:
            near = min(en, key=lambda q: dist(p, q))
            p.tgt = near if dist(p, near) <= rng else f

    # ------------------------------------------------------------------ movement
    def move(s, p):
        t = s.t
        if p.sky > t:
            s.ride(p); return
        if p.root > t or p.trap > t or p.stagger > t or p.air > t or p.slip > t or (p.hold == "BN" and BN_ROOT):
            p.mode = "fight"; return
        en = s.enemies(p)
        if not en or p.mtgt is None: return
        sp = s.speed(p)
        if sp <= 0: p.mode = "fight"; return
        lo, hi = BAND[p.el]
        if p.diving > t: lo, hi = 18, 40                       # Umbra mid-dive fights close
        near = min(en, key=lambda q: dist(p, q)); dn = dist(p, near)
        if p.disengage > t:                                    # P27: run straight out after Static Discharge
            st_ = sp * 0.87 * DT / max(dn, 1e-6)
            p.x = max(-AX, min(AX, p.x + (p.x - near.x) * st_)); p.y = max(-AY, min(AY, p.y + (p.y - near.y) * st_))
            p.mode = "move"; return
        goal = p.mtgt; gd = dist(p, goal)
        vx = vy = 0.0
        if p.el == "Terra":                                    # peel: run at a diver on an ally
            for a in s.allies(p):
                dv = s.diver_on(a, 14.0)
                if dv is not None and dist(p, a) > 10: goal, gd = dv, dist(p, dv); lo, hi = 4, 12; break
        if dn < lo - 2 and p.el not in ("Terra",):
            vx, vy = (p.x - near.x) / max(dn, 1e-6), (p.y - near.y) / max(dn, 1e-6)
        elif gd > hi:
            vx, vy = (goal.x - p.x) / max(gd, 1e-6), (goal.y - p.y) / max(gd, 1e-6)
        al = s.allies(p)
        for a in al:                                           # a hurt ally steps into a held wall's shadow
            if a.hold == "BW" and a.mtgt is not None and dist(p, a) <= 30 and (s.pressured(p) or p.hp / p.maxhp < 0.6):
                gx, gy = a.mtgt.x - a.x, a.mtgt.y - a.y; gn = math.hypot(gx, gy) or 1.0
                tx, ty = a.x - gx / gn * 5.0, a.y - gy / gn * 5.0
                dd = math.hypot(tx - p.x, ty - p.y)
                if dd > 1.0:
                    st_ = min(dd, sp * 0.87 * DT)
                    p.x += (tx - p.x) / dd * st_; p.y += (ty - p.y) / dd * st_
                p.mode = "fight"; return
        if al:
            cx = sum(a.x for a in al) / len(al); cy = sum(a.y for a in al) / len(al)
            leash = LEASH.get(p.el, 40.0)
            if TEAMPLAY:                                       # stick to the tank (or the team's centre), 18 studs
                tank = [a for a in al if a.el == "Terra"]
                if tank and p.el != "Terra": cx, cy = tank[0].x, tank[0].y
                leash = 45.0 if p.el == "Umbra" else (25.0 if p.el == "Terra" else 18.0)
            dc = math.hypot(cx - p.x, cy - p.y)
            if p.el == "Radiant":
                hurt = min(al, key=lambda a: a.hp / a.maxhp)
                dh = dist(p, hurt)
                if dh > (16 if TEAMPLAY else 22) and (vx == 0 and vy == 0 or dn >= lo):
                    vx, vy = (hurt.x - p.x) / dh, (hurt.y - p.y) / dh
            if dc > leash and not (dn < lo - 2):
                vx, vy = (cx - p.x) / dc, (cy - p.y) / dc
            for a in al:
                da = dist(p, a)
                if da < 6.0:
                    vx += (p.x - a.x) / max(da, 0.5) * 0.6; vy += (p.y - a.y) / max(da, 0.5) * 0.6
        n = math.hypot(vx, vy)
        if n < 0.15:
            p.mode = "fight"; return
        p.mode = "move"
        step = sp * 0.87 * DT / n
        p.x = max(-AX, min(AX, p.x + vx * step)); p.y = max(-AY, min(AY, p.y + vy * step))

    def ride(s, p):                                            # Skyrider: engage or escape at flight speed
        t = s.t
        en = s.enemies(p)
        if not en: p.sky = 0.0; return
        sp = s.D["sky"][1]
        if p.hold_aux > 0:                                     # escape: away from the nearest enemy
            near = min(en, key=lambda q: dist(p, q)); d = dist(p, near) or 1.0
            vx, vy = (p.x - near.x) / d, (p.y - near.y) / d
            if d > 45: p.sky = 0.0
        else:
            g = p.mtgt if p.mtgt is not None and p.mtgt.alive else min(en, key=lambda q: dist(p, q))
            d = dist(p, g) or 1.0
            if d < 24: p.sky = 0.0; return
            vx, vy = (g.x - p.x) / d, (g.y - p.y) / d
        p.x = max(-AX, min(AX, p.x + vx * sp * DT)); p.y = max(-AY, min(AY, p.y + vy * sp * DT))
        p.mode = "move"
        s.spend(p, "SK", 12.0 * DT)
        if p.mana <= 1 or t - p.hold_t0 >= 10.0: p.sky = 0.0
        if p.cd.get("SKg", -1) <= t and p.mana >= 10:          # a flap gusts the nearest body in front
            for e in en:
                if dist(p, e) <= 22:
                    p.cd["SKg"] = t + 1.0; s.spend(p, "SK", 10.0)
                    if s.rng.random() < 0.7:
                        s.deal(p, e, 12, "SK", HOME["SK"])
                        if e.alive: s.push(e, p.x, p.y, 12.0 * (1.5 if p.el == "Zephyr" else 1.0)); e.air = max(e.air, t + 0.6)
                    break
        if p.sky <= t: p.cd["SK"] = t + 12.0; p.hold_aux = 0.0

    # ------------------------------------------------------------------ the tick
    def tick(s):
        t = s.t
        if t >= s.next_focus:
            s.update_focus(); s.next_focus = t + 0.5
        while s.events and s.events[0][0] <= t:
            _, fn, args = s.events.pop(0); fn(*args)
        order = [p for p in s.all if p.alive]
        s.rng.shuffle(order)
        for p in order:
            if not p.alive: continue
            s.pick_target(p)
            KIT[p.el](s, p)
        for p in order:
            if p.alive: s.move(p)
        for d_ in s.all:                                       # contact: an enemy closes to 16 on d_ (re-armed past 30)
            if not d_.alive: continue
            for e in s.teams[1 - d_.team]:
                if not e.alive: continue
                dd = dist(d_, e); k = id(e)
                if dd <= 16.0:
                    if not d_.cin.get(k): d_.cin[k] = True; s.cev.append((t, d_, e))
                elif dd > 30.0: d_.cin[k] = False
        while s.cev and s.cev[0][0] + 6.0 <= t: s.contact_out(s.cev.pop(0))
        s.tick_zones()
        for p in s.all:
            if p.alive: s.dots(p)
        for ch in list(s.peel_checks):
            if ch[0] <= t:
                s.peel_checks.remove(ch)
                if ch[1].alive: s.add("peel_ok", ch[2])
        s.t = t + DT

    def contact_out(s, ev):
        """6 s after an enemy closed to 16: lost if the defender died first, won if the one who closed died first."""
        t0, d_, e = ev
        k = (d_.team, d_.el)
        s.add("contact", k + ("n",))
        dl = d_.dead_t is not None and d_.dead_t <= t0 + 6.0
        de = e.dead_t is not None and e.dead_t <= t0 + 6.0
        if dl and (not de or d_.dead_t <= e.dead_t): s.add("contact", k + ("lost",))
        elif de: s.add("contact", k + ("won",))

    def later(s, dt, fn, *args):
        s.events.append((s.t + dt, fn, args)); s.events.sort(key=lambda e: e[0])

    def tick_zones(s):
        t = s.t
        keep = []
        for z in s.zones:
            if z.until <= t: continue
            keep.append(z)
            if z.kind == "bz":
                for e in s.teams[1 - z.team]:
                    if e.alive and distp(e, z.x, z.y) <= z.r: e.caps.append([s.D["bz_cap"], t + 0.3, "bz"])
            elif z.kind in ("cloud", "pz"):
                dps = 6.0 if z.kind == "cloud" else 8.0
                for e in s.teams[1 - z.team]:
                    if e.alive and distp(e, z.x, z.y) <= z.r:
                        dmg = s.deal(z.owner, e, dps * DT, "CC" if z.kind == "cloud" else "PZ", "Toxin", "dot")
                        if z.owner.alive and z.owner.el == "Toxin": z.owner.hp = min(z.owner.maxhp, z.owner.hp + 0.3 * dmg)
                        s.add("heal", (z.team, "Toxin", "Symbiosis"), 0.3 * dmg)
                        if e.alive and z.kind == "cloud": e.poison = [s.D["ptick"], t + 5.0, z.owner]
                o = z.owner
                if z.kind == "cloud" and o.alive and distp(o, z.x, z.y) <= z.r:
                    s.deal(o, o, 0.4 * dps * DT, "SelfCloud", "Toxin", "dot")
                    if o.alive: o.poison = [s.D["ptick"] * 0.4, t + 5.0, o]
            elif z.kind == "rain":
                if t >= z.next:
                    z.next = t + 1.0
                    for e in s.teams[1 - z.team]:
                        if e.alive and distp(e, z.x, z.y) <= z.r:
                            dmg = s.deal(z.owner, e, s.D["ar_tick"], "AR", "Toxin", "hit")
                            if z.owner.alive and z.owner.el == "Toxin":
                                z.owner.hp = min(z.owner.maxhp, z.owner.hp + 0.3 * dmg); s.add("heal", (z.team, "Toxin", "Symbiosis"), 0.3 * dmg)
                            if e.alive: e.corrode = [min(4, (e.corrode[0] if e.corrode[1] > t else 0) + 1), t + 6.0]
            elif z.kind == "df":
                if t < z.armed: continue
                for e in s.teams[1 - z.team]:
                    if e.alive and distp(e, z.x, z.y) <= 4.0 and e.df_imm <= t:
                        z.until = t
                        if s.rng.random() < 0.6:
                            s.deal(z.owner, e, 10, "DF", "Cryo")
                            if e.alive: e.root = max(e.root, t + s.D["df_root"]); e.df_imm = t + s.D["df_root"] + 1.5
                        break
        s.zones = keep

    def dots(s, p):
        t = s.t
        if p.burn[1] > t: s.deal(p.burn[2], p, p.burn[0] * DT, "Burn", "Pyro", "dot")
        if p.alive and p.lash[1] > t and p.lash[0] > 0: s.deal(p.lash[2], p, s.D["ls_dps"] * p.lash[0] * DT, "LashBurn", "Pyro", "dot")
        if p.alive and p.poison[1] > t and p.poison[2] is not None:
            src = p.poison[2]
            mult = 1 + 0.12 * (p.corrode[0] if p.corrode[1] > t else 0)
            dmg = s.deal(src, p, p.poison[0] * mult * DT, "Poison", "Toxin", "dot")
            if src.alive and src.el == "Toxin" and src is not p:
                src.hp = min(src.maxhp, src.hp + 0.3 * dmg); s.add("heal", (src.team, "Toxin", "Symbiosis"), 0.3 * dmg)
        if not p.alive: return
        p.mana = min(MANA, p.mana + REGEN * DT)
        if p.mana >= 99.0: s.add("full", (p.team, p.el), DT)
        if p.mana < 10.0: s.add("dry", (p.team, p.el), DT)
        s.add("alive", (p.team, p.el), DT)
        p.dmg_in *= 0.967
        if p.ult >= 1.0 and p.ult_t is None: p.ult_t = t
        if p.shields:
            keep = []
            for sh in p.shields:
                if sh[1] > t and sh[0] > 0: keep.append(sh)
                elif sh[1] <= t and sh[0] > 0:                 # Overflow Light: unspent shield heals 0.6 x
                    h = min(0.6 * sh[0], p.maxhp - p.hp); p.hp += h; s.add("heal", (sh[2].team, "Radiant", "Overflow"), h)
            p.shields = keep
        if len(p.caps) > 6: p.caps = [c for c in p.caps if c[1] > t]
        if p.hold is not None: HOLD[p.hold](s, p)

    # ------------------------------------------------------------------ M1 firing with an exact long-run rate
    def m1_shots(s, p, interval, cost, k):
        t = s.t
        if p.next_m1 < t - interval: p.next_m1 = t
        n = 0
        while p.next_m1 <= t:
            p.next_m1 += interval; n += 1
            s.spend(p, k, cost)
        return n


# ====================================================================== shared Technique bodies (any caster)
SELF_STATUS = {"Pyro": {"burn"}, "Cryo": {"chill", "root"}, "Toxin": {"poison"}, "Voltaic": {"charged"}}
APPLIES = {"LS": "burn", "DF": "root"}
REACTORS = {"LS", "DT", "DF", "RS", "VO", "AR", "TT", "SA", "GP", "SK"}


def combo_wait(w, p, k, tg):
    """A self-combo player holds a reacting Technique until its own status is on the target (up to 4 s).
    Only a loadout that can feed itself does this, so the default loadouts never wait."""
    if k not in REACTORS or tg is None or NO_PATIENCE: return False
    mine = set(SELF_STATUS.get(p.el, ())) | {APPLIES[x] for x in p.tech if x in APPLIES and x != k}
    want = {s for s, rx in RULES.get(HOME[k], ()) if s in mine}
    if not want or any(w.has(tg, s) for s in want): return False
    key = k + "_wait"
    if p.cd.get(key) is None or w.t - p.cd[key] > 6.0: p.cd[key] = w.t
    return w.t - p.cd[key] < 4.0


def tech_all(w, p):
    t = w.t
    tg = p.tgt
    for k in p.tech:
        if not w.can_cast(p): return
        if combo_wait(w, p, k, tg): continue
        TECHS[k](w, p, tg)


class TTWall:
    """P28: one Twin Tide wall, 24 long, along the lane's axis. Live (AquaFX wallsFrame, AquaTTPose.travel): it stands
    11 off the lane's centre line until 0.3 s, closes as 11 - 7.45 s^2 (s = (e - 0.3) / 0.8) to 3.55 at 1.1 s, and has a
    collider from 0.16 s (35% up) until 1.1 s, when the crash flipbook replaces it. TT_HOLD: the met walls stand on."""
    __slots__ = ("owner", "team", "el", "abil", "cx", "cy", "ux", "uy", "side", "t0", "wall_hp", "until")

    def __init__(s, owner, cx, cy, ux, uy, side, t0, hp):
        s.owner, s.team, s.el, s.abil = owner, owner.team, owner.el, "TTwall"
        s.cx, s.cy, s.ux, s.uy, s.side, s.t0, s.wall_hp = cx, cy, ux, uy, side, t0, hp
        s.until = t0 + 1.1 + TT_HOLD

    def seg(s, t):
        k = min(1.0, max(0.0, (t - s.t0 - 0.3) / 0.8))
        g = 11.0 - 7.45 * k * k
        mx, my = s.cx - s.uy * s.side * g, s.cy + s.ux * s.side * g     # the wall's middle, g to this side of the line
        return mx - s.ux * 12.0, my - s.uy * 12.0, mx + s.ux * 12.0, my + s.uy * 12.0


def seg_cross(ax, ay, bx, by, cx, cy, dx, dy):
    d1 = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax); d2 = (bx - ax) * (dy - ay) - (by - ay) * (dx - ax)
    d3 = (dx - cx) * (ay - cy) - (dy - cy) * (ax - cx); d4 = (dx - cx) * (by - cy) - (dy - cy) * (bx - cx)
    return d1 * d2 < 0 and d3 * d4 < 0


def tt_walls(w, p, cx, cy, ux, uy, front):
    """Put up this cast's walls: the one on `front`'s side (a, c), or both with TT_HP each (b)."""
    sides = (1, -1) if TT_WALL == "b" else (front,)
    for sd in sides: w.ttw.append(TTWall(p, cx, cy, ux, uy, sd, w.t, TT_HP))


def tt_crush(w, p, cx, cy, ux, uy):
    """Whoever is still in the lane when the walls meet (1.1 s) is crushed: 35 and thrown up."""
    for e in w.enemies(p):
        ex, ey = e.x - cx, e.y - cy
        along = ex * ux + ey * uy; off = abs(ex * uy - ey * ux)
        if abs(along) > 12 or off > w.D["tt_seam"] + 6: continue
        need = max(0.0, w.D["tt_seam"] - off)
        if e.nocast > w.t + 0.6 or not w.escape(e, need, 1.1):
            w.deal(p, e, 35, "TT", HOME["TT"])
            if e.alive: e.air = max(e.air, w.t + 0.94)


def tt_protect(w, p):
    """P28: Twin Tide as cover. A teammate (or Aqua, in a and b) within reach is taking ranged fire: aim the lane so it
    runs across the line of fire through them, so the wall on the shooters' side stands between. The lane is centred on
    the aimed spot (live: aimedGround, range 40) with its axis along Aqua's aim, so she can only turn it by where she aims."""
    t = w.t
    best = None
    for a in w.allies(p, TT_WALL != "c"):
        if not w.pressured(a) or dist(p, a) > 46: continue
        shooters = [e for e in w.enemies(p) if e.tgt is a and dist(e, a) >= 12]
        if not shooters: continue
        if best is None or a.dmg_in > best[0].dmg_in: best = (a, shooters)
    if best is None: return False
    a, sh = best
    ex = sum(e.x for e in sh) / len(sh) - a.x; ey = sum(e.y for e in sh) / len(sh) - a.y
    en_ = math.hypot(ex, ey) or 1.0; fx, fy = ex / en_, ey / en_          # toward the shooters
    pick = None
    for k in (0.0, -3.0, 3.0, -6.0, 6.0, -10.0, 10.0):
        cx, cy = a.x - fy * k, a.y + fx * k                                # slide the spot along the line across the fire
        dc = math.hypot(cx - p.x, cy - p.y)
        if dc < 1.0 or dc > 40.0: continue
        ux, uy = (cx - p.x) / dc, (cy - p.y) / dc
        if abs((a.x - cx) * ux + (a.y - cy) * uy) > 10.0: continue        # the teammate inside the lane's 24
        sc = abs(ux * fx + uy * fy)                                        # 0 = the walls face the shooters square on
        if pick is None or sc < pick[0]: pick = (sc, cx, cy, ux, uy)
    if pick is None or pick[0] > 0.5: return False                         # walls more than 30 deg off square-on: no cover
    _, cx, cy, ux, uy = pick
    front = 1 if (-uy * fx + ux * fy) > 0 else -1                          # the wall on the shooters' side
    w.use(p, "TT", 16, w.D["tt_mana"]); p.busy = t + 0.3; w.add("casts", (p.team, p.el, "TT_cover"))
    tt_walls(w, p, cx, cy, ux, uy, front)
    if a is not p: w.peel(p, "Twin Tide cover", a)
    tt_crush(w, p, cx, cy, ux, uy)
    return True


def t_TT(w, p, tg):                                            # Twin Tide: crush on the seam at 1.1 s, 35 + lift 30
    if TT_WALL and w.has_tech(p, "TT") and w.ready(p, "TT", w.D["tt_mana"]) and tt_protect(w, p): return
    if tg is None or not w.has_tech(p, "TT"): return
    d = dist(p, tg)
    if d > 40 or not w.ready(p, "TT", w.D["tt_mana"]): return
    w.use(p, "TT", 16, w.D["tt_mana"]); p.busy = w.t + 0.3
    ux, uy = (tg.x - p.x) / max(d, 1e-6), (tg.y - p.y) / max(d, 1e-6)
    if TT_WALL:                                                 # the attack's walls block too (along the aim, so rarely)
        oth = [e for e in w.enemies(p) if e is not tg]
        sx = (sum(e.x for e in oth) / len(oth) - tg.x, sum(e.y for e in oth) / len(oth) - tg.y) if oth else (0.0, 0.0)
        tt_walls(w, p, tg.x, tg.y, ux, uy, 1 if (-uy * sx[0] + ux * sx[1]) >= 0 else -1)
    for e in w.enemies(p):
        ex, ey = e.x - p.x, e.y - p.y
        along = ex * ux + ey * uy; off = abs(ex * uy - ey * ux)
        if abs(along - d) > 12 or off > w.D["tt_seam"] + 6: continue
        need = max(0.0, w.D["tt_seam"] - off)
        if e.nocast > w.t + 0.6 or not w.escape(e, need, 1.1):
            w.deal(p, e, 35, "TT", HOME["TT"])
            if e.alive: e.air = max(e.air, w.t + 0.94)


def t_SA(w, p, tg):                                            # Sidearm: knock a diver off, or poke past 70
    if not w.has_tech(p, "SA"): return
    cost = w.D["sa_mana"]
    if not w.ready(p, "SA", cost * 2): return
    tgt = None
    for a in w.allies(p, True):
        dv = w.diver_on(a, 14.0)
        if dv is not None and dist(p, dv) <= 110: tgt = dv; peel_ally = a; break
    shots = 2
    if tgt is None:
        if tg is None or not (70 < dist(p, tg) <= 110) or p.mana < 50: return
        tgt, shots, peel_ally = tg, 3, None
    w.use(p, "SA", 0.9 + shots * 0.625, 0); p.busy = w.t + shots * 0.625
    if peel_ally is not None and peel_ally is not p: w.peel(p, "Sidearm knock", peel_ally)
    for _ in range(shots):
        if not tgt.alive: break
        w.spend(p, "SA", cost); w.add("casts", (p.team, p.el, "SA_b"))
        d = dist(p, tgt)
        if w.aim(p, tgt, d, 160, BODY + 0.5):
            w.deal(p, tgt, 8, "SA", HOME["SA"])
            if tgt.alive: w.push(tgt, p.x, p.y, 9.5); tgt.air = max(tgt.air, w.t + 0.55)


def ff_caught(w, e, r):
    """Flash Freeze, centre r away from e: caught (True) or out in time."""
    if CRYO_EXACT:
        a = (2.0 / math.pi) * math.asin(min(1.0, r / FF_R))        # the Sine-out front reaches r after a s
        return not w.escape(e, max(0.0, FF_R - r - 5.0), FF_LEAD + a, 0.4)
    return not w.escape(e, FF_R - r, FF_LEAD + r / FF_R, 0.4)


def ff_hold():
    """How long a caught body stays rooted, from the cast, before the 34 shatter."""
    return FF_LEAD + 1.0 + 3.5 if CRYO_EXACT else FF_FREEZE


def cursor_spot(w, p, rng_, reach, core):
    """P29: where a cursor-aimed ability goes: on an enemy at most `reach` away, pulled in to `rng_` from the caster;
    the spot with the most enemies within `core` wins, ties to a diver on a teammate, then the nearest. None if nobody
    is in reach."""
    en = w.enemies(p)
    best = None
    for e in en:
        d = dist(p, e)
        if d > reach: continue
        k = min(1.0, rng_ / max(d, 1e-6))
        cx, cy = p.x + (e.x - p.x) * k, p.y + (e.y - p.y) * k
        n = sum(1 for f in en if distp(f, cx, cy) <= core)
        dive = any(w.diver_on(a, 16) is e for a in w.allies(p, True))
        c = (n, dive, -d, cx, cy)
        if best is None or c[:3] > best[:3]: best = c
    if best is None or best[0] < 1: return None
    return best[3], best[4]


def t_BZ(w, p, tg):                                            # Blizzard: r32 on the enemy group, cap re-applied 0.3 s
    if BZ_RANGE > 0 or CRYO_LIVE:
        if not w.has_tech(p, "BZ") or not w.ready(p, "BZ", 28): return
        dur = BZ_DUR if BZ_DUR is not None else w.D["bz_dur"]
        if BZ_RANGE > 0:                                       # P29: at the cursor, up to BZ_RANGE out
            spot = cursor_spot(w, p, BZ_RANGE, BZ_RANGE + 0.5 * BZ_R, 0.5 * BZ_R)
            if spot is None: return
        else:                                                  # live: the storm where Cryo stands, once it would catch
            en = w.enemies(p)
            if not (any(dist(p, e) <= 26 for e in en) or sum(1 for e in en if dist(p, e) <= BZ_R) >= 2): return
            spot = (p.x, p.y)
        w.use(p, "BZ", 18, 28); p.busy = w.t + 0.3
        if CRYO_EXACT: w.zones.append(Zone("bz", p, spot[0], spot[1], BZ_R, w.t, w.t + dur))     # live: slows from the cast, 6 s
        else: w.zones.append(Zone("bz", p, spot[0], spot[1], BZ_R, w.t + 0.6, w.t + 0.6 + dur))
        return
    if tg is None or not w.has_tech(p, "BZ") or dist(p, tg) > 45 or not w.ready(p, "BZ", 28): return
    w.use(p, "BZ", 18, 28); p.busy = w.t + 0.3
    w.zones.append(Zone("bz", p, tg.x, tg.y, 32.0, w.t + 0.6, w.t + 0.6 + w.D["bz_dur"]))


def t_DF(w, p, tg):                                            # Deep Freeze: a trap where a diver is coming
    if not w.has_tech(p, "DF") or not w.ready(p, "DF", 22): return
    if CRYO_LIVE and DF_RANGE <= 0:                            # live: the trap goes down at Cryo's own feet
        if w.diver_on(p, 28.0) is not None:
            w.use(p, "DF", 16, 22)
            w.zones.append(Zone("df", p, p.x, p.y, 4.0, w.t, w.t + 20.0)); w.zones[-1].armed = w.t + 0.5
        return
    for a in w.allies(p, True):
        dv = w.diver_on(a, 28.0)
        if dv is not None and (DF_RANGE <= 0 or dist(p, dv) <= DF_RANGE):
            w.use(p, "DF", 16, 22)
            w.zones.append(Zone("df", p, dv.x, dv.y, 4.0, w.t, w.t + 20.0)); w.zones[-1].armed = w.t + 0.5
            if a is not p: w.peel(p, "Deep Freeze trap", a)
            return
    if DF_RANGE > 0:                                            # P29: nobody in range, but one coming at Cryo: the trap
        dv = w.diver_on(p, 28.0)                                # on its path, as far out as the range lets it go
        if dv is not None:
            d = dist(p, dv); k = min(1.0, DF_RANGE / max(d, 1e-6))
            w.use(p, "DF", 16, 22)
            w.zones.append(Zone("df", p, p.x + (dv.x - p.x) * k, p.y + (dv.y - p.y) * k, 4.0, w.t, w.t + 20.0))
            w.zones[-1].armed = w.t + 0.5


def t_DT(w, p, tg):                                            # Detonate: the last-hit target, no line of sight
    if not w.has_tech(p, "DT") or not w.ready(p, "DT", 20): return
    q = p.lasttgt
    if q is None or not q.alive or w.t - p.lasthit_t > 4.0 or dist(p, q) > 120: return
    miss = (q.maxhp - q.hp) / q.maxhp
    dmg = 12 + 36 * min(1.0, miss / 0.75)
    if dmg < q.hp + sum(sh[0] for sh in q.shields) and miss < 0.5: return
    w.use(p, "DT", 14, 20); p.busy = w.t + 0.27

    def boom(src=p, q=q):
        if q.alive and src.alive:
            m = (q.maxhp - q.hp) / q.maxhp
            w.deal(src, q, 12 + 36 * min(1.0, m / 0.75), "DT", HOME["DT"])
    w.later(1.77, boom)


def t_LS(w, p, tg):                                            # Scorching Lash: sweep 35 in front, <=5, 12 + a burn stack
    if not w.has_tech(p, "LS") or not w.ready(p, "LS", 12): return
    hit = [e for e in w.enemies(p) if dist(p, e) <= 35]
    if not hit: return
    w.use(p, "LS", w.D["ls_cd"], 12); p.busy = w.t + 0.22
    for e in hit[:5]:
        if w.rng.random() < 0.85:
            w.deal(p, e, 12, "LS", HOME["LS"])
            if e.alive: w.add_lash(p, e)


def t_PT(w, p, tg):                                            # Position Trade: pull a dived, low ally back to me
    if not w.has_tech(p, "PT") or not w.ready(p, "PT", 18): return
    for a in w.allies(p):
        if a.hp / a.maxhp < 0.4 and dist(p, a) <= 45:
            dv = w.diver_on(a, 14.0)
            if dv is None: continue
            mine = min((dist(p, e) for e in w.enemies(p)), default=99)
            if mine <= dist(a, dv) + 8: continue
            w.use(p, "PT", 14, 18); p.busy = w.t + 0.12
            p.x, p.y, a.x, a.y = a.x, a.y, p.x, p.y
            w.peel(p, "Position Trade", a)
            return


def t_BN(w, p, tg):                                            # Benediction: rooted area heal, 7.5 per 0.5 s, r25
    if not w.has_tech(p, "BN") or not w.ready(p, "BN", 20): return
    if BN_RANGE > 0:                                            # P29: the staff goes down at the cursor, on the hurt
        hurt = [a for a in w.allies(p) if a.maxhp - a.hp >= 30]
        if not hurt: return
        hx = sum(a.x for a in hurt) / len(hurt); hy = sum(a.y for a in hurt) / len(hurt)
        dh = math.hypot(hx - p.x, hy - p.y); k = min(1.0, BN_RANGE / max(dh, 1e-6))
        p.bn_c = (p.x + (hx - p.x) * k, p.y + (hy - p.y) * k)
        inr = [a for a in w.allies(p, True) if distp(a, *p.bn_c) <= BN_R]
    else:
        inr = [a for a in w.allies(p, True) if dist(p, a) <= BN_R]
    missing = sum(a.maxhp - a.hp for a in inr)
    worst = max((a.maxhp - a.hp for a in inr if a is not p), default=0)
    if missing < 50 or worst < 30: return                       # a teammate is hurt, not only me
    if any(dist(p, e) <= 14 for e in w.enemies(p)): return
    if w.pressured(p) and p.hp / p.maxhp < 0.7: return
    w.use(p, "BN", 0, 20); p.busy = w.t + 0.5
    p.hold = "BN"; p.hold_t0 = w.t + 0.5
    for a in inr:
        if a is not p and w.pressured(a): w.peel(p, "Benediction", a); break


def h_BN(w, p):
    t = w.t
    if t < p.hold_t0: return
    if BN_RANGE > 0: inr = [a for a in w.allies(p, True) if distp(a, *p.bn_c) <= BN_R]
    else: inr = [a for a in w.allies(p, True) if dist(p, a) <= BN_R]
    others = sum(a.maxhp - a.hp for a in inr if a is not p)
    near = min((dist(p, e) for e in w.enemies(p)), default=99)
    if (t - p.hold_t0 >= w.D["ben_max"] or p.mana < 1 or others < 10 or near < 12
            or (w.pressured(p) and p.hp / p.maxhp < 0.5)):
        p.hold = None; p.cd["BN"] = t + BN_CD; return
    w.spend(p, "BN", 10.0 * DT)
    for a in inr:
        h = min(BN_HEAL * DT, a.maxhp - a.hp)
        if h > 0: a.hp += h; w.add("heal", (p.team, p.el, "BN"), h)


def t_AS(w, p, tg):                                            # Aftershock: r24 ring, 20 + knock + 0.5 s no-cast
    if not w.has_tech(p, "AS") or not w.ready(p, "AS", 20): return
    if AS_RANGE > 0:                                            # P29: the ring at the cursor, up to AS_RANGE out
        spot = cursor_spot(w, p, AS_RANGE, AS_RANGE + 12.0, 12.0)
        if spot is None: return
        cx, cy = spot
        inr = [e for e in w.enemies(p) if distp(e, cx, cy) <= 22]
        w.use(p, "AS", 12, 20); p.busy = w.t + 1.0
        for a in w.allies(p):
            if any(dist(e, a) <= 14 for e in inr): w.peel(p, "Aftershock", a); break
        for e in inr:
            r = distp(e, cx, cy)
            if not w.escape(e, 24 - r, 0.68 + 0.7 * r / 24, 0.6):
                w.deal(p, e, 20, "AS", HOME["AS"])
                if e.alive:
                    w.push(e, cx, cy, 9.0); e.air = max(e.air, w.t + 0.69); e.nocast = max(e.nocast, w.t + 0.5)
        return
    inr = [e for e in w.enemies(p) if dist(p, e) <= 22]
    if not inr: return
    w.use(p, "AS", 12, 20); p.busy = w.t + 1.0
    for a in w.allies(p):
        if any(dist(e, a) <= 14 for e in inr): w.peel(p, "Aftershock", a); break
    for e in inr:
        r = dist(p, e)
        if not w.escape(e, 24 - r, 0.68 + 0.7 * r / 24, 0.6):
            w.deal(p, e, 20, "AS", HOME["AS"])
            if e.alive:
                w.push(e, p.x, p.y, 9.0); e.air = max(e.air, w.t + 0.69); e.nocast = max(e.nocast, w.t + 0.5)


def t_BW(w, p, tg):                                            # Bulwark Wall: held cover for me and an ally behind me
    if not w.has_tech(p, "BW") or not w.ready(p, "BW", 25): return
    cover = [a for a in w.allies(p, BW_EAGER) if dist(p, a) <= 25 and (w.pressured(a) or (BW_EAGER and a.dmg_in > 6))]
    if not cover and not (w.pressured(p) and p.hp / p.maxhp < 0.6): return
    w.use(p, "BW", 0.3, 10); p.hold = "BW"; p.hold_t0 = w.t; p.wall_hp = BW_HP
    for a in cover:
        if a is not p: w.peel(p, "Bulwark Wall", a); break


def h_BW(w, p):
    t = w.t
    w.spend(p, "BW", BW_DRAIN * DT)
    cover = [a for a in w.allies(p, True) if dist(p, a) <= 25 and (w.pressured(a) or a.dmg_in > 6)]
    if p.mana < 2 or p.wall_hp <= 0 or t - p.hold_t0 > BW_HOLD or (not cover and t - p.hold_t0 > 1.0):
        p.hold = None; p.wall_hp = 0.0; p.cd["BW"] = t + BW_GAP   # short holds: 2.5 s at most, 2 s between (default)


def t_AV(w, p, tg):                                            # Antitoxin Vent: cleanse own poison (+ live: DoT shield)
    if not w.has_tech(p, "AV") or not w.ready(p, "AV", 20): return
    t = w.t
    own_poison = p.poison[1] > t and p.poison[2] is not None and p.poison[2].team == p.team
    dots = p.burn[1] > t or (p.lash[0] > 0 and p.lash[1] > t) or p.poison[1] > t
    if own_poison or (w.D["vent_dr"] > 0 and dots):
        w.use(p, "AV", 16, 20); p.busy = t + 0.35
        if own_poison: p.poison = [0.0, 0.0, None]
        p.vent = t + 6.0


def t_AR(w, p, tg):                                            # Acid Rain: r10 at range 50, gathers 0.7 s, 4 s
    if tg is None or not w.has_tech(p, "AR") or dist(p, tg) > 50 or not w.ready(p, "AR", 30): return
    w.use(p, "AR", 14, 30); p.busy = w.t + 0.3
    z = Zone("rain", p, tg.x, tg.y, 10.0, w.t, w.t + 4.7); z.next = w.t + 0.7
    w.zones.append(z)


def t_MK(w, p, tg):                                            # Mark: 1 stack a second to 3, expires 5 s after full
    if tg is None or not w.has_tech(p, "MK") or dist(p, tg) > 120 or not w.ready(p, "MK", 18): return
    if tg.mark is not None and w.t - tg.mark[0] < 8: return
    if w.rng.random() < p_hit(dist(p, tg), None, 7.0, w.vlat(tg), w.vlat(p), w.vvert(tg)):
        w.use(p, "MK", 14, 18); tg.mark = (w.t, p)


def t_DD(w, p, tg):                                            # Decoy Double: soaks one aimed hit (assumed 50%)
    if not w.has_tech(p, "DD") or not w.ready(p, "DD", 18): return
    if w.pressured(p) or any(e.tgt is p and dist(p, e) <= 60 for e in w.enemies(p)):
        w.use(p, "DD", 20, 18); p.decoy = w.t + 8.0


def t_RS(w, p, tg):                                            # Railspike: hitscan 30, pierce 6, 0.55 s windup
    if tg is None or not w.has_tech(p, "RS") or dist(p, tg) > 90 or not w.ready(p, "RS", 20): return
    w.use(p, "RS", 10, 20); p.busy = w.t + 0.55
    d = dist(p, tg)
    ux, uy = (tg.x - p.x) / max(d, 1e-6), (tg.y - p.y) / max(d, 1e-6)
    for e in w.enemies(p):
        ex, ey = e.x - p.x, e.y - p.y
        along = ex * ux + ey * uy; off = abs(ex * uy - ey * ux)
        if along < 0 or along > 90: continue
        if blocked(w, p, e): continue
        if w.rng.random() < p_off(along, None, BODY + 0.9, off, w.vlat(e), w.vlat(p), w.vvert(e)):
            w.deal(p, e, 30, "RS", HOME["RS"])


def t_VO(w, p, tg):                                            # Volt Orb: r7.5, 28 -> 14, +8 direct, fuse 1.25
    if tg is None or not w.has_tech(p, "VO") or dist(p, tg) > 60 or not w.ready(p, "VO", 20): return
    w.use(p, "VO", 12, 20); p.busy = w.t + 0.12
    d = dist(p, tg)
    direct = w.aim(p, tg, d, 48, BODY + 0.6)
    for e in w.enemies(p):
        r = dist(e, tg)
        if r > 7.5: continue
        if e is tg and direct:
            w.deal(p, e, 28 + 8, "VO", HOME["VO"]); continue
        if not w.escape(e, 7.5 - r, 1.25 + d / 48.0):
            w.deal(p, e, 28 - 14 * r / 7.5, "VO", HOME["VO"])


def t_SK(w, p, tg):                                            # Skyrider: ride to a far target, or ride out of a dive
    if not w.has_tech(p, "SK") or not w.ready(p, "SK", 30): return
    if w.capnow(p) < w.D["dash_min"]: return
    t = w.t
    near = min((dist(p, e) for e in w.enemies(p)), default=999)
    esc = p.hp / p.maxhp < 0.4 and near < 18
    m = p.mtgt                                                  # join a fight in progress, or catch an isolated target
    eng = m is not None and dist(p, m) > 60 and (any(dist(a, m) <= 40 for a in w.allies(p)) or
                                                  not any(dist(f, m) <= 25 for f in w.teams[m.team] if f.alive and f is not m))
    if not (esc or eng): return
    w.use(p, "SK", 0, 15); p.busy = t + 0.44
    p.sky = t + 10.44; p.hold_t0 = t + 0.44; p.hold_aux = 1.0 if esc else 0.0


def t_GP(w, p, tg):                                            # Gust Pad under the target: 19 up, <=8 flat speed
    if tg is None or not w.has_tech(p, "GP") or dist(p, tg) > 40 or not w.ready(p, "GP", 20): return
    w.use(p, "GP", 14, 20); p.busy = w.t + 0.26
    for e in w.enemies(p):
        if dist(e, tg) > 3.4 + (0 if e is not tg else 0): continue
        stuck = w.capnow(e) < 8 or e.root > w.t or e.trap > w.t or e.stagger > w.t
        if stuck or w.rng.random() > AWARE * 0.6:
            e.air = max(e.air, w.t + 1.54); e.caps.append([8.0, w.t + 1.54, "gp"])
            w.deal(p, e, 0.01, "GP", HOME["GP"])


TECHS = {"TT": t_TT, "SA": t_SA, "BZ": t_BZ, "DF": t_DF, "DT": t_DT, "LS": t_LS, "PT": t_PT, "BN": t_BN, "AS": t_AS,
         "BW": t_BW, "AV": t_AV, "AR": t_AR, "MK": t_MK, "DD": t_DD, "RS": t_RS, "VO": t_VO, "SK": t_SK, "GP": t_GP}
HOLD = {"BN": h_BN, "BW": h_BW}


def blocked(w, p, q):
    """Bulwark Wall on q's side eats a direct shot from p: the shooter must be within ~70 degrees of the wall's face,
    and q is the Terra holding it or stands in the wall's shadow (behind Terra, within 6 of the line to the shooter)."""
    for a in w.teams[q.team]:
        if not (a.alive and a.hold == "BW" and a.wall_hp > 0) or a.mtgt is None: continue
        fx, fy = p.x - a.x, p.y - a.y
        fn = math.hypot(fx, fy)
        gx, gy = a.mtgt.x - a.x, a.mtgt.y - a.y
        n = fn * math.hypot(gx, gy)
        if n <= 0 or (fx * gx + fy * gy) / n <= 0.34: continue
        if a is q: return a
        ux, uy = fx / fn, fy / fn
        vx, vy = q.x - a.x, q.y - a.y
        if vx * ux + vy * uy < 0 and abs(vx * uy - vy * ux) <= BW_SHADOW: return a
    if w.ttw:                                                   # P28: a standing Twin Tide wall across the shot's path
        t = w.t
        w.ttw = [z for z in w.ttw if z.until > t and z.wall_hp > 0]
        for z in w.ttw:
            if z.team != q.team or t < z.t0 + 0.16 or (TT_WALL == "c" and q is z.owner): continue
            if seg_cross(p.x, p.y, q.x, q.y, *z.seg(t)): return z
    return False


def wall_eat(w, a, amt, p):
    take = min(a.wall_hp, amt); a.wall_hp -= take
    w.add("absorb", (a.team, a.el, getattr(a, "abil", "BW")), take)


def shot(w, p, q, dmg, abil, elem, vp, wid, d=None):
    """An aimed shot at q: Bulwark Wall and Decoy Double can eat it. Returns True if it reached q."""
    d = dist(p, q) if d is None else d
    if q.untarget > w.t: return False
    if not w.aim(p, q, d, vp, wid): return False
    a = blocked(w, p, q)
    if a:
        wall_eat(w, a, dmg, p); return False
    if q.decoy > w.t and w.rng.random() < 0.5:
        q.decoy = 0.0; return False
    w.deal(p, q, dmg, abil, elem)
    return True


def line_extra(w, p, q, d, vp, wid, reach, dmg, abil, elem, maxn):
    """Pierce: other enemies near the aim line through q."""
    ux, uy = (q.x - p.x) / max(d, 1e-6), (q.y - p.y) / max(d, 1e-6)
    n = 0
    for e in w.enemies(p):
        if e is q or n >= maxn: continue
        ex, ey = e.x - p.x, e.y - p.y
        along = ex * ux + ey * uy; off = abs(ex * uy - ey * ux)
        if along <= 0 or along > reach or off > wid + 4: continue
        if blocked(w, p, e): continue
        if w.rng.random() < p_off(along, vp, wid, off, w.vlat(e), w.vlat(p), w.vvert(e)):
            w.deal(p, e, dmg, abil, elem); n += 1


# ====================================================================== the nine kits (M1, Primary, Ultimate)
def kit_aqua(w, p):
    tg = p.tgt
    if tg is None or not w.can_cast(p): return
    t, d = w.t, dist(p, tg)
    if w.ult_ready(p) and d <= 45:
        grp = [e for e in w.enemies(p) if dist(e, tg) <= 22]
        if len(grp) >= 2 or tg.hp / tg.maxhp < 0.5 or t > 45:
            w.use_ult(p, "Maw"); p.busy = t + 1.2
            for e in grp:
                r = dist(e, tg)
                if e.nocast > t + 0.8 or e.root > t + 1.2 or not w.escape(e, 22 - r, 1.2, 0.3):
                    w.deal(p, e, 65, "Maw", "Aqua")
                    if e.alive: w.deal(p, e, 25, "Maw", "Aqua"); e.trap = max(e.trap, t + 4.6)
            return
    if 8 < d <= 36 and w.ready(p, "UT", 25):                   # Undertow: pull the target into my team
        w.use(p, "UT", 9, 25); p.busy = t + 0.6
        if w.rng.random() < p_hit(d, None, d * 0.3153, w.vlat(tg), w.vlat(p), w.vvert(tg)):
            w.pull_to(tg, p.x, p.y, 4.2); tg.nocast = max(tg.nocast, t + 0.5)
    tech_all(w, p)
    if not w.can_cast(p) or d > 70: return
    n = w.m1_shots(p, 0.667, 4.0, "Riptide")
    for _ in range(n):
        p.current = t + 3.0
        jf = (1 - (0.35 if d > 15 else 0.1)) if w.jump else 1.0
        if w.rng.random() < jf and shot(w, p, tg, RIP_DMG, "Riptide", "Aqua", PROJ, 3.5 + BODY, d):
            if tg.alive and tg.mode == "move" and w.rng.random() < 0.15: tg.slip = t + 0.8
        line_extra(w, p, tg, d, PROJ, 3.5 + BODY, 70, RIP_DMG, "Riptide", "Aqua", 3)


def kit_cryo(w, p):
    tg = p.tgt
    if tg is None or not w.can_cast(p): return
    t = w.t
    en = w.enemies(p)
    n16 = sum(1 for e in en if dist(p, e) <= 16); n18 = sum(1 for e in en if dist(p, e) <= 18)
    if FF_RANGE > 0:                                            # P29: Flash Freeze at the cursor, up to FF_RANGE out
        spot = cursor_spot(w, p, FF_RANGE, FF_RANGE + 5.0, 0.6 * FF_R) if w.ready(p, "FF", 30) else None
        if spot is not None:
            cx, cy = spot
            w.use(p, "FF", 14, 30); p.busy = t + FF_LEAD
            for a in w.allies(p):
                dv = w.diver_on(a, 16)
                if dv is not None and distp(dv, cx, cy) <= FF_R: w.peel(p, "Flash Freeze", a); break
            for e in en:
                r = distp(e, cx, cy)
                if r > FF_R: continue
                if ff_caught(w, e, r):
                    w.deal(p, e, 10, "FF", "Cryo")
                    if e.alive:
                        e.caps.append([5.0, t + 1.2, "ff"]); e.root = max(e.root, t + ff_hold())
                        w.later(ff_hold(), lambda src=p, q=e: q.alive and w.deal(src, q, 34, "FF", "Cryo"))
    elif w.ready(p, "FF", 30) and (n16 >= 1 or n18 >= 2):      # Flash Freeze: r20 around me
        w.use(p, "FF", 14, 30); p.busy = t + FF_LEAD
        for a in w.allies(p):
            if dist(a, p) <= 20 and w.diver_on(a, 16) is not None: w.peel(p, "Flash Freeze", a); break
        for e in en:
            r = dist(p, e)
            if r > FF_R: continue
            if ff_caught(w, e, r):
                w.deal(p, e, 10, "FF", "Cryo")
                if e.alive:
                    e.caps.append([5.0, t + 1.2, "ff"]); e.root = max(e.root, t + ff_hold())
                    w.later(ff_hold(), lambda src=p, q=e: q.alive and w.deal(src, q, 34, "FF", "Cryo"))
    d = dist(p, tg)
    if w.ult_ready(p) and d <= 60:                              # Mirror Cage: lock 4.5, trap r19.5 around the catch
        grp = [e for e in en if dist(e, tg) <= 19.5]
        if len(grp) >= 2 or tg.hp / tg.maxhp < 0.6 or t > 40:
            w.use_ult(p, "Cage"); p.busy = t + 0.7
            if w.rng.random() < p_hit(d, None, 4.5, w.vlat(tg), w.vlat(p), w.vvert(tg)):
                for e in grp:
                    r = dist(e, tg)
                    caught = (e is tg and (tg.root > t or not w.escape(tg, 19.5, 0.7))) or \
                             (e is not tg and not w.escape(e, 19.5 - r, 1.2))
                    if caught:
                        w.deal(p, e, 72, "Cage", "Cryo")
                        if e.alive: e.root = max(e.root, t + w.D["mc_root"])
            return
    tech_all(w, p)
    if not w.can_cast(p): return
    q = tg
    for a in w.allies(p):                                       # peel: Chill the diver on an ally
        dv = w.diver_on(a, 15.0)
        if dv is not None and dist(p, dv) <= 120: q = dv; break
    dq = dist(p, q)
    if dq > 120: return
    n = w.m1_shots(p, 0.333, 2.0, "Icicle")
    for _ in range(n):
        if q is not tg: w.add("peel", (p.team, "Cryo", "Icicle on a diver"), 1.0 / 3)
        if shot(w, p, q, 8, "Icicle", "Cryo", PROJ, BODY + 0.2, dq):
            p.cold = t + 2.0
            if q.alive: w.add_chill(p, q)


def kit_pyro(w, p):
    tg = p.tgt
    if tg is None or not w.can_cast(p): return
    t, d = w.t, dist(p, tg)
    rng = w.D["fb_range"]
    if w.ult_ready(p) and d <= 60:                              # Ring of Fire r17.5, 55 + burn 10 x 1.5
        grp = [e for e in w.enemies(p) if dist(e, tg) <= 17.5]
        if len(grp) >= 2 or tg.hp / tg.maxhp < 0.6 or t > 40:
            w.use_ult(p, "RoF"); p.busy = t + 0.5
            for e in grp:
                ok = (w.rng.random() < 0.92) if e is tg else not w.escape(e, 17.5 - dist(e, tg), 0.83)
                if ok:
                    w.deal(p, e, 55, "RoF", "Pyro")
                    if e.alive: w.add_burn(p, e, 3.0, 5.0)
            return
    if d <= rng and w.ready(p, "IM", 25):
        w.use(p, "IM", 12, 25); p.busy = t + 0.22; p.immolate = 3
    tech_all(w, p)
    if not w.can_cast(p) or d > rng: return
    n = w.m1_shots(p, FB_RATE, 3.0, "Fireball")
    for _ in range(n):
        hitq = []
        if EXPOSE < 1.0 and w.rng.random() > EXPOSE: continue  # cover: one check per fireball, splash included
        if tg.untarget > t: continue
        if w.aim(p, tg, d, PROJ, BODY + 1.0, False):
            a = blocked(w, p, tg)
            if a: wall_eat(w, a, 18, p); continue
            if tg.decoy > t and w.rng.random() < 0.5: tg.decoy = 0.0; continue
            w.deal(p, tg, FB_DIRECT, "Fireball", "Pyro"); hitq.append(tg)
        elif w.aim(p, tg, d, PROJ, FB_SPLASH_R + BODY, False):
            a = blocked(w, p, tg)
            if a: wall_eat(w, a, 9, p); continue
            w.deal(p, tg, FB_SPLASH, "Fireball", "Pyro"); hitq.append(tg)
        else:
            continue
        for e in w.enemies(p):                                  # splash r6 around the impact
            if e is not tg and dist(e, tg) <= FB_SPLASH_R:
                w.deal(p, e, FB_SPLASH, "Fireball", "Pyro"); hitq.append(e)
        if p.immolate > 0:
            p.immolate -= 1
            for e in hitq:
                if e.alive: w.add_burn(p, e, 2.4, 5.0)


def kit_radiant(w, p):
    tg = p.tgt
    if not w.can_cast(p): return
    t = w.t
    al = w.allies(p, True)
    if w.ult_ready(p) and tg is not None and dist(p, tg) <= 60:  # Halo: team r40, 6 s of lifesteal (cap 60)
        inr = [a for a in al if dist(p, a) <= 40]
        if len(inr) >= 2 or t > 40:
            w.use_ult(p, "Halo"); p.busy = t + 0.9
            for a in inr: a.halo = [0.0, t + 6.9]
            return
    if w.ready(p, "BL", 25):                                   # Blessing on the ally under the most pressure
        cand = [a for a in al if dist(p, a) <= 45 and (w.pressured(a) or a.hp / a.maxhp < 0.6)]
        if cand:
            a = max(cand, key=lambda a: a.dmg_in + (a.maxhp - a.hp) * 0.2)
            w.use(p, "BL", BL_CD, 25)
            a.shields.append([BL_SHIELD, t + 8.0, p])
            if a is not p: w.peel(p, "Blessing", a)
    tech_all(w, p)
    if not w.can_cast(p) or tg is None: return
    if LANCE_HEAL > 0:                                          # team-mode option: the Lance heals a hurt ally
        hurt = [a for a in w.allies(p) if dist(p, a) <= 60 and a.hp < a.maxhp and
                (a.hp / a.maxhp < 0.6 or (w.pressured(a) and a.hp / a.maxhp < 0.85))]
        if hurt:
            a = min(hurt, key=lambda a: a.hp / a.maxhp)
            if p.lance_ally is not a: p.lance_t = 0.0; p.lance_ally = a
            if p.lance_t == 0.0: w.spend(p, "Lance", 2.0)
            w.spend(p, "Lance", 7.5 * DT)
            h = min(LANCE_HEAL * (0.5 + 0.5 * min(1.0, p.lance_t / 2.0)) * DT, a.maxhp - a.hp)
            a.hp += h; w.add("heal", (p.team, p.el, "LanceHeal"), h); p.lance_t += DT
            return
        if p.lance_ally is not None: p.lance_ally = None; p.lance_t = 0.0
    d = dist(p, tg)
    if d > 60: p.lance_t = 0.0; return
    if p.lance_t == 0.0: w.spend(p, "Lance", 2.0)
    w.spend(p, "Lance", 7.5 * DT)
    if blocked(w, p, tg):
        a = blocked(w, p, tg); wall_eat(w, a, 16 * DT, p); p.lance_t = max(0.0, p.lance_t - 0.2); return
    if tg.untarget > t: return
    if w.aim(p, tg, d, None, BODY + 0.75):
        dps = 16 + 16 * min(1.0, p.lance_t / 2.0)
        w.deal(p, tg, dps * DT, "Lance", "Radiant")
        p.lance_t += DT
    else:
        p.lance_t = max(0.0, p.lance_t - 0.4)


def kit_terra(w, p):
    tg = p.tgt
    if tg is None or not w.can_cast(p): return
    t, d = w.t, dist(p, tg)
    dash_ok = w.capnow(p) >= w.D["dash_min"]
    if "BW" in p.tech and w.ready(p, "BW", 25):                 # peel first: wall for an ally under fire
        if any(dist(p, a) <= 25 and (w.pressured(a) or (BW_EAGER and a.dmg_in > 6)) for a in w.allies(p, BW_EAGER)):
            t_BW(w, p, tg)
            if not w.can_cast(p): return
    if w.ult_ready(p) and d <= 40:                              # Earthen Tomb: fissure 60 studs/s for <=1.6 s
        v = w.speed(tg) * 0.87
        if d / max(1e-3, 60 - min(59.9, v)) <= 1.6:
            w.use_ult(p, "Tomb"); p.busy = t + 0.6
            if not (w.jump and w.rng.random() < AWARE * 0.5):
                w.deal(p, tg, 75, "Tomb", "Terra")
            return
    if dash_ok and w.ready(p, "BC", 30):                        # Bulwark Charge: peel a diver first, else engage
        q, peel_ally = None, None
        for a in w.allies(p):
            dv = w.diver_on(a, 14.0)
            if dv is not None and 6 < dist(p, dv) <= 30: q, peel_ally = dv, a; break
        if q is None and 8 < d <= 30 and p.hp / p.maxhp > 0.5 and (p.mana >= 55 or "BW" not in p.tech): q = tg
        if q is not None:
            dq = dist(p, q)
            w.use(p, "BC", 9, 30); p.busy = t + 0.62; p.dr, p.dr_until = 0.4, t + 0.62
            step = min(26.0, dq - 3.0)
            p.x += (q.x - p.x) / dq * step; p.y += (q.y - p.y) / dq * step
            if peel_ally is not None: w.peel(p, "Bulwark Charge", peel_ally)
            if w.rng.random() < p_hit(min(dq, 26), None, 3.6, w.vlat(q), 0.0, w.vvert(q)):
                w.deal(p, q, 35, "BC", "Terra")
                if q.alive:
                    w.push(q, p.x, p.y, 7.5); q.air = max(q.air, t + 0.44); q.stagger = max(q.stagger, t + 1.2)
            return
    tech_all(w, p)
    if not w.can_cast(p): p.boulder_t = 0.0; return
    if d > 120: p.boulder_t = 0.0; return
    if t < p.next_m1: return
    p.boulder_t += DT
    if p.boulder_t < 1.1: return
    p.boulder_t = 0.0; p.next_m1 = t + 0.85; w.spend(p, "Boulder", 4.0)
    shot(w, p, tg, 48, "Boulder", "Terra", w.D["boulder_v"], BODY + 1.1, d)


def kit_toxin(w, p):
    tg = p.tgt
    if tg is None or not w.can_cast(p): return
    t, d = w.t, dist(p, tg)
    pz = None
    if w.ult_ready(p):                                          # Patient Zero: the catch bursts r20 after 3.5 s, so
        cand = [e for e in w.enemies(p) if dist(p, e) <= 60]    # catch the enemy with the most teammates around it
        if cand: pz = max(cand, key=lambda e: (sum(1 for f in w.teams[e.team] if f.alive and dist(f, e) <= 20), e.hp))
    if pz is not None:
        tg, d = pz, dist(p, pz)
        w.use_ult(p, "PZ"); p.busy = t + 0.4
        if w.rng.random() < p_hit(d, None, 7.0, w.vlat(tg), w.vlat(p), w.vvert(tg)):
            def burst(src=p, q=tg):
                if not q.alive: return
                for e in w.teams[q.team]:
                    if not e.alive: continue
                    r = dist(e, q)
                    if r > 20: continue
                    if e is q or not w.escape(e, 20 - r, 3.5):
                        w.deal(src, e, 18, "PZ", "Toxin")
                w.zones.append(Zone("pz", src, q.x, q.y, 12.0, w.t, w.t + 5.0))
            w.later(3.5, burst)
        return
    if d <= 60 and w.ready(p, "CC", 25):                        # Corrosive Cloud on the newest bubble, r9, 6 s
        w.use(p, "CC", 9, 25); p.busy = t + 0.3
        w.zones.append(Zone("cloud", p, tg.x + w.rng.uniform(-3, 3), tg.y + w.rng.uniform(-3, 3), 9.0, t + 0.6, t + 6.6))
    tech_all(w, p)
    if not w.can_cast(p) or d > 120: return
    n = w.m1_shots(p, 0.55, 3.0, "Bubbles")
    for _ in range(n):
        if shot(w, p, tg, 9, "Bubbles", "Toxin", PROJ, BODY + 1.0, d) and tg.alive:
            tg.poison = [w.D["ptick"], t + 5.0, p]


def kit_umbra(w, p):
    tg = p.tgt
    if tg is None or not w.can_cast(p): return
    t, d = w.t, dist(p, tg)
    en = w.enemies(p)
    if w.ult_ready(p) and d <= 160:                             # Eclipse: 1 s windup, 7 s of faster darts, all unaware
        w.use_ult(p, "Eclipse"); p.busy = t + 1.0; p.eclipse = t + 8.0
        return
    near = min(en, key=lambda e: dist(p, e)); dn = dist(p, near)

    def step(kind):                                             # one Shadow Step, with the P27 options
        cd = 5.0 if (UMBRA_SS == "dive" and t - p.lasthit_t <= 2.0) else 10.0   # (a): within 2 s after a hit
        w.use(p, "SS", cd, 20); w.add("casts", (p.team, p.el, kind))
        p.ss_cast_t = t; p.ss_halved = cd < 10.0; p.decoy = max(p.decoy, t + 0.6)
        if UMBRA_SS == "vanish": p.untarget = t + VANISH        # (b): untargetable window
    if (UMBRA_DIVE and p.diving <= t and dn > 30 and tg.hp / tg.maxhp < 0.6 and p.mana >= 40 and w.capnow(p) > 0
            and w.ready(p, "SS", 20) and d > 30):                # dive: blink 22 in on a low target, fight close 4 s
        step("SS_in")
        p.x += (tg.x - p.x) / d * 22.0; p.y += (tg.y - p.y) / d * 22.0; p.diving = t + 4.0
        near = min(en, key=lambda e: dist(p, e)); dn = dist(p, near)
    exit_now = UMBRA_DIVE and p.diving > t and (w.pressured(p) or p.diving - t < 0.1)
    pressed = UMBRA_SS in ("vanish", "press", "dive") and w.pressured(p) and p.hp / p.maxhp < 0.6   # mid-focus-fire
    if UMBRA_EXIT > 0 and (dn <= 16 or pressed or exit_now) and w.capnow(p) > 0 and w.ready(p, "SSX", 20):
        w.use(p, "SSX", UMBRA_EXIT, 20); w.add("casts", (p.team, p.el, "SS_out")); p.decoy = max(p.decoy, t + 0.6)
        w.push(p, near.x, near.y, 22.0); p.diving = 0.0           # handoff D: the escape blink, its own charge
    elif (dn <= 16 or pressed or exit_now) and w.capnow(p) > 0 and w.ready(p, "SS", 20):   # step out (22 studs)
        step("SS_out"); w.push(p, near.x, near.y, 22.0); p.diving = 0.0
    tech_all(w, p)
    if not w.can_cast(p) or d > 160: return
    if p.next_m1 == 0.0 or p.next_m1 < t - 2.6: p.next_m1 = t + 2.3   # a fresh dart needs its 2.3 s charge
    if t < p.next_m1: return
    p.next_m1 += 2.6 / (1.5 if p.eclipse > t else 1.0)
    w.spend(p, "Dart", 5.0)
    dmg = DART_DMG
    if tg.mark is not None and tg.mark[1] is p:
        st = min(3, int(t - tg.mark[0]))
        if t - tg.mark[0] <= 8 and st >= 1:
            dmg += (50 if w.rng.random() < HEADSHOT else 10) * st
    if shot(w, p, tg, dmg, "Dart", "Umbra", PROJ, BODY + 0.35, d):
        if tg.mark is not None and tg.mark[1] is p: tg.mark = None
        if UMBRA_SS == "dive" and not p.ss_halved and t - p.ss_cast_t <= 2.0 and p.cd.get("SS", 0) > t:
            p.cd["SS"] = max(t, min(p.cd["SS"], p.ss_cast_t + 5.0)); p.ss_halved = True   # (a): a hit within 2 s after


def kit_voltaic(w, p):
    tg = p.tgt
    if tg is None or not w.can_cast(p): return
    t, d = w.t, dist(p, tg)
    en = w.enemies(p)
    if VOLT_SD == "manual" and w.ready(p, "SD", 0):           # P27 Static Discharge, player-cast, 12 s
        if (min(dist(p, e) for e in en) <= 8 and (w.pressured(p) or p.hp / p.maxhp < 0.5)) or                 (w.pressured(p) and p.hp / p.maxhp < 0.4):          # or just for the speed burst out of focus fire
            w.use(p, "SD", SD_CD, 0); w.static_discharge(p, False)
            return
    if w.ult_ready(p) and d <= 60:                              # Cascade r11, 5 x 14 over 1.23-1.53 s
        grp = [e for e in en if dist(e, tg) <= 11]
        if len(grp) >= 2 or tg.root > t + 1 or tg.hp / tg.maxhp < 0.6 or t > 40:
            w.use_ult(p, "Cascade"); p.busy = t + 0.5
            for e in grp:
                if e.root > t + 1.5 or e.trap > t + 1.5: k = 5
                else:
                    out = (w.react_t() + (11 - dist(e, tg)) / max(1.0, w.speed(e)) * 0.7) if w.rng.random() < AWARE else 9
                    k = sum(1 for s_ in (1.23, 1.30, 1.37, 1.47, 1.53) if s_ < out)
                for _ in range(k):
                    w.deal(p, e, 14, "Cascade", "Voltaic")
            return
    dash_ok = w.capnow(p) >= w.D["dash_min"]
    near = min(en, key=lambda e: dist(p, e))
    if dash_ok and w.ready(p, "OC", 18):                        # Overcharge: close the last 11, or get out
        if 24 < d <= 36:
            w.use(p, "OC", 9, 18); step = min(11.0, d - 20)
            p.x += (tg.x - p.x) / d * step; p.y += (tg.y - p.y) / d * step; p.prime = t + 6.0
        elif p.hp / p.maxhp < 0.3 and dist(p, near) < 10:
            w.use(p, "OC", 9, 18); w.push(p, near.x, near.y, 11.0); p.prime = t + 6.0
    tech_all(w, p)
    if not w.can_cast(p): return
    d = dist(p, tg)
    if d > CB_RANGE: return
    n = w.m1_shots(p, 0.32, 2.0, "ChainBolt")
    for _ in range(n):
        if not tg.alive: break
        if shot(w, p, tg, CB_DMG, "ChainBolt", "Voltaic", None, BODY + 0.865, d):
            legs = 3 if p.prime > t else 1
            if p.prime > t: p.prime = 0.0
            others = sorted((e for e in en if e is not tg and e.alive and dist(e, tg) <= 16), key=lambda e: dist(e, tg))
            for e in others[:legs]:
                w.deal(p, e, 5, "Chain", "Voltaic", "chain")
            if tg.alive and (w.D["ch_alone"] > 0 or others):
                w.add_charged(p, tg)


def kit_zephyr(w, p):
    tg = p.tgt
    if tg is None or not w.can_cast(p) or p.sky > w.t: return
    t, d = w.t, dist(p, tg)
    en = w.enemies(p)
    if w.ult_ready(p) and d <= 70:                              # Cyclone: pull 22, r26, 6 per 0.5 s for 4 s
        grp = [e for e in en if dist(e, tg) <= 26]
        if len(grp) >= 2 or tg.hp / tg.maxhp < 0.6 or t > 40:
            w.use_ult(p, "Cyclone"); p.busy = t + 1.2
            for e in grp:
                r = max(0.0, dist(e, tg) - 22.0)
                w.pull_to(e, tg.x, tg.y, r)
                if e.root > t or e.trap > t or w.capnow(e) < 12: inside = 4.0
                else: inside = min(4.0, w.react_t() + (26 - r) / max(1.0, w.speed(e) * 0.5))
                for _ in range(int(inside / 0.5) + 1):
                    w.deal(p, e, 6, "Cyclone", "Zephyr")
            return
    if 12 < d <= 36 and w.capnow(p) >= w.D["dash_min"] and w.ready(p, "CS", 25):   # Cross-Slash through the group
        w.use(p, "CS", 10, 25); p.busy = t + 0.6 + 0.5
        L = min(40.0, d + 4.0)
        ux, uy = (tg.x - p.x) / d, (tg.y - p.y) / d
        n = 0
        for e in en:
            ex, ey = e.x - p.x, e.y - p.y
            along = ex * ux + ey * uy; off = abs(ex * uy - ey * ux)
            if 0 < along <= L and off <= 6 and n < 4:
                if w.rng.random() < p_off(min(along, 26), None, 4.5, off, w.vlat(e), 0.0, w.vvert(e)):
                    w.deal(p, e, 30, "CS", "Zephyr"); n += 1
        p.x = max(-AX, min(AX, p.x + ux * L)); p.y = max(-AY, min(AY, p.y + uy * L))
        return
    tech_all(w, p)
    if not w.can_cast(p) or p.sky > t or d > 80: return
    n = w.m1_shots(p, 0.12, 0.8, "WindBlade")
    for _ in range(n):
        if not tg.alive: break
        shot(w, p, tg, 3, "WindBlade", "Zephyr", PROJ, BODY + 1.1, d)
        line_extra(w, p, tg, d, PROJ, BODY + 1.1, 80, 3, "WindBlade", "Zephyr", 2)


KIT = {"Aqua": kit_aqua, "Cryo": kit_cryo, "Pyro": kit_pyro, "Radiant": kit_radiant, "Terra": kit_terra,
       "Toxin": kit_toxin, "Umbra": kit_umbra, "Voltaic": kit_voltaic, "Zephyr": kit_zephyr}


# ====================================================================== one round
def fight(comp_a, comp_b, ds, hp_pass, jump, policy, seed, tech_a=None, tech_b=None):
    rng = random.Random(seed)
    w = World(comp_a, comp_b, ds, hp_pass, jump, policy, rng, tech_a, tech_b)
    A, B = w.teams
    first_death = None
    while w.t < TMAX:
        w.tick()
        if first_death is None:
            for q in w.all:
                if not q.alive: first_death = (q.team, q.el, q.role, w.t); break
        aa = any(q.alive for q in A); bb = any(q.alive for q in B)
        if not aa or not bb: break
    for ev in w.cev: w.contact_out(ev)
    w.cev = []
    aa = [q for q in A if q.alive]; bb = [q for q in B if q.alive]
    if aa and not bb: win, how = 1.0, "wipe"
    elif bb and not aa: win, how = 0.0, "wipe"
    elif not aa and not bb: win, how = 0.5, "wipe"
    else:
        sa = sum(q.hp for q in A) / sum(q.maxhp for q in A); sb = sum(q.hp for q in B) / sum(q.maxhp for q in B)
        win, how = (0.5 if abs(sa - sb) < 1e-9 else (1.0 if sa > sb else 0.0)), "time"
    ults = [[q.ult_t for q in A], [q.ult_t for q in B]]
    return w, win, how, w.t, first_death, ults
