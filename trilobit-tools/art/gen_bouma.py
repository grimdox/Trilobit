#!/usr/bin/env python3
"""Bouma: the Trilobit isometric tileset, drawn entirely from code (Milestone 19, tier 1).
usage: gen_bouma.py <stock cdda dir> <trilobit repo dir>
Reads every terrain, furniture and monster definition (stock plus the mod), sorts each into a drawn kind by flags,
id and name, paints one sprite per kind and colour, packs the sheets and writes gfx/Bouma/.
Only the sprite SIZES follow the Ultica_iso convention (so tile geometry is compatible); no Ultica art is used.
"""
import json, os, re, sys, math, random
from PIL import Image, ImageDraw, ImageFont
sys.path.insert(0, os.path.dirname(__file__))
import defs
import items as itm
import extra as ex
from iso import Canvas, box, face, sides, diamond, shade, mix, W, DH

PAL = {
    "black": (30, 30, 40), "red": (150, 52, 62), "green": (62, 124, 82), "brown": (122, 90, 62), "blue": (62, 84, 150),
    "magenta": (150, 62, 150), "cyan": (52, 140, 150), "light_gray": (150, 152, 162), "dark_gray": (84, 86, 98),
    "light_red": (222, 92, 102), "light_green": (112, 200, 122), "yellow": (222, 200, 82), "light_blue": (104, 142, 232),
    "pink": (232, 134, 182), "light_cyan": (122, 220, 232), "white": (226, 230, 238),
}
NEON = {"cyan": (60, 235, 255), "magenta": (255, 70, 200), "green": (90, 255, 140), "amber": (255, 170, 50), "red": (255, 70, 80)}
SHEETS = ["flat", "half", "full", "high", "chars", "items"]
SIZE = {"flat": (48, 36), "half": (48, 48), "full": (48, 72), "high": (48, 96), "chars": (32, 36), "items": (32, 32)}
OFFS = {"flat": (0, -12), "half": (0, -24), "full": (0, -48), "high": (0, -72), "chars": (8, -19), "items": (8, -15)}
COLS = {"flat": 16, "half": 16, "full": 16, "high": 16, "chars": 24, "items": 24}
Hh = {k: v[1] for k, v in SIZE.items()}


def rgb(cname):
    return PAL.get(cname, PAL["light_gray"])


def has(s, *words):
    return any(w in s for w in words)


# ---------------------------------------------------------------- painters.  each returns a PIL image of the sheet's sprite size
def p_floor(kind, col, seed):
    H = 36
    cv = Canvas(48, H)
    base = rgb(col)
    ground = {"asphalt": (46, 48, 58), "concrete": (112, 114, 124), "grass": (52, 100, 62), "dirt": (96, 72, 52), "sand": (190, 170, 116),
              "snow": (214, 222, 234), "roof": (70, 62, 68), "carpet": mix(base, (40, 30, 60), 0.55), "wood": (126, 92, 62),
              "tile": mix(base, (190, 196, 206), 0.55), "metal": (96, 102, 114), "water": (34, 78, 130), "deepwater": (22, 48, 100),
              "rock": (90, 90, 98), "generic": mix(base, (50, 50, 60), 0.4), "floor": mix(base, (70, 72, 84), 0.6), "bridge": (70, 66, 62)}[kind]
    d = diamond(H, 1.0)
    cv.poly(d, ground)
    L, T, R, B = d
    if kind == "asphalt":
        cv.line([(24 - 10, 18), (24 + 10, 18)], (200, 180, 70), 0.6)
    elif kind == "concrete":
        cv.line([L, R], shade(ground, 0.85), 0.5)
        cv.line([T, B], shade(ground, 0.85), 0.5)
    elif kind in ("tile", "floor"):
        for t in (0.33, 0.66):
            cv.line([(L[0] + (T[0] - L[0]) * t, L[1] + (T[1] - L[1]) * t), (B[0] + (R[0] - B[0]) * t, B[1] + (R[1] - B[1]) * t)], shade(ground, 0.8), 0.5)
            cv.line([(L[0] + (B[0] - L[0]) * t, L[1] + (B[1] - L[1]) * t), (T[0] + (R[0] - T[0]) * t, T[1] + (R[1] - T[1]) * t)], shade(ground, 0.8), 0.5)
    elif kind == "wood":
        for t in (0.25, 0.5, 0.75):
            cv.line([(L[0] + (T[0] - L[0]) * t, L[1] + (T[1] - L[1]) * t), (B[0] + (R[0] - B[0]) * t, B[1] + (R[1] - B[1]) * t)], shade(ground, 0.72), 0.6)
    elif kind in ("water", "deepwater"):
        for y in (14, 20, 26):
            cv.line([(16, y), (22, y - 1), (28, y)], shade(ground, 1.6), 0.6)
    elif kind == "roof":
        for t in (0.25, 0.5, 0.75):
            cv.line([(L[0] + (B[0] - L[0]) * t, L[1] + (B[1] - L[1]) * t), (T[0] + (R[0] - T[0]) * t, T[1] + (R[1] - T[1]) * t)], shade(ground, 1.3), 0.5)
    elif kind == "metal":
        cv.line([(L[0] + 8, L[1]), (R[0] - 8, R[1])], shade(ground, 1.3), 0.5)
        cv.line([T, B], shade(ground, 0.8), 0.5)
    cv.line(d + [d[0]], shade(ground, 0.8), 0.5)
    return cv.done(seed, 5 if kind in ("grass", "dirt", "sand", "concrete", "asphalt", "snow", "rock") else 2)


