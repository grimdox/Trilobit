#!/usr/bin/env python3
"""Generate Trilobit places: new terrain, furniture (with light), 30 one-tile locations, loot groups.
usage: gen_places.py <mod dir>"""
import gen_factions as gfac
import gen_androids as gand
import json, os, random, sys
MOD = sys.argv[1]
W = H = 24

# ---------------------------------------------------------------- terrain catalog
# key: (char, id, name, description, symbol, color, base_copy_from or None, extra)
T = {}
def ter(key, ch, name, desc, sym, color, base, **extra):
    T[key] = dict(ch=ch, id=f"t_trl_{key}", name=name, desc=desc, sym=sym, color=color, base=base, extra=extra)

ter("walk", ",", None, None, None, None, "t_sidewalk")           # existing terrain, no new def
T["walk"]["id"] = "t_sidewalk"; T["walk"]["existing"] = True
ter("road", "_", None, None, None, None, "t_pavement"); T["road"]["id"] = "t_pavement"; T["road"]["existing"] = True
ter("water", "w", None, None, None, None, "t_water_dp"); T["water"]["id"] = "t_water_dp"; T["water"]["existing"] = True
ter("shallow", "v", None, None, None, None, "t_water_sh"); T["shallow"]["id"] = "t_water_sh"; T["shallow"]["existing"] = True
ter("grass", "m", None, None, None, None, "t_grass"); T["grass"]["id"] = "t_grass"; T["grass"]["existing"] = True
ter("pave", ":", "wet paving stones", "Dark stone paving, slick with rain.", ".", "dark_gray", "t_sidewalk")
ter("gravel", "a", "raked gravel", "Pale gravel raked into neat lines.", ".", "light_gray", "t_dirt")
ter("floor_corp", "f", "clean white tile", "Seamless pale tile, spotless and faintly blue under the light.", ".", "light_cyan", "t_linoleum_white")
ter("floor_wood", "F", "polished wood floor", "Dark polished boards.", ".", "brown", "t_floor")
ter("tatami", "t", "tatami mat", "A woven rush mat, pale green and soft underfoot.", ".", "light_green", "t_floor")
ter("slab", "k", "bare concrete slab", "A poured concrete floor, scuffed and oil-stained.", ".", "dark_gray", "t_floor")
ter("checker", "c", "checker tile", "Black and white tile in a worn checker pattern.", ".", "white", "t_linoleum_white")
ter("grating", "g", "metal grating", "A steel floor grating over a dark void.", "#", "light_gray", "t_floor")
ter("hazard", "y", "hazard-striped floor", "Painted yellow and black warning stripes.", ".", "yellow", "t_floor")
ter("neon_cyan", "n", "cyan light floor", "Floor panels with a cyan light strip beneath the glass.", ".", "light_cyan", "t_floor", light_emitted=6)
ter("neon_amber", "N", "amber light floor", "Floor panels with a warm amber light strip beneath the glass.", ".", "yellow", "t_floor", light_emitted=6)
ter("neon_pink", "p", "magenta light floor", "Floor panels that glow a deep magenta.", ".", "pink", "t_floor", light_emitted=6)
ter("crystal", "z", "crystal-seamed ground", "Rock veined with glowing blue-violet crystal.", ".", "light_blue", "t_dirt", light_emitted=7)
ter("wall_concrete", "W", "concrete wall", "A bare poured-concrete wall.", "#", "light_gray", "t_concrete_wall")
ter("wall_corp", "X", "white panel wall", "A smooth white composite wall.", "#", "white", "t_concrete_wall")
ter("wall_shoji", "S", "paper screen wall", "A wall of wooden frames and translucent paper, backlit from within.", "#", "light_green", "t_concrete_wall", light_emitted=4)
ter("wall_slat", "Y", "wooden slat wall", "A wall of dark vertical wooden slats.", "#", "brown", "t_concrete_wall")
ter("wall_rust", "R", "rusted sheet wall", "Corrugated sheet metal, patched, painted over and rusting.", "#", "red", "t_concrete_wall")
ter("wall_mural", "M", "mural wall", "A concrete wall painted with a huge faded mural of waves and cranes.", "#", "light_blue", "t_concrete_wall")
ter("wall_pipes", "P", "pipework wall", "A wall crowded with pipes, valves and cable trays.", "#", "dark_gray", "t_concrete_wall")
ter("wall_screens", "E", "screen wall", "A wall of small screens cycling through static and adverts.", "#", "light_cyan", "t_concrete_wall", light_emitted=7)
ter("wall_neon", "B", "neon-banded wall", "A black wall with a glowing neon band running along it.", "#", "pink", "t_concrete_wall", light_emitted=9)
ter("window", "G", "tinted window", "A tall window of teal-tinted glass.", "\"", "cyan", "t_window_no_curtains")
ter("door_c", "d", "sliding door", "A glass sliding door.", "+", "light_cyan", "t_door_glass_c")
ter("door_o", "D", "open sliding door", "A glass sliding door, slid open.", "'", "light_cyan", "t_door_glass_o")
ter("screen_c", "e", "paper screen door", "A sliding screen door of wood and paper.", "+", "light_green", "t_door_c")
ter("screen_o", "E2", "open paper screen door", "A sliding screen door, pushed open.", "'", "light_green", "t_door_o")
ter("shutter_c", "r", "rust shutter", "A rolling shutter patched with sheet metal.", "+", "red", "t_door_c")
ter("shutter_o", "R2", "open rust shutter", "A rolling shutter, rattled up.", "'", "red", "t_door_o")
OPEN = {"door_c": "door_o", "screen_c": "screen_o", "shutter_c": "shutter_o"}
CLOSE = {v: k for k, v in OPEN.items()}
# open variants get internal chars (not used in layouts); closed doors and open variants are paired in JSON
FLOORS = {"pave", "gravel", "floor_corp", "floor_wood", "tatami", "slab", "checker", "grating", "hazard", "neon_cyan",
          "neon_amber", "neon_pink", "crystal", "walk", "grass", "road"}
WALLS = {k for k in T if k.startswith("wall_")}

# ---------------------------------------------------------------- furniture catalog
F = {}
def fur(key, name, desc, sym, color, light=0, **kw):
    F[key] = dict(id=f"f_trl_{key}", name=name, desc=desc, sym=sym, color=color, light=light, kw=kw)
