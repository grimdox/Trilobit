#!/usr/bin/env python3
"""Generate 41 Trilobit mid-rise buildings (1 OMT footprint, 2-4 stories + roof).
Run AFTER gen_city.py and gen_places.py.  usage: gen_midrise.py <mod dir>"""
import json, os, random, sys
MOD = sys.argv[1]
sys.argv = [sys.argv[0], MOD]
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_places as gp
from gen_places import ter, fur, G, SEAT, SURF, SOLID, T, F, FLOORS, WALLS

# ------------------------------------------------------------------ new terrain / furniture
NEW_T, NEW_F = set(), set()
def nter(*a, **k):
    ter(*a, **k); NEW_T.add(a[0])
def nfur(*a, **k):
    fur(*a, **k); NEW_F.add(a[0])
def exist(key, tid):
    T[key] = dict(ch="?", id=tid, name=None, desc=None, sym=None, color=None, base=None, extra={}, existing=True)

exist("air", "t_open_air"); exist("rail", "t_railing"); exist("roof", "t_flat_roof"); exist("wall_part", "t_wall")
exist("stair_up", "t_stairs_up"); exist("stair_down", "t_stairs_down")
exist("door_wood", "t_door_c"); exist("door_steel", "t_door_metal_c")
nter("wall_brick", "?", "weathered brick wall", "Dark red brick, stained by decades of soot and rain.", "#", "red", "t_concrete_wall")
nter("wall_olive", "?", "olive-drab panel wall", "Flat olive-green panels, scuffed and stencilled with unit codes.", "#", "green", "t_concrete_wall")
nter("wall_tile", "?", "stained tile wall", "Cracked white tile gone yellow and brown with grease and damp.", "#", "brown", "t_concrete_wall")
nter("wall_lacquer", "?", "red lacquer wall", "A wall of deep red lacquer with gold trim.", "#", "light_red", "t_concrete_wall")
nter("wall_steel", "?", "brushed steel wall", "A seamless wall of brushed steel, cold to the touch.", "#", "light_gray", "t_concrete_wall")
nter("floor_dirty", "?", "stained linoleum", "Linoleum worn through to the backing, stained brown and grey.", ".", "brown", "t_floor")
nter("floor_steel", "?", "brushed steel floor", "Plain steel floor plates, bolted down in a neat grid.", ".", "light_gray", "t_floor")
nter("carpet_red", "?", "worn red carpet", "A red carpet, bald in the places where people walk.", ".", "red", "t_floor")
nter("floor_olive", "?", "painted concrete floor", "A concrete floor painted a flat military grey-green.", ".", "green", "t_floor")
nter("window_bars", "?", "barred window", "A small window behind rusted bars.", "\"", "dark_gray", "t_window_no_curtains")
for k in ("floor_dirty", "floor_steel", "carpet_red", "floor_olive", "wall_part", "roof"):
    pass
FLOORS.update({"floor_dirty", "floor_steel", "carpet_red", "floor_olive", "roof"})
WALLS.update({"wall_brick", "wall_olive", "wall_tile", "wall_lacquer", "wall_steel", "wall_part"})

# neon
nfur("pachinko", "pachinko machine", "A pachinko machine, a roaring waterfall of steel balls and light.", "P", "pink", 9, flags=SOLID)
nfur("karaoke", "karaoke booth", "A little booth with a glowing lyric screen and sticky microphones.", "K", "magenta", 8, flags=SOLID)
nfur("mirror_ball", "mirror ball", "A slow-turning mirror ball that scatters coloured light.", "o", "light_cyan", 13, flags=SOLID, passable=True)
nfur("speaker", "speaker stack", "A stack of speakers, silent now.", "S", "dark_gray", flags=SOLID)
nfur("neon_pink_big", "huge magenta neon sign", "A sign the size of a door, burning magenta.", "=", "pink", 14, flags=SOLID, passable=True)
# tea / Chinese / Russian
nfur("samovar", "samovar", "A dented brass urn for boiling tea water, still warm to the touch.", "u", "yellow", flags=SOLID)
nfur("red_lantern", "red lantern", "A round red paper lantern with a gold tassel.", "o", "light_red", 11, flags=SOLID, passable=True)
nfur("tea_shelf", "tea shelf", "A shelf of round tins and brick-pressed tea cakes.", "H", "brown", flags=SOLID + ["FLAT_SURF"])
nfur("tea_table", "tea table", "A heavy wooden table with a drain for spilled tea.", "T", "brown", flags=SURF)
nfur("tiled_stove", "tiled stove", "A tall stove clad in glazed blue and white tiles.", "H", "light_blue", flags=SOLID)
nfur("icon_lamp", "icon corner", "A small dark painted icon with a flickering lamp before it.", "+", "yellow", 5, flags=SOLID, passable=True)
nfur("banner_red", "red banner", "A long red banner with gold lettering.", "|", "light_red", flags=SOLID, passable=True)
# military
nfur("cot", "army cot", "A canvas cot with a grey blanket, squared away.", "b", "green", flags=["TRANSPARENT", "MOUNTABLE"], comfort=2)
nfur("bunk_steel", "steel bunk", "A steel bunk, two high.", "B", "light_gray", flags=SOLID, comfort=2)
nfur("ammo_crate", "ammo crate", "A green steel crate stencilled with ammunition codes.", "X", "green", flags=SOLID + ["FLAT_SURF"])
nfur("map_table", "map table", "A big table under a sheet of scratched plastic, grease-pencil marks across it.", "T", "green", flags=SURF)
nfur("weapon_rack", "weapon rack", "An empty steel rack for long weapons.", "H", "dark_gray", flags=SOLID)
nfur("radio_set", "radio set", "A bank of military radios, dials faintly lit.", "R", "light_green", 7, flags=SOLID)
nfur("locker_mil", "steel locker", "A grey locker with a name card slot.", "H", "light_gray", flags=SOLID + ["FLAT_SURF"])
nfur("sandbags", "sandbag wall", "A knee-high wall of sandbags.", "#", "brown", flags=["TRANSPARENT", "MOUNTABLE"])
nfur("sentry_lamp", "sentry lamp", "A caged lamp on a pole, hard white light.", "Y", "white", 30, flags=SOLID)
nfur("banner_unit", "regimental banner", "A faded unit banner on a pole.", "|", "white", flags=SOLID, passable=True)
# android
nfur("android_pod", "android pod", "A tall glass pod with a pale figure sleeping upright inside, lit blue.", "A", "light_blue", 8, flags=SOLID)
nfur("assembly_arm", "assembly arm", "A ceiling-mounted robot arm, frozen mid-stroke.", "Z", "light_cyan", 6, flags=SOLID)
nfur("limb_bin", "limb bin", "A bin of pale synthetic limbs, tagged and sorted.", "L", "white", flags=SOLID + ["FLAT_SURF"])
nfur("head_rack", "face-blank rack", "A rack of blank faces waiting for features.", "H", "white", 5, flags=SOLID)
nfur("test_bench", "diagnostic bench", "A bench with straps, probes and a flickering diagnostic screen.", "W", "light_cyan", 7, flags=SURF)
nfur("mannequin", "display mannequin", "A pale mannequin in the season's fashion.", "M", "white", flags=SOLID)
nfur("charge_rack", "charging rack", "A rack of seats with cables and green charge lights.", "P", "light_green", 6, flags=SOLID)
# dingy
nfur("mattress", "stained mattress", "A thin mattress, stained and sagging.", "b", "brown", flags=["TRANSPARENT", "MOUNTABLE"], comfort=1)
nfur("hotplate", "hotplate on a crate", "A single hotplate on an upturned crate.", "h", "light_red", flags=SOLID + ["FLAT_SURF"])
nfur("water_barrel", "water barrel", "A plastic barrel of stale rainwater.", "0", "light_blue", flags=SOLID)
nfur("tv_static", "flickering screen", "A cracked screen showing nothing but static.", "V", "light_gray", 6, flags=SOLID)
nfur("sewing_table", "sewing table", "A long table with a row of sewing machines bolted down.", "T", "light_gray", flags=SURF)
nfur("bunk_rust", "rust bunk", "A rusty bunk with a thin pad.", "B", "red", flags=SOLID, comfort=1)
nfur("table_card", "card table", "A green-topped table scattered with chips and cards.", "T", "green", flags=SURF)
nfur("wall_pipes_f", "leaking pipe", "A pipe sweating rust-coloured water down the wall.", "%", "brown", flags=SOLID)

