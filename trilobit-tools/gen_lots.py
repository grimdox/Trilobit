#!/usr/bin/env python3
"""Generate 12 one-tile city squares / wasteland lots (plazas, rubble, camps, yards).
Run AFTER gen_midrise.py (needs its terrain/furniture).  usage: gen_lots.py <mod dir>"""
import json, os, random, sys
MOD = sys.argv[1]
sys.argv = [sys.argv[0], MOD]
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_midrise as mr
from gen_midrise import gp, T, F, G, FLOORS, WALLS

LOTS = []
def lot(pid, name, sym, color, loot, base="pave", edge="walk"):
    def deco(fn):
        LOTS.append(dict(id=f"trl_lot_{pid}", name=name, sym=sym, color=color, fn=fn, loot=loot, base=base, edge=edge))
        return fn
    return deco

def lamps(g, key="street_lamp", n=4):
    for pos in [(3, 3), (20, 3), (3, 20), (20, 20), (11, 2), (11, 21), (2, 11), (21, 11)][:n + 4]:
        if sum(1 for k, _, _ in g.f if F[k]["light"] >= 4) >= n + 1: break
        g.f_(key, *pos)

@lot("plaza", "stone plaza", "P", "light_gray", "decor")
def _(g):
    g.fill(10, 10, 13, 13, "pave")
    g.f_("fountain", 11, 11); g.f_("fountain", 12, 12)
    for x, y in ((8, 11), (15, 11), (11, 8), (12, 15)): g.f_("bench_park", x, y)
    for x, y in ((5, 5), (18, 5), (5, 18), (18, 18)): g.f_("planter", x, y); g.f_("street_lamp", x + 1, y)
    g.f_("neon_cyan", 3, 12); g.f_("neon_amber", 20, 12); g.f_("holo_ad", 11, 4)
@lot("neon_square", "neon square", "N", "pink", "drink")
def _(g):
    for x in range(3, 21, 3): g.fill(x, 3, x, 20, "neon_pink" if x % 6 == 0 else "neon_cyan")
    g.f_("mirror_ball", 11, 11); g.f_("mirror_ball", 12, 12)
    for y in (5, 11, 17): g.f_("holo_ad", 5, y); g.f_("holo_ad", 18, y)
    g.f_("vending", 2, 6); g.f_("vending", 21, 17); g.f_("neon_pink_big", 11, 2)
    for x, y in ((8, 8), (15, 8), (8, 15), (15, 15)): g.f_("bar_stool", x, y)
@lot("rubble", "rubble lot", "r", "dark_gray", "tool", base="gravel")
def _(g):
    for _ in range(6): g.f_("crate", g.rng.randint(3, 20), g.rng.randint(3, 20))
    g.scatter("trash", 3, 3, 20, 20, 8); g.scatter("pipes", 3, 3, 20, 20, 5)
    g.f_("fire_drum", 8, 8); g.f_("fire_drum", 16, 15); g.f_("neon_amber", 2, 2); g.f_("neon_red", 21, 21)
    g.fill(5, 5, 7, 6, "wall_concrete"); g.fill(15, 16, 18, 16, "wall_concrete"); g.fill(12, 3, 12, 6, "wall_concrete")
@lot("shanty", "shanty camp", "s", "brown", "dingy", base="slab")
def _(g):
    for (x0, y0) in ((4, 4), (14, 4), (4, 14), (14, 14)):
        g.box(x0, y0, x0 + 5, y0 + 4, "wall_rust", "slab"); g.door("shutter_c", x0 + 2, y0 + 4)
        g.f_("mattress", x0 + 1, y0 + 1); g.f_("hotplate", x0 + 4, y0 + 1); g.f_("tv_static", x0 + 3, y0 + 1)
    g.f_("fire_drum", 11, 11); g.f_("fire_drum", 12, 12); g.f_("laundry", 10, 8); g.f_("laundry", 13, 16)
    g.scatter("trash", 3, 3, 20, 20, 6); g.scatter("water_barrel", 3, 3, 20, 20, 3); g.f_("neon_amber", 11, 2)