def p_stairs(kind, col, seed):
    H = 72
    cv = Canvas(48, H)
    base = rgb(col)
    top = mix(base, (110, 112, 124), 0.5)
    d = diamond(H, 1.0)
    cv.poly(d, shade(top, 0.7))
    for i in range(4):
        up = kind == "stairs_up"
        h = (i + 1) * 5 if up else (4 - i) * 5
        f = 0.9
        # steps run from the left corner to the top corner
        x0 = 4 + i * 8
        ext = 0
        b = [(x0, H - 12), (x0 + 8, H - 16), (x0 + 16, H - 12), (x0 + 8, H - 8)]
        cv.poly([(p[0], p[1] - h) for p in b], shade(top, 1.0 - 0.05 * i))
        cv.poly([b[0], b[3], (b[3][0], b[3][1] - h), (b[0][0], b[0][1] - h)], shade(top, 0.55))
        cv.poly([b[3], b[2], (b[2][0], b[2][1] - h), (b[3][0], b[3][1] - h)], shade(top, 0.75))
    arrow = (255, 200, 60) if kind == "stairs_up" else (90, 200, 255)
    cv.poly([(24, H - 30), (30, H - 24), (18, H - 24)] if kind == "stairs_up" else [(24, H - 20), (30, H - 26), (18, H - 26)], arrow)
    return cv.done(seed, 2)


def wall_faces(cv, H, h, f=1.0):
    return sides(H, h, f)


def p_wall(kind, col, seed):
    """kind: wall, window, window_open, door, door_open, rock, tree, bars (all on the 'full' sheet except tree)."""
    H = 72
    cv = Canvas(48, H)
    c = rgb(col)
    if kind == "rock":
        top = mix(c, (110, 108, 116), 0.6)
        box(cv, H, 40, 1.0, top)
        return cv.done(seed, 6)
    wallc = mix(c, (96, 98, 112), 0.55)
    # slab floor beneath so that a wall always has a footprint
    cv.poly(diamond(H, 1.0), shade(wallc, 0.45))
    b, t = box(cv, H, 48, 1.0, shade(wallc, 1.15), edge=True)
    L, R = sides(H, 48, 1.0)
    if kind == "wall":
        for v in (0.25, 0.5, 0.75):
            face(cv, L, 0, 1, v, v + 0.012, shade(wallc, 0.5))
            face(cv, R, 0, 1, v, v + 0.012, shade(wallc, 0.62))
    elif kind in ("window", "window_open"):
        glass = (50, 150, 190) if kind == "window" else (16, 18, 26)
        for P, k in ((L, 0.55), (R, 0.72)):
            face(cv, P, 0.18, 0.82, 0.30, 0.78, shade(wallc, k * 0.6))
            face(cv, P, 0.24, 0.76, 0.36, 0.72, shade(glass, k + 0.2))
            if kind == "window":
                face(cv, P, 0.24, 0.50, 0.58, 0.72, shade((170, 220, 245), k + 0.15))
        if kind == "window":
            face(cv, R, 0.48, 0.52, 0.36, 0.72, shade(wallc, 0.6))
    elif kind == "door":
        for P, k in ((L, 0.55), (R, 0.72)):
            face(cv, P, 0.25, 0.75, 0.0, 0.78, shade((100, 70, 50), k + 0.1))
            face(cv, P, 0.30, 0.70, 0.05, 0.72, shade((124, 88, 62), k + 0.1))
            face(cv, P, 0.62, 0.67, 0.34, 0.40, (230, 200, 90))
    elif kind == "door_open":
        for P, k in ((L, 0.55), (R, 0.72)):
            face(cv, P, 0.22, 0.78, 0.0, 0.8, (14, 14, 20))
            face(cv, P, 0.22, 0.28, 0.0, 0.8, shade(wallc, k + 0.2))
    elif kind == "bars":
        for P, k in ((L, 0.55), (R, 0.72)):
            face(cv, P, 0.1, 0.9, 0.25, 0.8, (10, 10, 14))
            for i in range(5):
                u = 0.14 + i * 0.18
                face(cv, P, u, u + 0.04, 0.22, 0.82, shade((150, 154, 164), k + 0.1))
    return cv.done(seed, 3)


def p_tree(kind, col, seed):
    H = 96
    cv = Canvas(48, H)
    g = rgb(col) if col in ("green", "light_green") else (52, 110, 66)
    cv.poly(diamond(H, 1.0), (40, 70, 48, 120))
    box(cv, H, 30, 0.14, (88, 62, 44), edge=False)
    rnd = random.Random(seed)
    for i in range(6):
        cx = 24 + rnd.randint(-8, 8)
        cy = 48 - i * 5 + rnd.randint(-2, 2)
        r = 16 - i * 1.4
        cv.ellipse((cx - r, cy - r * 0.75, cx + r, cy + r * 0.75), shade(g, 0.7 + i * 0.1))
    return cv.done(seed, 5)


def p_bush(kind, col, seed):
    H = 48
    cv = Canvas(48, H)
    g = rgb(col) if col in ("green", "light_green", "brown") else (60, 120, 70)
    cv.poly(diamond(H, 1.0), (40, 70, 48, 110))
    rnd = random.Random(seed)
    for i in range(5):
        cx = 24 + rnd.randint(-9, 9)
        cy = 30 + rnd.randint(-5, 3)
        cv.ellipse((cx - 8, cy - 6, cx + 8, cy + 5), shade(g, 0.7 + i * 0.1))
    return cv.done(seed, 5)


def p_fence(kind, col, seed):
    H = 48
    cv = Canvas(48, H)
    c = mix(rgb(col), (110, 112, 124), 0.5)
    L, R = sides(H, 18, 1.0)
    for P, k in ((L, 0.6), (R, 0.8)):
        face(cv, P, 0.02, 0.07, 0.0, 1.0, shade(c, k + 0.1))
        face(cv, P, 0.93, 0.98, 0.0, 1.0, shade(c, k + 0.1))
        face(cv, P, 0.02, 0.98, 0.9, 1.0, shade(c, k + 0.2))
        face(cv, P, 0.02, 0.98, 0.45, 0.52, shade(c, k))
    return cv.done(seed, 2)


def glow_poly(cv, col, pts):
    cv.poly(pts, col)


