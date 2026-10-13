#!/usr/bin/env python3
"""Rooftop solar panels and wind turbines (design doc section M8): about half of all roofs get a few solar panels, one roof in six a wind turbine.
Scenery only; chosen once at generation time.  Run after the building generators (it edits their mapgen files).
usage: gen_roofs.py <mod dir>"""
import hashlib, json, os, random, sys
MOD = sys.argv[1]
PANEL, TURBINE = "f_trl_solar_panel", "f_trl_wind_turbine"
tot = [0, 0, 0]
for sub in ("houses", "midrise", "midrise2", "towers", "city"):
    path = os.path.join(MOD, sub, "mapgen.json")
    if not os.path.exists(path):
        continue
    data = json.load(open(path))
    for m in data:
        if m.get("type") != "mapgen" or "om_terrain" not in m:
            continue
        obj = m.get("object", {})
        terr = obj.get("terrain", {})
        roof_chars = {c for c, t in terr.items() if (t == "t_flat_roof" or (isinstance(t, list) and "t_flat_roof" in t))}
        furn = [f for f in obj.get("place_furniture", []) if f.get("furn") not in (PANEL, TURBINE)]
        if not roof_chars:
            if len(furn) != len(obj.get("place_furniture", [])):
                obj["place_furniture"] = furn
            continue
        oid = m["om_terrain"] if isinstance(m["om_terrain"], str) else json.dumps(m["om_terrain"])
        rnd = random.Random(hashlib.md5(oid.encode()).hexdigest())
        taken = {(f["x"], f["y"]) for f in furn if isinstance(f.get("x"), int) and isinstance(f.get("y"), int)}
        cells = {(x, y) for y, row in enumerate(obj.get("rows", [])) for x, ch in enumerate(row)
                 if ch in roof_chars and 2 <= x <= 21 and 2 <= y <= 21 and (x, y) not in taken}
        add = []
        tot[0] += 1
        if len(cells) >= 4 and rnd.random() < 0.72:
            for _ in range(rnd.choice([1, 1, 2, 3])):
                x0, y0 = rnd.choice(sorted(cells))
                w, h = rnd.choice([(2, 2), (3, 2), (4, 2), (3, 1), (2, 1)])
                for yy in range(y0, y0 + h):
                    for xx in range(x0, x0 + w):
                        if (xx, yy) in cells:
                            add.append({"furn": PANEL, "x": xx, "y": yy}); cells.discard((xx, yy))
            tot[1] += 1
        if len(cells) >= 6 and rnd.random() < 0.22:
            for _ in range(rnd.choice([1, 1, 2])):
                x0, y0 = rnd.choice(sorted(cells))
                add.append({"furn": TURBINE, "x": x0, "y": y0}); cells.discard((x0, y0))
            tot[2] += 1
        obj["place_furniture"] = furn + add
    json.dump(data, open(path, "w"), indent=1)
print("roofs:", tot[0], "with panels:", tot[1], "with turbines:", tot[2])
