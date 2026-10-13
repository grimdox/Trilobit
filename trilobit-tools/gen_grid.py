#!/usr/bin/env python3
"""The power grid (design doc section M8): a nuclear power station well outside the city, powerlines, a tidal generator, and the
furniture (pylons, cables, transformers, reactor core, solar panels, wind turbines).  Everything here is scenery or a one-time spawn:
nothing in it runs per turn.
usage: gen_grid.py <mod dir> -> <mod>/grid.json

The C++ side (overmap.cpp, place_trilobit_grid) places the station in overmap (2, 0), lays the line west along a fixed row
beside the highway, and puts tidal generators at some river bridges.
Terrain ids used: the mod's t_trl_* (gen_places.py) plus stock terrain."""
import json, math, os, random, sys
MOD = sys.argv[1]
out = []

# ---------------------------------------------------------------- furniture
def furn(key, name, desc, sym, color, light=0, passable=False, flags=None, **kw):
    d = {"type": "furniture", "id": f"f_trl_{key}", "name": name, "description": desc, "symbol": sym, "color": color,
         "move_cost_mod": 0 if passable else -1, "coverage": 0 if passable else 40, "required_str": -1,
         "flags": flags or ["TRANSPARENT"], "bash": {"str_min": 12, "str_max": 40, "sound": "smash!", "sound_fail": "thump."}}
    if light:
        d["light_emitted"] = light
    d.update(kw)
    out.append(d)


furn("pylon", "power pylon", "A tall lattice pylon strung with thick cables, humming in the damp air.", "T", "light_gray", passable=False)
furn("cable_ew", "overhead cable", "Heavy power cables hang overhead, running east to west.", "-", "dark_gray", passable=True)
furn("cable_ns", "overhead cable", "Heavy power cables hang overhead, running north to south.", "|", "dark_gray", passable=True)
furn("reactor_core", "reactor core", "A shielded reactor vessel as tall as a house, glowing a pale, steady green behind thick glass.", "O", "light_green", light=20)
furn("turbine", "turbine generator", "A huge steel turbine generator, spinning in its housing.", "G", "light_cyan", light=6)
furn("cooling_fan", "cooling stack", "A tall cooling stack, breathing steam into the sky.", "!", "white", light=4)
furn("solar_panel", "solar panel", "A flat solar panel angled at the sky, its surface a deep blue-violet.", "=", "blue", passable=True)
furn("wind_turbine", "wind turbine", "A slim wind turbine with three long white blades turning slowly.", "Y", "white", light=3)
furn("tidal_turbine", "tidal turbine", "A submerged turbine on a steel mast; the water turns its blades with a deep, slow thrum.", "&", "light_blue", light=4)
furn("substation_unit", "substation unit", "A transformer cabinet with fat insulators and a sign: DANGER, HIGH VOLTAGE.", "Z", "yellow", light=5)

# ---------------------------------------------------------------- overmap terrain, connection and the special
W, H = 96, 72           # plant canvas: 4 by 3 overmap tiles
TX, TY = 4, 3
GATE = (1, 2)           # the tile with the gate; the powerline leaves just south of it


def plant_id(tx, ty, roof=False):
    return f"trl_plant_{tx}_{ty}" + ("_roof" if roof else "")


for ty in range(TY):
    for tx in range(TX):
        for roof in (False, True):
            gate = (tx, ty) == GATE
            nm = ("power station gate" if gate else "nuclear power station") + (" roof" if roof else "")
            out.append({"type": "overmap_terrain", "id": plant_id(tx, ty, roof), "name": nm, "sym": "N", "color": "light_green",
                        "see_cost": "full_high", "vision_levels": "large_city_building", "flags": ["NO_ROTATE"]})
out.append({"type": "overmap_special", "id": "trl_nuclear_station", "subtype": "fixed",
            "overmaps": [{"point": [tx, ty, 0], "overmap": plant_id(tx, ty)} for ty in range(TY) for tx in range(TX)] +
                        [{"point": [tx, ty, 1], "overmap": plant_id(tx, ty, True)} for ty in range(TY) for tx in range(TX)],
            "locations": ["land"], "occurrences": [0, 0], "flags": ["MAN_MADE", "SAFE_AT_WORLDGEN"]})
out.append({"type": "overmap_terrain", "id": "trl_powerline", "name": "high-voltage powerline", "sym": "|", "color": "yellow",
            "see_cost": "spaced_high", "vision_levels": "blends_till_details", "flags": ["LINEAR", "REQUIRES_PREDECESSOR"]})
