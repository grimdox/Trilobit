"""Core for gen_towers: catalog extension, multi-cell level grid (Lv), local-frame room builder (LF),
auto-lighting, connectivity check. Reuses the terrain/furniture catalog of gen_places."""
import random, pickle, os
import gen_places as gp

T, F = gp.T, gp.F
ORIG_T, ORIG_F = set(T), set(F)
SOLID, SEAT, SURF = gp.SOLID, gp.SEAT, gp.SURF

# --------------------------------------------------------------------------- vanilla id check
IDS = set()
for _p in ("/tmp/claude-0/ids.pkl",):
    if os.path.exists(_p): IDS = pickle.load(open(_p, "rb"))
ITEMS = set()
if os.path.exists("/tmp/claude-0/itemids.pkl"): ITEMS = pickle.load(open("/tmp/claude-0/itemids.pkl", "rb"))
MISSING = set()
def vet_item(i):
    if not ITEMS or i in ITEMS: return True
    MISSING.add(i); return False
def vet(i):
    """True if the vanilla id exists (or we cannot check)."""
    if not IDS or i in IDS: return True
    MISSING.add(i); return False

# --------------------------------------------------------------------------- terrain additions
def ex(key, tid):
    T[key] = dict(ch="?", id=tid, name=None, desc=None, sym=None, color=None, base=None, extra={}, existing=True)
    vet(tid)
def nter(key, name, desc, sym, color, base, **extra):
    gp.ter(key, "?", name, desc, sym, color, base, **extra)

ex("air", "t_open_air"); ex("roof", "t_flat_roof"); ex("rail", "t_railing")
ex("stair_up", "t_stairs_up"); ex("stair_down", "t_stairs_down")
ex("wdoor", "t_door_c"); ex("ldoor", "t_door_locked"); ex("mdoor", "t_door_metal_c"); ex("mdoor_l", "t_door_metal_locked")
ex("bars", "t_bars"); ex("cell_door", "t_door_bar_locked"); ex("floor_plain", "t_floor")
nter("carpet_red", "crimson carpet", "Deep crimson carpet, thick enough to swallow footsteps.", ".", "red", "t_carpet_red")
nter("carpet_grey", "grey office carpet", "Hard-wearing grey carpet tile.", ".", "dark_gray", "t_carpet_red")
nter("carpet_teal", "teal carpet", "Teal carpet with a faint woven pattern.", ".", "cyan", "t_carpet_red")
nter("marble", "white marble floor", "Polished white marble veined with grey, cold and flawless.", ".", "white", "t_floor")
nter("tile_bath", "bathroom tile", "Small pale-blue tiles, a little damp.", ".", "light_blue", "t_linoleum_white")
nter("floor_clean", "cleanroom floor", "Seamless antistatic floor with a soft white glow from the seams.", ".", "white", "t_linoleum_white", light_emitted=4)
nter("epoxy", "grey epoxy floor", "Industrial epoxy flooring, scuffed and stained.", ".", "dark_gray", "t_floor")
nter("balcony", "balcony deck", "A narrow deck bolted to the wall, with a rail-less edge.", ".", "light_gray", "t_floor")
nter("wall_gilt", "gilded wall panel", "A wall panelled in hammered gold leaf that catches every light.", "#", "yellow", "t_concrete_wall", light_emitted=4)
nter("wall_lacquer", "black lacquer wall", "A glossy black lacquer wall with fine gold inlay.", "#", "dark_gray", "t_concrete_wall")
nter("wall_clean", "cleanroom wall", "A smooth white sealed panel wall, softly lit from within.", "#", "white", "t_concrete_wall", light_emitted=4)
nter("wall_brick", "dark brick wall", "Old dark brick, repointed many times.", "#", "red", "t_concrete_wall")
nter("wall_glass", "glass partition", "A clear glass partition in a thin steel frame.", "\"", "light_cyan", "t_window_no_curtains")