def p_furn(kind, col, seed):
    """furniture; returns (sheet, image)."""
    if kind in ex.KINDS:
        return ex.furn_extra(kind, col, seed)
    c = rgb(col)
    if kind in ("table", "seat", "bed", "crate", "plant", "generic_low", "rubble", "lamp_low"):
        H = 48
        cv = Canvas(48, H)
        if kind == "table":
            top = mix(c, (130, 108, 90), 0.55)
            box(cv, H, 11, 0.88, top, edge=True)
            b, t = box(cv, H, 11, 0.88, top, edge=True)
            for x, y in ((t[0][0] + 6, t[0][1] + 4),):
                pass
        elif kind == "seat":
            top = mix(c, (120, 80, 70), 0.5)
            box(cv, H, 8, 0.5, top)
            L, R = sides(H, 20, 0.5)
            b = diamond(H, 0.5, 8)
            t = diamond(H, 0.5, 20)
            cv.poly([b[0], b[1], t[1], t[0]], shade(top, 0.55))
        elif kind == "bed":
            box(cv, H, 8, 0.95, (60, 70, 100))
            b = diamond(H, 0.7, 8)
            cv.poly([b[0], b[1], b[2], b[3]], (190, 190, 215))
            cv.poly([(b[1][0] - 8, b[1][1] + 4), (b[1][0] + 2, b[1][1]), (b[1][0] + 10, b[1][1] + 4), (b[1][0], b[1][1] + 8)], (240, 240, 250))
        elif kind == "crate":
            top = mix(c, (130, 100, 70), 0.55)
            box(cv, H, 16, 0.62, top)
            L, R = sides(H, 16, 0.62)
            face(cv, L, 0.1, 0.9, 0.42, 0.52, shade(top, 0.4))
            face(cv, R, 0.1, 0.9, 0.42, 0.52, shade(top, 0.5))
        elif kind == "plant":
            cv.poly(diamond(H, 0.4, 0), (80, 60, 50))
            for i, (dx, dy, rr) in enumerate(((0, 8, 6), (-5, 14, 5), (5, 14, 5), (0, 18, 6))):
                cv.ellipse((24 + dx - rr, 28 - dy - rr * 0.6, 24 + dx + rr, 28 - dy + rr * 0.6), shade((70, 150, 80), 0.8 + i * 0.1))
        elif kind == "rubble":
            rnd = random.Random(seed)
            for i in range(7):
                x, y = 24 + rnd.randint(-10, 10), 34 + rnd.randint(-4, 3)
                cv.ellipse((x - 4, y - 2, x + 4, y + 2), shade(c, 0.6 + rnd.random() * 0.5))
        else:
            box(cv, H, 12, 0.6, mix(c, (110, 112, 124), 0.5))
        return "half", cv.done(seed, 3)
    H = 72
    cv = Canvas(48, H)
    if kind == "cabinet":
        top = mix(c, (110, 112, 126), 0.55)
        box(cv, H, 34, 0.74, top)
        L, R = sides(H, 34, 0.74)
        face(cv, L, 0.12, 0.88, 0.08, 0.92, shade(top, 0.5))
        face(cv, R, 0.08, 0.92, 0.08, 0.92, shade(top, 0.62))
        face(cv, R, 0.45, 0.5, 0.1, 0.9, shade(top, 0.38))
        face(cv, R, 0.55, 0.62, 0.45, 0.55, (220, 220, 230))
    elif kind == "aquarium":
        box(cv, H, 10, 0.86, (46, 44, 60))
        box(cv, H, 30, 0.8, (110, 205, 235), base=10, edge=True)
        L, R = sides(H, 30, 0.8, 10)
        face(cv, R, 0.06, 0.94, 0.05, 0.95, (40, 120, 170))
        face(cv, L, 0.06, 0.94, 0.05, 0.95, (30, 96, 146))
        face(cv, R, 0.06, 0.94, 0.7, 0.95, (150, 230, 250))
        face(cv, R, 0.22, 0.46, 0.4, 0.6, (250, 150, 60)); face(cv, R, 0.46, 0.58, 0.45, 0.55, (250, 150, 60))
        face(cv, R, 0.6, 0.78, 0.2, 0.34, (90, 170, 255))
        face(cv, R, 0.8, 0.88, 0.05, 0.4, (60, 190, 110))
        face(cv, L, 0.25, 0.5, 0.3, 0.45, (250, 220, 90))
        face(cv, R, 0.06, 0.94, 0.05, 0.12, (214, 190, 150))
    elif kind == "machine":
        body = (36, 38, 52)
        box(cv, H, 40, 0.66, body)
        L, R = sides(H, 40, 0.66)
        glow = NEON.get({"green": "green", "light_green": "green", "magenta": "magenta", "pink": "magenta", "red": "red", "light_red": "red", "yellow": "amber", "brown": "amber"}.get(col, "cyan"))
        face(cv, R, 0.12, 0.88, 0.45, 0.9, shade(glow, 0.45))
        face(cv, R, 0.18, 0.82, 0.52, 0.84, glow)
        face(cv, R, 0.2, 0.8, 0.12, 0.3, shade(glow, 0.5))
        face(cv, L, 0.2, 0.8, 0.5, 0.85, shade(glow, 0.35))
    elif kind == "lamp":
        cv.poly(diamond(H, 0.25, 0), (50, 52, 64))
        box(cv, H, 46, 0.07, (70, 72, 86), edge=False)
        # halo and bulb
        for r, a in ((18, 40), (12, 70), (7, 120)):
            cv.ellipse((24 - r, 20 - r, 24 + r, 20 + r), NEON["amber"] + (a,) if col not in ("cyan", "light_cyan", "magenta", "light_blue") else (NEON["cyan"] if col != "magenta" else NEON["magenta"]) + (a,))
        cv.ellipse((21, 17, 27, 23), (255, 245, 200))
        cv.poly(diamond(H, 0.0001, 0), (0, 0, 0, 0))
    elif kind == "sign":
        cv.poly(diamond(H, 0.25, 0), (50, 52, 64))
        box(cv, H, 30, 0.07, (70, 72, 86), edge=False)
        g = NEON["magenta"] if col in ("magenta", "pink", "red", "light_red") else NEON["cyan"]
        L, R = sides(H, 46, 0.7)
        face(cv, R, 0.05, 0.95, 0.55, 0.98, shade(g, 0.35))
        face(cv, R, 0.12, 0.88, 0.62, 0.9, g)
    elif kind == "tall_generic":
        box(cv, H, 34, 0.64, mix(c, (110, 112, 126), 0.5))
    else:
        box(cv, H, 30, 0.7, mix(c, (110, 112, 126), 0.5))
    return "full", cv.done(seed, 3)


