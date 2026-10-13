"""Item icons (32x32), vehicle part sprites (48x48) and field overlays (48x36) for the Bouma tileset, drawn from code.
classify_item / classify_vpart / classify_field sort every definition into a drawn kind."""
import re, random
import numpy as np
from PIL import Image
from iso import Canvas, box, face, sides, diamond, shade, mix

PAL = {
    "black": (30, 30, 40), "red": (170, 56, 66), "green": (62, 140, 86), "brown": (132, 94, 62), "blue": (66, 90, 170),
    "magenta": (160, 66, 160), "cyan": (56, 150, 160), "light_gray": (176, 178, 188), "dark_gray": (92, 94, 108),
    "light_red": (232, 100, 110), "light_green": (120, 210, 130), "yellow": (232, 208, 90), "light_blue": (112, 150, 240),
    "pink": (238, 142, 190), "light_cyan": (130, 226, 238), "white": (232, 236, 244),
}
NEON = {"cyan": (60, 235, 255), "magenta": (255, 70, 200), "green": (90, 255, 140), "amber": (255, 170, 50), "red": (255, 70, 80)}
DARK = (24, 24, 34)


def pal(c):
    c = (c or "light_gray")
    if isinstance(c, list):
        c = c[0] if c else "light_gray"
    c = re.sub(r"^(c_|i_|h_)", "", str(c))
    c = {"ltgray": "light_gray", "dkgray": "dark_gray", "ltred": "light_red", "ltgreen": "light_green", "ltblue": "light_blue", "ltcyan": "light_cyan"}.get(c, c)
    if c in PAL:
        return c
    for name in sorted(PAL, key=len, reverse=True):
        if c.startswith(name + "_") or c.startswith(name):
            return name
    return "light_gray"


def rgb(c):
    return PAL[pal(c)]


def has(s, *w):
    return any(x in s for x in w)


def outline(img, col=(16, 16, 24)):
    a = np.array(img)
    solid = a[..., 3] > 40
    pad = np.pad(solid, 1)
    near = pad[:-2, 1:-1] | pad[2:, 1:-1] | pad[1:-1, :-2] | pad[1:-1, 2:]
    edge = near & ~solid
    a[edge] = (col[0], col[1], col[2], 255)
    return Image.fromarray(a)


