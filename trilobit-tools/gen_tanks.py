#!/usr/bin/env python3
"""Display aquariums in rich places (design doc M11): tower entry lobbies (the z1 ground tile of each tower section) and rich-district
estate homes get one or two 1- or 2-tile aquariums set against a wall.  The tank's fish are themed at random by the nested mapgens
trl_tank_1 / trl_tank_2 (gen_fish.py).  Shops, restaurants and lounges place their own tanks in gen_places.py / shoplayout.py.
usage: gen_tanks.py <mod dir>   (run after gen_presence.py; idempotent)"""
import json, os, random, re, sys
MOD = sys.argv[1]
BAD = re.compile(r"wall|window|door|rock|air|sky|water|pavement|sidewalk|grass|dirt|road|open|roof|stair|ladder|pit|glass|gravel|rubble", re.I)
WALL = re.compile(r"wall|window", re.I)


def terr_at(obj, x, y):
    rows = obj.get("rows", [])
    if not (0 <= y < len(rows) and 0 <= x < len(rows[y])):
        return None
    t = obj.get("terrain", {}).get(rows[y][x]) or obj.get("fill_ter")
    if isinstance(t, list):
        t = t[0]
    return t if isinstance(t, str) else "x"


def used_cells(obj):
    u = set()
    for key in ("place_furniture", "place_npcs", "place_nested", "place_monster"):
        for e in obj.get(key, []):
            if isinstance(e.get("x"), int) and isinstance(e.get("y"), int):
                u.add((e["x"], e["y"]))
    return u


def ok(obj, x, y, used):
    t = terr_at(obj, x, y)
    return t is not None and not BAD.search(t) and (x, y) not in used


def wall_side(obj, x, y):
    """a floor cell with a wall directly north or south: the tank stands against it"""
    return any(terr_at(obj, x, y + d) and WALL.search(terr_at(obj, x, y + d)) for d in (-1, 1))


def place(obj, rng, n, wide_chance):
    used = used_cells(obj)
    cands = [(x, y) for y in range(len(obj["rows"])) for x in range(len(obj["rows"][0])) if ok(obj, x, y, used) and wall_side(obj, x, y)]
    rng.shuffle(cands)
    added = []
    for x, y in cands:
        if len(added) >= n:
            break
        if (x, y) in used:
            continue
        wide = rng.random() < wide_chance and ok(obj, x + 1, y, used) and wall_side(obj, x + 1, y)
        cells = [(x, y), (x + 1, y)] if wide else [(x, y)]
        if any(c in used for c in cells):
            continue
        # keep a clear tile on either side so the tank never blocks a corridor
        added.append({"chunks": [["trl_tank_2" if wide else "trl_tank_1", 100]], "x": x, "y": y})
        used.update(cells); used.update({(cx, cy + d) for cx, cy in cells for d in (-1, 1)})
    return added


total = 0
for sub in ("towers", "houses"):
    path = os.path.join(MOD, sub, "mapgen.json")
    if not os.path.exists(path):
        continue
    data = json.load(open(path))
    for m in data:
        if m.get("type") != "mapgen" or "om_terrain" not in m:
            continue
        oid = m["om_terrain"][0]
        obj = m.get("object", {})
        keep = [n for n in obj.get("place_nested", []) if not str(n.get("chunks", [["", 0]])[0][0]).startswith("trl_tank_")]
        add = []
        rng = random.Random("tank-" + oid)
        if re.match(r"^trl_mt\d+_\d+z1$", oid):
            add = place(obj, rng, rng.choice([1, 2, 2, 3]), 0.5)
        elif re.match(r"^trl_estate_\d+_t\d+_z0$", oid) and rng.random() < 0.6:
            add = place(obj, rng, 1, 0.4)
        total += len(add)
        if keep + add:
            obj["place_nested"] = keep + add
        elif "place_nested" in obj:
            del obj["place_nested"]
    json.dump(data, open(path, "w"), indent=1)
print("display aquariums placed in tower lobbies and estates:", total)