@lot("scrapyard", "scrap yard", "S", "light_red", "tool", base="gravel")
def _(g):
    g.hwall(2, 21, 2, "wall_rust"); g.hwall(2, 21, 21, "wall_rust"); g.vwall(2, 2, 21, "wall_rust"); g.vwall(21, 2, 21, "wall_rust")
    g.door("shutter_c", 11, 21)
    for x in range(4, 20, 4):
        for y in (5, 9, 15): g.f_("crate", x, y)
    g.scatter("pipes", 3, 3, 20, 20, 6); g.scatter("limb_bin", 3, 3, 20, 20, 3)
    g.f_("fire_drum", 6, 12); g.f_("fire_drum", 17, 12); g.f_("workbench", 10, 7); g.f_("neon_red", 11, 3)
@lot("hydro", "hydroponic yard", "h", "light_green", "food")
def _(g):
    g.box(2, 3, 21, 20, "wall_corp", "floor_corp"); g.door("door_c", 11, 20)
    g.windows(2, 21, 3); g.windows_v(2, 3, 20); g.windows_v(21, 3, 20)
    for y in (6, 9, 14, 17):
        for x in range(4, 20, 2): g.f_("planter" if (x + y) % 4 == 0 else "fern", x, y)
    g.f_("neon_green", 6, 4); g.f_("neon_green", 16, 4); g.f_("neon_green", 11, 12); g.f_("console", 20, 19)
@lot("helipad", "rooftop-style helipad", "H", "yellow", "tech", base="slab")
def _(g):
    g.fill(7, 7, 16, 16, "hazard"); g.fill(9, 9, 14, 14, "slab")
    for x, y in ((7, 7), (16, 7), (7, 16), (16, 16)): g.f_("sentry_lamp", x, y)
    g.f_("crate", 3, 3); g.f_("crate", 4, 3); g.f_("console", 20, 20); g.f_("neon_amber", 11, 3); g.f_("neon_amber", 11, 20)
@lot("parking", "parking deck", "p", "light_blue", "tool", base="slab")
def _(g):
    for x in range(4, 20, 4): g.fill(x, 4, x, 19, "hazard")
    for y in (5, 10, 15): g.f_("bike_rack", 5, y); g.f_("bike_rack", 14, y)
    g.f_("charging_pod", 2, 3); g.f_("charging_pod", 21, 20); g.f_("ticket_machine", 11, 2); g.f_("neon_cyan", 11, 21)
    g.f_("street_lamp", 3, 11); g.f_("street_lamp", 20, 11)
@lot("shrine_garden", "stone garden", "g", "light_green", "decor", base="gravel")
def _(g):
    g.f_("torii", 11, 20); g.f_("shrine", 11, 5); g.f_("fountain", 6, 8); g.f_("fountain", 17, 8)
    for x, y in ((5, 5), (18, 5), (5, 17), (18, 17), (8, 14), (15, 14)): g.f_("lantern_stone", x, y)
    for x, y in ((4, 10), (19, 10), (7, 18), (16, 18)): g.f_("bonsai", x, y)
    g.f_("statue_fox", 10, 6); g.f_("statue_fox", 13, 6); g.f_("wind_chime", 11, 8)
@lot("memorial", "memorial park", "m", "green", "decor", base="grass")
def _(g):
    g.fill(10, 3, 13, 20, "pave"); g.fill(3, 10, 20, 13, "pave")
    g.f_("statue_fox", 11, 11); g.f_("lantern_stone", 10, 10); g.f_("lantern_stone", 13, 13)
    for x, y in ((7, 11), (16, 11), (11, 7), (12, 16)): g.f_("bench_park", x, y)
    for x, y in ((5, 5), (18, 5), (5, 18), (18, 18), (7, 7), (16, 16)): g.f_("bonsai", x, y); g.f_("street_lamp", x + 1, y + 1)
