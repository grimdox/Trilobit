"""Item icons (32x32), vehicle part sprites (48x48) and field overlays (48x36) for the Bouma tileset, drawn from code.
classify_item / classify_vpart / classify_field sort every definition into a drawn kind."""
import re, random
import numpy as np
from PIL import Image
from iso import Canvas, box, face, sides, diamond, shade, mix
import icons2
import icons3

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
RELIGIOUS_KINDS = {"trl_omamori": "charm", "trl_ofuda": "talisman", "trl_ema": "ema_plaque", "trl_omikuji": "omikuji", "trl_gohei": "gohei",
                   "trl_icon": "icon_item", "trl_chotki": "prayer_rope", "trl_censer": "censer", "trl_church_candle": "church_candle", "trl_gospel": "gospel"}
ARMOR_KINDS = {"trl_plasteel_armor": "plasteel_suit", "trl_plasteel_helm": "plasteel_helm", "trl_kp_vest": "kp_vest", "trl_kp_helmet": "kp_helmet",
               "trl_plasteel_boots": "plasteel_boots", "trl_plasteel_gloves": "plasteel_gloves"}
PLATE, PLATE_D, PLATE_L = (176, 190, 212), (96, 110, 134), (226, 236, 250)
GRAPH, GRAPH_D = (58, 62, 78), (34, 36, 48)
SEAM = (80, 235, 255)


def _armor_icon(cv, kind):
    """Plasteel and kevlar-plasteel armor icons (original designs), drawn on a 32x32 canvas."""
    if kind == "plasteel_suit":
        cv.rect((9, 24, 23, 28), GRAPH_D)                       # waist and legs hint
        cv.rect((10, 25, 15, 30), PLATE); cv.rect((17, 25, 22, 30), PLATE)
        cv.rect((10, 25, 15, 26), PLATE_L); cv.rect((17, 25, 22, 26), PLATE_L)
        cv.poly([(8, 6), (24, 6), (26, 22), (22, 25), (10, 25), (6, 22)], PLATE)   # breastplate
        cv.poly([(8, 6), (16, 6), (16, 25), (10, 25), (6, 22)], PLATE_D)
        cv.ellipse((2, 4, 10, 12), PLATE); cv.ellipse((22, 4, 30, 12), PLATE)       # pauldrons
        cv.ellipse((3, 5, 9, 9), PLATE_L); cv.ellipse((23, 5, 29, 9), PLATE_L)
        cv.line([(16, 8), (16, 24)], SEAM, 0.9)
        cv.line([(9, 15), (23, 15)], SEAM, 0.7)
        cv.rect((13, 5, 19, 7), GRAPH_D)
    elif kind == "plasteel_helm":
        cv.ellipse((7, 4, 25, 24), PLATE_D)
        cv.ellipse((8, 4, 24, 20), PLATE)
        cv.ellipse((11, 6, 19, 11), PLATE_L)
        cv.rect((10, 15, 22, 17), GRAPH_D)
        cv.rect((11, 15.5, 21, 16.5), SEAM)                 # visor slit
        cv.rect((9, 22, 23, 27), PLATE_D)                   # gorget
        cv.rect((10, 22, 22, 23), PLATE_L)
    elif kind == "kp_vest":
        cv.poly([(8, 5), (13, 5), (16, 8), (19, 5), (24, 5), (25, 24), (7, 24)], GRAPH)
        cv.poly([(8, 5), (13, 5), (16, 8), (16, 24), (7, 24)], GRAPH_D)
        cv.rect((9, 10, 15, 20), PLATE); cv.rect((17, 10, 23, 20), PLATE)
        cv.rect((9, 10, 15, 11), PLATE_L); cv.rect((17, 10, 23, 11), PLATE_L)
        cv.line([(8, 22), (24, 22)], SEAM, 0.8)
        cv.rect((7, 22, 25, 25), GRAPH_D)
    elif kind == "kp_helmet":
        cv.ellipse((6, 5, 26, 24), GRAPH_D)
        cv.ellipse((7, 5, 25, 20), GRAPH)
        cv.rect((7, 15, 25, 17), PLATE)                         # rim
        cv.poly([(7, 16), (12, 16), (12, 25), (8, 24)], GRAPH)   # cheek guards
        cv.poly([(25, 16), (20, 16), (20, 25), (24, 24)], GRAPH)
        cv.ellipse((11, 7, 21, 12), PLATE_D)
        cv.line([(9, 17), (23, 17)], SEAM, 0.6)
        cv.poly([(8, 24), (24, 24), (22, 28), (10, 28)], GRAPH_D)   # neck flare