# ------------------------------------------------------------------ items
def classify_item(i, o):
    n = (o.get("name") or {})
    n = (n.get("str") or n.get("str_sp") or "") if isinstance(n, dict) else str(n)
    s = (i + " " + n).lower()
    st = set(o.get("subtypes") or [])
    t = o.get("type")
    col = pal(o.get("color"))
    if "GUN" in st or t == "GUN":
        sk = str(o.get("skill") or "")
        if "archery" in sk or has(s, "bow", "crossbow"):
            return ("bow", col)
        if "launcher" in sk or has(s, "launcher", "rocket"):
            return ("launcher", col)
        if sk in ("pistol",) or has(s, "pistol", "revolver", "handgun"):
            return ("pistol", col)
        if sk == "shotgun" or has(s, "shotgun"):
            return ("shotgun", col)
        if sk == "smg" or has(s, "smg", "submachine"):
            return ("smg", col)
        if has(s, "laser", "beam"):
            return ("laser", col)
        return ("rifle", col)
    if "MAGAZINE" in st or t == "MAGAZINE":
        return ("magazine", col)
    if "AMMO" in st or t == "AMMO":
        if has(s, "shell", "gauge", "slug", "buckshot"):
            return ("shell", col)
        if has(s, "arrow", "bolt", "dart"):
            return ("arrow", col)
        return ("rounds", col)
    if "BIONIC_ITEM" in st or t == "BIONIC_ITEM":
        return ("chip", col)
    if "BOOK" in st or t == "BOOK":
        return ("book", col)
    if "COMESTIBLE" in st or t == "COMESTIBLE":
        ct = str(o.get("comestible_type") or "")
        if ct == "MED" or has(s, "pill", "tablet", "capsule", "syringe", "injector", "bandage", "aspirin", "vitamin"):
            if has(s, "bandage", "gauze", "splint"):
                return ("bandage", col)
            if has(s, "syringe", "injector", "inject", "shot"):
                return ("syringe", col)
            return ("pills", col)
        if ct == "DRINK" or has(s, "bottle", "juice", "soda", "beer", "wine", "sake", "water", "tea", "coffee", "milk", "cola", "drink"):
            return ("bottle" if not has(s, "can ") else "can", col)
        if has(s, "can of", "canned", "tin"):
            return ("can", col)
        return ("food", col)
    if "ARMOR" in st or "TOOL_ARMOR" in st or "PET_ARMOR" in st or t in ("ARMOR", "TOOL_ARMOR", "PET_ARMOR"):
        cv = " ".join(map(str, o.get("covers") or [])) + " " + str(o.get("armor") or "")
        if has(s, "helmet", "hardhat", "hard hat"):
            return ("helmet", col)
        if has(s, "hat", "cap", "beret", "hood", "crown", "mask") or ("head" in cv and "torso" not in cv):
            return ("hat", col)
        if has(s, "goggle", "glasses", "visor", "eyewear", "shades"):
            return ("goggles", col)
        if has(s, "glove", "gauntlet", "mitt") or ("hand" in cv and "torso" not in cv):
            return ("glove", col)
        if has(s, "boot", "shoe", "sneaker", "sandal", "sock", "slipper", "foot") or ("foot" in cv and "leg" not in cv):
            return ("boot", col)
        if has(s, "pants", "jeans", "trousers", "shorts", "skirt", "leggings", "greaves", "chaps") or ("leg" in cv and "torso" not in cv):
            return ("pants", col)
        if has(s, "backpack", "bag", "satchel", "rucksack", "pack"):
            return ("bag", col)
        if has(s, "vest", "armor", "plate", "cuirass", "kevlar"):
            return ("vest", col)
        if has(s, "coat", "jacket", "trench", "cloak", "robe", "kimono", "poncho", "hoodie", "sweater"):
            return ("jacket", col)
        return ("shirt", col)
    if "GUNMOD" in st or t == "GUNMOD":
        return ("mod", col)
    if "BATTERY" in st or has(s, "battery", "cell"):
        return ("battery", col)
    # melee and everything else, by name
    if has(s, "katana", "sword", "knife", "dagger", "tanto", "wakizashi", "nodachi", "machete", "blade", "kama", "sickle", "cleaver", "scalpel", "razor", "saber", "sabre", "scythe"):
        return ("blade", col)
    if has(s, "spear", "yari", "naginata", "javelin", "pike", "halberd", "lance"):
        return ("spear", col)
    if has(s, "axe", "hatchet", "tomahawk"):
        return ("axe", col)
    if has(s, "shuriken", "star", "kunai"):
        return ("star", col)
    if has(s, "hammer", "mallet", "club", "bat ", " bat", "baton", "staff", "nunchaku", "pipe", "crowbar", "wrench", "tonfa", "cane", "bo ", "sledge", "flail", "mace"):
        return ("blunt", col)
    if has(s, "chip", "data", "card", "usb", "cpu", "processor", "ram", "circuit", "disk", "drive"):
        return ("chip", col)
    if has(s, "phone", "radio", "laptop", "computer", "tablet", "camera", "scanner", "monitor", "screen", "device", "detector", "remote", "gps", "lcd", "tv"):
        return ("device", col)
    if has(s, "cable", "wire", "rope", "cord", "chain", "tether"):
        return ("coil", col)
    if has(s, "screwdriver", "wrench", "pliers", "saw", "drill", "welder", "tool", "kit", "torch", "lighter", "flashlight", "lamp", "light"):
        return ("tool", col)
    if has(s, "box", "case", "crate", "chest", "container", "jar", "bin", "barrel", "pouch", "sack"):
        return ("box", col)
    if has(s, "bottle", "flask", "vial", "canteen", "jug"):
        return ("bottle", col)
    if has(s, "key", "token", "coin", "yen", "cash", "money", "chit"):
        return ("coin", col)
    return ("gem", col)


