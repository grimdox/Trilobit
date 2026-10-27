"""Item icons: what lies on the ground (and in the hand) for every item that is not a weapon.  Guns and melee
weapons keep their approved designs (the game's tools/content/t64_guns.py and t64_melee.py); everything else is drawn
here with the world's renderer, so a dropped bento and the counter it came from are lit and outlined alike.

Icons are one per item id, drawn over nothing (the game draws them over the floor), centred, about 48 px across,
seen from above like the world.  Builders share a few forms (bowl, plate, cup, can, bottle, box, bag) and add what
makes each item itself."""
import math

import numpy as np

from canvas import Tile, N, XX, YY, Rng, speckle, blotches
import furniture as F


def piece():
    return Tile('', periodic=False)


def done(t, shadow=True):
    if shadow:
        t.drop_shadow(t.solid.copy(), 3, 3, 0.4)
    return t


def D(cx, cy, r, ry=None):
    return Tile.disk_mask(cx, cy, r, ry)


def B(x0, y0, x1, y1, r=0.0):
    return Tile.box_mask(x0, y0, x1, y1, r)


def L(x0, y0, x1, y1, w):
    return Tile.line_mask(x0, y0, x1, y1, w)


# ------------------------------------------------------------------------------------------------ shared forms
def bowl(t, inner, h=10, rim='plastic_w', r=21, cx=32, cy=32):
    t.slab(D(cx, cy, r), rim, h, bevel=2)
    fill = D(cx, cy, r - 3)
    t.paint(fill, inner)
    t.h[fill] -= 2
    return fill


def plate(t, r=24, mat='plastic_w', cx=32, cy=32, oval=1.0):
    t.slab(D(cx, cy, r, r * oval), mat, 3, bevel=1.5)
    t.mark(D(cx, cy, r - 4, (r - 4) * oval) & ~D(cx, cy, r - 5, (r - 5) * oval), -1)
    return D(cx, cy, r - 3, (r - 3) * oval)


def cup(t, liquid, mat='plastic_w', r=13, cx=32, cy=32, h=14):
    t.slab(D(cx, cy, r), mat, h, bevel=1.5)
    f = D(cx, cy, r - 2.5)
    t.paint(f, liquid)
    t.h[f] -= 2
    return f


def can(t, body, band=None, r=13, cx=32, cy=32):
    t.slab(D(cx, cy, r), body, 16, bevel=1.2)
    t.paint(D(cx, cy, r - 2) & ~D(cx, cy, r - 3), 'chrome')
    t.paint(D(cx, cy, r - 3), 'steel')
    t.slab(B(cx - 3, cy - 6, cx + 3, cy - 3, 1), 'chrome', 17, bevel=0.4)
    if band:
        t.paint(D(cx, cy, r) & ~D(cx, cy, r - 1.5), band)


def bottle(t, glass, cap='dark_steel', x0=14, y0=26, x1=50, y1=38, label=None):
    """a bottle lying on its side, neck to the right"""
    body_ = B(x0, y0, x1 - 10, y1, 5)
    t.slab(body_, glass, 10, profile='dome')
    neck = B(x1 - 12, (y0 + y1) / 2 - 3, x1 - 2, (y0 + y1) / 2 + 3, 2)
    t.slab(neck, glass, 8, profile='dome')
    t.slab(B(x1 - 3, (y0 + y1) / 2 - 3.5, x1, (y0 + y1) / 2 + 3.5, 1), cap, 9, bevel=0.5)
    if label:
        t.paint(B(x0 + 8, y0 + 1, x0 + 18, y1 - 1), label)
    t.mark(L(x0 + 4, y0 + 3, x1 - 14, y0 + 3, 1.2) & body_, 2)


def box(t, mat, x0=12, y0=16, x1=51, y1=47, h=12, r=2, top=None):
    m = B(x0, y0, x1, y1, r)
    t.slab(m, mat, h, bevel=1.5)
    if top:
        t.paint(B(x0 + 3, y0 + 3, x1 - 3, y1 - 3, max(0, r - 1)), top)
    return m


def dots(t, pts, mat, r=2.5, h=3, profile='dome'):
    for x, y in pts:
        t.slab(D(x, y, r), mat, h, profile=profile)


# ------------------------------------------------------------------------------------------------ food
def f_cup_ramen(t):
    t.slab(D(32, 32, 20), 'paint_w', 14, bevel=1.5)
    t.paint(D(32, 32, 20) & ~D(32, 32, 18), 'plastic_r')
    f = D(32, 32, 17)
    t.paint(f, 'broth')
    t.h[f] -= 3
    for k in range(7):
        t.slab(L(18 + k * 4, 22, 22 + k * 3, 42, 1.4) & f, 'noodle', 13, bevel=0)
    dots(t, [(26, 28), (38, 36)], 'egg', 2.5, 13)
    t.slab(D(36, 26, 3.5), 'nori', 13, bevel=0.5)


def f_gyoza(t):
    p = plate(t, 24)
    for k in range(5):
        x = 16 + k * 8
        t.slab(D(x, 32, 5, 9), 'dough', 6, profile='dome')
        t.paint(D(x, 36, 4, 4) & D(x, 32, 5, 9), 'crust')
        t.mark(L(x - 3, 26, x + 3, 26, 1) & D(x, 32, 5, 9), -1)


