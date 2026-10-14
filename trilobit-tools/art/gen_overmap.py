#!/usr/bin/env python3
"""Bouma Overmap: a 16x16 neon top-down overmap tileset for every Trilobit overmap terrain (about 1,300 ids) plus roads, fields, forest and water.
Each building is a dark tile with a colored frame and a small icon (cross, torii, bowl, window grid, bolt, crane, a letter); roofs are dimmer.
usage: gen_overmap.py <repo root>   -> gfx/Bouma_Overmap/ (tileset.txt, tile_config.json, overmap.png) and gfx/Mokuhanga_Overmap/ (black, white and one neon)"""
import glob, json, os, re, sys
from PIL import Image, ImageDraw, ImageFont
ROOT = sys.argv[1]
S = 16
FONT = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf", 11)

PAL = {"black": (30, 30, 40), "red": (190, 50, 70), "green": (60, 170, 90), "brown": (160, 110, 60), "blue": (70, 110, 220), "magenta": (190, 70, 190),
       "cyan": (60, 180, 190), "gray": (150, 150, 165), "dark_gray": (95, 95, 110), "light_gray": (190, 190, 205), "light_red": (255, 90, 120),
       "light_green": (110, 240, 140), "yellow": (240, 210, 70), "light_blue": (110, 160, 255), "pink": (255, 110, 200), "light_cyan": (90, 235, 245),
       "white": (240, 240, 250), "light_magenta": (240, 120, 240), "i_red": (190, 50, 70), "i_green": (60, 170, 90), "i_blue": (70, 110, 220),
       "i_cyan": (60, 180, 190), "i_yellow": (240, 210, 70), "i_magenta": (190, 70, 190), "i_white": (240, 240, 250), "i_ltgray": (190, 190, 205),
       "light_purple": (200, 130, 250), "magenta": (190, 70, 190)}


def col(name):
    return PAL.get(str(name or "light_gray").replace("i_", "", 1) if str(name or "").startswith("i_") and name not in PAL else str(name or "light_gray"), (190, 190, 205))


def dim(c, f):
    return tuple(int(v * f) for v in c)


def base(c, roof=False):
    im = Image.new("RGBA", (S, S), (10, 12, 22, 255) if roof else (16, 18, 34, 255))
    d = ImageDraw.Draw(im)
    f = dim(c, 0.35 if roof else 0.6)
    if roof:
        for i in range(0, S, 2):
            d.point((i, 0), fill=f); d.point((i, S - 1), fill=f); d.point((0, i), fill=f); d.point((S - 1, i), fill=f)
    else:
        d.rectangle((0, 0, S - 1, S - 1), outline=f)
    return im, d


def glyph(d, ch, c):
    try:
        w = d.textlength(ch, font=FONT)
    except Exception:
        w = 7
    d.text(((S - w) / 2, 1), ch, fill=c, font=FONT)


def icon_cross(d, c):      # church: dome and a three-bar cross
    d.ellipse((4, 7, 11, 14), fill=dim(c, 0.55)); d.rectangle((7, 1, 8, 7), fill=c); d.rectangle((5, 3, 10, 3), fill=c); d.rectangle((6, 5, 9, 5), fill=c)


def icon_torii(d, c):
    d.rectangle((2, 3, 13, 4), fill=c); d.rectangle((3, 6, 12, 6), fill=c); d.rectangle((4, 4, 5, 13), fill=c); d.rectangle((10, 4, 11, 13), fill=c)


def icon_plus(d, c):
    d.rectangle((6, 2, 9, 13), fill=c); d.rectangle((2, 6, 13, 9), fill=c)


def icon_bowl(d, c):
    d.pieslice((2, 4, 13, 15), 0, 180, fill=c); d.line((4, 2, 11, 6), fill=dim(c, 0.8)); d.line((6, 1, 12, 5), fill=dim(c, 0.8))


def icon_grid(d, c):
    for x in (3, 7, 11):
        for y in (3, 7, 11):
            d.rectangle((x, y, x + 2, y + 2), fill=c)