def p_item(kind, col, seed):
    cv = Canvas(32, 32)
    c = PAL[col]
    d = shade(c, 0.55)
    l = shade(c, 1.25)
    rnd = random.Random(seed)
    steel = (176, 182, 196)
    if kind in ("pistol", "smg", "shotgun", "rifle", "laser", "launcher"):
        L = {"pistol": 12, "smg": 16, "shotgun": 22, "rifle": 22, "laser": 16, "launcher": 22}[kind]
        x0 = 16 - L // 2
        body = (60, 62, 74) if kind != "laser" else (84, 90, 110)
        cv.rect((x0, 12, x0 + L, 16), body)
        cv.rect((x0 + L - 4 if kind != "launcher" else x0, 13, x0 + L + 4 if kind != "launcher" else x0 + L + 4, 15), shade(body, 0.8))
        cv.rect((x0 + 2, 16, x0 + 5, 22), body)
        if kind in ("rifle", "shotgun", "smg"):
            cv.poly([(x0 - 4, 14), (x0 + 1, 12), (x0 + 1, 18), (x0 - 4, 21)], c)
            cv.rect((x0 + 8, 16, x0 + 10, 21), shade(body, 0.8))
        if kind == "launcher":
            cv.rect((x0, 10, x0 + L + 2, 17), c)
        if kind == "laser":
            cv.rect((x0 + L, 13, x0 + L + 4, 15), NEON["cyan"])
        cv.rect((x0 + 1, 11, x0 + 4, 12), l)
    elif kind == "bow":
        cv.line([(10, 5), (6, 16), (10, 27)], c, 2)
        cv.line([(10, 5), (10, 27)], (230, 230, 220), 0.6)
        cv.line([(10, 16), (24, 16)], (150, 110, 70), 1)
        cv.poly([(24, 14), (28, 16), (24, 18)], steel)
    elif kind == "blade":
        cv.poly([(8, 24), (22, 6), (24, 8), (11, 26)], steel)
        cv.line([(9, 25), (23, 7)], (240, 244, 250), 0.7)
        cv.poly([(6, 22), (9, 20), (13, 25), (10, 27)], c)
        cv.rect((5, 25, 9, 28), d)
    elif kind == "spear":
        cv.line([(6, 27), (22, 9)], (140, 100, 66), 1.8)
        cv.poly([(22, 9), (27, 4), (26, 11)], steel)
    elif kind == "axe":
        cv.line([(7, 27), (21, 7)], (140, 100, 66), 1.8)
        cv.poly([(17, 6), (26, 8), (24, 15), (20, 13)], steel)
    elif kind == "blunt":
        cv.line([(7, 26), (22, 9)], c, 2.6)
        cv.poly([(19, 6), (26, 11), (23, 14), (17, 9)], shade(c, 0.8))
    elif kind == "star":
        cv.poly([(16, 6), (19, 13), (26, 16), (19, 19), (16, 26), (13, 19), (6, 16), (13, 13)], steel)
        cv.ellipse((14, 14, 18, 18), DARK)
    elif kind == "magazine":
        cv.poly([(11, 6), (20, 6), (22, 26), (13, 26)], (66, 68, 82))
        cv.rect((11, 4, 20, 7), c)
        for y in (12, 17, 22):
            cv.line([(12, y), (21, y)], (110, 112, 126), 0.6)
    elif kind == "rounds":
        for k, x in enumerate((9, 14, 19, 24)):
            cv.rect((x, 12, x + 3, 24), (214, 176, 80))
            cv.poly([(x, 12), (x + 3, 12), (x + 1.5, 6)], c if k % 2 else (190, 120, 60))
    elif kind == "shell":
        for x in (10, 17):
            cv.rect((x, 8, x + 6, 24), c)
            cv.rect((x, 20, x + 6, 24), (214, 176, 80))
    elif kind == "arrow":
        cv.line([(5, 27), (26, 6)], (150, 110, 70), 1.2)
        cv.poly([(26, 6), (29, 3), (28, 9)], steel)
        cv.poly([(4, 28), (8, 26), (6, 24)], c)
    elif kind == "chip":
        cv.rect((9, 9, 23, 23), (34, 38, 52))
        cv.rect((12, 12, 20, 20), c)
        for k in range(4):
            cv.rect((10 + k * 4, 6, 11 + k * 4, 9), (214, 190, 90))
            cv.rect((10 + k * 4, 23, 11 + k * 4, 26), (214, 190, 90))
        cv.rect((14, 14, 18, 18), l)
    elif kind == "book":
        cv.rect((8, 7, 24, 25), c)
        cv.rect((8, 7, 11, 25), d)
        cv.rect((13, 11, 21, 13), (236, 236, 226))
        cv.rect((13, 15, 19, 16), (236, 236, 226))
    elif kind == "bandage":
        cv.ellipse((8, 9, 24, 23), (240, 240, 232))
        cv.ellipse((13, 13, 19, 19), (170, 60, 60) if col in ("red", "light_red") else d)
    elif kind == "syringe":
        cv.rect((8, 14, 22, 18), (220, 226, 232))
        cv.rect((9, 15, 18, 17), c)
        cv.line([(22, 16), (28, 16)], steel, 1)
        cv.rect((4, 12, 8, 20), steel)
    elif kind == "pills":
        cv.rect((10, 10, 22, 26), (220, 222, 228))
        cv.rect((10, 7, 22, 11), c)
        cv.rect((12, 15, 20, 21), shade(c, 1.1))
    elif kind in ("bottle", "can"):
        if kind == "bottle":
            cv.rect((12, 6, 20, 10), (190, 200, 210))
            cv.poly([(12, 10), (20, 10), (23, 14), (23, 27), (9, 27), (9, 14)], (200, 208, 220))
            cv.rect((10, 17, 22, 26), c)
        else:
            cv.rect((9, 8, 23, 26), c)
            cv.rect((9, 8, 23, 10), steel)
            cv.rect((9, 24, 23, 26), steel)
    elif kind == "food":
        cv.ellipse((6, 11, 26, 25), (220, 210, 190))
        cv.ellipse((9, 13, 23, 22), c)
        cv.ellipse((12, 14, 18, 18), l)
    elif kind == "hat":
        cv.ellipse((5, 17, 27, 25), d)
        cv.ellipse((9, 8, 23, 22), c)
    elif kind == "helmet":
        cv.ellipse((7, 7, 25, 25), c)
        cv.rect((7, 17, 25, 21), d)
        cv.rect((10, 13, 22, 16), (30, 34, 50))
    elif kind == "goggles":
        cv.ellipse((4, 12, 15, 21), (40, 44, 60))
        cv.ellipse((17, 12, 28, 21), (40, 44, 60))
        cv.ellipse((6, 14, 13, 19), NEON["cyan"] if col in ("cyan", "light_cyan", "blue", "light_blue") else c)
        cv.ellipse((19, 14, 26, 19), NEON["cyan"] if col in ("cyan", "light_cyan", "blue", "light_blue") else c)
    elif kind in ("shirt", "jacket", "vest"):
        cv.poly([(5, 10), (12, 6), (20, 6), (27, 10), (24, 15), (21, 13), (21, 26), (11, 26), (11, 13), (8, 15)], c)
        cv.poly([(13, 6), (19, 6), (16, 12)], d)
        if kind == "jacket":
            cv.line([(16, 12), (16, 26)], d, 1)
        if kind == "vest":
            cv.rect((12, 14, 20, 24), d)
    elif kind == "pants":
        cv.poly([(9, 5), (23, 5), (25, 27), (18, 27), (16, 14), (14, 27), (7, 27)], c)
        cv.rect((9, 5, 23, 8), d)
    elif kind == "boot":
        cv.poly([(10, 6), (17, 6), (17, 18), (27, 21), (27, 26), (10, 26)], c)
        cv.rect((10, 24, 27, 27), d)
    elif kind == "glove":
        cv.rect((9, 12, 23, 24), c)
        for x in (9, 13, 17, 21):
            cv.rect((x, 5, x + 3, 13), c)
        cv.rect((10, 22, 22, 26), d)
    elif kind == "bag":
        cv.rect((8, 8, 24, 27), c)
        cv.ellipse((8, 5, 24, 12), d)
        cv.rect((11, 17, 21, 25), d)
        cv.rect((14, 14, 18, 16), l)
    elif kind == "mod":
        cv.rect((7, 12, 25, 20), (66, 68, 82))
        cv.rect((10, 9, 22, 12), c)
        cv.rect((22, 14, 28, 18), l)
    elif kind == "battery":
        cv.rect((8, 8, 24, 26), (40, 44, 58))
        cv.rect((8, 14, 24, 24), c)
        cv.rect((13, 5, 19, 8), steel)
        cv.poly([(17, 13), (13, 20), (16, 20), (15, 26), (20, 17), (17, 17)], (255, 240, 120))
    elif kind == "device":
        cv.rect((6, 8, 26, 24), (40, 44, 58))
        cv.rect((8, 10, 24, 20), shade(NEON["cyan"], 0.55) if col not in ("red", "light_red") else shade(NEON["red"], 0.6))
        cv.rect((8, 10, 24, 12), c)
        cv.rect((12, 22, 20, 23), steel)
    elif kind == "coil":
        for r in (11, 8, 5):
            cv.ellipse((16 - r, 16 - r, 16 + r, 16 + r), c if r % 2 else d)
        cv.ellipse((13, 13, 19, 19), DARK)
    elif kind == "tool":
        cv.line([(8, 25), (20, 11)], (120, 120, 134), 2.4)
        cv.ellipse((17, 5, 27, 14), steel)
        cv.ellipse((20, 6, 25, 11), (0, 0, 0, 0))
        cv.rect((6, 23, 10, 28), c)
    elif kind == "box":
        b, t = box(cv, 32, 12, 0.7, shade(c, 1.0), edge=False, base=2)
    elif kind == "coin":
        cv.ellipse((8, 8, 24, 24), (220, 190, 80))
        cv.ellipse((11, 11, 21, 21), (170, 140, 50))
        cv.rect((15, 12, 17, 20), (235, 210, 110))
    else:  # gem / generic
        cv.poly([(16, 6), (25, 13), (21, 25), (11, 25), (7, 13)], c)
        cv.poly([(16, 6), (25, 13), (16, 15)], l)
        cv.poly([(16, 15), (21, 25), (11, 25)], d)
    img = cv.done(seed, 2)
    return outline(img)


