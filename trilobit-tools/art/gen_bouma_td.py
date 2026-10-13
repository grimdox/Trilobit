#!/usr/bin/env python3
"""Bouma TopDown: the same tileset content as Bouma (every id, item, monster and overlay) redrawn as flat 32x32 top-down tiles.
usage: gen_bouma_td.py <stock cdda dir> <trilobit repo dir>
It reuses gen_bouma's classification and packing and swaps in top-down painters for terrain, furniture and markers.
People and monsters keep their front-view figures (readable at 32x32); items are already flat icons.
Writes gfx/Bouma_TopDown ("Bouma TopDown") and then gen_mokuhanga.py can restyle it into gfx/Mokuhanga_TopDown.
"""
import sys, os, random
import gen_bouma as gb
from iso import Canvas, shade, mix
import extra as ex

T = 32
rgb = gb.rgb
NEON = gb.NEON
INK = (14, 14, 20)

gb.SIZE.update({"flat": (T, T), "half": (T, T), "full": (T, T), "high": (T, T), "chars": (32, 36), "items": (32, 32)})
gb.OFFS.update({"flat": (0, 0), "half": (0, 0), "full": (0, 0), "high": (0, 0), "chars": (0, -2), "items": (0, 0)})
gb.COLS.update({"flat": 24, "half": 24, "full": 24, "high": 24, "chars": 24, "items": 24})
gb.CONF.update({"dir": "gfx/Bouma_TopDown", "name": "Bouma TopDown", "cell": (T, T),
                "info": {"pixelscale": 1, "width": T, "height": T}})


def R(cv, box, fill):
    cv.rect(box, fill)


def frame(cv, box, fill, edge=None, bevel=True):
    x0, y0, x1, y1 = box
    cv.rect(box, edge or shade(fill, 0.55))
    cv.rect((x0 + 1, y0 + 1, x1 - 1, y1 - 1), fill)
    if bevel:
        cv.rect((x0 + 1, y0 + 1, x1 - 1, y0 + 2), shade(fill, 1.25))
        cv.rect((x0 + 1, y1 - 2, x1 - 1, y1 - 1), shade(fill, 0.8))


# ------------------------------------------------------------------ terrain
def p_floor(kind, col, seed):
    cv = Canvas(T, T)
    base = rgb(col)
    ground = {"asphalt": (46, 48, 58), "concrete": (112, 114, 124), "grass": (52, 100, 62), "dirt": (96, 72, 52), "sand": (190, 170, 116),
              "snow": (214, 222, 234), "roof": (70, 62, 68), "carpet": mix(base, (40, 30, 60), 0.55), "wood": (126, 92, 62),
              "tile": mix(base, (190, 196, 206), 0.55), "metal": (96, 102, 114), "water": (34, 78, 130), "deepwater": (22, 48, 100),
              "rock": (90, 90, 98), "generic": mix(base, (50, 50, 60), 0.4), "floor": mix(base, (70, 72, 84), 0.6), "bridge": (70, 66, 62)}[kind]
    cv.rect((0, 0, T, T), ground)
    dk, lt = shade(ground, 0.8), shade(ground, 1.25)
    if kind == "asphalt":
        cv.rect((14, 13, 18, 19), (200, 180, 70))
    elif kind == "concrete":
        cv.line([(0, 16), (T, 16)], dk, 0.7); cv.line([(16, 0), (16, T)], dk, 0.7)
    elif kind in ("tile", "floor"):
        for t in (8, 16, 24):
            cv.line([(t, 0), (t, T)], dk, 0.6); cv.line([(0, t), (T, t)], dk, 0.6)
    elif kind == "wood":
        for t in (8, 16, 24):
            cv.line([(0, t), (T, t)], shade(ground, 0.7), 0.7)
        cv.line([(10, 0), (10, 8)], shade(ground, 0.7), 0.6); cv.line([(22, 8), (22, 16)], shade(ground, 0.7), 0.6)
        cv.line([(6, 16), (6, 24)], shade(ground, 0.7), 0.6); cv.line([(20, 24), (20, T)], shade(ground, 0.7), 0.6)
    elif kind in ("water", "deepwater"):
        for y in (9, 17, 25):
            cv.line([(4, y), (9, y - 2), (14, y), (19, y - 2), (24, y)], lt, 0.7)
    elif kind == "roof":
        for t in (6, 12, 18, 24, 30):
            cv.line([(0, t), (T, t)], lt, 0.6)
    elif kind == "metal":
        for t in (0, 16):
            cv.line([(t, 0), (t, T)], lt, 0.6); cv.line([(0, t), (T, t)], dk, 0.6)
        for x, y in ((4, 4), (28, 4), (4, 28), (28, 28)):
            cv.ellipse((x - 1, y - 1, x + 1, y + 1), lt)
    elif kind == "grass":
        rnd = random.Random(seed)
        for _ in range(14):
            x, y = rnd.randint(2, 29), rnd.randint(2, 29)
            cv.line([(x, y), (x + rnd.choice((-1, 0, 1)), y - 3)], shade(ground, 1.35), 0.6)
    elif kind == "carpet":
        cv.rect((2, 2, 30, 3), shade(ground, 1.3)); cv.rect((2, 29, 30, 30), shade(ground, 0.7))
    elif kind == "bridge":
        for t in (8, 16, 24):
            cv.line([(t, 0), (t, T)], shade(ground, 0.7), 0.8)
    return cv.done(seed, 5 if kind in ("grass", "dirt", "sand", "concrete", "asphalt", "snow", "rock") else 2)


