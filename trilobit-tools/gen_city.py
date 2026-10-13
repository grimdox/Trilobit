#!/usr/bin/env python3
"""Generate Trilobit Milestone 2 city content into the mod folder."""
import json, os, sys, random
MOD = sys.argv[1]
STOCK = sys.argv[2]   # path to data/json/regional_map_settings.json
CITY_RINGS = int(sys.argv[3]) if len(sys.argv) > 3 else 1
OMT = 24

# --- building definitions ------------------------------------------------
# (id, nx, ny, stories, basement, wall, window_period, name)
SKY = []
walls = ["t_concrete_wall", "t_strconc_wall"]
for i in range(10):
    big = i < 5
    SKY.append(dict(id=f"trl_sky{i+1:02d}", nx=3 if big else 2, ny=3 if big else 2,
                    stories=10 + (i % 3) * 0 , wall=walls[i % 2], period=3 + (i % 3),
                    name=f"skyscraper {i+1}", sym="T", color="light_cyan", basement=True))
# tower 3x3: 5, 2x2: 5. Heights: 10 stories (z0..9) + roof z10 is the engine maximum.
MID = [
    dict(id="trl_mid01", nx=1, ny=1, stories=2, name="midrise block A"),
    dict(id="trl_mid02", nx=1, ny=1, stories=3, name="midrise block B"),
    dict(id="trl_mid03", nx=2, ny=1, stories=3, name="midrise block C"),
    dict(id="trl_mid04", nx=1, ny=2, stories=2, name="midrise block D"),
    dict(id="trl_mid05", nx=2, ny=2, stories=2, name="midrise block E"),
    dict(id="trl_mid06", nx=2, ny=2, stories=3, name="midrise block F"),
]
for m in MID:
    m.update(wall="t_concrete_wall", period=4, sym="m", color="light_gray", basement=False, lab=True)

def cellgrid(b, cx, cy, z, stairs_cell):
    """Return 24 strings for cell (cx,cy) at level z."""
    nx, ny, st = b["nx"], b["ny"], b["stories"]
    W, H = nx * OMT, ny * OMT
    roof = (z == st)
    base = (z < 0)
    ground = (z == 0)
    rows = []
    for r in range(OMT):
        gy = cy * OMT + r
        line = []
        for c in range(OMT):
            gx = cx * OMT + c
            ch = None
            ring = gx in (0, W - 1) or gy in (0, H - 1)
            wall = (gx in (1, W - 2) and 1 <= gy <= H - 2) or (gy in (1, H - 2) and 1 <= gx <= W - 2)
            inside = 2 <= gx <= W - 3 and 2 <= gy <= H - 3
            if ring:
                ch = ',' if ground else (' ' if not base else '#')  # sidewalk / open air / rock
                if base: ch = 'R'
            elif wall:
                if True:
                    ch = 'W'
                    corner = (gx in (1, W-2)) and (gy in (1, H-2))
                    if not corner and not base:
                        idx = gx if gy in (1, H - 2) else gy
                        edge_d = min(idx - 1, (W - 2 if gy in (1, H-2) else H - 2) - idx)
                        if edge_d > 2 and (idx % b["period"]) != 0:
                            ch = 'G'
                    if ground:
                        idx = gx if gy in (1, H - 2) else gy
                        if idx % OMT == 12 and not corner:
                            ch = 'D'
            elif inside:
                ch = 'r' if roof else 'f'
            line.append(ch)
        rows.append(line)
    # stair core
    if (cx, cy) == stairs_cell and not roof:
        # walls of core 7..16 with doors
        for r in range(7, 17):
            for c in range(7, 17):
                edge = r in (7, 16) or c in (7, 16)
                rows[r][c] = 'W' if edge else 'f'
        rows[7][11] = 'd'
        rows[16][12] = 'd'
    # stair tiles
    if (cx, cy) == stairs_cell and z <= st:
        a, b_ = (10, 12), (13, 12)  # (col,row)
        up_a = (z % 2 == 0)
        def put(pos, ch): rows[pos[1]][pos[0]] = ch
        if roof:
            put(a, 'r'); put(b_, '<')   # z=st even or odd handled below
        # general rule: parity layout A when z even: a up, b down; B when odd: a down, b up
        if not roof:
            if z % 2 == 0:
                put(a, '>'); put(b_, '<') if z > -1 else None
            else:
                put(a, '<'); put(b_, '>')
            if z == st - 1: pass
    return ["".join(x) for x in rows]

