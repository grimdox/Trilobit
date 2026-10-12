#!/usr/bin/env python3
"""Generate 15 Trilobit mid-sized towers (multi-level, multi-cell) into <mod>/towers/.
usage: gen_towers.py <mod dir>   (env PREVIEW=mt03 [Z=1] prints ASCII of a level)"""
import json, os, sys, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gt_recipes import *
MOD = sys.argv[1]

# ============================================================================ registry
BUILDINGS = []
def bld(id, name, nx, ny, floors, sym, color, wall, weight, min_city=1, flip=False, transpose=False, kind="mixed"):
    def deco(fn):
        BUILDINGS.append(dict(id=f"trl_{id}", name=name, nx=nx, ny=ny, floors=floors, sym=sym, color=color, wall=wall,
                              weight=weight, min_city=min_city, flip=flip, transpose=transpose, fn=fn, kind=kind))
        return fn
    return deco

def balcony(L, x0, x1, side="s", door=True, plants=True):
    """Balcony strip on the ring outside an exterior wall; windows/door behind it."""
    for x in range(x0, x1 + 1):
        ry, wy = (L.H - 1, L.H - 2) if side == "s" else (0, 1)
        L.put("balcony", x, ry)
        if L.get(x, wy) in WALLK and L.get(x, wy + (-1 if side == "s" else 1)) in FLOORS:
            L.put("door_c" if (door and x == (x0 + x1) // 2) else "window", x, wy)
        if plants and x != (x0 + x1) // 2:
            L.f_(L.rng.choice(["fern", "laundry", "planter", "wind_chime"]), x, ry)

def lobby_decor(L, x0, y0, x1, y1, n=6):
    for _ in range(n):
        L.scatter(["vase_tall", "fern", "bonsai", "vase_white"], x0, y0, x1, y1, 1)

def roof_level(L, core, door=("s", 2), void=None, extra=()):
    """Standard roof: parapet rail, stair hut, props, lamps."""
    for y in range(L.H):
        for x in range(L.W):
            edge = x in (0, L.W - 1) or y in (0, L.H - 1)
            w = x in (1, L.W - 2) or y in (1, L.H - 2)
            L.t[y][x] = "air" if edge else "rail" if w else "roof"
    if void:
        vx0, vy0, vx1, vy1 = void
        L.fill(vx0, vy0, vx1, vy1, "air")
        for x in range(vx0 - 1, vx1 + 2):
            L.put("rail", x, vy0 - 1); L.put("rail", x, vy1 + 1)
        for y in range(vy0 - 1, vy1 + 2):
            L.put("rail", vx0 - 1, y); L.put("rail", vx1 + 1, y)
    L.rooms.append((2, 2, L.W - 3, L.H - 3))
    if core: L.core(core[0], core[1], door)
    for k in extra: L.scatter(k, 3, 3, L.W - 4, L.H - 4, 1)
    L.scatter("ac_unit", 3, 3, L.W - 4, L.H - 4, 2 + (L.W * L.H) // 1500)
    L.scatter("water_tank", 3, 3, L.W - 4, L.H - 4, 1)
    L.clear_doors()
    for (x, y) in ((3, 3), (L.W - 4, 3), (3, L.H - 4), (L.W - 4, L.H - 4), (L.W // 2, L.H // 2)):
        if L.t[y][x] == "roof" and (x, y) not in L.occ:
            L.f.append(("street_lamp", x, y)); L.occ.add((x, y))

# ============================================================================ skeleton S1: 1x1, cross hall
def s1(L, p):
    z = L.z
    L.shell(p["wall"], "marble" if z == 0 else p["hall"])
    if z == 0:
        ka, kb = p["shops"]
        sa = shop(L, 1, 12, 10, 22, "s", ka, p["wall"], off=5)
        sb = shop(L, 13, 12, 22, 22, "s", kb, p["wall"], off=18)
        L.door("door_c", 10, 17); L.door("door_c", 13, 17)
        L.hline(11, 12, 22, "door_c")
        L.fill(11, 13, 12, 21, p.get("lobby_floor", "checker"))
        storeroom(L, 1, 1, 9, 12, "s", off=5, wall=p["wall"]); storeroom(L, 14, 1, 22, 12, "s", off=18, wall=p["wall"])
        L.fill(10, 6, 13, 11, p.get("lobby_floor", "checker"))
        for y in (7, 8, 9): L.f_("locker", 10, y)
        L.f_("bench", 13, 8); L.f_("bench", 13, 9); lobby_decor(L, 10, 6, 13, 21, 4)
        L.f_("lightbox", 13, 11); L.f_("neon_cyan", 11, 21)
        L.windows(p.get("wp", 4))
        frontage(L, 1, 10, 22, 5); frontage(L, 13, 22, 22, 18)
        L.sign(p["signs"][0], 4, 23); L.sign(p["signs"][1], 18, 23); L.sign("neon_cyan", 11, 23)
        L.core(9, 2, ("s", 2))
    else:
        styles = p["styles"][(z - 1) % len(p["styles"])]
        flat(L, 1, 1, 9, 12, "e", styles[0], p["wall"], off=8)
        flat(L, 14, 1, 22, 12, "w", styles[1], p["wall"], off=8)
        flat(L, 1, 12, 9, 22, "e", styles[2], p["wall"], off=17)
        flat(L, 14, 12, 22, 22, "w", styles[3], p["wall"], off=17)
        lobby_decor(L, 10, 6, 13, 21, 3); L.f_("status_panel", 10, 20) if False else None
        L.windows(p.get("wp", 4))
        L.put("window", 11, 22); L.put("window", 12, 22)
        balcony(L, 3, 7); balcony(L, 16, 20)
        L.core(9, 2, ("s", 2))

# ============================================================================ skeleton S2: 2x1, mall corridor
def s2(L, p):
    z = L.z; xs = p.get("xs", [1, 10, 19, 28, 37, 46]); mid = (xs[2] + xs[3]) // 2
    L.shell(p["wall"], "marble" if z == 0 else p["hall"])
    L.fill(2, 11, L.W - 3, 13, p.get("mall", "checker") if z == 0 else p["hall"])
    slots_n = [0, 1, 3, 4]; slots_s = [0, 1, 3, 4]
    if z == 0:
        for i, s in enumerate(slots_n):
            shop(L, xs[s], 1, xs[s + 1], 10, "s", p["north"][i], p["wall"], off=(xs[s] + xs[s + 1]) // 2)
        for i, s in enumerate(slots_s):
            cx = (xs[s] + xs[s + 1]) // 2
            shop(L, xs[s], 14, xs[s + 1], 22, "s", p["south"][i], p["wall"], off=cx)
            L.door("door_c", cx, 14)
        L.hline(mid - 1, mid, L.H - 2, "door_c")
        L.door("door_c", 1, 12); L.door("door_c", L.W - 2, 12)
        L.fill(xs[2] + 1, 14, xs[3] - 1, 21, p.get("lobby_floor", "marble"))
        L.fill(xs[2] + 1, 6, xs[3] - 1, 10, p.get("lobby_floor", "marble"))
        lobby_decor(L, xs[2] + 1, 6, xs[3] - 1, 21, 6)
        for y in (15, 17, 19): L.f_("locker", xs[2] + 1, y)
        L.f_("bench", xs[3] - 1, 16); L.f_("bench", xs[3] - 1, 17); L.f_("lightbox", xs[3] - 1, 20)
        L.windows(p.get("wp", 5))
        for i, s in enumerate(slots_s): frontage(L, xs[s], xs[s + 1], L.H - 2, (xs[s] + xs[s + 1]) // 2)
        for i, s in enumerate(slots_s): L.sign(p["signs"][i % len(p["signs"])], (xs[s] + xs[s + 1]) // 2 - 2, L.H - 1)
        L.sign("neon_cyan", mid - 1, L.H - 1)
    else:
        styles = p["styles"][(z - 1) % len(p["styles"])]
        for i, s in enumerate(slots_n):
            flat(L, xs[s], 1, xs[s + 1], 10, "s", styles[i % len(styles)], p["wall"], off=(xs[s] + xs[s + 1]) // 2)
        for i, s in enumerate(slots_s):
            flat(L, xs[s], 14, xs[s + 1], 22, "n", styles[(i + 2) % len(styles)], p["wall"], off=(xs[s] + xs[s + 1]) // 2)
        L.fill(xs[2] + 1, 14, xs[3] - 1, 21, p["hall"]); L.fill(xs[2] + 1, 6, xs[3] - 1, 10, p["hall"])
        lobby_decor(L, xs[2] + 1, 6, xs[3] - 1, 21, 6)
        for y in (16, 18): L.f_("bench", xs[2] + 1, y); L.f_("table_low", xs[2] + 2, y)
        L.f_("aquarium", xs[3] - 1, 17) if p.get("aquarium") else None
        L.windows(p.get("wp", 5))
        L.put("window", mid - 1, L.H - 2); L.put("window", mid, L.H - 2)
        for s in slots_s:
            cx = (xs[s] + xs[s + 1]) // 2
            balcony(L, cx - 2, cx + 2)
    L.core(xs[2] + 2, 2, ("s", 2))

# ============================================================================ registered mixed-use buildings
S1_COMMON = dict(hall="carpet_grey", lobby_floor="checker")

@bld("mt01", "noodle row flats", 1, 1, 4, "m", "light_red", "wall_concrete", 700)
def mt01(L):
    s1(L, dict(S1_COMMON, wall="wall_concrete", shops=("noodle", "conv"), signs=("neon_red", "neon_cyan"),
               styles=[("micro", "micro", "micro", "tatami"), ("micro", "worker", "micro", "micro"), ("tatami", "micro", "micro", "micro")]))

@bld("mt02", "clinic and tea house stack", 1, 1, 5, "m", "light_green", "wall_corp", 700, flip=True)
def mt02(L):
    s1(L, dict(S1_COMMON, wall="wall_corp", shops=("pharm", "tea"), signs=("neon_green", "neon_amber"), lobby_floor="marble",
               styles=[("tatami", "tatami", "micro", "micro"), ("micro", "tatami", "tatami", "micro")], wp=3))

@bld("mt08", "karaoke and dorm tower", 1, 1, 4, "m", "pink", "wall_lacquer", 700)
def mt08(L):
    s1(L, dict(S1_COMMON, wall="wall_lacquer", shops=("karaoke", "salon"), signs=("neon_pink", "neon_violet"), hall="carpet_red",
               styles=[("dorm", "dorm", "capsule", "capsule"), ("dorm", "capsule", "dorm", "dorm")], wp=5))

@bld("mt03", "bazaar stack", 2, 1, 4, "m", "yellow", "wall_rust", 700)
def mt03(L):
    s2(L, dict(wall="wall_rust", hall="carpet_grey", north=["elec", "repair", "pawn", "elec"], south=["elec", "arcade", "repair", "pawn"],
               signs=("neon_cyan", "neon_amber", "neon_red", "neon_green"), styles=[("worker", "micro", "worker", "micro"), ("micro", "worker", "micro", "micro")]))

@bld("mt04", "izakaya and capsule hotel", 2, 1, 4, "m", "yellow", "wall_slat", 700, flip=True)
def mt04(L):
    s2(L, dict(wall="wall_slat", hall="carpet_red", xs=[1, 11, 19, 28, 36, 46], north=["izakaya", "noodle", "izakaya", "karaoke"], south=["arcade", "izakaya", "tea", "conv"],
               signs=("neon_amber", "neon_red", "neon_violet", "neon_pink"), styles=[("capsule", "capsule", "capsule", "capsule")], mall="neon_amber"))

@bld("mt07", "boutique heights", 2, 1, 5, "m", "pink", "wall_corp", 700)
def mt07(L):
    s2(L, dict(wall="wall_corp", hall="carpet_teal", north=["fashion", "salon", "art", "fashion"], south=["fashion", "salon", "tea", "art"],
               signs=("neon_pink", "neon_violet", "neon_cyan", "neon_pink"), styles=[("lux", "lux", "lux", "family"), ("lux", "family", "lux", "lux")], aquarium=True, mall="marble"))

@bld("mt05", "bookbinders and flats", 1, 2, 4, "m", "light_cyan", "wall_brick", 700, transpose=True)
def mt05(L):
    s2(L, dict(wall="wall_brick", hall="carpet_grey", xs=[1, 12, 19, 28, 35, 46], north=["books", "art", "books", "tea"], south=["books", "art", "books", "salon"],
               signs=("neon_amber", "neon_green", "neon_amber", "neon_violet"), styles=[("tatami", "micro", "tatami", "tatami"), ("micro", "tatami", "micro", "tatami")], mall="floor_wood"))

@bld("mt10", "back-alley clinic flats", 1, 2, 5, "m", "red", "wall_rust", 700, transpose=True, flip=True)
def mt10(L):
    s2(L, dict(wall="wall_rust", hall="carpet_grey", xs=[1, 10, 20, 29, 38, 46], north=["bodyshop", "pharm", "pawn", "repair"], south=["bodyshop", "market", "noodle", "pharm"],
               signs=("neon_red", "neon_green", "neon_red", "neon_cyan"), styles=[("worker", "worker", "micro", "worker"), ("worker", "micro", "worker", "worker")], mall="slab"))

# --- atrium market (2x2) -----------------------------------------------------
def atrium_rooms(xs_w, ys_w):
    return None

@bld("mt06", "atrium market and courtyard flats", 2, 2, 4, "m", "light_green", "wall_mural", 700)
def mt06(L):
    z = L.z; wall = "wall_mural"
    L.shell(wall, "marble" if z == 0 else "carpet_grey")
    # walkway strips (4 wide) around a void/courtyard whose rail ring is x15..32, y15..32
    strips = ((2, 11, 45, 14), (2, 33, 45, 36), (11, 15, 14, 32), (33, 15, 36, 32))
    for (a, b_, c, d) in strips: L.fill(a, b_, c, d, "pave" if z == 0 else "carpet_grey")
    if z == 0:
        L.fill(15, 15, 32, 32, "grass")
        L.fill(19, 19, 28, 28, "water"); L.fill(23, 19, 24, 28, "floor_wood"); L.fill(19, 23, 28, 24, "floor_wood")
        for (x, y) in ((17, 17), (30, 17), (17, 30), (30, 30), (22, 16), (25, 31), (16, 22), (31, 25)): L.f_("bonsai", x, y)
        for (x, y) in ((18, 18), (29, 18), (18, 29), (29, 29)): L.f_("lantern_stone", x, y)
        L.f_("holo_ad", 23, 16); L.f_("holo_ad", 24, 31)
    else:
        L.fill(16, 16, 31, 31, "air")
        for x in range(15, 33): L.put("rail", x, 15); L.put("rail", x, 32)
        for y in range(15, 33): L.put("rail", 15, y); L.put("rail", 32, y)
    xs = [1, 10, 19, 28, 37, 46]
    styles = ["micro", "tatami", "worker", "micro", "tatami"]
    kinds = {"n": ["art", "tea", None, "market", "noodle"], "s": ["repair", "elec", None, "izakaya", "books"],
             "w": ["pawn", "salon"], "e": ["conv", "fashion"]}
    def room(x0, y0, x1, y1, side, key, i):
        if z == 0:
            k = kinds[key][i]
            if k: shop(L, x0, y0, x1, y1, side, k, wall)
        else:
            flat(L, x0, y0, x1, y1, side, styles[(i + z + len(key) + ord(key)) % 5], wall)
    for i in range(5):
        if i != 2:
            room(xs[i], 1, xs[i + 1], 10, "s", "n", i)
            room(xs[i], 37, xs[i + 1], 46, "n", "s", i)
    wy = [15, 23, 32]
    for i in range(2):
        room(1, wy[i], 10, wy[i + 1], "e", "w", i)
        room(37, wy[i], 46, wy[i + 1], "w", "e", i)
    fl = "marble" if z == 0 else "carpet_grey"
    L.fill(20, 6, 27, 10, fl); L.fill(20, 37, 27, 45, fl)
    lobby_decor(L, 20, 6, 27, 10, 4); lobby_decor(L, 20, 37, 27, 45, 5)
    if z == 0:
        L.hline(23, 24, 46, "door_c")
        L.f_("neon_cyan", 21, 40); L.f_("bench", 20, 42); L.f_("bench", 27, 42)
    L.windows(5)
    if z == 0:
        frontage(L, 1, 10, 46, 5) if False else None
    else:
        L.put("window", 23, 46); L.put("window", 24, 46)
        for x0 in (3, 12, 30, 39): balcony(L, x0 + 1, x0 + 5, side="s") if False else None
    L.core(21, 2, ("s", 2))
    L.roof_void = (16, 16, 31, 31)

@bld("mt09", "supermarket court", 2, 2, 3, "m", "light_green", "wall_corp", 700)
def mt09(L):
    z = L.z; wall = "wall_corp"
    L.shell(wall, "marble" if z == 0 else "carpet_teal")
    xs = [1, 10, 19, 28, 37, 46]
    if z == 0:
        # north half: eight small shops along a mall corridor y11..13
        L.fill(2, 11, 45, 13, "checker")
        nk = ["pharm", "salon", None, "books", "fashion", "repair", None, "conv"]
        k = 0
        for row_y0, row_y1, side in ((1, 10, "s"), (14, 23, "n")):
            for s in (0, 1, 3, 4):
                kind = nk[k]; k += 1
                x0, x1 = xs[s], xs[s + 1]
                if kind: shop(L, x0, row_y0, x1, row_y1, side, kind, wall, off=(x0 + x1) // 2)
                else: storeroom(L, x0, row_y0, x1, row_y1, side, off=(x0 + x1) // 2, wall=wall)
        # central lobby column x20..27 y6..23, core at top
        L.fill(20, 6, 27, 10, "marble"); L.fill(20, 14, 27, 23, "marble")
        # supermarket (west) and food hall (east) with a gateway between
        shop(L, 1, 24, 19, 46, "s", "super", wall, off=10)
        shop(L, 28, 24, 46, 46, "s", "market", wall, off=36)
        L.door("door_c", 19, 33); L.door("door_c", 28, 33)
        L.fill(20, 24, 27, 45, "marble"); L.hline(23, 24, 46, "door_c")
        lobby_decor(L, 20, 14, 27, 45, 8)
        L.f_("bench", 20, 30); L.f_("bench", 27, 30); L.f_("lightbox", 20, 40); L.f_("lightbox", 27, 40)
        L.door("door_c", 1, 12); L.door("door_c", 46, 12)
        L.windows(5)
        frontage(L, 1, 19, 46, 10); frontage(L, 28, 46, 46, 36)
        L.sign("neon_green", 8, 47) if False else None
        L.sign("neon_green", 10, 47) if False else None
        L.sign("neon_green", 10, L.H - 1); L.sign("neon_amber", 36, L.H - 1); L.sign("neon_cyan", 23, L.H - 1)
    else:
        styles = [("family", "micro", "family", "worker"), ("lux", "family", "micro", "family")][z % 2]
        L.fill(2, 11, 45, 13, "carpet_teal"); L.fill(2, 33, 45, 35, "carpet_teal")
        L.fill(20, 6, 27, 45, "carpet_teal")
        i = 0
        for (y0, y1, side) in ((1, 10, "s"), (14, 23, "n"), (24, 33, "s"), (35, 46, "n")):
            for s in (0, 1, 3, 4):
                x0, x1 = xs[s], xs[s + 1]
                flat(L, x0, y0, x1, y1, side, styles[(i + s) % 4], wall, off=(x0 + x1) // 2); i += 1
        lobby_decor(L, 20, 14, 27, 45, 8)
        for y in (26, 30): L.f_("bench", 20, y); L.f_("sofa", 27, y)
        L.windows(5)
        L.put("window", 23, 46); L.put("window", 24, 46)
        for s in (0, 1, 3, 4): cx = (xs[s] + xs[s + 1]) // 2; balcony(L, cx - 2, cx + 2)
    L.core(21, 2, ("s", 2))

# ============================================================================ specials
import gt_special
gt_special.register(bld, globals())
for _b in BUILDINGS:
    if _b["id"] in ROOF_FNS: _b["roof"] = ROOF_FNS[_b["id"]]

# ============================================================================ build levels
def mirror_x(L):
    W = L.W
    L.t = [row[::-1] for row in L.t]
    L.f = [(k, W - 1 - x, y) for k, x, y in L.f]
    L.items = [(g, W - 1 - x1, y0, W - 1 - x0, y1, c, r) for g, x0, y0, x1, y1, c, r in L.items]
    L.stairs_tiles = [(W - 1 - x, y) for x, y in L.stairs_tiles]
    return L
def transpose(L):
    N = Lv(L.ny, L.nx, L.z, L.st, 0)
    N.t = [[L.t[x][y] for x in range(L.H)] for y in range(L.W)]
    N.f = [(k, y, x) for k, x, y in L.f]
    N.items = [(g, y0, x0, y1, x1, c, r) for g, x0, y0, x1, y1, c, r in L.items]
    N.stairs_tiles = [(y, x) for x, y in L.stairs_tiles]
    N.rooms = []; N.occ = set((y, x) for x, y in L.occ)
    return N

def build_levels(b):
    out = []
    nx, ny = (b["ny"], b["nx"]) if b["transpose"] else (b["nx"], b["ny"])
    for z in range(0, b["floors"] + 1):
        L = Lv(nx, ny, z, b["floors"], seed=f"{b['id']}-{z}")
        if z < b["floors"]:
            b["fn"](L)
            if getattr(L, "roof_void", None): b["roof_void"] = L.roof_void
            if z == 0: b["core"] = L.core_box
            L.clear_doors()
            if L.stairs_tiles: L.fix_pockets(L.stairs_tiles[0])
            L.exterior_lights()
            L.autolight()
        else:
            if b.get("roof"): b["roof"](L)
            else: roof_level(L, b["core"], void=b.get("roof_void"), extra=b.get("roof_extra", ()))
        # sanity
        if L.stairs_tiles:
            bad = L.unreachable(L.stairs_tiles[0])
            if bad: b.setdefault("warn", []).append((z, len(bad), bad[:6]))
        if b["flip"]: mirror_x(L)
        if b["transpose"]: L = transpose(L)
        out.append(L)
    return out

# ============================================================================ output
CHARPOOL = [c for c in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@#$%^&*()-=+[]{}|;:<>?/~`"]
def cell_object(L, cx, cy, z):
    x0, y0 = cx * 24, cy * 24
    keys = sorted({L.t[y0 + y][x0 + x] for y in range(24) for x in range(24)})
    cm = {k: CHARPOOL[i] for i, k in enumerate(keys)}
    rows = ["".join(cm[L.t[y0 + y][x0 + x]] for x in range(24)) for y in range(24)]
    obj = {"fill_ter": "t_open_air" if z > 0 else "t_grass", "rows": rows, "terrain": {cm[k]: T[k]["id"] for k in keys}}
    fur = [{"furn": F[k]["id"], "x": x - x0, "y": y - y0} for k, x, y in L.f if x0 <= x < x0 + 24 and y0 <= y < y0 + 24]
    if fur: obj["place_furniture"] = fur
    it = []
    for g, ax, ay, bx, by, c, r in L.items:
        ix0, ix1 = max(ax, x0), min(bx, x0 + 23); iy0, iy1 = max(ay, y0), min(by, y0 + 23)
        if ix0 > ix1 or iy0 > iy1: continue
        # scale chance by area share so big rooms spanning cells do not multiply loot
        it.append({"item": g, "x": [ix0 - x0, ix1 - x0], "y": [iy0 - y0, iy1 - y0], "chance": c, "repeat": r})
    if it: obj["place_items"] = it
    return obj

def emit(b, levels, ter_out, map_out, cb_out):
    nx, ny, st = b["nx"], b["ny"], b["floors"]
    seen = {}; cb = []
    for z, L in enumerate(levels):
        for cy in range(ny):
            for cx in range(nx):
                obj = cell_object(L, cx, cy, z)
                key = json.dumps(obj, sort_keys=True)
                if key not in seen:
                    oid = f"{b['id']}_{cx}{cy}z{z+1}"
                    seen[key] = oid
                    map_out.append({"type": "mapgen", "om_terrain": [oid], "object": obj})
                    roof = (z == st)
                    ter_out.append({"type": "overmap_terrain", "id": oid, "name": b["name"] + (" roof" if roof else ""),
                                    "sym": b["sym"], "color": b["color"], "see_cost": "none" if roof else "full_high",
                                    "vision_levels": "roof_or_air" if roof else "large_city_building",
                                    "flags": ["SIDEWALK"] if z == 0 else []})
                cb.append({"point": [cx, cy, z], "overmap": seen[key] + "_north"})
    cb_out.append({"type": "city_building", "id": b["id"], "locations": ["land"], "overmaps": cb, "city_sizes": [b["min_city"], -1]})

# ---------------------------------------------------------------- loot groups
def prefix(pfx, n=10): return sorted(i for i in ITEMS if i.startswith(pfx))[:n]
POOLS = {
 "apt": ["noodles_fast", "rice_cooked", "cola", "tea_green", "energy_drink", "candy", "water_clean", "tshirt", "jeans", "hoodie", "umbrella",
         "soap", "towel", "pillow", "blanket", "lighter", "candle", "flashlight", "aspirin", "bandages", "vitamins", "sake_filtered", "beer"],
 "worker": ["scrap", "pipe", "wire", "duct_tape", "rice_cooked", "water_clean", "beer", "tshirt", "jacket_light", "lighter", "candle", "flashlight", "noodles_fast", "wrench"],
 "dorm": ["tshirt", "jeans", "towel", "soap", "pillow", "blanket", "energy_drink", "noodles_fast", "water_clean", "umbrella"],
 "conv": ["noodles_fast", "cola", "energy_drink", "candy", "water_clean", "tea_green", "sushi_fishroll", "rice_cooked", "beer", "cigar", "lighter", "umbrella", "bandages", "aspirin"],
 "pharm": ["aspirin", "bandages", "vitamins", "water_clean", "disinfectant", "gauze", "medical_tape", "saline", "ibuprofen", "adhesive"],
 "books": prefix("textbook_", 8) + prefix("mag_", 8) + prefix("novel_", 6) + ["paper", "pen"],
 "fashion": ["kimono", "jeans", "tshirt", "hoodie", "dress_shirt", "jacket_light", "umbrella", "scarf", "gloves_light", "sunglasses", "hat_ball", "boots"],
 "pawn": ["cash_card", "camera", "laptop", "smart_phone", "radio", "flashlight", "lighter", "cigar", "kimono", "umbrella", "light_battery_cell", "e_scrap", "processor"],
 "implant": ["circuit", "processor", "e_scrap", "motor_micro", "plastic_chunk", "steel_chunk", "power_supply", "small_lcd_screen", "wire", "cable"],
 "police": ["flashlight", "radio", "cash_card", "bandages", "aspirin", "energy_drink", "coffee_raw", "pen", "paper", "tazer", "baton", "smart_phone"],
 "armory": ["tazer", "baton", "baton-extended", "kevlar", "ballistic_vest_esapi", "helmet_riot", "9mm"],
 "evidence": ["cash_card", "smart_phone", "laptop", "e_scrap", "cigar", "lighter", "tshirt", "jacket_light", "camera"],
 "power": ["wire", "cable", "light_battery_cell", "medium_battery_cell", "power_supply", "amplifier", "circuit", "scrap", "sheet_metal", "pipe", "wrench", "screwdriver"],
 "telecom": ["processor", "RAM", "cable", "circuit", "amplifier", "e_scrap", "small_lcd_screen", "radio", "wire", "light_battery_cell"],
 "fmetal": ["nuts_bolts", "steel_chunk", "steel_lump", "sheet_metal", "pipe", "scrap", "bearing", "nail", "wire", "motor_micro", "wrench"],
 "fpoly": ["plastic_chunk", "plastic_sheet", "adhesive", "wire", "cable", "scrap", "sheet_metal", "plastic_bag", "bottle_plastic"],
 "palace": ["cash_card", "kimono", "sake_filtered", "tea_green", "candle", "cigar", "lighter", "umbrella", "jacket_light", "smart_phone", "gold_small", "silver_small", "diamond", "pearl"],
 "office": ["paper", "pen", "laptop", "smart_phone", "cash_card", "coffee_raw", "energy_drink", "flashlight"],
}
def loot_groups():
    out = []
    for tag, ids in POOLS.items():
        ok = [i for i in ids if vet_item(i)]
        if tag == "implant": pass
        ents = [{"item": i} for i in ok]
        if tag == "implant": ents.append({"group": "trl_random_cbm", "prob": 4})
        if tag == "armory":
            ents += [{"group": g, "prob": 6} for g in ("trl_pistol_loaded", "trl_smg_loaded", "trl_rifle_loaded")]
        out.append({"type": "item_group", "id": f"trl_loot_{tag}", "subtype": "distribution", "entries": ents})
    return out

# ---------------------------------------------------------------- terrain/furniture json
def new_terrain_json():
    out = []
    for k, t in T.items():
        if k in ORIG_T or t.get("existing"): continue
        d = {"type": "terrain", "id": t["id"], "copy-from": t["base"], "name": t["name"], "description": t["desc"],
             "symbol": t["sym"], "color": t["color"]}
        d.update(t["extra"]); out.append(d)
    return out
def new_furniture_json():
    out = []
    for k in F:
        if k in ORIG_F or F[k].get("existing"): continue
        f = F[k]
        d = {"type": "furniture", "id": f["id"], "name": f["name"], "description": f["desc"], "symbol": f["sym"], "color": f["color"],
             "move_cost_mod": -1 if not f["kw"].get("passable") else 0, "coverage": 0 if f["kw"].get("passable") else 30,
             "required_str": -1, "flags": f["kw"].get("flags", ["TRANSPARENT"]),
             "bash": {"str_min": 6, "str_max": 30, "sound": "smash!", "sound_fail": "whump."}}
        if "CAN_SIT" in f["kw"].get("flags", []):
            d["move_cost_mod"] = 1; d["coverage"] = 40; d["comfort"] = 1; d["required_str"] = 4
        if f["kw"].get("comfort"): d["comfort"] = f["kw"]["comfort"]
        if f["light"]: d["light_emitted"] = f["light"]
        out.append(d)
    return out

def main():
    only = os.environ.get("PREVIEW")
    ter, mp, cb = [], [], []
    report = []
    for b in BUILDINGS:
        levels = build_levels(b)
        b["levels"] = levels
        emit(b, levels, ter, mp, cb)
        lights = [sum(1 for k, _, _ in L.f if F[k]["light"] > 0) for L in levels]
        report.append((b["id"], b["name"], f"{b['nx']}x{b['ny']}", b["floors"], sum(len(L.f) for L in levels), min(lights[:-1]) if len(lights) > 1 else 0, b.get("warn", [])))
    od = os.path.join(MOD, "towers"); os.makedirs(od, exist_ok=True)
    json.dump(new_terrain_json(), open(os.path.join(od, "terrain.json"), "w"), indent=1)
    json.dump(new_furniture_json(), open(os.path.join(od, "furniture.json"), "w"), indent=1)
    json.dump(loot_groups(), open(os.path.join(od, "loot.json"), "w"), indent=1)
    json.dump(mp, open(os.path.join(od, "mapgen.json"), "w"))
    json.dump(ter + cb, open(os.path.join(od, "buildings.json"), "w"), indent=1)
    ro_path = os.path.join(MOD, "region_overlay.json")
    ro = json.load(open(ro_path)); shops = ro[0]["city"]["shops"]
    for b in BUILDINGS: shops[b["id"]] = b["weight"]
    json.dump(ro, open(ro_path, "w"), indent=1)
    print(len(BUILDINGS), "towers;", len(mp), "mapgen objects;", len(ter), "overmap terrains")
    for r in report: print(f"{r[0]:10} {r[1][:36]:36} {r[2]} floors={r[3]} furn={r[4]:4} minlights={r[5]:3} warn={r[6]}")
    if MISSING: print("MISSING vanilla ids:", sorted(MISSING))
    if only:
        for b in BUILDINGS:
            if b["id"].endswith(only):
                z = int(os.environ.get("Z", "0")); L = b["levels"][z]
                ch = {k: CHARPOOL[i] for i, k in enumerate(sorted({k for row in L.t for k in row}))}
                print({v: k for k, v in ch.items()})
                grid = [[ch[k] for k in row] for row in L.t]
                bad = set(L.unreachable(L.stairs_tiles[0])) if L.stairs_tiles else set()
                for k, x, y in L.f: grid[y][x] = "~" if F[k]["light"] > 0 else "B" if blocks(k) else "o"
                for (x, y) in bad: grid[y][x] = "X"
                print("\n".join("".join(r) for r in grid))

if __name__ == "__main__":
    main()
