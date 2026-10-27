"""Icons for the shop goods (the game's trl_good_* items, tools/content goods list): what stands on the shelves of the
bakeries, pharmacies, pawn shops and hardware stores.  Same rules as items.py: seen from above, about 48 px across,
outlined, no lettering (labels are bands of colour)."""
import math

import numpy as np

from canvas import Tile, XX, YY, Rng, speckle
from items import D, B, L, bowl, plate, cup, can, bottle, box, dots, bag


def poly(*pts):
    return Tile.poly_mask(list(pts))


def label(t, m, mat, y0, y1):
    t.paint(m & (YY >= y0) & (YY <= y1), mat)


def jar(t, mat, lid, r=14, cx=32, cy=32):
    t.slab(D(cx, cy, r), mat, 14, bevel=1.5)
    t.slab(D(cx, cy, r - 3), lid, 16, bevel=1)
    t.mark(D(cx, cy, r - 5) & ~D(cx, cy, r - 6), -1)


def tub(t, body_, lid, r=16):
    t.slab(D(32, 32, r), body_, 14, bevel=1.2)
    t.slab(D(32, 32, r - 2), lid, 15, bevel=0.8)
    t.mark(D(32, 32, r - 2) & ~D(32, 32, r - 3), -1)


def tin(t, mat, lid='chrome', x0=16, y0=16, x1=47, y1=47, r=4):
    t.slab(B(x0, y0, x1, y1, r), mat, 12, bevel=1)
    t.slab(B(x0 + 3, y0 + 3, x1 - 3, y1 - 3, r - 1), lid, 13, bevel=0.6)


def garment(t, mat, trim=None, sleeves=True):
    pts = [(20, 10), (26, 8), (32, 12), (38, 8), (44, 10), (46, 54), (18, 54)]
    m = poly(*pts)
    t.slab(m, mat, 6, bevel=2)
    if sleeves:
        t.slab(poly((20, 10), (8, 26), (14, 32), (20, 22)), mat, 5, bevel=1.5)
        t.slab(poly((44, 10), (56, 26), (50, 32), (44, 22)), mat, 5, bevel=1.5)
    t.mark(D(32, 10, 5, 3) & m, -2)
    if trim:
        t.paint(m & (YY > 50), trim)
    return m


def stack_of(t, mat, n, x0, y0, x1, y1, dy=-3):
    for k in range(n):
        m = B(x0, y0 + k * dy, x1, y1 + k * dy, 1)
        t.slab(m, mat if k % 2 == 0 else mat, 3, bevel=0.6)
        t.mark(B(x0, y1 + k * dy, x1, y1 + k * dy), -1)


def coil(t, mat, r=18, inner=8, cx=32, cy=32):
    t.slab(D(cx, cy, r) & ~D(cx, cy, inner), mat, 8, profile='dome')
    for rr in range(inner + 3, r, 3):
        t.mark(D(cx, cy, rr) & ~D(cx, cy, rr - 1), -1)