@lot("bombed", "bombed block", "b", "dark_gray", "tool", base="gravel")
def _(g):
    for (x0, y0, x1, y1) in ((3, 3, 9, 3), (3, 3, 3, 8), (14, 14, 20, 14), (20, 9, 20, 14), (3, 16, 8, 16)):
        if x0 == x1: g.vwall(x0, y0, y1, "wall_brick")
        else: g.hwall(x0, x1, y0, "wall_brick")
    g.scatter("crate", 3, 3, 20, 20, 6); g.scatter("trash", 3, 3, 20, 20, 8); g.scatter("pipes", 3, 3, 20, 20, 4)
    g.f_("fire_drum", 11, 11); g.f_("neon_red", 6, 5); g.f_("neon_amber", 17, 17)
@lot("fight_pit", "fight pit", "F", "red", "drink", base="slab")
def _(g):
    g.box(7, 7, 16, 16, "wall_pipes", "slab")
    for x, y in ((6, 11), (17, 11), (11, 6), (12, 17)): g.door("door_steel", x, y) if False else None
    g.put("floor_steel", 11, 7); g.put("floor_steel", 12, 7)
    for x in range(4, 20, 3): g.f_("neon_red", x, 3); g.f_("bar_stool", x, 5)
    g.f_("fire_drum", 3, 20); g.f_("fire_drum", 20, 20); g.f_("vending", 2, 12); g.f_("tv_static", 21, 12)


# ---- downtown fillers: any downtown spot that would be left empty becomes a parking lot or a construction site
CARS = {}
def cars(pid, spots):
    CARS[f"trl_lot_{pid}"] = spots

def bays(g, xs, y0, y1):
    for x in xs: g.fill(x, y0, x, y1, "hazard")

@lot("park_a", "surface parking lot", "p", "light_blue", "tool", base="slab")
def _(g):
    bays(g, (4, 8, 12, 16, 20), 4, 9); bays(g, (4, 8, 12, 16, 20), 14, 19)
    g.f_("ticket_machine", 11, 11); g.f_("street_lamp", 3, 11); g.f_("street_lamp", 20, 11); g.f_("neon_cyan", 11, 2)
    g.f_("trash", 21, 3); g.f_("bike_rack", 3, 21)
cars("park_a", [(5, 5, 90), (9, 6, 90), (13, 5, 90), (17, 6, 90), (5, 16, 90), (13, 16, 90), (17, 15, 90)])
@lot("park_b", "attendant parking lot", "p", "light_blue", "tool", base="slab")
def _(g):
    bays(g, (5, 9, 13, 17), 3, 8); bays(g, (5, 9, 13, 17), 15, 20)
    g.box(18, 10, 21, 13, "wall_corp", "floor_corp"); g.door("door_c", 18, 11)
    g.f_("console", 20, 11); g.f_("chair_office", 19, 12); g.f_("neon_amber", 20, 9)
    g.f_("street_lamp", 3, 11); g.f_("street_lamp", 16, 11); g.f_("ticket_machine", 14, 11)
cars("park_b", [(6, 4, 85), (10, 5, 85), (14, 4, 85), (6, 17, 85), (10, 18, 85), (14, 17, 85)])
@lot("park_c", "charging lot", "p", "light_green", "tech", base="slab")
def _(g):
    bays(g, (4, 8, 12, 16, 20), 4, 8); bays(g, (4, 8, 12, 16, 20), 15, 19)
    for x in (6, 10, 14, 18):
        g.f_("charging_pod", x, 9); g.f_("charging_pod", x, 14)
    g.f_("street_lamp", 3, 11); g.f_("street_lamp", 20, 11); g.f_("neon_green", 11, 2); g.f_("neon_green", 11, 21); g.f_("ticket_machine", 11, 11)