def stairs_fix(b, z, grids, stairs_cell):
    return grids

PAL = {
    "f": "t_linoleum_white", "r": "t_flat_roof", "W": None, "G": "t_window_no_curtains",
    "D": "t_door_glass_c", "d": "t_door_c", "P": "t_concrete_wall", ",": "t_sidewalk",
    " ": "t_open_air", "R": "t_rock", ">": "t_stairs_up", "<": "t_stairs_down",
}

def build_cell(b, cx, cy, z, sc):
    # stairs: layout by parity. '>' = stairs up, '<' = stairs down
    nx, ny, st = b["nx"], b["ny"], b["stories"]
    g = cellgrid(b, cx, cy, z, sc)
    rows = [list(r) for r in g]
    if (cx, cy) == sc and z <= st:
        a, bb = (10, 12), (13, 12)
        def put(p, ch): rows[p[1]][p[0]] = ch
        has_up = z < st
        has_down = z > -1 if b["basement"] else z > 0
        if z % 2 == 0:       # a up, b down
            put(a, '>' if has_up else 'f'); put(bb, '<' if has_down else 'f')
        else:                # a down, b up
            put(a, '<' if has_down else 'f'); put(bb, '>' if has_up else 'f')
        if z == st:          # roof: stair hut around the stairs down
            for r in range(10, 15):
                for c in range(8, 16):
                    edge = r in (10, 14) or c in (8, 15)
                    rows[r][c] = ('G' if ((r in (10, 14) and c in (10, 13)) or (c in (8, 15) and r == 12)) else 'W') if edge else 'f'
            rows[14][11] = 'd'
        if z == st:          # roof: arrival tile is stairs down
            if st % 2 == 0: put(bb, '<'); put(a, 'r')
            else: put(a, '<'); put(bb, 'r')
        if z < st:
            pass
    if b.get("lab") and z == 0 and (cx, cy) == sc:
        LAB = ["WWWWWWW",
               "WrbbbrW",
               "WbbcbbW",
               "WrbabrW",
               "WdWWWWW"]
        # lab room (7x5) in the top-left corner of the stair cell, door on the south wall
        for rr, line in enumerate(LAB):
            for cc, ch in enumerate(line):
                rows[2 + rr][2 + cc] = ch
    return ["".join(r) for r in rows]

