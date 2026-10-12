#!/usr/bin/env python3
"""Generate 100 Trilobit houses: 50 slum shacks, 35 middle-class houses, 15 rich houses (1-2 tiles).
Run AFTER gen_city.py, gen_places.py, gen_midrise.py.  usage: gen_houses.py <mod dir> <stock regional_map_settings.json>"""
import json, os, random, sys, hashlib
MOD = sys.argv[1]
STOCK = sys.argv[2] if len(sys.argv) > 2 else None
sys.argv = [sys.argv[0], MOD]
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_midrise as mr
from gen_midrise import gp, T, F, FLOORS, WALLS, nfur, nter, exist, POOL
from gen_places import SOLID, SURF

# ------------------------------------------------------------------ catalog additions
exist("fence", "t_chainfence"); exist("dirt", "t_dirt"); exist("garage_door", "t_door_metal_corrugated_c")
exist("pool", "t_water_pool"); exist("pool_sh", "t_water_pool_shallow")
exist("wall_wood", "t_wall_wood"); exist("carpet_green", "t_carpet_green"); exist("carpet_purple", "t_carpet_purple")
exist("floor_waxed", "t_floor_waxed"); exist("rock_floor", "t_rock_floor"); exist("rock", "t_rock")
exist("window_dom", "t_window_domestic"); exist("wall_metal", "t_wall_metal")
FLOORS.update({"dirt", "carpet_green", "carpet_purple", "floor_waxed", "rock_floor", "pool_sh"})
WALLS.update({"wall_wood", "wall_metal"})

HOUSE_F = set()
def stock(key, fid):
    F["s_" + key] = dict(id=fid, name=key, desc="", sym="?", color="white", light=0, kw={}, existing=True)
for k, i in dict(bed="f_bed", sofa="f_sofa", armchair="f_armchair", table="f_table", chair="f_chair", fridge="f_fridge",
                 oven="f_oven", sink="f_sink", toilet="f_toilet", bath="f_bathtub", dresser="f_dresser", bookcase="f_bookcase",
                 counter="f_counter", cupboard="f_cupboard", washer="f_washer", dryer="f_dryer", woodstove="f_woodstove",
                 rack="f_rack", locker="f_locker", desk="f_desk", stool="f_stool", wardrobe="f_wardrobe",
                 makeshift_bed="f_makeshift_bed", cardbox="f_cardboard_box", dumpster="f_dumpster", bench="f_bench",
                 treadmill="f_treadmill", exercise="f_exercise", punchbag="f_punching_bag", fireplace="f_fireplace",
                 piano="f_piano", coffee="f_coffee_table", trashcan="f_trashcan", glass_cab="f_glass_cabinet",
                 workbench="f_workbench", filing="f_filing_cabinet", ergometer="f_ergometer", robot_arm="f_robotic_arm",
                 server="f_server", pool_table="f_pool_table").items():
    stock(k, i)

def hfur(*a, **k):
    nfur(*a, **k); HOUSE_F.add(a[0])
hfur("tv_flat", "wall screen", "A flat screen on the wall, dark and faintly reflecting the room.", "V", "light_gray", 6, flags=SOLID)
hfur("nightstand", "nightstand", "A small bedside table with a drawer.", "n", "brown", flags=SURF)
hfur("weight_rack", "weight rack", "A rack of iron plates and a bench.", "W", "light_gray", flags=SOLID)
hfur("hot_tub", "hot tub", "A round tub of steaming water with a faintly glowing rim.", "O", "light_blue", 8, flags=SOLID)
hfur("kitchen_island", "kitchen island", "A counter island with a built-in induction hob.", "I", "white", flags=SURF)
hfur("clothesline", "clothesline", "A sagging line of damp laundry between two poles.", "~", "white", flags=SOLID, passable=True)
hfur("vr_rig", "immersion rig", "A reclined chair with a visor, cables and a humming rack behind it.", "v", "light_cyan", 7, flags=SOLID)
hfur("garden_bed", "garden bed", "A raised bed of vegetables and herbs.", "g", "green", flags=SOLID)
hfur("sun_lounger", "sun lounger", "A folding lounger beside the water.", "l", "light_gray", flags=["TRANSPARENT", "MOUNTABLE"])
hfur("bbq", "barbecue grill", "A squat charcoal grill.", "b", "dark_gray", flags=SOLID)
hfur("mailbox", "mailbox", "A dented mailbox on a post.", "m", "light_gray", flags=SOLID)
hfur("antenna", "rooftop antenna", "A tangle of salvaged antenna and dish.", "Y", "light_gray", flags=SOLID)
hfur("car_charger", "charge post", "A charging post with a steady green light.", "c", "light_green", 7, flags=SOLID)
hfur("holo_wall", "holographic wall", "A wall of shifting light showing a rain-lit city that does not exist.", "H", "light_cyan", 13, flags=SOLID)
hfur("garden_lamp", "garden lamp", "A low lamp lighting the path.", "i", "yellow", 12, flags=SOLID, passable=True)
hfur("koi_basin", "koi basin", "A stone basin with slow orange fish.", "o", "light_cyan", 5, flags=SOLID)