def icon_bolt(d, c):
    d.polygon([(9, 1), (4, 9), (7, 9), (6, 14), (12, 6), (8, 6)], fill=c)


def icon_crane(d, c):
    d.line((4, 14, 4, 2), fill=c); d.line((2, 3, 13, 3), fill=c); d.line((11, 3, 11, 8), fill=dim(c, 0.8)); d.rectangle((10, 8, 12, 10), fill=c); d.rectangle((2, 13, 7, 14), fill=c)


def icon_fish(d, c):
    d.ellipse((2, 5, 11, 11), fill=c); d.polygon([(11, 8), (14, 5), (14, 11)], fill=c); d.point((5, 7), fill=(10, 12, 22))


def icon_car(d, c):
    d.rectangle((2, 7, 13, 11), fill=c); d.rectangle((4, 5, 10, 7), fill=dim(c, 0.8)); d.ellipse((3, 10, 5, 12), fill=(10, 12, 22)); d.ellipse((10, 10, 12, 12), fill=(10, 12, 22))


def icon_tower(d, c):
    d.rectangle((5, 1, 10, 14), fill=dim(c, 0.55))
    for y in range(3, 14, 3):
        d.rectangle((6, y, 9, y), fill=c)


def icon_house(d, c):
    d.polygon([(8, 2), (2, 8), (13, 8)], fill=c); d.rectangle((4, 8, 11, 13), fill=dim(c, 0.7))


def icon_gun(d, c):
    d.rectangle((2, 6, 12, 8), fill=c); d.rectangle((9, 8, 11, 12), fill=c)


def icon_chip(d, c):
    d.rectangle((4, 4, 11, 11), outline=c)
    for i in (5, 8, 10):
        d.point((i, 3), fill=c); d.point((i, 12), fill=c); d.point((3, i), fill=c); d.point((12, i), fill=c)


ICONS = {"cross": icon_cross, "torii": icon_torii, "plus": icon_plus, "bowl": icon_bowl, "grid": icon_grid, "bolt": icon_bolt, "crane": icon_crane,
         "fish": icon_fish, "car": icon_car, "tower": icon_tower, "house": icon_house, "gun": icon_gun, "chip": icon_chip}


def kind_of(i, name, sym):
    s = (i + " " + str(name)).lower()
    for pat, k in (("church|orthodox", "cross"), ("shrine", "torii"), ("hospital|clinic|medical|surgery|pharmacy|doctor", "plus"),
                   (r"restaurant|rest[pmr]\d|izakaya|noodle|ramen|sushi|pizza|cafe|diner|bistro|food court|kitchen|bar\b|tea|teahouse|dessert|bakery|burger", "bowl"),
                   (r"apt\d|apartment|tenement|dormitory|flats|housing|condo|residence|hotel|khrushch", "grid"),
                   ("substation|transformer|power|reactor|plant|pylon", "bolt"), ("construction|building site|excavation|half_built|scaffold", "crane"),
                   ("pet|aquarium|fish", "fish"), ("parking|garage|charging lot|scooter", "car"), ("tower|sky\\d|skyscraper", "tower"),
                   ("estate|home_|slum|house|shack", "house"), ("armory|military|barracks|garrison|checkpoint|police|precinct", "gun"),
                   ("implant|nano|android|chip|terminal|net |server|telecom", "chip")):
        if re.search(pat, s):
            return k
    return None


def building(i, name, sym, color):
    roof = "roof" in str(name).lower() or re.search(r"_z([1-9]\d*)$", i) is not None
    c = col(color)
    im, d = base(c, roof)
    k = kind_of(i, name, sym)
    cc = dim(c, 0.6) if roof else c
    if k:
        ICONS[k](d, cc)
    else:
        glyph(d, (str(sym) or "?")[:1], cc)
    return im


