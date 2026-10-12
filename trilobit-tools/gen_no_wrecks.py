#!/usr/bin/env python3
"""Remove road wrecks, pileups, crash chunks and vehicle map extras. usage: gen_no_wrecks.py <mod dir> <cdda data/json dir>
Nested chunks are 'replaced' by adding an empty chunk of the same id with an enormous weight (nested mapgen picks by weight)."""
import json, glob, re, sys, os
MOD, STOCK = sys.argv[1], sys.argv[2]
PAT = re.compile(r"vehicle|carcrash|wreck|crash|parking|parked|pileup|jack-knifed")
nested = {}
def walk(o):
    if isinstance(o, list):
        for x in o: walk(x)
    elif isinstance(o, dict):
        if o.get("type") == "mapgen" and o.get("nested_mapgen_id"):
            nested.setdefault(o["nested_mapgen_id"], 0)
            if "place_vehicles" in json.dumps(o): nested[o["nested_mapgen_id"]] = 1
for f in glob.glob(os.path.join(STOCK, "mapgen/**/*.json"), recursive=True):
    try: walk(json.load(open(f)))
    except Exception: pass
# every road-vehicle chunk, plus any nested chunk with a vehicle-ish name that actually places vehicles or is a crash/wreck
ids = sorted(i for i, hasv in nested.items() if PAT.search(i) and (hasv or i.startswith("24x24_road_") or i.startswith("24x24_bridge")))
ids = [i for i in ids if not i.startswith("nest_exodii")]    # alien wrecks are handled by removing the crash extras
out = [{"type": "mapgen", "nested_mapgen_id": i, "weight": 1000000000,
        "object": {"mapgensize": [24, 24] if i.startswith("24x24") else [1, 1], "rotation": [0]}} for i in ids]
# vehicle map extras
EXTRAS = ["mx_roadblock", "mx_roadblock_mil", "mx_bandits_block", "mx_mayhem", "mx_roadworks", "mx_prison_bus", "mx_prison_van",
          "mx_exocrash_1", "mx_exocrash_2", "mx_helicopter"]
rs = json.load(open(os.path.join(STOCK, "regional_map_settings.json")))
region = next(r for r in rs if r.get("type") == "region_settings")
zones = {}
for zone, v in region["map_extras"].items():
    for e in EXTRAS:
        if e in v.get("extras", {}): zones.setdefault(zone, {})[e] = 0
overlay = {"type": "region_overlay", "regions": ["all"], "map_extras": {z: {"extras": ex} for z, ex in zones.items()}}
json.dump(out + [overlay], open(os.path.join(MOD, "no_wrecks.json"), "w"), indent=1)
print(len(ids), "nested chunks blanked;", sum(len(v) for v in zones.values()), "extra entries zeroed in", len(zones), "zones")