# ------------------------------------------------------------------ layout helpers
LANE = range(10, 14)       # x of the entrance lane / core columns
def clear_zone(g):
    g.f = [(k, x, y) for k, x, y in g.f if not ((9 <= x <= 14 and 10 <= y <= 14) or (10 <= x <= 13 and y >= 15))]
    g.occ = {(x, y) for _, x, y in g.f}

def core(g, z, st, ground_door=None):
    """Stair core: walls x9..14, y10..14; stairs at (10,12) and (13,12)."""
    for y in range(10, 15):
        for x in range(9, 15):
            edge = x in (9, 14) or y in (10, 14)
            g.t[y][x] = "wall_part" if edge else ("slab" if z < st else "roof")
    g.t[10][12] = "door_wood"; g.t[14][11] = "door_wood"
    a, b = (10, 12), (13, 12)
    has_up, has_down = z < st, z > 0
    if z == st:
        # roof: arrival tile is the stairs down
        if st % 2 == 0: g.t[b[1]][b[0]] = "stair_down"
        else: g.t[a[1]][a[0]] = "stair_down"
    elif z % 2 == 0:
        g.t[a[1]][a[0]] = "stair_up"
        if has_down: g.t[b[1]][b[0]] = "stair_down"
    else:
        g.t[a[1]][a[0]] = "stair_down" if has_down else g.t[a[1]][a[0]]
        g.t[b[1]][b[0]] = "stair_up"
    g.occ |= {(x, y) for x in range(9, 15) for y in range(10, 15)}
    g.f_("floor_lamp", 11, 11) if False else None
    g.f.append(("floor_lamp", 11, 11))

def rooms_ns(g, S, z):
    """Apartment-style floor: corridor band y10..14, three rooms north, two south, open lobby south middle."""
    wp = "wall_part"
    for x in (8, 15):
        g.vwall(x, 3, 9, wp); g.vwall(x, 15, 20, wp)
    g.hwall(3, 20, 9, wp); g.hwall(3, 8, 15, wp); g.hwall(15, 20, 15, wp)
    for x, y in ((5, 9), (11, 9), (18, 9), (5, 15), (18, 15)): g.door("door_wood", x, y)
    if S.get("lobby", True) is False:
        g.hwall(9, 14, 15, wp); g.door("door_wood", 11, 15)
    rooms = [(3, 3, 7, 8), (9, 3, 14, 8), (16, 3, 20, 8), (3, 16, 7, 20), (16, 16, 20, 20)]
    for x0, y0, x1, y1 in rooms:
        for key, n in S["room"]:
            g.scatter(key, x0, y0, x1, y1, n)
    for key, n in S.get("hall", []):
        g.scatter(key, 3, 10, 20, 14, n)
    if S.get("lobby_items"):
        for key, n in S["lobby_items"]: g.scatter(key, 9, 16, 14, 20, n)

def hall(g, S, z):
    row, seat = S["row"], S.get("seat")
    xs = range(4, 20, 2 if S.get("dense") else 3)
    for y in S.get("rows", (5, 8)):
        for x in xs:
            g.f_(row, x, y)
            if seat: g.f_(seat, x, y + 1)
    for y in S.get("rows2", (16, 19)):
        for x in xs:
            g.f_(row, x, y)
            if seat and y + 1 < 21: g.f_(seat, x, y + 1)
    if S.get("back"): g.line(S["back"], 3, 3, 20, 3)
    for k, n in S.get("deco", []): g.scatter(k, 3, 3, 20, 20, n)
    for k, n in S.get("hall", []): g.scatter(k, 3, 10, 20, 14, n)

