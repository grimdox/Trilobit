#!/usr/bin/env python3
"""The electric fleet (Milestone 23): 31 more vehicles on top of gen_vehicles.py's 12.  Run AFTER gen_vehicles.py.
usage: gen_fleet.py <mod dir> <stock tree> -> <mod>/fleet.json, and extends the trl_veh_* groups in vehicles.json
Each vehicle is a stock design rebuilt as an electric one: combustion engines become electric motors, fuel tanks become
battery banks, and alternators, mufflers and lead-acid starter batteries are dropped.  Names are Trilobit's own.
"""
import copy, glob, json, os, sys
MOD, STOCK = sys.argv[1], sys.argv[2]
# id, stock base, name, size (S two-wheel, M car, L truck/bus), tiers it spawns in on the street ([] = specials only), weight
FLEET = [
    ("kaze",     "motorcycle",                    "Kaze street bike",         "S", ["mid"], 15),
    ("dune",     "motorcycle_cross",              "Dune trail bike",          "S", ["poor", "mid"], 10),
    ("ridge",    "motorcycle_enduro",             "Ridge enduro",             "S", ["poor", "mid"], 10),
    ("trio",     "motorcycle_3wheel",             "Trio cargo trike",         "S", ["poor"], 12),
    ("pod",      "scompact_tandem_electric_stow", "Tandem pod",               "M", ["poor", "mid"], 10),
    ("shuttle",  "golf_cart_4seat",               "Resort shuttle",           "M", ["poor", "mid"], 10),
    ("tourer",   "car_shootingbrake_electric",    "Wagon tourer",             "M", ["mid"], 18),
    ("longtour", "car_shootingbrake_long_electric", "Long wagon",             "M", ["mid", "rich"], 10),
    ("sportsed", "car_sedan_sports_electric",     "Sport sedan",              "M", ["mid", "rich"], 12),
    ("track",    "car_coupe_sports_electric",     "Track coupe",              "M", ["rich"], 8),
    ("roadster", "car_sports_electric",           "Roadster",                 "M", ["rich"], 8),
    ("expedit",  "suv_electric_rack",             "Expedition crossover",     "M", ["mid"], 10),
    ("hypergt",  "car_super_electric_alt",        "Hypercar GT",              "M", ["rich"], 3),
    ("minivan",  "van_mini",                      "Courier minivan",          "M", ["poor", "mid"], 18),
    ("cargovan", "van_cargo",                     "Cargo van",                "L", ["poor", "mid"], 15),
    ("boxtruck", "cube_van",                      "Box delivery truck",       "L", ["poor", "mid"], 12),
    ("coldvan",  "fridge_van",                    "Cold-chain van",           "L", ["mid"], 6),
    ("camper",   "van_camper",                    "Camper van",               "L", ["mid"], 5),
    ("citybus",  "bus",                           "City bus",                 "L", ["poor", "mid"], 6),
    ("shutbus",  "schoolbus",                     "Shuttle bus",              "L", ["poor"], 5),
    ("pickup",   "pickup",                        "Work pickup",              "M", ["poor", "mid"], 18),
    ("crewpick", "extended_pickup",               "Crew pickup",              "M", ["mid"], 12),
    ("famipick", "4seat_pickup",                  "Family pickup",            "M", ["mid"], 10),
    ("flatbed",  "flatbed_truck",                 "Flatbed hauler",           "L", ["poor", "mid"], 8),
    ("heavy",    "tatra_truck",                   "Heavy hauler",             "L", ["poor"], 4),
    ("freight",  "semi_truck",                    "Freight tractor",          "L", ["mid"], 3),
    ("tow",      "underlift_tow_truck",           "Tow truck",                "L", ["poor"], 4),
    ("riot",     "truck_swat",                    "Riot response truck",      "L", [], 0),
    ("secvan",   "security_van",                  "Security van",             "L", [], 0),
    ("fireeng",  "fire_truck",                    "Fire engine",              "L", [], 0),
    ("armored",  "military_cargo_truck",          "Armored transport",        "L", [], 0),
]
assert len(FLEET) == 31 and len({f[0] for f in FLEET}) == 31