def p_stairs(kind, col, seed):
    cv = Canvas(T, T)
    top = mix(rgb(col), (110, 112, 124), 0.5)
    cv.rect((0, 0, T, T), shade(top, 0.6))
    up = kind == "stairs_up"
    for i in range(5):
        y0 = 2 + i * 6
        cv.rect((1, y0, 31, y0 + 5), shade(top, (0.7 + 0.09 * i) if up else (1.1 - 0.09 * i)))
        cv.rect((1, y0 + 4, 31, y0 + 5), shade(top, 0.45))
    arrow = (255, 200, 60) if up else (90, 200, 255)
    cv.poly([(16, 6), (23, 15), (9, 15)] if up else [(16, 26), (23, 17), (9, 17)], arrow)
    return cv.done(seed, 2)


def p_wall(kind, col, seed):
    cv = Canvas(T, T)
    c = rgb(col)
    if kind == "rock":
        top = mix(c, (110, 108, 116), 0.6)
        cv.rect((0, 0, T, T), shade(top, 0.6))
        rnd = random.Random(seed)
        for _ in range(7):
            x, y = rnd.randint(4, 27), rnd.randint(4, 27)
            r = rnd.randint(4, 7)
            cv.ellipse((x - r, y - r, x + r, y + r), shade(top, 0.75 + rnd.random() * 0.5))
        return cv.done(seed, 6)
    wallc = mix(c, (96, 98, 112), 0.55)
    cv.rect((0, 0, T, T), shade(wallc, 0.45))
    frame(cv, (1, 1, 31, 31), shade(wallc, 1.1))
    if kind == "wall":
        for y in (9, 17, 25):
            cv.line([(2, y), (30, y)], shade(wallc, 0.55), 0.7)
        for y, xs in ((5, (8, 20)), (13, (14, 26)), (21, (8, 20)), (28, (14, 26))):
            for x in xs:
                cv.line([(x, y - 3), (x, y + 3)], shade(wallc, 0.55), 0.6)
    elif kind in ("window", "window_open"):
        glass = (50, 150, 190) if kind == "window" else (16, 18, 26)
        cv.rect((1, 11, 31, 21), shade(wallc, 0.5))
        cv.rect((3, 13, 29, 19), glass)
        if kind == "window":
            cv.rect((4, 14, 14, 16), (170, 220, 245)); cv.rect((15, 13, 17, 19), shade(wallc, 0.6))
    elif kind == "door":
        cv.rect((4, 3, 28, 29), (100, 70, 50)); cv.rect((6, 5, 26, 27), (124, 88, 62))
        cv.rect((6, 15, 26, 17), (100, 70, 50)); cv.ellipse((21, 21, 25, 25), (230, 200, 90))
    elif kind == "door_open":
        cv.rect((4, 3, 28, 29), (14, 14, 20)); cv.rect((4, 3, 7, 29), shade(wallc, 1.2)); cv.rect((7, 6, 10, 26), (124, 88, 62))
    elif kind == "bars":
        cv.rect((3, 3, 29, 29), (10, 10, 14))
        for x in (6, 11, 16, 21, 26):
            cv.rect((x - 1, 3, x + 1, 29), (150, 154, 164))
    return cv.done(seed, 3)