SEAT = ["TRANSPARENT", "MOUNTABLE", "CAN_SIT", "EASY_DECONSTRUCT"]
SURF = ["TRANSPARENT", "FLAT_SURF", "MOUNTABLE"]
SOLID = ["TRANSPARENT"]
# lighting
fur("lantern", "paper lantern", "A round paper lantern glowing a soft amber.", "o", "yellow", 10, flags=SOLID, passable=True)
fur("lantern_stone", "stone lantern", "A squat stone lantern with a warm flame-coloured lamp inside.", "o", "light_gray", 12, flags=SOLID)
fur("floor_lamp", "floor lamp", "A slim floor lamp with a warm shade.", "i", "yellow", 14, flags=SOLID)
fur("street_lamp", "street lamp", "A tall street lamp casting an amber pool of light.", "Y", "yellow", 30, flags=SOLID)
fur("desk_lamp", "desk lamp", "A small adjustable desk lamp.", "i", "white", 9, flags=SOLID, passable=True)
fur("holo_ad", "holographic advert", "A projector throwing a shimmering cyan advert into the air.", "h", "light_cyan", 13, flags=SOLID, passable=True)
fur("crystal_lamp", "crystal lamp", "A blue-violet crystal in a metal cradle, glowing steadily.", "*", "light_blue", 15, flags=SOLID)
fur("neon_pink", "magenta neon sign", "A glass tube sign burning magenta.", "=", "pink", 11, flags=SOLID, passable=True)
fur("neon_cyan", "cyan neon sign", "A glass tube sign burning cyan.", "=", "light_cyan", 11, flags=SOLID, passable=True)
fur("neon_amber", "amber neon sign", "A glass tube sign burning a warm amber.", "=", "yellow", 11, flags=SOLID, passable=True)
fur("neon_violet", "violet neon sign", "A glass tube sign burning violet.", "=", "magenta", 11, flags=SOLID, passable=True)
fur("neon_red", "red neon sign", "A glass tube sign burning red.", "=", "light_red", 11, flags=SOLID, passable=True)
fur("neon_green", "green neon sign", "A glass tube sign burning green.", "=", "light_green", 11, flags=SOLID, passable=True)
fur("aquarium", "wall aquarium", "A glowing tank of slow, pale fish.", "A", "light_cyan", 9, flags=SOLID)
fur("fire_drum", "burning drum", "An oil drum with a fire burning inside.", "0", "light_red", 22, flags=SOLID)
fur("vending", "vending machine", "A brightly lit vending machine.", "V", "light_blue", 9, flags=SOLID)
fur("console", "glowing console", "A console with a panel of lit controls.", "C", "light_cyan", 7, flags=SOLID)
fur("server_rack", "server rack", "A tall rack of blinking servers.", "S", "light_cyan", 6, flags=SOLID)
fur("arcade", "arcade cabinet", "An arcade cabinet blaring colour.", "&", "pink", 8, flags=SOLID)
fur("lightbox", "light box display", "A lit display case for small goods.", "L", "white", 8, flags=SOLID)
# seats
fur("stool_plastic", "plastic stool", "A low plastic stool, the kind used at food stalls.", "s", "light_red", flags=SEAT)
fur("chair_lounge", "lounge chair", "A low, deep lounge chair in dark leatherette.", "h", "magenta", flags=SEAT)
fur("chair_office", "office chair", "A grey swivel chair.", "h", "light_gray", flags=SEAT)
fur("cushion", "floor cushion", "A flat floor cushion, deep red.", "o", "red", flags=SEAT)
fur("bar_stool", "bar stool", "A tall stool with a round metal seat.", "i", "light_gray", flags=SEAT)
fur("bench_scrap", "scrap bench", "A bench of planks on cinder blocks.", "=", "brown", flags=SEAT)
fur("bench_park", "slatted bench", "A slatted bench with iron ends.", "=", "green", flags=SEAT)
fur("chair_wicker", "wicker chair", "A tall wicker-backed chair.", "h", "yellow", flags=SEAT)
# tables and storage
fur("table_low", "low table", "A low lacquered table for sitting on the floor.", "T", "red", flags=SURF)
fur("counter_noodle", "noodle counter", "A narrow counter with a steaming broth pot sunk into it.", "T", "light_red", flags=SURF)
fur("desk_corp", "white desk", "A white desk with built-in screens.", "T", "white", flags=SURF)
fur("table_plastic", "plastic table", "A folding plastic table.", "T", "light_gray", flags=SURF)
fur("shelf_clean", "retail shelf", "A clean white shelf of neatly arranged goods.", "H", "white", flags=SOLID + ["FLAT_SURF"])
fur("shelf_scrap", "scrap shelf", "A welded shelf of salvage.", "H", "brown", flags=SOLID + ["FLAT_SURF"])
fur("cabinet_lacquer", "lacquered cabinet", "A black lacquered cabinet with gold inlay.", "H", "black", flags=SOLID + ["FLAT_SURF"])
fur("crate", "cargo crate", "A stenciled cargo crate.", "X", "brown", flags=SOLID + ["FLAT_SURF"])
fur("workbench", "workbench", "A heavy workbench scarred with burns.", "W", "brown", flags=SURF)
fur("reception", "reception desk", "A long curved reception desk.", "T", "light_cyan", flags=SURF)
# beds
fur("futon", "futon", "A rolled-out futon with a thin blanket.", "b", "light_blue", flags=["TRANSPARENT", "MOUNTABLE"], comfort=3)
fur("capsule", "sleeping capsule", "A stacked sleeping capsule with a curtain and a tiny screen.", "B", "white", flags=SOLID, comfort=4)
# decorative
fur("vase_blue", "blue-glazed vase", "A tall vase with a deep blue glaze.", "v", "blue", flags=SOLID)
fur("vase_white", "white porcelain vase", "A slim white porcelain vase painted with cranes.", "v", "white", flags=SOLID)
fur("vase_red", "red lacquer jar", "A squat jar of red lacquer.", "v", "red", flags=SOLID)
fur("vase_tall", "tall floor vase", "A waist-high ceramic vase holding dry reeds.", "V", "light_green", flags=SOLID)
fur("bonsai", "bonsai tree", "A small twisted tree in a shallow tray.", "&", "green", flags=SOLID)
fur("planter", "bamboo planter", "A stand of bamboo in a long planter.", "#", "light_green", flags=SOLID)
fur("fern", "potted fern", "A fern in a plain white pot.", "&", "light_green", flags=SOLID)
fur("shrine", "small shrine", "A small shrine with offerings and incense.", "A", "light_red", 5, flags=SOLID)
fur("torii", "gate", "A red gate of two pillars and two crossbeams.", "n", "red", flags=SOLID, passable=True)
fur("statue_fox", "stone fox statue", "A stone fox with a red bib.", "f", "light_gray", flags=SOLID)
fur("scroll", "hanging scroll stand", "A stand with a long painted scroll of mountains.", "|", "white", flags=SOLID)
fur("wind_chime", "wind chime", "Glass chimes that clink in the draught.", "!", "light_cyan", flags=SOLID, passable=True)
fur("laundry", "laundry line", "A line of damp clothes hung between balconies.", "~", "light_blue", flags=SOLID, passable=True)
fur("pipes", "tangled pipes", "A knot of pipes and cabling.", "%", "dark_gray", flags=SOLID)
fur("noodle_cart", "noodle cart", "A hand cart with a stove, a hanging lamp and a curtain.", "C", "light_red", 8, flags=SOLID)
fur("bike_rack", "bike rack", "A rack for small hover bikes.", "H", "light_gray", flags=SOLID, passable=True)
fur("charging_pod", "charging pod", "A pod with a cable and a green charge light.", "P", "light_green", 5, flags=SOLID)
fur("ticket_machine", "ticket machine", "A ticket machine with a bright display.", "M", "light_blue", 7, flags=SOLID)
fur("trash", "overflowing bin", "A bin overflowing with cans and wrappers.", "t", "dark_gray", flags=SOLID)
fur("fountain", "stone basin", "A stone basin with a trickle of water.", "U", "light_blue", flags=SOLID)

