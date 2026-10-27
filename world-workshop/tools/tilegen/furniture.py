"""Furniture and fittings: everything the game places in rooms, shops, clinics, churches, shrines and the docks.

Seen from above like the rest of the world.  A piece is a body (a raised slab with a top surface), the things on it,
and a contact shadow on the floor.  Builders name roles: 'body' and 'top' (the piece's own materials, marble and brass
downtown, laminate in the slums), 'accent', 'trim', plus fixed materials where the object is what it is (a red
lacquer shrine, a white fridge).  The theme's wear is applied last: grime, chips and rust where the world is worn."""
import math

import numpy as np

from canvas import Tile, N, XX, YY, Rng, blotches, speckle, cracks
from themes import style


def piece():
    return Tile('', periodic=False)


def body(t, x0, y0, x1, y1, h, mat='body', top='top', r=2.0, inset=2, bevel=1.5):
    m = Tile.box_mask(x0, y0, x1, y1, r)
    t.slab(m, mat, h, bevel=bevel)
    if top:
        tm = Tile.box_mask(x0 + inset, y0 + inset, x1 - inset, y1 - inset, max(0.0, r - 1))
        t.paint(tm, top)
        t.mark(tm & ~Tile.box_mask(x0 + inset + 1, y0 + inset + 1, x1 - inset - 1, y1 - inset - 1), 1)
    return m


def on(t, mask, mat, h, bevel=0.8, profile='bevel'):
    """a thing standing on the surface below it"""
    return t.slab(mask, mat, h, bevel=bevel, profile=profile)


def legs(t, x0, y0, x1, y1, mat='trim', r=1.6, h=4):
    for x, y in ((x0, y0), (x1, y0), (x0, y1), (x1, y1)):
        t.slab(Tile.disk_mask(x, y, r), mat, h, bevel=0.4)


def finish(t, theme, rng, mask=None, shadow=True, cells=4, amount=1.0):
    st = style(theme)
    o = t.obj if mask is None else mask
    if st['grime'] > 0.2:
        t.mark(o & blotches(rng.int(0, 1 << 20), st['grime'] * 0.6 * amount, cells=cells) & ~t.glow, -1)
    if st['rust'] > 0.3:
        mt = np.isin(t.m, ['steel', 'dark_steel', 'body2', 'trim', 'chrome'])
        t.paint(o & mt & blotches(rng.int(0, 1 << 20), st['rust'] * 0.35 * amount, cells=cells) & ~t.glow, 'rust')
    if st['wear'] > 0.6:
        c = cracks(rng.int(0, 1 << 20), 1, 8, region=o) & o & ~t.glow
        t.mark(c, -1)
    if shadow:
        t.drop_shadow(t.solid.copy(), 3, 3, 0.42)
    return t


def screen(t, x0, y0, x1, y1, mat='screen_glow', lines=True):
    m = Tile.box_mask(x0, y0, x1, y1)
    t.emit(m, mat)
    if lines:
        t.mark(m & (((YY - y0) % 3) == 0), -1)
    return m


# ------------------------------------------------------------------------------------------------ the generic pieces
def chair(theme, rng):
    t = piece()
    seat = body(t, 20, 24, 43, 45, 6, 'body', 'fabric_b' if theme != 'slum' else 'fabric_r', r=3)
    back = Tile.box_mask(20, 16, 43, 23, 2)
    t.slab(back, 'body2', 10, bevel=1.0)
    return finish(t, theme, rng)


def table(theme, rng):
    t = piece()
    legs(t, 12, 14, 51, 49, 'trim', h=6)
    body(t, 8, 10, 55, 53, 8, 'body', 'top', r=3)
    if theme != 'slum':
        on(t, Tile.disk_mask(24, 26, 4), 'plastic_w', 1.5, profile='dome')
    return finish(t, theme, rng)


def crate(theme, rng):
    t = piece()
    m = body(t, 8, 8, 55, 55, 12, 'wood', 'wood', r=1, inset=3)
    slats = m & (((XX - 8) % 12) < 2) & ~Tile.box_mask(11, 11, 52, 52)
    t.mark(slats, -1)
    t.mark(Tile.line_mask(11, 11, 52, 52, 3) & m, 1)
    t.mark(Tile.box_mask(11, 11, 52, 52) & ~Tile.box_mask(13, 13, 50, 50), -1)
    return finish(t, theme, rng)


def dumpster(theme, rng):
    t = piece()
    col = {'rich': 'plastic_b', 'mid': 'container_g', 'slum': 'container_g', 'rural': 'container_g', 'industry': 'container_o'}[theme]
    m = body(t, 4, 12, 59, 53, 13, col, col, r=2, inset=3)
    lid = Tile.box_mask(7, 15, 31, 50) | Tile.box_mask(33, 15, 56, 50)
    t.mark(Tile.box_mask(32, 15, 32, 50), -2)
    t.mark(lid & ((YY % 9) == 0), -1)
    if theme == 'slum':
        bags = Tile.disk_mask(14, 58, 6, 4) | Tile.disk_mask(26, 60, 5, 3)
        on(t, bags, 'rubber', 4, profile='dome')
    return finish(t, theme, rng)


def planter(theme, rng):
    t = piece()
    st = style(theme)
    pot = {'rich': 'wall', 'mid': 'concrete', 'slum': 'concrete', 'rural': 'wood', 'industry': 'dark_steel'}[theme]
    m = body(t, 8, 8, 55, 55, 7, pot, None, r=4)
    soil = Tile.box_mask(13, 13, 50, 50, 3)
    t.paint(soil, 'soil')
    t.h[soil] -= 1
    n = 9 if st['plants'] > 0.6 else (6 if st['plants'] > 0.3 else 3)
    for k in range(n):
        x, y, r = rng.range(17, 46), rng.range(17, 46), rng.range(5, 8)
        mat = 'leaf' if k % 3 else 'leaf_dark'
        if theme == 'slum' and k % 2:
            mat = 'grass_dry'
        t.slab(Tile.disk_mask(x, y, r) & Tile.box_mask(11, 11, 52, 52, 3), mat, 5 + rng.range(0, 4), profile='dome', obj=(k % 3 == 0))
    if theme == 'rich':
        for k in range(5):
            t.slab(Tile.disk_mask(rng.range(18, 46), rng.range(18, 46), 2), 'blossom', 10, profile='dome', obj=False)
    return finish(t, theme, rng)