def p_tree(kind, col, seed):
    cv = Canvas(T, T)
    rnd = random.Random(seed)
    cv.ellipse((6, 7, 28, 30), (22, 40, 28))
    for r, shd in ((14, 0.55), (11, 0.8), (7, 1.05)):
        cx, cy = 16 + rnd.randint(-2, 2), 16 + rnd.randint(-2, 2)
        for _ in range(3):
            ox, oy = rnd.randint(-4, 4), rnd.randint(-4, 4)
            cv.ellipse((cx + ox - r * .6, cy + oy - r * .6, cx + ox + r * .6, cy + oy + r * .6), shade((58, 130, 70), shd))
    cv.ellipse((14, 14, 18, 18), (96, 66, 44))
    return cv.done(seed, 4)


def p_bush(kind, col, seed):
    cv = Canvas(T, T)
    c = rgb(col)
    g = mix(c, (60, 140, 70), 0.6)
    rnd = random.Random(seed)
    for _ in range(6):
        x, y, r = rnd.randint(8, 24), rnd.randint(8, 24), rnd.randint(5, 8)
        cv.ellipse((x - r, y - r, x + r, y + r), shade(g, 0.6 + rnd.random() * 0.6))
    return cv.done(seed, 3)


def p_fence(kind, col, seed):
    cv = Canvas(T, T)
    c = mix(rgb(col), (140, 120, 100), 0.5)
    cv.rect((0, 13, T, 15), shade(c, 0.8)); cv.rect((0, 17, T, 19), shade(c, 0.8))
    for x in (2, 15, 28):
        cv.rect((x - 1.5, 11, x + 1.5, 21), shade(c, 1.2))
    return cv.done(seed, 2)


# ------------------------------------------------------------------ furniture
def glow_of(col):
    return NEON.get({"green": "green", "light_green": "green", "magenta": "magenta", "pink": "magenta", "red": "red", "light_red": "red",
                     "yellow": "amber", "brown": "amber"}.get(col, "cyan"))


def p_furn(kind, col, seed):
    cv = Canvas(T, T)
    c = rgb(col)
    rnd = random.Random(seed)
    g = glow_of(col)
    metal = mix(c, (110, 112, 126), 0.55)
    if kind == "table":
        top = mix(c, (130, 108, 90), 0.55)
        frame(cv, (4, 6, 28, 26), top)
    elif kind == "seat":
        top = mix(c, (120, 80, 70), 0.5)
        frame(cv, (8, 9, 24, 27), top); frame(cv, (7, 4, 25, 10), shade(top, 0.8))
    elif kind == "bed":
        frame(cv, (5, 3, 27, 29), (60, 70, 100)); frame(cv, (7, 5, 25, 25), (190, 190 , 215)); cv.rect((9, 6, 23, 11), (240, 240, 250))
    elif kind == "crate":
        top = mix(c, (130, 100, 70), 0.55)
        frame(cv, (4, 4, 28, 28), top); cv.line([(5, 5), (27, 27)], shade(top, 0.5), 0.8); cv.line([(27, 5), (5, 27)], shade(top, 0.5), 0.8)
    elif kind == "plant":
        cv.ellipse((9, 9, 23, 23), (80, 60, 50))
        for i in range(6):
            a = i / 6 * 6.28
            import math
            x, y = 16 + 7 * math.cos(a), 16 + 7 * math.sin(a)
            cv.ellipse((x - 5, y - 5, x + 5, y + 5), shade((70, 150, 80), 0.8 + i * 0.07))
    elif kind == "rubble":
        for _ in range(9):
            x, y = rnd.randint(5, 27), rnd.randint(5, 27)
            cv.ellipse((x - 4, y - 3, x + 4, y + 3), shade(c, 0.6 + rnd.random() * 0.5))
    elif kind == "cabinet":
        frame(cv, (3, 5, 29, 27), metal); cv.line([(16, 6), (16, 26)], shade(metal, 0.4), 0.7)
        cv.rect((13, 15, 15, 18), (220, 220, 230)); cv.rect((17, 15, 19, 18), (220, 220, 230))
    elif kind == "aquarium":
        frame(cv, (3, 6, 29, 26), (46, 44, 60)); cv.rect((5, 8, 27, 24), (90, 190, 225)); cv.rect((5, 8, 27, 11), (150, 230, 250))
        cv.ellipse((9, 14, 15, 18), (250, 150, 60)); cv.poly([(15, 16), (18, 13), (18, 19)], (250, 150, 60)); cv.ellipse((20, 18, 25, 21), (90, 170, 255))
        cv.rect((22, 12, 24, 20), (60, 190, 110))
    elif kind == "machine":
        frame(cv, (4, 4, 28, 28), (36, 38, 52)); cv.rect((7, 7, 25, 17), shade(g, 0.45)); cv.rect((8, 8, 24, 16), g)
        for x in (8, 13, 18):
            cv.rect((x, 20, x + 3, 23), shade(g, 0.7))
    elif kind == "lamp":
        for r, a in ((15, 40), (10, 70), (6, 120)):
            cv.ellipse((16 - r, 16 - r, 16 + r, 16 + r), (NEON["amber"] if col not in ("cyan", "light_cyan", "magenta", "light_blue") else glow_of(col)) + (a,))
        cv.ellipse((13, 13, 19, 19), (255, 245, 200))
    elif kind == "sign":
        gg = NEON["magenta"] if col in ("magenta", "pink", "red", "light_red") else NEON["cyan"]
        frame(cv, (3, 11, 29, 21), shade(gg, 0.35)); cv.rect((5, 13, 27, 19), gg)
    elif kind in ex.KINDS:
        td_extra(cv, kind, c, g, rnd)
    elif kind == "tall_generic":
        frame(cv, (5, 5, 27, 27), metal)
    else:
        frame(cv, (6, 6, 26, 26), metal)
    return "half", cv.done(seed, 3)