def ruin(g, S, z):
    for k, n in S.get("deco", [("trash", 4), ("pipes", 3)]): g.scatter(k, 3, 3, 20, 20, n)
    for x in (8, 15): g.vwall(x, 3, 9, "wall_part"); g.vwall(x, 15, 20, "wall_part")

KINDS = {"apts": rooms_ns, "hall": hall, "ruin": ruin}

def exterior_signs(g, S):
    for i, k in enumerate(S.get("signs", [])):
        g.f_(k, 5 + 12 * i, 22 if i < 2 else 1)
    g.f_(S.get("lamp", "street_lamp"), 3, 22); g.f_(S.get("lamp", "street_lamp"), 20, 22)

def floor_lights(g, n=5):
    cnt = sum(1 for k, _, _ in g.f if F[k]["light"] >= 4) + sum(
        1 for row in g.t for k in row if T[k]["extra"].get("light_emitted"))
    for pos in [(4, 4), (19, 4), (4, 19), (19, 19), (6, 12), (17, 12), (4, 12), (19, 12), (7, 6), (16, 6), (7, 17), (16, 17), (11, 8), (12, 17), (11, 4)]:
        if cnt >= n: break
        if g.f_(S_LAMP[0], *pos): cnt += 1
    return cnt

S_LAMP = ["floor_lamp"]

def build_level(S, z):
    st = S["stories"]
    ground, roof = z == 0, z == st
    g = G(base="air" if not ground else "walk", edge="air" if not ground else "walk")
    if not ground:
        g.fill(0, 0, 23, 23, "air")
    else:
        g.fill(0, 0, 23, 23, "walk")
    fl = "roof" if roof else S["floor_g"] if ground else S["floor_u"]
    wall = S["wall_g"] if ground else S["wall_u"]
    win = S["window"]
    g.box(2, 2, 21, 21, wall, fl)
    if not roof:
        for x in range(3, 21, 3):
            if x not in (10, 11, 12): g.put(win, x, 2)
            if x not in (10, 11, 12) or not ground: g.put(win, x, 21)
        for y in range(4, 21, 3):
            g.put(win, 2, y); g.put(win, 21, y)
        if ground:
            g.door(S.get("door", "door_c"), 11, 21)
    else:
        for i in range(2, 22):
            for (x, y) in ((i, 2), (i, 21), (2, i), (21, i)): g.t[y][x] = "rail"
    if roof:
        S_LAMP[0] = "floor_lamp"
        for k, n in S.get("roof", [("neon_pink_big", 2), ("pipes", 3), ("vending", 1), ("crate", 3)]):
            g.scatter(k, 3, 3, 20, 20, n)
        # guarantee some glow
        g.f_(S.get("roof_sign", "neon_pink_big"), 5, 18); g.f_(S.get("roof_sign", "neon_pink_big"), 18, 5)
    else:
        kind, args = S["ground"] if ground else S["upper"]
        S2 = dict(args)
        KINDS[kind](g, S2, z)
    if ground: exterior_signs(g, S)
    if not roof:
        S_LAMP[0] = S.get("lamp_f", "floor_lamp")
    core(g, z, st)
    clear_zone_after = True
    # clear furniture on the core / entrance lane, but keep the core lamp
    g.f = [(k, x, y) for k, x, y in g.f if not ((9 <= x <= 14 and 10 <= y <= 14 and (x, y) != (11, 11)) or (10 <= x <= 13 and y >= 15 and ground) or (10 <= x <= 13 and y in (9,) and False))]
    # also no furniture on top of a wall or door
    g.f = [(k, x, y) for k, x, y in g.f if g.t[y][x] in FLOORS or F[k]["kw"].get("passable")]
    g.occ = {(x, y) for _, x, y in g.f}
    g.f = [(k, x, y) for k, x, y in g.f if g.t[y][x] in FLOORS]
    g.occ = {(x, y) for _, x, y in g.f}
    floor_lights(g, 6 if not roof else 4)
    # final: lamp inside core
    return g

# ------------------------------------------------------------------ the 40 buildings
# loot tags: food drink tech med tool decor + mil android dingy
B = []
def b(id, name, theme, sym, color, stories, wall_g, wall_u, window, floor_g, floor_u, ground, upper, loot_g, loot_u, **kw):
    B.append(dict(id=f"trl_mr{len(B)+1:02d}_{id}", name=name, theme=theme, sym=sym, color=color, stories=stories,
                  wall_g=wall_g, wall_u=wall_u, window=window, floor_g=floor_g, floor_u=floor_u,
                  ground=ground, upper=upper, loot_g=loot_g, loot_u=loot_u, **kw))

# ---- neon (8)
b("pachinko", "pachinko parlour tower", "neon", "N", "pink", 3, "wall_neon", "wall_concrete", "window", "slab", "carpet_red",
  ("hall", dict(row="pachinko", seat="bar_stool", dense=True, deco=[("neon_pink", 2), ("vending", 2)])),
  ("apts", dict(room=[("futon", 1), ("table_plastic", 1), ("desk_lamp", 1), ("tv_static", 1)], hall=[("trash", 2)])),
  "tech", "decor", signs=["neon_pink_big", "neon_cyan"])
b("karaoke", "karaoke tower", "neon", "N", "magenta", 4, "wall_neon", "wall_concrete", "window", "carpet_red", "carpet_red",
  ("hall", dict(row="karaoke", seat="chair_lounge", deco=[("neon_violet", 3), ("speaker", 2), ("mirror_ball", 1)], back="neon_violet")),
  ("apts", dict(room=[("karaoke", 1), ("chair_lounge", 2), ("neon_violet", 1), ("table_low", 1)], hall=[("neon_pink", 2)])),
  "drink", "drink", signs=["neon_violet", "neon_pink_big"])
