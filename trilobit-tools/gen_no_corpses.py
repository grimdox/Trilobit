#!/usr/bin/env python3
"""Blank every item group that spawns dead bodies (corpse*, everyday_corpse*, mil_base corpses...).
usage: gen_no_corpses.py <mod dir> <cdda data/json dir>"""
import json, glob, os, re, sys
MOD, STOCK = sys.argv[1], sys.argv[2]
PAT = re.compile(r"(^|_)corpses?(_|$)")
ids = set()
for f in glob.glob(os.path.join(STOCK, "**/*.json"), recursive=True):
    try: d = json.load(open(f))
    except Exception: continue
    if not isinstance(d, list): continue
    for o in d:
        if isinstance(o, dict) and o.get("type") == "item_group" and PAT.search(o.get("id", "")):
            ids.add(o["id"])
out = [{"type": "item_group", "id": i, "subtype": "collection", "entries": []} for i in sorted(ids)]
json.dump(out, open(os.path.join(MOD, "no_corpses.json"), "w"), indent=1)
print(len(ids), "corpse item groups blanked")
