"""Extra Bouma sprites for the objects added after the base tileset: power-grid and medical furniture, shrine, torii, statues, holograms,
church furniture, and the pet monsters.  All original designs.  furn_extra(kind, col, seed) -> (sheet, image)."""
import math
from PIL import Image
from iso import Canvas, box, face, sides, diamond, shade, mix

PAL = {"black": (30, 30, 40), "red": (190, 58, 66), "green": (62, 140, 86), "brown": (132, 94, 62), "blue": (66, 90, 170),
       "magenta": (160, 66, 160), "light_gray": (176, 178, 188), "dark_gray": (92, 94, 108), "light_red": (232, 100, 110),
       "light_green": (120, 210, 130), "yellow": (232, 208, 90), "light_blue": (112, 150, 240), "pink": (238, 142, 190),
       "light_cyan": (130, 226, 238), "white": (232, 236, 244), "cyan": (56, 150, 160)}
NEON = {"cyan": (60, 235, 255), "magenta": (255, 70, 200), "green": (90, 255, 140), "amber": (255, 170, 50), "red": (255, 70, 80)}
GOLD, GOLD_D = (236, 196, 84), (176, 134, 48)


def glow_of(col):
    return NEON[{"light_green": "green", "green": "green", "pink": "magenta", "magenta": "magenta", "light_red": "red", "red": "red",
                 "yellow": "amber", "brown": "amber"}.get(col, "cyan")]


KINDS = ("charger", "autodoc", "pylon", "cable_ew", "cable_ns", "reactor", "solar", "windturbine", "tidalturbine", "turbine", "torii", "shrine",
         "statue", "holo", "gurney", "pod", "iconostasis", "candlestand", "altar", "bell", "analoy", "font", "komainu", "ema", "offering", "chozuya",
         "shimenawa", "substation", "transformer", "cross")


