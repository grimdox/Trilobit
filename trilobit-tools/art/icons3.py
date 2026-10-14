"""More named-object icons for Bouma (Milestone 23): the 1,480 items that used to fall back to a generic gem.
icons2.named_kind() tries its own rules first and then NAMED3 here; items.classify_item() then tries a MATERIAL fallback
(metal, wood, plastic, cloth, leather, glass, paper, stone) before the gem, so every item gets a shape that fits what it is made of."""
import re
from iso import Canvas, shade

NAMED3 = [
    ("corpse3", r"corpses?|carcass(?:es)?|bodies"),
    ("drone3", r"drones?|bots?|robots?|droids?|turrets?|crows|rover"),
    ("tank3", r"tanks?|canisters?|cylinders?|drums?|kegs?|barrels?|gallon|jerry ?cans?|propane|oxygen"),
    ("appliance3", r"cookers?|ovens?|stoves?|heaters?|generators?|presses|press|kilns?|vacuum|fridges?|freezers?|machines?|furnaces?|grills?|conditioners?|washers?|dryers?|concentrators?|extruders?|emitters?|blenders?|toasters?|microwaves?|dehydrators?|dispensers?|coolers?|boilers?"),
    ("map3", r"maps?|reports?|brochures?|catalogs?|catalogues?|manuals?|certificates?|tickets?|licen[sc]es?|advertising|posters?|patterns?|magazines?|pages?"),
    ("painting3", r"paintings?|portraits?|frames?"),
    ("chair3", r"chairs?|stools?|benche?s?|sofas?|couch(?:es)?|seats?"),
    ("pillow3", r"pillows?|cushions?|mattress(?:es)?|blankets?|towels?|quilts?|futons?"),
    ("cup3", r"cups?|bowls?|mugs?|tankards?|ladles?|funnels?|dish(?:es)?|goblets?|chalices?|spoons?|forks?|chopsticks?|saucers?"),
    ("rod3", r"rods?|poles?|shafts?|handles?|dowels?|spars?|ski|oars?|pipes?|tubes?|struts?"),
    ("trap3", r"traps?|snares?|caltrops?|bear ?traps?"),
    ("anvil3", r"anvils?|molds?|moulds?|crucibles?|tongs|forge|bellows?|bellow"),
    ("chunk3", r"chunks?|scraps?|lumps?|bricks?|clay|charcoal|ores?|clods?|bundles?|pieces?|slag|shards? of|cement|gravel|sand|salt"),
    ("guards3", r"guards?|pads?|greaves|pauldrons?|patch(?:es)?|plating|plates? armou?r|shoulders?|pairs? of"),
    ("hook3", r"fishing|lures?|hooks?|baits?|nets?|reels?|spools?"),
    ("dice3", r"dominoes|mahjong|cards|dice|chess|checkers|game|puzzle|toys?|dolls?|balls?"),
    ("wallet3", r"wallets?|purses?|handbags?|billfolds?"),
    ("ladder3", r"ladders?|stepladders?|scaffold(?:ing)?"),
    ("gear3", r"gears?|pseudo|debug|cogs?|sprockets?|bearings?|springs?|pistons?|valves?|pumps?|fans?|hinges?|bolts?|nuts?|screws?|nails?|washers?|gaskets?"),
    ("plant3", r"roots?|bulbs?|tubers?|seeds?|leaf|leaves|herbs?|moss|bark|branch(?:es)?|twigs?|logs?|planks?|boards?|lumber|sticks?|stalks?|flowers?|petals?"),
    ("cloth3", r"cotton|cloth|fabrics?|rags?|threads?|yarn|wool|silk|fur|hides?|leather|tarps?|canvas|sheets?|ropes?|bandages?"),
    ("crystal3", r"rifts?|portals?|alien|exodii|crystals?|artifacts?|gems?|jewels?|orbs?|shards?"),
    ("bottle3", r"bottles?|jars?|jugs?|flasks?|vials?|cans?|tins?"),
]
NAMED3_RE = [(k, re.compile(r"\b(?:" + p + r")\b")) for k, p in NAMED3]
MAT_KIND = {"steel": "m_metal", "iron": "m_metal", "aluminum": "m_metal", "copper": "m_metal", "brass": "m_metal", "bronze": "m_metal", "superalloy": "m_metal",
            "lead": "m_metal", "silver": "m_metal", "gold": "m_metal", "tin": "m_metal", "qt_steel": "m_metal", "mc_steel": "m_metal", "hc_steel": "m_metal", "lc_steel": "m_metal",
            "wood": "m_wood", "plastic": "m_plastic", "cotton": "cloth3", "wool": "cloth3", "leather": "cloth3", "fur": "cloth3", "canvas": "cloth3", "nylon": "cloth3", "silk": "cloth3",
            "glass": "m_glass", "paper": "map3", "cardboard": "m_wood", "stone": "m_stone", "clay": "m_stone", "ceramic": "m_stone", "concrete": "m_stone", "rubber": "m_plastic",
            "powder": "m_stone", "bone": "m_stone", "veggy": "plant3", "flesh": "m_stone"}