def td_extra(cv, kind, c, g, rnd):
    import math
    body = (40, 42, 56)
    if kind in ("charger", "pod", "gurney"):
        frame(cv, (6, 3, 26, 29), (200, 204, 214) if kind == "gurney" else body)
        if kind == "charger":
            cv.poly([(17, 8), (11, 17), (15, 17), (13, 25), (21, 14), (17, 14)], (255, 240, 120))
        elif kind == "pod":
            cv.rect((9, 6, 23, 26), shade(g, 0.5)); cv.rect((11, 8, 21, 24), g)
        else:
            cv.rect((9, 5, 23, 11), (240, 240, 250)); cv.line([(16, 14), (16, 26)], (200, 40, 56), 1.2)
    elif kind == "autodoc":
        frame(cv, (4, 4, 28, 28), (210, 214, 224)); cv.rect((14, 8, 18, 24), (200, 40, 56)); cv.rect((8, 14, 24, 18), (200, 40, 56))
    elif kind in ("pylon", "substation", "transformer", "reactor"):
        frame(cv, (4, 4, 28, 28), body)
        cv.ellipse((8, 8, 24, 24), shade(g, 0.5)); cv.ellipse((11, 11, 21, 21), g); cv.ellipse((14, 14, 18, 18), (240, 255, 255))
    elif kind == "cable_ew":
        cv.rect((0, 13, T, 19), (30, 32, 42)); cv.line([(0, 16), (T, 16)], g, 1.2)
    elif kind == "cable_ns":
        cv.rect((13, 0, 19, T), (30, 32, 42)); cv.line([(16, 0), (16, T)], g, 1.2)
    elif kind == "solar":
        frame(cv, (2, 4, 30, 28), (20, 40, 90))
        for x in (9, 16, 23):
            cv.line([(x, 5), (x, 27)], (90, 130, 200), 0.6)
        for y in (11, 18):
            cv.line([(3, y), (29, y)], (90, 130, 200), 0.6)
    elif kind in ("windturbine", "tidalturbine", "turbine"):
        cv.ellipse((12, 12, 20, 20), (180, 184, 196))
        for k in range(3):
            a = k * 2.094 + 0.5
            cv.poly([(16, 16), (16 + 14 * math.cos(a - 0.15), 16 + 14 * math.sin(a - 0.15)), (16 + 14 * math.cos(a + 0.15), 16 + 14 * math.sin(a + 0.15))], (220, 224, 236))
    elif kind in ("torii",):
        cv.rect((2, 4, 30, 8), (200, 40, 50)); cv.rect((5, 10, 27, 12), (200, 40, 50)); cv.rect((6, 4, 10, 28), (170, 30, 40)); cv.rect((22, 4, 26, 28), (170, 30, 40))
    elif kind in ("shrine", "iconostasis", "altar"):
        frame(cv, (4, 6, 28, 26), (150, 100, 70)); cv.poly([(4, 12), (16, 4), (28, 12)], (90, 70, 60)) if kind == "shrine" else cv.rect((8, 10, 24, 22), (226, 180, 70))
    elif kind in ("statue", "komainu"):
        cv.ellipse((6, 6, 26, 26), (150, 152, 160)); cv.ellipse((10, 10, 22, 22), (190, 192, 200))
    elif kind in ("holo",):
        cv.ellipse((5, 5, 27, 27), shade(g, 0.4)); cv.ellipse((9, 9, 23, 23), g); cv.ellipse((13, 13, 19, 19), (240, 255, 255))
    elif kind in ("candlestand",):
        cv.ellipse((6, 6, 26, 26), (140, 110, 60))
        for x, y in ((11, 11), (21, 11), (16, 16), (11, 21), (21, 21)):
            cv.ellipse((x - 2, y - 2, x + 2, y + 2), (255, 220, 120))
    elif kind in ("bell",):
        cv.ellipse((5, 5, 27, 27), (180, 140, 60)); cv.ellipse((10, 10, 22, 22), (220, 180, 90)); cv.ellipse((14, 14, 18, 18), (90, 70, 40))
    elif kind in ("analoy", "font", "chozuya", "ema", "offering", "shimenawa", "cross"):
        frame(cv, (6, 8, 26, 24), (170, 130, 80))
        if kind in ("font", "chozuya"):
            cv.ellipse((9, 10, 23, 22), (60, 150, 200))
        elif kind == "cross":
            cv.rect((14, 4, 18, 28), (226, 200, 120)); cv.rect((8, 11, 24, 15), (226, 200, 120))
        elif kind == "shimenawa":
            cv.line([(2, 16), (30, 16)], (240, 236, 220), 2.0)
        elif kind == "offering":
            cv.rect((10, 10, 22, 22), (90, 60, 40)); cv.line([(11, 16), (21, 16)], (230, 200, 90), 1)
    else:
        frame(cv, (6, 6, 26, 26), (120, 124, 138))


