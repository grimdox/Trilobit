#!/usr/bin/env python3
"""Disable fungal, triffid, ant, spider, slime, bee/wasp/dermatik, Mi-Go and Exodii overmap specials and their map extras.
usage: gen_no_aliens.py <mod dir> <cdda data/json dir>   (occurrences [0,0] removes a special from world generation)"""
import json, glob, os, sys
MOD, STOCK = sys.argv[1], sys.argv[2]
BAN_FLAGS = {"FUNGAL", "TRIFFID", "ANT", "SPIDER", "SLIME", "BEE", "WASP", "DERMATIK", "MI-GO", "EXODII"}
BAN_IDS = {"void_spider_lair", "labyrinthine_structure", "nuclear power plant"}   # the stock plant is replaced by trl_nuclear_station (gen_grid.py)
out, seen = [], set()
for f in sorted(glob.glob(os.path.join(STOCK, "overmap/**/*.json"), recursive=True)):
    try: d = json.load(open(f))
    except Exception: continue
    for o in d:
        if isinstance(o, dict) and o.get("type") == "overmap_special":
            if (BAN_FLAGS & set(o.get("flags", []))) or o["id"] in BAN_IDS:
                if o["id"] in seen: continue
                seen.add(o["id"])
                if o.get("subtype") == "mutable":
                    # mutable specials cannot copy-from; replace with an inert fixed special that never places
                    out.append({"type": "overmap_special", "id": o["id"], "subtype": "fixed", "locations": ["forest"],
                                "overmaps": [{"point": [0, 0, 0], "overmap": "forest"}], "occurrences": [0, 0],
                                "flags": ["WILDERNESS"]})
                else:
                    out.append({"type": "overmap_special", "id": o["id"], "copy-from": o["id"], "occurrences": [0, 0]})
EXTRAS = ["mx_fungal_zone", "mx_marloss_pilgrimage", "mx_nest_wasp", "mx_spider", "mx_house_spider", "mx_house_wasp",
          "mx_Trapdoor_spider_den", "mx_nest_dermatik", "mx_beehive_natural", "mx_worm_sign", "mx_jabberwock", "mx_portal",
          "mx_portal_in", "mx_exocrash_1", "mx_exocrash_2", "mx_crater", "mx_golden_monoliths", "mx_dormant", "mx_toxic_waste",
          "mx_mass_grave", "mx_bugout", "mx_looters"]
rs = json.load(open(os.path.join(STOCK, "regional_map_settings.json")))
region = next(r for r in rs if r.get("type") == "region_settings")
zones = {}
for z, v in region["map_extras"].items():
    for e in EXTRAS:
        if e in v.get("extras", {}): zones.setdefault(z, {})[e] = 0
out.append({"type": "region_overlay", "regions": ["all"], "map_extras": {z: {"extras": ex} for z, ex in zones.items()}})
json.dump(out, open(os.path.join(MOD, "no_aliens.json"), "w"), indent=1)
print(len(seen), "specials disabled:", sorted(seen)); print(sum(len(v) for v in zones.values()), "extra entries zeroed")