# ---------------------------------------------------------------- characters
def skin(seed):
    return [(236, 200, 170), (200, 150, 110), (150, 100, 70), (110, 70, 50)][seed % 4]


def p_human(role, seed, female=False):
    cv = Canvas(32, 36)
    cvcol = {"player": (40, 220, 255), "npc": (255, 170, 60), "hostile": (230, 70, 80), "android": (190, 200, 215)}[role]
    # shadow
    cv.ellipse((8, 28, 24, 34), (0, 0, 0, 110))
    leg = (36, 40, 56)
    cv.rect((12, 21, 15, 30), leg)
    cv.rect((17, 21, 20, 30), leg)
    cv.rect((11, 29, 15, 31), (20, 20, 26))
    cv.rect((17, 29, 21, 31), (20, 20, 26))
    cv.rect((10, 12, 22, 22), shade(cvcol, 0.7))
    cv.rect((10, 12, 22, 14), cvcol)
    cv.rect((8, 13, 10, 21), shade(cvcol, 0.55))
    cv.rect((22, 13, 24, 21), shade(cvcol, 0.55))
    cv.rect((15, 12, 17, 22), shade(cvcol, 0.45))
    sk = skin(seed) if role != "android" else (170, 180, 195)
    cv.ellipse((12, 3, 20, 12), sk)
    hair = (30, 30, 40) if role != "android" else (90, 100, 120)
    if female:
        cv.ellipse((11, 2, 21, 9), hair)
        cv.rect((11, 6, 13, 14), hair)
        cv.rect((19, 6, 21, 14), hair)
    else:
        cv.ellipse((11, 2, 21, 8), hair)
    if role == "android":
        cv.rect((13, 6, 19, 8), (80, 240, 255))
    else:
        cv.rect((14, 7, 15, 8), (20, 20, 20))
        cv.rect((17, 7, 18, 8), (20, 20, 20))
    return cv.done(seed, 0)


SHAPE_OF = {"Z": "human", "@": "human", "h": "human", "H": "human", "a": "bug", "A": "bug", "x": "bug", "S": "spider", "s": "spider", "d": "quad", "f": "quad", "C": "quad",
            "q": "quad", "r": "quad", "R": "quad", "m": "quad", "M": "quad", "u": "quad", "Y": "quad", "O": "quad", "B": "bird", "b": "bird", "j": "blob", "F": "blob", "J": "blob",
            "z": "human", "w": "worm", "W": "worm", "e": "blob", "E": "blob", "k": "human", "K": "human", "g": "human", "G": "human", "l": "quad", "L": "quad", "n": "human", "N": "human",
            "p": "human", "P": "human", "t": "human", "T": "human", "y": "blob", "Q": "quad", "D": "quad", "c": "quad", "v": "blob", "V": "blob", "X": "human", "I": "bug", "i": "bug",
            "o": "human", "U": "human", "?": "blob", "&": "human", "$": "human", "~": "worm", ";": "blob", "=": "worm", "l": "quad", "f": "quad"}


def p_mon(shape, col, seed, tough):
    cv = Canvas(32, 36)
    c = rgb(col)
    cv.ellipse((6, 28, 26, 34), (0, 0, 0, 110))
    dark = shade(c, 0.55)
    if shape == "human":
        cv.rect((12, 21, 15, 30), dark)
        cv.rect((17, 21, 20, 30), dark)
        cv.rect((10, 12, 22, 22), c)
        cv.rect((8, 14, 10, 24), dark)
        cv.rect((22, 14, 24, 24), dark)
        cv.ellipse((12, 3, 20, 12), mix(c, (150, 170, 140), 0.5))
        cv.rect((14, 7, 15, 8), (255, 40, 40))
        cv.rect((17, 7, 18, 8), (255, 40, 40))
    elif shape == "quad":
        cv.ellipse((5, 14, 24, 26), c)
        cv.ellipse((19, 10, 29, 20), shade(c, 1.15))
        cv.rect((7, 24, 9, 31), dark)
        cv.rect((11, 24, 13, 31), dark)
        cv.rect((17, 24, 19, 31), dark)
        cv.rect((21, 24, 23, 31), dark)
        cv.rect((24, 13, 26, 15), (255, 40, 40))
    elif shape == "bug":
        cv.ellipse((8, 18, 24, 28), c)
        cv.ellipse((20, 18, 28, 26), shade(c, 1.2))
        for x in (10, 14, 18, 22):
            cv.line([(x, 26), (x - 3, 32)], dark, 1)
            cv.line([(x, 26), (x + 3, 32)], dark, 1)
    elif shape == "spider":
        cv.ellipse((10, 16, 22, 26), c)
        cv.ellipse((19, 17, 25, 23), shade(c, 1.2))
        for i, x in enumerate((9, 12, 20, 23)):
            cv.line([(x, 22), (x - 6 if x < 16 else x + 6, 14)], dark, 1)
            cv.line([(x - 6 if x < 16 else x + 6, 14), (x - 8 if x < 16 else x + 8, 30)], dark, 1)
        cv.rect((22, 19, 24, 21), (120, 255, 255))
    elif shape == "bird":
        cv.ellipse((9, 14, 23, 26), c)
        cv.ellipse((19, 8, 27, 15), shade(c, 1.15))
        cv.poly([(26, 11), (31, 12), (26, 13)], (230, 190, 60))
        cv.line([(14, 25), (14, 31)], dark, 1)
        cv.line([(18, 25), (18, 31)], dark, 1)
    elif shape == "worm":
        for i in range(6):
            cv.ellipse((4 + i * 4, 22 - (i % 2) * 4 - i, 11 + i * 4, 29 - (i % 2) * 4 - i), shade(c, 0.8 + i * 0.05))
    else:  # blob
        cv.ellipse((6, 14, 26, 30), c)
        cv.ellipse((10, 16, 18, 22), shade(c, 1.35))
        cv.rect((13, 22, 15, 24), (20, 20, 20))
        cv.rect((18, 22, 20, 24), (20, 20, 20))
    if tough:
        cv.rect((4, 2, 28, 4), (20, 20, 20))
        cv.rect((5, 3, 27, 3), (200, 60, 60))
    return cv.done(seed, 3)