b("lovehotel", "capsule love hotel", "neon", "N", "pink", 4, "wall_neon", "wall_concrete", "window", "carpet_red", "neon_pink",
  ("hall", dict(row="chair_lounge", seat=None, rows=(5,), rows2=(18,), deco=[("neon_pink", 3), ("vase_red", 2), ("fern", 2), ("ticket_machine", 1)], back="reception")),
  ("apts", dict(room=[("futon", 1), ("neon_pink", 2), ("chair_lounge", 1), ("mirror_ball", 1)], hall=[("neon_cyan", 1)])),
  "decor", "decor", signs=["neon_pink_big", "neon_red"])
b("holo", "holo-advert block", "neon", "N", "light_cyan", 3, "wall_screens", "wall_concrete", "window", "floor_corp", "slab",
  ("hall", dict(row="holo_ad", seat=None, rows=(6,), rows2=(17,), deco=[("neon_cyan", 3), ("console", 3), ("vending", 2)], back="lightbox")),
  ("apts", dict(room=[("desk_corp", 1), ("holo_ad", 1), ("console", 1), ("chair_office", 1)], hall=[("holo_ad", 2)])),
  "tech", "tech", signs=["neon_cyan", "neon_cyan"])
b("arcade_tower", "arcade tower", "neon", "N", "pink", 3, "wall_neon", "wall_concrete", "window", "checker", "slab",
  ("hall", dict(row="arcade", seat=None, dense=True, rows=(5, 7), rows2=(16, 18), deco=[("neon_pink", 3), ("vending", 2)])),
  ("hall", dict(row="arcade", seat="bar_stool", rows=(5,), rows2=(17,), deco=[("neon_cyan", 2), ("console", 2)])),
  "tech", "tech", signs=["neon_pink_big", "neon_amber"])
b("noodle_neon", "noodle bar tower", "neon", "N", "light_red", 3, "wall_slat", "wall_concrete", "window", "floor_wood", "floor_dirty",
  ("hall", dict(row="counter_noodle", seat="bar_stool", rows=(6, 9), rows2=(17,), deco=[("neon_red", 3), ("lantern", 4), ("noodle_cart", 1)])),
  ("apts", dict(room=[("futon", 1), ("hotplate", 1), ("neon_red", 1), ("table_plastic", 1)], hall=[("laundry", 2)])),
  "food", "food", signs=["neon_red", "neon_amber"])
b("club", "night club tower", "neon", "N", "magenta", 3, "wall_neon", "wall_concrete", "window", "neon_cyan", "carpet_red",
  ("hall", dict(row="speaker", seat=None, rows=(4,), rows2=(19,), deco=[("mirror_ball", 3), ("neon_violet", 3), ("chair_lounge", 4), ("table_low", 3)], back="neon_violet")),
  ("apts", dict(room=[("chair_lounge", 2), ("table_low", 1), ("neon_violet", 1), ("mirror_ball", 1)], hall=[("neon_pink", 2)])),
  "drink", "drink", signs=["neon_violet", "neon_cyan"])
b("boutique", "cyber boutique mall", "neon", "N", "light_cyan", 3, "wall_neon", "wall_concrete", "window", "floor_corp", "floor_corp",
  ("hall", dict(row="lightbox", seat=None, rows=(5, 8), rows2=(16, 19), deco=[("mannequin", 4), ("neon_cyan", 2), ("neon_pink", 2)])),
  ("hall", dict(row="shelf_clean", seat=None, rows=(5, 8), rows2=(16, 19), deco=[("mannequin", 3), ("neon_pink", 2)])),
  "decor", "decor", signs=["neon_cyan", "neon_pink_big"])

# ---- tea (6)
b("tea_salon", "tea salon block", "tea", "t", "light_green", 3, "wall_shoji", "wall_slat", "window", "tatami", "tatami",
  ("hall", dict(row="table_low", seat="cushion", rows=(5, 8), rows2=(16, 19), deco=[("lantern", 4), ("bonsai", 2), ("vase_white", 2), ("wind_chime", 1)], back="cabinet_lacquer")),
  ("apts", dict(room=[("futon", 1), ("table_low", 1), ("lantern", 1), ("vase_blue", 1)], hall=[("bonsai", 2)])),
  "drink", "decor", door="screen_c", signs=["lantern_stone", "lantern_stone"])
b("tea_wholesale", "tea wholesaler", "tea", "t", "green", 3, "wall_brick", "wall_concrete", "window", "slab", "floor_dirty",
  ("hall", dict(row="tea_shelf", seat=None, rows=(5, 8), rows2=(16, 19), deco=[("crate", 4), ("tea_table", 2), ("lantern", 2)], back="tea_shelf")),
  ("apts", dict(room=[("mattress", 1), ("tea_table", 1), ("desk_lamp", 1), ("crate", 1)], hall=[("crate", 3)])),
  "drink", "drink", door="shutter_c", signs=["neon_green", "neon_amber"])
b("gongfu", "gongfu tea house", "tea", "t", "light_red", 3, "wall_lacquer", "wall_lacquer", "window", "floor_wood", "carpet_red",
  ("hall", dict(row="tea_table", seat="chair_wicker", rows=(5, 8), rows2=(16, 19), deco=[("red_lantern", 5), ("vase_white", 2), ("banner_red", 2), ("fern", 2)], back="cabinet_lacquer")),
  ("apts", dict(room=[("tea_table", 1), ("chair_wicker", 2), ("red_lantern", 1), ("vase_blue", 1)], hall=[("banner_red", 2)])),
  "drink", "decor", signs=["red_lantern", "neon_red"])
b("tea_school", "tea ceremony school", "tea", "t", "light_green", 3, "wall_shoji", "wall_shoji", "window", "tatami", "floor_wood",
  ("hall", dict(row="table_low", seat="cushion", rows=(6,), rows2=(17,), deco=[("shrine", 1), ("scroll", 2), ("lantern_stone", 3), ("bonsai", 2)], back="scroll")),
  ("apts", dict(room=[("futon", 1), ("table_low", 1), ("scroll", 1), ("lantern", 1)], hall=[("lantern_stone", 2)])),
  "decor", "decor", door="screen_c", signs=["lantern_stone", "lantern_stone"])