# ------------------------------------------------------------------------------------------------ the goods
def g(name, t):
    n = name
    if n == 'loaf_bread':
        m = B(10, 18, 53, 45, 12)
        t.slab(m, 'crust', 14, profile='dome')
        for x in (20, 30, 40):
            t.mark(L(x, 22, x + 6, 40, 1.5) & m, 1)
    elif n == 'melon_pan':
        m = D(32, 32, 20)
        t.slab(m, 'cheese', 12, profile='dome')
        t.mark(m & ((((XX + YY) % 8) == 0) | (((XX - YY) % 8) == 0)), -1)
    elif n == 'pastry_box':
        box(t, 'paint_w', 8, 14, 55, 49, 12, 2)
        t.paint(B(11, 17, 52, 46) & ((XX % 10) < 2), 'blossom')
        t.paint(D(32, 31, 7, 5), 'glass')
        t.paint(D(32, 31, 5, 3), 'cream')
    elif n == 'coffee_beans':
        bag(t, 'kraft', 14, 8, 49, 56, straps=False, flap=False)
        t.paint(B(14, 8, 49, 14), 'dark_steel')
        dots(t, [(26, 34), (34, 30), (38, 40), (28, 44)], 'coffee', 2.8, 11)
    elif n == 'tea_tin':
        t.slab(D(32, 32, 16), 'lacquer_red', 18, bevel=1)
        t.slab(D(32, 32, 13), 'gold', 19, bevel=0.6)
        t.mark(D(32, 32, 9) & ~D(32, 32, 8), -1)
    elif n == 'rice_sack':
        m = B(10, 8, 53, 56, 8)
        t.slab(m, 'canvas_w', 14, profile='dome')
        t.paint(B(10, 26, 53, 38) & m, 'fabric_b')
        t.slab(L(24, 8, 40, 8, 4), 'canvas_w', 15, bevel=0.6)
        t.mark(m & speckle(Rng(5).int(0, 999), 0.05), -1)
    elif n == 'produce_crate':
        box(t, 'wood_light', 6, 12, 57, 51, 10, 1)
        t.carve(B(9, 15, 54, 48), 3)
        for k, mat in enumerate(['apple_r', 'orange_f', 'lettuce', 'apple_r', 'orange_f', 'tomato']):
            dots(t, [(15 + (k % 3) * 16, 23 + (k // 3) * 16)], mat, 6, 9)
    elif n == 'fish_crate':
        box(t, 'plastic_b', 6, 12, 57, 51, 10, 2)
        t.carve(B(9, 15, 54, 48), 3)
        t.paint(B(9, 15, 54, 48) & speckle(Rng(7).int(0, 999), 0.3), 'foam')
        for y in (22, 34, 44):
            f = poly((12, y), (44, y - 4), (50, y), (44, y + 4))
            t.slab(f, 'fish_silver', 10, profile='dome')
            t.slab(poly((50, y), (56, y - 4), (56, y + 4)), 'fish_silver', 9, profile='dome')
    elif n == 'soy_sauce':
        bottle(t, 'cola_d', 'plastic_r', 10, 24, 54, 40, label='paint_w')
    elif n == 'canned_fish':
        t.slab(B(10, 18, 53, 45, 9), 'chrome', 6, bevel=1)
        t.paint(B(10, 18, 53, 45, 9) & ~B(13, 21, 50, 42, 7), 'container_b')
        t.mark(B(15, 23, 48, 40, 6) & ~B(16, 24, 47, 39, 6), -1)
        t.slab(D(44, 31, 3) & ~D(44, 31, 1.5), 'steel', 7)
    elif n == 'snack_bag':
        m = poly((12, 10), (52, 10), (54, 54), (10, 54))
        t.slab(m, 'container_o', 9, profile='dome')
        t.paint(B(10, 10, 54, 14) | B(10, 50, 54, 54), 'paint_y')
        t.slab(D(32, 32, 7), 'meat_fried', 10, profile='dome')
        t.mark(L(18, 16, 30, 50, 1) & m, 2)
    elif n == 'detergent_box':
        box(t, 'container_b', 12, 10, 51, 53, 16, 1)
        t.paint(B(15, 22, 48, 36), 'paint_w')
        t.paint(D(32, 29, 5), 'gel_b')
        t.slab(B(26, 10, 37, 14), 'plastic_w', 17, bevel=0.4)
    elif n == 'sake_bottle':
        bottle(t, 'paint_w', 'fabric_b', 8, 22, 56, 42, label='fabric_indigo')
    elif n == 'whisky_bottle':
        t.slab(B(12, 20, 44, 44, 3), 'beer_a', 11, bevel=1.5)
        t.slab(B(42, 28, 54, 36, 2), 'beer_a', 9, profile='dome')
        t.slab(B(53, 27, 57, 37, 1), 'wood_dark', 10, bevel=0.5)
        t.paint(B(18, 22, 30, 42), 'paper')
        t.mark(L(14, 23, 40, 23, 1.2), 2)
    elif n == 'vodka_bottle':
        bottle(t, 'clear', 'dark_steel', 8, 24, 56, 40, label='silk_r')
    elif n == 'beer_crate':
        box(t, 'container_g', 6, 10, 57, 53, 12, 2)
        for r_ in range(3):
            for c_ in range(4):
                x, y = 13 + c_ * 12, 18 + r_ * 13
                t.slab(D(x, y, 4.5), 'kvass_b', 15, profile='dome')
                t.slab(D(x, y, 2.2), 'brass_case', 16, profile='cyl')
    elif n == 'cocktail_shaker':
        t.slab(B(14, 20, 50, 44, 11), 'chrome', 10, profile='dome')
        t.slab(B(46, 24, 56, 40, 4), 'chrome', 9, profile='dome')
        t.mark(B(36, 20, 37, 44) & t.obj, -1)
    elif n == 'tumbler_box':
        box(t, 'paint_w', 8, 10, 55, 53, 10, 2)
        for x, y in ((20, 22), (43, 22), (20, 42), (43, 42)):
            t.slab(D(x, y, 8), 'glass', 12, bevel=0.8)
            t.carve(D(x, y, 5.5), 2)
    elif n == 'bandage_roll':
        t.slab(B(10, 18, 40, 46, 4), 'paint_w', 14, profile='dome')
        t.mark(B(10, 18, 40, 46) & ((XX % 4) == 0), -1)
        t.slab(B(38, 26, 56, 38, 1), 'paint_w', 3, bevel=0.5)
    elif n == 'pill_bottle':
        t.slab(D(32, 32, 14), 'container_o', 16, bevel=1)
        t.slab(D(32, 32, 12), 'paint_w', 17, bevel=0.6)
        t.mark(D(32, 32, 12) & ((np.round(np.arctan2(YY - 32, XX - 32) * 5) % 2) == 0) & ~D(32, 32, 10), -1)
        dots(t, [(14, 50), (20, 54), (50, 14)], 'paint_w', 2.5, 3)
    elif n == 'cough_syrup':
        bottle(t, 'cola_d', 'paint_w', 12, 24, 52, 40, label='laminate_g')
        t.slab(D(18, 50, 5), 'plastic_w', 4, bevel=0.6)
    elif n == 'saline_bag':
        m = B(14, 8, 49, 48, 6)
        t.slab(m, 'clear', 6, profile='dome')
        t.paint(B(18, 18, 45, 30), 'paint_w')
        t.slab(L(32, 48, 32, 58, 3), 'plastic_w', 4, bevel=0.5)
        t.slab(B(28, 4, 36, 9, 2) & ~B(30, 6, 34, 9), 'plastic_w', 6, bevel=0.4)
    elif n == 'surgical_gloves':
        for k, dx in enumerate((0, 12)):
            hand = B(12 + dx, 26, 30 + dx, 52, 6)
            t.slab(hand, 'gel_b', 4 + k, profile='dome')
            for j in range(4):
                t.slab(B(12 + dx + j * 5, 10 + (j % 2) * 3, 15 + dx + j * 5, 28), 'gel_b', 4 + k, profile='dome')
            t.slab(B(42 + dx // 3, 34, 50 + dx // 3, 42, 3), 'gel_b', 4 + k, profile='dome')
    elif n == 'shampoo_bottle':
        t.slab(B(16, 14, 44, 52, 8), 'enamel_teal', 14, profile='dome')
        t.slab(B(26, 6, 36, 14, 2), 'paint_w', 15, bevel=0.6)
        t.paint(B(20, 28, 40, 40), 'paint_w')
    elif n == 'hair_dye_box':
        box(t, 'paint_w', 12, 10, 51, 53, 12, 1)
        t.paint(B(15, 13, 48, 50) & (XX < 32), 'velvet_v')
        t.paint(D(38, 28, 7), 'blossom')
    elif n == 'hair_wax_tin':
        t.slab(D(32, 32, 17), 'dark_steel', 9, bevel=1)
        t.slab(D(32, 32, 14), 'paint_y', 10, bevel=0.6)
        t.mark(D(32, 32, 8) & ~D(32, 32, 7), -1)
    elif n == 'hairbrush':
        t.slab(L(10, 50, 30, 30, 6), 'wood', 6, profile='dome')
        m = D(40, 22, 14, 11)
        t.slab(m, 'wood', 7, profile='dome')
        t.paint(D(40, 22, 11, 8), 'rubber')
        t.mark(D(40, 22, 11, 8) & ((XX % 3) == 0) & ((YY % 3) == 0), 2)
    elif n == 'laundry_basket':
        m = B(8, 12, 55, 52, 8)
        t.slab(m, 'plastic_b', 12, bevel=1.5)
        t.carve(B(12, 16, 51, 48, 6), 5)
        t.mark(m & ~B(12, 16, 51, 48, 6) & ((XX % 4) < 2), -1)
        t.slab(D(26, 32, 9, 7), 'paint_w', 9, profile='dome')
        t.slab(D(40, 36, 8, 6), 'fabric_b', 9, profile='dome')
    elif n == 't_shirt':
        garment(t, 'fabric_b')
    elif n == 'jeans':
        m = poly((18, 8), (46, 8), (50, 56), (36, 56), (32, 24), (28, 56), (14, 56))
        t.slab(m, 'fabric_indigo', 6, bevel=2)
        t.mark(L(32, 10, 32, 24, 1), -1)
        t.paint(B(18, 8, 46, 11), 'fabric_b')
        t.slab(D(37, 10, 1.2), 'brass', 7)
    elif n == 'sneakers':
        for dx in (0, 18):
            m = D(23 + dx, 32, 8, 20)
            t.slab(m, 'paint_w', 8, profile='dome')
            t.paint(D(23 + dx, 22, 4, 7), 'fabric_b')
            t.paint(m & (np.abs(XX - 23 - dx) > 6), 'rubber')
    elif n == 'dress':
        m = poly((24, 6), (40, 6), (42, 22), (54, 58), (10, 58), (22, 22))
        t.slab(m, 'velvet_v', 6, bevel=2)
        t.paint(B(20, 20, 44, 23) & m, 'gold')
        t.mark(m & (((XX - 32) % 8) == 0) & (YY > 30), -1)
    elif n == 'kimono':
        garment(t, 'fabric_indigo', sleeves=False)
        t.slab(poly((20, 10), (6, 18), (6, 40), (20, 40)), 'fabric_indigo', 5, bevel=1.5)
        t.slab(poly((44, 10), (58, 18), (58, 40), (44, 40)), 'fabric_indigo', 5, bevel=1.5)
        t.paint(B(18, 28, 46, 34), 'fabric_o')
        t.paint(L(26, 10, 36, 28, 2) & t.obj, 'paint_w')
        t.paint(speckle(Rng(11).int(0, 999), 0.03) & t.obj & ~B(18, 28, 46, 34), 'blossom')
    elif n == 'scarf':
        t.slab(L(12, 14, 50, 22, 9), 'silk_r', 5, profile='dome')
        t.slab(L(46, 22, 30, 52, 9), 'silk_r', 6, profile='dome')
        t.mark(t.obj & (((XX + YY) % 6) == 0), -1)
        t.mark(L(26, 50, 36, 56, 2), -1)
    elif n == 'television':
        t.slab(B(6, 14, 57, 46, 2), 'graphite', 8, bevel=1)
        t.paint(B(9, 17, 54, 43), 'screen')
        t.mark(L(12, 40, 30, 19, 2) & B(9, 17, 54, 43), 2)
        t.slab(B(24, 48, 39, 54, 1), 'dark_steel', 4, bevel=0.6)
    elif n == 'radio':
        box(t, 'enamel_cream', 8, 16, 55, 47, 12, 4)
        t.paint(D(22, 32, 9), 'kraft')
        t.mark(D(22, 32, 9) & ((XX % 2) == 0), -1)
        t.slab(D(44, 26, 3), 'chrome', 13, profile='dome')
        t.slab(D(44, 38, 3), 'chrome', 13, profile='dome')
        t.slab(L(14, 16, 50, 6, 1.4), 'chrome', 13, bevel=0)
    elif n == 'headphones':
        t.slab((np.abs(np.hypot(XX - 32, YY - 36) - 18) < 2.5) & (YY < 36), 'graphite', 8, bevel=0.8)
        for x in (14, 50):
            t.slab(D(x, 40, 7, 9), 'graphite', 9, profile='dome')
            t.paint(D(x, 40, 4, 6), 'leather_k')
        t.emit(D(50, 34, 1.2), 'neon_cyan')
    elif n == 'game_console':
        box(t, 'paint_w', 10, 18, 53, 45, 8, 4)
        t.mark(B(10, 31, 53, 31), -1)
        t.emit(B(14, 22, 18, 23), 'neon_cyan')
        t.slab(D(42, 54, 6, 4) | D(30, 54, 6, 4), 'graphite', 6, profile='dome')
    elif n == 'phone_handset':
        t.slab(B(20, 6, 43, 57, 5), 'graphite', 6, bevel=1)
        t.slab(B(22, 9, 41, 53, 3), 'screen', 7, bevel=0.4)
        t.emit(B(24, 12, 39, 22), 'screen_glow')
        t.mark(L(24, 50, 38, 26, 1) & B(22, 9, 41, 53), 1)
    elif n == 'desk_lamp':
        t.slab(D(18, 46, 10), 'dark_steel', 4, bevel=1)
        t.slab(L(18, 46, 30, 26, 3), 'chrome', 10, bevel=0)
        t.slab(L(30, 26, 44, 22, 3), 'chrome', 12, bevel=0)
        t.slab(D(46, 22, 9), 'enamel_g', 14, profile='dome')
        t.emit(D(48, 24, 4), 'lamp')
    elif n == 'paperback':
        t.slab(B(14, 10, 49, 53, 1), 'paper', 6, bevel=0.6)
        t.slab(B(12, 8, 47, 51, 1), 'fabric_o', 7, bevel=0.6)
        t.paint(D(30, 26, 8), 'paint_y')
    elif n == 'manga_volume':
        t.slab(B(14, 8, 49, 55, 1), 'paint_w', 8, bevel=0.6)
        t.paint(B(14, 8, 49, 20), 'plastic_r')
        t.paint(D(32, 38, 9, 11), 'ink')
        t.paint(D(30, 36, 4), 'paint_w')
    elif n == 'magazine':
        t.slab(B(12, 6, 51, 57, 1), 'blossom', 3, bevel=0.5)
        t.paint(D(32, 34, 12, 15), 'fabric_cream')
        t.paint(B(14, 8, 49, 16), 'ink')
        t.mark(L(14, 50, 46, 10, 1), 2)
    elif n == 'toner_cartridge':
        t.slab(B(6, 22, 57, 41, 4), 'graphite', 10, bevel=1)
        t.paint(B(10, 26, 26, 37), 'container_b')
        t.slab(B(44, 18, 52, 22), 'dark_steel', 11, bevel=0.4)
    elif n == 'label_printer':
        box(t, 'enamel_grey', 10, 14, 53, 49, 10, 4)
        t.paint(B(14, 18, 34, 28), 'screen')
        t.emit(B(15, 19, 33, 22), 'neon_green')
        dots(t, [(16 + (k % 6) * 6, 36 + (k // 6) * 6) for k in range(12)], 'dark_steel', 1.8, 11)
        t.slab(B(48, 22, 58, 28), 'paper', 6, bevel=0.3)
    elif n == 'toolbox':
        box(t, 'enamel_b', 6, 18, 57, 49, 12, 2)
        t.mark(B(6, 32, 57, 32), -2)
        t.slab(B(22, 12, 41, 18, 2) & ~B(25, 15, 38, 18), 'dark_steel', 13, bevel=0.4)
        t.slab(B(28, 30, 35, 35), 'chrome', 13, bevel=0.3)
    elif n == 'paint_can':
        can(t, 'enamel_teal', 'chrome', r=17)
        t.paint(D(32, 32, 13), 'enamel_teal')
        t.mark(D(32, 32, 13) & ~D(32, 32, 12), -1)
        t.slab((np.abs(np.hypot(XX - 32, YY - 32) - 19) < 1) & (YY < 32), 'steel', 14, bevel=0)
    elif n == 'rope_coil':
        coil(t, 'kraft', 21, 7)
    elif n == 'padlock':
        t.slab((np.abs(np.hypot(XX - 32, YY - 22) - 9) < 2.5) & (YY < 26), 'chrome', 10, bevel=0.4)
        t.slab(B(16, 24, 47, 52, 4), 'brass', 12, bevel=1)
        t.mark(D(32, 36, 2.5) | B(31, 36, 33, 44), -2)
    elif n == 'nail_box':
        box(t, 'kraft', 12, 14, 51, 49, 9, 1)
        t.carve(B(15, 17, 48, 46), 3)
        for k in range(14):
            x = 18 + (k * 7) % 28
            y = 20 + (k * 11) % 24
            t.slab(L(x, y, x + 8, y + 3 - (k % 3) * 3, 1.4), 'steel', 8, bevel=0)
    elif n == 'lightbulb_pack':
        box(t, 'paint_w', 10, 12, 53, 51, 8, 2)
        for x in (22, 42):
            t.slab(D(x, 28, 8), 'glass', 10, profile='dome')
            t.paint(D(x, 28, 3), 'lamp_dead')
            t.slab(B(x - 3, 37, x + 3, 44), 'brass', 9, bevel=0.4)
    elif n == 'extension_cord':
        coil(t, 'paint_y', 18, 9)
        t.slab(B(42, 42, 56, 52, 2), 'paint_w', 10, bevel=0.6)
        t.mark(B(46, 45, 47, 49) | B(51, 45, 52, 49), -2)
    elif n == 'gi_uniform':
        m = B(10, 12, 53, 51, 2)
        t.slab(m, 'paint_w', 9, bevel=1)
        t.mark(L(18, 12, 32, 32, 1.5) | L(46, 12, 32, 32, 1.5), -1)
        t.slab(B(8, 30, 55, 34), 'ink', 10, bevel=0.4)
    elif n == 'training_belt':
        coil(t, 'ink', 18, 10)
        t.slab(B(28, 40, 34, 58, 1), 'ink', 7, bevel=0.5)
        t.paint(B(28, 52, 34, 55), 'gold')
    elif n == 'hand_wraps':
        coil(t, 'silk_r', 13, 4, 22, 30)
        coil(t, 'silk_r', 13, 4, 42, 36)
    elif n == 'tatami_roll':
        m = B(6, 20, 57, 43, 10)
        t.slab(m, 'tatami', 14, profile='dome')
        t.mark(m & ((XX % 3) == 0), -1)
        t.paint(B(6, 20, 9, 43) | B(54, 20, 57, 43), 'fabric_g')
    elif n == 'protein_tub':
        tub(t, 'graphite', 'paint_y', 18)
    elif n == 'gym_bag':
        m = B(6, 18, 57, 47, 10)
        t.slab(m, 'graphite', 13, profile='dome')
        t.paint(B(6, 30, 57, 34) & m, 'silk_r')
        t.slab((np.abs(np.hypot(XX - 32, YY - 22) - 12) < 2) & (YY < 22), 'rubber', 14, bevel=0)
    elif n == 'gym_towel':
        stack_of(t, 'fabric_b', 3, 12, 20, 51, 44)
        t.paint(B(12, 38, 51, 40) & t.obj, 'paint_w')
    elif n == 'cleaning_kit':
        box(t, 'olive_d', 8, 14, 55, 49, 8, 3)
        t.carve(B(11, 17, 52, 46), 3)
        t.slab(L(14, 24, 50, 24, 2), 'dark_steel', 7, bevel=0)
        t.slab(B(16, 32, 30, 42, 1), 'paint_w', 7, bevel=0.5)
        t.slab(D(42, 38, 5), 'cola_d', 8, profile='cyl')
    elif n == 'gun_case':
        m = B(4, 16, 59, 47, 5)
        t.slab(m, 'graphite', 12, bevel=1.5)
        t.mark(B(4, 31, 59, 31), -2)
        for x in (18, 46):
            t.slab(B(x - 3, 29, x + 3, 34), 'chrome', 13, bevel=0.3)
    elif n == 'ear_defenders':
        t.slab((np.abs(np.hypot(XX - 32, YY - 38) - 18) < 3) & (YY < 38), 'paint_y', 8, bevel=0.8)
        for x in (14, 50):
            t.slab(D(x, 42, 8, 10), 'paint_y', 10, profile='dome')
            t.mark(D(x, 42, 5, 7) & ~D(x, 42, 4, 6), -1)
    elif n == 'wristwatch':
        t.slab(B(26, 4, 37, 59, 3), 'leather_br', 4, bevel=0.8)
        t.slab(D(32, 32, 11), 'gold', 8, bevel=1)
        t.paint(D(32, 32, 8), 'paint_w')
        t.paint(L(32, 32, 32, 26, 1) | L(32, 32, 36, 32, 1), 'ink')
    elif n == 'gold_ring':
        t.slab(D(32, 34, 14) & ~D(32, 34, 9), 'gold', 6, profile='dome')
        t.slab(D(32, 20, 5), 'clear', 9, profile='dome')
    elif n == 'music_box':
        box(t, 'wood_dark', 10, 16, 53, 47, 12, 2)
        t.paint(B(14, 20, 49, 43), 'lacquer_red')
        t.paint(D(32, 31, 6), 'gold')
    elif n == 'camera':
        box(t, 'graphite', 8, 18, 55, 45, 12, 3)
        t.slab(D(30, 34, 11), 'dark_steel', 16, profile='cyl')
        t.paint(D(30, 34, 7), 'glass')
        t.mark(D(27, 31, 2), 2)
        t.slab(B(44, 14, 52, 18), 'chrome', 13, bevel=0.3)
    elif n == 'guitar':
        t.slab(D(22, 42, 13, 12) | D(30, 30, 9), 'wood_light', 6, bevel=1.5)
        t.carve(D(26, 37, 4), 2)
        t.slab(L(32, 28, 56, 6, 4), 'wood_dark', 7, bevel=0.5)
        t.paint(L(18, 48, 54, 8, 1) & t.obj, 'chrome')
    elif n == 'car_tire':
        t.slab(D(32, 32, 24) & ~D(32, 32, 11), 'rubber', 12, profile='dome')
        t.mark(D(32, 32, 24) & ~D(32, 32, 19) & ((np.round(np.arctan2(YY - 32, XX - 32) * 8) % 2) == 0), -1)
    elif n == 'car_battery':
        box(t, 'graphite', 10, 14, 53, 49, 14, 2)
        t.slab(D(18, 22, 3), 'silk_r', 15, profile='cyl')
        t.slab(D(45, 22, 3), 'dark_steel', 15, profile='cyl')
        t.paint(B(14, 32, 49, 44), 'paint_y')
    elif n == 'oil_can':
        t.slab(B(12, 14, 46, 52, 3), 'paint_y', 14, bevel=1)
        t.slab(B(36, 8, 44, 16, 2), 'ink', 15, bevel=0.5)
        t.paint(B(16, 26, 42, 40), 'ink')
    elif n == 'spark_plugs':
        for k, x in enumerate((20, 32, 44)):
            t.slab(B(x - 3, 10, x + 3, 30), 'paint_w', 6 + k, profile='dome')
            t.slab(B(x - 4, 30, x + 4, 40), 'steel', 6 + k, bevel=0.5)
            t.slab(B(x - 1, 40, x + 1, 52), 'chrome', 5 + k, bevel=0)
    elif n == 'key_fob':
        t.slab(D(26, 36, 13, 9), 'graphite', 6, profile='dome')
        t.slab(D(22, 34, 3), 'rubber', 7, profile='dome')
        t.slab(D(30, 38, 3), 'rubber', 7, profile='dome')
        t.slab(D(46, 22, 7) & ~D(46, 22, 4.5), 'chrome', 4, bevel=0)
        t.emit(D(34, 32, 1), 'neon_cyan')
    elif n == 'steel_bar':
        for k in range(3):
            t.slab(B(4, 20 + k * 9, 59, 27 + k * 9, 2), 'steel', 7 + (k % 2) * 3, profile='dome')
    elif n == 'bolt_crate':
        box(t, 'wood_light', 8, 12, 55, 51, 10, 1)
        t.carve(B(11, 15, 52, 48), 3)
        t.paint(B(11, 15, 52, 48) & speckle(Rng(13).int(0, 999), 0.6), 'steel')
        t.mark(B(11, 15, 52, 48) & speckle(Rng(14).int(0, 999), 0.3), -1)
    elif n == 'scrap_bundle':
        box(t, 'rust', 10, 12, 53, 51, 14, 1)
        t.paint(B(10, 12, 53, 51) & speckle(Rng(15).int(0, 999), 0.4), 'container_b')
        t.slab(B(20, 12, 22, 51) | B(40, 12, 42, 51), 'chrome', 15, bevel=0)
    elif n == 'wire_spool':
        t.slab(D(32, 32, 22), 'wood_light', 6, bevel=1)
        t.slab(D(32, 32, 17), 'copper', 10, profile='dome')
        t.mark(D(32, 32, 17) & ((np.hypot(XX - 32, YY - 32) % 3) < 1), -1)
        t.slab(D(32, 32, 5), 'wood_dark', 11, profile='cyl')
    elif n == 'welding_rods':
        t.slab(B(10, 18, 53, 45, 3), 'olive_d', 8, bevel=1)
        for k in range(5):
            t.slab(L(6, 22 + k * 5, 58, 22 + k * 5, 1.6), 'steel', 10, bevel=0)
    elif n == 'machine_part':
        t.slab(D(32, 32, 20), 'steel', 10, bevel=1)
        t.mark(D(32, 32, 20) & ((np.round(np.arctan2(YY - 32, XX - 32) * 12 / math.pi) % 2) == 0) & ~D(32, 32, 17), -2)
        t.carve(D(32, 32, 7), 4)
        t.paint(D(32, 32, 7), 'dark_steel')
    elif n == 'candle_box':
        box(t, 'paint_w', 10, 14, 53, 49, 8, 1)
        for k in range(5):
            t.slab(B(14 + k * 8, 18, 18 + k * 8, 46, 2), 'wax', 10, profile='dome')
    elif n == 'prayer_beads':
        for k in range(18):
            a = k / 18 * 2 * math.pi
            t.slab(D(32 + math.cos(a) * 17, 28 + math.sin(a) * 15, 3), 'wood_dark', 5, profile='dome')
        t.slab(L(32, 43, 32, 56, 2), 'silk_r', 3, bevel=0)
        t.slab(D(32, 56, 3), 'silk_r', 4, profile='dome')
    elif n == 'incense_sticks':
        t.slab(B(10, 36, 53, 46, 3), 'kraft', 6, bevel=0.8)
        for k in range(6):
            t.slab(L(14 + k * 6, 40, 20 + k * 6, 8, 1.5), 'meat', 7, bevel=0)
        t.emit(D(20, 8, 1.2), 'fire')
    elif n == 'ema_plaque':
        m = poly((10, 20), (32, 8), (54, 20), (54, 52), (10, 52))
        t.slab(m, 'wood_light', 5, bevel=1)
        t.paint(D(32, 34, 9), 'lacquer_red')
        t.slab(L(32, 14, 32, 4, 1.5), 'silk_r', 6, bevel=0)
    elif n == 'holy_water':
        t.slab(D(32, 36, 14, 16), 'clear', 12, profile='dome')
        t.slab(B(28, 12, 36, 20, 2), 'clear', 11, profile='dome')
        t.slab(B(27, 8, 37, 12, 1), 'gold', 12, bevel=0.4)
        t.paint(B(31, 28, 33, 44) | B(25, 33, 39, 35), 'gold')
    elif n == 'microphone':
        t.slab(L(16, 48, 38, 26, 6), 'graphite', 8, profile='dome')
        t.slab(D(42, 22, 9), 'chrome', 10, profile='dome')
        t.mark(D(42, 22, 8) & (((XX + YY) % 3) == 0), -1)
    elif n == 'vinyl_record':
        t.slab(B(8, 8, 55, 55, 1), 'velvet_v', 3, bevel=0.6)
        t.slab(D(38, 32, 21), 'ink', 4, bevel=0.6)
        t.mark(D(38, 32, 19) & ((np.hypot(XX - 38, YY - 32) % 3) < 1), 1)
        t.paint(D(38, 32, 6), 'paint_y')
    elif n == 'arcade_tokens':
        for x, y in ((22, 26), (40, 22), (30, 40), (44, 40), (18, 44)):
            t.slab(D(x, y, 7), 'brass_case', 4, bevel=0.6)
            t.mark(D(x, y, 4) & ~D(x, y, 3), -1)
    elif n == 'game_cartridge':
        t.slab(B(14, 10, 49, 53, 2), 'enamel_grey', 6, bevel=0.8)
        t.paint(B(18, 14, 45, 38), 'velvet_v')
        t.paint(D(31, 26, 6), 'paint_y')
        t.mark(B(18, 44, 45, 50) & ((XX % 3) == 0), -1)
    elif n == 'glow_sticks':
        for k, c in enumerate(('neon_green', 'neon_pink', 'neon_cyan')):
            m = L(14 + k * 8, 52, 30 + k * 8, 10, 4)
            t.slab(m, 'clear', 5, bevel=0.5)
            t.emit(L(15 + k * 8, 49, 29 + k * 8, 13, 2), c)
    elif n == 'towel_stack':
        stack_of(t, 'paint_w', 4, 12, 24, 51, 46)
    elif n == 'suitcase':
        box(t, 'leather_br', 8, 14, 55, 51, 12, 4)
        t.paint(B(8, 22, 55, 24) | B(8, 42, 55, 44), 'leather_k')
        t.slab(B(24, 8, 39, 14, 2) & ~B(27, 11, 36, 14), 'leather_k', 12, bevel=0.4)
    elif n == 'room_key':
        t.slab(B(12, 26, 34, 50, 4), 'wood_dark', 5, bevel=0.8)
        t.paint(B(16, 30, 30, 46, 2), 'gold')
        t.slab(D(40, 26, 5) & ~D(40, 26, 2.5), 'brass', 4, bevel=0)
        t.slab(L(44, 22, 56, 10, 2.4), 'brass', 4, bevel=0)
    elif n == 'mail_sack':
        m = D(32, 36, 22, 20)
        t.slab(m, 'canvas_bag', 14, profile='dome')
        t.slab(B(24, 6, 40, 18, 3), 'canvas_bag', 12, profile='dome')
        t.paint(B(10, 34, 54, 40) & m, 'fabric_b')
    elif n == 'packing_tape':
        t.slab(D(32, 32, 20) & ~D(32, 32, 10), 'kraft', 10, profile='dome')
        t.slab(D(32, 32, 10) & ~D(32, 32, 8), 'paper', 11, bevel=0)
        t.slab(B(48, 28, 58, 36), 'kraft', 4, bevel=0.3)
    elif n == 'handcuffs':
        for x in (20, 44):
            t.slab(D(x, 32, 11) & ~D(x, 32, 7), 'chrome', 5, bevel=0.6)
        t.slab(L(30, 32, 34, 32, 2.5), 'steel', 5, bevel=0)
    elif n == 'evidence_bag':
        m = B(10, 8, 53, 55, 2)
        t.slab(m, 'clear', 4, bevel=0.8)
        t.paint(B(10, 8, 53, 14), 'paint_y')
        t.paint(B(14, 18, 34, 28), 'paint_w')
        t.slab(B(26, 34, 44, 48, 2), 'dark_steel', 5, bevel=0.5)
    elif n == 'coin_roll':
        for k, y in enumerate((22, 34, 46)):
            t.slab(B(10, y - 5, 53, y + 5, 4), ['kraft', 'container_b', 'laminate_g'][k], 9, profile='dome')
            t.paint(B(10, y - 5, 13, y + 5) | B(50, y - 5, 53, y + 5), 'brass_case')
    elif n == 'deposit_key':
        t.slab(D(18, 32, 8) & ~D(18, 32, 3.5), 'brass', 4, bevel=0.5)
        t.slab(B(24, 30, 54, 34), 'brass', 4, bevel=0.4)
        t.slab(B(44, 34, 47, 40) | B(50, 34, 53, 38), 'brass', 4, bevel=0.3)
    elif n == 'rubber_stamp':
        t.slab(D(32, 40, 15, 9), 'ink', 6, bevel=0.6)
        t.slab(L(32, 40, 32, 20, 7), 'wood', 12, profile='dome')
        t.slab(D(32, 16, 8), 'wood', 14, profile='dome')
    elif n == 'blank_id_card':
        t.slab(B(8, 16, 55, 47, 3), 'paint_w', 3, bevel=0.6)
        t.paint(B(12, 22, 26, 38, 1), 'enamel_grey')
        t.paint(B(30, 22, 50, 25) | B(30, 30, 46, 32), 'enamel_grey')
        t.paint(B(30, 38, 38, 43), 'gold')
    elif n == 'rice_cooker':
        t.slab(D(32, 34, 21, 19), 'paint_w', 14, profile='dome')
        t.slab(D(32, 30, 15, 12), 'enamel_cream', 16, profile='dome')
        t.slab(B(26, 50, 38, 54), 'dark_steel', 10, bevel=0.4)
        t.emit(D(32, 50, 1.2), 'neon_amber')
    elif n == 'kettle':
        t.slab(D(30, 34, 17), 'chrome', 14, profile='dome')
        t.slab(L(44, 30, 56, 22, 4), 'chrome', 12, bevel=0.5)
        t.slab((np.abs(np.hypot(XX - 30, YY - 28) - 10) < 2) & (YY < 28), 'ink', 17, bevel=0)
    elif n == 'cooking_pot':
        bowl(t, 'broth', 12, 'steel', 20)
        t.slab(B(4, 30, 12, 34, 1) | B(52, 30, 60, 34, 1), 'ink', 10, bevel=0.4)
    elif n == 'bedding_bundle':
        m = B(8, 14, 55, 49, 8)
        t.slab(m, 'fabric_indigo', 14, profile='dome')
        t.paint(B(8, 28, 55, 34) & m, 'linen')
        t.slab(B(28, 14, 34, 49), 'kraft', 15, bevel=0.4)
    elif n == 'alarm_clock':
        t.slab(D(32, 34, 16), 'enamel_teal', 12, bevel=1)
        t.paint(D(32, 34, 12), 'paint_w')
        t.paint(L(32, 34, 32, 26, 1) | L(32, 34, 38, 36, 1), 'ink')
        for x in (20, 44):
            t.slab(D(x, 16, 5), 'chrome', 13, profile='dome')
    elif n == 'houseplant':
        t.slab(D(32, 34, 13), 'rock_red', 10, bevel=1)
        t.paint(D(32, 34, 10), 'soil')
        for k in range(7):
            a = k * 0.9
            t.slab(D(32 + math.cos(a) * 12, 30 + math.sin(a) * 12, 7, 4), 'leaf' if k % 2 else 'leaf_dark', 14, profile='dome')
    elif n == 'tea_set':
        t.slab(B(6, 14, 57, 49, 3), 'wood_dark', 3, bevel=0.6)
        t.slab(D(24, 30, 10), 'stone_dark', 12, profile='dome')
        t.slab(L(32, 24, 40, 18, 3), 'stone_dark', 10, bevel=0.5)
        for x in (40, 50):
            t.slab(D(x, 40, 4.5), 'stone_dark', 6, bevel=0.6)
            t.paint(D(x, 40, 3), 'tea_green')
    elif n == 'laptop':
        t.slab(B(8, 10, 55, 53, 2), 'alu', 4, bevel=0.6)
        t.paint(B(12, 14, 51, 30), 'screen')
        t.emit(B(13, 15, 50, 29), 'screen_glow')
        t.mark(B(12, 34, 51, 46) & ((XX % 3) == 0) & ((YY % 3) == 0), -1)
        t.mark(B(24, 48, 39, 51), -1)
    elif n == 'briefcase':
        box(t, 'leather_k', 6, 18, 57, 49, 12, 3)
        t.slab(B(24, 12, 39, 18, 2) & ~B(27, 15, 36, 18), 'leather_k', 12, bevel=0.4)
        t.slab(B(14, 30, 20, 34) | B(43, 30, 49, 34), 'gold', 13, bevel=0.3)
    elif n == 'company_badge':
        t.slab(B(18, 18, 45, 55, 3), 'paint_w', 3, bevel=0.6)
        t.paint(B(22, 24, 41, 38, 1), 'enamel_b')
        t.paint(B(22, 42, 41, 44), 'enamel_grey')
        t.slab(L(26, 18, 22, 4, 2) | L(38, 18, 42, 4, 2), 'container_b', 3, bevel=0)
        t.emit(D(32, 50, 1.2), 'neon_cyan')
    elif n == 'coffee_mug':
        cup(t, 'coffee', 'enamel_b', 15)
        t.slab((np.abs(np.hypot(XX - 48, YY - 32) - 5) < 2) & (XX > 46), 'enamel_b', 12, bevel=0.4)
    elif n == 'water_jug':
        t.slab(D(32, 32, 20), 'clear', 16, profile='dome')
        t.paint(D(32, 32, 16), 'water')
        t.slab(D(32, 32, 6), 'plastic_b', 18, profile='cyl')
    else:
        return False
    return True


NAMES = ['loaf_bread', 'melon_pan', 'pastry_box', 'coffee_beans', 'tea_tin', 'rice_sack', 'produce_crate', 'fish_crate',
         'soy_sauce', 'canned_fish', 'snack_bag', 'detergent_box', 'sake_bottle', 'whisky_bottle', 'vodka_bottle', 'beer_crate',
         'cocktail_shaker', 'tumbler_box', 'bandage_roll', 'pill_bottle', 'cough_syrup', 'saline_bag', 'surgical_gloves',
         'shampoo_bottle', 'hair_dye_box', 'hair_wax_tin', 'hairbrush', 'laundry_basket', 't_shirt', 'jeans', 'sneakers', 'dress',
         'kimono', 'scarf', 'television', 'radio', 'headphones', 'game_console', 'phone_handset', 'desk_lamp', 'paperback',
         'manga_volume', 'magazine', 'toner_cartridge', 'label_printer', 'toolbox', 'paint_can', 'rope_coil', 'padlock',
         'nail_box', 'lightbulb_pack', 'extension_cord', 'gi_uniform', 'training_belt', 'hand_wraps', 'tatami_roll',
         'protein_tub', 'gym_bag', 'gym_towel', 'cleaning_kit', 'gun_case', 'ear_defenders', 'wristwatch', 'gold_ring',
         'music_box', 'camera', 'guitar', 'car_tire', 'car_battery', 'oil_can', 'spark_plugs', 'key_fob', 'steel_bar',
         'bolt_crate', 'scrap_bundle', 'wire_spool', 'welding_rods', 'machine_part', 'candle_box', 'prayer_beads',
         'incense_sticks', 'ema_plaque', 'holy_water', 'microphone', 'vinyl_record', 'arcade_tokens', 'game_cartridge',
         'glow_sticks', 'towel_stack', 'suitcase', 'room_key', 'mail_sack', 'packing_tape', 'handcuffs', 'evidence_bag',
         'coin_roll', 'deposit_key', 'rubber_stamp', 'blank_id_card', 'rice_cooker', 'kettle', 'cooking_pot', 'bedding_bundle',
         'alarm_clock', 'houseplant', 'tea_set', 'laptop', 'briefcase', 'company_badge', 'coffee_mug', 'water_jug']