# ------------------------------------------------------------------ vehicle parts
def classify_vpart(i, o):
    n = o.get("name") or {}
    n = (n.get("str") or n.get("str_sp") or "") if isinstance(n, dict) else str(n)
    s = (i + " " + n).lower()
    fl = set(o.get("flags") or [])
    col = pal(o.get("color"))
    loc = str(o.get("location") or "")
    if "WHEEL" in fl or has(s, "wheel", "tire", "tyre", "caster", "tread", "track"):
        return ("wheel", col)
    if has(s, "turret", "gun", "cannon", "launcher", "laser", "mount"):
        return ("turret", col)
    if has(s, "windshield", "window", "glass", "canopy", "visor"):
        return ("window", col)
    if has(s, "headlight", "searchlight", "light", "lamp", "flood", "beacon", "siren"):
        return ("lamp", col)
    if has(s, "seat", "bed", "bench", "cockpit", "saddle", "stool", "chair"):
        return ("seat", col)
    if has(s, "motor", "engine", "turbine", "generator", "thruster", "jet"):
        return ("engine", col)
    if has(s, "battery", "solar", "reactor", "capacitor", "charger", "fuel cell", "panel"):
        return ("battery", col)
    if has(s, "door", "hatch", "aisle", "ramp", "hood", "trunk"):
        return ("door", col)
    if has(s, "tank", "cargo", "storage", "box", "trunk", "locker", "cabinet", "fridge", "freezer", "kitchen", "tool", "rack", "bin"):
        return ("storage", col)
    if has(s, "armor", "plate", "board", "roof", "hull", "frame", "bumper", "spike", "ram", "shield") or "STRUCTURE" in loc.upper():
        return ("plate", col)
    if has(s, "control", "dashboard", "console", "computer", "terminal", "autopilot", "controls", "steering", "handle"):
        return ("console", col)
    return ("part", col)