def _armor_icon2(cv, kind):
    if kind == "plasteel_boots":
        for dx in (0, 11):
            cv.poly([(5 + dx, 8), (12 + dx, 8), (12 + dx, 20), (15 + dx, 24), (15 + dx, 27), (4 + dx, 27), (4 + dx, 20)], PLATE)
            cv.poly([(5 + dx, 8), (8 + dx, 8), (8 + dx, 22), (4 + dx, 20)], PLATE_D)
            cv.rect((5 + dx, 8, 12 + dx, 10), PLATE_L)
            cv.rect((4 + dx, 14, 12 + dx, 15), SEAM)
            cv.rect((4 + dx, 26, 15 + dx, 28), GRAPH_D)
    elif kind == "plasteel_gloves":
        for dx in (0, 12):
            cv.poly([(6 + dx, 14), (14 + dx, 14), (15 + dx, 24), (5 + dx, 24)], PLATE)
            cv.poly([(6 + dx, 14), (9 + dx, 14), (9 + dx, 24), (5 + dx, 24)], PLATE_D)
            for fx in (6, 8.5, 11, 13):
                cv.rect((fx + dx, 8, fx + 1.8 + dx, 14), PLATE_L)
            cv.rect((5 + dx, 17, 15 + dx, 18), SEAM)
            cv.rect((6 + dx, 24, 14 + dx, 27), GRAPH_D)


def p_worn(kind):
    """On-body overlays (32x36, aligned to the character sprite): the armor drawn over the body."""
    cv = Canvas(32, 36)
    if kind == "plasteel_suit":
        cv.rect((11, 21, 16, 31), PLATE); cv.rect((16, 21, 21, 31), PLATE)       # leg plates
        cv.rect((11, 21, 16, 22), PLATE_L); cv.rect((16, 21, 21, 22), PLATE_L)
        cv.rect((11, 26, 16, 27), SEAM); cv.rect((16, 26, 21, 27), SEAM)         # knees
        cv.rect((10, 29, 16, 32), GRAPH_D); cv.rect((16, 29, 22, 32), GRAPH_D)   # boots
        cv.rect((7, 13, 10, 22), PLATE); cv.rect((22, 13, 25, 22), PLATE)        # arm plates
        cv.rect((7, 19, 10, 20), SEAM); cv.rect((22, 19, 25, 20), SEAM)
        cv.rect((9, 11, 23, 23), PLATE)                                          # breastplate
        cv.rect((9, 11, 16, 23), PLATE_D)
        cv.rect((9, 11, 23, 12), PLATE_L)
        cv.line([(16, 12), (16, 22)], SEAM, 0.8)
        cv.ellipse((5, 10, 11, 16), PLATE_L); cv.ellipse((21, 10, 27, 16), PLATE_L)   # pauldrons
    elif kind == "plasteel_helm":
        cv.ellipse((10.5, 1.5, 21.5, 13), PLATE)
        cv.ellipse((11, 1.5, 21, 7), PLATE_L)
        cv.rect((12, 6, 20, 8.5), GRAPH_D)
        cv.rect((12.5, 6.8, 19.5, 7.8), SEAM)
        cv.rect((11, 11, 21, 14), PLATE_D)
    elif kind == "kp_vest":
        cv.rect((9.5, 12, 22.5, 22.5), GRAPH)
        cv.rect((11, 13, 15, 21), PLATE); cv.rect((17, 13, 21, 21), PLATE)
        cv.rect((11, 13, 15, 14), PLATE_L); cv.rect((17, 13, 21, 14), PLATE_L)
        cv.rect((9.5, 21, 22.5, 23), GRAPH_D)
        cv.line([(10, 22), (22, 22)], SEAM, 0.6)
    elif kind == "plasteel_boots":
        for x0 in (10, 16):
            cv.rect((x0, 27, x0 + 6, 33), PLATE); cv.rect((x0, 27, x0 + 6, 28), PLATE_L)
            cv.rect((x0 - 1, 32, x0 + 6, 34.5), GRAPH_D); cv.rect((x0, 29, x0 + 6, 30), SEAM)
    elif kind == "plasteel_gloves":
        for x0 in (5, 23):
            cv.rect((x0, 20, x0 + 4, 25), PLATE); cv.rect((x0, 20, x0 + 4, 21), PLATE_L)
            cv.rect((x0, 22.5, x0 + 4, 23.3), SEAM)
    elif kind == "kp_helmet":
        cv.ellipse((10.5, 1.5, 21.5, 9), GRAPH)
        cv.rect((10.5, 6, 21.5, 7.4), PLATE)
        cv.rect((10.5, 6, 12.5, 11), GRAPH); cv.rect((19.5, 6, 21.5, 11), GRAPH)
        cv.rect((10.5, 10.5, 12.5, 11.5), SEAM); cv.rect((19.5, 10.5, 21.5, 11.5), SEAM)
    return cv.done()