def f_onigiri(t):
    tri = Tile.poly_mask([(32, 8), (54, 50), (10, 50)])
    t.slab(tri, 'rice', 12, profile='dome')
    t.mark(tri & speckle(Rng(3).int(0, 9999), 0.15), -1)
    t.slab(B(22, 38, 42, 52, 2) & tri, 'nori', 13, bevel=0.5)


def f_sashimi(t):
    plate(t, 25, 'lacquer_black', oval=0.7)
    for k in range(5):
        x = 16 + k * 8
        s = Tile.poly_mask([(x - 4, 24), (x + 4, 22), (x + 5, 40), (x - 3, 42)])
        t.slab(s, 'fish_pink' if k % 2 == 0 else 'fish_silver', 6, profile='dome')
        t.mark(L(x - 2, 26, x + 2, 38, 1) & s, 1)
    t.slab(D(52, 30, 3), 'leaf', 5, profile='dome')


def f_skewer(t):
    for k in range(3):
        y = 20 + k * 12
        t.slab(L(6, y + 4, 58, y - 4, 1.6), 'wood_light', 4, bevel=0)
        for j in range(4):
            x = 16 + j * 9
            t.slab(D(x, y + 2 - j * 1.2, 4.5, 4), 'meat' if j % 2 == 0 else 'meat_fried', 8, profile='dome')


def f_bento(t, main='meat_fried'):
    m = box(t, 'lacquer_black', 8, 12, 55, 51, 9, 3)
    inner = B(11, 15, 52, 48, 2)
    t.paint(inner, 'lacquer_red')
    t.h[inner] -= 3
    t.slab(B(11, 15, 30, 48, 1), 'rice', 8, bevel=1)
    t.mark(B(11, 15, 30, 48) & speckle(Rng(4).int(0, 9999), 0.12), -1)
    for k in range(3):
        t.slab(B(34, 17 + k * 10, 50, 24 + k * 10, 2), main, 9, profile='dome')
    t.slab(D(20, 31, 3), 'plastic_r', 9, profile='dome')


def f_donburi(t):
    f = bowl(t, 'rice', 12, 'lacquer_black', 22)
    t.mark(f & speckle(Rng(5).int(0, 9999), 0.12), -1)
    for k in range(3):
        t.slab(B(16, 20 + k * 9, 48, 26 + k * 9, 3), 'eel', 13, profile='dome')
        t.mark(B(16, 23 + k * 9, 48, 23 + k * 9), 1)


def f_soup(t, liquid='broth', bits=('lettuce', 'paint_w')):
    f = bowl(t, liquid, 10, 'lacquer_red' if liquid == 'broth' else 'plastic_w', 20)
    rng = Rng(liquid)
    for k in range(7):
        x, y = rng.range(22, 42), rng.range(22, 42)
        t.slab(B(x, y, x + 3, y + 3, 1) & f, bits[k % len(bits)], 9, bevel=0.3)


def f_pancake(t, top='crust', extra=None):
    plate(t, 25)
    t.slab(D(32, 32, 19), top, 6, profile='dome')
    t.mark(D(32, 32, 19) & (((XX + YY) % 7) == 0), -1)
    if extra == 'mayo':
        for k in range(5):
            t.slab(L(16 + k * 7, 20, 20 + k * 7, 44, 1.2) & D(32, 32, 18), 'cream', 7, bevel=0)
    if extra == 'caviar':
        dots(t, [(26, 28), (36, 30), (30, 38), (40, 38)], 'caviar', 2.5, 8)
        t.slab(D(30, 30, 4), 'cream', 7.5, profile='dome')


