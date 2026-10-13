#!/usr/bin/env python3
"""Downtown has no grass: every ground level of a skyscraper or tower (mid-rise and tower regions) swaps grass for paving.
Roofs, parks, shrines and churches keep theirs.  Idempotent post-pass over the generated mapgens.  usage: gen_downtown.py <mod dir>"""
import json, os, sys
MOD = sys.argv[1]
n = 0
for sub in ("towers", "city", "midrise", "midrise2", "midrise3"):
    path = os.path.join(MOD, sub, "mapgen.json")
    if not os.path.exists(path):
        continue
    data = json.load(open(path))
    dirty = False
    for m in data:
        if m.get("type") != "mapgen" or "object" not in m:
            continue
        o = m["object"]
        if o.get("fill_ter") == "t_grass":
            o["fill_ter"] = "t_pavement"; dirty = True; n += 1
        ter = o.get("terrain", {})
        if o.get("fill_ter") in ("t_pavement",) or "z0" in str(m.get("om_terrain")) or "z1" in str(m.get("om_terrain")):
            for k, v in list(ter.items()):
                if v == "t_grass" and o.get("fill_ter") != "t_open_air":
                    ter[k] = "t_pavement"; dirty = True; n += 1
    if dirty:
        json.dump(data, open(path, "w"), indent=1)
print("downtown grass replaced:", n)
