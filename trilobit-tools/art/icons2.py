"""Named-object icons for Bouma: explicit shapes for things whose name says what they look like (newspapers, rocks, signs, skulls...)
and colour words in the name (green, red...) that override the item's own colour so the picture matches the label."""
import re
from iso import Canvas, shade
import icons3

# first matching rule wins; patterns are whole words (plural allowed)
NAMED = [
    ("newspaper", r"newspapers?"), ("note", r"notes?|papers?|sheets? of paper|letters?|flyers?|pamphlets?|leaflets?"),
    ("rock", r"rocks?|stones?|pebbles?|boulders?|cobbles?|limestone|sandstone|granite|rubble chunks?|chunks? of stone"),
    ("skull", r"skulls?"), ("bone", r"bones?|ribs?|femurs?"),
    ("sign_item", r"signs?|placards?"), ("badge", r"badges?|id cards?|medals?"),
    ("wheel", r"wheels?|tires?|tyres?"), ("casing", r"casings?|cartridge cases?"),
    ("sheet", r"sheets?|plates?|panels?|pane"), ("ingot", r"ingots?|bars?|billets?"),
    ("pot", r"pots?|pans?|kettles?|crocks?|vases?"), ("lantern", r"lanterns?|lamps?"),
    ("grenade", r"grenades?|bombs?|mines?"), ("engine", r"engines?|motors?"),
    ("sample", r"samples?|vials?|ampoules?"), ("shard", r"glass|shards?|lenses|lens"),
]
NAMED_RE = [(k, re.compile(r"\b(?:" + p + r")\b")) for k, p in NAMED]
COLORS = [("light green", "light_green"), ("light blue", "light_blue"), ("light red", "light_red"), ("green", "green"), ("red", "red"),
          ("blue", "blue"), ("yellow", "yellow"), ("white", "white"), ("black", "black"), ("pink", "pink"), ("brown", "brown"),
          ("purple", "magenta"), ("magenta", "magenta"), ("cyan", "cyan"), ("orange", "yellow"), ("gray", "light_gray"), ("grey", "light_gray")]
BASE = {"newspaper": "white", "note": "white", "rock": "light_gray", "skull": "white", "bone": "white", "pot": "dark_gray", "lantern": "yellow",
        "casing": "yellow", "ingot": "light_gray", "sheet": "light_gray", "shard": "light_cyan", "wheel": "dark_gray"}


def named_kind(name):
    n = name.lower()
    for k, rx in NAMED_RE:
        if rx.search(n):
            col = None
            for w, c in COLORS:
                if re.search(r"\b" + w + r"\b", n):
                    col = c
                    break
            return k, col
    return None