def tree(theme, rng, v=0):
    """a tree seen from above: trunk shadow, a layered canopy lit from the top left"""
    t = piece()
    kind = {'rich': 'ornamental', 'mid': 'round', 'slum': 'scraggly', 'rural': ['pine', 'birch', 'round'][v % 3], 'industry': 'scraggly'}[theme]
    if kind == 'pine':
        for k, r in enumerate((27, 21, 15, 9, 4)):
            ring = Tile.disk_mask(32, 32, r)
            on(t, ring, 'leaf_dark' if k % 2 == 0 else 'leaf', 4 + k * 3, bevel=2.5)
            if k < 4:
                spikes = ring & ~Tile.disk_mask(32, 32, r - 3) & (((np.arctan2(YY - 32, XX - 32) * 10 / math.pi).astype(int) % 2) == 0)
                t.mark(spikes, -1)
    elif kind == 'birch':
        for k in range(7):
            x, y, r = 32 + rng.range(-14, 14), 32 + rng.range(-14, 14), rng.range(8, 13)
            on(t, Tile.disk_mask(x, y, r), 'leaf' if k % 3 else 'grass_dry', 10 + rng.range(0, 6), profile='dome')
        t.mark(speckle(rng.int(0, 1 << 20), 0.08) & t.obj, 1)
    else:
        n = {'ornamental': 9, 'round': 8, 'scraggly': 6}[kind]
        rad = {'ornamental': (9, 13), 'round': (9, 14), 'scraggly': (6, 10)}[kind]
        for k in range(n):
            a = k / n * 2 * math.pi + rng.range(-0.3, 0.3)
            d = rng.range(6, 14) if k else 0
            x, y = 32 + math.cos(a) * d, 32 + math.sin(a) * d
            mat = 'leaf_dark' if k % 3 == 0 else 'leaf'
            if kind == 'scraggly' and k % 2:
                mat = 'grass_dry'
            on(t, Tile.disk_mask(x, y, rng.range(*rad)), mat, 12 + rng.range(0, 6), profile='dome')
        if kind == 'ornamental':
            bl = speckle(rng.int(0, 1 << 20), 0.05) & t.obj & (t.h > 14)
            t.paint(bl | np.roll(bl, 1, 1), 'blossom')
        if kind == 'scraggly':
            for k in range(4):
                a = rng.range(0, 2 * math.pi)
                br = Tile.line_mask(32, 32, 32 + math.cos(a) * 26, 32 + math.sin(a) * 26, 1.5)
                t.slab(br & ~t.obj, 'bark', 8, bevel=0.3)
    t.drop_shadow(t.solid.copy(), 5, 5, 0.38)
    return t


# ------------------------------------------------------------------------------------------------ shops and eateries
def counter(theme, rng):
    t = piece()
    m = body(t, 2, 18, 61, 45, 11, 'body', 'top', r=1)
    t.noline |= (XX == 0) | (XX == 63)
    on(t, Tile.box_mask(8, 22, 18, 30, 1), 'dark_steel', 3)
    screen(t, 10, 24, 16, 28, 'screen_glow', lines=False)
    on(t, Tile.box_mask(40, 24, 52, 34, 1), 'paper', 1)
    if theme == 'rich':
        t.paint(Tile.box_mask(2, 43, 61, 45), 'accent')
    return finish(t, theme, rng)


def noodle_counter(theme, rng):
    t = piece()
    body(t, 2, 16, 61, 44, 11, 'wood' if theme != 'industry' else 'body', 'wood_light', r=1)
    t.noline |= (XX == 0) | (XX == 63)
    for x in (14, 32, 50):
        on(t, Tile.disk_mask(x, 26, 6), 'lacquer_red' if x != 32 else 'lacquer_black', 4, profile='dome')
        t.paint(Tile.disk_mask(x, 26, 3.5), 'foam')
        t.slab(Tile.line_mask(x + 2, 20, x + 8, 30, 1), 'wood_light', 6, bevel=0)
    t.emit(Tile.box_mask(4, 40, 59, 41), style(theme)['neon'][0])
    return finish(t, theme, rng)


def kitchen_range(theme, rng):
    t = piece()
    body(t, 6, 8, 57, 55, 12, 'steel', 'dark_steel', r=2)
    for x, y in ((20, 22), (43, 22), (20, 42), (43, 42)):
        ring = Tile.disk_mask(x, y, 8) & ~Tile.disk_mask(x, y, 5)
        on(t, ring, 'ink', 1)
        t.emit(Tile.disk_mask(x, y, 2) & ~Tile.disk_mask(x, y, 1), 'fire' if (x + y) % 3 else 'neon_amber')
    return finish(t, theme, rng)


def fridge(theme, rng):
    t = piece()
    body(t, 10, 6, 53, 57, 16, 'plastic_w', 'plastic_w', r=3)
    t.mark(Tile.box_mask(13, 26, 50, 26), -2)
    on(t, Tile.box_mask(46, 12, 48, 22), 'chrome', 1)
    on(t, Tile.box_mask(46, 30, 48, 44), 'chrome', 1)
    return finish(t, theme, rng)


def sushi_case(theme, rng):
    t = piece()
    body(t, 2, 14, 61, 49, 10, 'body', 'glass', r=1)
    t.noline |= (XX == 0) | (XX == 63)
    for k in range(8):
        x = 8 + k * 7
        col = ['fabric_r', 'paint_w', 'container_o', 'fabric_r', 'leaf', 'paint_w', 'container_o', 'fabric_r'][k]
        on(t, Tile.box_mask(x, 26, x + 4, 32, 1), col, 1.2)
        on(t, Tile.box_mask(x, 34, x + 4, 40, 1), 'paint_w', 1.2)
    t.mark(Tile.line_mask(4, 18, 59, 46, 1) & t.obj, 2)
    return finish(t, theme, rng)


def pizza_oven(theme, rng):
    t = piece()
    dome = Tile.disk_mask(32, 30, 25, 22)
    t.slab(dome, 'stone' if theme != 'rich' else 'wall', 16, profile='dome')
    mouth = Tile.disk_mask(32, 50, 10, 6)
    t.emit(mouth & dome, 'fire')
    t.mark(dome & speckle(rng.int(0, 1 << 20), 0.06), -1)
    on(t, Tile.disk_mask(32, 12, 4), 'dark_steel', 6)
    return finish(t, theme, rng)


def dining_table(theme, rng):
    t = piece()
    for x, y in ((32, 6), (32, 58), (6, 32), (58, 32)):
        on(t, Tile.box_mask(x - 6, y - 5, x + 6, y + 5, 2), 'body2', 5)
    body(t, 12, 12, 51, 51, 9, 'body', 'top' if theme != 'rural' else 'wood_light', r=3)
    on(t, Tile.disk_mask(24, 24, 4), 'plastic_w', 1.5, profile='dome')
    on(t, Tile.disk_mask(40, 40, 4), 'plastic_w', 1.5, profile='dome')
    on(t, Tile.disk_mask(32, 32, 2.5), 'glass', 4, profile='cyl')
    return finish(t, theme, rng)