# ---------------------------------------------------------------- grid helpers
class G:
    def __init__(self, base="pave", edge="walk"):
        self.t = [[base] * W for _ in range(H)]
        for i in range(W):
            for j in (0, H - 1): self.t[j][i] = edge
            for j in (0, H - 1): self.t[i][j] = edge
        self.f = []   # (key, x, y)
        self.occ = set()
        self.items = []
        self.rng = random.Random(0)
    def fill(self, x0, y0, x1, y1, k):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1): self.t[y][x] = k
    def box(self, x0, y0, x1, y1, wall, floor):
        self.fill(x0, y0, x1, y1, wall); self.fill(x0 + 1, y0 + 1, x1 - 1, y1 - 1, floor)
    def hwall(self, x0, x1, y, k):
        for x in range(x0, x1 + 1): self.t[y][x] = k
    def vwall(self, x, y0, y1, k):
        for y in range(y0, y1 + 1): self.t[y][x] = k
    def put(self, k, x, y): self.t[y][x] = k
    def windows(self, x0, x1, y, step=3, skip=()):
        for x in range(x0 + 1, x1, step):
            if x not in skip and self.t[y][x] in WALLS: self.t[y][x] = "window"
    def windows_v(self, x, y0, y1, step=3, skip=()):
        for y in range(y0 + 1, y1, step):
            if y not in skip and self.t[y][x] in WALLS: self.t[y][x] = "window"
    def door(self, k, x, y): self.t[y][x] = k
    def free(self, x, y):
        return 0 < x < W - 1 and 0 < y < H - 1 and self.t[y][x] in FLOORS and (x, y) not in self.occ
    def f_(self, key, x, y):
        if self.free(x, y) or (F[key]["kw"].get("passable") and 0 < x < W - 1 and 0 < y < H - 1 and self.t[y][x] in FLOORS and (x, y) not in self.occ):
            self.f.append((key, x, y)); self.occ.add((x, y)); return True
        return False
    def line(self, key, x0, y0, x1, y1):
        n = max(abs(x1 - x0), abs(y1 - y0))
        for i in range(n + 1):
            x = x0 + (x1 - x0) * i // max(n, 1); y = y0 + (y1 - y0) * i // max(n, 1)
            self.f_(key, x, y)
    def scatter(self, key, x0, y0, x1, y1, n):
        tries = 0; placed = 0
        while placed < n and tries < 200:
            tries += 1
            if self.f_(key, self.rng.randint(x0, x1), self.rng.randint(y0, y1)): placed += 1
    def loot(self, group, x0, y0, x1, y1, chance=60, repeat=1):
        self.items.append((group, x0, y0, x1, y1, chance, repeat))
    def lights(self):
        return sum(1 for k, _, _ in self.f if F[k]["light"] > 0) + sum(
            1 for row in self.t for k in row if T[k]["extra"].get("light_emitted"))

def shell(g, x0, y0, x1, y1, wall, floor, door="door_c", side="s", win=True, dx=None):
    g.box(x0, y0, x1, y1, wall, floor)
    cx = dx if dx is not None else (x0 + x1) // 2
    cy = (y0 + y1) // 2
    if side == "s": g.door(door, cx, y1)
    if side == "n": g.door(door, cx, y0)
    if side == "e": g.door(door, x1, cy)
    if win:
        g.windows(x0, x1, y0); g.windows(x0, x1, y1, skip=(cx,))
        g.windows_v(x0, y0, y1); g.windows_v(x1, y0, y1)
        if side == "e": g.put(door, x1, cy)
    return cx

def neon_row(g, keys, y, x0, x1):
    for i, x in enumerate(range(x0, x1 + 1, 3)): g.f_(keys[i % len(keys)], x, y)

PLACES = []
def ensure_lights(g, n=8):
    cnt = sum(1 for k, _, _ in g.f if F[k]["light"] > 0)
    for pos in [(3,3),(20,3),(3,20),(20,20),(11,3),(11,20),(3,11),(20,11),(6,6),(17,6),(6,17),(17,17),(8,12),(15,12)]:
        if cnt >= n: break
        key = "floor_lamp" if g.t[pos[1]][pos[0]] in ("floor_corp","floor_wood","slab","checker","tatami","grating") else "lantern_stone"
        if g.f_(key, *pos): cnt += 1

def place(pid, name, sym, color, loot_tag):
    def deco(fn):
        def wrapped(g):
            fn(g); ensure_lights(g)
        PLACES.append(dict(id=f"trl_pl_{pid}", name=name, sym=sym, color=color, fn=wrapped, tag=loot_tag)); return fn
    return deco

# ---------------------------------------------------------------- 30 places
@place("noodle_alley", "noodle alley", "n", "light_red", "food")
def _(g):
    g.fill(1, 1, 22, 22, "pave")
    g.fill(1, 1, 3, 22, "wall_concrete"); g.fill(20, 1, 22, 22, "wall_mural")
    for y in range(3, 21, 4):
        g.fill(3, y, 3, y + 1, "floor_wood"); g.fill(20, y + 2, 20, y + 3, "floor_wood")
        g.put("window", 2, y + 2) if y + 2 < 22 else None
    for y in range(3, 21, 4):
        g.f_("noodle_cart", 5, y); g.f_("stool_plastic", 6, y); g.f_("stool_plastic", 6, y + 1)
        g.f_("noodle_cart", 18, y + 2); g.f_("stool_plastic", 17, y + 2); g.f_("stool_plastic", 17, y + 3)
        g.f_("lantern", 5, y - 1); g.f_("lantern", 18, y + 1)
    for y in (2, 10, 18): g.f_("neon_red", 4, y); g.f_("neon_amber", 19, y)
    g.f_("trash", 4, 21); g.f_("vending", 19, 4); g.f_("holo_ad", 11, 12); g.f_("street_lamp", 11, 4); g.f_("street_lamp", 11, 20)
    g.loot("trl_loot_food", 5, 3, 18, 20, 70, 3)