def classify_item(i, o):
    n = (o.get("name") or {})
    n = (n.get("str") or n.get("str_sp") or "") if isinstance(n, dict) else str(n)
    s = (i + " " + n).lower()
    st = set(o.get("subtypes") or [])
    t = o.get("type")
    col = pal(o.get("color"))
    if i == "trl_gun_w2011":
        return ("arcrifle", "light_green")
    if i in ARMOR_KINDS:
        return (ARMOR_KINDS[i], "light_cyan")
    if i.startswith("trl_fish_"):
        return ("fish", col)
    if i.startswith("trl_tank_"):
        return ("fishtank", "light_cyan")
    if i.startswith("trl_pet_"):
        return ("petticket", col)
    if i.startswith("trl_buy_"):
        return ("contract", "light_cyan")
    if i in ("trl_nh_console",):
        return ("device", col)
    if i in ("trl_kumo_wreck",):
        return ("box", col)
    if "kusarigama" in i:
        return ("blade", col)
    if i in RELIGIOUS_KINDS:
        return (RELIGIOUS_KINDS[i], col)
    if ("BIONIC_ITEM" in st or t == "BIONIC_ITEM") and i.startswith("trl_"):
        if has(s, " arm", "hand", "wrist", "forearm"):
            return ("limb_arm", col)
        if has(s, " leg", "foot", "thigh", "knee"):
            return ("limb_leg", col)
        if has(s, "eye", "optic", "retina", "vision"):
            return ("implant_eye", col)
    if not (i.startswith("trl_") and ("GUN" in st or t == "GUN")) and t not in ("GUN", "ARMOR", "TOOL_ARMOR", "MAGAZINE", "BOOK", "BIONIC_ITEM", "COMESTIBLE", "AMMO", "GUNMOD"):
        nk = icons2.named_kind(n)
        if nk:
            return ("named_" + nk[0], nk[1] or (col if nk[0] not in icons2.BASE else icons2.BASE[nk[0]]))
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
    if has(s, "katana", "sword", "knife", "dagger", "tanto", "wakizashi", "nodachi", "machete", "blade", "kama", "sickle", "cleaver", "scalpel", "razor", "saber", "sabre", "scythe",
             "rapier", "estoc", "jian", "cutlass", "falx", "kukri", "kriegsmesser", "shamshir", "zweih", "claymore", "scimitar", "gladius", "dao ", "sai "):
        return ("blade", col)
    if has(s, "spear", "yari", "naginata", "javelin", "pike", "halberd", "lance"):
        return ("spear", col)
    if has(s, "axe", "hatchet", "tomahawk"):
        return ("axe", col)
    if has(s, "shuriken", "star", "kunai"):
        return ("star", col)
    if has(s, "hammer", "mallet", "club", "bat ", " bat", "baton", "staff", "nunchaku", "pipe", "crowbar", "wrench", "tonfa", "cane", "bo ", "sledge", "flail", "mace"):
        return ("blunt", col)
    if has(s, "software", "efile", "encryption", "media file", "photo gallery", "chip", "data", "card", "usb", "cpu", "processor", "ram", "circuit", "disk", "drive"):
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
    if has(s, "pecan", "almond", "pistachio", "peanut", "walnut", "hazelnut", "butternut", "acorn", "chestnut"):
        return ("food", col)
    if i.startswith("material_") or has(s, "uranium", "plutonium", "rhodonite", "zincite", "goop", "effigy"):
        return ("named_crystal3", col)
    # nothing above fits: a shape by name (icons3), then by material, and only then the generic gem
    k3 = icons3.named_kind3(n)
    if k3:
        return ("named_" + k3, col)
    mk = icons3.material_kind(o.get("material"))
    if mk:
        return ("named_" + mk, col)
    return ("gem", col)