FLOORS = set(gp.FLOORS) | {"carpet_red", "carpet_grey", "carpet_teal", "marble", "tile_bath", "floor_clean", "epoxy",
                          "balcony", "roof", "floor_plain", "stair_up", "stair_down"}
DOORS = {"door_c", "door_o", "screen_c", "screen_o", "shutter_c", "shutter_o", "wdoor", "ldoor", "mdoor", "mdoor_l", "cell_door"}
WALLK = {k for k in T if k.startswith("wall_")} | {"window", "rail", "bars"}
PASS_T = FLOORS | DOORS | {"water_shallow"}
LIGHT_T = {k for k, t in T.items() if t["extra"].get("light_emitted")}

# --------------------------------------------------------------------------- furniture additions
def nfur(key, name, desc, sym, color, light=0, **kw): gp.fur(key, name, desc, sym, color, light, **kw)
def xfur(key, fid, flags=None, passable=False):
    F[key] = dict(id=fid, name=None, desc=None, sym=None, color=None, light=0,
                  kw=dict(flags=flags or SOLID, passable=passable), existing=True)
    vet(fid)
# lighting
nfur("ceil_lamp", "ceiling lamp", "A flat ceiling panel giving an even white light.", "*", "white", 15, flags=SOLID, passable=True)
nfur("strip_light", "strip light", "A long fluorescent strip, buzzing very faintly.", "-", "light_cyan", 12, flags=SOLID, passable=True)
nfur("warm_lamp", "paper ceiling lamp", "A round paper shade with a warm glow.", "*", "yellow", 14, flags=SOLID, passable=True)
nfur("chandelier", "crystal chandelier", "A great tier of cut crystal that scatters the light in sparks.", "*", "white", 30, flags=SOLID, passable=True)
nfur("beacon", "warning beacon", "A rotating beacon throwing red light across the walls.", "!", "light_red", 16, flags=SOLID, passable=True)
nfur("floodlight", "floodlight", "A hard white floodlight on a stand.", "Y", "white", 22, flags=SOLID)
nfur("status_panel", "status panel", "A wall panel of green, amber and red indicator lights.", "=", "light_green", 8, flags=SOLID, passable=True)
# apartments
nfur("bunk_bed", "bunk bed", "A steel bunk bed with thin mattresses.", "B", "light_blue", flags=SOLID, comfort=3)
nfur("silk_bed", "silk canopy bed", "A broad bed under a canopy of pale silk.", "B", "pink", flags=["TRANSPARENT", "MOUNTABLE"], comfort=6)
nfur("shop_counter", "shop counter", "A counter with a payment pad and a smeared glass top.", "T", "light_gray", flags=SURF)
nfur("hot_plate", "hot plate", "A two-ring electric hot plate wired to a car battery.", "h", "red", flags=SURF)
nfur("shoe_rack", "shoe rack", "A low rack of worn shoes by the door.", "=", "brown", flags=SOLID)
nfur("gilt_screen", "gilded folding screen", "A six-panel folding screen of gold leaf painted with pines and mist.", "|", "yellow", flags=SOLID)
nfur("throne", "lacquered throne", "A tall black lacquer chair with gold dragons on the arms.", "H", "yellow", flags=SEAT)
nfur("banquet_table", "banquet table", "A long lacquered table laid with white linen.", "T", "white", flags=SURF)
nfur("statue_gilt", "gilded statue", "A life-size statue of a crane in beaten gold.", "&", "yellow", 6, flags=SOLID)
nfur("koi_lantern", "carved water lantern", "A stone lantern standing in the water, lit from within.", "o", "light_cyan", 12, flags=SOLID)
# police
nfur("cell_bench", "cell bench", "A steel bench bolted to the wall.", "=", "light_gray", flags=SEAT)
nfur("evidence_locker", "evidence locker", "A numbered locker with a tamper seal.", "H", "light_gray", flags=SOLID)
nfur("weapon_rack", "weapon rack", "A locked rack of rifles behind a mesh door.", "H", "dark_gray", flags=SOLID)
nfur("interrogation_table", "interrogation table", "A steel table with ring-bolts set into the top.", "T", "light_gray", flags=SURF)
nfur("bench_waiting", "waiting bench", "A row of joined moulded seats.", "=", "light_blue", flags=SEAT)
nfur("dispatch_desk", "dispatch console", "A curved desk of screens and radio gear.", "C", "light_cyan", 8, flags=SOLID)
# power and telecom
nfur("generator", "turbine generator", "A humming turbine housing with a thick copper bus.", "G", "light_blue", 6, flags=SOLID)
nfur("transformer", "transformer", "A ribbed transformer, humming a note too low to hear.", "M", "light_gray", 4, flags=SOLID)
nfur("capacitor_bank", "capacitor bank", "A cage of capacitors under hazard stickers.", "C", "yellow", 6, flags=SOLID)
nfur("battery_bank", "battery bank", "Tall racks of storage cells with green status lights.", "B", "light_green", 7, flags=SOLID)
nfur("switchgear", "switchgear cabinet", "A grey cabinet full of heavy breakers.", "H", "dark_gray", 5, flags=SOLID)
nfur("cable_trunk", "cable trunk", "A fat trunk of braided cables.", "%", "dark_gray", flags=SOLID, passable=True)
nfur("antenna_mast", "antenna mast", "A lattice mast tipped with a steady red light.", "Y", "light_red", 10, flags=SOLID)
nfur("solar_array", "solar array", "Tilted panels of dark photovoltaic glass.", "=", "blue", flags=SOLID)
nfur("ac_unit", "cooling unit", "A big cooling unit, fans turning slowly.", "A", "light_gray", flags=SOLID)
nfur("water_tank", "water tank", "A rusted roof water tank on stilts.", "O", "brown", flags=SOLID)
# factory
nfur("assembly_line", "assembly line", "A belt of rollers carrying trays of parts past the stations.", "=", "light_gray", 5, flags=SURF)
nfur("robot_arm", "robot arm", "A jointed arm hovering over its work, a small lamp on its wrist.", "R", "yellow", 8, flags=SOLID)
nfur("press", "hydraulic press", "A hydraulic press with a yellow-striped guard.", "P", "yellow", 5, flags=SOLID)
nfur("lathe", "lathe", "A heavy lathe with a pooled coolant tray.", "L", "light_gray", flags=SOLID)
nfur("extruder", "polymer extruder", "A heated barrel feeding a long die, glowing orange at the seams.", "E", "light_red", 9, flags=SOLID)
nfur("polymer_vat", "polymer vat", "A steaming vat of molten polymer.", "O", "light_green", 8, flags=SOLID)
nfur("parts_bin", "parts bin", "A tray of sorted bolts, washers and brackets.", "H", "light_gray", flags=SOLID + ["FLAT_SURF"])
nfur("pallet", "loaded pallet", "A pallet stacked with shrink-wrapped goods.", "X", "brown", flags=SOLID + ["FLAT_SURF"])
nfur("cleanroom_bench", "cleanroom bench", "A sealed bench under a laminar flow hood.", "T", "white", 6, flags=SURF)
nfur("implant_printer", "implant printer", "A sealed chamber building a bio-mechanical limb layer by layer.", "I", "light_cyan", 10, flags=SOLID)
nfur("fume_hood", "fume hood", "A glass-fronted extraction cabinet.", "F", "light_cyan", 6, flags=SOLID)
nfur("tool_cabinet", "tool cabinet", "A rolling cabinet of drawers, every one labelled.", "H", "red", flags=SOLID + ["FLAT_SURF"])
nfur("sheet_roll", "polymer sheet roll", "A giant roll of clear polymer sheet on a spindle.", "O", "light_cyan", flags=SOLID)
# vanilla furniture
xfur("bed", "f_bed", ["TRANSPARENT", "MOUNTABLE"], True)
xfur("dresser", "f_dresser"); xfur("bookcase", "f_bookcase"); xfur("sofa", "f_sofa", SEAT, True)
xfur("armchair", "f_armchair", SEAT, True); xfur("chair", "f_chair", SEAT, True); xfur("table", "f_table", SURF)
xfur("desk", "f_desk", SURF); xfur("fridge", "f_fridge"); xfur("oven", "f_oven"); xfur("sink", "f_sink")
xfur("toilet", "f_toilet", SEAT, True); xfur("bathtub", "f_bathtub"); xfur("locker", "f_locker")
xfur("rack", "f_rack"); xfur("counter", "f_counter", SURF); xfur("cupboard", "f_cupboard")
xfur("filing", "f_filing_cabinet"); xfur("safe", "f_safe_c"); xfur("displaycase", "f_displaycase")
xfur("wardrobe", "f_wardrobe"); xfur("glass_fridge", "f_glass_fridge"); xfur("bench", "f_bench", SEAT, True)
xfur("washer", "f_washer"); xfur("dryer", "f_dryer"); xfur("mannequin", "f_mannequin")
xfur("workbench_v", "f_workbench", SURF); xfur("shower", "f_shower", ["TRANSPARENT"], True)
xfur("piano", "f_piano"); xfur("pool_table", "f_pool_table", SURF); xfur("atm", "f_atm"); xfur("dumpster", "f_dumpster")

