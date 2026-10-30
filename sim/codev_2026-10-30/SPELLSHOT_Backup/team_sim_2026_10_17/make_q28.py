"""P28 (Twin Tide cover) + P29 (cursor-targeting) run list. Every run: package v3 + the live Cryo fix (SIM_CRYO_LIVE)."""
import json, os
HERE = os.path.dirname(os.path.abspath(__file__))
V3 = json.load(open(os.path.join(HERE, "pkg_tm3.json")))
LIVE = {"SIM_CRYO_LIVE": "1"}
RUNS = {
    "base": {}, "base_b": {"SIM_SEED_SALT": "1"},
    # P28 as specced: the live footprint (walls ~1.7 s), now blocking shots
    "tt_a150": {"SIM_TT_WALL": "a", "SIM_TT_HP": "150"}, "tt_a200": {"SIM_TT_WALL": "a", "SIM_TT_HP": "200"},
    "tt_a250": {"SIM_TT_WALL": "a", "SIM_TT_HP": "250"},
    "tt_b100": {"SIM_TT_WALL": "b", "SIM_TT_HP": "100"}, "tt_b125": {"SIM_TT_WALL": "b", "SIM_TT_HP": "125"},
    "tt_c150": {"SIM_TT_WALL": "c", "SIM_TT_HP": "150"}, "tt_c200": {"SIM_TT_WALL": "c", "SIM_TT_HP": "200"},
    "tt_c250": {"SIM_TT_WALL": "c", "SIM_TT_HP": "250"},
    # addition: the met walls stand on (3 s, 6 s) -- the live walls are gone in ~1.7 s
    "tt_a200_h3": {"SIM_TT_WALL": "a", "SIM_TT_HP": "200", "SIM_TT_HOLD": "3"},
    "tt_b100_h3": {"SIM_TT_WALL": "b", "SIM_TT_HP": "100", "SIM_TT_HOLD": "3"},
    "tt_c200_h3": {"SIM_TT_WALL": "c", "SIM_TT_HP": "200", "SIM_TT_HOLD": "3"},
    "tt_a200_h6": {"SIM_TT_WALL": "a", "SIM_TT_HP": "200", "SIM_TT_HOLD": "6"},
    # P29 (a) straight conversions
    "ff15": {"SIM_FF_RANGE": "15"}, "ff20": {"SIM_FF_RANGE": "20"}, "ff25": {"SIM_FF_RANGE": "25"},
    "bz20": {"SIM_BZ_RANGE": "20"}, "bz32": {"SIM_BZ_RANGE": "32"}, "bz45": {"SIM_BZ_RANGE": "45"},
    "df10": {"SIM_DF_RANGE": "10"}, "df20": {"SIM_DF_RANGE": "20"}, "df30": {"SIM_DF_RANGE": "30"},
    "as15": {"SIM_AS_RANGE": "15"}, "as24": {"SIM_AS_RANGE": "24"}, "as35": {"SIM_AS_RANGE": "35"},
    "bn20": {"SIM_BN_RANGE": "20"}, "bn35": {"SIM_BN_RANGE": "35"}, "bn50": {"SIM_BN_RANGE": "50"},
    "cryo_all": {"SIM_FF_RANGE": "20", "SIM_BZ_RANGE": "32", "SIM_DF_RANGE": "20"},
    # P29 (b) conversions with a trade-off
    "ff20_r14": {"SIM_FF_RANGE": "20", "SIM_FF_R": "14"}, "ff20_wind": {"SIM_FF_RANGE": "20", "SIM_FF_LEAD": "0.78"},
    "ff20_frz25": {"SIM_FF_RANGE": "20", "SIM_FF_FREEZE": "2.5"},
    "bz32_r24": {"SIM_BZ_RANGE": "32", "SIM_BZ_R": "24"}, "bz32_dur4": {"SIM_BZ_RANGE": "32", "SIM_BZ_DUR": "4"},
}
ORDER = ["base", "base_b", "ff20", "tt_a200", "tt_b100", "tt_c200", "bz32", "df20", "as24", "bn35",
         "tt_a200_h3", "ff15", "ff25", "tt_a150", "tt_a250", "tt_b125", "tt_c150", "tt_c250", "bz20", "bz45",
         "df10", "df30", "as15", "as35", "bn20", "bn50", "tt_b100_h3", "tt_c200_h3", "tt_a200_h6", "cryo_all",
         "ff20_r14", "ff20_wind", "ff20_frz25", "bz32_r24", "bz32_dur4"]
assert sorted(ORDER) == sorted(RUNS), set(RUNS) ^ set(ORDER)
for tag, ov in RUNS.items():
    json.dump(dict(V3, **LIVE, **ov), open(os.path.join(HERE, f"pkg_q28_{tag}.json"), "w"), indent=1)
open(os.path.join(HERE, "queue_q28.txt"), "w").write("\n".join(f"q28_{t} rr84" for t in ORDER) + "\n")
print(len(ORDER), "runs")