# ------------------------------------------------------------------ canvas
class Cv:
    def __init__(s, nx, base="grass"):
        s.nx = nx; s.w = 24 * nx
        s.t = [[base] * s.w for _ in range(24)]
        s.f = []; s.occ = set(); s.rng = random.Random(0); s.cars = []; s.loot = []
        for i in range(s.w):
            s.t[0][i] = "walk"; s.t[23][i] = "walk"
        for j in range(24):
            s.t[j][0] = "walk"; s.t[j][s.w - 1] = "walk"
    def fill(s, x0, y0, x1, y1, k):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if 0 <= x < s.w and 0 <= y < 24: s.t[y][x] = k
    def box(s, x0, y0, x1, y1, wall, floor):
        s.fill(x0, y0, x1, y1, wall); s.fill(x0 + 1, y0 + 1, x1 - 1, y1 - 1, floor)
    def put(s, k, x, y):
        if 0 <= x < s.w and 0 <= y < 24: s.t[y][x] = k
    def free(s, x, y):
        return 0 < x < s.w - 1 and 0 < y < 23 and s.t[y][x] in FLOORS and (x, y) not in s.occ
    def f_(s, key, x, y):
        k = F[key]
        if s.free(x, y):
            s.f.append((key, x, y)); s.occ.add((x, y)); return True
        return False
    def scatter(s, key, x0, y0, x1, y1, n):
        tries = placed = 0
        while placed < n and tries < 120:
            tries += 1
            if s.f_(key, s.rng.randint(x0, x1), s.rng.randint(y0, y1)): placed += 1

DOORS = {"door_wood", "door_c", "shutter_c", "screen_c", "door_steel", "garage_door"}
def door_cells(g):
    return [(x, y) for y in range(24) for x in range(g.w) if g.t[y][x] in DOORS]

def along_wall(g, rect, keys):
    """Place furniture on cells touching the walls of an interior rect, away from doors."""
    x0, y0, x1, y1 = rect
    bad = set()
    for dx, dy in door_cells(g):
        for a in (-1, 0, 1):
            for b in (-1, 0, 1): bad.add((dx + a, dy + b))
    cells = [(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)
             if (x in (x0, x1) or y in (y0, y1)) and (x, y) not in bad]
    g.rng.shuffle(cells)
    n = 0
    for key in keys:
        for i, (x, y) in enumerate(cells):
            if g.f_(key, x, y):
                cells.pop(i); n += 1; break
    return n

def centre_table(g, rect, table, seat, nseat=2):
    x0, y0, x1, y1 = rect
    if x1 - x0 < 3 or y1 - y0 < 3: return
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    if g.f_(table, cx, cy):
        for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1))[:nseat + 1]:
            g.f_(seat, cx + dx, cy + dy)

