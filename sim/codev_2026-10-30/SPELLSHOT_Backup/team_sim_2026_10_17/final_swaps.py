"""Step 8 table from the fresh-seed confirmation runs (results_swapconfirm_S3.json, *_np.json)."""
import json, os
import team_sim as T

HERE = os.path.dirname(os.path.abspath(__file__))
A = json.load(open(os.path.join(HERE, "results_swapconfirm_S3.json")))["jobs"]
B = json.load(open(os.path.join(HERE, "results_swapconfirm_S3_np.json")))["jobs"]
picks = json.load(open(os.path.join(HERE, "swap_picks_S3.json")))
NAMES = {"TT": "Twin Tide", "SA": "Sidearm", "BZ": "Blizzard", "DF": "Deep Freeze", "DT": "Detonate", "LS": "Scorching Lash",
         "PT": "Position Trade", "BN": "Benediction", "AS": "Aftershock", "BW": "Bulwark Wall", "AV": "Antitoxin Vent",
         "AR": "Acid Rain", "MK": "Mark", "DD": "Decoy Double", "RS": "Railspike", "VO": "Volt Orb", "SK": "Skyrider", "GP": "Gust Pad"}
RXN = {("Cryo", ("BZ", "RS")): "Shatter", ("Pyro", ("DT", "VO")): "Overload", ("Toxin", ("LS", "AR")): "Combustion",
       ("Voltaic", ("LS", "VO")): "Overload", ("Zephyr", ("LS", "GP")): "Wildfire", ("Aqua", ("LS", "VO")): "Overload",
       ("Terra", ("LS", "VO")): "Overload", ("Radiant", ("LS", "VO")): "Overload"}


def get(R, el, tech, suf):
    os_ = [R[f"P|1|A|{pol}|{el}|S3|{'+'.join(tech)}{suf}"] for pol in ("low", "soft")]
    n = sum(o["n"] for o in os_)
    rx = sum(v for o in os_ for k, v in o["st"].get("rx", {}).items() if k.startswith("A|")) / n
    return sum(o["win"] for o in os_) / n, rx, [o["win"] / o["n"] for o in os_]


def lo(tech): return " + ".join(NAMES[k] for k in tech)


print("| Mono | Default vs S3 | Swap | Reaction it adds | Played for the combo | Cast on cooldown | Reactions/round |")
print("|---|---|---|---|---|---|---|")
for el in T.ELS:
    d = get(A, el, T.TECH[el], "|confirm")
    techs = [tuple(x) for x in picks.get(el, [])]
    if not techs:
        print(f"| {el} | {100 * d[0]:.0f}% | none | — | — | — | — |"); continue
    for tech in techs:
        a = get(A, el, tech, "|confirm"); b = get(B, el, tech, "|confirm_np")
        rx = RXN.get((el, tech), "none (raw power)")
        two = sum(1 for k in tech if k not in T.TECH[el]) == 2
        print(f"| {el} | {100 * d[0]:.0f}% | {lo(tech)}{' (both slots)' if two else ''} | {rx} | "
              f"{100 * a[0]:.0f}% ({100 * a[2][0]:.0f}/{100 * a[2][1]:.0f}) | {100 * b[0]:.0f}% ({100 * b[2][0]:.0f}/{100 * b[2][1]:.0f}) | "
              f"{a[1]:.1f} / {b[1]:.1f} |")