def p_vpart(kind, col, seed):
    cv = Canvas(48, 48)
    c = PAL[col]
    body = mix(c, (90, 94, 110), 0.55)
    if kind == "wheel":
        L, R = sides(48, 14, 0.5)
        cv.poly(diamond(48, 0.5, 0), (20, 20, 28))
        box(cv, 48, 14, 0.5, (28, 28, 38), left=(18, 18, 26), right=(34, 34, 46), edge=False)
        face(cv, R, 0.2, 0.8, 0.2, 0.8, (60, 62, 76))
    elif kind == "turret":
        box(cv, 48, 8, 0.6, shade(body, 0.8))
        b = diamond(48, 0.3, 8)
        cv.poly(b, shade(body, 1.2))
        cv.line([(24, 22), (36, 28)], (30, 30, 40), 2.2)
    elif kind == "window":
        box(cv, 48, 18, 0.9, (40, 90, 120), left=(30, 70, 100), right=(70, 150, 190), edge=False)
    elif kind == "lamp":
        box(cv, 48, 8, 0.4, (60, 62, 76))
        for r, a in ((12, 40), (8, 80)):
            cv.ellipse((24 - r, 24 - r, 24 + r, 24 + r), NEON["amber"] + (a,))
        cv.ellipse((21, 22, 27, 26), (255, 248, 210))
    elif kind == "seat":
        box(cv, 48, 8, 0.6, body)
        b = diamond(48, 0.6, 8)
        t = diamond(48, 0.6, 22)
        cv.poly([b[0], b[1], t[1], t[0]], shade(body, 0.7))
    elif kind == "engine":
        box(cv, 48, 16, 0.78, (70, 74, 90))
        L, R = sides(48, 16, 0.78)
        for u in (0.2, 0.4, 0.6, 0.8):
            face(cv, R, u, u + 0.06, 0.15, 0.85, (130, 134, 150))
    elif kind == "battery":
        box(cv, 48, 14, 0.72, (40, 44, 58))
        L, R = sides(48, 14, 0.72)
        face(cv, R, 0.15, 0.85, 0.25, 0.75, NEON["green"])
    elif kind == "door":
        box(cv, 48, 26, 0.92, body, edge=False)
        L, R = sides(48, 26, 0.92)
        face(cv, R, 0.1, 0.9, 0.1, 0.9, shade(body, 0.8))
        face(cv, R, 0.75, 0.82, 0.45, 0.55, (230, 230, 240))
    elif kind == "storage":
        box(cv, 48, 18, 0.8, body)
        L, R = sides(48, 18, 0.8)
        face(cv, R, 0.1, 0.9, 0.45, 0.55, shade(body, 0.5))
    elif kind == "plate":
        box(cv, 48, 5, 0.96, body)
    elif kind == "console":
        box(cv, 48, 16, 0.5, (36, 40, 54))
        L, R = sides(48, 16, 0.5)
        face(cv, R, 0.15, 0.85, 0.4, 0.9, NEON["cyan"])
    else:
        box(cv, 48, 8, 0.7, body)
    return cv.done(seed, 2)