def material_kind(mats):
    for m in mats or []:
        t = m["type"] if isinstance(m, dict) else m
        if t in MAT_KIND:
            return MAT_KIND[t]
    return None


def named_kind3(name):
    n = name.lower()
    for k, rx in NAMED3_RE:
        if rx.search(n):
            return k
    return None


METAL, WOOD, PLASTIC, GLASS, INK = (150, 156, 170), (150, 108, 70), (92, 100, 118), (140, 210, 225), (36, 38, 50)


def draw(kind, c, d, l, cv, PAL):
    if kind == "drone3":
        cv.ellipse((6, 11, 26, 24), c); cv.ellipse((8, 12, 24, 17), l)
        cv.rect((2, 9, 11, 10), d); cv.rect((21, 9, 30, 10), d); cv.rect((15, 6, 17, 11), d)
        cv.ellipse((13, 16, 19, 22), (60, 235, 255)); cv.ellipse((15, 18, 17, 20), (230, 255, 255))
        cv.rect((10, 24, 12, 27), d); cv.rect((20, 24, 22, 27), d)
    elif kind == "tank3":
        cv.rect((9, 8, 23, 27), c); cv.ellipse((9, 5, 23, 11), l); cv.ellipse((9, 24, 23, 30), d)
        cv.rect((9, 14, 23, 16), d); cv.rect((9, 21, 23, 23), d); cv.rect((14, 3, 18, 6), METAL); cv.rect((12, 2, 20, 3), shade(METAL, .7))
    elif kind == "appliance3":
        cv.rect((5, 6, 27, 27), c); cv.rect((5, 6, 27, 9), l); cv.rect((5, 25, 27, 27), d)
        cv.rect((8, 12, 20, 23), shade(c, .55)); cv.rect((9, 13, 19, 22), (30, 44, 58)); cv.rect((10, 14, 14, 16), (255, 170, 50))
        cv.ellipse((22, 12, 26, 16), METAL); cv.ellipse((22, 18, 26, 22), METAL); cv.rect((23, 13, 24, 15), INK)
    elif kind == "map3":
        cv.poly([(5, 8), (12, 6), (19, 8), (27, 6), (27, 25), (19, 27), (12, 25), (5, 27)], (232, 226, 200))
        cv.line([(12, 6), (12, 25)], (200, 192, 160), 1); cv.line([(19, 8), (19, 27)], (200, 192, 160), 1)
        cv.line([(7, 20), (13, 14), (18, 19), (25, 11)], (190, 60, 60), 1); cv.rect((22, 21, 24, 23), (60, 90, 190))
    elif kind == "painting3":
        cv.rect((4, 6, 28, 26), WOOD); cv.rect((7, 9, 25, 23), (200, 220, 230))
        cv.poly([(7, 23), (13, 15), (18, 21), (22, 17), (25, 23)], (70, 110, 80)); cv.ellipse((19, 10, 23, 14), (250, 220, 90))
    elif kind == "chair3":
        cv.rect((9, 5, 12, 20), c); cv.rect((9, 5, 22, 8), l); cv.rect((8, 17, 24, 21), c); cv.rect((8, 17, 24, 18), l)
        cv.rect((9, 21, 11, 28), d); cv.rect((21, 21, 23, 28), d)
    elif kind == "pillow3":
        cv.poly([(5, 10), (27, 8), (28, 22), (6, 24)], c); cv.poly([(5, 10), (27, 8), (24, 12), (8, 14)], l)
        cv.line([(6, 24), (28, 22)], d, 1)
    elif kind == "cup3":
        cv.poly([(7, 11), (25, 11), (22, 25), (10, 25)], c); cv.ellipse((7, 8, 25, 14), l); cv.ellipse((9, 9, 23, 13), shade(c, .45))
        cv.ellipse((22, 14, 28, 21), c); cv.ellipse((24, 16, 26, 19), (0, 0, 0, 0))
    elif kind == "rod3":
        cv.line([(6, 26), (26, 6)], d, 4); cv.line([(6, 26), (26, 6)], c, 2); cv.rect((5, 25, 8, 28), METAL)
    elif kind == "trap3":
        cv.ellipse((5, 11, 27, 25), METAL); cv.ellipse((8, 14, 24, 22), (0, 0, 0, 0))
        for x in (7, 11, 15, 19, 23): cv.poly([(x, 17), (x + 2, 11), (x + 3, 17)], (210, 214, 224))
        cv.rect((14, 24, 18, 27), d)
    elif kind == "anvil3":
        cv.poly([(5, 10), (28, 10), (25, 15), (20, 16), (21, 23), (24, 26), (8, 26), (11, 23), (12, 16), (9, 15)], METAL)
        cv.rect((5, 10, 28, 12), (200, 206, 218))
    elif kind == "chunk3":
        cv.poly([(5, 22), (8, 13), (14, 9), (21, 11), (27, 17), (25, 25), (14, 27)], c)
        cv.poly([(8, 13), (14, 9), (21, 11), (15, 15)], l); cv.poly([(15, 15), (27, 17), (25, 25), (14, 27)], d)
    elif kind == "guards3":
        cv.poly([(5, 14), (10, 8), (22, 8), (27, 14), (25, 24), (7, 24)], c); cv.poly([(10, 8), (22, 8), (20, 13), (12, 13)], l)
        cv.rect((7, 18, 25, 20), d); cv.rect((15, 9, 17, 23), shade(c, .8))
    elif kind == "hook3":
        cv.line([(16, 4), (16, 20)], METAL, 2); cv.ellipse((11, 17, 21, 27), (0, 0, 0, 0)); cv.line([(16, 20), (16, 25), (21, 25), (22, 20)], METAL, 2)
        cv.ellipse((13, 3, 19, 8), (230, 80, 80))
    elif kind == "dice3":
        cv.rect((6, 10, 18, 22), (240, 236, 226)); cv.rect((16, 14, 27, 25), (220, 60, 70))
        for (x, y) in ((8, 12), (14, 12), (11, 16), (8, 19), (14, 19)): cv.rect((x, y, x + 2, y + 2), INK)
        for (x, y) in ((19, 16), (24, 16), (21, 20), (19, 22), (24, 22)): cv.rect((x, y, x + 2, y + 2), (250, 240, 230))
    elif kind == "wallet3":
        cv.rect((5, 9, 27, 24), c); cv.rect((5, 9, 27, 13), l); cv.rect((21, 14, 27, 20), d); cv.ellipse((23, 16, 26, 19), (230, 200, 90))
    elif kind == "ladder3":
        cv.line([(10, 4), (6, 28)], METAL, 2); cv.line([(22, 4), (26, 28)], METAL, 2)
        for y in (9, 14, 19, 24): cv.rect((9 - (y - 9) // 6, y, 23 + (y - 9) // 6, y + 1), METAL)
    elif kind == "gear3":
        cv.ellipse((6, 6, 26, 26), c)
        for (x, y) in ((14, 2), (14, 25), (2, 14), (25, 14), (5, 5), (22, 5), (5, 22), (22, 22)): cv.rect((x, y, x + 4, y + 4), c)
        cv.ellipse((11, 11, 21, 21), (0, 0, 0, 0)); cv.ellipse((13, 13, 19, 19), d)
    elif kind == "plant3":
        cv.line([(16, 27), (16, 12)], (90, 130, 70), 2); cv.poly([(16, 14), (7, 10), (11, 18)], (96, 170, 90)); cv.poly([(16, 17), (25, 12), (22, 21)], (84, 150, 80))
        cv.poly([(16, 12), (13, 4), (19, 4)], (120, 190, 100)); cv.rect((10, 26, 22, 28), (120, 90, 60))
    elif kind == "cloth3":
        cv.poly([(5, 10), (13, 7), (21, 10), (28, 8), (26, 24), (19, 26), (12, 24), (6, 26)], c)
        cv.line([(13, 7), (12, 24)], d, 1); cv.line([(21, 10), (19, 26)], d, 1); cv.poly([(5, 10), (13, 7), (21, 10), (13, 12)], l)
    elif kind == "crystal3":
        cv.poly([(16, 3), (24, 12), (20, 27), (12, 27), (8, 12)], (150, 230, 250)); cv.poly([(16, 3), (24, 12), (16, 14)], (230, 255, 255))
        cv.poly([(16, 14), (20, 27), (12, 27)], (70, 150, 200)); cv.line([(16, 3), (16, 27)], (210, 245, 255), 1)
    elif kind == "bottle3":
        cv.rect((11, 12, 21, 27), GLASS); cv.rect((14, 5, 18, 12), GLASS); cv.rect((13, 3, 19, 6), WOOD)
        cv.rect((12, 19, 20, 27), c); cv.rect((12, 15, 14, 24), (230, 250, 255))
    elif kind == "corpse3":
        cv.ellipse((4, 20, 28, 28), (0, 0, 0, 90)); cv.ellipse((4, 12, 12, 20), (190, 160, 140)); cv.rect((10, 14, 25, 21), c)
        cv.rect((24, 15, 28, 18), d); cv.rect((24, 18, 28, 21), d)
    elif kind == "m_metal":
        cv.poly([(4, 20), (9, 10), (24, 8), (28, 18), (22, 26), (8, 26)], c if c != (0, 0, 0) else METAL)
        cv.poly([(9, 10), (24, 8), (28, 18), (17, 17)], l); cv.rect((10, 20, 20, 22), d); cv.ellipse((17, 12, 20, 15), (240, 240, 250))
    elif kind == "m_wood":
        cv.rect((6, 10, 26, 24), WOOD); cv.rect((6, 10, 26, 13), shade(WOOD, 1.25)); cv.ellipse((21, 12, 25, 20), shade(WOOD, .6))
        cv.line([(8, 17), (18, 17)], shade(WOOD, .7), 1); cv.line([(9, 21), (17, 21)], shade(WOOD, .7), 1)
    elif kind == "m_plastic":
        cv.rect((6, 8, 26, 25), PLASTIC); cv.rect((6, 8, 26, 11), shade(PLASTIC, 1.3)); cv.rect((6, 22, 26, 25), shade(PLASTIC, .7))
        cv.rect((9, 14, 15, 19), shade(PLASTIC, .5)); cv.ellipse((19, 14, 23, 18), (80, 240, 255))
    elif kind == "m_glass":
        cv.poly([(7, 7), (25, 7), (27, 25), (5, 25)], (180, 226, 238)); cv.poly([(7, 7), (25, 7), (20, 12)], (240, 252, 255)); cv.line([(10, 22), (22, 10)], (255, 255, 255), 1)
    elif kind == "m_stone":
        cv.poly([(5, 24), (7, 14), (13, 8), (21, 9), (27, 16), (26, 24), (16, 27)], (140, 138, 130))
        cv.poly([(7, 14), (13, 8), (21, 9), (16, 14)], (180, 178, 168)); cv.poly([(16, 14), (27, 16), (26, 24), (16, 27)], (100, 98, 94))