stock = {}
for f in glob.glob(os.path.join(STOCK, "data/json/vehicles/*.json")):
    for o in json.load(open(f)):
        if o.get("type") == "vehicle" and ("id" in o or "abstract" in o):
            stock[o.get("id") or o["abstract"]] = o

def resolve(i, depth=0):
    """a stock vehicle with its copy-from chain flattened (child parts and items are added to the parent's)"""
    v = copy.deepcopy(stock[i])
    if "copy-from" in v and v["copy-from"] in stock:
        p = resolve(v["copy-from"], depth + 1)
        for k in ("parts", "items"):
            if k in v or k in p:
                p[k] = p.get(k, []) + v.get(k, [])
        for k in v:
            if k not in ("parts", "items", "copy-from"):
                p[k] = v[k]
        v = p
    return v


ENGINE = {"S": "engine_electric_small", "M": "engine_electric", "L": "engine_electric_large"}
BATT = {"S": "medium_storage_battery", "M": "storage_battery", "L": "large_storage_battery"}
DROP = ("alternator_", "battery_car", "battery_motorbike", "muffler")
IS_ENGINE = lambda p: isinstance(p, str) and (p.startswith(("engine_", "diesel_engine_")) and not p.startswith("engine_electric"))


def convert(v, size):
    parts, had_batt, had_engine = [], False, False
    for cell in copy.deepcopy(v["parts"]):
        new = []
        for p in cell.get("parts", []):
            name = p["part"] if isinstance(p, dict) else p
            if name.startswith(DROP):
                continue
            if IS_ENGINE(name):
                new.append(ENGINE[size]); had_engine = True; continue
            if isinstance(p, dict) and p.get("part", "").startswith("tank") and p.get("fuel") in ("gasoline", "diesel", "ethanol", "jp8", "biodiesel"):
                new.append(BATT[size]); had_batt = True; continue
            if "storage_battery" in name:
                had_batt = True
            if name.startswith("engine_electric"):
                had_engine = True
            new.append(p)
        if new:
            cell["parts"] = new
            parts.append(cell)
    if not had_batt:                              # a motor with no battery bank: put one beside the motor
        for cell in parts:
            if any(isinstance(p, str) and p.startswith("engine_electric") for p in cell["parts"]):
                cell["parts"].append(BATT[size]); break
    return parts, had_engine


out, tiers, big = [], {}, []
for vid, base, name, size, tr, w in FLEET:
    v = resolve(base)
    if "parts" not in v:
        raise SystemExit(f"{base}: no parts (abstract?)")
    parts, ok = convert(v, size)
    assert ok or any("electric" in str(c) for c in parts), base
    o = {"type": "vehicle", "id": "trl_veh_" + vid, "name": name, "parts": parts}
    for k in ("items", "fuel"):
        if k in v:
            o[k] = v[k]
    out.append(o)
    xs = [c["x"] for c in parts]; ys = [c["y"] for c in parts]
    length, width = max(xs) - min(xs) + 1, max(ys) - min(ys) + 1
    if length > 7 or width > 4:                   # street and lot spawns only fit short vehicles
        big.append(f"{vid}({length}x{width})")
        tr = []
    for t in tr:
        tiers.setdefault(t, []).append(["trl_veh_" + vid, w])
json.dump(out, open(os.path.join(MOD, "fleet.json"), "w"), indent=1)

# add the new vehicles to the district groups made by gen_vehicles.py (idempotent)
path = os.path.join(MOD, "vehicles.json")
vj = json.load(open(path))
street = []
for g in vj:
    if g.get("type") == "vehicle_group" and g["id"].startswith("trl_veh_"):
        tier = g["id"][8:]
        add = tiers.get(tier) if tier != "street" else (tiers.get("poor", []) + [x for x in tiers.get("mid", []) if x not in tiers.get("poor", [])])
        g["vehicles"] = [e for e in g["vehicles"] if not e[0].split("trl_veh_")[1] in {f[0] for f in FLEET}] + (add or [])
json.dump(vj, open(path, "w"), indent=1)
print("too long for street spawns:", ", ".join(big))
print(len(out), "fleet vehicles;", {t: len(v) for t, v in tiers.items()})