@place("night_market", "night market", "M", "yellow", "food")
def _(g):
    g.fill(1, 1, 22, 22, "pave")
    for y in (4, 10, 16):
        for x in range(4, 20, 5):
            g.f_("table_plastic", x, y); g.f_("lantern", x + 1, y); g.f_("stool_plastic", x, y + 1); g.f_("stool_plastic", x + 1, y + 1)
    neon_row(g, ["neon_pink", "neon_cyan", "neon_amber", "neon_green"], 2, 3, 21)
    g.f_("street_lamp", 2, 12); g.f_("street_lamp", 21, 12); g.f_("holo_ad", 11, 8); g.f_("holo_ad", 11, 20)
    g.line("noodle_cart", 3, 20, 20, 20)
    g.loot("trl_loot_food", 3, 3, 20, 19, 60, 4); g.loot("trl_loot_drink", 3, 3, 20, 19, 40, 2)
@place("arcade_hall", "arcade hall", "A", "pink", "tech")
def _(g):
    shell(g, 2, 3, 21, 20, "wall_neon", "slab", door="door_c")
    for y in (5, 8, 11, 14, 17): g.hwall(3, 20, y, "neon_pink")
    for y in (6, 9, 12): 
        for x in range(4, 20, 2): g.f_("arcade", x, y)
    g.line("counter_noodle", 4, 17, 10, 17); g.f_("bar_stool", 5, 18); g.f_("bar_stool", 7, 18); g.f_("vending", 20, 18)
    g.f_("neon_cyan", 10, 4); g.f_("neon_amber", 16, 4); g.f_("holo_ad", 12, 15)
    g.loot("trl_loot_tech", 4, 15, 20, 19, 50, 2)
@place("tea_house", "tea house", "t", "light_green", "decor")
def _(g):
    shell(g, 3, 4, 20, 19, "wall_shoji", "tatami", door="screen_c", win=False)
    for x in (6, 11, 16): g.f_("table_low", x, 9); g.f_("cushion", x - 1, 9); g.f_("cushion", x + 1, 9)
    for x in (6, 11, 16): g.f_("table_low", x, 14); g.f_("cushion", x, 13); g.f_("cushion", x, 15)
    g.f_("vase_white", 4, 5); g.f_("vase_blue", 19, 5); g.f_("bonsai", 4, 18); g.f_("scroll", 19, 18)
    g.f_("lantern", 8, 6); g.f_("lantern", 14, 6); g.f_("lantern", 8, 17); g.f_("lantern", 14, 17)
    g.f_("cabinet_lacquer", 12, 5); g.f_("wind_chime", 11, 18)
    g.loot("trl_loot_drink", 5, 6, 18, 17, 50, 2)
@place("izakaya", "izakaya", "I", "yellow", "drink")
def _(g):
    shell(g, 2, 4, 21, 19, "wall_slat", "floor_wood")
    g.line("counter_noodle", 5, 8, 18, 8)
    for x in range(5, 19, 2): g.f_("bar_stool", x, 9)
    for x in (5, 10, 15): g.f_("table_low", x, 14); g.f_("cushion", x, 13); g.f_("cushion", x, 15)
    for x in (4, 8, 12, 16, 20): g.f_("lantern", x, 5)
    g.f_("neon_red", 9, 5); g.f_("neon_amber", 14, 5); g.f_("vase_red", 3, 6); g.f_("vase_blue", 20, 6)
    g.f_("shelf_clean", 6, 6); g.f_("shelf_clean", 12, 6); g.f_("fridge" if False else "lightbox", 17, 6)
    g.loot("trl_loot_drink", 5, 5, 19, 7, 70, 3); g.loot("trl_loot_food", 4, 13, 18, 16, 40, 2)
@place("neon_lounge", "neon lounge", "L", "pink", "drink")
def _(g):
    shell(g, 3, 4, 20, 19, "wall_neon", "floor_wood")
    for y in (9, 14, 18): g.hwall(4, 19, y, "neon_cyan")
    g.line("counter_noodle", 5, 6, 14, 6)
    for x in range(5, 15, 2): g.f_("bar_stool", x, 7)
    for (x, y) in ((5, 12), (11, 12), (17, 12), (5, 16), (11, 16), (17, 16)):
        g.f_("table_plastic", x, y); g.f_("chair_lounge", x - 1, y); g.f_("chair_lounge", x + 1, y)
    g.f_("neon_pink", 7, 4); g.f_("neon_violet", 12, 4); g.f_("neon_cyan", 17, 4); g.f_("aquarium", 19, 8)
    g.f_("holo_ad", 11, 10)
    g.loot("trl_loot_drink", 5, 5, 15, 6, 70, 3)
@place("capsule_hotel", "capsule hotel", "H", "white", "tech")
def _(g):
    shell(g, 2, 2, 21, 21, "wall_corp", "floor_corp")
    g.vwall(11, 3, 17, "wall_corp"); g.put("floor_corp", 11, 10)
    for y in range(4, 19, 2):
        g.f_("capsule", 4, y); g.f_("capsule", 6, y); g.f_("capsule", 15, y); g.f_("capsule", 17, y)
    g.line("neon_cyan", 9, 4, 9, 18); g.line("neon_cyan", 13, 4, 13, 18)
    g.f_("reception", 8, 19); g.f_("chair_office", 8, 20); g.f_("vending", 19, 19); g.f_("holo_ad", 12, 19)
    g.loot("trl_loot_tech", 4, 18, 20, 20, 40, 1)
@place("convenience_store", "convenience store", "C", "light_cyan", "food")
def _(g):
    shell(g, 3, 5, 20, 19, "wall_corp", "floor_corp")
    for x in (6, 9, 12, 15): 
        g.line("shelf_clean", x, 8, x, 14)
    g.line("lightbox", 5, 17, 10, 17); g.f_("vending", 18, 7); g.f_("vending", 18, 9); g.f_("neon_cyan", 7, 6); g.f_("neon_green", 14, 6)
    g.f_("holo_ad", 12, 16)
    g.loot("trl_loot_food", 6, 8, 15, 14, 80, 5); g.loot("trl_loot_drink", 17, 7, 19, 12, 60, 2)