cars("park_c", [(5, 5, 80), (9, 5, 80), (13, 6, 80), (17, 5, 80), (5, 16, 80), (9, 17, 80), (17, 16, 80)])
@lot("park_d", "bike and scooter lot", "p", "cyan", "tool", base="slab")
def _(g):
    for y in range(4, 20, 3):
        for x in (4, 5, 6, 7): g.f_("bike_rack", x, y)
        for x in (14, 15, 16, 17): g.f_("bike_rack", x, y)
    g.f_("charging_pod", 11, 6); g.f_("charging_pod", 12, 6); g.f_("charging_pod", 11, 17); g.f_("charging_pod", 12, 17)
    g.f_("street_lamp", 3, 11); g.f_("street_lamp", 20, 11); g.f_("neon_cyan", 11, 2); g.f_("ticket_machine", 12, 11)
cars("park_d", [(10, 10, 60)])

@lot("build_a", "construction site", "c", "yellow", "tool", base="gravel")
def _(g):
    g.hwall(2, 21, 2, "wall_rust"); g.hwall(2, 21, 21, "wall_rust"); g.vwall(2, 2, 21, "wall_rust"); g.vwall(21, 2, 21, "wall_rust")
    g.door("shutter_c", 11, 21)
    g.fill(6, 6, 17, 14, "slab")
    for x in (6, 11, 17): g.vwall(x, 6, 12, "wall_concrete")
    g.hwall(6, 17, 6, "wall_concrete")
    for x, y in ((4, 18), (8, 18), (13, 18), (18, 17)): g.f_("crate", x, y)
    g.scatter("pipes", 3, 15, 20, 20, 5); g.f_("workbench", 4, 4); g.f_("workbench", 19, 4)
    for x, y in ((3, 3), (20, 3), (3, 20), (20, 20)): g.f_("sentry_lamp", x, y)
    g.f_("fire_drum", 10, 17); g.f_("neon_amber", 11, 1)
@lot("build_b", "building site with site office", "c", "yellow", "tool", base="gravel")
def _(g):
    g.hwall(2, 21, 2, "wall_rust"); g.hwall(2, 21, 21, "wall_rust"); g.vwall(2, 2, 21, "wall_rust"); g.vwall(21, 2, 21, "wall_rust")
    g.door("shutter_c", 11, 21)
    g.box(3, 3, 9, 8, "wall_corp", "floor_corp"); g.door("door_c", 6, 8)
    g.f_("desk_corp", 5, 5); g.f_("chair_office", 6, 5); g.f_("console", 8, 4); g.f_("floor_lamp", 4, 4)
    g.fill(12, 5, 19, 12, "slab"); g.hwall(12, 19, 5, "wall_concrete"); g.vwall(19, 5, 12, "wall_concrete")
    g.scatter("crate", 3, 10, 20, 20, 8); g.scatter("pipes", 3, 10, 20, 20, 4)
    for x, y in ((11, 13), (16, 16)): g.f_("fire_drum", x, y)
    g.f_("sentry_lamp", 3, 20); g.f_("sentry_lamp", 20, 20); g.f_("neon_amber", 11, 1)
@lot("build_c", "scaffolded tower foundation", "c", "brown", "tool", base="slab")
def _(g):
    g.hwall(2, 21, 2, "wall_rust"); g.hwall(2, 21, 21, "wall_rust"); g.vwall(2, 2, 21, "wall_rust"); g.vwall(21, 2, 21, "wall_rust")
    g.door("shutter_c", 11, 21)
    g.box(6, 6, 17, 16, "wall_pipes", "slab")
    g.door("door_steel", 11, 16) if False else None
    g.put("floor_steel", 11, 16); g.put("floor_steel", 12, 16)
    g.f_("workbench", 8, 9); g.f_("workbench", 15, 9); g.f_("crate", 10, 12); g.f_("crate", 13, 12)
    g.scatter("crate", 3, 17, 20, 20, 5); g.scatter("pipes", 3, 17, 20, 20, 4)
    for x, y in ((3, 3), (20, 3), (3, 20), (20, 20), (11, 3)): g.f_("sentry_lamp", x, y)
    g.f_("fire_drum", 5, 12); g.f_("fire_drum", 18, 12)