def subdivide(g, x0, y0, x1, y1, nx, ny, wall, floor, door="door_wood"):
    """Outer box x0..x1,y0..y1 split into nx*ny rooms.  Returns dict[(i,j)] -> interior rect."""
    g.box(x0, y0, x1, y1, wall, floor)
    xs = [x0 + (x1 - x0) * i // nx for i in range(nx + 1)]
    ys = [y0 + (y1 - y0) * j // ny for j in range(ny + 1)]
    for i in range(1, nx):
        for y in range(y0 + 1, y1): g.t[y][xs[i]] = wall
    for j in range(1, ny):
        for x in range(x0 + 1, x1): g.t[ys[j]][x] = wall
    rooms = {}
    for i in range(nx):
        for j in range(ny):
            rooms[(i, j)] = (xs[i] + 1, ys[j] + 1, xs[i + 1] - 1, ys[j + 1] - 1)
    for i in range(1, nx):
        for j in range(ny):
            r = rooms[(i, j)]; g.t[(r[1] + r[3]) // 2][xs[i]] = door
    for j in range(1, ny):
        for i in range(nx):
            r = rooms[(i, j)]; g.t[ys[j]][(r[0] + r[2]) // 2] = door
    return rooms

def windows(g, x0, y0, x1, y1, key, step=3, skip=()):
    for x in range(x0 + 2, x1 - 1, step):
        for y in (y0, y1):
            if (x not in skip or y == y0) and g.t[y][x] in WALLS and g.t[y][x - 1] not in DOORS and g.t[y][x + 1] not in DOORS:
                g.t[y][x] = key
    for y in range(y0 + 2, y1 - 1, step):
        for x in (x0, x1):
            if g.t[y][x] in WALLS and g.t[y - 1][x] not in DOORS and g.t[y + 1][x] not in DOORS:
                g.t[y][x] = key

def lights(g, n=3):
    cnt = sum(1 for k, _, _ in g.f if F[k]["light"] >= 4)
    for pos in [(2, 22), (21, 22), (g.w - 3, 22), (2, 2), (g.w - 3, 2), (12, 21), (g.w // 2, 21), (3, 12), (g.w - 4, 12)]:
        if cnt >= n: break
        if g.f_("street_lamp", *pos): cnt += 1

def fence(g, x0, y0, x1, y1, gaps, key="fence"):
    for x in range(x0, x1 + 1):
        for y in (y0, y1):
            if g.t[y][x] in ("grass", "gravel", "pave", "dirt") and x not in gaps: g.t[y][x] = key
    for y in range(y0, y1 + 1):
        for x in (x0, x1):
            if g.t[y][x] in ("grass", "gravel", "pave", "dirt"): g.t[y][x] = key

def path(g, x, y0, y1, k="pave"):
    for y in range(y0, y1 + 1):
        if g.t[y][x] in ("grass", "gravel", "dirt", "fence"): g.t[y][x] = k

# ------------------------------------------------------------------ themes
# per theme: wall, floor, window, door, room extras, yard extras, flavour names
TH = {
 "tea":      dict(wall="wall_slat", floor="floor_wood", win="window", door="screen_c", living=["tea_table", "tea_shelf", "red_lantern"], yard=["bonsai", "red_lantern", "planter"], bed=["futon"], kitchen=["samovar"], loot="dingy"),
 "noodle":   dict(wall="wall_rust", floor="floor_dirty", win="window", door="door_wood", living=["noodle_cart", "stool_plastic", "lantern"], yard=["noodle_cart", "stool_plastic", "lantern", "trash"], bed=["mattress"], kitchen=["hotplate"], loot="dingy"),
 "scrap":    dict(wall="wall_pipes", floor="slab", win="window_bars", door="shutter_c", living=["shelf_scrap", "crate", "pipes"], yard=["crate", "pipes", "fire_drum", "trash"], bed=["bunk_rust"], kitchen=["hotplate"], loot="dingy"),
 "android":  dict(wall="wall_corp", floor="floor_steel", win="window", door="door_steel", living=["charge_rack", "test_bench", "limb_bin"], yard=["charging_pod", "limb_bin", "crystal_lamp"], bed=["capsule"], kitchen=["charge_rack"], loot="android"),
 "mil":      dict(wall="wall_olive", floor="floor_olive", win="window_bars", door="door_steel", living=["locker_mil", "ammo_crate", "map_table"], yard=["sandbags", "ammo_crate", "sentry_lamp"], bed=["cot"], kitchen=["hotplate"], loot="mil"),
 "gambler":  dict(wall="wall_lacquer", floor="carpet_red", win="window", door="door_wood", living=["table_card", "tv_static", "neon_amber"], yard=["neon_amber", "bar_stool", "trash"], bed=["mattress"], kitchen=["hotplate"], loot="dingy"),
 "izba":     dict(wall="wall_wood", floor="floor_wood", win="window_dom", door="door_wood", living=["tiled_stove", "icon_lamp", "samovar"], yard=["fern", "water_barrel", "planter"], bed=["s_bed"], kitchen=["s_woodstove"], loot="dingy"),
 "courtyard":dict(wall="wall_lacquer", floor="tatami", win="window", door="screen_c", living=["red_lantern", "banner_red", "vase_red", "tea_table"], yard=["red_lantern", "vase_red", "bonsai", "fern"], bed=["futon"], kitchen=["tea_shelf"], loot="dingy"),
 "neon":     dict(wall="wall_neon", floor="checker", win="window", door="door_c", living=["neon_pink", "speaker", "mirror_ball"], yard=["neon_cyan", "neon_pink", "holo_ad"], bed=["futon"], kitchen=["vending"], loot="dingy"),
 "water":    dict(wall="wall_rust", floor="floor_dirty", win="window", door="shutter_c", living=["water_barrel", "water_barrel", "crate"], yard=["water_barrel", "water_barrel", "water_barrel", "pipes"], bed=["mattress"], kitchen=["hotplate"], loot="dingy"),
}

def seat_set(th, rich=False):
    return {"sofa": "s_sofa", "table": "s_table", "chair": "s_chair"}

# ------------------------------------------------------------------ poor shacks
def shack(g, x0, y0, x1, y1, th, door_side="s"):
    g.box(x0, y0, x1, y1, th["wall"], th["floor"])
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    if door_side == "s": g.put(th["door"], cx, y1)
    elif door_side == "e": g.put(th["door"], x1, cy)
    else: g.put(th["door"], x0, cy)
    windows(g, x0, y0, x1, y1, th["win"], 3)
    inner = (x0 + 1, y0 + 1, x1 - 1, y1 - 1)
    if x1 - x0 >= 8 and g.rng.random() < 0.6:       # lean-to partition
        px = x0 + (x1 - x0) // 2 + g.rng.choice((-1, 0, 1))
        for y in range(y0 + 1, y1): g.t[y][px] = th["wall"]
        g.t[y1 - 2][px] = "door_wood"
        along_wall(g, (x0 + 1, y0 + 1, px - 1, y1 - 1), [g.rng.choice(th["bed"])] + [g.rng.choice(th["living"])])
        along_wall(g, (px + 1, y0 + 1, x1 - 1, y1 - 1), [g.rng.choice(th["kitchen"]), "water_barrel", g.rng.choice(th["living"]), "crate"])
    else:
        along_wall(g, inner, [g.rng.choice(th["bed"]), g.rng.choice(th["kitchen"])] + th["living"][:3] + ["crate"] * g.rng.randint(0, 2) + ["tv_static"] * g.rng.randint(0, 1))
    # a hanging light inside
    g.f_("lantern", x0 + 1, y0 + 1) or g.f_("lantern", x1 - 1, y0 + 1) or g.f_("desk_lamp", x0 + 1, y1 - 1)
    return (x0, y0, x1, y1)

def poor_house(spec, rng):
    th = TH[spec["theme"]]
    g = Cv(1, base=rng.choice(("gravel", "dirt", "pave", "gravel")))
    g.rng = rng
    shacks = []
    duo = spec["duo"]
    ground = rng.choice(("gravel", "dirt", "pave"))
    g.fill(1, 1, 22, 22, ground)
    if duo:
        wa, wb = rng.randint(5, 7), rng.randint(5, 7)
        ha, hb = rng.randint(4, 6), rng.randint(4, 6)
        xa = rng.randint(2, 4); xb = 21 - wb + 1 - rng.randint(0, 2)
        ya = 19 - rng.randint(0, 3); yb = 19 - rng.randint(0, 5)
        thb = TH[spec.get("theme2", spec["theme"])]
        shacks.append(shack(g, xa, ya - ha + 1, xa + wa, ya, th, "s"))
        shacks.append(shack(g, xb, yb - hb + 1, xb + wb, yb, thb, rng.choice(("s", "s", "w"))))
    else:
        w, h = rng.randint(7, 11), rng.randint(5, 7)
        x0 = rng.randint(3, 21 - w); y1 = 19 - rng.randint(0, 3)
        shacks.append(shack(g, x0, y1 - h + 1, x0 + w, y1, th, rng.choice(("s", "s", "s", "e", "w"))))
    # yard
    for key in th["yard"]:
        g.scatter(key, 2, 2, 21, 21, rng.randint(1, 3))
    if rng.random() < 0.6: g.scatter("laundry", 2, 2, 21, 21, rng.randint(1, 2))
    if rng.random() < 0.5: g.scatter("fire_drum", 2, 2, 21, 21, 1)
    if rng.random() < 0.4: g.scatter("antenna", 2, 2, 21, 21, 1)
    g.scatter("trash", 2, 2, 21, 21, rng.randint(2, 5))
    for k in rng.sample(["neon_amber", "neon_red", "neon_green", "neon_cyan"], 1): g.f_(k, rng.randint(3, 20), 22)
    if rng.random() < 0.5:
        fence(g, 1, 1, 22, 22, set(range(9, 15)))
    lights(g, 3)
    g.rect_loot = shacks
    return [g], dict(stories=1, roofs=[(0, s, 1) for s in shacks], loot="dingy", loot_rects=shacks)

# ------------------------------------------------------------------ middle / rich houses
def build_block(levels, rect, stories, th, ctx, basement=False):
    """Create walls/rooms on each level for one block; returns room map per level."""
    x0, y0, x1, y1 = rect
    w, h = x1 - x0 + 1, y1 - y0 + 1
    nx = 3 if w >= 15 else 2
    ny = 2 if h >= 8 else 1
    rooms_by_z = {}
    for z in range(stories):
        g = levels[z]
        wall = th["wall"] if z == 0 else th.get("wall_up", th["wall"])
        rooms = subdivide(g, x0, y0, x1, y1, nx, ny, wall, th["floor"] if z == 0 else th.get("floor_up", th["floor"]))
        rooms_by_z[z] = rooms
        windows(g, x0, y0, x1, y1, th["win"], 3)
    # front door in ground floor, bottom row middle-left cell
    g0 = levels[0]
    r = rooms_by_z[0][(0, ny - 1)]
    dx = (r[0] + r[2]) // 2
    g0.put(th["door"], dx, y1)
    ctx["door_x"] = dx
    return rooms_by_z, nx, ny

def furnish_ground(g, rooms, nx, ny, th, ctx, rich):
    rng = g.rng
    cells = sorted(rooms)
    # living room = front-left, kitchen next to it, rest cycle
    types = ["living", "kitchen", "den", "bath", "bedroom", "study"]
    order = [(0, ny - 1)] + [c for c in cells if c != (0, ny - 1)]
    for t, c in zip(types + types, order):
        r = rooms[c]
        if t == "living":
            along_wall(g, r, ["s_sofa", "tv_flat", "s_bookcase", "floor_lamp"] + th["living"][:2] + (["s_piano"] if rich and rng.random() < .4 else []))
            centre_table(g, r, "s_coffee", "s_armchair", 1)
        elif t == "kitchen":
            along_wall(g, r, ["s_fridge", "s_oven", "s_sink", "s_counter", "s_cupboard"] + th["kitchen"][:1])
            centre_table(g, r, "kitchen_island" if rich else "s_table", "s_chair", 3)
        elif t == "den":
            along_wall(g, r, th["living"][-2:] + ["s_sofa", "s_bookcase"] + (["arcade"] if rng.random() < .3 else []))
        elif t == "bath":
            along_wall(g, r, ["s_toilet", "s_sink", "s_bath", "s_washer"] + (["s_dryer"] if rich else []))
        elif t == "bedroom":
            along_wall(g, r, ["s_bed", "nightstand", "s_dresser", "s_wardrobe", "floor_lamp"])
        else:
            along_wall(g, r, ["s_desk", "s_chair", "s_filing", "s_bookcase", "desk_lamp"])

def furnish_upper(g, rooms, th, rich):
    types = ["bedroom", "bedroom", "bath", "study", "bedroom", "bedroom"]
    for t, c in zip(types, sorted(rooms)):
        r = rooms[c]
        if t == "bedroom":
            along_wall(g, r, [g.rng.choice(("s_bed", "s_bed", th["bed"][0])) if th["bed"][0].startswith("s_") else "s_bed", "nightstand", "s_dresser", "s_wardrobe", "floor_lamp"])
        elif t == "bath":
            along_wall(g, r, ["s_toilet", "s_sink", "s_bath"] + (["hot_tub"] if rich and g.rng.random() < .3 else []))
        else:
            along_wall(g, r, ["s_desk", "s_chair", "s_bookcase", "desk_lamp"] + th["living"][-1:])

def garage_block(g, rect, cars, door_gap, rich):
    x0, y0, x1, y1 = rect
    g.box(x0, y0, x1, y1, "wall_concrete", "slab")
    cx = (x0 + x1) // 2
    for x in range(cx - door_gap // 2, cx - door_gap // 2 + door_gap): g.put("garage_door", x, y1)
    inner = (x0 + 1, y0 + 1, x1 - 1, y1 - 1)
    along_wall(g, inner, ["s_workbench", "s_rack", "s_rack", "car_charger", "crate"] + (["weight_rack"] if rich else []))
    g.put("window", x0, (y0 + y1) // 2) if g.t[(y0 + y1) // 2][x0] in WALLS else None
    for vx, vy, vr in cars: g.cars.append((vx, vy, vr))
    g.f_("floor_lamp", x1 - 1, y0 + 1)

def middle_or_rich(spec, rng):
    rich = spec["rich"]
    th = dict(TH[spec["theme"]])
    # house wants domestic floors/windows
    th["floor"] = spec.get("floor", th["floor"] if th["floor"] not in ("slab", "floor_dirty") else "floor_wood")
    th["win"] = spec.get("win", "window" if th["win"] == "window_bars" else th["win"])
    th["floor_up"] = spec.get("floor_up", "carpet_green" if spec["theme"] in ("izba", "mil") else "carpet_purple" if rich else "floor_wood")
    nx = spec["tiles"]
    stories = spec["stories"]
    levels = {}
    zs = list(range(-1 if spec.get("basement") else 0, stories + 1))
    for z in zs:
        levels[z] = Cv(nx, base="air" if z > 0 else "rock" if z < 0 else spec.get("yard", "grass"))
        levels[z].rng = random.Random(rng.random())
        if z != 0:
            levels[z].fill(0, 0, levels[z].w - 1, 23, "air" if z > 0 else "rock")
    g = levels[0]; g.rng = rng
    W = 24 * nx
    # --- plan
    if rich:
        hw = rng.randint(15, 19) if nx == 2 else rng.randint(9, 11)
        hh = rng.randint(10, 12) if nx == 2 else rng.randint(8, 9)
        gw = 10 if nx == 2 else 8
    else:
        hw = rng.randint(10, 12); hh = rng.randint(9, 11); gw = 8
    has_garage = spec["garage"]
    total = hw + (gw - 1 if has_garage else 0)
    xs = rng.randint(2, W - 2 - total)
    ys1 = 20 if not rich or nx == 1 else rng.choice((19, 20))
    if has_garage and rng.random() < .5:
        gx0 = xs; hx0 = xs + gw - 1
    else:
        hx0 = xs; gx0 = xs + hw - 1
    hrect = (hx0, ys1 - hh + 1, hx0 + hw - 1, ys1)
    ctx = {}
    # yard base
    g.fill(1, 1, W - 2, 22, spec.get("yard", "grass"))
    # blocks
    rooms_by_z, bx, by = build_block(levels, hrect, stories, th, ctx, basement=False)
    # stairs: top-left interior corner of the front-left room on ground; same on upper floors
    sr = rooms_by_z[0][(0, by - 1)]
    sx_, sy_ = sr[0], sr[1]
    if stories > 1:
        for z in range(stories - 1):
            levels[z].put("stair_up", sx_, sy_); levels[z].occ.add((sx_, sy_))
            levels[z + 1].put("stair_down", sx_, sy_); levels[z + 1].occ.add((sx_, sy_))
    # basement
    if spec.get("basement"):
        b = levels[-1]
        br = subdivide(b, *hrect, bx, 1, "wall_concrete", "floor_waxed")
        # stairs down from ground to basement at the right end of the front-left room
        bsx, bsy = sr[2], sr[3]
        g.put("stair_down", bsx, bsy); g.occ.add((bsx, bsy))
        b.put("stair_up", bsx, bsy); b.occ.add((bsx, bsy))
        # make sure stair is inside a basement room
        for rr in br.values():
            pass
        btypes = spec.get("btypes", ["gym", "theatre", "server"])
        for t, c in zip(btypes, sorted(br)):
            r = br[c]
            if t == "gym": along_wall(b, r, ["s_treadmill", "s_exercise", "s_punchbag", "weight_rack", "s_ergometer", "floor_lamp"])
            elif t == "theatre": along_wall(b, r, ["holo_wall", "s_sofa", "s_sofa", "vr_rig", "speaker", "floor_lamp"])
            elif t == "server": along_wall(b, r, ["server_rack", "server_rack", "console", "s_server", "s_desk", "floor_lamp"])
            elif t == "lab": along_wall(b, r, ["test_bench", "s_robot_arm", "limb_bin", "console", "floor_lamp"])
            elif t == "armoury": along_wall(b, r, ["weapon_rack", "weapon_rack", "ammo_crate", "locker_mil", "floor_lamp"])
            elif t == "cellar": along_wall(b, r, ["s_rack", "s_rack", "crate", "water_barrel", "floor_lamp"])
            else: along_wall(b, r, ["s_pool_table", "bar_stool", "floor_lamp"])
        b.lamps_ok = True
    # furnish
    furnish_ground(g, rooms_by_z[0], bx, by, th, ctx, rich)
    for z in range(1, stories):
        furnish_upper(levels[z], rooms_by_z[z], th, rich)
    # garage
    garect = None
    if has_garage:
        garect = (gx0, ys1 - 8, gx0 + gw - 1, ys1) if not (rich and nx == 2) else (gx0, ys1 - 9, gx0 + gw - 1, ys1)
        ghalf = (garect[0] + garect[2]) // 2
        cars = [(ghalf, (garect[1] + garect[3]) // 2, rng.choice((90, 270)))]
        if rich and nx == 2:
            cars = [(garect[0] + 3, (garect[1] + garect[3]) // 2, 90), (garect[2] - 3, (garect[1] + garect[3]) // 2, 90)]
        garage_block(g, garect, [(x, y, r) for x, y, r in cars], 3 if gw < 10 else 6, rich)
        # interior door between house and garage
        wallx = hrect[0] if gx0 > hx0 and False else None
        shared = hrect[0] if hx0 > gx0 else hrect[2]
        gy = max(hrect[1], garect[1]) + 3
        if gy < min(hrect[3], garect[3]) - 1:
            g.put("door_wood", shared, gy)
            g.put("door_wood", shared, gy) if g.t[gy][shared] in WALLS or True else None
        # drive
        dw = range(ghalf - 1, ghalf + 2) if gw < 10 else range(garect[0] + 2, garect[2] - 1)
        for x in dw:
            for y in range(ys1 + 1, 23): g.put("pave", x, y)
    # front path + fence
    path(g, ctx["door_x"], ys1 + 1, 22)
    gaps = set(range(ctx["door_x"] - 1, ctx["door_x"] + 2))
    if has_garage:
        gaps |= set(range(garect[0], garect[2] + 1))
    if spec.get("fence", True):
        fence(g, 1, 1, W - 2, 22, gaps)
    # roofs
    if has_garage:
        top_g = 1
        levels[1].fill(garect[0], garect[1], garect[2], garect[3], "roof")
    for z in range(1, stories + 1):
        pass
    levels[stories].fill(hrect[0], hrect[1], hrect[2], hrect[3], "roof")
    if has_garage and stories == 1:
        pass
    # --- yard dressing
    back = (2, 2, W - 3, hrect[1] - 2)
    for key in th["yard"]:
        g.scatter(key, 2, 2, W - 3, 21, rng.randint(2, 4))
    g.f_("mailbox", ctx["door_x"] + 2, 22)
    for key in ("garden_lamp", "garden_lamp"):
        g.scatter(key, 2, ys1 + 1, W - 3, 21, 1)
    if spec.get("pool") and back[3] - back[1] >= 4:
        pw = rng.randint(6, 9) if nx == 2 else 6
        ph = min(5, back[3] - back[1] - 1)
        px0 = rng.randint(back[0] + 1, max(back[0] + 1, back[2] - pw - 1))
        py0 = back[1] + 1
        g.fill(px0 - 1, py0 - 1, px0 + pw, py0 + ph, "pave")
        g.fill(px0, py0, px0 + pw - 1, py0 + ph - 1, "pool")
        g.fill(px0, py0, px0 + pw - 1, py0, "pool_sh")
        for k in ("sun_lounger", "sun_lounger", "bbq", "garden_lamp", "garden_lamp"):
            g.scatter(k, px0 - 1, py0 - 1, px0 + pw, py0 + ph, 1)
        if g.t[py0 + ph][px0] == "pave" or True:
            g.f_("hot_tub", px0 + pw + 2, py0) if g.free(px0 + pw + 2, py0) else None
    if spec.get("garden"):
        g.scatter("garden_bed", 2, 2, W - 3, hrect[1] - 1, 3)
        g.scatter("bonsai", 2, 2, W - 3, hrect[1] - 1, 2)
    lights(g, 3)
    for z, lv in levels.items():
        if z < 0 or z == stories + 1: continue
        n = sum(1 for k, _, _ in lv.f if F[k]["light"] >= 4)
        if n < 1 and z > 0:
            for pos in [(hrect[0] + 1, hrect[1] + 1), (hrect[2] - 1, hrect[1] + 1)]:
                if lv.f_("floor_lamp", *pos): break
    # cars and loot
    return [levels[z] for z in zs], dict(stories=stories, zs=zs, loot="rich" if rich else "mid",
                                         loot_rects=[(hrect[0], hrect[1], hrect[2], hrect[3])],
                                         roofs=None, rich=rich, hrect=hrect, garect=garect)

# ------------------------------------------------------------------ specs
POOR_FAM = [
    ("tea", "tea-seller's lean-to", "tea"), ("noodle", "noodle-cart family hut", "noodle"), ("scrap", "scrap-picker's den", "scrap"),
    ("android", "android-repair shed", "android"), ("mil", "deserter's bunk shack", "mil"), ("gambler", "gambler's hut", "gambler"),
    ("izba", "izba hovel", "izba"), ("courtyard", "courtyard shanty", "courtyard"), ("neon", "neon squat", "neon"), ("water", "water-seller's yard", "water"),
]
POOR = []
for fi, (th, nm, _) in enumerate(POOR_FAM):
    for v in range(5):
        duo = v < 2
        spec = dict(kind="poor", theme=th, duo=duo, name=f"slum {nm}" + (" pair" if duo else ""), id=f"trl_slum_{fi * 5 + v + 1:02d}")
        if duo: spec["theme2"] = POOR_FAM[(fi + 3) % 10][0]
        POOR.append(spec)

MID_FAM = [("tea", "tea-house family home", 4), ("izba", "dacha-style house", 4), ("mil", "officer's family house", 3), ("android", "android household", 4),
           ("neon", "neon-flat townhouse", 3), ("courtyard", "courtyard house", 4), ("noodle", "shopkeeper's house", 4), ("gambler", "gamer's house", 3),
           ("scrap", "tinkerer's workshop house", 3), ("tea", "shrine-garden house", 3)]
MID = []
n = 0
for fi, (th, nm, cnt) in enumerate(MID_FAM):
    for v in range(cnt):
        n += 1
        spec = dict(kind="mid", rich=False, theme=th, tiles=1, stories=2 if (n % 3 != 0) else 1, garage=(n % 4 != 3),
                    name=f"{nm}", id=f"trl_home_{n:02d}", fence=(n % 5 != 0), garden=(fi in (1, 9)), pool=False)
        spec["name"] = f"{nm} {v + 1}"
        MID.append(spec)
assert len(MID) == 35, len(MID)

RICH_FAM = [("neon", "executive villa", 2), ("courtyard", "oyabun's estate", 2), ("android", "android magnate's residence", 2), ("izba", "oligarch's manor", 2),
            ("tea", "tea magnate's pavilion", 1), ("mil", "arms dealer's compound", 2), ("gambler", "netrunner's den-house", 2), ("neon", "idol star's penthouse-house", 2)]
RICH = []
n = 0
for fi, (th, nm, cnt) in enumerate(RICH_FAM):
    for v in range(cnt):
        n += 1
        two = n % 2 == 0 or n in (1, 3)
        btypes = [["gym", "theatre", "server"], ["cellar", "gym", "theatre"], ["lab", "server", "gym"], ["armoury", "gym", "cellar"]][n % 4]
        spec = dict(kind="rich", rich=True, theme=th, tiles=2 if two else 1, stories=2 if n % 5 != 0 else 1, garage=True,
                    name=f"{nm} {v + 1}", id=f"trl_estate_{n:02d}", pool=(n % 3 != 2), garden=(n % 2 == 0), basement=(n % 2 == 1) or n in (4, 8),
                    btypes=btypes, fence=True, yard="grass")
        if spec["tiles"] == 1: spec["pool"] = spec["pool"] and n % 4 != 1
        RICH.append(spec)
assert len(RICH) == 15, len(RICH)
ALL = []
for S in POOR + MID + RICH:
    ALL.append(S)
assert len(POOR) == 50

# ------------------------------------------------------------------ emit
def make(S):
    seed = int(hashlib.md5(S["id"].encode()).hexdigest()[:8], 16)
    rng = random.Random(seed)
    if S["kind"] == "poor":
        levels, info = poor_house(S, rng)
        S["zs"] = [0, 1]
        # roof level on top of shacks
        r = Cv(1, base="air"); r.fill(0, 0, 23, 23, "air")
        for sh in info["roofs"]: r.fill(sh[1][0], sh[1][1], sh[1][2], sh[1][3], "roof")
        levels.append(r)
        info["stories"] = 1; info["zs"] = [0, 1]
        return levels, info
    return middle_or_rich(S, rng)

def tile_json(S, levels, info, d_loot):
    mgs, oms, cb = [], [], []
    zs = info["zs"]
    nx = S.get("tiles", 1)
    sig = hashlib.md5()
    for z, lv in zip(zs, levels):
        keys = sorted(set(k for row in lv.t for k in row))
        assert len(keys) <= len(mr.POOL), (S["id"], z, len(keys))
        ch = {k: mr.POOL[i] for i, k in enumerate(keys)}
        for t in range(nx):
            oid = f"{S['id']}_t{t}_z{z}" if z >= 0 else f"{S['id']}_t{t}_zm{-z}"
            rows = ["".join(ch[k] for k in row[24 * t:24 * t + 24]) for row in lv.t]
            sig.update("".join(rows).encode())
            fur = [{"furn": F[k]["id"], "x": x - 24 * t, "y": y} for k, x, y in lv.f if 24 * t <= x < 24 * t + 24]
            obj = {"fill_ter": "t_open_air" if z > 0 else "t_rock" if z < 0 else "t_pavement", "rows": rows,
                   "terrain": {ch[k]: T[k]["id"] for k in keys}, "place_furniture": fur}
            if z == 0:
                its = []
                for (x0, y0, x1, y1) in info["loot_rects"]:
                    a, b = max(x0, 24 * t) - 24 * t, min(x1, 24 * t + 23) - 24 * t
                    if a <= b:
                        its.append({"item": f"trl_loot_house_{info['loot']}" if info["loot"] in ("mid", "rich") else f"trl_loot_{info['loot']}",
                                    "x": [a, b], "y": [y0, y1], "chance": 40, "repeat": 3})
                obj["place_items"] = its
                veh = [{"vehicle": random.Random(x * 31 + y).choice(("car", "car", "suv", "car_sports", "electric_car", "pickup") if info.get("rich") else ("car", "car_mini", "motorcycle", "scooter", "car")),
                        "x": x - 24 * t, "y": y, "chance": 55, "status": 60, "rotation": r}
                       for x, y, r in lv.cars if 24 * t <= x < 24 * t + 24]
                if veh: obj["place_vehicles"] = veh
            elif 0 < z <= info["stories"] - 1 or z < 0:
                x0, y0, x1, y1 = info["loot_rects"][0]
                a, b = max(x0, 24 * t) - 24 * t, min(x1, 24 * t + 23) - 24 * t
                if a <= b:
                    obj["place_items"] = [{"item": f"trl_loot_house_{info['loot']}" if info["loot"] in ("mid", "rich") else f"trl_loot_{info['loot']}",
                                           "x": [a, b], "y": [y0, y1], "chance": 30, "repeat": 3}]
            mgs.append({"type": "mapgen", "om_terrain": [oid], "object": obj})
            roof = z > 0 and z == info["stories"]
            top = z == zs[-1]
            oms.append({"type": "overmap_terrain", "id": oid, "name": S["name"] + (" roof" if top and z > 0 else " basement" if z < 0 else ""),
                        "sym": {"poor": "s", "mid": "h", "rich": "H"}[S["kind"]], "color": {"poor": "brown", "mid": "light_green", "rich": "yellow"}[S["kind"]],
                        "see_cost": "none" if top and z > 0 else "full_high",
                        "vision_levels": "roof_or_air" if top and z > 0 else "large_city_building",
                        "flags": ["SIDEWALK"] if z == 0 else []})
            cb.append({"point": [t, 0, z], "overmap": oid + "_north"})
    return mgs, oms, {"type": "city_building", "id": S["id"], "locations": ["land"], "overmaps": cb, "city_sizes": [1, -1]}, sig.hexdigest()

def emit():
    gp.assign_chars()
    mg, om, cbs, sigs = [], [], [], {}
    for S in ALL:
        levels, info = make(S)
        # sanity: ground floor lights
        g0 = levels[info["zs"].index(0)] if "zs" in info else levels[0]
        assert sum(1 for k, _, _ in g0.f if F[k]["light"] >= 4) >= 2, S["id"]
        a, b, c, sg = tile_json(S, levels, info, None)
        assert sg not in sigs, (S["id"], sigs.get(sg))
        sigs[sg] = S["id"]
        mg += a; om += b; cbs.append(c)
        S["_lv"] = levels; S["_info"] = info
    d = os.path.join(MOD, "houses"); os.makedirs(d, exist_ok=True)
    fj = [f for f in gp.furniture_json() if f["id"] in {F[k]["id"] for k in HOUSE_F}]
    json.dump(fj, open(os.path.join(d, "furniture.json"), "w"), indent=1)
    loot = {
      "mid": ["can_beans", "water_clean", "bandages", "jacket_light", "tshirt", "flashlight", "candle", "matches", "lighter", "rag", "duct_tape", "wrench", "small_lcd_screen", "cable"],
      "rich": ["circuit", "processor", "RAM", "amplifier", "small_lcd_screen", "light_battery_cell", "cable", "e_scrap", "flashlight", "bandages", "water_clean", "jacket_light"],
    }
    json.dump([{"type": "item_group", "id": f"trl_loot_house_{k}", "subtype": "distribution", "entries": [{"item": i} for i in v]}
               for k, v in loot.items()], open(os.path.join(d, "loot.json"), "w"), indent=1)
    json.dump(om + cbs, open(os.path.join(d, "buildings.json"), "w"), indent=1)
    json.dump(mg, open(os.path.join(d, "mapgen.json"), "w"), indent=1)
    # region overlay: houses
    ro_path = os.path.join(MOD, "region_overlay.json")
    ro = json.load(open(ro_path))
    stock = json.load(open(STOCK))
    houses = {}
    for o in stock:
        if o.get("type") == "region_settings" and "city" in o and "houses" in o["city"]:
            houses = {k: v for k, v in o["city"]["houses"].items() if not k.startswith("//")}
    S_total = sum(houses.values())
    new_total = 5 * S_total
    ov = {k: max(1, v // 8) for k, v in houses.items()}
    shares = (("poor", 0.40, len(POOR)), ("mid", 0.50, len(MID)), ("rich", 0.10, len(RICH)))
    wmap = {k: max(1, int(new_total * sh / n)) for k, sh, n in shares}
    for S in ALL: ov[S["id"]] = wmap[S["kind"]]
    ro[0]["city"]["houses"] = ov
    json.dump(ro, open(ro_path, "w"), indent=1)
    print(len(ALL), "houses,", len(mg), "mapgen levels; stock house weight", S_total)

if __name__ == "__main__":
    emit()
    pv = os.environ.get("PREVIEW")
    if pv:
        for S in ALL:
            if pv in S["id"]:
                info = S["_info"]
                for z, lv in zip(info["zs"], S["_lv"]):
                    print(f"--- {S['id']} {S['name']} z{z}")
                    inv = {(x, y): F[k]["sym"] for k, x, y in lv.f}
                    for y in range(24):
                        print("".join(inv.get((x, y), (T[lv.t[y][x]].get("sym") or ("." if lv.t[y][x] in FLOORS else "?")) if lv.t[y][x] != "air" else " ") for x in range(lv.w)))