# ------------------------------------------------------------------ fields
def classify_field(i, o):
    n = (o.get("intensity_levels") or [{}])[0].get("name", "") if o.get("intensity_levels") else ""
    s = (i + " " + str(n)).lower()
    lv = (o.get("intensity_levels") or [{}])
    col = pal(lv[0].get("color") if lv else None)
    if has(s, "fire", "flame", "burn", "ember", "lava", "plasma", "inferno"):
        return ("fire", col)
    if has(s, "smoke", "fog", "mist", "steam", "dust", "ash"):
        return ("smoke", col)
    if has(s, "blood", "gore", "bile", "ichor", "viscera", "bone", "meat", "hemolymph", "pus", "guts", "gibs", "slime", "sludge"):
        return ("splat", col)
    if has(s, "acid", "toxic", "poison", "gas", "spore", "tear", "nuke", "radiation", "sap", "fungal", "miasma", "stink"):
        return ("gas", col)
    if has(s, "electric", "lightning", "spark", "shock", "emp", "static"):
        return ("spark", col)
    if has(s, "web", "net", "wire"):
        return ("web", col)
    if has(s, "water", "puddle", "rain", "flood", "ice", "frost", "snow", "sludge", "oil", "fuel", "gasoline", "wet"):
        return ("puddle", col)
    if has(s, "zone", "loot", "marker", "highlight", "trail", "light", "glow", "portal", "hole", "rift", "crack", "tear"):
        return ("glow", col)
    return ("blob", col)