@place("electronics_bazaar", "electronics bazaar", "E", "light_cyan", "tech")
def _(g):
    shell(g, 2, 3, 21, 20, "wall_screens", "slab")
    for x in range(4, 20, 4):
        for y in (7, 12):
            g.f_("table_plastic", x, y); g.f_("table_plastic", x + 1, y); g.f_("desk_lamp", x, y - 1); g.f_("console", x + 1, y - 1)
    g.f_("holo_ad", 11, 16); g.f_("neon_cyan", 5, 4); g.f_("neon_amber", 18, 4); g.f_("server_rack", 20, 18)
    g.loot("trl_loot_tech", 3, 6, 20, 13, 80, 6); g.loot("trl_loot_chips", 3, 6, 20, 13, 25, 1)
@place("implant_clinic", "implant clinic", "+", "white", "med")
def _(g):
    shell(g, 3, 3, 20, 20, "wall_corp", "floor_corp")
    g.hwall(4, 19, 12, "wall_corp"); g.put("door_c", 11, 12)
    for x in (5, 8, 11): g.f_("chair_office", x, 16); g.f_("fern", 18, 18)
    g.f_("reception", 14, 17); g.f_("holo_ad", 7, 18); g.f_("neon_cyan", 10, 4); g.f_("neon_green", 16, 4)
    for x in (5, 9, 14, 18): g.f_("desk_corp", x, 6); g.f_("chair_office", x, 7); g.f_("console", x, 5)
    g.loot("trl_loot_med", 4, 5, 19, 10, 60, 4); g.loot("trl_loot_chips", 4, 5, 19, 10, 20, 1)
@place("corp_lobby", "corporate lobby", "L", "white", "decor")
def _(g):
    shell(g, 2, 3, 21, 20, "wall_corp", "checker", door="door_c")
    g.line("reception", 6, 8, 17, 8); g.f_("chair_office", 8, 9); g.f_("chair_office", 12, 9); g.f_("chair_office", 15, 9)
    for x in (4, 19): g.f_("fern", x, 5); g.f_("vase_white", x, 17); g.f_("vase_tall", x, 11)
    for y in (13, 16): g.f_("chair_lounge", 8, y); g.f_("chair_lounge", 15, y)
    g.f_("holo_ad", 11, 14); g.f_("holo_ad", 11, 5); g.f_("neon_cyan", 5, 4); g.f_("neon_cyan", 18, 4); g.f_("floor_lamp", 11, 18)
    g.loot("trl_loot_decor", 4, 5, 19, 18, 40, 2); g.loot("trl_loot_chips", 6, 7, 17, 9, 30, 1)
@place("govt_office", "government office", "G", "light_gray", "tech")
def _(g):
    shell(g, 2, 3, 21, 20, "wall_concrete", "slab")
    for y in (6, 9, 12, 15):
        for x in range(4, 20, 3): g.f_("desk_corp", x, y); g.f_("chair_office", x, y + 1)
    g.line("shelf_clean", 3, 18, 20, 18); g.f_("floor_lamp", 4, 19); g.f_("floor_lamp", 19, 19); g.f_("desk_lamp", 10, 6)
    g.f_("neon_amber", 11, 4); g.f_("vending", 20, 5)
    g.loot("trl_loot_tech", 4, 6, 20, 16, 40, 4)
@place("server_hall", "server hall", "S", "light_cyan", "tech")
def _(g):
    shell(g, 2, 2, 21, 21, "wall_pipes", "grating")
    for x in range(5, 20, 3):
        g.line("server_rack", x, 5, x, 9); g.line("server_rack", x, 13, x, 17)
    g.f_("console", 3, 19); g.f_("console", 20, 19); g.f_("neon_cyan", 11, 3); g.f_("neon_cyan", 11, 20); g.f_("chair_office", 3, 20)
    g.loot("trl_loot_tech", 4, 3, 20, 19, 40, 4); g.loot("trl_loot_chips", 4, 3, 20, 19, 30, 1)
@place("transit_station", "transit station", "T", "light_blue", "tech")
def _(g):
    shell(g, 2, 3, 21, 20, "wall_concrete", "slab")
    g.fill(3, 14, 20, 19, "hazard"); g.fill(3, 16, 20, 18, "grating")
    for x in (5, 9, 13, 17): g.f_("bench_park", x, 11); g.f_("holo_ad", x, 5)
    g.f_("ticket_machine", 4, 6); g.f_("ticket_machine", 6, 6); g.f_("ticket_machine", 18, 6); g.f_("vending", 20, 8)
    g.f_("neon_cyan", 12, 4); g.f_("neon_amber", 8, 4); g.f_("street_lamp", 3, 12); g.f_("street_lamp", 20, 12)
    g.loot("trl_loot_tech", 4, 6, 19, 12, 30, 2)
@place("bike_pad", "hover-bike pad", "B", "yellow", "tool")
def _(g):
    g.fill(1, 1, 22, 22, "pave"); g.fill(3, 3, 20, 20, "hazard"); g.fill(5, 5, 18, 18, "slab")
    for x in (6, 9, 12, 15): g.f_("bike_rack", x, 7); g.f_("bike_rack", x, 16)
    for (x, y) in ((2, 2), (21, 2), (2, 21), (21, 21)): g.f_("street_lamp", x, y)
    g.f_("charging_pod", 11, 11); g.f_("charging_pod", 12, 11); g.f_("neon_green", 11, 3); g.f_("neon_green", 11, 20); g.f_("console", 18, 11)
    g.loot("trl_loot_tool", 5, 5, 18, 18, 30, 3)
@place("slum_block", "slum block", "s", "red", "tool")
def _(g):
    shell(g, 2, 2, 21, 21, "wall_rust", "slab", door="shutter_c")
    g.vwall(8, 3, 20, "wall_rust"); g.vwall(15, 3, 20, "wall_rust")
    for x in (5, 12, 18): g.put("slab", 8 if x == 5 else 15 if x == 12 else 15, 10)
    for y in (6, 12, 17): g.f_("laundry", 4, y); g.f_("laundry", 12, y); g.f_("laundry", 18, y)
    g.f_("fire_drum", 11, 19); g.f_("lantern", 5, 5); g.f_("lantern", 12, 5); g.f_("lantern", 18, 5)
    g.f_("neon_red", 4, 3); g.f_("neon_green", 18, 3); g.f_("bench_scrap", 5, 18); g.f_("shelf_scrap", 18, 18)
    g.loot("trl_loot_tool", 3, 4, 20, 19, 30, 4)
@place("micro_apartment", "micro apartment", "a", "light_gray", "decor")
def _(g):
    shell(g, 5, 6, 18, 17, "wall_corp", "floor_wood")
    g.f_("futon", 7, 8); g.f_("desk_corp", 15, 8); g.f_("chair_office", 15, 9); g.f_("desk_lamp", 16, 8); g.f_("fern", 7, 15)
    g.f_("floor_lamp", 6, 14); g.f_("vase_white", 17, 15); g.f_("holo_ad", 11, 12); g.f_("neon_cyan", 11, 7)
    g.loot("trl_loot_decor", 6, 7, 17, 16, 50, 2)