out.append({"type": "overmap_terrain", "id": "trl_tidal", "name": "tidal generator", "sym": "~", "color": "light_blue",
            "see_cost": "none", "vision_levels": "blends_till_details", "flags": ["NO_ROTATE"]})

# ---------------------------------------------------------------- canvas helpers (terrain keys -> ids)
TER = {"grass": "t_grass", "pave": "t_trl_pave", "road": "t_pavement", "fence": "t_chainfence", "wall_neon": "t_trl_wall_neon",
       "wall_corp": "t_trl_wall_corp", "wall_conc": "t_trl_wall_concrete", "wall_pipes": "t_trl_wall_pipes", "floor": "t_trl_floor_corp",
       "grating": "t_trl_grating", "window": "t_trl_window", "door": "t_trl_elock_c", "slab": "t_trl_slab", "hazard": "t_trl_hazard",
       "neon_c": "t_trl_neon_cyan", "neon_p": "t_trl_neon_pink", "water": "t_water_dp", "shallow": "t_water_sh", "gravel": "t_trl_gravel",
       "roof": "t_flat_roof", "air": "t_open_air", "walk": "t_sidewalk"}


class Canvas:
    def __init__(self, base):
        self.t = [[base] * W for _ in range(H)]
        self.f = {}

    def put(self, x, y, k):
        if 0 <= x < W and 0 <= y < H:
            self.t[y][x] = k

    def fur(self, x, y, key):
        if 0 <= x < W and 0 <= y < H:
            self.f[(x, y)] = key

    def rect(self, x0, y0, x1, y1, k):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, k)

    def box(self, x0, y0, x1, y1, wall, floor):
        self.rect(x0, y0, x1, y1, wall)
        self.rect(x0 + 1, y0 + 1, x1 - 1, y1 - 1, floor)

    def disc(self, cx, cy, r, k):
        for y in range(H):
            for x in range(W):
                if math.hypot(x - cx, y - cy) <= r:
                    self.t[y][x] = k

    def ring(self, cx, cy, r0, r1, k):
        for y in range(H):
            for x in range(W):
                if r0 < math.hypot(x - cx, y - cy) <= r1:
                    self.t[y][x] = k