def p_field(kind, col, seed):
    cv = Canvas(48, 36)
    c = PAL[col]
    rnd = random.Random(seed)
    if kind == "fire":
        for k in range(6):
            x = 24 + rnd.randint(-10, 10)
            y = 24 + rnd.randint(-3, 3)
            h = rnd.randint(8, 16)
            cv.poly([(x - 4, y), (x, y - h), (x + 4, y)], (255, 110 + rnd.randint(0, 60), 30, 220))
            cv.poly([(x - 2, y), (x, y - h * 0.6), (x + 2, y)], (255, 230, 120, 230))
    elif kind == "smoke":
        for k in range(7):
            x, y = 24 + rnd.randint(-12, 12), 22 + rnd.randint(-5, 4)
            cv.ellipse((x - 7, y - 4, x + 7, y + 4), mix(c, (70, 74, 88), 0.6) + (110,))
    elif kind in ("splat", "puddle"):
        base = (150, 20, 30) if kind == "splat" and col in ("red", "light_red") else c if kind == "splat" else (50, 100, 160)
        for k in range(8):
            x, y = 24 + rnd.randint(-11, 11), 18 + rnd.randint(-4, 4)
            r = rnd.randint(2, 5)
            cv.ellipse((x - r * 1.6, y - r * 0.8, x + r * 1.6, y + r * 0.8), shade(base, 0.7 + rnd.random() * 0.4) + (200,))
    elif kind == "gas":
        for k in range(8):
            x, y = 24 + rnd.randint(-12, 12), 20 + rnd.randint(-5, 5)
            cv.ellipse((x - 8, y - 4, x + 8, y + 4), c + (70,))
    elif kind == "spark":
        for k in range(4):
            x, y = 24 + rnd.randint(-9, 9), 18 + rnd.randint(-3, 3)
            cv.line([(x - 5, y - 3), (x, y + 1), (x - 2, y + 1), (x + 5, y + 5)], NEON["cyan"], 1.2)
    elif kind == "web":
        for a in range(0, 360, 45):
            import math
            cv.line([(24, 18), (24 + 14 * math.cos(math.radians(a)), 18 + 7 * math.sin(math.radians(a)))], (225, 228, 236), 0.6)
        for r in (4, 8, 12):
            cv.line([(24 + r * math.cos(math.radians(a)), 18 + r / 2 * math.sin(math.radians(a))) for a in range(0, 361, 45)], (225, 228, 236), 0.5)
    elif kind == "glow":
        d = diamond(36, 1.0)
        cv.poly(d, c + (90,))
        cv.line(d + [d[0]], c, 0.9)
    else:
        for k in range(4):
            x, y = 24 + rnd.randint(-8, 8), 18 + rnd.randint(-3, 3)
            cv.ellipse((x - 6, y - 3, x + 6, y + 3), c + (140,))
    return cv.done(seed, 0)