@place("safehouse", "bare safehouse", "h", "dark_gray", "med")
def _(g):
    shell(g, 4, 5, 19, 18, "wall_concrete", "slab", door="shutter_c", win=False)
    g.f_("futon", 6, 7); g.f_("table_plastic", 14, 8); g.f_("chair_office", 14, 9); g.f_("shelf_scrap", 17, 7); g.f_("crate", 17, 16)
    g.f_("desk_lamp", 14, 7); g.f_("floor_lamp", 6, 16); g.f_("neon_red", 11, 6)
    g.loot("trl_loot_med", 5, 6, 18, 17, 60, 3); g.loot("trl_loot_tool", 5, 6, 18, 17, 40, 2)
@place("shared_dorm", "shared dorm", "d", "light_blue", "decor")
def _(g):
    shell(g, 3, 4, 20, 19, "wall_corp", "floor_wood")
    for y in (7, 11, 15):
        for x in (5, 8, 14, 17): g.f_("futon", x, y)
        g.f_("lantern", 11, y)
    g.f_("table_low", 11, 9); g.f_("table_low", 11, 13); g.f_("floor_lamp", 4, 5); g.f_("floor_lamp", 19, 5); g.f_("neon_cyan", 11, 5)
    g.loot("trl_loot_decor", 5, 6, 18, 17, 40, 3)
@place("rooftop_garden", "rooftop garden", "g", "light_green", "decor")
def _(g):
    g.fill(1, 1, 22, 22, "pave"); g.fill(3, 3, 20, 20, "grass"); g.fill(8, 8, 15, 15, "gravel")
    for x in range(4, 20, 3): g.f_("planter", x, 4); g.f_("planter", x, 19)
    g.f_("bonsai", 10, 10); g.f_("bonsai", 13, 13); g.f_("stone" if False else "statue_fox", 12, 11); g.f_("bench_park", 5, 11); g.f_("bench_park", 18, 11)
    for (x, y) in ((3, 3), (20, 3), (3, 20), (20, 20), (11, 6), (11, 17)): g.f_("lantern_stone", x, y)
    g.f_("shrine", 12, 9); g.f_("neon_green", 2, 12); g.f_("neon_green", 21, 12)
    g.loot("trl_loot_decor", 4, 4, 19, 19, 20, 2)
@place("shrine_courtyard", "shrine courtyard", "S", "light_red", "decor")
def _(g):
    g.fill(1, 1, 22, 22, "gravel"); g.fill(9, 1, 14, 22, "pave")
    g.f_("torii", 11, 20); g.f_("torii", 12, 20); g.f_("torii", 11, 17)
    for y in (6, 10, 14, 18): g.f_("lantern_stone", 8, y); g.f_("lantern_stone", 15, y)
    g.f_("shrine", 11, 3); g.f_("shrine", 12, 3); g.f_("statue_fox", 9, 5); g.f_("statue_fox", 14, 5)
    g.f_("fountain", 5, 12); g.f_("bonsai", 18, 6); g.f_("bonsai", 4, 6); g.f_("wind_chime", 11, 6)
    g.f_("vase_red", 10, 4); g.f_("vase_red", 13, 4); g.f_("neon_red", 3, 21); g.f_("neon_red", 20, 21)
    g.loot("trl_loot_decor", 8, 3, 15, 8, 30, 2)
@place("koi_garden", "koi garden", "k", "light_blue", "decor")
def _(g):
    g.fill(1, 1, 22, 22, "grass"); g.fill(6, 6, 17, 17, "water"); g.fill(8, 8, 15, 15, "water"); g.fill(5, 5, 18, 5, "shallow")
    g.fill(11, 5, 12, 18, "pave")
    for (x, y) in ((4, 4), (19, 4), (4, 19), (19, 19), (11, 3), (11, 20)): g.f_("lantern_stone", x, y)
    for x in (3, 7, 16, 20): g.f_("planter", x, 2); g.f_("planter", x, 21)
    g.f_("bonsai", 4, 12); g.f_("bonsai", 19, 12); g.f_("bench_park", 5, 9); g.f_("vase_blue", 9, 4); g.f_("neon_cyan", 2, 12); g.f_("neon_cyan", 21, 12)
    g.loot("trl_loot_decor", 3, 3, 20, 20, 10, 1)
@place("gallery", "art gallery", "a", "pink", "decor")
def _(g):
    shell(g, 2, 3, 21, 20, "wall_mural", "checker")
    for (x, y) in ((6, 8), (11, 8), (16, 8), (6, 14), (11, 14), (16, 14)): g.f_("lightbox", x, y)
    for x in (4, 8, 13, 19): g.f_("vase_tall", x, 5); g.f_("scroll", x, 18)
    for x in (9, 15): g.f_("vase_blue", x, 11); g.f_("vase_white", x - 5, 11)
    g.f_("bench_park", 11, 11); g.f_("holo_ad", 11, 16); g.f_("neon_violet", 7, 4); g.f_("neon_violet", 16, 4); g.f_("floor_lamp", 11, 19)
    g.loot("trl_loot_decor", 4, 6, 19, 17, 40, 3)
@place("archive_library", "data archive", "l", "light_cyan", "tech")
def _(g):
    shell(g, 3, 3, 20, 20, "wall_corp", "floor_corp")
    for x in range(5, 19, 3): g.line("shelf_clean", x, 5, x, 10); g.line("shelf_clean", x, 13, x, 17)
    g.f_("console", 4, 19); g.f_("console", 19, 19); g.f_("chair_office", 4, 18); g.f_("desk_lamp", 11, 19); g.f_("neon_cyan", 11, 4); g.f_("neon_cyan", 12, 19)
    g.f_("fern", 19, 4)
    g.loot("trl_loot_chips", 4, 5, 19, 17, 40, 3); g.loot("trl_loot_tech", 4, 5, 19, 17, 40, 2)
@place("mech_garage", "mech garage", "G", "yellow", "tool")
def _(g):
    shell(g, 2, 3, 21, 20, "wall_rust", "slab", door="shutter_c", win=False)
    g.fill(6, 8, 17, 16, "hazard"); g.fill(7, 9, 16, 15, "slab")
    for x in (3, 20): g.line("workbench", x, 5, x, 10)
    g.line("shelf_scrap", 4, 19, 19, 19); g.f_("fire_drum", 4, 12); g.f_("fire_drum", 19, 12); g.f_("crate", 5, 17); g.f_("crate", 18, 17)
    g.f_("neon_amber", 8, 4); g.f_("neon_amber", 15, 4); g.f_("floor_lamp", 11, 5); g.f_("pipes", 12, 4)
    g.loot("trl_loot_tool", 4, 5, 19, 19, 60, 6)