def p_marker(kind):
    cv = Canvas(T, T)
    box = [(1, 1), (31, 1), (31, 31), (1, 31), (1, 1)]
    if kind == "cursor":
        cv.line(box, (255, 230, 60), 1.6)
    elif kind == "highlight":
        cv.rect((0, 0, T, T), (255, 230, 60, 90)); cv.line(box, (255, 230, 60), 0.9)
    elif kind == "line_target":
        cv.line(box, (255, 70, 70), 1.4); cv.line([(1, 1), (31, 31)], (255, 70, 70), 0.8); cv.line([(31, 1), (1, 31)], (255, 70, 70), 0.8)
    elif kind == "animation_line":
        cv.ellipse((12, 12, 20, 20), (255, 255, 160))
    elif kind.startswith("sees_"):
        colr = {"sees_hostile": (255, 60, 60), "sees_neutral": (255, 220, 60), "sees_friendly": (60, 255, 120), "sees_other": (150, 150, 255)}[kind]
        cv.line(box, colr, 0.9); cv.poly([(16, 3), (21, 10), (11, 10)], colr)
    return cv.done()


def p_unknown():
    cv = Canvas(T, T)
    cv.rect((0, 0, T, T), (60, 20, 80))
    cv.line([(8, 8), (24, 24)], (255, 80, 220), 1.4); cv.line([(24, 8), (8, 24)], (255, 80, 220), 1.4)
    return cv.done()