def blocks(fkey):
    kw = F[fkey]["kw"]; fl = kw.get("flags", [])
    return not kw.get("passable") and "MOUNTABLE" not in fl and "CAN_SIT" not in fl

def furn_json():
    out = []
    for k in F:
        if k in ORIG_F or F[k].get("existing"): continue
        out.append(k)
    return out

# --------------------------------------------------------------------------- level grid
class Lv:
    def __init__(s, nx, ny, z, st, seed):
        s.nx, s.ny, s.z, s.st = nx, ny, z, st
        s.W, s.H = nx * 24, ny * 24
        s.t = [["air"] * s.W for _ in range(s.H)]
        s.f, s.occ, s.items, s.rooms, s.stairs_tiles = [], set(), [], [], []
        s.rng = random.Random(seed)
        s.nolight = set()
    # ---- terrain
    def inb(s, x, y): return 0 <= x < s.W and 0 <= y < s.H
    def put(s, k, x, y):
        if s.inb(x, y): s.t[y][x] = k
    def fill(s, x0, y0, x1, y1, k):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1): s.put(k, x, y)
    def rect(s, x0, y0, x1, y1, wall, floor):
        """Walls on the perimeter, floor inside. Registers a room."""
        keep = {(x, y): s.t[y][x] for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)
                if (x in (x0, x1) or y in (y0, y1)) and s.inb(x, y) and s.t[y][x] in DOORS}
        s.fill(x0, y0, x1, y1, wall); s.fill(x0 + 1, y0 + 1, x1 - 1, y1 - 1, floor)
        for (x, y), k in keep.items(): s.t[y][x] = k
        s.rooms.append((x0 + 1, y0 + 1, x1 - 1, y1 - 1))
    def hline(s, x0, x1, y, k):
        for x in range(x0, x1 + 1): s.put(k, x, y)
    def vline(s, x, y0, y1, k):
        for y in range(y0, y1 + 1): s.put(k, x, y)
    def door(s, k, x, y): s.put(k, x, y)
    def get(s, x, y): return s.t[y][x] if s.inb(x, y) else "air"
    # ---- furniture
    def free(s, x, y):
        return s.inb(x, y) and s.t[y][x] in FLOORS and (x, y) not in s.occ and s.t[y][x] not in ("stair_up", "stair_down")
    def f_(s, key, x, y, force=False):
        if key not in F: raise KeyError(key)
        if s.free(x, y) or (force and s.inb(x, y) and (x, y) not in s.occ and s.t[y][x] in FLOORS):
            s.f.append((key, x, y)); s.occ.add((x, y)); return True
        return False
    def line(s, key, x0, y0, x1, y1):
        n = max(abs(x1 - x0), abs(y1 - y0))
        for i in range(n + 1):
            s.f_(key, x0 + (x1 - x0) * i // max(n, 1), y0 + (y1 - y0) * i // max(n, 1))
    def scatter(s, keys, x0, y0, x1, y1, n):
        tries = 0; placed = 0
        while placed < n and tries < 300:
            tries += 1
            k = keys if isinstance(keys, str) else s.rng.choice(keys)
            if s.f_(k, s.rng.randint(x0, x1), s.rng.randint(y0, y1)): placed += 1
    def loot(s, group, x0, y0, x1, y1, chance=50, repeat=1):
        s.items.append((group, x0, y0, x1, y1, chance, repeat))
    def clear_doors(s):
        """Remove blocking furniture two tiles deep on both sides of every door so no doorway is walled in."""
        around = set()
        for y in range(s.H):
            for x in range(s.W):
                if s.t[y][x] not in DOORS: continue
                horiz_wall = s.get(x - 1, y) in WALLK and s.get(x + 1, y) in WALLK
                dirs = ((0, 1), (0, -1)) if horiz_wall else ((1, 0), (-1, 0))
                for dx, dy in dirs:
                    for d in (1, 2): around.add((x + dx * d, y + dy * d))
        keep = []
        for k, x, y in s.f:
            if (x, y) in around and blocks(k): s.occ.discard((x, y))
            else: keep.append((k, x, y))
        s.f = keep
    # ---- shell
    def shell(s, wall, floor, ring="walk"):
        for y in range(s.H):
            for x in range(s.W):
                edge = x in (0, s.W - 1) or y in (0, s.H - 1)
                w = x in (1, s.W - 2) or y in (1, s.H - 2)
                if edge: s.t[y][x] = ring if s.z == 0 else "air"
                elif w: s.t[y][x] = wall
                else: s.t[y][x] = floor
        s.rooms.append((2, 2, s.W - 3, s.H - 3))
    def windows(s, period=4, wkey="window", skip=()):
        """Paired windows along the outer walls wherever an interior floor tile sits behind."""
        for y in range(s.H):
            for x in range(s.W):
                on_x = x in (1, s.W - 2); on_y = y in (1, s.H - 2)
                if not (on_x or on_y) or (on_x and on_y): continue
                if not (2 <= x <= s.W - 3 or 2 <= y <= s.H - 3): continue
                if s.t[y][x] not in WALLK or s.t[y][x] in ("window", "wall_glass", "rail", "bars"): continue
                idx = x if on_y else y
                if (x, y) in skip: continue
                if idx % period in (1, 2) and idx > 3 and idx < (s.W if on_y else s.H) - 4:
                    nx_, ny_ = (x, y + 1) if y == 1 else (x, y - 1) if y == s.H - 2 else (x + 1, y) if x == 1 else (x - 1, y)
                    if s.get(nx_, ny_) in FLOORS: s.t[y][x] = wkey
    def exterior_lights(s):
        if s.z != 0: return
        pts = [(0, 0), (s.W - 1, 0), (0, s.H - 1), (s.W - 1, s.H - 1)]
        pts += [(s.W // 2, 0), (s.W // 2, s.H - 1)]
        if s.W > 24: pts += [(s.W // 4, s.H - 1), (3 * s.W // 4, s.H - 1)]
        for (x, y) in pts:
            if s.t[y][x] == "walk" and (x, y) not in s.occ:
                s.f.append(("street_lamp", x, y)); s.occ.add((x, y))
    def sign(s, key, x, y):
        if s.inb(x, y) and (x, y) not in s.occ and s.t[y][x] in ("walk",):
            s.f.append((key, x, y)); s.occ.add((x, y))
    # ---- stairs
    def core(s, x0, y0, door=("s", 2), wall="wall_concrete", floor="floor_corp"):
        """Stair core: 6x4 box, interior 4x2; stairs A=(x0+1,y0+1) B=(x0+4,y0+1). Parity: up at A on even floors, B on odd."""
        s.rect(x0, y0, x0 + 5, y0 + 3, wall, floor)
        side, off = door
        dx, dy = {"s": (off, 3), "n": (off, 0), "w": (0, 1 + (off % 2)), "e": (5, 1 + (off % 2))}[side]
        s.door("wdoor", x0 + dx, y0 + dy)
        A, B = (x0 + 1, y0 + 1), (x0 + 4, y0 + 1)
        z, st = s.z, s.st
        up, dn = (A, B) if z % 2 == 0 else (B, A)
        if z < st: s.put("stair_up", *up)
        if z > 0: s.put("stair_down", *dn)
        for p in (A, B): s.occ.add(p)
        s.stairs_tiles = [A, B]
        s.core_box = (x0, y0)
    # ---- lighting
    def _sources(s):
        src = [(x, y, 7 if F[k]["light"] >= 22 else 5) for k, x, y in s.f if F[k]["light"] >= 8]
        src += [(x, y, 4) for k, x, y in s.f if 0 < F[k]["light"] < 8]
        for y in range(s.H):
            for x in range(s.W):
                if s.t[y][x] in LIGHT_T: src.append((x, y, 3))
        return src
    def _flood(s, x, y, r):
        seen = {(x, y): 0}; fr = [(x, y)]
        while fr:
            nf = []
            for (cx, cy) in fr:
                d = seen[(cx, cy)]
                if d >= r: continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
                    p = (cx + dx, cy + dy)
                    if p in seen or not s.inb(*p): continue
                    k = s.t[p[1]][p[0]]
                    if k in WALLK and k not in ("window", "wall_glass", "bars"): continue
                    seen[p] = d + 1; nf.append(p)
            fr = nf
        return seen
    def autolight(s, lamp="ceil_lamp", hall_lamp="strip_light", skip_keys=("air", "walk", "grass", "roof", "water", "shallow", "pave", "gravel", "balcony")):
        covered = set()
        for (x, y, r) in s._sources():
            covered.update(s._flood(x, y, r).keys())
        n = 0
        for y in range(s.H):
            for x in range(s.W):
                k = s.t[y][x]
                if k in skip_keys or k not in FLOORS or (x, y) in covered or (x, y) in s.nolight: continue
                # find a free tile nearby
                spot = None
                for d in (0, 1, 2):
                    for dy in range(-d, d + 1):
                        for dx in range(-d, d + 1):
                            px, py = x + dx, y + dy
                            if s.free(px, py) and s.t[py][px] not in skip_keys and s.t[py][px] not in DOORS:
                                spot = (px, py); break
                        if spot: break
                    if spot: break
                if not spot: continue
                rn = s._room_at(*spot)
                key = hall_lamp if (rn is None or (rn[2] - rn[0] < 4 or rn[3] - rn[1] < 4)) and hall_lamp else lamp
                if s.t[spot[1]][spot[0]] == "tatami" or s.t[spot[1]][spot[0]] == "floor_wood": key = lamp if lamp != "ceil_lamp" else "warm_lamp"
                s.f.append((key, *spot)); s.occ.add(spot); n += 1
                covered.update(s._flood(spot[0], spot[1], 4 if F[key]["light"] < 20 else 6).keys())
        return n
    def _room_at(s, x, y):
        best = None
        for r in s.rooms:
            if r[0] <= x <= r[2] and r[1] <= y <= r[3]:
                if best is None or (r[2] - r[0]) * (r[3] - r[1]) < (best[2] - best[0]) * (best[3] - best[1]): best = r
        return best
    def fix_pockets(s, start, rounds=8):
        """Remove blocking furniture that walls off small pockets of floor."""
        for _ in range(rounds):
            bad = s.unreachable(start)
            if not bad: return 0
            badset = set(bad); rm = set()
            blockers = {(x, y): k for k, x, y in s.f if blocks(k)}
            for (x, y) in bad:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    p = (x + dx, y + dy)
                    if p in blockers and p not in rm: rm.add(p); break
            if not rm: return len(bad)
            s.f = [(k, x, y) for k, x, y in s.f if (x, y) not in rm]
            for p in rm: s.occ.discard(p)
        return len(s.unreachable(start))
    # ---- check
    def reach(s, start):
        seen = {start}; fr = [start]
        blocked = {(x, y) for k, x, y in s.f if blocks(k)}
        while fr:
            nf = []
            for (cx, cy) in fr:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    p = (cx + dx, cy + dy)
                    if p in seen or not s.inb(*p): continue
                    k = s.t[p[1]][p[0]]
                    if k not in PASS_T or p in blocked: continue
                    seen.add(p); nf.append(p)
            fr = nf
        return seen
    def unreachable(s, start):
        r = s.reach(start)
        bad = []
        for y in range(2, s.H - 2):
            for x in range(2, s.W - 2):
                if s.t[y][x] in FLOORS and (x, y) not in r and (x, y) not in s.occ and s.t[y][x] not in ("stair_up", "stair_down") and s.t[y][x] not in ("grass",):
                    bad.append((x, y))
        return bad

# --------------------------------------------------------------------------- local-frame builder
class LF:
    """Furnish a rectangle in a local frame: u along the back wall (0..w-1), v from the back wall (0) toward the door (h-1).
    door side: 's' means the door is on the south wall, so the back wall is north."""
    def __init__(s, L, x0, y0, x1, y1, side):
        s.L, s.side = L, side
        s.ix0, s.iy0, s.ix1, s.iy1 = x0 + 1, y0 + 1, x1 - 1, y1 - 1
        iw, ih = s.ix1 - s.ix0 + 1, s.iy1 - s.iy0 + 1
        s.w, s.h = (iw, ih) if side in "sn" else (ih, iw)
    def xy(s, u, v):
        if s.side == "s": return s.ix0 + u, s.iy0 + v
        if s.side == "n": return s.ix0 + u, s.iy1 - v
        if s.side == "e": return s.ix0 + v, s.iy0 + u
        return s.ix1 - v, s.iy0 + u
    def ok(s, u, v): return 0 <= u < s.w and 0 <= v < s.h
    def t(s, k, u, v):
        if s.ok(u, v): s.L.put(k, *s.xy(u, v))
    def f(s, key, u, v): return s.ok(u, v) and s.L.f_(key, *s.xy(u, v))
    def fill(s, k, u0, v0, u1, v1):
        for u in range(u0, u1 + 1):
            for v in range(v0, v1 + 1): s.t(k, u, v)
    def furn_row(s, key, u0, u1, v):
        for u in range(u0, u1 + 1): s.f(key, u, v)
    def furn_col(s, key, u, v0, v1):
        for v in range(v0, v1 + 1): s.f(key, u, v)
    def floor(s, k): s.fill(k, 0, 0, s.w - 1, s.h - 1)
    def loot(s, group, chance=50, repeat=1):
        xs = [s.ix0, s.ix1]; ys = [s.iy0, s.iy1]
        s.L.loot(group, s.ix0, s.iy0, s.ix1, s.iy1, chance, repeat)
    def wall_v(s, u, v0, v1, k="wall_concrete"):
        for v in range(v0, v1 + 1): s.t(k, u, v)
    def wall_u(s, v, u0, u1, k="wall_concrete"):
        for u in range(u0, u1 + 1): s.t(k, u, v)
