"""Shop and flat recipes, drawn in the local frame of gt_core.LF."""
from gt_core import *

def door_pos(x0, y0, x1, y1, side, off=None):
    if side == "s": return (off if off is not None else (x0 + x1) // 2, y1)
    if side == "n": return (off if off is not None else (x0 + x1) // 2, y0)
    if side == "e": return (x1, off if off is not None else (y0 + y1) // 2)
    return (x0, off if off is not None else (y0 + y1) // 2)

def local_u(lf, d):
    x, y = d
    return (x - lf.ix0) if lf.side in "sn" else (y - lf.iy0)

def make_room(L, x0, y0, x1, y1, side, floor, wall="wall_concrete", door_key="wdoor", off=None):
    L.rect(x0, y0, x1, y1, wall, floor)
    d = door_pos(x0, y0, x1, y1, side, off)
    L.door(door_key, *d)
    lf = LF(L, x0, y0, x1, y1, side)
    ud = local_u(lf, d)
    # keep the doorway clear
    for v in (lf.h - 1, lf.h - 2):
        L.occ.add(lf.xy(ud, v))
    return lf, ud

DECOR = ["vase_blue", "vase_white", "vase_red", "fern", "bonsai", "wind_chime", "scroll", "vase_tall"]

# ============================================================================ FLATS
def flat(L, x0, y0, x1, y1, side, style, wall="wall_concrete", off=None, loot=True):
    floor = dict(micro="floor_plain", tatami="tatami", lux="floor_wood", dorm="carpet_grey", worker="slab", capsule="carpet_grey",
                 family="carpet_teal")[style]
    lf, ud = make_room(L, x0, y0, x1, y1, side, floor, wall, "wdoor" if style not in ("capsule",) else "wdoor", off)
    w, h = lf.w, lf.h
    mirror = ud < w // 2
    U = (lambda u: w - 1 - u) if mirror else (lambda u: u)
    def f(key, u, v): return lf.f(key, U(u), v)
    def t(k, u, v): lf.t(k, U(u), v)
    # bath nook, back corner on the side away from the door
    bath = w >= 6 and h >= 5 and style not in ("capsule", "dorm")
    if bath:
        bw = 3 if w >= 7 else 2
        for v in range(0, 4): t("wall_concrete", bw, v)
        for u in range(0, bw + 1): t("wall_concrete", u, 3)
        for u in range(0, bw):
            for v in range(0, 3): t("tile_bath", u, v)
        t("wdoor", bw, 1)
        f("toilet", 0, 0); f("sink", bw - 1, 0)
        f("bathtub" if style in ("lux", "family") else "shower", bw - 1, 2)
    kx = w - 4 if bath else 0
    # kitchenette along the back wall, opposite corner
    if style in ("micro", "tatami", "lux", "worker", "family"):
        kit = {"worker": ["hot_plate", "counter", "sink", "fridge"], "lux": ["sink", "counter", "oven", "fridge"]}.get(style, ["sink", "counter", "oven", "fridge"])
        for i, k in enumerate(kit): f(k, w - 1 - i, 0)
    if style == "micro":
        f("bed", 0, h - 3); f("dresser", 0, h - 5 if h > 7 else h - 4)
        f("table", w - 2, h // 2 + 1); f("chair", w - 2, h // 2 + 2); f("chair", w - 3, h // 2 + 1)
        f("wardrobe", w - 1, h - 2); f("shoe_rack", 1, h - 1)
    elif style == "tatami":
        f("table_low", w // 2, h // 2); f("cushion", w // 2 - 1, h // 2); f("cushion", w // 2 + 1, h // 2)
        f("futon", 1, h - 3); f("futon", 2, h - 3)
        f("shrine", w - 1, h - 3); f("scroll", 0, h // 2); f("shoe_rack", 1, h - 1); f("bookcase", w - 1, h // 2 + 1)
    elif style == "lux":
        f("bed", 0, h - 3); f("bed", 1, h - 3); f("dresser", 0, h - 5); f("dresser", 2, h - 5)
        f("sofa", w // 2, h - 3); f("armchair", w // 2 + 2, h - 4); f("armchair", w // 2 - 2, h - 4)
        f("table_low", w // 2, h - 4); f("aquarium", w // 2, 0 if not bath else 0)
        f("bookcase", w - 1, h // 2); f("piano", w - 2, h // 2 + 2); f("shoe_rack", 1, h - 1)
    elif style == "worker":
        f("futon", 0, h - 3); f("futon", 0, h - 5); f("futon", 1, h - 4)
        f("shelf_scrap", w - 1, h // 2); f("bench_scrap", w // 2, h // 2); f("laundry", 1, h // 2)
        f("table_plastic", w - 2, h - 3); f("stool_plastic", w - 3, h - 3); f("fire_drum_s", 0, 0) if False else None
    elif style == "family":
        f("bed", 0, h - 3); f("bed", 0, h - 5); f("dresser", 1, h - 6 if h > 8 else h - 2)
        f("sofa", w - 2, h - 3); f("table", w // 2, h // 2); f("chair", w // 2 - 1, h // 2); f("chair", w // 2 + 1, h // 2)
        f("armchair", w - 1, h // 2 + 2); f("fern", 1, h - 1)
    elif style == "dorm":
        for i, v in enumerate(range(1, h - 2, 2)):
            f("bunk_bed", 0, v); f("bunk_bed", w - 1, v)
            f("locker", 1, v) if i % 2 == 0 else None
        f("table", w // 2, 1); f("chair", w // 2, 2); f("washer", w // 2 + 1, 0) if False else None
    elif style == "capsule":
        for v in range(0, h - 2, 2):
            f("capsule", 0, v); f("capsule", 1, v)
            f("capsule", w - 1, v); f("capsule", w - 2, v)
        f("locker", w // 2, 0)
    # decor
    for _ in range(2):
        lf.f(L.rng.choice(DECOR), L.rng.randint(0, w - 1), L.rng.randint(0, h - 3))
    if loot:
        tag = "worker" if style == "worker" else "dorm" if style in ("dorm", "capsule") else "apt"
        lf.loot(f"trl_loot_{tag}", 55, 3)
    return lf

# ============================================================================ SHOPS
def shop(L, x0, y0, x1, y1, side, kind, wall="wall_concrete", off=None, door_key="door_c", glass=True):
    lf, ud = make_room(L, x0, y0, x1, y1, side, "floor_corp", wall, door_key, off)
    w, h = lf.w, lf.h
    KIND[kind](lf, w, h, ud)
    return lf

def _front_gap(lf, ud): return ud
def k_noodle(lf, w, h, ud):
    lf.floor("checker")
    for u in range(w): lf.f(["oven", "fridge", "sink", "counter"][u % 4], u, 0)
    for u in range(3, w): lf.f("counter_noodle", u, 2)
    for u in range(3, w): lf.f("bar_stool", u, 3)
    for u in range(1, w - 2, 3):
        for v in range(5, h - 2, 3):
            lf.f("table_plastic", u, v); lf.f("stool_plastic", u - 1, v) if u > 0 else None; lf.f("stool_plastic", u + 1, v)
    lf.f("lantern", 1, 4); lf.f("lantern", w - 1, 4); lf.f("neon_red", w // 2, 1); lf.f("vending", w - 1, h - 2)
    lf.loot("trl_loot_food", 70, 3)
def k_conv(lf, w, h, ud):
    for v in (2, 4):
        for u in range(1, w - 2): lf.f("shelf_clean", u, v)
    for u in range(w): lf.f("glass_fridge", u, 0)
    lf.f("shop_counter", 0, h - 2); lf.f("shop_counter", 1, h - 2)
    lf.f("vending", w - 1, h - 2); lf.f("vending", w - 1, h - 3); lf.f("neon_cyan", w // 2, 1)
    lf.loot("trl_loot_conv", 70, 4)
def k_pharm(lf, w, h, ud):
    for u in range(w): lf.f("cabinet_lacquer" if u % 3 == 0 else "cupboard", u, 0)
    for v in (3, 5):
        for u in range(1, w - 2): lf.f("shelf_clean", u, v)
    for u in range(1, w - 1): lf.f("shop_counter", u, 2) if u != w // 2 else None
    lf.f("lightbox", 0, h - 2); lf.f("lightbox", w - 1, h - 2); lf.f("bench_waiting", w - 1, h // 2 + 1)
    lf.f("neon_green", 1, 1)
    lf.loot("trl_loot_pharm", 70, 4)
def k_tea(lf, w, h, ud):
    lf.floor("tatami")
    for u in range(1, w - 1): lf.f("shelf_clean", u, 0)
    for u in range(2, w - 2, 3):
        for v in range(2, h - 2, 3):
            lf.f("table_low", u, v); lf.f("cushion", u - 1, v); lf.f("cushion", u + 1, v)
    lf.f("bonsai", 0, 1); lf.f("vase_white", w - 1, 1); lf.f("lantern", 0, h // 2); lf.f("lantern", w - 1, h // 2); lf.f("scroll", w // 2, 1)
    lf.loot("trl_loot_food", 55, 2)
def k_elec(lf, w, h, ud):
    lf.floor("checker")
    for u in range(w): lf.f("lightbox", u, 2) if u % 2 == 0 else None
    for u in range(1, w - 1): lf.f("workbench", u, 0) if u % 2 else lf.f("server_rack", u, 0)
    for u in range(1, w - 2, 3): lf.f("lightbox", u, 5); lf.f("desk_lamp", u, 5) if False else None
    lf.f("holo_ad", w // 2, 3); lf.f("shop_counter", 0, h - 2); lf.f("shop_counter", 1, h - 2); lf.f("neon_cyan", w - 2, 1)
    lf.loot("trl_loot_tech", 75, 5)
def k_repair(lf, w, h, ud):
    lf.floor("slab")
    for u in range(w): lf.f("tool_cabinet" if u % 4 == 0 else "shelf_scrap", u, 0)
    for u in range(1, w - 2, 3): lf.f("workbench", u, 3); lf.f("stool_plastic", u, 4)
    lf.f("crate", w - 1, h - 2); lf.f("fire_drum", w - 1, 1) if False else None; lf.f("floodlight", 0, h - 3)
    lf.loot("trl_loot_tool", 75, 5)
def k_izakaya(lf, w, h, ud):
    lf.floor("floor_wood")
    for u in range(w): lf.f("cabinet_lacquer" if u % 3 == 1 else "shelf_clean", u, 0)
    for u in range(2, w): lf.f("counter_noodle", u, 2)
    for u in range(2, w): lf.f("bar_stool", u, 3)
    for u in range(1, w - 1, 4):
        for v in range(6, h - 2, 3): lf.f("table_low", u, v); lf.f("cushion", u - 1, v); lf.f("cushion", u + 1, v)
    for u in range(1, w - 1, 3): lf.f("lantern", u, 4)
    lf.f("neon_amber", w // 2, 1); lf.f("vase_red", 0, 1)
    lf.loot("trl_loot_drink", 70, 4)
def k_arcade(lf, w, h, ud):
    lf.floor("checker")
    for u in range(w): lf.t("neon_pink" if (u % 3 == 0) else "checker", u, h // 2)
    for u in range(0, w, 2): lf.f("arcade", u, 0); lf.f("arcade", u, 2)
    for u in range(1, w - 1, 2): lf.f("arcade", u, 4) if h > 8 else None
    lf.f("ticket_machine", w - 1, h - 3); lf.f("vending", 0, h - 2); lf.f("neon_violet", w // 2, 1)
    lf.loot("trl_loot_conv", 40, 2)
def k_books(lf, w, h, ud):
    lf.floor("floor_wood")
    for u in range(w): lf.f("bookcase", u, 0)
    for v in range(2, h - 2, 3):
        for u in range(1, w - 3): lf.f("bookcase", u, v)
    lf.f("chair_wicker", w - 1, 2); lf.f("chair_wicker", w - 1, h - 3); lf.f("desk_lamp", w - 2, 2)
    lf.f("shop_counter", 0, h - 2); lf.f("scroll", w - 1, 4); lf.f("neon_amber", 1, 1)
    lf.loot("trl_loot_books", 70, 4)
def k_art(lf, w, h, ud):
    lf.floor("floor_wood")
    for u in range(1, w - 1, 2): lf.f("scroll", u, 0)
    for u in range(2, w - 2, 3):
        for v in range(2, h - 2, 3): lf.f("table_low", u, v); lf.f("vase_blue" if (u + v) % 2 else "vase_white", u, v - 1)
    lf.f("shop_counter", 0, h - 2); lf.f("bonsai", w - 1, 1); lf.f("lantern_stone", w - 1, h - 3)
    lf.loot("trl_loot_decor", 60, 3)
def k_fashion(lf, w, h, ud):
    lf.floor("carpet_red")
    for u in range(w): lf.f("mannequin" if u % 3 == 1 else "rack", u, 0)
    for v in (3, 5):
        for u in range(1, w - 2, 2): lf.f("rack", u, v)
    lf.f("lightbox", w - 1, 2); lf.f("shop_counter", 0, h - 2); lf.f("shop_counter", 1, h - 2)
    lf.f("neon_pink", w // 2, 1); lf.f("chair_lounge", w - 1, h - 3)
    lf.loot("trl_loot_fashion", 75, 5)
def k_salon(lf, w, h, ud):
    lf.floor("checker")
    for u in range(1, w - 1, 2): lf.f("chair_office", u, 2); lf.f("lightbox", u, 0)
    for u in range(1, w - 1, 2): lf.f("chair_office", u, 5) if h > 8 else None
    lf.f("shop_counter", 0, h - 2); lf.f("sink", w - 1, 0); lf.f("fern", w - 1, h - 3); lf.f("neon_violet", w // 2, 1)
    lf.loot("trl_loot_fashion", 55, 3)
def k_bodyshop(lf, w, h, ud):
    lf.floor("floor_corp")
    for u in range(w): lf.f("cabinet_lacquer" if u % 2 else "implant_printer", u, 0) if u % 2 == 0 else lf.f("cupboard", u, 0)
    for u in range(1, w - 1, 3): lf.f("chair_office", u, 3); lf.f("console", u + 1, 3)
    lf.f("lightbox", 0, h - 2); lf.f("bench_waiting", w - 1, h - 2); lf.f("neon_cyan", w // 2, 1)
    lf.loot("trl_loot_implant", 55, 3); lf.loot("trl_loot_pharm", 40, 2)
def k_pawn(lf, w, h, ud):
    lf.floor("slab")
    for u in range(w): lf.f("safe" if u == w - 1 else "shelf_scrap", u, 0)
    for u in range(1, w - 1, 2): lf.f("displaycase", u, 2)
    for u in range(1, w - 2, 3): lf.f("lightbox", u, 4)
    lf.f("shop_counter", 0, h - 2); lf.f("neon_red", w // 2, 1)
    lf.loot("trl_loot_pawn", 70, 4)
def k_market(lf, w, h, ud):
    lf.floor("pave")
    for u in range(1, w - 1, 4):
        for v in range(2, h - 2, 4):
            lf.f("table_plastic", u, v); lf.f("lantern", u + 1, v); lf.f("stool_plastic", u, v + 1)
    lf.f("holo_ad", w // 2, 1)
    lf.loot("trl_loot_food", 60, 3)
def k_super(lf, w, h, ud):
    lf.floor("checker")
    for u in range(w): lf.f("glass_fridge", u, 0)
    for v in range(2, h - 4, 3):
        for u in range(1, w - 1): lf.f("shelf_clean", u, v) if u != w // 2 else None
    for u in range(0, w - 1, 3): lf.f("shop_counter", u, h - 2); lf.f("console", u + 1, h - 2) if False else None
    lf.f("vending", w - 1, h - 3); lf.f("neon_green", w // 2, 1)
    lf.loot("trl_loot_conv", 75, 6)
def k_karaoke(lf, w, h, ud):
    lf.floor("carpet_red")
    for u in range(0, w, 2): lf.f("neon_pink" if u % 4 == 0 else "neon_violet", u, 0)
    for u in range(1, w - 1, 3): lf.f("chair_lounge", u, 2); lf.f("chair_lounge", u + 1, 2); lf.f("table_low", u, 3)
    for u in range(w): lf.f("bar_stool", u, h - 3) if 0 < u < w - 2 else None
    lf.f("counter_noodle", w - 1, h - 3); lf.f("console", 0, 1); lf.f("holo_ad", w // 2, 4)
    lf.loot("trl_loot_drink", 60, 3)

KIND = dict(noodle=k_noodle, conv=k_conv, pharm=k_pharm, tea=k_tea, elec=k_elec, repair=k_repair, izakaya=k_izakaya,
            arcade=k_arcade, books=k_books, art=k_art, fashion=k_fashion, salon=k_salon, bodyshop=k_bodyshop, pawn=k_pawn,
            market=k_market, super=k_super, karaoke=k_karaoke)

# ============================================================================ common bits
def frontage(L, x0, x1, y, door_x, pillar=6, pillar_key="wall_neon"):
    """Glass shopfront on a horizontal wall at y, a door at door_x(s), neon pillars."""
    ds = door_x if isinstance(door_x, (list, tuple)) else [door_x]
    for x in range(x0 + 1, x1):
        if x in ds: continue
        if (x - x0) % pillar == 0: L.put(pillar_key, x, y)
        else: L.put("window", x, y)

def storeroom(L, x0, y0, x1, y1, side, off=None, wall="wall_concrete", kind="stock"):
    lf, ud = make_room(L, x0, y0, x1, y1, side, "slab", wall, "wdoor", off)
    w, h = lf.w, lf.h
    for u in range(1, w - 1):
        lf.f("shelf_scrap", u, 0)
        if h > 5 and u % 2: lf.f("crate", u, 2)
    lf.f("crate", w - 1, h - 2)
    lf.loot("trl_loot_tool", 45, 2); lf.loot("trl_loot_conv", 30, 2)
    return lf

def roof_props(L, rng, ac=3, extra=()):
    """Scatter roof furniture."""
    for k in ("ac_unit",) * ac + tuple(extra):
        L.scatter(k, 3, 3, L.W - 4, L.H - 4, 1)
    L.scatter("water_tank", 3, 3, L.W - 4, L.H - 4, 1)