b("tea_market", "covered tea market", "tea", "t", "yellow", 2, "wall_brick", "wall_brick", "window", "pave", "floor_wood",
  ("hall", dict(row="tea_table", seat="stool_plastic", dense=True, rows=(5, 8), rows2=(16, 19), deco=[("lantern", 6), ("red_lantern", 3), ("noodle_cart", 2)])),
  ("hall", dict(row="tea_shelf", seat=None, rows=(5, 8), rows2=(16, 19), deco=[("crate", 4), ("lantern", 3)])),
  "drink", "food", signs=["neon_amber", "red_lantern"])
b("chaikhana", "samovar tea room", "tea", "t", "yellow", 3, "wall_brick", "wall_tile", "window", "floor_wood", "floor_dirty",
  ("hall", dict(row="table_plastic", seat="chair_wicker", rows=(5, 8), rows2=(16, 19), deco=[("samovar", 4), ("tiled_stove", 2), ("icon_lamp", 2), ("floor_lamp", 3)], back="samovar")),
  ("apts", dict(room=[("mattress", 1), ("samovar", 1), ("tiled_stove", 1), ("icon_lamp", 1)], hall=[("laundry", 1), ("samovar", 1)])),
  "drink", "dingy", signs=["neon_red", "neon_amber"])

# ---- military (7)
b("garrison_us", "field command post", "military", "M", "green", 3, "wall_olive", "wall_olive", "window_bars", "floor_olive", "floor_olive",
  ("hall", dict(row="map_table", seat="chair_office", rows=(6,), rows2=(17,), deco=[("radio_set", 3), ("weapon_rack", 2), ("banner_unit", 2), ("ammo_crate", 3)], back="locker_mil")),
  ("apts", dict(room=[("cot", 2), ("locker_mil", 2), ("desk_lamp", 1)], hall=[("sandbags", 3), ("ammo_crate", 1)])),
  "mil", "mil", door="door_steel", lamp="sentry_lamp", signs=["sentry_lamp", "sentry_lamp"])
b("barracks_ru", "grey barracks block", "military", "M", "dark_gray", 4, "wall_brick", "wall_brick", "window_bars", "floor_olive", "floor_dirty",
  ("hall", dict(row="locker_mil", seat=None, rows=(5,), rows2=(17,), deco=[("banner_red", 3), ("table_plastic", 3), ("chair_office", 4), ("tv_static", 1)], back="locker_mil")),
  ("apts", dict(room=[("bunk_steel", 3), ("locker_mil", 2), ("floor_lamp", 1)], hall=[("banner_red", 1)])),
  "mil", "mil", door="door_steel", signs=["sentry_lamp", "banner_red"])
b("garrison_cn", "red garrison", "military", "M", "red", 3, "wall_lacquer", "wall_olive", "window_bars", "floor_olive", "floor_olive",
  ("hall", dict(row="map_table", seat="chair_office", rows=(6,), rows2=(17,), deco=[("banner_red", 4), ("red_lantern", 3), ("weapon_rack", 2), ("radio_set", 2)], back="locker_mil")),
  ("apts", dict(room=[("bunk_steel", 2), ("locker_mil", 2), ("red_lantern", 1)], hall=[("banner_red", 2)])),
  "mil", "mil", door="door_steel", signs=["red_lantern", "sentry_lamp"])
b("armory", "armory depot", "military", "M", "green", 3, "wall_steel", "wall_olive", "window_bars", "floor_steel", "floor_olive",
  ("hall", dict(row="weapon_rack", seat=None, rows=(5, 8), rows2=(16, 19), deco=[("ammo_crate", 6), ("locker_mil", 3), ("sentry_lamp", 1)])),
  ("hall", dict(row="ammo_crate", seat=None, rows=(5, 8), rows2=(16, 19), deco=[("locker_mil", 3), ("desk_lamp", 2)])),
  "mil", "mil", door="door_steel", signs=["sentry_lamp", "sentry_lamp"], lamp="sentry_lamp")
b("signals", "signals relay station", "military", "M", "light_green", 4, "wall_olive", "wall_olive", "window_bars", "floor_steel", "floor_olive",
  ("hall", dict(row="radio_set", seat="chair_office", rows=(5,), rows2=(17,), deco=[("server_rack", 4), ("console", 3), ("map_table", 1)])),
  ("apts", dict(room=[("radio_set", 1), ("chair_office", 1), ("desk_corp", 1), ("console", 1)], hall=[("server_rack", 2)])),
  "mil", "tech", door="door_steel", signs=["neon_green", "sentry_lamp"])
b("field_hospital", "field hospital", "military", "M", "light_red", 3, "wall_olive", "wall_tile", "window_bars", "floor_olive", "floor_dirty",
  ("hall", dict(row="cot", seat=None, dense=True, rows=(5, 8), rows2=(16, 19), deco=[("test_bench", 2), ("console", 2), ("floor_lamp", 3)], back="locker_mil")),
  ("apts", dict(room=[("cot", 2), ("test_bench", 1), ("floor_lamp", 1)], hall=[("floor_lamp", 1)])),
  "med", "med", door="door_steel", signs=["neon_red", "sentry_lamp"])
b("checkpoint", "military police post", "military", "M", "blue", 2, "wall_olive", "wall_olive", "window_bars", "floor_olive", "floor_olive",
  ("hall", dict(row="sandbags", seat=None, rows=(6,), rows2=(17,), deco=[("map_table", 1), ("radio_set", 1), ("weapon_rack", 1), ("locker_mil", 3), ("sentry_lamp", 2)], back="locker_mil")),
  ("apts", dict(room=[("cot", 1), ("locker_mil", 1), ("table_plastic", 1), ("desk_lamp", 1)], hall=[("sandbags", 2)])),
  "mil", "mil", door="door_steel", lamp="sentry_lamp", signs=["sentry_lamp", "neon_red"])