def draw(kind, c, d, l, cv, PAL):
    if kind.endswith('3') or kind.startswith('m_'):
        return icons3.draw(kind, c, d, l, cv, PAL)
    ink = (36, 38, 50)
    if kind == "newspaper":
        cv.rect((5, 7, 26, 26), (226, 224, 214)); cv.rect((5, 7, 26, 9), (150, 148, 140))
        cv.rect((7, 11, 24, 14), (40, 40, 46))  # masthead
        for y in (16, 19, 22):
            cv.rect((7, y, 15, y + 1), (110, 108, 104)); cv.rect((17, y, 24, y + 1), (110, 108, 104))
        cv.rect((7, 24, 24, 25), (150, 148, 140))
    elif kind == "note":
        cv.poly([(8, 5), (22, 5), (25, 8), (25, 27), (8, 27)], (240, 238, 226))
        for y in (11, 14, 17, 20, 23):
            cv.rect((11, y, 22, y + 1), (130, 130, 150))
    elif kind == "rock":
        cv.poly([(5, 24), (7, 14), (13, 8), (21, 9), (27, 16), (26, 24), (16, 27)], c)
        cv.poly([(7, 14), (13, 8), (21, 9), (16, 14)], l)
        cv.poly([(16, 14), (27, 16), (26, 24), (16, 27)], d)
        cv.line([(12, 18), (17, 22)], d, 1)
    elif kind == "skull":
        cv.ellipse((7, 4, 25, 20), c); cv.rect((11, 17, 21, 26), c)
        cv.ellipse((10, 11, 15, 17), ink); cv.ellipse((17, 11, 22, 17), ink)
        cv.poly([(16, 17), (14, 21), (18, 21)], ink)
        for x in (12, 15, 18): cv.rect((x, 23, x + 1, 26), ink)
    elif kind == "bone":
        cv.line([(8, 24), (24, 8)], c, 4)
        for p in ((6, 22), (10, 26), (22, 6), (26, 10)): cv.ellipse((p[0] - 3, p[1] - 3, p[0] + 3, p[1] + 3), c)
    elif kind == "sign_item":
        cv.rect((15, 14, 17, 28), (120, 84, 56)); cv.rect((4, 4, 28, 16), c); cv.rect((4, 4, 28, 6), l); cv.rect((6, 9, 26, 10), d); cv.rect((6, 12, 20, 13), d)
    elif kind == "badge":
        cv.poly([(16, 4), (26, 9), (24, 21), (16, 28), (8, 21), (6, 9)], c); cv.ellipse((11, 10, 21, 20), l); cv.ellipse((13, 12, 19, 18), d)
    elif kind == "wheel":
        cv.ellipse((4, 4, 28, 28), (24, 24, 30)); cv.ellipse((9, 9, 23, 23), (150, 154, 168)); cv.ellipse((13, 13, 19, 19), (60, 62, 74))
    elif kind == "casing":
        cv.rect((11, 6, 21, 26), c); cv.rect((11, 6, 21, 9), l); cv.rect((9, 24, 23, 27), d); cv.ellipse((13, 22, 19, 26), (70, 60, 40))
    elif kind == "sheet":
        cv.poly([(4, 10), (22, 6), (28, 12), (10, 18)], l); cv.poly([(10, 18), (28, 12), (28, 16), (10, 22)], d); cv.poly([(4, 10), (10, 18), (10, 22), (4, 14)], c)
    elif kind == "ingot":
        cv.poly([(6, 14), (10, 9), (24, 9), (28, 14)], l); cv.rect((6, 14, 28, 24), c); cv.rect((6, 21, 28, 24), d)
    elif kind == "pot":
        cv.rect((7, 12, 25, 25), c); cv.ellipse((6, 9, 26, 15), d); cv.ellipse((8, 10, 24, 14), shade(c, 0.4)); cv.rect((3, 15, 7, 17), d); cv.rect((25, 15, 29, 17), d)
    elif kind == "lantern":
        cv.rect((10, 6, 22, 8), d); cv.rect((11, 8, 21, 24), (255, 214, 120)); cv.rect((13, 10, 19, 22), (255, 244, 190)); cv.rect((10, 24, 22, 26), d)
        cv.line([(12, 6), (16, 2), (20, 6)], d, 1)
    elif kind == "grenade":
        cv.ellipse((8, 10, 24, 27), c); cv.rect((13, 5, 19, 11), d); cv.line([(19, 6), (25, 4)], (200, 200, 210), 1); cv.line([(10, 17), (22, 17)], d, 1)
        cv.line([(10, 21), (22, 21)], d, 1)
    elif kind == "engine":
        cv.rect((6, 10, 26, 26), (90, 94, 110)); cv.rect((8, 6, 14, 10), c); cv.rect((18, 6, 24, 10), c); cv.rect((6, 10, 26, 13), (150, 154, 170)); cv.rect((10, 17, 22, 23), d)
    elif kind == "sample":
        cv.rect((12, 6, 20, 9), (160, 164, 176)); cv.rect((12, 9, 20, 27), (210, 230, 240)); cv.rect((12, 17, 20, 27), c); cv.rect((12, 17, 20, 19), l)
    elif kind == "shard":
        cv.poly([(6, 22), (14, 5), (20, 18), (27, 10), (24, 26)], (170, 228, 240)); cv.poly([(14, 5), (20, 18), (14, 20)], (230, 250, 255))
    else:
        return False
    return True