def p_machine(kind, col, seed):
    """robots, androids, drones, turrets"""
    cv = Canvas(32, 36)
    c = mix(rgb(col), (140, 148, 164), 0.55)
    cv.ellipse((6, 28, 26, 34), (0, 0, 0, 110))
    glow = NEON["cyan"] if col not in ("red", "light_red", "magenta") else NEON["red"]
    if kind == "drone":
        cv.ellipse((7, 14, 25, 22), c)
        cv.rect((3, 12, 13, 13), shade(c, 0.6))
        cv.rect((19, 12, 29, 13), shade(c, 0.6))
        cv.ellipse((14, 17, 18, 21), glow)
    elif kind == "turret":
        cv.rect((10, 22, 22, 30), shade(c, 0.6))
        cv.ellipse((9, 12, 23, 24), c)
        cv.rect((21, 16, 31, 18), shade(c, 0.5))
        cv.ellipse((14, 15, 18, 19), glow)
    elif kind == "tread":
        cv.rect((6, 24, 26, 31), shade(c, 0.5))
        cv.rect((9, 12, 23, 25), c)
        cv.rect((11, 14, 21, 17), glow)
    else:  # walker
        cv.rect((12, 21, 15, 30), shade(c, 0.6))
        cv.rect((17, 21, 20, 30), shade(c, 0.6))
        cv.rect((9, 11, 23, 22), c)
        cv.rect((7, 12, 9, 22), shade(c, 0.65))
        cv.rect((23, 12, 25, 22), shade(c, 0.65))
        cv.rect((12, 3, 20, 11), shade(c, 1.1))
        cv.rect((13, 6, 19, 8), glow)
    return cv.done(seed, 2)


def p_unknown():
    cvu = Canvas(48, 36)
    cvu.poly(diamond(36, 1.0), (60, 20, 80))
    cvu.line([(18, 14), (30, 22)], (255, 80, 220), 1.2)
    cvu.line([(30, 14), (18, 22)], (255, 80, 220), 1.2)
    return cvu.done()


def p_marker(kind):
    cv = Canvas(48, 36)
    d = diamond(36, 1.0)
    if kind == "cursor":
        cv.line(d + [d[0]], (255, 230, 60), 1.6)
        cv.line([(d[0][0] + 6, d[0][1]), (d[1][0], d[1][1] + 3), (d[2][0] - 6, d[2][1])], (255, 255, 160), 0.8)
    elif kind == "highlight":
        cv.poly(d, (255, 230, 60, 90), None)
        cv.line(d + [d[0]], (255, 230, 60), 0.9)
    elif kind == "line_target":
        cv.line(d + [d[0]], (255, 70, 70), 1.4)
        cv.line([d[1], d[3]], (255, 70, 70), 0.8)
        cv.line([d[0], d[2]], (255, 70, 70), 0.8)
    elif kind == "animation_line":
        cv.ellipse((20, 21, 28, 27), (255, 255, 160))
    elif kind.startswith("sees_"):
        colr = {"sees_hostile": (255, 60, 60), "sees_neutral": (255, 220, 60), "sees_friendly": (60, 255, 120), "sees_other": (150, 150, 255)}[kind]
        cv.line(d + [d[0]], colr, 0.9)
        cv.poly([(24, 6), (28, 12), (20, 12)], colr)
    return cv.done()


# ---------------------------------------------------------------- classification
def tkind(i, o):
    fl = set(o.get("flags") or [])
    n = defs.nm(o).lower()
    s = i.lower() + " " + n
    col = defs.color(o)
    if i == "t_null":
        return None
    if "GOES_UP" in fl or "GOES_DOWN" in fl or "stairs" in i:
        return ("stairs_down" if ("GOES_DOWN" in fl or "down" in i) else "stairs_up", col, "full")
    if "DOOR" in fl or re.search(r"door|gate", i) and "window" not in i:
        if "gate" in i and "fence" in s or "fence_gate" in i:
            return ("fence", col, "half")
        if "frame" in i or "open" in i or ("close" in o and "open" not in o) or "o" == i.split("_")[-1] or "broken" in i:
            return ("door_open", col, "full")
        return ("door", col, "full")
    if "window" in i or "WINDOW" in fl:
        if has(s, "empty", "broken", "frame", "open", "smash", "shatter"):
            return ("window_open", col, "full")
        return ("window", col, "full")
    if "TREE" in fl or re.search(r"(^|_)tree|trunk", i) and "stump" not in i:
        return ("tree", "green", "high")
    if "SHRUB" in fl or re.search(r"bush|shrub|brush|thicket", i):
        return ("bush", col, "half")
    if has(i, "fence", "railing", "chainlink", "barricade", "guardrail"):
        return ("fence", col, "half")
    if has(i, "bars", "grate_wall", "grille"):
        return ("bars", col, "full")
    if "WALL" in fl or re.search(r"wall", i) or "wall" in n or has(i, "pillar", "column"):
        return ("wall", col, "full")
    if "SWIMMABLE" in fl or re.search(r"water|lake|river|swamp|ocean|pool", i):
        return ("deepwater" if has(i, "deep", "ocean", "lake") else "water", col, "flat")
    if has(s, "rock", "boulder", "cliff", "mountain", "stone wall") and "OBSTRUCTED" in fl:
        return ("rock", col, "full")
    if "OBSTRUCTED" in fl and "FLAT" not in fl and "TRANSPARENT" not in fl:
        return ("rock", col, "full")
    for words, k in ((("pavement", "asphalt", "road", "street", "tarmac", "highway"), "asphalt"),
                     (("sidewalk", "concrete", "cement", "plaza", "curb"), "concrete"),
                     (("grass", "lawn", "field", "meadow", "moss", "weed"), "grass"),
                     (("dirt", "mud", "soil", "ground", "clay", "gravel", "path", "trail", "farmland", "furrow"), "dirt"),
                     (("sand", "beach", "dune"), "sand"),
                     (("snow", "ice", "frost"), "snow"),
                     (("roof", "shingle", "tar", "chimney", "gutter"), "roof"),
                     (("carpet", "rug", "mat"), "carpet"),
                     (("wood", "plank", "parquet", "deck", "boardwalk", "hardwood"), "wood"),
                     (("tile", "linoleum", "marble", "ceramic"), "tile"),
                     (("metal", "steel", "grate", "catwalk", "iron", "plate", "rail"), "metal"),
                     (("floor",), "floor"),
                     (("bridge",), "bridge"),
                     (("rock", "stone", "slate", "cave", "bedrock"), "rock")):
        if has(s, *words):
            return (k, col, "flat")
    return ("generic", col, "flat")