@place("scrap_camp", "scrap camp", "c", "red", "tool")
def _(g):
    g.fill(1, 1, 22, 22, "slab"); g.fill(2, 2, 21, 2, "wall_rust"); g.fill(2, 21, 21, 21, "wall_rust"); g.fill(2, 2, 2, 21, "wall_rust"); g.fill(21, 2, 21, 21, "wall_rust")
    g.put("shutter_c", 11, 21); g.put("slab", 21, 11)
    for (x, y) in ((6, 6), (16, 6), (6, 16), (16, 16), (11, 11)): g.f_("fire_drum", x, y)
    for x in (5, 8, 14, 17): g.f_("bench_scrap", x, 8); g.f_("bench_scrap", x, 14)
    g.f_("shelf_scrap", 4, 4); g.f_("shelf_scrap", 19, 4); g.f_("crate", 4, 19); g.f_("crate", 19, 19); g.f_("trash", 11, 19)
    g.f_("lantern", 11, 4); g.f_("neon_red", 8, 3); g.f_("neon_green", 15, 3)
    g.loot("trl_loot_tool", 3, 3, 20, 20, 25, 6)
@place("crystal_works", "crystal works", "*", "light_blue", "chips")
def _(g):
    g.fill(1, 1, 22, 22, "slab"); g.fill(8, 8, 15, 15, "water")
    for y in range(4, 20):
        for x in range(4, 20):
            if (x + y) % 5 == 0 and not (8 <= x <= 15 and 8 <= y <= 15): g.put("crystal", x, y)
    for (x, y) in ((5, 5), (18, 5), (5, 18), (18, 18), (11, 3), (11, 20), (3, 11), (20, 11)): g.f_("crystal_lamp", x, y)
    g.line("pipes", 2, 2, 2, 21); g.line("pipes", 21, 2, 21, 21)
    g.f_("console", 8, 3); g.f_("console", 15, 3); g.f_("charging_pod", 3, 20); g.f_("charging_pod", 20, 20); g.f_("neon_cyan", 6, 2); g.f_("neon_cyan", 17, 2)
    g.loot("trl_loot_chips", 4, 4, 19, 19, 20, 2); g.loot("trl_loot_tool", 3, 3, 20, 20, 20, 2)
@place("canal_dock", "canal dock", "d", "light_blue", "tool")
def _(g):
    g.fill(1, 1, 22, 22, "pave"); g.fill(1, 8, 22, 15, "water"); g.fill(1, 8, 22, 8, "shallow"); g.fill(1, 15, 22, 15, "shallow")
    g.fill(10, 8, 13, 15, "pave")
    for x in (3, 7, 16, 20): g.f_("crate", x, 5); g.f_("bollard" if False else "crate", x, 18)
    for x in (2, 8, 14, 21): g.f_("street_lamp", x, 7); g.f_("street_lamp", x, 16)
    g.f_("noodle_cart", 5, 20); g.f_("stool_plastic", 6, 20); g.f_("lantern", 5, 19); g.f_("neon_cyan", 3, 2); g.f_("neon_amber", 20, 2)
    g.loot("trl_loot_tool", 2, 3, 21, 6, 40, 3); g.loot("trl_loot_food", 2, 17, 21, 20, 30, 2)
@place("cargo_warehouse", "cargo warehouse", "W", "brown", "tool")
def _(g):
    shell(g, 2, 3, 21, 20, "wall_pipes", "slab", door="shutter_c", win=False)
    for x in range(4, 20, 5):
        g.line("crate", x, 6, x + 2, 6); g.line("crate", x, 8, x + 2, 8); g.line("crate", x, 14, x + 2, 14); g.line("crate", x, 16, x + 2, 16)
    g.line("hazard", 4, 11, 19, 11) if False else None
    g.f_("floor_lamp", 3, 4); g.f_("floor_lamp", 20, 4); g.f_("floor_lamp", 3, 19); g.f_("floor_lamp", 20, 19)
    g.f_("neon_amber", 11, 4); g.f_("console", 11, 19)
    g.loot("trl_loot_tool", 3, 5, 20, 18, 50, 8)
@place("dojo_hall", "dojo hall", "D", "brown", "decor")
def _(g):
    shell(g, 3, 4, 20, 19, "wall_slat", "floor_wood", door="screen_c", win=False)
    g.fill(6, 7, 17, 16, "tatami")
    for x in (4, 19): g.f_("vase_tall", x, 5); g.f_("vase_blue", x, 18)
    g.f_("shrine", 11, 5); g.f_("scroll", 8, 5); g.f_("scroll", 14, 5); g.f_("cabinet_lacquer", 19, 11)
    for x in (5, 8, 14, 17): g.f_("lantern", x, 6)
    g.f_("lantern_stone", 5, 17); g.f_("lantern_stone", 18, 17); g.f_("bonsai", 4, 11)
    g.loot("trl_loot_decor", 5, 6, 18, 17, 30, 2)

# ---------------------------------------------------------------- output
def terrain_json():
    out = []; done = set()
    for k, t in T.items():
        if t.get("existing"): continue
        d = {"type": "terrain", "id": t["id"], "copy-from": t["base"], "name": t["name"], "description": t["desc"],
             "symbol": t["sym"], "color": t["color"]}
        if k in OPEN:
            d["open"] = T[OPEN[k]]["id"]
        if k in CLOSE:
            d["close"] = T[CLOSE[k]]["id"]
        d.update({a: b for a, b in t["extra"].items()})
        out.append(d)
    return out
def furniture_json():
    out = []
    for k, f in F.items():
        d = {"type": "furniture", "id": f["id"], "name": f["name"], "description": f["desc"], "symbol": f["sym"], "color": f["color"],
             "move_cost_mod": -1 if not f["kw"].get("passable") else 0, "coverage": 0 if f["kw"].get("passable") else 30,
             "required_str": -1, "flags": f["kw"].get("flags", ["TRANSPARENT"]),
             "bash": {"str_min": 6, "str_max": 30, "sound": "smash!", "sound_fail": "whump."}}
        if f["kw"].get("flags") and "CAN_SIT" in f["kw"]["flags"]:
            d["move_cost_mod"] = 1; d["coverage"] = 40; d["comfort"] = 1; d["required_str"] = 4
        if f["kw"].get("comfort"): d["comfort"] = f["kw"]["comfort"]
        if f["light"]: d["light_emitted"] = f["light"]
        out.append(d)
    return out