def table_plastic(theme, rng):
    t = piece()
    m = Tile.disk_mask(32, 32, 22)
    t.slab(m, 'plastic_w' if theme != 'slum' else 'plastic_r', 8, bevel=1.5)
    t.mark(Tile.disk_mask(32, 32, 20) & ~Tile.disk_mask(32, 32, 19), -1)
    on(t, Tile.disk_mask(26, 28, 3), 'plastic_r', 2, profile='dome')
    return finish(t, theme, rng)


def tea_table(theme, rng):
    t = piece()
    body(t, 10, 16, 53, 47, 5, 'lacquer_black' if theme != 'slum' else 'wood_dark', 'lacquer_black' if theme != 'slum' else 'wood', r=2)
    on(t, Tile.disk_mask(26, 31, 5), 'stone_dark', 4, profile='dome')
    on(t, Tile.disk_mask(38, 28, 2.5), 'paper', 2, profile='cyl')
    on(t, Tile.disk_mask(40, 37, 2.5), 'paper', 2, profile='cyl')
    return finish(t, theme, rng)


def stool(theme, rng, bar=False):
    t = piece()
    if bar:
        on(t, Tile.disk_mask(32, 32, 4), 'chrome', 6)
        t.slab(Tile.disk_mask(32, 32, 14), 'fabric_r' if theme != 'industry' else 'rubber', 12, profile='dome')
    else:
        t.slab(Tile.disk_mask(32, 32, 14), 'plastic_r' if theme in ('slum', 'mid') else 'plastic_b', 7, bevel=2)
        t.mark(Tile.disk_mask(32, 32, 4), -1)
    return finish(t, theme, rng)


def menu_board(theme, rng):
    t = piece()
    body(t, 6, 20, 57, 43, 12, 'body2', None, r=1)
    sc = screen(t, 9, 23, 54, 40, 'screen_glow' if theme != 'rural' else 'lamp', lines=False)
    for k in range(4):
        t.mark(sc & (YY == 26 + k * 4) & (XX < 40 - k * 3), -2)
    t.mark(sc & (XX > 44) & (XX < 52) & (YY > 26) & (YY < 37), 1)
    return finish(t, theme, rng)


def samovar(theme, rng):
    t = piece()
    on(t, Tile.box_mask(18, 40, 46, 54, 2), 'wood_dark', 3)
    t.slab(Tile.disk_mask(32, 30, 15), 'brass' if theme != 'slum' else 'copper', 14, profile='dome')
    on(t, Tile.disk_mask(32, 30, 5), 'brass', 5, profile='cyl')
    t.slab(Tile.line_mask(12, 26, 18, 30, 3), 'wood_dark', 10, bevel=0.5)
    t.slab(Tile.line_mask(46, 30, 54, 40, 3), 'brass', 9, bevel=0.5)
    return finish(t, theme, rng)


def liquor_shelf(theme, rng):
    t = piece()
    body(t, 2, 16, 61, 36, 18, 'wood_dark' if theme != 'rich' else 'body2', 'wood' if theme != 'rich' else 'top', r=1)
    t.noline |= (XX == 0) | (XX == 63)
    cols = ['glass', 'container_o', 'leaf', 'paint_y', 'fabric_r', 'glass', 'container_b']
    for k in range(9):
        x = 6 + k * 6
        on(t, Tile.disk_mask(x + 2, 26, 2.4), cols[k % len(cols)], 4, profile='cyl')
    t.emit(Tile.box_mask(4, 36, 59, 37), style(theme)['neon'][-1])
    return finish(t, theme, rng)


def hot_plate(theme, rng):
    t = piece()
    body(t, 14, 18, 49, 45, 4, 'dark_steel', 'dark_steel', r=2)
    ring = Tile.disk_mask(32, 31, 9) & ~Tile.disk_mask(32, 31, 6)
    t.emit(ring, 'fire')
    on(t, Tile.box_mask(44, 40, 47, 43), 'plastic_r', 1)
    return finish(t, theme, rng)


def shelf(theme, rng):
    t = piece()
    body(t, 2, 18, 61, 45, 15, 'body', 'top', r=1)
    t.noline |= (XX == 0) | (XX == 63)
    cols = ['container_o', 'container_b', 'paint_y', 'fabric_g', 'plastic_r', 'paint_w']
    for k in range(10):
        x = 5 + k * 6
        for y in (22, 34):
            on(t, Tile.box_mask(x, y, x + 4, y + 7, 1), cols[(k + y) % len(cols)], 3)
    if theme == 'slum':
        t.clear(Tile.box_mask(40, 22, 56, 40) & (t.h > 15))
    return finish(t, theme, rng)