def fkind(i, o):
    fl = set(o.get("flags") or [])
    n = defs.nm(o).lower()
    s = i.lower() + " " + n
    col = defs.color(o)
    if has(s, "aquarium"):
        return ("aquarium", col, "full")
    for words, k in ((("recharge",), "charger"), (("autodoc",), "autodoc"), (("pylon",), "pylon"), (("transformer", "substation_unit", "capacitor_bank"), "transformer"),
                     (("cable_ew",), "cable_ew"), (("cable_ns",), "cable_ns"), (("reactor",), "reactor"), (("solar_panel", "solar_array"), "solar"),
                     (("wind_turbine",), "windturbine"), (("tidal",), "tidalturbine"), (("_turbine",), "turbine"), (("shinto_torii",), "torii"),
                     (("komainu",), "komainu"), (("statue",), "statue"), (("holo_ad", "hologram"), "holo"), (("gurney",), "gurney"),
                     (("android_pod", "charging_pod"), "pod"), (("iconostasis",), "iconostasis"), (("candle_stand",), "candlestand"),
                     (("altar_table",), "altar"), (("church_bell",), "bell"), (("analoy",), "analoy"), (("baptismal",), "font"), (("chozuya",), "chozuya"),
                     (("ema_rack",), "ema"), (("saisen",), "offering"), (("shimenawa",), "shimenawa"), (("hokora",), "shrine"), (("worship_cross",), "cross")):
        if has(i, *words):
            return (k, col, "full")
    if has(s, "terminal", "computer", "atm", "console", "vending", "kiosk", "arcade", "server", "jack", "monitor", "screen", "tv", "television", "radio", "machine", "dispenser", "scanner", "charger"):
        return ("machine", col, "full")
    if has(s, "streetlamp", "street lamp", "lamp", "lantern", "torch", "floodlight", "light"):
        return ("lamp", col, "full")
    if has(s, "neon", "sign", "billboard", "banner", "poster"):
        return ("sign", col, "full")
    if has(s, "bed", "mattress", "cot", "hammock", "sleeping", "futon"):
        return ("bed", col, "half")
    if has(s, "chair", "stool", "bench", "seat", "sofa", "couch", "armchair", "recliner", "throne", "pew"):
        return ("seat", col, "half")
    if has(s, "table", "desk", "counter", "bar", "workbench", "stall", "booth", "stage"):
        return ("table", col, "half")
    if has(s, "fridge", "freezer", "cabinet", "locker", "closet", "wardrobe", "shelf", "shelves", "rack", "bookcase", "dresser", "oven", "stove", "washer", "dryer", "fireplace", "safe", "cupboard", "sink", "toilet", "bathtub", "shower", "fountain", "forge", "kiln", "furnace", "generator", "tank", "cooler", "display", "cage", "altar"):
        return ("cabinet", col, "full")
    if has(s, "plant", "flower", "bush", "fern", "vine", "sapling", "seedling", "weed", "crop", "pot"):
        return ("plant", col, "half")
    if has(s, "crate", "box", "barrel", "bin", "dumpster", "trash", "container", "chest", "pallet", "bag", "sack", "drum", "keg", "trunk", "suitcase", "garbage"):
        return ("crate", col, "half")
    if has(s, "rubble", "debris", "pile", "ash", "scrap", "wreck", "junk", "bones", "corpse", "web", "puddle", "stain"):
        return ("rubble", col, "half")
    if "OBSTRUCTED" in fl:
        return ("tall_generic", col, "full")
    return ("generic_low", col, "half")


def mkind(i, o):
    n = defs.nm(o).lower()
    s = i.lower() + " " + n
    col = defs.color(o)
    sym = (o.get("symbol") or "?")[:1]
    fl = set(o.get("flags") or [])
    tough = bool({"EXTREME"} & set(o.get("special_attacks") and [] or [])) or (o.get("hp", 0) or 0) >= 300 and False
    mach = bool(re.search(r"\b(robot|robots|drone|android|mech|turret|bot|cyborg|automaton|kumo|daikumo|mecha|droid|sentinel|tank)\b", s))
    if mach or "ELECTRONIC" in fl or "ROBOT" in str(o.get("species", "")).upper():
        if has(s, "drone", "copter", "flying", "hover"):
            return ("machine", "drone", col)
        if has(s, "turret"):
            return ("machine", "turret", col)
        if has(s, "kumo", "tank", "treads", "rover", "mech", "vehicle"):
            return ("machine", "tread", col)
        return ("machine", "walker", col)
    return ("mon", SHAPE_OF.get(sym, "blob"), col)