def _arcrifle(cv):
    """The Cameco W-2011 electric rifle, drawn pointing right on a 32x32 canvas.  Original design from the brief: an oversized steel
    body with a rounded belly, a pointed nose, and a glowing neon-green chamber in the middle; it looks too big for one person."""
    steel = (150, 158, 176)
    steel_d = (86, 92, 110)
    steel_l = (214, 220, 232)
    glow = (90, 255, 140)
    cv.ellipse((8, 8, 21, 22), steel_d)                     # rounded body, deep belly
    cv.ellipse((8, 7, 21, 19), steel)
    cv.poly([(20, 11), (31, 14.5), (20, 17)], steel)         # long pointed nose
    cv.poly([(20, 11), (31, 14.5), (20, 14.5)], steel_l)
    cv.rect((2, 11, 9, 19), steel_d)                         # heavy stock block
    cv.poly([(2, 11), (9, 9), (9, 11)], steel)
    cv.ellipse((10.5, 9.5, 18.5, 17.5), (20, 60, 40))        # chamber window in the middle
    cv.ellipse((11.5, 10.5, 17.5, 16.5), glow)
    cv.ellipse((13, 12, 16, 15), (225, 255, 235))
    for x in (6, 8):
        cv.rect((x, 12, x + 0.6, 18), steel_l)
    cv.rect((11, 21, 14, 27), steel_d)                       # fat grip
    cv.rect((14, 20, 17, 21), steel_d)
    cv.line([(30, 14.5), (31.5, 14.5)], glow, 0.8)           # muzzle glow


def p_wield_arcrifle():
    """The W-2011 as held by a person: a 32x36 overlay for the chars sheet.  It is still the biggest weapon on the sheet but now sits
    low across the body (about 60% of its old size) so the person underneath stays visible."""
    tmp = Canvas(32, 32)
    _arcrifle(tmp)
    g = tmp.done()
    g = g.resize((22, 22), Image.LANCZOS).rotate(24, resample=Image.BICUBIC, center=(11, 11))
    out = Image.new("RGBA", (32, 36), (0, 0, 0, 0))
    out.alpha_composite(g, (8, 14))
    return out


WIELD_KINDS = {"pistol", "smg", "shotgun", "rifle", "laser", "launcher", "bow", "blade", "spear", "axe", "blunt"}