def build_plant():
    g = Canvas("grass")         # ground level
    r = Canvas("air")           # roofs
    # compound, fence, forecourt
    g.rect(3, 3, 92, 68, "fence"); g.rect(4, 4, 91, 67, "pave")
    g.rect(44, 3, 51, 68, "road")                               # gate road runs north from the gate
    g.rect(44, 68, 51, 71, "road")
    for x in (43, 52):
        for y in (68, 67):
            g.put(x, y, "pave"); g.fur(x, y, "neon_pink")
    g.rect(4, 56, 43, 67, "pave")
    # cooling towers (two): neon rim, water basin, steam stack
    for cx, cy in ((16, 18), (16, 44)):
        g.disc(cx, cy, 11, "wall_neon"); g.disc(cx, cy, 9, "wall_conc"); g.disc(cx, cy, 8, "water"); g.disc(cx, cy, 4, "shallow")
        g.fur(cx, cy, "cooling_fan")
        for a in range(0, 360, 20):
            g.fur(round(cx + 10 * math.cos(math.radians(a))), round(cy + 10 * math.sin(math.radians(a))), "neon_cyan" if (a // 20) % 2 else "neon_pink")
        r.disc(cx, cy, 11, "roof"); r.disc(cx, cy, 8, "air")   # the tower is open at the top
    # turbine hall
    g.box(30, 8, 60, 28, "wall_corp", "floor")
    for x in range(32, 59, 4):
        g.put(x, 8, "window"); g.put(x, 28, "window")
    g.put(45, 28, "door")
    for x in (36, 42, 48, 54):
        for y in (13, 21):
            g.fur(x, y, "turbine")
    for x in range(33, 58):
        g.fur(x, 10, "pipes")
    for x in (34, 58):
        g.fur(x, 25, "console"); g.fur(x, 26, "chair_office")
    for x in range(34, 59, 6):
        g.fur(x, 17, "neon_cyan")
    r.rect(30, 8, 60, 28, "roof")
    # reactor dome
    g.disc(74, 36, 14, "wall_neon"); g.disc(74, 36, 13, "floor"); g.disc(74, 36, 8, "neon_p"); g.disc(74, 36, 6, "grating")
    g.fur(74, 36, "reactor_core")
    for dx, dy in ((-3, 0), (3, 0), (0, -3), (0, 3)):
        g.fur(74 + dx, 36 + dy, "pipes")
    for dx, dy in ((-6, -6), (6, -6), (-6, 6), (6, 6)):
        g.fur(74 + dx, 36 + dy, "console")
    g.put(74, 50, "door"); g.put(74, 49, "floor")
    r.disc(74, 36, 14, "roof"); r.disc(74, 36, 5, "neon_p")
    # control block
    g.box(64, 6, 90, 20, "wall_corp", "floor")
    for x in range(66, 89, 3):
        g.put(x, 6, "window"); g.put(x, 20, "window")
    g.put(77, 20, "door")
    for x in range(67, 88, 3):
        g.fur(x, 9, "console"); g.fur(x, 10, "chair_office")
        g.fur(x, 13, "server_rack")
    g.fur(70, 17, "holo_ad"); g.fur(84, 17, "holo_ad"); g.fur(77, 16, "reception")
    r.rect(64, 6, 90, 20, "roof")
    # gate road, lamps, gatehouse (armory to the west, guard post to the east)
    g.box(30, 56, 43, 66, "wall_corp", "floor"); g.put(43, 61, "door"); g.put(31, 56, "window"); g.put(38, 56, "window")
    for y in (58, 60, 62, 64):
        g.fur(32, y, "cabinet_lacquer"); g.fur(33, y, "crate"); g.fur(40, y, "shelf_clean")
    g.fur(36, 60, "neon_pink"); g.fur(37, 64, "floor_lamp")
    ARMORY = [(32, y) for y in (58, 60, 62, 64)] + [(40, y) for y in (58, 60, 62, 64)]
    g.box(52, 56, 62, 66, "wall_corp", "floor"); g.put(52, 62, "door"); g.put(57, 56, "window")
    g.fur(55, 59, "desk_corp"); g.fur(55, 60, "chair_office"); g.fur(59, 59, "console"); g.fur(60, 63, "vending")
    r.rect(30, 56, 43, 66, "roof"); r.rect(52, 56, 62, 66, "roof")
    # transformer yard, solar field and lights
    g.rect(66, 54, 90, 66, "gravel")
    for y in (56, 60, 64):
        for x in range(67, 90, 3):
            g.fur(x, y, "transformer")
    for x, y in ((66, 54), (90, 54), (66, 66), (90, 66)):
        g.fur(x, y, "pylon")
    for y in (54, 66):
        for x in range(67, 90):
            g.fur(x, y, "cable_ew")
    g.rect(8, 58, 28, 66, "gravel")
    for y in (59, 62, 65):
        for x in range(9, 28, 2):
            g.fur(x, y, "solar_panel")
    for x, y in ((8, 8), (8, 30), (8, 52)):
        g.fur(x, y, "wind_turbine")
    for y in range(8, 66, 8):
        g.fur(43, y, "street_lamp"); g.fur(52, y, "street_lamp")
    for x in range(6, 90, 8):
        g.fur(x, 5, "neon_cyan"); g.fur(x, 66, "neon_pink")
    # roofs: panels on the halls, turbines on the control block
    for x in range(32, 59, 3):
        for y in (11, 14, 17, 20, 23):
            r.fur(x, y, "solar_panel")
    for x in range(66, 89, 4):
        r.fur(x, 8, "wind_turbine")
    for x in range(66, 89, 3):
        for y in (13, 16):
            r.fur(x, y, "solar_panel")
    for x in range(32, 43, 2):
        r.fur(x, 59, "solar_panel"); r.fur(x, 63, "solar_panel")
    # people: the NAP guard the gate and the reactor; engineers work the control block
    npcs = [("trl_nc_nap_patrol", 46, 66), ("trl_nc_nap_patrol", 49, 66), ("trl_nc_nap_patrol", 55, 61), ("trl_nc_nap_patrol", 46, 40),
            ("trl_nc_nap_tactical", 74, 46), ("trl_nc_nap_tactical", 68, 36), ("trl_nc_nap_riot", 48, 60),
            ("trl_nc_res_mid_engineer", 70, 11), ("trl_nc_res_mid_engineer", 80, 11), ("trl_nc_res_mid_engineer", 45, 19)]
    return g, r, ARMORY, npcs


def tile_mapgen(canvas, tx, ty, roof, extra):
    pal = {}
    pool = list("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
    rows = []
    for y in range(24):
        row = ""
        for x in range(24):
            k = canvas.t[ty * 24 + y][tx * 24 + x]
            if k not in pal:
                pal[k] = pool[len(pal)]
            row += pal[k]
        rows.append(row)
    obj = {"fill_ter": "t_open_air" if roof else "t_grass", "rows": rows, "terrain": {c: TER[k] for k, c in pal.items()},
           "place_furniture": [{"furn": "f_trl_" + key, "x": x - tx * 24, "y": y - ty * 24} for (x, y), key in sorted(canvas.f.items())
                               if tx * 24 <= x < tx * 24 + 24 and ty * 24 <= y < ty * 24 + 24]}
    obj.update(extra)
    return {"type": "mapgen", "om_terrain": plant_id(tx, ty, roof), "object": obj}


g, r, ARMORY, NPCS = build_plant()
for ty in range(TY):
    for tx in range(TX):
        extra = {}
        n = [{"class": c, "x": x - tx * 24, "y": y - ty * 24} for c, x, y in NPCS if tx * 24 <= x < tx * 24 + 24 and ty * 24 <= y < ty * 24 + 24]
        if n:
            extra["place_npcs"] = n
        its = [{"item": "trl_w2011_cache", "x": x - tx * 24, "y": y - ty * 24, "chance": 70} for x, y in ARMORY
               if tx * 24 <= x < tx * 24 + 24 and ty * 24 <= y < ty * 24 + 24]
        if its:
            extra["place_items"] = its
        out.append(tile_mapgen(g, tx, ty, False, extra))
        out.append(tile_mapgen(r, tx, ty, True, {}))
out.append({"type": "item_group", "id": "trl_w2011_cache", "subtype": "distribution",
            "entries": [{"item": "trl_gun_w2011", "prob": 14}, {"item": "heavy_battery_cell", "prob": 30, "count": [1, 2]},
                        {"item": "medium_battery_cell", "prob": 40, "count": [2, 4]}, {"group": "trl_loot_guns", "prob": 16}, {"group": "trl_loot_armor", "prob": 24}]})

# ---------------------------------------------------------------- powerline tiles: one mapgen per linear variant
# the engine rotates one drawing per shape: straight (north-south), curved (east and south), end (south), tee (east, south, west), four-way
ARMS = {"isolated": "", "straight": "ns", "curved": "es", "end": "s", "tee": "esw", "four_way": "nesw"}
for name, arms in ARMS.items():
    furn_list = [{"furn": "f_trl_pylon", "x": 12, "y": 12}]
    for a in arms:
        if a in "ew":
            xs = range(0, 12) if a == "w" else range(13, 24)
            furn_list += [{"furn": "f_trl_cable_ew", "x": x, "y": 12} for x in xs]
        else:
            ys = range(0, 12) if a == "n" else range(13, 24)
            furn_list += [{"furn": "f_trl_cable_ns", "x": 12, "y": y} for y in ys]
    out.append({"type": "mapgen", "om_terrain": "trl_powerline_" + name,
                "object": {"fallback_predecessor_mapgen": "field", "rows": [" " * 24] * 24, "place_furniture": furn_list}})

# ---------------------------------------------------------------- tidal generator tile: deep water, steel platforms, turbines
rows = [["w"] * 24 for _ in range(24)]
pal = {"w": "t_water_dp", "g": "t_trl_grating", "n": "t_trl_neon_cyan"}
fl = []
for (cx, cy) in ((6, 6), (17, 6), (6, 17), (17, 17)):
    for dy in range(-1, 2):
        for dx in range(-1, 2):
            rows[cy + dy][cx + dx] = "g"
    fl.append({"furn": "f_trl_tidal_turbine", "x": cx, "y": cy})
for i in range(5, 19):
    rows[11][i] = "g"; rows[12][i] = "g"
fl += [{"furn": "f_trl_neon_cyan", "x": 12, "y": 11}, {"furn": "f_trl_street_lamp", "x": 8, "y": 11}, {"furn": "f_trl_street_lamp", "x": 16, "y": 12},
       {"furn": "f_trl_substation_unit", "x": 11, "y": 12}]
out.append({"type": "mapgen", "om_terrain": "trl_tidal", "object": {"fill_ter": "t_water_dp", "rows": ["".join(r_) for r_ in rows], "terrain": pal, "place_furniture": fl}})

json.dump(out, open(os.path.join(MOD, "grid.json"), "w"), indent=1)
print("grid: plant tiles", TX * TY, "x2 levels, powerline variants", len(ARMS), "tidal tile")