@lot("build_d", "excavation and materials yard", "c", "brown", "tool", base="gravel")
def _(g):
    g.hwall(2, 21, 2, "wall_rust"); g.hwall(2, 21, 21, "wall_rust"); g.vwall(2, 2, 21, "wall_rust"); g.vwall(21, 2, 21, "wall_rust")
    g.door("shutter_c", 11, 21)
    for (x0, y0, x1, y1) in ((4, 4, 9, 4), (4, 4, 4, 9), (14, 14, 20, 14), (20, 8, 20, 14)):
        if x0 == x1: g.vwall(x0, y0, y1, "wall_concrete")
        else: g.hwall(x0, x1, y0, "wall_concrete")
    g.scatter("crate", 3, 3, 20, 20, 10); g.scatter("pipes", 3, 3, 20, 20, 7); g.scatter("trash", 3, 3, 20, 20, 3)
    g.f_("workbench", 11, 16); g.f_("fire_drum", 11, 11); g.f_("fire_drum", 16, 7)
    for x, y in ((3, 3), (20, 3), (3, 20), (20, 20)): g.f_("sentry_lamp", x, y)

def emit():
    om, cb, mg = [], [], []
    for L in LOTS:
        g = G(base=L["base"], edge=L["edge"])
        g.rng = random.Random(sum(map(ord, L["id"])))
        L["fn"](g)
        n_lit = sum(1 for k, _, _ in g.f if F[k]["light"] >= 4)
        cnt = n_lit
        for pos in [(3, 3), (20, 3), (3, 20), (20, 20), (11, 2), (11, 21)]:
            if cnt >= 4: break
            if g.f_("street_lamp", *pos): cnt += 1
        assert cnt >= 3, (L["id"], cnt)
        keys = sorted(set(k for row in g.t for k in row))
        ch = {k: mr.POOL[i] for i, k in enumerate(keys)}
        rows = ["".join(ch[k] for k in row) for row in g.t]
        obj = {"fill_ter": "t_pavement", "rows": rows, "terrain": {ch[k]: T[k]["id"] for k in keys},
               "place_furniture": [{"furn": F[k]["id"], "x": x, "y": y} for k, x, y in g.f],
               "place_items": [{"item": f"trl_loot_{L['loot']}", "x": [3, 20], "y": [3, 20], "chance": 40, "repeat": 4}]}
        if L["id"] in CARS:
            obj["place_vehicles"] = [{"vehicle": "trl_veh_mid", "x": x, "y": y, "chance": ch, "status": 60, "rotation": 90} for x, y, ch in CARS[L["id"]]]
        mg.append({"type": "mapgen", "om_terrain": [L["id"]], "object": obj})
        om.append({"type": "overmap_terrain", "id": L["id"], "name": L["name"], "sym": L["sym"], "color": L["color"],
                   "see_cost": "full_high", "vision_levels": "large_city_building", "flags": ["SIDEWALK"]})
        cb.append({"type": "city_building", "id": L["id"], "locations": ["land"],
                   "overmaps": [{"point": [0, 0, 0], "overmap": L["id"] + "_north"}], "city_sizes": [1, -1]})
    d = os.path.join(MOD, "lots"); os.makedirs(d, exist_ok=True)
    json.dump(om + cb, open(os.path.join(d, "buildings.json"), "w"), indent=1)
    json.dump(mg, open(os.path.join(d, "mapgen.json"), "w"), indent=1)
    ro_path = os.path.join(MOD, "region_overlay.json")
    ro = json.load(open(ro_path))
    parks = ro[0]["city"]["parks"]
    w = 1296 * 2 // 5     # about a tenth of all city squares
    for L in LOTS: parks[L["id"]] = 0 if L["id"].startswith(("trl_lot_park_", "trl_lot_build_")) else max(1, w)
    json.dump(ro, open(ro_path, "w"), indent=1)
    print(len(LOTS), "lots")

if __name__ == "__main__":
    emit()