# ---- android (7)
b("assembly", "android assembly plant", "android", "A", "light_cyan", 3, "wall_steel", "wall_steel", "window", "floor_steel", "floor_steel",
  ("hall", dict(row="assembly_arm", seat=None, rows=(5, 8), rows2=(16, 19), deco=[("limb_bin", 4), ("head_rack", 3), ("console", 2)])),
  ("hall", dict(row="test_bench", seat=None, rows=(5, 8), rows2=(16, 19), deco=[("limb_bin", 3), ("android_pod", 3), ("console", 2)])),
  "android", "android", door="door_steel", signs=["neon_cyan", "neon_cyan"])
b("android_clinic", "android repair clinic", "android", "A", "light_blue", 3, "wall_steel", "wall_part", "window", "floor_corp", "floor_corp",
  ("hall", dict(row="charge_rack", seat=None, rows=(6,), rows2=(17,), deco=[("test_bench", 3), ("limb_bin", 2), ("console", 2)], back="reception")),
  ("apts", dict(room=[("test_bench", 1), ("android_pod", 1), ("console", 1), ("chair_office", 1)], hall=[("charge_rack", 2)])),
  "android", "android", signs=["neon_cyan", "neon_green"])
b("showroom", "android showroom", "android", "A", "white", 3, "wall_corp_hide" if False else "wall_corp", "wall_corp", "window", "floor_corp", "floor_corp",
  ("hall", dict(row="android_pod", seat=None, rows=(6,), rows2=(17,), deco=[("mannequin", 4), ("holo_ad", 2), ("neon_cyan", 2)], back="lightbox")),
  ("hall", dict(row="mannequin", seat=None, rows=(6,), rows2=(17,), deco=[("android_pod", 3), ("desk_corp", 2), ("holo_ad", 1)])),
  "android", "decor", signs=["neon_cyan", "holo_ad"])
b("dorm_android", "android dormitory", "android", "A", "light_green", 4, "wall_steel", "wall_concrete", "window", "floor_steel", "floor_steel",
  ("hall", dict(row="charge_rack", seat=None, dense=True, rows=(5, 8), rows2=(16, 19), deco=[("vending", 2), ("console", 1)])),
  ("apts", dict(room=[("charge_rack", 3), ("android_pod", 1), ("desk_lamp", 1)], hall=[("charging_pod", 2)])),
  "android", "android", signs=["neon_green", "charging_pod"])
b("memory_broker", "memory broker tower", "android", "A", "pink", 3, "wall_neon", "wall_steel", "window", "floor_corp", "floor_steel",
  ("hall", dict(row="server_rack", seat=None, rows=(5, 8), rows2=(16, 19), deco=[("neon_pink", 3), ("console", 3), ("holo_ad", 1)], back="reception")),
  ("apts", dict(room=[("server_rack", 2), ("chair_office", 1), ("console", 1)], hall=[("neon_pink", 2)])),
  "tech", "tech", signs=["neon_pink_big", "neon_cyan"])
b("mod_shop", "body-mod shop", "android", "A", "light_red", 3, "wall_steel", "wall_tile", "window", "floor_steel", "floor_dirty",
  ("hall", dict(row="test_bench", seat="chair_office", rows=(5,), rows2=(17,), deco=[("limb_bin", 3), ("neon_red", 3), ("vending", 1)], back="lightbox")),
  ("apts", dict(room=[("test_bench", 1), ("limb_bin", 1), ("desk_lamp", 1), ("futon", 1)], hall=[("trash", 2)])),
  "android", "dingy", signs=["neon_red", "neon_cyan"])
b("scrapyard_inside", "android scrap hall", "android", "A", "dark_gray", 2, "wall_brick", "wall_brick", "window_bars", "slab", "floor_dirty",
  ("hall", dict(row="limb_bin", seat=None, rows=(5, 8), rows2=(16, 19), deco=[("android_pod", 2), ("pipes", 4), ("trash", 3), ("fire_drum", 1)])),
  ("ruin", dict(deco=[("limb_bin", 5), ("trash", 4), ("pipes", 3), ("desk_lamp", 2)])),
  "android", "android", door="shutter_c", signs=["neon_red", "fire_drum"])

# ---- dingy life (12)
b("capsule_hotel", "capsule hotel", "dingy", "D", "light_gray", 4, "wall_tile", "wall_tile", "window", "floor_dirty", "floor_dirty",
  ("hall", dict(row="vending", seat=None, rows=(5,), rows2=(17,), deco=[("bench_scrap", 3), ("tv_static", 1), ("trash", 2), ("neon_cyan", 1)], back="reception")),
  ("hall", dict(row="capsule", seat=None, dense=True, rows=(4, 5), rows2=(16, 17), deco=[("desk_lamp", 3), ("trash", 2)])),
  "dingy", "dingy", signs=["neon_cyan", "neon_amber"])
b("khrushchyovka", "grey apartment block", "dingy", "D", "dark_gray", 4, "wall_brick", "wall_brick", "window", "floor_dirty", "floor_dirty",
  ("hall", dict(row="bench_scrap", seat=None, rows=(6,), rows2=(17,), deco=[("tiled_stove", 1), ("laundry", 2), ("trash", 3), ("icon_lamp", 1)])),
  ("apts", dict(room=[("mattress", 1), ("tiled_stove", 1), ("table_plastic", 1), ("floor_lamp", 1)], hall=[("laundry", 2), ("bike_rack", 1)])),
  "dingy", "dingy", signs=["neon_red", "street_lamp"])
b("tenement", "laundry tenement", "dingy", "D", "brown", 4, "wall_rust", "wall_rust", "window_bars", "slab", "floor_dirty",
  ("hall", dict(row="shelf_scrap", seat=None, rows=(6,), rows2=(17,), deco=[("laundry", 4), ("trash", 3), ("fire_drum", 1), ("water_barrel", 2)])),
  ("apts", dict(room=[("mattress", 2), ("hotplate", 1), ("tv_static", 1), ("laundry", 1)], hall=[("laundry", 3), ("trash", 2)])),
  "dingy", "dingy", signs=["neon_amber", "fire_drum"])