def terrain_tiles():
    T = {}
    def tile(bg, fn=None):
        im = Image.new("RGBA", (S, S), bg + (255,)); d = ImageDraw.Draw(im)
        if fn:
            fn(d)
        return im
    T["field"] = tile((22, 40, 38), lambda d: [d.point(p, fill=(50, 100, 80)) for p in ((3, 4), (9, 2), (12, 9), (5, 11), (2, 14), (14, 14))])
    T["open_land"] = T["field"]
    T["forest"] = tile((14, 36, 30), lambda d: [d.ellipse((x, y, x + 4, y + 4), fill=(30, 110, 80)) for x, y in ((1, 2), (8, 1), (4, 8), (11, 9))])
    T["forest_thick"] = tile((10, 28, 24), lambda d: [d.ellipse((x, y, x + 5, y + 5), fill=(24, 90, 64)) for x, y in ((0, 0), (8, 1), (3, 6), (10, 8), (1, 11))])
    T["forest_water"] = tile((16, 34, 44), lambda d: [d.ellipse((x, y, x + 4, y + 4), fill=(30, 90, 80)) for x, y in ((1, 2), (9, 8))])
    T["lake_surface"] = tile((14, 26, 70), lambda d: [d.arc((x, y, x + 6, y + 4), 200, 340, fill=(80, 140, 255)) for x, y in ((1, 3), (8, 8), (3, 11))])
    T["lake_shore"] = tile((24, 50, 110), lambda d: [d.arc((x, y, x + 6, y + 4), 200, 340, fill=(130, 190, 255)) for x, y in ((2, 3), (9, 9))])
    T["river"] = tile((20, 40, 100), lambda d: d.arc((-4, 3, 14, 15), 250, 340, fill=(120, 180, 255)))
    T["river_center"] = T["river"]
    T["s_lot"] = tile((26, 28, 44), lambda d: [d.line((x, 3, x, 12), fill=(90, 100, 130)) for x in (3, 7, 11)])
    T["park"] = tile((20, 50, 40), lambda d: [d.ellipse((x, y, x + 3, y + 3), fill=(255, 130, 200)) for x, y in ((3, 3), (10, 5), (5, 10), (11, 12))])
    return T


def road_variants(kind):
    """returns dict of subtile -> list of 16x16 images in the game's rotation order (see cata_tiles get_rotation_and_subtile)"""
    bg = {"road": (26, 28, 42), "subway": (18, 20, 28), "sewer": (20, 28, 26)}[kind]
    edge = {"road": (70, 74, 100), "subway": (60, 90, 140), "sewer": (60, 120, 100)}[kind]
    line = {"road": (255, 200, 60), "subway": (110, 200, 255), "sewer": (110, 220, 160)}[kind]
    def mk(mask):          # N=1, W=2, E=4, S=8
        im = Image.new("RGBA", (S, S), bg + (255,)); d = ImageDraw.Draw(im)
        if mask == 0:
            d.rectangle((5, 5, 10, 10), fill=edge)
            return im
        def arm(x0, y0, x1, y1): d.rectangle((x0, y0, x1, y1), fill=edge)
        arm(5, 5, 10, 10)
        if mask & 1: arm(5, 0, 10, 5)
        if mask & 8: arm(5, 10, 10, 15)
        if mask & 2: arm(0, 5, 5, 10)
        if mask & 4: arm(10, 5, 15, 10)
        c = (7, 7, 8, 8)
        d.rectangle(c, fill=line)
        if mask & 1: d.line((7, 0, 7, 6), fill=line); d.point((8, 2), fill=line)
        if mask & 8: d.line((8, 9, 8, 15), fill=line)
        if mask & 2: d.line((0, 8, 6, 8), fill=line)
        if mask & 4: d.line((9, 7, 15, 7), fill=line)
        return im
    return {
        "center": [mk(15)],
        "corner": [mk(3), mk(10), mk(12), mk(5)],
        "t_connection": [mk(7), mk(11), mk(14), mk(13)],
        "edge": [mk(9), mk(6)],
        "end_piece": [mk(1), mk(2), mk(8), mk(4)],
        "unconnected": [mk(9), mk(6)],
    }


