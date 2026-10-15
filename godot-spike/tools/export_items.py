#!/usr/bin/env python3
"""Export Trilobit's CDDA-side content tables into the Godot spike's item schema (data/items.json).
Shows that the generated content transfers: the 50 new guns (gunset.json) become engine-neutral records, plus a few containers
that exercise the pocket model.  usage: export_items.py  (run from godot-spike/)"""
import json, os, re
HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.join(HERE, "../../data/mods/trilobit")
LEN = {"SMG": 450, "Pistol": 200, "Revolver": 220, "Rifle": 900, "Shotgun": 950, "Sniper": 1100, "MG": 1000, "Heavy MG": 1300, "Launcher": 800, "Laser": 700}


def grams(s):
    m = re.match(r"([\d.]+)\s*(kg|g)", s)
    return int(float(m.group(1)) * (1000 if m.group(2) == "kg" else 1))


names = {}
src = open(os.path.join(HERE, "../../trilobit-tools/gen_gunset.py")).read()
ns = {"__file__": os.path.join(HERE, "../../trilobit-tools/gen_gunset.py")}
import sys
sys.argv = ["x", "/tmp"]
exec(src.split("out = []")[0], ns)
cls = {g[0]: g[4] for g in ns["GUNS"]}
base = {g[0]: g[3] for g in ns["GUNS"]}
# class table: damage range, effective range in tiles, base accuracy (percent), caliber, magazine, fire modes [name, shots], recoil per extra shot,
# report radius (how far a shot is heard, in tiles), reload turns, pellets per shot, mod slots, jam chance (percent per trigger pull)
SL = ["optic", "muzzle", "barrel", "mag", "under", "stock"]
GUN = {"SMG": {"dmg": [7, 11], "range": 12, "acc": 62, "cal": "9mm", "mag": 25, "modes": [["single", 1], ["burst", 3], ["auto", 6]], "recoil": 4, "noise": 16, "reload": 1, "pellets": 1, "slots": ["optic", "muzzle", "mag", "under", "stock"], "jam": 1.0},
       "Pistol": {"dmg": [10, 16], "range": 10, "acc": 70, "cal": "9mm", "mag": 12, "modes": [["single", 1]], "recoil": 3, "noise": 14, "reload": 1, "pellets": 1, "slots": ["optic", "muzzle", "mag", "under"], "jam": 0.6},
       "Revolver": {"dmg": [14, 22], "range": 10, "acc": 72, "cal": ".357", "mag": 6, "modes": [["single", 1]], "recoil": 5, "noise": 18, "reload": 3, "pellets": 1, "slots": ["optic", "muzzle", "under"], "jam": 0.1},
       "Rifle": {"dmg": [16, 24], "range": 18, "acc": 74, "cal": "5.56", "mag": 30, "modes": [["single", 1], ["burst", 3]], "recoil": 4, "noise": 20, "reload": 2, "pellets": 1, "slots": ["optic", "muzzle", "barrel", "mag", "under", "stock"], "jam": 0.8},
       "Shotgun": {"dmg": [20, 34], "range": 6, "acc": 80, "cal": "12ga", "mag": 6, "modes": [["single", 1]], "recoil": 6, "noise": 22, "reload": 3, "pellets": 8, "slots": ["optic", "barrel", "under", "stock"], "jam": 0.8},
       "Sniper": {"dmg": [30, 48], "range": 30, "acc": 82, "cal": ".338", "mag": 5, "modes": [["single", 1]], "recoil": 6, "noise": 24, "reload": 2, "pellets": 1, "slots": ["optic", "muzzle", "barrel", "under", "stock"], "jam": 0.5},
       "MG": {"dmg": [12, 18], "range": 16, "acc": 55, "cal": "7.62", "mag": 50, "modes": [["burst", 4], ["auto", 8]], "recoil": 3, "noise": 22, "reload": 4, "pellets": 1, "slots": ["optic", "muzzle", "under", "stock"], "jam": 1.5},
       "Heavy MG": {"dmg": [16, 24], "range": 20, "acc": 55, "cal": "12.7", "mag": 60, "modes": [["burst", 5], ["auto", 10]], "recoil": 3, "noise": 26, "reload": 5, "pellets": 1, "slots": ["optic", "muzzle"], "jam": 1.5},
       "Launcher": {"dmg": [40, 70], "range": 14, "acc": 65, "cal": "40mm", "mag": 1, "modes": [["single", 1]], "recoil": 0, "noise": 24, "reload": 2, "pellets": 1, "slots": ["optic", "under"], "jam": 0.5},
       "Laser": {"dmg": [14, 22], "range": 15, "acc": 78, "cal": "cell", "mag": 12, "modes": [["single", 1], ["burst", 2]], "recoil": 1, "noise": 8, "reload": 1, "pellets": 1, "slots": ["optic", "under"], "jam": 0.0}}