b("sro_noodle", "noodle rooming house", "dingy", "D", "light_red", 3, "wall_slat", "wall_tile", "window", "floor_wood", "floor_dirty",
  ("hall", dict(row="counter_noodle", seat="stool_plastic", rows=(6,), rows2=(17,), deco=[("noodle_cart", 1), ("neon_red", 2), ("lantern", 3), ("trash", 2)])),
  ("apts", dict(room=[("futon", 1), ("hotplate", 1), ("desk_lamp", 1)], hall=[("trash", 2)])),
  "food", "dingy", signs=["neon_red", "neon_amber"])
b("black_clinic", "back-alley clinic", "dingy", "D", "red", 3, "wall_tile", "wall_tile", "window_bars", "floor_dirty", "floor_dirty",
  ("hall", dict(row="bench_scrap", seat=None, rows=(5,), rows2=(17,), deco=[("test_bench", 2), ("autodoc_stub" if False else "console", 2), ("trash", 3), ("neon_red", 1)])),
  ("apts", dict(room=[("futon", 1), ("test_bench", 1), ("desk_lamp", 1), ("trash", 1)], hall=[("trash", 2)])),
  "med", "med", signs=["neon_red", "neon_red"])
b("pawn_flats", "pawnshop and flats", "dingy", "D", "yellow", 3, "wall_brick", "wall_brick", "window_bars", "slab", "floor_dirty",
  ("hall", dict(row="lightbox", seat=None, rows=(5,), rows2=(17,), deco=[("shelf_scrap", 4), ("crate", 2), ("neon_amber", 2), ("desk_lamp", 2)], back="reception")),
  ("apts", dict(room=[("mattress", 1), ("shelf_scrap", 1), ("desk_lamp", 1), ("crate", 1)], hall=[("trash", 2)])),
  "decor", "dingy", signs=["neon_amber", "neon_amber"])
b("gambling", "gambling den", "dingy", "D", "green", 3, "wall_brick", "wall_concrete", "window_bars", "carpet_red", "floor_dirty",
  ("hall", dict(row="table_card", seat="chair_lounge", rows=(5, 8), rows2=(16, 19), deco=[("neon_green", 3), ("bar_stool", 3), ("lantern", 2), ("tv_static", 1)], back="counter_noodle")),
  ("apts", dict(room=[("table_card", 1), ("chair_lounge", 2), ("desk_lamp", 1)], hall=[("trash", 2)])),
  "drink", "dingy", signs=["neon_green", "neon_red"])
b("sweatshop", "garment sweatshop", "dingy", "D", "brown", 3, "wall_tile", "wall_tile", "window_bars", "slab", "slab",
  ("hall", dict(row="sewing_table", seat="stool_plastic", rows=(5, 8), rows2=(16, 19), deco=[("desk_lamp", 3), ("crate", 3), ("tv_static", 1)])),
  ("hall", dict(row="sewing_table", seat="stool_plastic", rows=(5, 8), rows2=(16, 19), deco=[("desk_lamp", 3), ("bunk_rust", 3)])),
  "decor", "dingy", door="shutter_c", signs=["neon_amber", "fire_drum"])
b("soup_shelter", "soup kitchen shelter", "dingy", "D", "light_gray", 3, "wall_tile", "wall_tile", "window", "floor_dirty", "floor_dirty",
  ("hall", dict(row="table_plastic", seat="stool_plastic", rows=(6,), rows2=(17,), deco=[("counter_noodle", 3), ("water_barrel", 2), ("floor_lamp", 2), ("trash", 2)])),
  ("hall", dict(row="mattress", seat=None, dense=True, rows=(5, 8), rows2=(16, 19), deco=[("water_barrel", 2), ("desk_lamp", 3)])),
  "food", "dingy", signs=["neon_amber", "street_lamp"])
b("half_built", "half-finished tower", "dingy", "D", "dark_gray", 4, "wall_concrete", "wall_concrete", "window", "slab", "slab",
  ("ruin", dict(deco=[("crate", 4), ("pipes", 4), ("fire_drum", 2), ("workbench", 2)])),
  ("ruin", dict(deco=[("crate", 3), ("pipes", 4), ("trash", 3), ("desk_lamp", 2)])),
  "tool", "tool", signs=["fire_drum", "neon_amber"])
b("bazaar", "black-market bazaar", "dingy", "D", "yellow", 3, "wall_rust", "wall_rust", "window", "slab", "floor_dirty",
  ("hall", dict(row="shelf_scrap", seat=None, dense=True, rows=(5, 8), rows2=(16, 19), deco=[("lantern", 5), ("neon_amber", 2), ("crate", 4), ("noodle_cart", 1)])),
  ("hall", dict(row="table_plastic", seat="stool_plastic", rows=(5, 8), rows2=(16, 19), deco=[("lantern", 3), ("crate", 3), ("trash", 2)])),
  "dingy", "dingy", signs=["neon_amber", "neon_red"])
b("rusted_dorm", "rusted dormitory", "dingy", "D", "red", 4, "wall_rust", "wall_rust", "window_bars", "floor_dirty", "floor_dirty",
  ("hall", dict(row="locker_mil", seat=None, rows=(6,), rows2=(17,), deco=[("bench_scrap", 3), ("trash", 3), ("tv_static", 1), ("water_barrel", 1)])),
  ("apts", dict(room=[("bunk_rust", 2), ("locker_mil", 1), ("desk_lamp", 1)], hall=[("trash", 2)])),
  "dingy", "dingy", signs=["neon_red", "fire_drum"])
b("mahjong_flats", "mahjong parlour flats", "dingy", "D", "light_green", 3, "wall_lacquer", "wall_tile", "window", "carpet_red", "floor_dirty",
  ("hall", dict(row="table_card", seat="chair_wicker", rows=(5, 8), rows2=(16, 19), deco=[("red_lantern", 4), ("neon_green", 2), ("vase_red", 2), ("tv_static", 1)])),
  ("apts", dict(room=[("mattress", 1), ("table_card", 1), ("red_lantern", 1), ("tv_static", 1)], hall=[("laundry", 2)])),
  "drink", "dingy", signs=["neon_green", "red_lantern"])