# ---------------------------------------------------------------- packing
class Sheet:
    def __init__(self, name):
        self.name, self.w, self.h = name, *SIZE[name]
        self.sprites = []
        self.cols = COLS[name]

    def add(self, img):
        self.sprites.append(img)
        return len(self.sprites) - 1

    def capacity(self):
        rows = max(1, math.ceil(len(self.sprites) / self.cols))
        return rows * self.cols

    def image(self):
        rows = max(1, math.ceil(len(self.sprites) / self.cols))
        im = Image.new("RGBA", (self.cols * self.w, rows * self.h), (0, 0, 0, 0))
        for k, s in enumerate(self.sprites):
            im.paste(s, ((k % self.cols) * self.w, (k // self.cols) * self.h))
        return im


ASCII = [(0, False, "BLACK"), (256, True, "WHITE"), (512, False, "WHITE"), (768, True, "BLACK"), (1024, False, "RED"), (1280, False, "GREEN"), (1536, False, "BLUE"),
         (1792, False, "CYAN"), (2048, False, "MAGENTA"), (2304, False, "YELLOW"), (2560, True, "RED"), (2816, True, "GREEN"), (3072, True, "BLUE"),
         (3328, True, "CYAN"), (3584, True, "MAGENTA"), (3840, True, "YELLOW")]
ASCII_RGB = {"BLACK": (0, 0, 0), "WHITE": (200, 200, 205), "RED": (190, 40, 50), "GREEN": (40, 170, 70), "BLUE": (50, 80, 200), "CYAN": (40, 170, 180),
             "MAGENTA": (180, 50, 180), "YELLOW": (190, 160, 50)}


def make_fallback(repo, out):
    font = ImageFont.truetype(os.path.join(repo, "data/font/Terminus.ttf"), 22)
    cw, ch_ = CONF["cell"]
    im = Image.new("RGBA", (16 * cw, 256 * ch_), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for ci, (off, bold, cname) in enumerate(ASCII):
        c = ASCII_RGB[cname]
        if bold:
            c = tuple(min(255, int(v * 1.35 + 40)) for v in c)
        if cname == "BLACK" and not bold:
            c = (10, 10, 14)
        for g in range(256):
            idx = off + g
            x, y = (idx % 16) * cw, (idx // 16) * ch_
            if g < 32 or g == 127:
                continue
            ch = chr(g) if g < 127 else None
            if ch is None:
                continue
            d.text((x + cw // 2, y + ch_ // 2), ch, font=font, fill=c + (255,), anchor="mm")
    im.save(out)


CONF = {"dir": "gfx/Bouma", "name": "Bouma", "cell": (48, 24),
        "info": {"pixelscale": 1, "width": 48, "height": 24, "zlevel_height": 108, "iso": True, "retract_dist_min": 2.5, "retract_dist_max": 6.0}}


def main(stock, repo):
    D = defs.load(stock, os.path.join(repo, "data/mods/trilobit"))
    out = os.path.join(repo, CONF["dir"])
    os.makedirs(out, exist_ok=True)
    sheets = {n: Sheet(n) for n in SHEETS}
    sprite_of = {}   # key -> (sheet, local index)
    entries = {}     # (sheet,idx) -> list of ids
    ids_all = {}

    def want(key, sheet, painter):
        if key not in sprite_of:
            img = painter()
            sprite_of[key] = (sheet, sheets[sheet].add(img))
        return sprite_of[key]

    def seed_of(key):
        return sum(ord(c) * (k + 1) for k, c in enumerate(str(key))) & 0xffff

    # terrain
    for i, o in sorted(D["terrain"].items()):
        k = tkind(i, o)
        if not k:
            continue
        kind, col, sh = k
        if kind in ("stairs_up", "stairs_down"):
            key = ("t", kind, col)
            tgt = want(key, "full", lambda kind=kind, col=col, key=key: p_stairs(kind, col, seed_of(key)))
        elif kind in ("wall", "window", "window_open", "door", "door_open", "rock", "bars"):
            key = ("t", kind, col)
            tgt = want(key, "full", lambda kind=kind, col=col, key=key: p_wall(kind, col, seed_of(key)))
        elif kind == "tree":
            key = ("t", kind, "green", i)
            tgt = want(key, "high", lambda key=key: p_tree("tree", "green", seed_of(key)))
        elif kind == "bush":
            key = ("t", kind, col)
            tgt = want(key, "half", lambda col=col, key=key: p_bush("bush", col, seed_of(key)))
        elif kind == "fence":
            key = ("t", kind, col)
            tgt = want(key, "half", lambda col=col, key=key: p_fence("fence", col, seed_of(key)))
        else:
            ckey = col if kind in ("carpet", "tile", "generic", "floor") else "x"
            key = ("t", kind, ckey)
            tgt = want(key, "flat", lambda kind=kind, ckey=ckey, key=key: p_floor(kind, ckey if ckey != "x" else "light_gray", seed_of(key)))
        entries.setdefault(tgt, []).append(i)

    # furniture
    for i, o in sorted(D["furniture"].items()):
        kind, col, sh = fkind(i, o)
        key = ("f", kind, col)
        if key not in sprite_of:
            shn, img = p_furn(kind, col, seed_of(key))
            sprite_of[key] = (shn, sheets[shn].add(img))
        entries.setdefault(sprite_of[key], []).append(i)

    # monsters
    PETSHAPE = {"mon_trl_dog": "dog", "mon_trl_cat": "cat", "mon_trl_rabbit": "rabbit", "mon_trl_chicken": "chicken"}
    for i, o in sorted(D["monster"].items()):
        cls, shape, col = mkind(i, o)
        if i in PETSHAPE:
            key = ("m", "pet", PETSHAPE[i], col)
            tgt = want(key, "chars", lambda shape=PETSHAPE[i], col=col, key=key: ex.p_pet(shape, col, seed_of(key)))
            entries.setdefault(tgt, []).append(i)
            continue
        key = ("m", cls, shape, col)
        if cls == "machine":
            tgt = want(key, "chars", lambda shape=shape, col=col, key=key: p_machine(shape, col, seed_of(key)))
        else:
            tgt = want(key, "chars", lambda shape=shape, col=col, key=key: p_mon(shape, col, seed_of(key), False))
        entries.setdefault(tgt, []).append(i)

    # items, vehicle parts and fields
    for i, o in sorted(D["item"].items()):
        kind, col = itm.classify_item(i, o)
        key = ("i", kind, col)
        tgt = want(key, "items", lambda kind=kind, col=col, key=key: itm.p_item(kind, col, seed_of(key)))
        entries.setdefault(tgt, []).append(i)
    for i, o in sorted(D["vpart"].items()):
        kind, col = itm.classify_vpart(i, o)
        key = ("v", kind, col)
        tgt = want(key, "half", lambda kind=kind, col=col, key=key: itm.p_vpart(kind, col, seed_of(key)))
        entries.setdefault(tgt, []).append("vp_" + i)
    for i, o in sorted(D["field"].items()):
        kind, col = itm.classify_field(i, o)
        key = ("fd", kind, col)
        tgt = want(key, "flat", lambda kind=kind, col=col, key=key: itm.p_field(kind, col, seed_of(key)))
        entries.setdefault(tgt, []).append(i)

    # people
    for role, fem, ids in (("player", False, ["player_male"]), ("player", True, ["player_female"]), ("npc", False, ["npc_male"]), ("npc", True, ["npc_female"])):
        key = ("h", role, fem)
        tgt = want(key, "chars", lambda role=role, fem=fem: p_human(role, 3 if role == "player" else 1, fem))
        entries.setdefault(tgt, []).extend(ids)

    # held weapons: overlays drawn on top of the character
    key = ("o", "w2011")
    tgt = want(key, "chars", lambda: itm.outline(itm.p_wield_arcrifle()))
    entries.setdefault(tgt, []).append("overlay_wielded_trl_gun_w2011")

    # held overlays for every Trilobit weapon (guns, bows, blades, spears, axes, blunt weapons)
    held = 0
    for i, o in sorted(D["item"].items()):
        if not i.startswith("trl_") or i == "trl_gun_w2011":
            continue
        kind, col = itm.classify_item(i, o)
        if kind in itm.WIELD_KINDS:
            key = ("o", "wield", kind, col)
            tgt = want(key, "chars", lambda kind=kind, col=col, key=key: itm.outline(itm.p_wield(kind, col, seed_of(key))))
            entries.setdefault(tgt, []).append("overlay_wielded_" + i)
            held += 1
    print("held-weapon overlays:", held)

    # worn armor: overlays over the body
    for iid, akind in itm.ARMOR_KINDS.items():
        key = ("o", akind)
        tgt = want(key, "chars", lambda akind=akind: itm.outline(itm.p_worn(akind)))
        entries.setdefault(tgt, []).append("overlay_worn_" + iid)

    # markers (drawn on the flat sheet)
    for mk, ids in (("cursor", ["cursor"]), ("highlight", ["highlight", "highlight_item", "highlight_item_static"]), ("line_target", ["line_target"]),
                    ("animation_line", ["animation_line", "line_trail"]), ("sees_hostile", ["overlay_hostile_sees_player"]),
                    ("sees_neutral", ["overlay_neutral_sees_player"]), ("sees_friendly", ["overlay_friendly_sees_player"]), ("sees_other", ["overlay_other_sees_player"])):
        key = ("k", mk)
        tgt = want(key, "flat", lambda mk=mk: p_marker(mk))
        entries.setdefault(tgt, []).extend(ids)
    # unknown tile
    key = ("k", "unknown")
    sprite_of[key] = ("flat", sheets["flat"].add(p_unknown()))
    entries.setdefault(sprite_of[key], []).append("unknown")

    # write sheets and config
    cfg_sheets = []
    base = 1
    for n in SHEETS:
        sh = sheets[n]
        fn = f"bouma_{n}.png"
        sh.image().save(os.path.join(out, fn))
        tiles = []
        for (sn, idx), ids in sorted(entries.items(), key=lambda kv: (kv[0][0], kv[0][1])):
            if sn != n:
                continue
            ids = sorted(set(ids))
            tiles.append({"id": ids if len(ids) > 1 else ids[0], "fg": base + idx})
        cfg_sheets.append({"file": fn, "sprite_width": sh.w, "sprite_height": sh.h, "sprite_offset_x": OFFS[n][0], "sprite_offset_y": OFFS[n][1], "tiles": tiles})
        base += sh.capacity()
    make_fallback(repo, os.path.join(out, "fallback.png"))
    cfg_sheets.append({"file": "fallback.png", "tiles": [], "ascii": [{"offset": o, "bold": b, "color": c} for o, b, c in ASCII]})
    cfg = {"tile_info": [CONF["info"]],
           "tiles-new": cfg_sheets}
    json.dump(cfg, open(os.path.join(out, "tile_config.json"), "w"), indent=1)
    open(os.path.join(out, "tileset.txt"), "w").write("NAME: %s\nVIEW: %s\nJSON: tile_config.json\nTILESET: tiles.png\n" % (CONF["name"], CONF["name"]))
    n_ids = sum(len(v) for v in entries.values())
    print({n: len(sheets[n].sprites) for n in SHEETS}, "sprites;", n_ids, "ids covered")
    contact(sheets, out)


def contact(sheets, out):
    """A contact sheet of every sprite on a mid-grey ground, for visual checking (not shipped)."""
    pad = Image.new("RGBA", (1, 1))
    rows = []
    for n in SHEETS:
        sh = sheets[n]
        cols = 16 if n != "chars" else 24
        r = math.ceil(len(sh.sprites) / cols)
        im = Image.new("RGBA", (cols * (sh.w + 2), r * (sh.h + 2)), (70, 72, 80, 255))
        for k, s in enumerate(sh.sprites):
            im.alpha_composite(s, ((k % cols) * (sh.w + 2), (k // cols) * (sh.h + 2)))
        rows.append(im)
    for n, im in zip(SHEETS, rows):
        im.save(f"/tmp/claude-0/contact_{n}.png")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