def produce_bin(theme, rng):
    t = piece()
    body(t, 4, 10, 59, 53, 9, 'wood' if theme != 'industry' else 'body', None, r=1)
    for k, (x0, mat) in enumerate(((7, 'plastic_r'), (25, 'leaf'), (43, 'paint_y'))):
        bay = Tile.box_mask(x0, 13, x0 + 15, 50)
        t.paint(bay, 'wood_dark')
        for j in range(14):
            on(t, Tile.disk_mask(x0 + 3 + (j % 3) * 4.5, 17 + (j // 3) * 7, 2.6), mat if theme != 'slum' or j % 4 else 'soil', 3, profile='dome')
    return finish(t, theme, rng)


def freezer_case(theme, rng):
    t = piece()
    body(t, 2, 12, 61, 51, 12, 'plastic_w', 'glass', r=2)
    t.noline |= (XX == 0) | (XX == 63)
    t.mark(Tile.box_mask(4, 31, 59, 31), -2)
    t.emit(Tile.box_mask(4, 12, 59, 13), 'lamp_cold' if style(theme)['lights'] > 0.5 else 'lamp_dead')
    t.mark(Tile.line_mask(6, 14, 30, 30, 1) & t.obj, 2)
    return finish(t, theme, rng)


def checkout(theme, rng):
    t = piece()
    body(t, 4, 14, 59, 49, 10, 'body', 'rubber', r=2)
    on(t, Tile.box_mask(40, 18, 54, 30, 1), 'dark_steel', 4)
    screen(t, 42, 20, 52, 27)
    t.mark(Tile.box_mask(8, 18, 36, 45) & ((XX % 4) == 0), -1)
    return finish(t, theme, rng)


def vending(theme, rng):
    t = piece()
    m = body(t, 8, 8, 55, 55, 18, 'plastic_r' if theme != 'industry' else 'container_b', 'body2', r=2)
    win = Tile.box_mask(12, 12, 40, 50)
    t.paint(win, 'glass')
    cols = ['container_o', 'paint_y', 'leaf', 'container_b', 'paint_w']
    for r_ in range(4):
        for c_ in range(4):
            on(t, Tile.box_mask(14 + c_ * 7, 14 + r_ * 9, 18 + c_ * 7, 20 + r_ * 9, 1), cols[(r_ + c_) % 5], 1)
    lit = style(theme)['lights'] > 0.6 or rng.chance(0.6)
    t.emit(Tile.box_mask(44, 14, 51, 20), 'screen_glow' if lit else 'lamp_dead')
    if not lit:
        t.glow[:] = False
    return finish(t, theme, rng)


def water_cooler(theme, rng):
    t = piece()
    body(t, 18, 22, 45, 49, 10, 'plastic_w', 'plastic_w', r=3)
    t.slab(Tile.disk_mask(32, 30, 10), 'glass', 18, profile='dome')
    t.paint(Tile.disk_mask(32, 30, 7), 'water')
    on(t, Tile.box_mask(26, 42, 29, 46), 'plastic_b', 1)
    on(t, Tile.box_mask(35, 42, 38, 46), 'plastic_r', 1)
    return finish(t, theme, rng)


# ------------------------------------------------------------------------------------------------ clinics and ripperdocs
def implant_chair(theme, rng):
    t = piece()
    seat = Tile.box_mask(18, 8, 45, 57, 7)
    t.slab(seat, 'plastic_w' if theme != 'slum' else 'fabric_r', 9, bevel=3)
    t.mark(Tile.box_mask(18, 24, 45, 25) | Tile.box_mask(18, 42, 45, 43), -1)
    arm = Tile.line_mask(50, 6, 50, 40, 3)
    t.slab(arm, 'chrome', 16, bevel=0.8)
    t.slab(Tile.line_mask(50, 8, 34, 14, 3), 'chrome', 18, bevel=0.8)
    t.emit(Tile.disk_mask(33, 14, 2.2), 'neon_cyan')
    return finish(t, theme, rng)


def implant_printer(theme, rng):
    t = piece()
    body(t, 6, 6, 57, 57, 16, 'body2', 'dark_steel', r=3)
    bed = Tile.box_mask(14, 14, 49, 49, 2)
    t.paint(bed, 'glass')
    t.slab(Tile.box_mask(14, 30, 49, 32), 'chrome', 18, bevel=0.5)
    on(t, Tile.box_mask(28, 28, 35, 34), 'dark_steel', 2)
    t.emit(Tile.disk_mask(31.5, 40, 3), 'neon_cyan')
    t.emit(Tile.box_mask(10, 52, 20, 53), 'neon_green')
    return finish(t, theme, rng)


def limb_bin(theme, rng):
    t = piece()
    body(t, 8, 12, 55, 51, 12, 'dark_steel', None, r=2)
    inner = Tile.box_mask(11, 15, 52, 48)
    t.paint(inner, 'ink')
    t.h[inner] -= 4
    for k in range(4):
        a = rng.range(0, math.pi)
        x0, y0 = rng.range(16, 46), rng.range(20, 44)
        lm = Tile.line_mask(x0, y0, x0 + math.cos(a) * 14, y0 + math.sin(a) * 10, 4)
        t.slab(lm & inner, rng.pick(['plastic_w', 'chrome', 'tank_w']), 7, profile='dome')
    return finish(t, theme, rng)


def autodoc(theme, rng):
    t = piece()
    pod = Tile.box_mask(14, 4, 49, 59, 12)
    t.slab(pod, 'tank_w', 14, profile='dome')
    lid = Tile.box_mask(18, 10, 45, 53, 9)
    t.paint(lid, 'glass')
    t.emit(Tile.box_mask(30, 12, 33, 50) & lid, 'neon_cyan')
    t.emit(Tile.disk_mask(32, 56, 2), 'neon_green')
    return finish(t, theme, rng)


def hospital_bed(theme, rng, ward=False):
    t = piece()
    frame = Tile.box_mask(14, 4, 49, 59, 2)
    t.slab(frame, 'steel', 8, bevel=1)
    mat_ = Tile.box_mask(17, 7, 46, 56, 3)
    t.slab(mat_, 'linen', 2, bevel=1.5, on=8)
    t.slab(Tile.box_mask(20, 9, 43, 17, 4), 'paper', 3, profile='dome', on=10)
    sheet = Tile.box_mask(17, 26, 46, 56, 2)
    t.paint(sheet, 'fabric_b' if not ward else 'fabric_g')
    t.mark(sheet & (YY == 26), 1)
    if not ward:
        t.slab(Tile.box_mask(52, 10, 60, 22, 1), 'body2', 14, bevel=0.6)
        screen(t, 53, 12, 59, 17, 'neon_green', lines=False)
    return finish(t, theme, rng)


def scanner(theme, rng):
    t = piece()
    ring = Tile.disk_mask(32, 32, 28) & ~Tile.disk_mask(32, 32, 13)
    t.slab(ring, 'tank_w', 18, profile='dome')
    t.emit(Tile.disk_mask(32, 32, 24) & ~Tile.disk_mask(32, 32, 22.5), 'neon_cyan')
    t.slab(Tile.box_mask(26, 0, 37, 63), 'plastic_w', 7, bevel=1)
    t.noline |= (YY == 0) | (YY == 63)
    return finish(t, theme, rng)


def med_cabinet(theme, rng):
    t = piece()
    body(t, 8, 14, 55, 49, 16, 'plastic_w', 'plastic_w', r=2)
    cross = Tile.box_mask(28, 20, 35, 43) | Tile.box_mask(20, 28, 43, 35)
    t.paint(cross, 'red_cross')
    t.mark(Tile.box_mask(31, 14, 32, 49), -1)
    return finish(t, theme, rng)


def iv_stand(theme, rng):
    t = piece()
    for a in range(5):
        ang = a / 5 * 2 * math.pi
        t.slab(Tile.line_mask(32, 40, 32 + math.cos(ang) * 14, 40 + math.sin(ang) * 14, 2.5), 'chrome', 3, bevel=0.4)
    t.slab(Tile.disk_mask(32, 40, 2.5), 'chrome', 22, profile='cyl')
    t.slab(Tile.box_mask(24, 12, 40, 14), 'chrome', 24, bevel=0.3)
    bag = Tile.box_mask(26, 16, 37, 30, 3)
    t.slab(bag, 'glass', 22, profile='dome')
    t.paint(Tile.box_mask(28, 22, 35, 29, 2), 'water')
    return finish(t, theme, rng)


def reception(theme, rng):
    t = piece()
    m = Tile.box_mask(2, 14, 61, 50, 6) & ~Tile.box_mask(10, 30, 53, 63, 4)
    t.slab(m, 'body', 12, bevel=1.5)
    t.paint(Tile.box_mask(2, 14, 61, 18, 3), 'top')
    t.noline |= (XX == 0) | (XX == 63)
    on(t, Tile.box_mask(24, 20, 38, 27, 1), 'dark_steel', 3)
    screen(t, 26, 21, 36, 25)
    t.emit(Tile.box_mask(4, 13, 59, 13), style(theme)['neon'][0])
    return finish(t, theme, rng)


def exam_couch(theme, rng):
    t = piece()
    legs(t, 18, 8, 45, 55, 'chrome', h=6)
    t.slab(Tile.box_mask(14, 4, 49, 59, 4), 'fabric_b' if theme != 'slum' else 'fabric_r', 10, bevel=2)
    t.slab(Tile.box_mask(16, 4, 47, 16, 4), 'fabric_b' if theme != 'slum' else 'fabric_r', 13, profile='dome')
    t.paint(Tile.box_mask(18, 18, 45, 57, 2), 'paper')
    return finish(t, theme, rng)


# ------------------------------------------------------------------------------------------------ church
def church_bench(theme, rng):
    t = piece()
    seat = Tile.box_mask(0, 26, 63, 39)
    t.slab(seat, 'wood_dark', 8, bevel=1.2)
    t.slab(Tile.box_mask(0, 20, 63, 25), 'wood_dark', 13, bevel=1)
    t.noline |= (XX == 0) | (XX == 63)
    t.mark(seat & (((XX % 16) == 0)), -1)
    return finish(t, theme, rng)


def iconostasis(theme, rng):
    t = piece()
    m = Tile.box_mask(0, 14, 63, 30)
    t.slab(m, 'wood_dark', 20, bevel=1)
    t.noline |= (XX == 0) | (XX == 63)
    for k in range(4):
        x = 4 + k * 15
        ic = Tile.box_mask(x, 17, x + 10, 27, 1)
        t.paint(ic, 'icon_gold')
        t.paint(Tile.box_mask(x + 3, 19, x + 7, 25, 2), 'wood_light')
        t.mark(ic & ~Tile.box_mask(x + 1, 18, x + 9, 26), -1)
    return finish(t, theme, rng)


def candle_stand(theme, rng):
    t = piece()
    t.slab(Tile.disk_mask(32, 34, 16), 'brass', 12, bevel=1.5)
    t.paint(Tile.disk_mask(32, 34, 13), 'icon_gold')
    for k in range(9):
        a = k / 9 * 2 * math.pi
        x, y = 32 + math.cos(a) * 9, 34 + math.sin(a) * 9
        t.slab(Tile.disk_mask(x, y, 1.3), 'paper', 16, profile='cyl')
        t.emit(Tile.disk_mask(x, y - 1.5, 1.0), 'fire')
    return finish(t, theme, rng)


def analoy(theme, rng):
    t = piece()
    m = Tile.poly_mask([(16, 14), (48, 14), (52, 46), (12, 46)])
    t.slab(m, 'wood_dark', 14, bevel=1)
    cloth = Tile.poly_mask([(20, 18), (44, 18), (47, 42), (17, 42)])
    t.paint(cloth, 'fabric_r')
    t.paint(Tile.box_mask(24, 24, 40, 36, 1), 'icon_gold')
    return finish(t, theme, rng)


def baptismal_font(theme, rng):
    t = piece()
    bowl = Tile.disk_mask(32, 32, 22)
    t.slab(bowl, 'stone' if theme != 'rich' else 'wall', 14, bevel=2)
    w = Tile.disk_mask(32, 32, 17)
    t.paint(w, 'water')
    t.h[w] -= 3
    t.mark(Tile.disk_mask(26, 26, 3) & w, 2)
    return finish(t, theme, rng)


def icon_lamp(theme, rng):
    t = piece()
    t.slab(Tile.box_mask(31, 4, 32, 20), 'brass', 22, bevel=0)
    cup = Tile.disk_mask(32, 32, 9)
    t.slab(cup, 'lacquer_red', 18, profile='dome')
    t.emit(Tile.disk_mask(32, 31, 3), 'fire')
    return finish(t, theme, rng)


def worship_cross(theme, rng):
    t = piece()
    c = Tile.box_mask(28, 6, 35, 58) | Tile.box_mask(14, 18, 49, 25) | Tile.line_mask(22, 44, 42, 38, 5)
    t.slab(c, 'icon_gold' if theme != 'slum' else 'wood_dark', 16, bevel=1)
    t.slab(Tile.box_mask(20, 54, 43, 61, 1), 'stone', 4, bevel=1)
    return finish(t, theme, rng)


# ------------------------------------------------------------------------------------------------ shrine
def shrine(theme, rng):
    t = piece()
    body(t, 10, 18, 53, 55, 10, 'wood_dark', 'wood', r=1)
    roof_ = Tile.poly_mask([(4, 22), (32, 6), (60, 22), (54, 30), (10, 30)])
    t.slab(roof_, 'lacquer_black' if theme != 'rural' else 'roof', 18, bevel=3)
    t.mark(roof_ & Tile.line_mask(4, 22, 32, 6, 1.2) | roof_ & Tile.line_mask(32, 6, 60, 22, 1.2), 1)
    t.paint(Tile.box_mask(28, 34, 35, 52), 'lacquer_red')
    t.slab(Tile.box_mask(20, 54, 43, 58), 'paper', 6, bevel=0.5)
    return finish(t, theme, rng)


def offering_table(theme, rng):
    t = piece()
    body(t, 8, 18, 55, 45, 8, 'wood_light', 'wood_light', r=1)
    for x in (18, 32, 46):
        on(t, Tile.disk_mask(x, 31, 4), 'paint_w', 3, profile='dome')
    on(t, Tile.disk_mask(32, 31, 2), 'container_o', 5, profile='dome')
    return finish(t, theme, rng)


def saisen_box(theme, rng):
    t = piece()
    body(t, 10, 18, 53, 45, 12, 'wood', 'wood_dark', r=1)
    t.mark(Tile.box_mask(14, 22, 49, 41) & ((XX % 5) == 0), -1)
    t.paint(Tile.box_mask(10, 18, 53, 20) | Tile.box_mask(10, 43, 53, 45), 'brass')
    return finish(t, theme, rng)


def komainu(theme, rng):
    t = piece()
    t.slab(Tile.box_mask(14, 30, 49, 59, 2), 'stone_dark', 6, bevel=1)
    t.slab(Tile.disk_mask(32, 38, 12, 14), 'stone', 16, profile='dome')
    t.slab(Tile.disk_mask(32, 22, 9), 'stone', 20, profile='dome')
    t.mark(Tile.disk_mask(28, 20, 1.2) | Tile.disk_mask(36, 20, 1.2), -2)
    t.mark(Tile.disk_mask(32, 22, 9) & speckle(rng.int(0, 1 << 20), 0.15), -1)
    if theme in ('rural', 'slum'):
        t.paint(blotches(rng.int(0, 1 << 20), 0.2, cells=4) & t.obj, 'moss')
    return finish(t, theme, rng)


def lantern_stone(theme, rng):
    t = piece()
    t.slab(Tile.box_mask(20, 40, 43, 61, 2), 'stone_dark', 6, bevel=1)
    t.slab(Tile.box_mask(24, 24, 39, 44, 1), 'stone', 14, bevel=1)
    t.emit(Tile.box_mask(28, 30, 35, 36), 'lamp' if style(theme)['lights'] > 0.4 else 'fire')
    roof_ = Tile.poly_mask([(14, 24), (32, 10), (50, 24), (44, 28), (20, 28)])
    t.slab(roof_, 'stone', 20, bevel=2)
    if theme in ('rural', 'slum'):
        t.paint(blotches(rng.int(0, 1 << 20), 0.25, cells=4) & t.obj, 'moss')
    return finish(t, theme, rng)


def chozuya(theme, rng):
    t = piece()
    basin = Tile.box_mask(8, 22, 55, 47, 4)
    t.slab(basin, 'stone', 10, bevel=1.5)
    w = Tile.box_mask(12, 26, 51, 43, 2)
    t.paint(w, 'water')
    t.h[w] -= 2
    for x in (20, 32, 44):
        t.slab(Tile.line_mask(x, 20, x + 6, 32, 2), 'wood_light', 13, bevel=0)
        t.slab(Tile.disk_mask(x + 6, 32, 2.5), 'wood_light', 13, profile='cyl')
    t.slab(Tile.box_mask(4, 10, 59, 16, 1), 'lacquer_black' if theme != 'rural' else 'wood_dark', 18, bevel=1)
    return finish(t, theme, rng)


def ema_rack(theme, rng):
    t = piece()
    t.slab(Tile.box_mask(4, 18, 59, 22), 'wood_dark', 16, bevel=0.6)
    for x in (4, 56):
        t.slab(Tile.box_mask(x, 14, x + 3, 50), 'wood_dark', 18, bevel=0.6)
    for k in range(8):
        x = 8 + k * 6
        tag = Tile.poly_mask([(x, 24), (x + 4, 22), (x + 8, 24), (x + 8, 32), (x, 32)])
        t.slab(tag, 'wood_light', 14 - (k % 2), bevel=0.5)
        t.mark(tag & (YY == 27), -1)
    return finish(t, theme, rng)


def torii(theme, rng):
    t = piece()
    beam = Tile.box_mask(0, 18, 63, 25)
    t.slab(beam, 'lacquer_red', 24, bevel=1)
    t.paint(Tile.box_mask(0, 18, 63, 20), 'lacquer_black')
    t.slab(Tile.box_mask(4, 30, 59, 33), 'lacquer_red', 22, bevel=0.6)
    for x in (12, 51):
        t.slab(Tile.disk_mask(x, 32, 4.5), 'lacquer_red', 26, profile='cyl')
        t.slab(Tile.disk_mask(x, 32, 5.5) & ~Tile.disk_mask(x, 32, 4.5), 'lacquer_black', 4, bevel=0)
    t.noline |= (XX == 0) | (XX == 63)
    return finish(t, theme, rng)


def shimenawa(theme, rng):
    t = piece()
    t.slab(Tile.disk_mask(32, 32, 7), 'wood' if theme != 'rich' else 'wall', 22, profile='cyl')
    rope = Tile.disk_mask(32, 32, 11) & ~Tile.disk_mask(32, 32, 7)
    t.slab(rope, 'grass_dry', 16, profile='dome')
    t.mark(rope & ((np.arctan2(YY - 32, XX - 32) * 8 / math.pi).astype(int) % 2 == 0), -1)
    for a in (0.3, 2.4, 4.4):
        x, y = 32 + math.cos(a) * 12, 32 + math.sin(a) * 12
        t.slab(Tile.poly_mask([(x - 3, y), (x + 3, y), (x + 1, y + 7), (x - 1, y + 7)]), 'paper', 12, bevel=0.3)
    return finish(t, theme, rng)


def bonsai(theme, rng):
    t = piece()
    pot = Tile.box_mask(14, 30, 49, 51, 3)
    t.slab(pot, 'lacquer_black' if theme != 'slum' else 'concrete', 6, bevel=1)
    t.paint(Tile.box_mask(17, 33, 46, 48, 2), 'soil')
    t.slab(Tile.line_mask(30, 42, 24, 24, 3) | Tile.line_mask(26, 30, 40, 20, 2), 'bark', 12, bevel=0.5)
    for x, y, r in ((22, 20, 8), (38, 16, 7), (44, 26, 6)):
        on(t, Tile.disk_mask(x, y, r, r * 0.7), 'leaf_dark', 8, profile='dome')
    return finish(t, theme, rng)


def fern(theme, rng):
    t = piece()
    t.slab(Tile.disk_mask(32, 34, 10), 'concrete' if theme != 'rich' else 'wall', 6, bevel=1)
    for k in range(9):
        a = k / 9 * 2 * math.pi + 0.2
        fr = Tile.line_mask(32, 34, 32 + math.cos(a) * 26, 34 + math.sin(a) * 24, 5)
        t.slab(fr, 'leaf' if k % 2 else 'leaf_dark', 10 - k % 3, profile='dome')
        t.mark(fr & Tile.line_mask(32, 34, 32 + math.cos(a) * 26, 34 + math.sin(a) * 24, 1), -1)
    return finish(t, theme, rng)


def aquarium(theme, rng):
    t = piece()
    body(t, 2, 12, 61, 51, 14, 'body2', None, r=1)
    t.noline |= (XX == 0) | (XX == 63)
    w = Tile.box_mask(5, 15, 58, 48)
    t.paint(w, 'water')
    t.mark(w & (((XX + YY) % 19) == 0), 1)
    for k in range(5):
        x, y = rng.range(10, 52), rng.range(20, 44)
        fish = Tile.disk_mask(x, y, 3, 1.6)
        t.paint(fish, rng.pick(['container_o', 'paint_y', 'blossom']))
    t.paint(Tile.box_mask(5, 44, 58, 48) & speckle(rng.int(0, 1 << 20), 0.3), 'gravel')
    t.emit(Tile.box_mask(5, 15, 58, 15), 'lamp_cold')
    return finish(t, theme, rng)


def charm_counter(theme, rng):
    t = piece()
    body(t, 2, 18, 61, 45, 10, 'wood_light', 'wood_light', r=1)
    t.noline |= (XX == 0) | (XX == 63)
    for k in range(8):
        x = 6 + k * 7
        col = ['lacquer_red', 'fabric_b', 'fabric_g', 'paint_y'][k % 4]
        t.slab(Tile.box_mask(x, 24, x + 4, 33, 1), col, 12, bevel=0.5)
        t.mark(Tile.box_mask(x + 1, 25, x + 3, 25), 1)
    return finish(t, theme, rng)


def cabinet_lacquer(theme, rng):
    t = piece()
    body(t, 8, 14, 55, 49, 16, 'lacquer_black' if theme != 'slum' else 'wood_dark', 'lacquer_black' if theme != 'slum' else 'wood', r=2)
    t.mark(Tile.box_mask(31, 16, 32, 47), -1)
    for x in (27, 36):
        t.slab(Tile.disk_mask(x, 32, 1.6), 'gold', 18, profile='cyl')
    t.paint(Tile.box_mask(12, 18, 51, 20) & ((XX % 6) < 3), 'gold')
    return finish(t, theme, rng)


def neon_sign(theme, rng, colour='neon_pink'):
    """a neon sign on its mount: glowing tubes in a frame (the colour named in the id)"""
    t = piece()
    frame = Tile.box_mask(6, 16, 57, 47, 3)
    t.slab(frame, 'dark_steel', 6, bevel=1)
    t.paint(Tile.box_mask(9, 19, 54, 44, 2), 'ink')
    # an abstract motif (no letters: text is never baked into sprites): a ring, a wave and a bar
    ring = Tile.disk_mask(21, 31.5, 7.5) & ~Tile.disk_mask(21, 31.5, 5.3)
    wave = np.zeros((N, N), bool)
    for k in range(30, 51):
        y = 31.5 + 5 * math.sin((k - 30) / 20 * 2 * math.pi)
        wave |= Tile.disk_mask(k, y, 1.2)
    bar = Tile.line_mask(30, 40, 50, 40, 2.2)
    tubes = ring | wave | bar
    working = style(theme)['lights'] > 0.6 or rng.chance(0.7)
    t.emit(tubes, colour)
    if not working:
        dead = tubes & (XX > 30)
        t.glow[dead] = False
        t.m[dead] = 'lamp_dead'
    return finish(t, theme, rng)


def crane_leg(theme, rng):
    t = piece()
    m = Tile.box_mask(12, 12, 51, 51, 2)
    t.slab(m, 'paint_y' if theme != 'rich' else 'steel', 26, bevel=1)
    t.paint(Tile.box_mask(16, 16, 47, 47), 'ink')
    t.h[Tile.box_mask(16, 16, 47, 47)] = 0
    t.slab(Tile.line_mask(16, 16, 47, 47, 3) | Tile.line_mask(47, 16, 16, 47, 3), 'paint_y', 22, bevel=0.5)
    return finish(t, theme, rng)


def crane_beam(theme, rng):
    t = piece()
    m = Tile.box_mask(0, 18, 63, 45)
    t.slab(m, 'paint_y', 30, bevel=1)
    t.noline |= (XX == 0) | (XX == 63)
    lat = m & ((((XX + YY) % 16) < 2) | (((XX - YY) % 16) < 2))
    t.mark(lat, -1)
    return finish(t, theme, rng, shadow=False)


def crane_trolley(theme, rng):
    t = crane_beam(theme, rng)
    trol = Tile.box_mask(14, 12, 49, 51, 2)
    t.slab(trol, 'dark_steel', 33, bevel=1, on=0)
    t.emit(Tile.box_mask(18, 14, 22, 16), 'neon_amber')
    return t


def container(theme, rng, v=0):
    """a shipping container from above (fills its cell, joins its neighbours into a long box)"""
    t = piece()
    col = ['container_r', 'container_b', 'container_g', 'container_o'][v % 4]
    m = Tile.box_mask(0, 6, 63, 57)
    t.slab(m, col, 24, bevel=1)
    rib = m & ((XX % 8) < 2)
    t.h[rib] += 0.8
    t.mark(rib, 1)
    t.noline |= (XX == 0) | (XX == 63)
    t.paint(m & blotches(rng.int(0, 1 << 20), 0.12 + style(theme)['rust'] * 0.3, cells=4), 'rust')
    return finish(t, theme, rng)


def bollard(theme, rng):
    t = piece()
    t.slab(Tile.disk_mask(32, 32, 10), 'paint_y' if theme in ('industry', 'slum') else 'dark_steel', 12, profile='dome')
    t.paint(Tile.disk_mask(32, 32, 10) & ~Tile.disk_mask(32, 32, 7), 'dark_steel')
    if theme == 'rich':
        t.emit(Tile.disk_mask(32, 32, 10) & ~Tile.disk_mask(32, 32, 8.5), 'neon_cyan')
    return finish(t, theme, rng)


def terminal(theme, rng):
    t = piece()
    body(t, 16, 14, 47, 49, 16, 'body2', 'dark_steel', r=3)
    screen(t, 20, 18, 43, 33, 'screen_glow')
    on(t, Tile.box_mask(20, 37, 43, 45, 1), 'rubber', 1)
    t.mark(Tile.box_mask(21, 38, 42, 44) & ((XX % 3) == 0), 1)
    return finish(t, theme, rng)


def portal(theme, rng):
    t = piece()
    ring = Tile.disk_mask(32, 32, 28) & ~Tile.disk_mask(32, 32, 20)
    t.slab(ring, 'dark_steel', 10, profile='dome')
    core = Tile.disk_mask(32, 32, 19)
    t.emit(core, 'portal_glow')
    sw = core & ((np.arctan2(YY - 32, XX - 32) * 3 + np.hypot(XX - 32, YY - 32) * 0.5).astype(int) % 2 == 0)
    t.m[sw] = 'neon_violet'
    return finish(t, theme, rng)


def device(theme, rng):
    t = piece()
    body(t, 18, 18, 45, 45, 10, 'body2', 'dark_steel', r=4)
    t.emit(Tile.disk_mask(32, 32, 5), 'neon_red')
    for x, y in ((22, 22), (41, 22), (22, 41), (41, 41)):
        t.slab(Tile.disk_mask(x, y, 1.5), 'chrome', 12, profile='cyl')
    return finish(t, theme, rng)


def charger(theme, rng):
    t = piece()
    body(t, 20, 14, 43, 49, 18, 'tank_w' if theme != 'slum' else 'body', 'body2', r=3)
    screen(t, 24, 18, 39, 26, 'neon_green', lines=False)
    t.slab(Tile.line_mask(40, 34, 54, 46, 2.5), 'rubber', 8, bevel=0.5)
    t.slab(Tile.box_mask(52, 44, 57, 50, 1), 'dark_steel', 9, bevel=0.5)
    return finish(t, theme, rng)


def gunsmith_table(theme, rng):
    t = piece()
    body(t, 2, 14, 61, 49, 10, 'wood_dark' if theme != 'industry' else 'body', 'rubber', r=1)
    t.noline |= (XX == 0) | (XX == 63)
    gun = Tile.box_mask(10, 26, 38, 30) | Tile.box_mask(30, 30, 34, 38) | Tile.box_mask(10, 24, 16, 30)
    t.slab(gun, 'dark_steel', 12.5, bevel=0.5)
    for k in range(5):
        t.slab(Tile.disk_mask(44 + k * 3, 24, 1.1), 'brass', 11.5, profile='cyl')
    t.slab(Tile.box_mask(42, 34, 56, 42, 1), 'chrome', 12, bevel=0.5)
    t.emit(Tile.box_mask(4, 14, 59, 15), 'lamp')
    return finish(t, theme, rng)


def ev_charger(theme, rng, corner='nw'):
    """a 2 x 2 car charging pad: this cell is one corner of it"""
    t = Tile('', periodic=False)
    pad = Tile.box_mask(0, 0, 63, 63)
    cx = 63 if 'e' in corner else 0
    cy = 63 if 's' in corner else 0
    big = Tile.disk_mask(63 - cx, 63 - cy, 60) if True else pad
    t.ground('concrete', pad)
    ring = (np.abs(np.hypot(XX - (63 - cx if cx else 63), YY - (63 - cy if cy else 63)) - 50) < 2)
    ring = np.abs(np.hypot(XX - (0 if cx else 63), YY - (0 if cy else 63)) - 50) < 2
    t.emit(ring, 'neon_green' if theme != 'rich' else 'neon_cyan')
    t.mark(np.abs(np.hypot(XX - (0 if cx else 63), YY - (0 if cy else 63)) - 44) < 1, -1)
    if corner == 'nw':
        post = Tile.box_mask(4, 4, 20, 20, 3)
        t.slab(post, 'tank_w', 16, bevel=1)
        t.emit(Tile.box_mask(8, 8, 16, 12), 'neon_green')
    return t


def gunsmith(theme, rng):
    return gunsmith_table(theme, rng)


# ------------------------------------------------------------------------------------------------ animals stay as drawn
BUILDERS = {
    'f_chair': chair, 'f_table': table, 'f_crate_c': crate, 'f_dumpster': dumpster, 'f_planter': planter,
    'f_trl_shop_counter': counter, 'f_trl_counter_noodle': noodle_counter, 'f_trl_kitchen_range': kitchen_range,
    'f_trl_kitchen_fridge': fridge, 'f_trl_sushi_case': sushi_case, 'f_trl_pizza_oven': pizza_oven,
    'f_trl_dining_table': dining_table, 'f_trl_table_plastic': table_plastic, 'f_trl_tea_table': tea_table,
    'f_trl_stool_plastic': lambda th, r: stool(th, r), 'f_trl_bar_stool': lambda th, r: stool(th, r, bar=True),
    'f_trl_menu_board': menu_board, 'f_trl_samovar': samovar, 'f_trl_liquor_shelf': liquor_shelf, 'f_trl_hot_plate': hot_plate,
    'f_trl_shelf_clean': shelf, 'f_trl_produce_bin': produce_bin, 'f_trl_freezer_case': freezer_case, 'f_trl_checkout': checkout,
    'f_trl_vending': vending, 'f_trl_water_cooler': water_cooler, 'f_trl_implant_chair': implant_chair,
    'f_trl_implant_printer': implant_printer, 'f_trl_limb_bin': limb_bin, 'f_trl_autodoc_imp_m': autodoc,
    'f_trl_hospital_bed': hospital_bed, 'f_trl_ward_bed': lambda th, r: hospital_bed(th, r, ward=True), 'f_trl_scanner': scanner,
    'f_trl_med_cabinet': med_cabinet, 'f_trl_iv_stand': iv_stand, 'f_trl_reception': reception, 'f_trl_exam_couch': exam_couch,
    'f_trl_church_bench': church_bench, 'f_trl_iconostasis': iconostasis, 'f_trl_candle_stand': candle_stand,
    'f_trl_analoy': analoy, 'f_trl_baptismal_font': baptismal_font, 'f_trl_icon_lamp': icon_lamp,
    'f_trl_worship_cross': worship_cross, 'f_trl_shrine': shrine, 'f_trl_offering_table': offering_table,
    'f_trl_saisen_box': saisen_box, 'f_trl_komainu': komainu, 'f_trl_lantern_stone': lantern_stone, 'f_trl_chozuya': chozuya,
    'f_trl_ema_rack': ema_rack, 'f_trl_torii': torii, 'f_trl_shimenawa_pole': shimenawa, 'f_trl_bonsai': bonsai,
    'f_trl_fern': fern, 'f_trl_aquarium': aquarium, 'f_trl_charm_counter': charm_counter, 'f_trl_cabinet_lacquer': cabinet_lacquer,
    'f_trl_neon_pink': lambda th, r: neon_sign(th, r, 'neon_pink'), 'f_trl_crane_leg': crane_leg, 'f_trl_crane_beam': crane_beam,
    'f_trl_crane_trolley': crane_trolley, 'f_trl_bollard': bollard, 'f_trl_terminal': terminal,
    'f_trl_portal': portal, 'f_trl_device': device, 'f_trl_charger': charger, 'f_trl_gunsmith_table': gunsmith_table,
    'f_trl_ev_nw': lambda th, r: ev_charger(th, r, 'nw'), 'f_trl_ev_ne': lambda th, r: ev_charger(th, r, 'ne'),
    'f_trl_ev_sw': lambda th, r: ev_charger(th, r, 'sw'), 'f_trl_ev_se': lambda th, r: ev_charger(th, r, 'se'),
}