assert len(B) >= 40, len(B)
NEW_T -= {"wall_brick", "wall_lacquer", "carpet_red"}; NEW_F -= {"weapon_rack"}   # already defined in towers/

T["wall_corp"]  # ensure exists

# ------------------------------------------------------------------ output
POOL = list("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@#$%^&*()-=+[]{}|;<>?/~")
def emit(blds=None, outdir="midrise", new_t=None, new_f=None, write_loot=True):
    blds = B if blds is None else blds
    ter_out, om_out, cb_out, mg_out = [], [], [], []
    full_tj = {t["id"]: t for t in gp.terrain_json()}
    for S in blds:
        rng_seed = sum(map(ord, S["id"]))
        levels = []
        for z in range(0, S["stories"] + 1):
            g = build_level(S, z)
            g.rng = random.Random(rng_seed + z)
            levels.append(g)
        cb = []
        for z, g in enumerate(levels):
            oid = f"{S['id']}_z{z}"
            keys = sorted(set(k for row in g.t for k in row))
            ch = {k: POOL[i] for i, k in enumerate(keys)}
            rows = ["".join(ch[k] for k in row) for row in g.t]
            terr = {ch[k]: T[k]["id"] for k in keys}
            loot_tag = S["loot_g"] if z == 0 else S["loot_u"]
            items = []
            if z <= S["stories"]:
                if z == S["stories"]:
                    items = [{"item": "trl_loot_tool", "x": [3, 20], "y": [3, 20], "chance": 25, "repeat": 2}]
                else:
                    items = [{"item": f"trl_loot_{loot_tag}", "x": [3, 20], "y": [3, 20], "chance": 55, "repeat": 6}]
            obj = {"fill_ter": "t_open_air" if z else "t_pavement", "rows": rows, "terrain": terr,
                   "place_furniture": [{"furn": F[k]["id"], "x": x, "y": y} for k, x, y in g.f],
                   "place_items": items}
            assert len(rows) == 24 and all(len(r) == 24 for r in rows), oid
            n_lit = sum(1 for k, _, _ in g.f if F[k]["light"] >= 4)
            assert n_lit >= 3, (oid, n_lit)
            mg_out.append({"type": "mapgen", "om_terrain": [oid], "object": obj})
            roof = z == S["stories"]
            om_out.append({"type": "overmap_terrain", "id": oid, "name": S["name"] + (" roof" if roof else ""),
                           "sym": S["sym"], "color": S["color"],
                           "see_cost": "none" if roof else "full_high",
                           "vision_levels": "roof_or_air" if roof else "large_city_building",
                           "flags": ["SIDEWALK"] if z == 0 else []})
            cb.append({"point": [0, 0, z], "overmap": oid + "_north"})
        cb_out.append({"type": "city_building", "id": S["id"], "locations": ["land"], "overmaps": cb, "city_sizes": [1, -1]})
        S["_g"] = levels
    d = os.path.join(MOD, outdir); os.makedirs(d, exist_ok=True)
    nt = NEW_T if new_t is None else new_t
    nf = NEW_F if new_f is None else new_f
    tj = [t for t in gp.terrain_json() if t["id"] in {T[k]["id"] for k in nt}]
    fj = [f for f in gp.furniture_json() if f["id"] in {F[k]["id"] for k in nf}]
    json.dump(tj, open(os.path.join(d, "terrain.json"), "w"), indent=1)
    json.dump(fj, open(os.path.join(d, "furniture.json"), "w"), indent=1)
    loot = {
      "mil": ["bandages", "flashlight", "rope_30", "knife_combat", "jacket_army", "helmet_army", "boots_combat", "water_clean", "rag", "duct_tape"],
      "android": ["circuit", "processor", "RAM", "cable", "e_scrap", "amplifier", "small_lcd_screen", "light_battery_cell", "scrap", "wrench"],
      "dingy": ["rag", "can_beans", "water_clean", "lighter", "bandages", "tshirt", "jacket_light", "candle", "matches"],
    }
    if write_loot:
        json.dump([{"type": "item_group", "id": f"trl_loot_{k}", "subtype": "distribution", "entries": [{"item": i} for i in v]}
                   for k, v in loot.items()], open(os.path.join(d, "loot.json"), "w"), indent=1)
    json.dump(om_out + cb_out, open(os.path.join(d, "buildings.json"), "w"), indent=1)
    json.dump(mg_out, open(os.path.join(d, "mapgen.json"), "w"), indent=1)
    # region overlay weights
    ro_path = os.path.join(MOD, "region_overlay.json")
    ro = json.load(open(ro_path))
    parks = ro[0]["city"]["parks"]
    w = 1296   # weight gen_city gives each plain mid-rise
    for S in blds: parks[S["id"]] = w
    # generic test blocks: only trl_mid01 stays (the player start / testing building); the rest are replaced by themed buildings
    parks["trl_mid01"] = w * 3
    for i in range(2, 7): parks[f"trl_mid0{i}"] = 0
    json.dump(ro, open(ro_path, "w"), indent=1)
    print(len(blds), "buildings,", len(mg_out), "mapgen levels,", len(NEW_T), "new terrain,", len(NEW_F), "new furniture")

if __name__ == "__main__":
    gp.assign_chars()
    emit()
    pv = os.environ.get("PREVIEW")
    if pv:
        for S in B:
            if pv in S["id"]:
                for z, g in enumerate(S["_g"]):
                    print(f"--- {S['id']} z{z}")
                    inv = {}
                    for k, x, y in g.f: inv[(x, y)] = F[k]["sym"]
                    for y in range(24):
                        print("".join(inv.get((x, y), T[g.t[y][x]]["sym"] or ("." if g.t[y][x] in FLOORS else "?")) if g.t[y][x] not in ("air",) else " " for x in range(24)))
