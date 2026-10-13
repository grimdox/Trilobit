#!/usr/bin/env python3
"""Vehicles (Milestone 16, section B1): electric-only city vehicles, with Trilobit names, grouped by district tier.
usage: gen_vehicles.py <mod dir> -> <mod>/vehicles.json
Vehicles copy the stock electric designs (parts, stats) and rename them.  The 'future' look is names and (later) tiles.
"""
import json, os, sys
V = [  # id, stock base, name, tier(s), weight
    ("scooter",   "scooter_electric",         "commuter scooter",   ["poor", "mid"], 30),
    ("ebike",     "bicycle_electric",         "electric bicycle",   ["poor"], 30),
    ("cart",      "golf_cart",                "utility cart",       ["poor"], 15),
    ("micro",     "car_micro_electric",       "micro runabout",     ["poor", "mid"], 25),
    ("compact",   "scompact_electric",        "compact commuter",   ["mid"], 25),
    ("sedan",     "car_sedan_electric",       "family sedan",       ["mid"], 30),
    ("hatch",     "electric_car",             "city hatchback",     ["mid"], 25),
    ("coupe",     "car_coupe_electric",       "sport coupe",        ["mid", "rich"], 15),
    ("suv",       "suv_electric",             "crossover",          ["mid", "rich"], 15),
    ("lux_sedan", "car_sedan_luxury_electric", "executive sedan",   ["rich"], 30),
    ("lux_coupe", "car_coupe_luxury_electric", "grand tourer",      ["rich"], 20),
    ("super",     "car_super_electric",       "hypercar",           ["rich"], 5),
]
out = []
for vid, base, name, tiers, w in V:
    out.append({"type": "vehicle", "id": "trl_veh_" + vid, "copy-from": base, "name": name})
for tier in ("poor", "mid", "rich"):
    out.append({"type": "vehicle_group", "id": f"trl_veh_{tier}",
                "vehicles": [[f"trl_veh_{v[0]}", v[4]] for v in V if tier in v[3]]})
out.append({"type": "vehicle_group", "id": "trl_veh_street",
            "vehicles": [[f"trl_veh_{v[0]}", v[4]] for v in V if "poor" in v[3] or "mid" in v[3]]})
json.dump(out, open(os.path.join(sys.argv[1], "vehicles.json"), "w"), indent=1)
print(len(V), "vehicles")

# ---- mechs (section B3, Tier 1): one-tile rideable mechs.  Kumo is a light walker (spider-tank), Daikumo a heavy mech.
mechs = [
    {"type": "MONSTER", "id": "mon_trl_kumo", "copy-from": "mon_mech_recon", "name": {"str": "Kumo spider-tank"},
     "description": "A four-legged walking tank the size of a small car, with a sensor turret and a chin-mounted laser.  Its owner's lock can be hacked to accept a new pilot.",
     "categories": ["TRILOBIT"], "color": "light_cyan", "hp": 280, "speed": 110, "revert_to_itype": "trl_kumo_wreck", "default_faction": "mech_bot"},
    {"type": "MONSTER", "id": "mon_trl_daikumo", "copy-from": "mon_mech_combat", "name": {"str": "Daikumo heavy walker"},
     "description": "A heavy two-legged combat walker, armored and loud.  Slow to turn, hard to stop.",
     "categories": ["TRILOBIT"], "color": "pink", "revert_to_itype": "trl_kumo_wreck", "default_faction": "mech_bot"},
    {"type": "ITEM", "subtypes": ["GENERIC"], "id": "trl_kumo_wreck", "name": {"str": "walker wreck"},
     "description": "The burned-out frame of a walker, beyond repair.", "weight": "300 kg", "volume": "125 L", "price": "10 USD", "price_postapoc": "10 cent",
     "material": ["superalloy"], "symbol": ";", "color": "light_green", "flags": ["TRADER_AVOID", "NO_REPAIR"]},
]
out2 = json.load(open(os.path.join(sys.argv[1], "vehicles.json")))
json.dump(out2 + mechs, open(os.path.join(sys.argv[1], "vehicles.json"), "w"), indent=1)