def p_vpart(kind, col, seed):
    cv = Canvas(T, T)
    c = gb.itm.PAL[col]
    body = mix(c, (90, 94, 110), 0.55)
    if kind == "wheel":
        cv.rect((8, 2, 24, 30), (24, 24, 30)); cv.rect((10, 4, 22, 28), (50, 52, 64))
        for y in (8, 14, 20, 26):
            cv.rect((8, y, 24, y + 1), (20, 20, 26))
    elif kind == "turret":
        frame(cv, (6, 6, 26, 26), shade(body, 0.8)); cv.ellipse((10, 10, 22, 22), shade(body, 1.2)); cv.rect((15, 1, 17, 14), (40, 42, 52))
    elif kind == "window":
        frame(cv, (3, 6, 29, 26), (50, 150, 190)); cv.rect((6, 9, 14, 12), (170, 220, 245))
    elif kind == "lamp":
        cv.ellipse((6, 6, 26, 26), (255, 220, 120, 90)); cv.ellipse((11, 11, 21, 21), (255, 245, 200))
    elif kind == "seat":
        frame(cv, (8, 8, 24, 26), shade(body, 0.9)); frame(cv, (7, 4, 25, 10), shade(body, 0.7))
    elif kind == "engine":
        frame(cv, (4, 4, 28, 28), (90, 94, 110)); cv.rect((7, 7, 13, 13), c); cv.rect((19, 7, 25, 13), c); cv.rect((9, 17, 23, 25), shade(body, 0.7))
    elif kind == "battery":
        frame(cv, (5, 5, 27, 27), (40, 44, 58)); cv.poly([(17, 8), (11, 17), (15, 17), (13, 25), (21, 14), (17, 14)], (255, 240, 120))
    elif kind == "door":
        frame(cv, (3, 8, 29, 24), body); cv.rect((4, 15, 28, 16), shade(body, 0.5)); cv.rect((22, 18, 26, 20), (220, 220, 230))
    elif kind == "storage":
        frame(cv, (4, 4, 28, 28), shade(body, 1.05)); cv.line([(5, 16), (27, 16)], shade(body, 0.5), 0.8); cv.rect((14, 14, 18, 18), (220, 220, 230))
    elif kind == "plate":
        frame(cv, (2, 2, 30, 30), shade(body, 1.1)); cv.ellipse((5, 5, 8, 8), (200, 204, 214)); cv.ellipse((24, 24, 27, 27), (200, 204, 214))
    elif kind == "console":
        frame(cv, (4, 8, 28, 24), (36, 38, 52)); cv.rect((7, 11, 25, 19), (60, 235, 255)); cv.rect((7, 21, 25, 22), (120, 130, 150))
    else:
        frame(cv, (5, 5, 27, 27), body)
    return cv.done(seed, 2)


def p_field(kind, col, seed):
    import math
    cv = Canvas(T, T)
    c = gb.itm.PAL[col]
    rnd = random.Random(seed)
    if kind == "fire":
        for k in range(6):
            x, y = rnd.randint(7, 25), rnd.randint(9, 25)
            h = rnd.randint(5, 10)
            cv.poly([(x - 3.5, y), (x, y - h), (x + 3.5, y)], (255, 110 + rnd.randint(0, 60), 30, 220))
            cv.poly([(x - 2, y), (x, y - h * 0.6), (x + 2, y)], (255, 230, 120, 230))
    elif kind == "smoke":
        for k in range(7):
            x, y = rnd.randint(7, 25), rnd.randint(7, 25)
            cv.ellipse((x - 6, y - 5, x + 6, y + 5), mix(c, (70, 74, 88), 0.6) + (110,))
    elif kind in ("splat", "puddle"):
        base = (150, 20, 30) if kind == "splat" and col in ("red", "light_red") else c if kind == "splat" else (50, 100, 160)
        for k in range(8):
            x, y = rnd.randint(6, 26), rnd.randint(6, 26)
            r = rnd.randint(2, 4)
            cv.ellipse((x - r, y - r, x + r, y + r), shade(base, 0.7 + rnd.random() * 0.4) + (200,))
    elif kind == "gas":
        for k in range(8):
            x, y = rnd.randint(6, 26), rnd.randint(6, 26)
            cv.ellipse((x - 7, y - 7, x + 7, y + 7), c + (70,))
    elif kind == "spark":
        for k in range(4):
            x, y = rnd.randint(7, 25), rnd.randint(7, 25)
            cv.line([(x - 4, y - 3), (x, y + 1), (x - 2, y + 1), (x + 4, y + 5)], NEON["cyan"], 1.2)
    elif kind == "web":
        for a in range(0, 360, 45):
            cv.line([(16, 16), (16 + 14 * math.cos(math.radians(a)), 16 + 14 * math.sin(math.radians(a)))], (225, 228, 236), 0.6)
        for r in (4, 8, 12):
            cv.line([(16 + r * math.cos(math.radians(a)), 16 + r * math.sin(math.radians(a))) for a in range(0, 361, 45)], (225, 228, 236), 0.5)
    elif kind == "glow":
        cv.rect((0, 0, T, T), c + (90,)); cv.line([(1, 1), (31, 1), (31, 31), (1, 31), (1, 1)], c, 0.9)
    else:
        for k in range(4):
            x, y = rnd.randint(8, 24), rnd.randint(8, 24)
            cv.ellipse((x - 6, y - 5, x + 6, y + 5), c + (140,))
    return cv.done(seed, 0)


for n in ("p_floor", "p_stairs", "p_wall", "p_tree", "p_bush", "p_fence", "p_furn", "p_marker", "p_unknown"):
    setattr(gb, n, globals()[n])
gb.itm.p_vpart = p_vpart
gb.itm.p_field = p_field

if __name__ == "__main__":
    gb.main(sys.argv[1], sys.argv[2])
