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
items = []
for o in json.load(open(os.path.join(MOD, "gunset.json"))):
    if o.get("type") != "ITEM":
        continue
    code = o["id"][len("trl_gun_"):]
    items.append({"id": o["id"], "name": o["name"]["str"], "desc": o["description"], "weight_g": grams(o["weight"]),
                  "volume_ml": grams(o["weight"]) // 2, "length_mm": LEN.get(cls[code], 600), "price": int(o["price"].split()[0]),
                  "tags": ["gun", cls[code].lower().replace(" ", "_")]})
# containers: the pocket model
P = lambda i, vol, wt, flex=False, tags=None, water=False, length=0: {"id": i, "max_volume_ml": vol, "max_weight_g": wt, "flexible": flex,
                                                                    "allow_tags": tags or [], "watertight": water, "max_item_length_mm": length}
items += [
    {"id": "trl_backpack", "name": "commuter backpack", "weight_g": 700, "volume_ml": 1500, "length_mm": 450, "price": 120, "tags": ["container", "worn"],
     "pockets": [P("main", 22000, 15000, True), P("side", 1500, 3000, False, ["bottle"], False, 300)]},
    {"id": "trl_holster", "name": "thigh holster", "weight_g": 250, "volume_ml": 400, "length_mm": 300, "price": 60, "tags": ["container", "worn"],
     "pockets": [P("holster", 600, 2500, False, ["pistol", "revolver"], False, 260)]},
    {"id": "trl_coat", "name": "long coat", "weight_g": 1400, "volume_ml": 3000, "length_mm": 800, "price": 300, "tags": ["container", "worn"],
     "pockets": [P("inner", 2500, 4000, True), P("left", 600, 1000, True), P("right", 600, 1000, True)]},
    {"id": "trl_pouch", "name": "belt pouch", "weight_g": 120, "volume_ml": 250, "length_mm": 180, "price": 20, "tags": ["container"],
     "pockets": [P("main", 1200, 2000, True)]},
    {"id": "trl_duffel", "name": "duffel bag", "weight_g": 900, "volume_ml": 1800, "length_mm": 700, "price": 80, "tags": ["container"],
     "pockets": [P("main", 55000, 30000, True)]},
    {"id": "trl_water_bottle", "name": "water bottle", "weight_g": 80, "volume_ml": 600, "length_mm": 230, "price": 5, "tags": ["container", "bottle"],
     "pockets": [P("liquid", 500, 600, False, ["liquid"], True, 0)]},
    {"id": "trl_water", "name": "water", "weight_g": 1, "volume_ml": 1, "length_mm": 0, "price": 0, "tags": ["liquid"], "per_unit": True},
    {"id": "trl_ration", "name": "cyber ration bar", "weight_g": 90, "volume_ml": 80, "length_mm": 150, "price": 15, "tags": ["food"]},
    {"id": "trl_credstick", "name": "credstick", "weight_g": 10, "volume_ml": 4, "length_mm": 80, "price": 0, "tags": ["card"]},
]
json.dump(items, open(os.path.join(HERE, "../data/items.json"), "w"), indent=1)
print(len(items), "items exported")