import zlib
items = []
for o in json.load(open(os.path.join(MOD, "gunset.json"))):
    if o.get("type") != "ITEM":
        continue
    code = o["id"][len("trl_gun_"):]
    gun = json.loads(json.dumps(GUN[cls[code]]))
    h = zlib.crc32(code.encode())
    gun["acc"] += (h % 9) - 4                       # every model handles a little differently
    gun["dmg"] = [gun["dmg"][0] + (h >> 4) % 3 - 1, gun["dmg"][1] + (h >> 6) % 3 - 1]
    if gun["mag"] > 1:
        gun["mag"] += ((h >> 8) % 5 - 2) * max(1, gun["mag"] // 12)
    items.append({"id": o["id"], "name": o["name"]["str"], "desc": o["description"], "weight_g": grams(o["weight"]),
                  "volume_ml": grams(o["weight"]) // 2, "length_mm": LEN.get(cls[code], 600), "price": int(o["price"].split()[0]),
                  "tags": ["gun", cls[code].lower().replace(" ", "_")], "looks_like": base[code], "gun": gun})
# ammunition: one item per caliber and kind; a box holds `rounds`.  kind modifiers live in the game (gunplay.gd).
AMMO = [("9mm", ["fmj", "ap", "hp"], 18, 14), (".357", ["fmj", "ap", "hp"], 12, 18), ("5.56", ["fmj", "ap", "hp"], 20, 24), ("12ga", ["shot", "slug"], 10, 20),
        (".338", ["fmj", "ap"], 10, 40), ("7.62", ["fmj", "ap"], 30, 30), ("12.7", ["fmj", "ap"], 20, 50), ("40mm", ["he"], 3, 45), ("cell", ["cell"], 20, 30)]
KINDN = {"fmj": "ball", "ap": "armor-piercing", "hp": "hollow-point", "shot": "buckshot", "slug": "slug", "he": "HE grenade", "cell": "charge pack"}
for cal, kinds, rounds, price in AMMO:
    for k in kinds:
        items.append({"id": "trl_ammo_%s_%s" % (cal.replace(".", ""), k), "name": "%s %s box" % (cal, KINDN[k]), "weight_g": rounds * 10, "volume_ml": rounds * 6, "length_mm": 80,
                      "price": price * (2 if k == "ap" else 1), "tags": ["ammo"], "looks_like": "9mm", "ammo": {"cal": cal, "kind": k, "rounds": rounds}})
# gun mods.  effects: acc (flat, percentage points), aim (extra bonus per aiming turn), hip (bonus when not aiming), range_pct, rangepen_pct (less accuracy lost per tile),
# close_pen (penalty inside 4 tiles), recoil_pct, noise_cap (shots are heard no further than this), dmg_pct, mag_pct, jam (percentage points), reload (turns), spread_pct
MODS = [
    ("redot", "red-dot sight", "optic", {"acc": 5, "aim": 1}, 90, 120, "Fast, forgiving.  A little steadier on the first aimed turn."),
    ("holo", "holographic sight", "optic", {"acc": 7, "aim": 2, "rangepen_pct": 15}, 150, 220, "Wide window, bright reticle."),
    ("scope4", "4x scope", "optic", {"acc": 8, "aim": 3, "range_pct": 30, "rangepen_pct": 40, "close_pen": 8}, 300, 400, "Reaches out; clumsy up close."),
    ("scope8", "8x sniper scope", "optic", {"acc": 10, "aim": 5, "range_pct": 70, "rangepen_pct": 65, "close_pen": 18}, 700, 900, "For long streets and rooftops.  Useless at arm's length."),
    ("smartlink", "smartlink sight", "optic", {"acc": 12, "aim": 3, "hip": 6, "rangepen_pct": 30}, 600, 1100, "Reads your optic nerve.  The gun knows where you are looking."),
    ("laser", "laser sight", "under", {"hip": 10, "close_pen": -4}, 70, 80, "A red dot on the target.  Helps most when you are not taking time to aim."),
    ("foregrip", "foregrip", "under", {"recoil_pct": -25, "acc": 2}, 40, 150, "Hold it down in bursts."),
    ("bipod", "folding bipod", "under", {"recoil_pct": -15, "aim": 2, "acc": 3}, 80, 500, "Steadies a long gun if you are not walking."),
    ("suppressor", "suppressor", "muzzle", {"noise_cap": 5, "dmg_pct": -6, "range_pct": -5, "jam": 0.2}, 500, 350, "Quiet shots.  Nobody comes to look."),
    ("compensator", "compensator", "muzzle", {"recoil_pct": -30, "noise_cap": 99}, 120, 200, "Tames the muzzle."),
    ("flashhider", "flash hider", "muzzle", {"recoil_pct": -10, "acc": 1}, 60, 100, "A little less climb, a little less glare."),
    ("longbarrel", "long barrel", "barrel", {"acc": 4, "range_pct": 25, "dmg_pct": 6}, 160, 450, "More velocity and more reach."),
    ("shortbarrel", "short barrel", "barrel", {"acc": -3, "range_pct": -20, "close_pen": -6, "reload": 0}, 90, 250, "Handy in corridors."),
    ("choke", "choke tube", "barrel", {"spread_pct": -35, "range_pct": 20}, 100, 120, "Tighter pattern, more reach."),
    ("extmag", "extended magazine", "mag", {"mag_pct": 50, "jam": 0.3}, 110, 120, "Half again as many rounds."),
    ("drum", "drum magazine", "mag", {"mag_pct": 150, "jam": 1.5, "reload": 1, "acc": -2}, 260, 400, "Lots of lead; slow to swap, fond of jamming."),
    ("quickmag", "quick-release magazine", "mag", {"reload": -1}, 70, 90, "Swaps in a heartbeat."),
    ("stock", "adjustable stock", "stock", {"recoil_pct": -20, "acc": 3}, 90, 450, "Solid against the shoulder."),
    ("cheekrest", "cheek rest and padded stock", "stock", {"recoil_pct": -30, "aim": 2, "acc": 2}, 160, 700, "Built for precision."),
]
for mid, name, slot, eff, price, wt, desc in MODS:
    items.append({"id": "trl_mod_" + mid, "name": name, "desc": desc, "weight_g": wt, "volume_ml": max(40, wt // 2), "length_mm": 150, "price": price,
                  "tags": ["mod"], "looks_like": "scope", "mod": {"slot": slot, "fx": eff}})
# containers: the pocket model
P = lambda i, vol, wt, flex=False, tags=None, water=False, length=0: {"id": i, "max_volume_ml": vol, "max_weight_g": wt, "flexible": flex,
                                                                    "allow_tags": tags or [], "watertight": water, "max_item_length_mm": length}
items += [
    {"id": "trl_backpack", "name": "commuter backpack", "weight_g": 700, "volume_ml": 1500, "length_mm": 450, "price": 120, "tags": ["container", "worn"], "looks_like": "backpack",
     "pockets": [P("main", 22000, 15000, True), P("side", 1500, 3000, False, ["bottle"], False, 300)]},
    {"id": "trl_holster", "name": "thigh holster", "weight_g": 250, "volume_ml": 400, "length_mm": 300, "price": 60, "tags": ["container", "worn"], "looks_like": "holster",
     "pockets": [P("holster", 600, 2500, False, ["pistol", "revolver"], False, 260)]},
    {"id": "trl_coat", "name": "long coat", "weight_g": 1400, "volume_ml": 3000, "length_mm": 800, "price": 300, "tags": ["container", "worn"], "looks_like": "trenchcoat",
     "pockets": [P("inner", 2500, 4000, True), P("left", 600, 1000, True), P("right", 600, 1000, True)]},
    {"id": "trl_pouch", "name": "belt pouch", "weight_g": 120, "volume_ml": 250, "length_mm": 180, "price": 20, "tags": ["container"], "looks_like": "chestpouch",
     "pockets": [P("main", 1200, 2000, True)]},
    {"id": "trl_duffel", "name": "duffel bag", "weight_g": 900, "volume_ml": 1800, "length_mm": 700, "price": 80, "tags": ["container"], "looks_like": "duffelbag",
     "pockets": [P("main", 55000, 30000, True)]},
    {"id": "trl_water_bottle", "name": "water bottle", "weight_g": 80, "volume_ml": 600, "length_mm": 230, "price": 5, "tags": ["container", "bottle"], "looks_like": "bottle_plastic",
     "pockets": [P("liquid", 500, 600, False, ["liquid"], True, 0)]},
    {"id": "trl_yen", "name": "yen notes", "weight_g": 1, "volume_ml": 1, "length_mm": 0, "price": 1, "tags": ["money"], "looks_like": "money_bundle_hundred"},
    {"id": "trl_ammo", "name": "ammo box", "weight_g": 120, "volume_ml": 70, "length_mm": 60, "price": 20, "tags": ["ammo"], "looks_like": "9mm", "ammo": {"cal": "9mm", "kind": "fmj", "rounds": 12}},
    {"id": "trl_water", "name": "water", "weight_g": 1, "volume_ml": 1, "length_mm": 0, "price": 0, "tags": ["liquid"], "per_unit": True},
    {"id": "trl_ration", "name": "cyber ration bar", "weight_g": 90, "volume_ml": 80, "length_mm": 150, "price": 15, "tags": ["food"], "looks_like": "granola"},
    {"id": "trl_parcel", "name": "sealed parcel", "weight_g": 600, "volume_ml": 1500, "length_mm": 250, "price": 0, "tags": ["job"], "looks_like": "box_small"},
    {"id": "trl_datacase", "name": "encrypted data case", "weight_g": 1800, "volume_ml": 6000, "length_mm": 420, "price": 400, "tags": ["job"], "looks_like": "briefcase"},
    {"id": "trl_medkit", "name": "trauma patch", "weight_g": 120, "volume_ml": 100, "length_mm": 120, "price": 40, "tags": ["medical"], "looks_like": "bandages"},
    {"id": "trl_credstick", "name": "credstick", "weight_g": 10, "volume_ml": 4, "length_mm": 80, "price": 0, "tags": ["card"], "looks_like": "cash_card"},
]
json.dump(items, open(os.path.join(HERE, "../data/items.json"), "w"), indent=1)
print(len(items), "items exported")