def p_wield(kind, col, seed):
    """Held-weapon overlay (32x36) for any weapon kind: the item icon, slanted and set in the character's hands."""
    g = p_item(kind, col, seed)
    if kind in ("pistol", "smg", "shotgun", "rifle", "laser", "launcher", "bow"):
        scale, ang, dx, dy = (1.15, 18, 3, 5) if kind != "pistol" else (1.0, 8, 5, 6)
    elif kind in ("spear",):
        scale, ang, dx, dy = (1.25, 0, 5, 0)
    else:
        scale, ang, dx, dy = (1.0, 0, 5, 3)
    n = int(32 * scale)
    g = g.resize((n, n), Image.LANCZOS)
    if ang:
        g = g.rotate(ang, resample=Image.BICUBIC, center=(n // 2, n // 2))
    out = Image.new("RGBA", (32, 36), (0, 0, 0, 0))
    out.alpha_composite(g, (dx - (n - 32) // 2, dy - (n - 32) // 2)) if dx - (n - 32) // 2 >= 0 and dy - (n - 32) // 2 >= 0 else out.alpha_composite(g.crop((max(0, -(dx - (n - 32) // 2)), max(0, -(dy - (n - 32) // 2)), n, n)), (max(0, dx - (n - 32) // 2), max(0, dy - (n - 32) // 2)))
    return out


def p_item(kind, col, seed):
    cv = Canvas(32, 32)
    c = PAL[col]
    d = shade(c, 0.55)
    l = shade(c, 1.25)
    rnd = random.Random(seed)
    steel = (176, 182, 196)
    if kind.startswith("named_"):
        icons2.draw(kind[6:], c, d, l, cv, PAL)
        return cv.done()
    if kind == "arcrifle":
        _arcrifle(cv)
    elif kind == "charm":
        cv.line([(16, 4), (16, 9)], (232, 200, 90), 1); cv.rect((10, 9, 22, 26), (200, 40, 56)); cv.rect((10, 9, 22, 12), (236, 200, 90))
        cv.rect((10, 22, 22, 26), (236, 200, 90)); cv.rect((14, 14, 18, 20), (250, 240, 220)); cv.rect((15, 15, 17, 19), (200, 40, 56))
    elif kind == "talisman":
        cv.rect((11, 5, 21, 27), (244, 240, 224)); cv.rect((13, 8, 19, 24), (30, 30, 36)); cv.rect((14, 9, 18, 14), (200, 40, 56)); cv.rect((14, 17, 18, 22), (200, 40, 56))
    elif kind == "ema_plaque":
        cv.poly([(7, 12), (16, 6), (25, 12), (25, 26), (7, 26)], (214, 172, 112)); cv.line([(16, 6), (16, 3)], (120, 80, 50), 1)
        cv.ellipse((12, 15, 20, 23), (200, 50, 60)); cv.rect((14, 17, 18, 21), (250, 240, 220))
    elif kind == "omikuji":
        cv.rect((13, 4, 19, 28), (246, 242, 230)); cv.rect((13, 4, 19, 8), (200, 40, 56))
        for y in (11, 15, 19, 23): cv.rect((15, y, 17, y + 2), (60, 60, 70))
    elif kind == "gohei":
        cv.line([(16, 28), (16, 8)], (176, 126, 76), 2)
        for dx in (-1, 1): cv.poly([(16, 8), (16 + 9 * dx, 11), (16 + 4 * dx, 14), (16 + 11 * dx, 18), (16 + 5 * dx, 20), (16, 14)], (250, 250, 252))
    elif kind == "icon_item":
        cv.rect((8, 5, 24, 27), (120, 76, 44)); cv.rect((10, 7, 22, 25), (226, 180, 70)); cv.ellipse((13, 10, 19, 17), (220, 170, 130))
        cv.rect((12, 17, 20, 24), (160, 40, 50)); cv.line([(10, 7), (22, 7)], (255, 230, 120), 0.6)
    elif kind == "prayer_rope":
        cv.ellipse((8, 6, 24, 24), (0, 0, 0, 0))
        for k in range(14):
            a = k / 14 * 6.2832
            x, y = 16 + 8 * np.cos(a), 14 + 8 * np.sin(a)
            cv.ellipse((x - 1.6, y - 1.6, x + 1.6, y + 1.6), (40, 40, 48))
        cv.rect((15, 24, 17, 29), (200, 200, 210)); cv.rect((13, 26, 19, 27), (200, 200, 210))
    elif kind == "censer":
        cv.line([(16, 3), (16, 10)], (190, 190, 200), 0.8); cv.ellipse((9, 10, 23, 22), (222, 180, 70)); cv.rect((9, 15, 23, 16), (170, 130, 40))
        cv.rect((12, 22, 20, 25), (170, 130, 40)); cv.ellipse((13, 5, 19, 9), (210, 210, 220, 160))
    elif kind == "church_candle":
        cv.rect((14, 9, 18, 27), (240, 214, 120)); cv.rect((14, 9, 15, 27), (250, 232, 160)); cv.line([(16, 9), (16, 6)], (60, 50, 40), 0.6)
        cv.ellipse((14, 2, 18, 8), (255, 190, 60))
    elif kind == "gospel":
        cv.rect((6, 7, 26, 26), (150, 40, 50)); cv.rect((7, 8, 25, 25), (236, 200, 90)); cv.rect((8, 9, 24, 24), (150, 40, 50))
        cv.rect((15, 11, 17, 22), (236, 200, 90)); cv.rect((12, 14, 20, 16), (236, 200, 90))
    elif kind == "contract":
        cv.rect((7, 7, 25, 25), (236, 240, 246)); cv.rect((7, 7, 25, 11), c)
        for y in (14, 17, 20): cv.rect((10, y, 22, y + 1), (150, 156, 170))
        cv.rect((18, 19, 24, 25), NEON["cyan"]); cv.rect((19, 20, 23, 24), (20, 40, 50))
    elif kind == "limb_arm":
        cv.rect((4, 12, 14, 20), (150, 156, 172)); cv.rect((14, 13, 24, 19), (110, 116, 134)); cv.ellipse((12, 10, 18, 22), (90, 96, 112))
        cv.rect((24, 11, 29, 21), (170, 176, 192))
        for x in (25, 27): cv.rect((x, 9, x + 1, 12), (170, 176, 192))
        cv.rect((5, 15, 13, 17), NEON["cyan"]); cv.rect((15, 15, 23, 17), shade(NEON["cyan"], 0.7))
    elif kind == "limb_leg":
        cv.rect((11, 4, 18, 14), (150, 156, 172)); cv.ellipse((9, 12, 20, 19), (90, 96, 112)); cv.rect((12, 17, 17, 26), (110, 116, 134))
        cv.poly([(10, 25), (21, 25), (27, 29), (10, 29)], (170, 176, 192))
        cv.rect((13, 7, 15, 12), NEON["cyan"]); cv.rect((13, 20, 15, 24), shade(NEON["cyan"], 0.7))
    elif kind == "implant_eye":
        cv.ellipse((5, 9, 27, 23), (232, 236, 244)); cv.ellipse((11, 9, 21, 23), c); cv.ellipse((14, 12, 18, 20), (16, 16, 24))
        cv.ellipse((13, 11, 15, 13), (255, 255, 255)); cv.rect((6, 22, 26, 24), (90, 96, 112))
    elif kind == "fish":
        # a fish in a clear water bag: body, tail, fin, eye
        cv.poly([(7, 8), (25, 8), (26, 25), (6, 25)], (150, 200, 232, 90))
        cv.ellipse((9, 12, 22, 21), c)
        cv.ellipse((10, 13, 20, 17), l)
        cv.poly([(21, 16), (27, 11), (27, 22)], d)
        cv.poly([(13, 12), (17, 8), (18, 12)], d)
        cv.rect((11, 15, 13, 17), (20, 20, 30))
        cv.line([(15, 13), (15, 21)], d, 0.7)
        cv.rect((10, 6, 22, 8), (226, 232, 240))
    elif kind == "fishtank":
        cv.rect((6, 10, 26, 26), (130, 200, 232, 120))
        cv.rect((6, 10, 26, 12), (226, 240, 250))
        cv.rect((6, 24, 26, 27), (60, 66, 84))
        cv.ellipse((10, 16, 17, 20), (240, 150, 60)); cv.poly([(16, 18), (20, 15), (20, 21)], (240, 150, 60))
        cv.ellipse((17, 20, 22, 23), (90, 170, 255))
        cv.rect((22, 17, 24, 24), (60, 190, 110))
        cv.line([(6, 10), (6, 26)], (226, 240, 250), 0.6); cv.line([(26, 10), (26, 26)], (226, 240, 250), 0.6)
    elif kind == "petticket":
        cv.rect((7, 9, 25, 23), (232, 232, 220))
        cv.rect((7, 9, 25, 12), c)
        cv.ellipse((12, 14, 20, 21), shade(c, 0.7))
        cv.ellipse((11, 13, 14, 16), shade(c, 0.7)); cv.ellipse((18, 13, 21, 16), shade(c, 0.7))
    elif kind in ("plasteel_suit", "plasteel_helm", "kp_vest", "kp_helmet", "plasteel_boots", "plasteel_gloves"):
        _armor_icon(cv, kind); _armor_icon2(cv, kind)
    elif kind in ("pistol", "smg", "shotgun", "rifle", "laser", "launcher"):
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