def make_building(b, out_ter, out_map, out_cb):
    nx, ny, st = b["nx"], b["ny"], b["stories"]
    sc = (nx // 2, ny // 2)
    zmin = -1 if b["basement"] else 0
    wall = b["wall"]
    pal = dict(PAL); pal["W"] = wall
    cb = []
    ids_all = []
    seen = {}
    for z in range(zmin, st + 1):
        for cy in range(ny):
            for cx in range(nx):
                grid = build_cell(b, cx, cy, z, sc)
                key = tuple(grid)
                if key not in seen:
                    suffix = f"{cx}{cy}z{z+1}"
                    oid = f"{b['id']}_{suffix}"
                    seen[key] = oid
                    ids_all.append((oid, z))
                    obj = {
                        "fill_ter": "t_open_air" if z > 0 else ("t_rock" if z < 0 else "t_pavement"),
                        "rows": grid,
                        "palettes": [],
                        "terrain": {k: v for k, v in pal.items() if v}
                    }
                    if b.get("lab") and z == 0 and (cx, cy) == sc:
                        obj["furniture"] = {"a": "f_autodoc", "c": "f_autodoc_couch", "r": "f_rack"}
                        obj["terrain"].update({"b": "t_floor_blue", "a": "t_floor_blue", "c": "t_floor_blue", "r": "t_floor_blue"})
                        obj["items"] = {"a": {"item": "autodoc_supplies", "chance": 100},
                                        "r": {"item": "dissection", "chance": 40}}
                    out_map.append({"type": "mapgen", "om_terrain": [oid], "object": obj})
                cb.append({"point": [cx, cy, z], "overmap": seen[key] + "_north"})
    # overmap terrains
    for oid, z in ids_all:
        roof = (z == st)
        out_ter.append({
            "type": "overmap_terrain", "id": oid,
            "name": b["name"] + (" roof" if roof else ""),
            "sym": b["sym"], "color": b["color"],
            "see_cost": "full_high" if not roof else "none",
            "vision_levels": "roof_or_air" if roof else "large_city_building",
            "flags": ["SIDEWALK"] if z == 0 else [],
        })
    out_cb.append({"type": "city_building", "id": b["id"], "locations": ["land"],
                   "overmaps": cb, "city_sizes": [b.get("min_city", 1), -1]})

def main():
    ter, mp, cbs = [], [], []
    for b in SKY:
        b['min_city'] = 50 if b['nx'] == 3 else 35
    for b in SKY + MID:
        make_building(b, ter, mp, cbs)
    d = os.path.join(MOD, "city")
    os.makedirs(d, exist_ok=True)
    json.dump(ter, open(os.path.join(d, "overmap_terrain.json"), "w"), indent=1)
    json.dump(mp, open(os.path.join(d, "mapgen.json"), "w"), indent=1)
    json.dump(cbs, open(os.path.join(d, "city_buildings.json"), "w"), indent=1)

    stock = json.load(open(STOCK))
    reg = [r for r in stock if r.get("type") == "region_settings"][0]
    city = reg["city"]
    def wsum(d): return sum(v for k, v in d.items() if not k.startswith("//"))
    def zero(d): return {k: 0 for k in d if not k.startswith("//")}
    park_sum = wsum(city["parks"])
    sky_w = {b["id"]: 1000 for b in SKY}
    # downtown (shops): towers dominate; keep stock shops at 10%
    shops = zero(city["shops"]); shops.update(sky_w)
    shops_total = 1000 * len(SKY)
    keep = dict(city["shops"]);
    # restore 10% stock shops in proportion
    scale = (shops_total / 9.0) / max(1, wsum(city["shops"]))
    for k, v in city["shops"].items():
        if k.startswith("//"): continue
        shops[k] = max(0, int(v * scale))
    parks = dict(city["parks"])
    mid_total = park_sum * 3
    for m in MID:
        parks[m["id"]] = max(1, int(mid_total / len(MID)))
    houses = dict(city["houses"])
    overlay = {
        "type": "region_overlay", "regions": ["all"],
        "city": {
            "shop_radius": 18, "shop_sigma": 4,
            "park_radius": 60, "park_sigma": 4,
            "shops": shops, "parks": {k: v for k, v in parks.items() if not k.startswith("//")},
        }
    }
    json.dump([overlay], open(os.path.join(MOD, "region_overlay.json"), "w"), indent=1)

    # predefined metro: cities per overmap
    cities = []
    n = 0
    R = CITY_RINGS
    # Two megacities (A at the world origin, where new characters start; B further east),
    # plus small towns/villages in about one overmap in four.  Everything else is wilderness.
    MEGA = eval(os.environ.get('TRL_MEGA', '{(0, 0): ("Trilobit A", 100), (4, -2): ("Trilobit B", 90)}'))
    rnd = random.Random(1999)
    for oy in range(-R, R + 1):
        for ox in range(-R, R + 1):
            if (ox, oy) in MEGA:
                name, size = MEGA[(ox, oy)]
                # two seeds so one is likely on dry ground; each is a full-size city (the second
                # only matters when the first lands in water)
                for sx, sy, sz in [(50, 50, size * 11 // 20), (130, 50, size * 11 // 20), (50, 130, size * 11 // 20), (130, 130, size * 11 // 20)]:
                    n += 1
                    cities.append({"type": "city", "id": f"TRL_{n}", "database_id": n,
                                   "name": name, "population": sz * sz * 40,
                                   "size": sz, "pos_om": [ox, oy], "pos": [sx, sy]})
            elif rnd.random() < 0.25:
                n += 1
                size = rnd.randint(4, 10)
                cities.append({"type": "city", "id": f"TRL_{n}", "database_id": n,
                               "name": f"Village {n}", "population": size * size * 30,
                               "size": size, "pos_om": [ox, oy],
                               "pos": [rnd.randint(30, 150), rnd.randint(30, 150)]})
    json.dump(cities, open(os.path.join(MOD, "cities.json"), "w"), indent=1)
    print("buildings:", len(SKY) + len(MID), "mapgen:", len(mp), "cities:", len(cities))
main()