def f_balls(t, mat='crust', n=6, sauce='cola_d'):
    plate(t, 25, 'wood_light', oval=0.75)
    for k in range(n):
        x, y = 16 + (k % 3) * 16, 26 + (k // 3) * 12
        t.slab(D(x, y, 6), mat, 8, profile='dome')
        t.slab(L(x - 4, y - 1, x + 4, y - 3, 1.2), sauce, 9, bevel=0)


def f_dumplings(t):
    f = bowl(t, 'broth', 9, 'plastic_w', 22)
    for k in range(6):
        a = k / 6 * 2 * math.pi
        x, y = 32 + math.cos(a) * 9, 32 + math.sin(a) * 9
        t.slab(D(x, y, 5, 4), 'dough', 11, profile='dome')
    t.slab(D(32, 32, 4), 'cream', 11, profile='dome')


def f_burger(t):
    t.slab(D(32, 34, 21), 'crust', 6, bevel=2)
    t.slab(D(32, 33, 22) & ~D(32, 33, 19), 'lettuce', 8, profile='dome')
    t.slab(D(32, 32, 20), 'crust', 14, profile='dome')
    t.mark(D(32, 32, 20) & speckle(Rng(6).int(0, 9999), 0.04), 2)


def f_taco(t):
    m = Tile.poly_mask([(10, 44), (32, 12), (54, 44)])
    t.slab(m, 'paint_y', 8, profile='dome')
    t.slab(Tile.poly_mask([(16, 40), (32, 18), (48, 40)]), 'lettuce', 10, profile='dome')
    dots(t, [(28, 32), (36, 30), (32, 36)], 'tomato', 2.5, 11)
    dots(t, [(24, 36), (40, 36)], 'meat', 2.5, 11)


def f_fries(t):
    t.slab(B(18, 30, 46, 54, 3), 'plastic_r', 14, bevel=1.5)
    t.paint(B(28, 38, 36, 46, 2), 'paint_y')
    for k in range(9):
        x = 18 + k * 3.4
        t.slab(L(x, 34, x + (k % 3 - 1) * 2, 10 + (k % 4) * 3, 2.4), 'paint_y', 15, bevel=0.4)


def f_crepe(t):
    cone = Tile.poly_mask([(32, 58), (16, 16), (48, 16)])
    t.slab(cone, 'dough', 10, profile='dome')
    t.paint(cone & (YY > 34), 'paper')
    t.slab(D(32, 18, 14, 8), 'cream', 12, profile='dome')
    dots(t, [(26, 16), (36, 18), (31, 13)], 'berry', 2.5, 13)


def f_tea(t, liquid):
    cup(t, liquid, 'stone' if liquid == 'tea_green' else 'paint_w', 14)
    t.mark(D(28, 28, 3), 1)


def f_can(t, body, band):
    can(t, body, band)


def f_bottle(t, glass, label, cap='dark_steel'):
    bottle(t, glass, cap, label=label)


def f_shot(t):
    t.slab(D(32, 32, 10), 'clear', 10, bevel=1.2)
    t.paint(D(32, 32, 7), 'clear')
    t.mark(D(29, 29, 2), 2)
    bottle(t, 'clear', 'plastic_r', 8, 42, 44, 54, label='paint_w')


def f_sake(t):
    t.slab(D(22, 28, 12), 'paint_w', 16, profile='dome')
    t.slab(D(22, 28, 4), 'paint_w', 20, profile='cyl')
    t.paint(D(22, 28, 12) & ~D(22, 28, 10) & (YY > 30), 'silk_b')
    t.slab(D(44, 42, 8), 'paint_w', 7, bevel=1)
    t.paint(D(44, 42, 5.5), 'clear')


def f_bread(t):
    m = B(10, 18, 54, 46, 10)
    t.slab(m, 'bread_dark', 14, profile='dome')
    for k in range(4):
        t.mark(L(18 + k * 9, 22, 22 + k * 9, 42, 1.2) & m, -1)
    t.mark(m & speckle(Rng(7).int(0, 9999), 0.05), 1)


def f_tushonka(t):
    can(t, 'steel', 'olive_d', 17)
    t.paint(D(32, 32, 14) & ~D(32, 32, 10), 'olive_d')


def f_herring(t):
    plate(t, 25, 'plastic_w', oval=0.65)
    fish = D(32, 32, 20, 6)
    t.slab(fish, 'fish_silver', 7, profile='dome')
    t.slab(Tile.poly_mask([(10, 32), (4, 26), (4, 38)]), 'fish_silver', 6, bevel=0.5)
    t.mark(D(48, 31, 1.2), -2)
    dots(t, [(22, 44), (34, 44), (44, 42)], 'beet', 2.2, 5)


def f_natto(t):
    m = box(t, 'paint_w', 14, 14, 49, 49, 8, 2)
    f = B(17, 17, 46, 46, 1)
    t.paint(f, 'crust')
    t.h[f] -= 2
    t.mark(f & speckle(Rng(8).int(0, 9999), 0.3), -1)
    t.slab(B(20, 40, 34, 44, 1), 'paint_y', 7, bevel=0.3)


def f_mochi(t):
    for x, y, m in ((22, 26, 'cream'), (40, 26, 'blossom'), (31, 42, 'leaf')):
        t.slab(D(x, y, 9), m, 10, profile='dome')


def f_fruit(t, kind):
    if kind == 'apple':
        t.slab(D(32, 34, 17), 'apple_r', 18, profile='dome')
        t.slab(L(32, 18, 35, 12, 1.6), 'bark', 20, bevel=0)
        t.slab(D(39, 14, 4, 2.5), 'leaf', 19, profile='dome')
    elif kind == 'orange':
        t.slab(D(32, 32, 17), 'orange_f', 18, profile='dome')
        t.mark(D(32, 32, 17) & speckle(Rng(9).int(0, 9999), 0.1), -1)
        t.slab(D(32, 18, 2), 'leaf_dark', 19, profile='dome')
    else:
        arc = np.zeros((N, N), bool)
        for k in range(28):
            a = math.pi * (0.15 + 0.7 * k / 27)
            arc |= D(32 + math.cos(a) * 20, 14 + math.sin(a) * 26, 5)
        t.slab(arc, 'banana_y', 10, profile='dome')
        t.slab(D(14, 24, 2), 'bark', 11, profile='cyl')


def f_milk(t):
    m = box(t, 'milk', 18, 10, 45, 53, 18, 1)
    t.paint(B(18, 10, 45, 18), 'silk_b')
    t.mark(B(31, 10, 32, 18), -1)
    t.paint(B(22, 28, 41, 40, 2), 'container_b')


def f_brick(t, mat='protein', wrap='kraft'):
    box(t, wrap, 12, 20, 51, 43, 9, 2)
    t.paint(B(20, 20, 43, 43), mat)
    t.mark(B(20, 20, 20, 43) | B(43, 20, 43, 43), -1)


def f_glucose(t):
    for x, y in ((24, 26), (40, 24), (32, 40)):
        t.slab(B(x - 7, y - 7, x + 7, y + 7, 1), 'glucose', 10, bevel=1.5)
        t.mark(B(x - 7, y - 7, x + 7, y + 7) & speckle(Rng(x, y).int(0, 9999), 0.12), -1)


def f_gel(t):
    m = Tile.poly_mask([(16, 14), (44, 14), (48, 50), (12, 50)])
    t.slab(m, 'gel_b', 10, profile='dome')
    t.slab(B(26, 6, 34, 15, 2), 'plastic_w', 12, bevel=0.6)
    t.mark(L(18, 20, 22, 44, 1.5) & m, 2)


def f_chocolate(t):
    m = box(t, 'chocolate', 10, 18, 53, 45, 6, 1)
    for k in range(5):
        t.mark(B(10 + k * 9, 18, 10 + k * 9, 45), -1)
    t.mark(B(10, 31, 53, 31), -1)
    t.slab(B(34, 14, 56, 49, 1), 'lacquer_red', 7, bevel=0.6)
    t.paint(B(34, 14, 56, 49) & (XX == 44), 'gold')


def f_cheese(t):
    w = Tile.poly_mask([(10, 46), (54, 46), (40, 16)])
    t.slab(w, 'cheese', 12, bevel=2)
    for x, y, r in ((30, 36, 3), (42, 38, 2.4), (36, 28, 2)):
        t.carve(D(x, y, r) & w, 2)


FOODS = {
    'cup_ramen': f_cup_ramen, 'gyoza': f_gyoza, 'onigiri': f_onigiri, 'sashimi': f_sashimi, 'yakitori': f_skewer,
    'katsu': lambda t: f_bento(t), 'unagi': f_donburi, 'miso': lambda t: f_soup(t, 'broth', ('lettuce', 'cream')),
    'okonomiyaki': lambda t: f_pancake(t, 'crust', 'mayo'), 'takoyaki': lambda t: f_balls(t), 'pelmeni': f_dumplings,
    'borscht': lambda t: f_soup(t, 'broth_red', ('cream', 'beet')), 'blini': lambda t: f_pancake(t, 'dough'),
    'caviar_blini': lambda t: f_pancake(t, 'dough', 'caviar'), 'solyanka': lambda t: f_soup(t, 'broth', ('meat', 'tomato', 'lettuce')),
    'piroshki': lambda t: f_balls(t, 'crust', 4, 'crust'), 'kotleta': lambda t: f_bento(t, 'meat'),
    'chow_mein': lambda t: (bowl(t, 'noodle', 10, 'plastic_w', 22), [t.slab(L(16 + k * 5, 20, 22 + k * 4, 44, 1.6) & D(32, 32, 18), 'noodle', 10, bevel=0) for k in range(6)],
                            dots(t, [(26, 28), (38, 36), (30, 40)], 'lettuce', 2.5, 10)),
    'fried_rice': lambda t: (bowl(t, 'rice', 10, 'plastic_w', 22), t.paint(D(32, 32, 18) & speckle(Rng(11).int(0, 9999), 0.12), 'egg'),
                             t.paint(D(32, 32, 18) & speckle(Rng(12).int(0, 9999), 0.06), 'lettuce')),
    'hamburger': f_burger, 'taco': f_taco, 'fries': f_fries, 'crepe': f_crepe,
    'sencha': lambda t: f_tea(t, 'tea_green'), 'oolong': lambda t: f_tea(t, 'tea_amber'),
    'kan_coffee': lambda t: f_can(t, 'coffee', 'paint_w'), 'kvass': lambda t: f_bottle(t, 'kvass_b', 'paper'),
    'kompot': lambda t: (t.slab(D(32, 32, 16), 'clear', 16, bevel=1.5), t.paint(D(32, 32, 13), 'berry'), t.slab(D(32, 32, 16) & ~D(32, 32, 14), 'steel', 17, bevel=0.3)),
    'cola': lambda t: f_can(t, 'plastic_r', 'paint_w'), 'beer': lambda t: f_bottle(t, 'beer_a', 'paint_w', 'gold'),
    'vodka': f_shot, 'sake': f_sake, 'black_bread': f_bread, 'tushonka': f_tushonka, 'herring': f_herring, 'natto': f_natto,
    'mochi': f_mochi, 'apple': lambda t: f_fruit(t, 'apple'), 'orange': lambda t: f_fruit(t, 'orange'),
    'banana': lambda t: f_fruit(t, 'banana'), 'milk': f_milk, 'protein': lambda t: f_brick(t), 'glucose': f_glucose,
    'hydrogel': f_gel, 'chocolate': f_chocolate, 'cheese': f_cheese,
}


# ------------------------------------------------------------------------------------------------ ammunition
CAL = {'9mm': (1.0, 'brass_case'), '357': (1.15, 'brass_case'), '556': (1.3, 'brass_case'), '762': (1.45, 'brass_case'),
       '338': (1.6, 'brass_case'), '127': (1.9, 'brass_case'), '12ga': (1.5, 'shell_red'), '40mm': (2.2, 'olive_d'),
       'cell': (1.2, 'tank_w')}
TIP = {'fmj': 'copper_tip', 'ap': 'hazard_k', 'hp': 'copper_tip', 'shot': 'brass_case', 'slug': 'dark_steel', 'he': 'paint_y',
       'cell': 'neon_cyan'}


def ammo(t, cal, kind):
    s, case = CAL.get(cal, (1.2, 'brass_case'))
    m = box(t, 'kraft' if cal not in ('40mm', 'cell') else 'olive_d', 8, 8, 55, 34, 10, 2)
    band = {'fmj': 'paint_w', 'ap': 'hazard_k', 'hp': 'plastic_r', 'shot': 'shell_red', 'slug': 'paint_y', 'he': 'paint_y',
            'cell': 'neon_cyan'}[kind]
    if band.startswith('neon'):
        t.emit(B(8, 20, 55, 23), band)
    else:
        t.paint(B(8, 20, 55, 23), band)
    n = max(2, int(5 / s))
    w = 4 * s
    for k in range(n):
        x = 14 + k * (40 / n)
        L_ = 14 * s
        body_ = B(x, 40, x + w, 40 + L_ * 0.6, w / 2)
        t.slab(body_, case, 5 * s, profile='dome')
        tip = D(x + w / 2, 40 + L_ * 0.6 + 2, w / 2)
        if kind == 'cell':
            t.emit(tip, 'neon_cyan')
        else:
            t.slab(tip, TIP.get(kind, 'copper_tip'), 5 * s, profile='dome')
        if kind == 'hp':
            t.mark(D(x + w / 2, 40 + L_ * 0.6 + 2, 1), -2)


# ------------------------------------------------------------------------------------------------ weapon mods
def mod(t, k):
    if k in ('redot', 'holo', 'smartlink', 'laser'):
        box(t, 'dark_steel', 16, 22, 47, 41, 10, 3)
        t.slab(B(16, 40, 47, 44), 'rubber', 4, bevel=0)
        lens = {'redot': 'neon_red', 'holo': 'neon_green', 'smartlink': 'neon_cyan', 'laser': 'neon_red'}[k]
        if k == 'holo':
            t.slab(B(20, 14, 43, 22, 1), 'clear', 12, bevel=0.5)
            t.emit(D(31.5, 18, 2), lens)
        elif k == 'laser':
            t.emit(D(44, 31, 3), lens)
            t.slab(B(16, 26, 40, 36, 2), 'container_b', 11, bevel=0.5)
        else:
            t.emit(D(31.5, 31, 4), lens)
            if k == 'smartlink':
                t.slab(L(47, 31, 58, 44, 2), 'rubber', 4, bevel=0)
    elif k in ('scope4', 'scope8'):
        ln = 22 if k == 'scope4' else 28
        t.slab(B(32 - ln, 24, 32 + ln, 39, 7), 'dark_steel', 12, profile='dome')
        t.slab(B(32 - ln - 2, 22, 32 - ln + 6, 41, 3), 'dark_steel', 13, profile='dome')
        t.slab(B(32 + ln - 6, 22, 32 + ln + 2, 41, 3), 'dark_steel', 13, profile='dome')
        t.slab(D(32, 31, 4), 'steel', 15, profile='cyl')
        t.paint(B(32 + ln - 2, 26, 32 + ln + 2, 37), 'glass')
    elif k == 'foregrip':
        t.slab(B(14, 26, 50, 34, 2), 'dark_steel', 6, bevel=0.6)
        t.slab(B(26, 30, 38, 54, 4), 'rubber', 10, profile='dome')
        t.mark(B(26, 36, 38, 52) & ((YY % 4) == 0), -1)
    elif k == 'bipod':
        t.slab(B(26, 20, 38, 30, 2), 'dark_steel', 8, bevel=0.6)
        for x in (28, 36):
            t.slab(L(x, 28, x + (x - 32) * 2.5, 56, 3), 'steel', 6, bevel=0.5)
    elif k in ('suppressor', 'longbarrel', 'shortbarrel', 'compensator', 'flashhider', 'choke'):
        ln = {'suppressor': 48, 'longbarrel': 52, 'shortbarrel': 40, 'compensator': 28, 'flashhider': 30, 'choke': 28}[k]
        r = {'suppressor': 8, 'longbarrel': 4, 'shortbarrel': 5, 'compensator': 7, 'flashhider': 6.5, 'choke': 6.5}[k]
        x0 = 32 - ln / 2
        body_ = B(x0, 32 - r, x0 + ln, 32 + r, r)
        t.slab(body_, 'dark_steel', 2 * r, profile='dome')
        if k == 'compensator':
            for j in range(3):
                t.carve(B(x0 + 5 + j * 5, 30, x0 + 7 + j * 5, 34), 3)
        if k == 'flashhider':
            for j in range(4):
                t.carve(B(x0 + ln - 9, 28 + j * 3, x0 + ln, 29 + j * 3), 3)
        if k == 'suppressor':
            t.mark(body_ & ((XX % 8) == 0), -1)
        t.slab(B(x0 - 3, 32 - r * 0.5, x0, 32 + r * 0.5), 'steel', r + 1, bevel=0.3)
    elif k in ('extmag', 'quickmag'):
        mag = Tile.poly_mask([(22, 10), (36, 10), (44, 54), (30, 56)])
        t.slab(mag, 'dark_steel', 9, bevel=1.2)
        t.mark(mag & ((YY % 6) == 0), -1)
        t.slab(B(24, 8, 34, 12, 1), 'brass_case', 10, bevel=0.3)
        if k == 'quickmag':
            t.slab(B(30, 52, 50, 56, 2), 'plastic_r', 10, bevel=0.5)
    elif k == 'drum':
        t.slab(D(32, 34, 20), 'dark_steel', 12, bevel=1.5)
        t.mark(D(32, 34, 14) & ~D(32, 34, 13), -1)
        t.slab(D(32, 34, 5), 'steel', 14, profile='cyl')
        t.slab(B(26, 6, 38, 16, 1), 'dark_steel', 10, bevel=0.6)
    elif k in ('stock', 'cheekrest'):
        st = Tile.poly_mask([(8, 26), (40, 22), (56, 14), (58, 48), (44, 44), (8, 36)])
        t.slab(st, 'rubber' if k == 'stock' else 'wood_dark', 10, bevel=1.5)
        if k == 'cheekrest':
            t.slab(B(26, 18, 46, 28, 4), 'fabric_b', 13, profile='dome')
        t.slab(B(54, 14, 60, 48, 2), 'rubber', 11, bevel=0.6)
    else:
        box(t, 'dark_steel')


# ------------------------------------------------------------------------------------------------ gear
def bag(t, mat, x0=12, y0=10, x1=51, y1=54, straps=True, flap=True):
    m = B(x0, y0, x1, y1, 8)
    t.slab(m, mat, 14, profile='dome')
    if flap:
        t.slab(B(x0 + 3, y0 + 2, x1 - 3, y0 + 18, 6), mat, 16, profile='dome')
        t.mark(B(x0 + 3, y0 + 18, x1 - 3, y0 + 18), -1)
        t.slab(B(29, y0 + 14, 34, y0 + 20, 1), 'dark_steel', 17, bevel=0.3)
    if straps:
        for x in (x0 + 6, x1 - 8):
            t.slab(B(x, y0 - 2, x + 3, y1 - 6), 'rubber', 15, bevel=0.3)


def armour(t, k):
    if k in ('helmet', 'helm_tac', 'visor'):
        t.slab(D(32, 32, 22, 20), 'kevlar' if k != 'visor' else 'container_b', 16, profile='dome')
        t.mark(D(32, 32, 22, 20) & ~D(32, 32, 20, 18), -1)
        if k == 'visor':
            t.slab(B(16, 36, 48, 50, 5) & D(32, 32, 23, 21), 'glass', 14, profile='dome')
        if k == 'helm_tac':
            t.slab(B(26, 10, 38, 18, 2), 'dark_steel', 18, bevel=0.5)
            t.emit(D(32, 14, 1.5), 'neon_green')
            t.slab(B(8, 28, 14, 40, 2) | B(50, 28, 56, 40, 2), 'dark_steel', 14, bevel=0.5)
    elif k in ('vest', 'vest_heavy', 'vest_corp', 'jacket'):
        mat = {'vest': 'kevlar', 'vest_heavy': 'olive_d', 'vest_corp': 'fabric_b', 'jacket': 'rubber'}[k]
        m = Tile.poly_mask([(16, 8), (26, 12), (38, 12), (48, 8), (52, 56), (12, 56)])
        if k == 'jacket':
            m |= B(4, 12, 16, 44, 4) | B(48, 12, 60, 44, 4)
        t.slab(m, mat, 10, bevel=2)
        t.carve(D(32, 6, 9) & m, 4)
        if k == 'vest_heavy':
            t.slab(B(20, 18, 44, 40, 2), 'dark_steel', 13, bevel=1)
            for y in (44, 50):
                t.slab(B(16, y, 48, y + 4, 1), 'olive_d', 12, bevel=0.5)
        if k == 'vest':
            t.mark(m & ((YY % 8) == 0), -1)
        if k == 'jacket':
            t.slab(B(29, 12, 34, 56), 'dark_steel', 11, bevel=0.3)
            t.slab(B(8, 16, 14, 30, 2) | B(50, 16, 56, 30, 2), 'dark_steel', 12, bevel=0.6)
    elif k in ('bracers', 'bracers_heavy', 'greaves', 'greaves_heavy', 'kneepads'):
        mat = 'dark_steel' if k.endswith('heavy') else 'kevlar'
        for x in (20, 44):
            if k == 'kneepads':
                t.slab(D(x, 32, 11, 13), 'rubber', 10, profile='dome')
                t.slab(D(x, 30, 7, 8), 'dark_steel', 12, profile='dome')
            else:
                ln = 20 if k.startswith('bracers') else 24
                m = B(x - 8, 32 - ln, x + 8, 32 + ln, 6)
                t.slab(m, mat, 10, profile='dome')
                t.mark(m & ((YY % 10) == 0), -1)
                t.slab(B(x - 9, 32 - ln + 6, x + 9, 32 - ln + 9) | B(x - 9, 32 + ln - 9, x + 9, 32 + ln - 6), 'rubber', 11, bevel=0.3)
    elif k == 'balaclava':
        m = D(32, 32, 20, 22)
        t.slab(m, 'rubber', 10, profile='dome')
        t.carve(B(20, 24, 44, 32, 3), 4)
        t.paint(B(21, 25, 43, 31, 3), 'ink')
        t.mark(m & ((XX + YY) % 4 == 0), -1)


def engine(t, k):
    col = {'city': 'container_b', 'mini': 'paint_w', 'sport': 'plastic_r', 'haul': 'paint_y', 'rotor': 'steel', 'reactor': 'tank_w'}[k]
    if k == 'rotor':
        t.slab(D(32, 32, 22), 'dark_steel', 14, bevel=1.5)
        for j in range(10):
            a = j / 10 * 2 * math.pi
            t.slab(L(32, 32, 32 + math.cos(a) * 18, 32 + math.sin(a) * 18, 3), 'steel', 15, bevel=0.3)
        t.slab(D(32, 32, 5), 'chrome', 17, profile='dome')
    elif k == 'reactor':
        t.slab(D(32, 32, 22), 'tank_w', 16, profile='dome')
        t.emit(D(32, 32, 9), 'neon_cyan')
        t.emit(D(32, 32, 12) & ~D(32, 32, 11), 'neon_cyan')
        for j in range(4):
            a = j / 4 * 2 * math.pi + 0.78
            t.slab(D(32 + math.cos(a) * 17, 32 + math.sin(a) * 17, 3), 'hazard_y', 17, profile='dome')
    else:
        sz = {'city': 16, 'mini': 12, 'sport': 16, 'haul': 22}[k]
        m = B(32 - sz - 4, 32 - sz * 0.7, 32 + sz, 32 + sz * 0.7, 4)
        t.slab(m, col, 14, bevel=2)
        for j in range(5):
            t.mark(B(32 - sz, 32 - sz * 0.7 + 3 + j * sz * 0.25, 32 + sz - 4, 32 - sz * 0.7 + 3 + j * sz * 0.25), -1)
        t.slab(D(32 + sz + 2, 32, 5), 'chrome', 12, profile='cyl')
        t.slab(B(32 - sz - 8, 32 - 3, 32 - sz - 3, 32 + 3, 1), 'copper', 10, bevel=0.3)
        t.emit(B(32 - 6, 32 - sz * 0.7 + 2, 32, 32 - sz * 0.7 + 4), 'neon_green')


def faith(t, k):
    if k == 'candle':
        t.slab(D(32, 34, 6), 'wax', 18, profile='cyl')
        t.emit(D(32, 30, 2.5), 'fire')
        t.slab(D(32, 34, 12) & ~D(32, 34, 6), 'brass', 4, bevel=0.8)
    elif k == 'icon':
        box(t, 'wood_dark', 14, 10, 49, 53, 6, 1, 'icon_gold')
        t.slab(D(31.5, 28, 7), 'wood_light', 8, profile='dome')
        t.paint(D(31.5, 28, 9) & ~D(31.5, 28, 7.5), 'gold')
        t.paint(B(24, 38, 39, 50, 2), 'fabric_r')
    elif k == 'gospel':
        box(t, 'lacquer_black', 14, 10, 49, 53, 8, 2)
        t.paint(B(14, 50, 49, 53), 'paper')
        t.paint(B(29, 18, 34, 42) | B(22, 24, 41, 29), 'gold')
    elif k == 'omamori':
        m = B(20, 14, 43, 52, 4)
        t.slab(m, 'silk_r', 8, profile='dome')
        t.paint(B(23, 24, 40, 44, 2), 'gold')
        t.slab(L(31.5, 14, 31.5, 4, 1.4) | D(31.5, 4, 2.5), 'silk_b', 9, bevel=0)
    elif k == 'ofuda':
        t.slab(B(22, 6, 41, 58, 1), 'paper', 3, bevel=0.5)
        t.paint(B(28, 12, 35, 50), 'lacquer_red')
        t.mark(B(29, 16, 34, 46) & ((YY % 5) == 0), -2)
    elif k == 'ema':
        m = Tile.poly_mask([(10, 24), (32, 10), (54, 24), (54, 52), (10, 52)])
        t.slab(m, 'wood_light', 5, bevel=1)
        t.paint(D(32, 36, 8), 'lacquer_red')
        t.slab(L(26, 14, 38, 14, 1.4), 'silk_r', 6, bevel=0)


def misc(t, n):
    if n == 'trl_backpack':
        bag(t, 'container_b')
    elif n == 'trl_duffel':
        t.slab(B(6, 20, 57, 44, 11), 'canvas_bag', 14, profile='dome')
        t.slab(L(12, 28, 52, 28, 2), 'dark_steel', 15, bevel=0)
        t.slab(B(26, 12, 38, 22, 3) & ~B(29, 15, 35, 22), 'rubber', 16, bevel=0.3)
    elif n == 'trl_pouch':
        bag(t, 'canvas_bag', 18, 18, 45, 48, straps=False)
    elif n == 'trl_holster':
        m = Tile.poly_mask([(22, 8), (42, 8), (44, 34), (36, 56), (24, 56), (20, 34)])
        t.slab(m, 'rubber', 10, profile='dome')
        t.slab(B(20, 8, 44, 14, 2), 'dark_steel', 12, bevel=0.5)
        t.slab(B(16, 36, 48, 40), 'canvas_bag', 11, bevel=0.3)
    elif n == 'trl_coat':
        m = Tile.poly_mask([(20, 6), (44, 6), (54, 58), (10, 58)])
        t.slab(m, 'kraft', 10, bevel=2)
        t.mark(L(32, 8, 32, 58, 1) & m, -1)
        t.slab(Tile.poly_mask([(22, 6), (32, 18), (42, 6)]), 'kraft', 12, profile='dome')
        dots(t, [(29, 26), (29, 36), (29, 46)], 'dark_steel', 1.6, 11)
    elif n == 'trl_water_bottle':
        bottle(t, 'clear', 'plastic_b', 10, 24, 54, 40)
        t.paint(B(12, 30, 38, 38, 3) & t.obj, 'water')
    elif n == 'trl_water':
        m = D(32, 34, 22, 14)
        t.ground('water', m, 0)
        t.mark(D(26, 30, 8, 4), 1)
        t.mark(m & ~D(32, 34, 20, 12), -1)
    elif n == 'trl_yen':
        for i, (x, y) in enumerate(((24, 40), (30, 32), (36, 24))):
            t.slab(B(x - 16, y - 8, x + 16, y + 8, 1), 'note_g', 2 + i, bevel=0.5)
            t.mark(D(x + 6, y, 4) & B(x - 16, y - 8, x + 16, y + 8), 1)
            t.mark(B(x - 14, y - 6, x + 14, y - 6), -1)
    elif n == 'trl_ammo':
        ammo(t, '9mm', 'fmj')
    elif n == 'trl_ration':
        f_brick(t, 'chocolate', 'olive_d')
    elif n == 'trl_parcel':
        box(t, 'kraft', 10, 14, 53, 49, 14, 2)
        t.paint(B(28, 14, 35, 49) | B(10, 28, 53, 35), 'paper')
        t.paint(B(38, 38, 50, 46, 1), 'paint_w')
    elif n == 'trl_datacase':
        box(t, 'card_k', 10, 16, 53, 49, 13, 4)
        t.slab(B(24, 8, 39, 16, 3) & ~B(27, 11, 36, 16), 'dark_steel', 13, bevel=0.4)
        t.mark(B(10, 31, 53, 32), -2)
        t.emit(D(18, 42, 1.5), 'neon_violet')
        t.emit(D(24, 42, 1.5), 'neon_cyan')
    elif n == 'trl_medkit':
        box(t, 'paint_w', 8, 16, 55, 49, 12, 4)
        t.paint(B(28, 21, 35, 44) | B(20, 29, 43, 36), 'red_cross')
        t.slab(B(24, 10, 39, 16, 2), 'steel', 12, bevel=0.5)
    elif n == 'trl_kit_repair':
        box(t, 'container_o', 8, 18, 55, 49, 12, 3)
        t.slab(B(22, 10, 41, 18, 3) & ~B(25, 13, 38, 18), 'rubber', 13, bevel=0.4)
        t.mark(B(8, 30, 55, 31), -2)
        t.slab(D(48, 40, 2.5), 'chrome', 13, profile='cyl')
    elif n == 'trl_credstick':
        m = Tile.poly_mask([(10, 44), (14, 38), (50, 20), (54, 24), (50, 34), (14, 50)])
        t.slab(m, 'card_k', 5, bevel=1)
        t.emit(D(46, 27, 2), 'neon_cyan')
        t.slab(L(16, 44, 36, 34, 1.6), 'gold', 6, bevel=0)
    else:
        box(t, 'body2')


def icon(item):
    """the icon Tile for an item dict (from the game's data/items.json)"""
    n = item['id']
    tags = item.get('tags', [])
    t = piece()
    if n.startswith('trl_good_'):
        import goods
        if not goods.g(n[9:], t):
            box(t, 'kraft')
    elif n.startswith('trl_food_') and n[9:] in FOODS:
        FOODS[n[9:]](t)
    elif n.startswith('trl_ammo_'):
        p = n.split('_')
        ammo(t, p[2], p[3] if len(p) > 3 else 'fmj')
    elif n.startswith('trl_mod_'):
        mod(t, n[8:])
    elif n.startswith('trl_eng_'):
        engine(t, n[8:])
    elif n.startswith('trl_faith_'):
        faith(t, n[10:])
    elif n[4:] in ('helmet', 'helm_tac', 'visor', 'vest', 'vest_heavy', 'vest_corp', 'jacket', 'bracers', 'bracers_heavy',
                   'greaves', 'greaves_heavy', 'kneepads', 'balaclava'):
        armour(t, n[4:])
    else:
        misc(t, n)
    return done(t, shadow=n != 'trl_water')


def is_drawn_here(item):
    """guns and melee weapons keep their approved designs"""
    return not (item['id'].startswith('trl_gun_') or item['id'].startswith('trl_mel_'))