CHAR = {}
used = set()
def assign_chars():
    # terrain chars (closed doors etc.), open variants get spare chars
    pool = [c for c in "0123456789@#$%^&*()-=+[]{}|;<>?/~`abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"]
    for k, t in T.items():
        c = t["ch"]
        if len(c) == 1 and c not in used and c not in " '\"\\": used.add(c); CHAR[k] = c
    for k in T:
        if k not in CHAR:
            c = next(p for p in pool if p not in used); used.add(c); CHAR[k] = c
def mapgen_json():
    out = []
    for p in PLACES:
        g = G(); p["fn"](g)
        assert g.lights() >= 3, (p["id"], g.lights())
        rows = ["".join(CHAR[k] for k in row) for row in g.t]
        terr = {CHAR[k]: T[k]["id"] for k in set(k for row in g.t for k in row)}
        obj = {"fill_ter": "t_pavement", "rows": rows, "terrain": terr,
               "place_furniture": [{"furn": F[k]["id"], "x": x, "y": y} for k, x, y in g.f],
               "place_items": [{"item": gr, "x": [x0, x1], "y": [y0, y1], "chance": ch, "repeat": rep} for gr, x0, y0, x1, y1, ch, rep in g.items]}
        bn = gfac.bar_npcs(p["id"])
        if bn: obj["place_npcs"] = [{"class": c, "x": x, "y": y} for c, x, y in bn]
        an = gand.android_npcs(p["id"])
        if an:
            taken = {(x, y) for _, x, y in bn} | {(x, y) for _, x, y in [(k, fx, fy) for k, fx, fy in g.f]}
            cx = cy = 11
            cells = sorted(((x, y) for y in range(2, 22) for x in range(2, 22)), key=lambda c: (c[0] - cx) ** 2 + (c[1] - cy) ** 2)
            ok = [c for c in cells if g.t[c[1]][c[0]] in FLOORS and c not in taken]
            indoor = [c for c in ok if g.t[c[1]][c[0]] not in ("walk", "road", "grass", "pave", "gravel")]
            pool = indoor if len(indoor) >= len(an) else ok
            obj.setdefault("place_npcs", []).extend({"class": c, "x": xy[0], "y": xy[1]} for c, xy in zip(an, pool))
            taken |= set(pool[:len(an)])
        if p["id"] == "trl_pl_mech_garage":
            used = {(a["x"], a["y"]) for a in obj.get("place_npcs", [])} | {(fx, fy) for _, fx, fy in g.f}
            cand = [(x, y) for y in range(3, 21) for x in range(3, 21) if g.t[y][x] in FLOORS and (x, y) not in used]
            cand.sort(key=lambda c: (c[0] - 16) ** 2 + (c[1] - 11) ** 2)
            obj["place_monster"] = [{"monster": "mon_trl_kumo", "x": cand[0][0], "y": cand[0][1]}]
        if p["id"] in gand.ATM_PLACES:
            taken2 = {(x, y) for _, x, y in bn} | {(fx, fy) for _, fx, fy in g.f} | {(a["x"], a["y"]) for a in obj.get("place_npcs", [])}
            cand = [(x, y) for y in range(2, 22) for x in range(2, 22) if g.t[y][x] in FLOORS and g.t[y][x] not in ("walk", "road", "grass", "pave", "gravel") and (x, y) not in taken2]
            if cand:
                obj["place_furniture"].append({"furn": "f_trl_atm", "x": cand[len(cand) // 3][0], "y": cand[len(cand) // 3][1]})
        out.append({"type": "mapgen", "om_terrain": [p["id"]], "object": obj})
        p["lights"] = g.lights(); p["rows"] = rows; p["nf"] = len(g.f)
    return out
LOOT = {
 "food": ["sake_filtered", "tea_green", "rice_cooked", "sushi_fishroll", "noodles_fast", "cola", "energy_drink", "candy"],
 "drink": ["sake_filtered", "beer", "cola", "tea_green", "energy_drink", "water_clean", "cigar", "lighter"],
 "tech": ["circuit", "processor", "RAM", "cable", "e_scrap", "amplifier", "small_lcd_screen", "light_battery_cell"],
 "med": ["bandages", "aspirin", "vitamins", "water_clean"],
 "tool": ["wrench", "screwdriver", "hammer", "welder", "crowbar", "duct_tape", "scrap", "pipe", "sheet_metal", "flashlight"],
 "decor": ["kimono", "umbrella", "candle", "tshirt", "jacket_light", "cash_card", "tea_green"],
}
def loot_json():
    out = []
    for tag, ids in LOOT.items():
        out.append({"type": "item_group", "id": f"trl_loot_{tag}", "subtype": "distribution", "entries": [{"item": i} for i in ids]})
    return out
def city_json():
    om, cb, mg = [], [], []
    for p in PLACES:
        om.append({"type": "overmap_terrain", "id": p["id"], "name": p["name"], "sym": p["sym"], "color": p["color"],
                   "see_cost": "full_high", "vision_levels": "large_city_building", "flags": ["SIDEWALK"] if False else []})
        cb.append({"type": "city_building", "id": p["id"], "locations": ["land"], "overmaps": [{"point": [0, 0, 0], "overmap": p["id"] + "_north"}],
                   "city_sizes": [1, -1]})
    return om, cb

if __name__ == "__main__":
    assign_chars()
    os.makedirs(os.path.join(MOD, "places"), exist_ok=True)
    json.dump(terrain_json(), open(os.path.join(MOD, "places/terrain.json"), "w"), indent=1)
    json.dump(furniture_json(), open(os.path.join(MOD, "places/furniture.json"), "w"), indent=1)
    json.dump(loot_json(), open(os.path.join(MOD, "places/loot.json"), "w"), indent=1)
    mg = mapgen_json()
    json.dump(mg, open(os.path.join(MOD, "places/mapgen.json"), "w"), indent=1)
    om, cb = city_json()
    json.dump(om + cb, open(os.path.join(MOD, "places/buildings.json"), "w"), indent=1)
    # region overlay weights
    ro_path = os.path.join(MOD, "region_overlay.json")
    ro = json.load(open(ro_path))
    shops = ro[0]["city"]["shops"]
    for p in PLACES: shops[p["id"]] = 300
    json.dump(ro, open(ro_path, "w"), indent=1)
    print(len(PLACES), "places;", len(F), "furniture;", len(T), "terrain keys")
    for p in PLACES: print(f'{p["id"]:28} lights={p["lights"]:3} furn={p["nf"]:3}')
    if os.environ.get("PREVIEW"):
        for p in PLACES:
            if p["id"].endswith(os.environ["PREVIEW"]): print("\n".join(p["rows"]))