def furn_extra(kind, col, seed):
    H = 72
    cv = Canvas(48, H)
    c = PAL.get(col, PAL["light_gray"])
    g = glow_of(col)
    sheet = "full"
    cx = 24
    gy = H - 18          # ground centre of the tile
    if kind == "charger":
        box(cv, H, 4, 0.5, (50, 52, 66))
        box(cv, H, 40, 0.22, (36, 38, 52), base=4)
        L, R = sides(H, 40, 0.22, 4)
        for v in (0.25, 0.5, 0.75):
            face(cv, R, 0.15, 0.85, v, v + 0.1, g)
            face(cv, L, 0.15, 0.85, v, v + 0.1, shade(g, 0.6))
        cv.ellipse((cx - 5, 14, cx + 5, 22), (255, 255, 255, 220))
        cv.ellipse((cx - 9, 10, cx + 9, 26), g + (70,))
    elif kind in ("autodoc", "gurney"):
        box(cv, H, 7, 0.9, (190, 196, 212) if kind == "autodoc" else (214, 218, 230))
        if kind == "autodoc":
            box(cv, H, 20, 0.7, (120, 220, 240, 150), base=7, edge=True)
            L, R = sides(H, 20, 0.7, 7)
            face(cv, R, 0.08, 0.92, 0.1, 0.9, (110, 210, 240, 140))
            face(cv, L, 0.08, 0.92, 0.1, 0.9, (80, 170, 210, 140))
            face(cv, R, 0.1, 0.9, 0.84, 0.96, g)
            box(cv, H, 9, 0.35, (60, 64, 80), base=27)
        else:
            L, R = sides(H, 7, 0.9)
            face(cv, R, 0.05, 0.95, 0.1, 0.9, (240, 242, 248))
            cv.ellipse((12, gy + 5, 18, gy + 11), (40, 40, 50)); cv.ellipse((30, gy + 5, 36, gy + 11), (40, 40, 50))
    elif kind in ("pylon", "transformer", "substation"):
        if kind == "pylon":
            cv.line([(cx - 9, gy + 4), (cx - 2, 10)], (150, 156, 170), 1.3)
            cv.line([(cx + 9, gy + 4), (cx + 2, 10)], (150, 156, 170), 1.3)
            for y in (22, 36, 50):
                w = 3 + (y - 10) * 0.16
                cv.line([(cx - w, y), (cx + w, y)], (130, 136, 150), 0.9)
                cv.line([(cx - w, y), (cx + w - 2, y + 12)], (110, 116, 130), 0.6)
            cv.line([(cx - 14, 16), (cx + 14, 16)], (170, 176, 190), 1.1)
            for x in (cx - 14, cx - 6, cx + 6, cx + 14):
                cv.rect((x - 1, 16, x + 1, 22), (230, 220, 190))
            cv.rect((cx - 1, 8, cx + 1, 11), (255, 90, 90))
        else:
            box(cv, H, 22 if kind == "transformer" else 14, 0.8, (96, 104, 118))
            L, R = sides(H, 22 if kind == "transformer" else 14, 0.8)
            for u in (0.2, 0.4, 0.6, 0.8):
                face(cv, R, u - 0.04, u + 0.04, 0.1, 0.9, (60, 64, 78))
            for x in (cx - 8, cx, cx + 8):
                cv.rect((x - 1, 20 if kind == "transformer" else 28, x + 1, 26 if kind == "transformer" else 32), (230, 220, 190))
                cv.ellipse((x - 2, 17 if kind == "transformer" else 25, x + 2, 21 if kind == "transformer" else 29), (255, 190, 60))
            face(cv, R, 0.3, 0.7, 0.4, 0.55, (255, 210, 70))
    elif kind in ("cable_ew", "cable_ns"):
        sheet = "half"
        cv = Canvas(48, 48)
        d = diamond(48, 0.7)
        if kind == "cable_ew":
            cv.line([d[0], d[2]], (30, 32, 40), 2.4); cv.line([d[0], d[2]], (230, 190, 70), 0.8)
        else:
            cv.line([d[1], d[3]], (30, 32, 40), 2.4); cv.line([d[1], d[3]], (230, 190, 70), 0.8)
        return sheet, cv.done(seed, 2)
    elif kind == "reactor":
        cv.ellipse((8, gy - 4, 40, gy + 8), (60, 66, 80))
        cv.rect((10, 28, 38, gy + 2), (88, 96, 112))
        cv.ellipse((10, 22, 38, 38), (130, 138, 156))
        for u in (0.3, 0.5, 0.7):
            cv.rect((10 + u * 28 - 1, 30, 10 + u * 28 + 1, gy + 2), (60, 66, 80))
        cv.rect((16, 34, 32, 46), (50, 255, 140, 230)); cv.ellipse((12, 28, 36, 40), (70, 255, 160, 120))
        cv.ellipse((18, 24, 30, 30), (230, 255, 240))
    elif kind == "solar":
        sheet = "half"
        cv = Canvas(48, 48)
        cv.rect((22, 30, 26, 40), (70, 72, 86))
        cv.poly([(8, 28), (24, 14), (42, 24), (26, 38)], (30, 56, 120))
        cv.poly([(8, 28), (26, 38), (26, 40), (8, 30)], (90, 96, 114))
        for t in (0.25, 0.5, 0.75):
            cv.line([(8 + 16 * t, 28 - 14 * t), (26 + 16 * t, 38 - 14 * t)], (100, 140, 210), 0.5)
            cv.line([(8 + 18 * t, 28 + 10 * t), (24 + 18 * t, 14 + 10 * t)], (100, 140, 210), 0.5)
        cv.poly([(14, 24), (22, 17), (26, 19), (18, 27)], (170, 210, 255, 150))
        return sheet, cv.done(seed, 2)
    elif kind == "windturbine":
        cv.rect((cx - 1.5, 22, cx + 1.5, gy + 4), (222, 226, 236))
        cv.ellipse((cx - 3, 18, cx + 3, 26), (240, 244, 250))
        for a in (90, 210, 330):
            r = math.radians(a)
            cv.line([(cx, 22), (cx + 18 * math.cos(r), 22 - 18 * math.sin(r))], (250, 252, 255), 1.6)
    elif kind in ("tidalturbine", "turbine"):
        sheet = "half"
        cv = Canvas(48, 48)
        if kind == "tidalturbine":
            cv.ellipse((6, 24, 42, 42), (20, 70, 120, 200))
            cv.rect((22, 12, 26, 32), (80, 90, 108))
            cv.ellipse((14, 26, 34, 38), (120, 130, 150))
            for a in (0, 120, 240):
                r = math.radians(a + 30)
                cv.line([(24, 32), (24 + 10 * math.cos(r), 32 - 5 * math.sin(r))], (220, 230, 245), 1.4)
            cv.ellipse((21, 29, 27, 35), (60, 235, 255))
        else:
            box(cv, 48, 8, 0.9, (86, 94, 108))
            cv.ellipse((6, 14, 42, 34), (120, 128, 146)); cv.ellipse((10, 14, 38, 28), (160, 170, 188))
            for x in (14, 20, 26, 32):
                cv.line([(x, 16), (x - 2, 28)], (90, 98, 116), 0.8)
            cv.ellipse((20, 18, 28, 24), g)
        return sheet, cv.done(seed, 2)
    elif kind == "torii":
        red = (208, 52, 52); dark = (120, 28, 34)
        for x in (cx - 12, cx + 9):
            cv.rect((x, 20, x + 3, gy + 6), red); cv.rect((x, 20, x + 1, gy + 6), shade(red, 1.2))
            cv.rect((x - 1, gy + 4, x + 4, gy + 8), (60, 56, 60))
        cv.poly([(cx - 20, 14), (cx + 20, 14), (cx + 16, 19), (cx - 16, 19)], (36, 34, 40))
        cv.rect((cx - 15, 24, cx + 15, 27), red)
        cv.rect((cx - 15, 27, cx + 15, 28), dark)
        cv.rect((cx - 1.5, 19, cx + 1.5, 24), dark)
    elif kind == "shrine":
        box(cv, H, 8, 0.7, (150, 118, 86))
        box(cv, H, 18, 0.5, (190, 150, 108), base=8)
        L, R = sides(H, 18, 0.5, 8)
        face(cv, R, 0.3, 0.7, 0.0, 0.7, (40, 30, 30))
        cv.poly([(cx - 17, 36), (cx, 18), (cx + 17, 36), (cx, 40)], (200, 56, 56))
        cv.poly([(cx - 17, 36), (cx, 40), (cx + 17, 36), (cx + 17, 38), (cx, 43), (cx - 17, 38)], (110, 28, 34))
        cv.rect((cx - 1, 14, cx + 1, 19), GOLD)
    elif kind in ("statue", "komainu"):
        stone = (170, 172, 182) if kind == "komainu" else mix(c, (170, 172, 182), 0.55)
        box(cv, H, 12, 0.5, shade(stone, 0.75))
        if kind == "komainu":
            cv.ellipse((cx - 9, 26, cx + 9, 42), stone)
            cv.ellipse((cx + 2, 20, cx + 12, 32), shade(stone, 1.1))
            cv.poly([(cx + 4, 21), (cx + 6, 16), (cx + 8, 21)], shade(stone, 1.1))
            cv.rect((cx - 8, 38, cx - 5, 50), stone); cv.rect((cx + 4, 38, cx + 7, 50), stone)
            cv.poly([(cx - 8, 30), (cx - 17, 32), (cx - 12, 38)], shade(stone, 0.9))
            cv.rect((cx + 9, 25, cx + 11, 27), (200, 50, 50))
        else:
            cv.rect((cx - 5, 28, cx + 5, 52), stone)
            cv.ellipse((cx - 5, 18, cx + 5, 29), shade(stone, 1.1))
            cv.rect((cx - 9, 31, cx - 5, 42), shade(stone, 0.9)); cv.rect((cx + 5, 31, cx + 9, 42), shade(stone, 0.9))
    elif kind == "holo":
        box(cv, H, 4, 0.4, (50, 54, 70))
        cv.poly([(cx - 4, gy + 2), (cx + 4, gy + 2), (cx + 16, 14), (cx - 16, 14)], g + (70,))
        cv.poly([(cx - 3, gy), (cx + 3, gy), (cx + 11, 18), (cx - 11, 18)], g + (60,))
        cv.rect((cx - 10, 18, cx + 10, 40), g + (110,))
        for y in (23, 28, 33):
            cv.line([(cx - 8, y), (cx + 8, y)], (255, 255, 255, 220), 0.7)
    elif kind == "pod":
        box(cv, H, 4, 0.7, (60, 64, 80))
        cv.ellipse((cx - 9, 22, cx + 9, gy + 2), (214, 220, 234))
        cv.ellipse((cx - 6, 26, cx + 6, 44), g + (190,))
        cv.rect((cx - 2, gy - 6, cx + 2, gy + 2), (60, 64, 80))
    elif kind == "iconostasis":
        wood = (120, 78, 40)
        box(cv, H, 6, 0.9, (96, 62, 34))
        for i in range(4):
            x = 8 + i * 9
            cv.rect((x, 12, x + 8, 50), wood)
            cv.rect((x + 1, 13, x + 7, 49), (60, 36, 24))
            cv.rect((x + 2, 15, x + 6, 26), (214, 170, 70))     # gilded icon panels
            cv.ellipse((x + 2.5, 28, x + 5.5, 32), (232, 196, 140))
            cv.rect((x + 2, 33, x + 6, 46), (150, 40, 50))
        cv.rect((6, 10, 42, 13), GOLD); cv.rect((cx - 1, 4, cx + 1, 11), GOLD); cv.rect((cx - 4, 6, cx + 4, 8), GOLD)
    elif kind == "candlestand":
        box(cv, H, 4, 0.6, (50, 44, 40))
        cv.rect((cx - 1.5, 30, cx + 1.5, 52), (60, 52, 46))
        cv.poly([(cx - 10, 30), (cx + 10, 30), (cx + 6, 34), (cx - 6, 34)], (90, 80, 70))
        for x in (cx - 8, cx - 3, cx + 2, cx + 7):
            cv.rect((x, 23, x + 2, 30), (250, 240, 214))
            cv.ellipse((x - 1, 18, x + 3, 24), (255, 190, 60, 230))
    elif kind == "altar":
        box(cv, H, 18, 0.8, (236, 230, 216))
        L, R = sides(H, 18, 0.8)
        face(cv, R, 0.08, 0.92, 0.15, 0.85, (200, 36, 52))
        face(cv, R, 0.08, 0.92, 0.8, 0.9, GOLD)
        cv.rect((cx - 1, 20, cx + 1, 32), GOLD); cv.rect((cx - 4, 24, cx + 4, 26), GOLD)
    elif kind == "analoy":
        cv.rect((cx - 1.5, 34, cx + 1.5, 54), (90, 60, 36))
        cv.poly([(cx - 10, 30), (cx + 10, 24), (cx + 10, 30), (cx - 10, 36)], (130, 86, 44))
        cv.rect((cx - 6, 25, cx + 4, 28), (230, 190, 90))
        box(cv, H, 3, 0.5, (70, 50, 34))
    elif kind == "bell":
        cv.rect((10, 12, 38, 16), (90, 62, 38))
        cv.rect((10, 12, 13, 54), (90, 62, 38)); cv.rect((35, 12, 38, 54), (90, 62, 38))
        cv.poly([(cx - 4, 16), (cx + 4, 16), (cx + 11, 40), (cx - 11, 40)], GOLD)
        cv.poly([(cx - 11, 40), (cx + 11, 40), (cx + 13, 44), (cx - 13, 44)], GOLD_D)
        cv.ellipse((cx - 2, 41, cx + 2, 47), (96, 70, 30))
    elif kind in ("font", "chozuya"):
        stone = (170, 174, 184)
        box(cv, H, 14, 0.7, stone)
        L, R = sides(H, 14, 0.7)
        face(cv, R, 0.1, 0.9, 0.7, 0.95, (80, 160, 220))
        if kind == "chozuya":
            cv.rect((cx - 10, 14, cx + 10, 17), (110, 70, 40))
            cv.rect((cx - 10, 14, cx - 8, 36), (110, 70, 40)); cv.rect((cx + 8, 14, cx + 10, 36), (110, 70, 40))
            cv.line([(cx - 14, 44), (cx - 4, 36)], (160, 110, 60), 1.4)
        else:
            cv.rect((cx - 1, 20, cx + 1, 30), GOLD); cv.rect((cx - 4, 23, cx + 4, 25), GOLD)
    elif kind == "ema":
        cv.rect((10, 14, 38, 17), (110, 78, 44))
        cv.rect((10, 14, 12, 52), (110, 78, 44)); cv.rect((36, 14, 38, 52), (110, 78, 44))
        for r in range(3):
            for k in range(5):
                cv.poly([(14 + k * 5, 20 + r * 10), (18 + k * 5, 20 + r * 10), (18 + k * 5, 27 + r * 10), (16 + k * 5, 29 + r * 10), (14 + k * 5, 27 + r * 10)], (222, 190, 140))
    elif kind == "offering":
        box(cv, H, 16, 0.55, (140, 100, 62))
        L, R = sides(H, 16, 0.55)
        for u in (0.25, 0.5, 0.75):
            face(cv, R, u - 0.03, u + 0.03, 0.55, 0.95, (60, 40, 30))
        cv.poly([(cx - 12, 36), (cx + 12, 36), (cx + 8, 30), (cx - 8, 30)], (110, 70, 44))
    elif kind == "cross":
        box(cv, H, 6, 0.55, (150, 152, 162))
        box(cv, H, 4, 0.4, (176, 178, 188), base=6)
        cv.rect((cx - 2, 14, cx + 2, 46), (190, 192, 202)); cv.rect((cx - 9, 22, cx + 9, 26), (190, 192, 202))
        cv.rect((cx - 6, 17, cx + 6, 19), (190, 192, 202)); cv.poly([(cx - 8, 36), (cx + 8, 32), (cx + 8, 34), (cx - 8, 38)], (190, 192, 202))
        cv.poly([(cx - 5, 12), (cx, 8), (cx + 5, 12), (cx + 5, 14), (cx - 5, 14)], (150, 90, 70))
        cv.rect((cx - 1, 14, cx + 1, 46), (214, 216, 226))
    elif kind == "shimenawa":
        cv.rect((10, 22, 14, 52), (130, 90, 58)); cv.rect((34, 22, 38, 52), (130, 90, 58))
        cv.line([(12, 26), (cx, 34), (36, 26)], (236, 224, 190), 2.4)
        for x in (cx - 8, cx, cx + 8):
            cv.poly([(x - 2, 32), (x + 2, 32), (x + 1, 42), (x - 1, 42)], (250, 250, 250))
    else:
        box(cv, H, 14, 0.6, c)
    return sheet, cv.done(seed, 3)