def moku(im):
    """Mokuhanga restyle: black and white with the one neon accent kept"""
    px = im.load()
    out = Image.new("RGBA", im.size)
    po = out.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            lum = (r * 3 + g * 6 + b) / 10
            sat = max(r, g, b) - min(r, g, b)
            if sat > 120 and lum > 90:
                po[x, y] = (255, 60, 120, a)          # the neon accent
            else:
                v = 250 if lum > 110 else 14 if lum < 60 else 120
                po[x, y] = (v, v, v, a)
    return out


def markers():
    """Overlay sprites the overmap renderer asks for: player, NPCs (friendly and hostile), cursor, path highlight, mission arrows, unexplored."""
    import math
    out = {}
    def blank():
        im = Image.new("RGBA", (S, S), (0, 0, 0, 0)); return im, ImageDraw.Draw(im)
    def dot(ring, fill, extra=None):
        im, d = blank()
        d.ellipse((2, 2, 13, 13), fill=(0, 0, 0, 200), outline=ring)
        d.ellipse((4, 4, 11, 11), fill=fill)
        if extra: extra(d)
        return im
    player = dot((255, 255, 255, 255), (60, 235, 255, 255), lambda d: (d.line((8, 0, 8, 3), fill=(255, 255, 255, 255)), d.line((8, 12, 8, 15), fill=(255, 255, 255, 255)), d.line((0, 8, 3, 8), fill=(255, 255, 255, 255)), d.line((12, 8, 15, 8), fill=(255, 255, 255, 255))))
    npc = dot((110, 240, 140, 255), (40, 170, 90, 255))
    hostile = dot((255, 90, 100, 255), (220, 40, 60, 255), lambda d: (d.line((8, 5, 8, 8), fill=(255, 255, 255, 255)), d.point((8, 10), fill=(255, 255, 255, 255))))
    for i in ("player_male", "player_female"): out[i] = player
    for i in ("npc_male", "npc_female"): out[i] = npc
    out["overmap_npc_hostile"] = hostile
    im, d = blank()
    y = (255, 230, 60, 255)
    for (x0, y0, dx, dy) in ((0, 0, 1, 1), (15, 0, -1, 1), (0, 15, 1, -1), (15, 15, -1, -1)):
        d.line((x0, y0, x0 + 5 * dx, y0), fill=y, width=1); d.line((x0, y0, x0, y0 + 5 * dy), fill=y, width=1)
        d.line((x0 + dx, y0 + dy, x0 + 5 * dx, y0 + dy), fill=y); d.line((x0 + dx, y0 + dy, x0 + dx, y0 + 5 * dy), fill=y)
    out["cursor"] = im
    im, d = blank(); d.rectangle((0, 0, S - 1, S - 1), fill=(255, 230, 60, 70), outline=(255, 230, 60, 255)); out["highlight"] = im
    im, d = blank(); d.rectangle((0, 0, S - 1, S - 1), outline=(255, 80, 220, 255)); d.rectangle((2, 2, S - 3, S - 3), outline=(255, 80, 220, 255)); d.line((5, 5, 10, 10), fill=(255, 80, 220, 255)); d.line((10, 5, 5, 10), fill=(255, 80, 220, 255)); out["mission_cursor"] = im
    for name, ang in (("e", 0), ("se", 45), ("s", 90), ("sw", 135), ("w", 180), ("nw", 225), ("n", 270), ("ne", 315)):
        im, d = blank(); a = math.radians(ang); cx = cy = 7.5
        tip = (cx + 7 * math.cos(a), cy + 7 * math.sin(a)); l = (cx + 4 * math.cos(a + 2.4), cy + 4 * math.sin(a + 2.4)); r = (cx + 4 * math.cos(a - 2.4), cy + 4 * math.sin(a - 2.4))
        d.polygon([tip, l, r], fill=(255, 80, 220, 255), outline=(255, 255, 255, 255)); out["mission_arrow_" + name] = im
    for name, pts in (("up", [(8, 1), (14, 9), (2, 9)]), ("down", [(8, 14), (14, 6), (2, 6)])):
        im, d = blank(); d.polygon(pts, fill=(255, 80, 220, 255), outline=(255, 255, 255, 255)); out["mission_arrow_" + name] = im
    im = Image.new("RGBA", (S, S), (28, 12, 40, 255)); ImageDraw.Draw(im).line((3, 3, 12, 12), fill=(255, 80, 220, 255)); ImageDraw.Draw(im).line((12, 3, 3, 12), fill=(255, 80, 220, 255))
    out["unknown_terrain"] = im
    im = Image.new("RGBA", (S, S), (18, 14, 30, 255)); out["unexplored_terrain"] = im
    return out