def p_pet(shape, col, seed):
    """Pet monster sprites: dog, cat, rabbit, chicken (32x36)."""
    cv = Canvas(32, 36)
    c = PAL.get(col, PAL["light_gray"])
    d = shade(c, 0.6)
    cv.ellipse((6, 28, 26, 34), (0, 0, 0, 110))
    if shape == "dog":
        cv.ellipse((4, 14, 22, 26), c)
        cv.ellipse((18, 9, 29, 20), shade(c, 1.12))
        cv.poly([(19, 9), (22, 4), (23, 10)], d); cv.poly([(25, 9), (28, 4), (28, 11)], d)
        cv.rect((6, 24, 8, 31), d); cv.rect((10, 24, 12, 31), d); cv.rect((15, 24, 17, 31), d); cv.rect((19, 24, 21, 31), d)
        cv.line([(5, 16), (1, 10)], d, 1.6)
        cv.rect((26, 13, 27, 14), (20, 20, 20)); cv.ellipse((27, 15, 30, 18), (30, 30, 36))
        cv.rect((19, 19, 25, 21), (200, 60, 60))                      # collar
    elif shape == "cat":
        cv.ellipse((5, 16, 22, 26), c)
        cv.ellipse((18, 11, 27, 20), shade(c, 1.1))
        cv.poly([(18, 12), (19, 6), (22, 11)], c); cv.poly([(23, 11), (26, 6), (27, 12)], c)
        cv.rect((7, 24, 9, 31), d); cv.rect((11, 24, 13, 31), d); cv.rect((15, 24, 17, 31), d); cv.rect((19, 24, 21, 31), d)
        cv.line([(5, 18), (2, 12), (4, 8)], d, 1.6)
        cv.rect((21, 14, 22, 15), (120, 255, 120)); cv.rect((24, 14, 25, 15), (120, 255, 120))
    elif shape == "rabbit":
        cv.ellipse((6, 17, 22, 27), c)
        cv.ellipse((17, 13, 26, 22), shade(c, 1.08))
        cv.ellipse((18, 2, 21, 14), c); cv.ellipse((22, 3, 25, 14), c)
        cv.ellipse((19, 4, 20.5, 12), (240, 170, 180)); cv.ellipse((23, 5, 24.5, 12), (240, 170, 180))
        cv.rect((8, 25, 11, 31), d); cv.rect((17, 25, 20, 31), d)
        cv.ellipse((3, 20, 8, 25), (250, 250, 250))
        cv.rect((22, 16, 23, 17), (200, 40, 60))
    else:  # chicken
        cv.ellipse((7, 14, 23, 27), c)
        cv.poly([(7, 18), (2, 14), (3, 24)], d)
        cv.ellipse((19, 8, 27, 16), shade(c, 1.05))
        cv.ellipse((21, 5, 25, 9), (210, 40, 50))
        cv.poly([(26, 11), (31, 12), (26, 14)], (236, 190, 60))
        cv.rect((22, 10, 23, 11), (20, 20, 20))
        cv.line([(13, 26), (13, 31)], (230, 170, 50), 1); cv.line([(17, 26), (17, 31)], (230, 170, 50), 1)
    return cv.done(seed, 2)