def main():
    types = {}
    visions = set()
    for f in glob.glob(os.path.join(ROOT, "data/mods/trilobit/**/*.json"), recursive=True):
        try:
            d = json.load(open(f))
        except Exception:
            continue
        for o in d if isinstance(d, list) else []:
            if isinstance(o, dict) and o.get("type") == "overmap_terrain":
                types[o["id"]] = (o.get("sym"), o.get("color"), o.get("name"))
                visions.add(o.get("vision_levels"))
    sprites, entries = [], []
    cache = {}
    def add(im):
        key = im.tobytes()
        if key not in cache:
            cache[key] = len(sprites); sprites.append(im)
        return cache[key]
    for i, (sym, color, name) in types.items():
        im = building(i, name, sym, color)
        entries.append({"id": i, "fg": add(im)})
    for tid, im in terrain_tiles().items():
        entries.append({"id": tid, "fg": add(im)})
    for kind in ("road", "subway", "sewer"):
        v = road_variants(kind)
        add_tiles = [{"id": k, "fg": [add(i) for i in ims] if len(ims) > 1 else add(ims[0])} for k, ims in v.items() if k != "unconnected"]
        add_tiles.append({"id": "unconnected", "fg": [add(i) for i in v["unconnected"]]})
        entries.append({"id": kind, "fg": add(v["unconnected"][0]), "multitile": True, "additional_tiles": add_tiles})
    for mid, im in markers().items():
        entries.append({"id": mid, "fg": add(im)})
    grey = Image.new("RGBA", (S, S), (24, 26, 42, 255)); ImageDraw.Draw(grey).rectangle((0, 0, S - 1, S - 1), outline=(60, 70, 110))
    dgrey = Image.new("RGBA", (S, S), (14, 16, 28, 255))
    for v in sorted(x for x in visions if x):
        entries.append({"id": f"{v}$outlines", "fg": add(grey)})
        entries.append({"id": f"{v}$vague", "fg": add(dgrey)})
    for name, tr, folder in (("Bouma Overmap", lambda im: im, "Bouma_Overmap"), ("Mokuhanga Overmap", moku, "Mokuhanga_Overmap")):
        d = os.path.join(ROOT, "gfx", folder)
        os.makedirs(d, exist_ok=True)
        cols = 16
        sheet = Image.new("RGBA", (cols * S, ((len(sprites) + cols - 1) // cols) * S), (0, 0, 0, 0))
        for n, im in enumerate(sprites):
            sheet.alpha_composite(tr(im), ((n % cols) * S, (n // cols) * S))
        sheet.save(os.path.join(d, "overmap.png"))
        Image.new("RGBA", (S, S), (0, 0, 0, 0)).save(os.path.join(d, "fallback.png"))
        open(os.path.join(d, "tileset.txt"), "w").write(f"NAME: {name}\nVIEW: {name}\nJSON: tile_config.json\nTILESET: overmap.png\n")
        json.dump({"tile_info": [{"pixelscale": 1, "width": S, "height": S, "zlevel_height": 0, "iso": False, "retract_dist_min": -1.0, "retract_dist_max": 1.0}],
                   "tiles-new": [{"file": "overmap.png", "tiles": entries}, {"file": "fallback.png", "tiles": []}]},
                  open(os.path.join(d, "tile_config.json"), "w"))
    print(len(types), "overmap terrains,", len(sprites), "sprites,", len(entries), "tile entries")


if __name__ == "__main__":
    main()
