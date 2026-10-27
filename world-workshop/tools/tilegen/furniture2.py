"""The furniture and floors of the businesses and homes (the game's tools/content/furniture_list.py): 116 pieces and
8 floors, each in three variants per theme.

The variant picks the piece's colourway and some of its build (a round or a square cafe table, two or three sofa
seats, wooden or plastic crates); the theme picks its quality (marble, leather and brass downtown, laminate and vinyl
in mid-town, patched vinyl, tape and dead bulbs in the slums, timber and indigo cloth in the country, enamel and
steel in industry).  The game shows one variant per 16-cell block, so a cafe's chairs match.

Scale: a cell is 2 m, 32 px to the metre, as for the dolls.  Pieces that stand against the back wall (shelves,
screens, lockers) fill the top of the cell and run on into the next cell (no outline at the sides), so a row of
them reads as one fitting."""
import math

import numpy as np

from canvas import Tile, N, XX, YY, Rng, blotches, speckle, cracks, grid, planks
from themes import style
from furniture import piece, body, on, legs, screen
import furniture as _F


def finish(t, theme, rng):
    """the theme's wear in finer, lighter patches than on the big fittings: grime on a sofa should read as wear,
    not as camouflage"""
    return _F.finish(t, theme, rng, cells=8, amount=0.55)
import terrain as T


def D(cx, cy, r, ry=None):
    return Tile.disk_mask(cx, cy, r, ry)


def B(x0, y0, x1, y1, r=0.0):
    return Tile.box_mask(x0, y0, x1, y1, r)


def L(x0, y0, x1, y1, w=1.0):
    return Tile.line_mask(x0, y0, x1, y1, w)


# ------------------------------------------------------------------------------------------------ palettes
UPH = {'rich': ['leather_k', 'fabric_cream', 'velvet_teal'], 'mid': ['fabric_b', 'fabric_grey', 'fabric_mustard'],
       'slum': ['vinyl_r', 'vinyl_teal', 'fabric_g'], 'rural': ['fabric_indigo', 'linen', 'fabric_o'],
       'industry': ['vinyl_k', 'fabric_grey', 'canvas_bag']}
WOOD = {'rich': [('body', 'top'), ('wood_dark', 'wood_dark'), ('lacquer_black', 'lacquer_black')],
        'mid': [('body', 'top'), ('wood', 'wood_light'), ('laminate_w', 'laminate_w')],
        'slum': [('body', 'top'), ('wood', 'wood'), ('laminate_g', 'laminate_g')],
        'rural': [('wood', 'wood_light'), ('wood_dark', 'wood'), ('body', 'top')],
        'industry': [('body', 'top'), ('dark_steel', 'steel'), ('enamel_grey', 'enamel_grey')]}
ENAMEL = {'rich': ['plastic_w', 'graphite', 'enamel_cream'], 'mid': ['enamel_b', 'enamel_grey', 'plastic_w'],
          'slum': ['enamel_g', 'enamel_grey', 'enamel_teal'], 'rural': ['enamel_cream', 'enamel_g', 'plastic_w'],
          'industry': ['enamel_o', 'enamel_g', 'enamel_b']}
METAL = {'rich': 'chrome', 'mid': 'steel', 'slum': 'dark_steel', 'rural': 'dark_steel', 'industry': 'steel'}
STOCK = ['container_o', 'container_b', 'paint_y', 'fabric_g', 'plastic_r', 'paint_w', 'kraft', 'enamel_teal', 'fabric_mustard']


class P:
    """the palette of one piece: theme and variant"""

    def __init__(self, theme, v):
        self.theme, self.v = theme, v
        self.uph = UPH[theme][v % 3]
        self.body, self.top = WOOD[theme][v % 3]
        self.enamel = ENAMEL[theme][v % 3]
        self.metal = METAL[theme]
        neon = style(theme)['neon']
        self.glow = neon[v % len(neon)]
        self.rich = theme == 'rich'
        self.poor = theme == 'slum'
        self.wood = {'rich': 'wood_dark', 'rural': 'wood'}.get(theme, 'wood_light' if v % 2 else 'wood')


def run(t, x=True, y=False):
    """the piece runs on into the next cell"""
    if x:
        t.noline |= (XX == 0) | (XX == 63)
    if y:
        t.noline |= (YY == 0) | (YY == 63)


def lit(t, p, rng, mask, mat=None):
    """a light: in the slums some are dead"""
    mat = mat or p.glow
    if p.poor and rng.chance(0.35):
        t.paint(mask, 'lamp_dead')
        return
    t.emit(mask, mat)


def tape(t, p, rng, mask, n=2):
    """slum repairs: grey tape over splits in upholstery"""
    if not p.poor:
        return
    ys, xs = np.nonzero(mask)
    if len(xs) == 0:
        return
    for k in range(n):
        i = rng.int(0, len(xs) - 1)
        x, y = xs[i], ys[i]
        tp = B(x - 3, y - 1, x + 3, y + 1) & mask
        t.paint(tp, 'fabric_grey')
        t.mark(tp, 1)


def band(t, p, mask, w=1):
    """downtown pieces get a brass edge"""
    if p.rich:
        from scipy import ndimage as ndi
        inner = ndi.binary_erosion(mask, iterations=w)
        t.paint(mask & ~inner, 'accent')


def stock(t, rng, x0, x1, y0, y1, mats, w=(3, 6), h=2.5, gap=1, prof='bevel', miss=0.0):
    """a row of things standing side by side on a shelf"""
    x = x0
    while x < x1:
        ww = rng.int(*w)
        if x + ww > x1:
            ww = x1 - x
        if ww >= 2 and not rng.chance(miss):
            on(t, B(x, y0, x + ww - 1, y1, 0.6), rng.pick(mats), h + rng.range(-0.5, 0.8), bevel=0.5, profile=prof)
        x += ww + gap


def shelf_run(t, p, y0=6, y1=28, h=16, mat=None, top=None):
    m = body(t, 0, y0, 63, y1, h, mat or p.body, top or p.top, r=1)
    run(t)
    return m


def wall_run(t, p, y0=4, y1=20, h=22, mat=None):
    """a fitting on the back wall: a tall shallow slab, its face drawn on top"""
    m = B(0, y0, 63, y1)
    t.slab(m, mat or p.body, h, bevel=1)
    run(t)
    return m


def cushion(t, m, mat, h, on_=None):
    t.slab(m, mat, h, profile='dome', on=on_)
    return m


def wheel(t, x, y, r=2.5, mat='rubber'):
    t.slab(D(x, y, r), mat, 3, profile='dome')


def chair_basic(t, p, x0, y0, x1, y1, seat_mat, frame, back=True, h=6):
    if back:
        t.slab(B(x0, y0, x1, y0 + 5, 2), frame, h + 6, bevel=1)
    cushion(t, B(x0 + 1, y0 + (6 if back else 1), x1 - 1, y1, 3), seat_mat, h)


# ================================================================================================ food and drink
def coffee_bar(theme, rng, v):
    t, p = piece(), P(theme, v)
    m = body(t, 0, 16, 63, 46, 12, p.body, p.top, r=1)
    run(t)
    band(t, p, B(0, 44, 63, 46))
    # a glass dome of cakes, cups, a grinder
    if v != 1:
        t.slab(D(14, 28, 8), 'cream', 3, profile='dome')
        t.slab(D(14, 28, 9), 'glass', 6, profile='dome', obj=True)
        t.paint(D(13, 27, 5), 'crust')
    else:
        t.slab(B(6, 21, 20, 33, 1), 'wood_light', 1.5)
        for k in range(3):
            t.slab(D(10 + k * 4, 27, 2), 'crust', 3, profile='dome')
    for k in range(3):
        x = 30 + k * 7
        t.slab(D(x, 26, 2.6), 'paint_w', 3, profile='cyl')
        t.paint(D(x, 26, 1.4), 'coffee')
    t.slab(B(50, 20, 58, 30, 2), p.metal, 7)
    t.slab(D(54, 23, 3), 'glass', 9, profile='dome')
    t.paint(D(54, 23, 2), 'coffee')
    t.slab(B(26, 36, 44, 41, 1), 'dark_steel', 1)
    lit(t, p, rng, B(2, 46, 61, 46), p.glow)
    return finish(t, theme, rng)


def cafe_table(theme, rng, v):
    t, p = piece(), P(theme, v)
    top = 'stone' if p.rich and v == 0 else p.top
    if v == 1:
        on(t, D(32, 32, 4), p.metal, 4)
        body(t, 17, 17, 46, 46, 8, p.body, top, r=2)
    else:
        on(t, D(32, 32, 5), p.metal, 4)
        t.slab(D(32, 32, 15), p.body if v == 2 else top, 8, bevel=1.5)
        t.paint(D(32, 32, 13), top)
        t.mark(D(32, 32, 13) & ~D(32, 32, 12), 1)
        if p.rich:
            t.paint(D(32, 32, 15) & ~D(32, 32, 14), 'accent')
    t.slab(D(26, 28, 3), 'paint_w', 2.5, profile='cyl')
    t.paint(D(26, 28, 1.6), 'coffee')
    t.slab(D(38, 37, 4), 'paint_w', 1.2)
    t.slab(D(38, 37, 2), 'crust', 2.5, profile='dome')
    if p.poor:
        t.slab(D(40, 24, 2), 'plastic_r', 2, profile='dome')
    return finish(t, theme, rng)


def cafe_chair(theme, rng, v):
    t, p = piece(), P(theme, v)
    if v == 0:      # bentwood / rattan
        frame = 'wood_light' if theme != 'rich' else 'wood_dark'
        hoop = (np.abs(np.hypot(XX - 32, (YY - 34) * 1.1) - 13) < 2) & (YY < 34)
        t.slab(hoop, frame, 13, bevel=0.6)
        seat = D(32, 35, 11, 10)
        t.slab(seat, frame, 6, bevel=1.2)
        t.mark(seat & (((XX + YY) % 4) == 0), -1)
        t.mark(seat & (((XX - YY) % 4) == 0), 1)
    elif v == 1:    # metal frame, cushion
        legs(t, 21, 25, 42, 44, p.metal, r=1.3, h=5)
        t.slab(L(20, 19, 43, 19, 2.5), p.metal, 12, bevel=0.5)
        cushion(t, B(21, 23, 42, 44, 4), p.uph, 7)
        tape(t, p, rng, B(21, 23, 42, 44), 1)
    else:           # moulded shell
        shell = D(32, 33, 13, 12)
        t.slab(shell, p.enamel, 7, bevel=2)
        t.slab(B(20, 17, 43, 23, 4), p.enamel, 12, bevel=1.5)
        t.mark(D(32, 34, 9, 8) & ~D(32, 34, 8, 7), -1)
    return finish(t, theme, rng)


def coffee_machine(theme, rng, v):
    t, p = piece(), P(theme, v)
    shell = [p.metal, 'alu', p.enamel if p.enamel != 'plastic_w' or theme != 'rural' else 'enamel_g'][v]
    body(t, 8, 10, 55, 50, 15, shell, 'dark_steel' if v == 0 else shell, r=3)
    for x in (20, 43):
        t.slab(D(x, 36, 5), 'dark_steel', 3, profile='cyl')
        t.slab(D(x, 36, 2.5), 'chrome', 1.5)
        t.slab(L(x, 41, x, 47, 2), 'rubber', 1.5)
    grille = B(12, 44, 51, 49)
    t.slab(grille, 'dark_steel', 1)
    t.mark(grille & (XX % 3 == 0), -1)
    for k in range(4):
        t.slab(D(14 + k * 6, 16, 2.4), 'paint_w', 3, profile='cyl')
    lit(t, p, rng, B(46, 14, 51, 17), 'screen_glow')
    t.slab(D(32, 24, 3.5), 'chrome', 2, profile='dome')
    return finish(t, theme, rng)


def bar_counter(theme, rng, v):
    t, p = piece(), P(theme, v)
    bmat, top = (p.body, p.top) if v != 1 else ('wood_dark', 'wood')
    if p.rich:
        bmat, top = ('lacquer_black', 'stone') if v == 0 else (bmat, top)
    body(t, 0, 14, 63, 44, 13, bmat, top, r=1)
    run(t)
    t.slab(L(0, 49, 63, 49, 2.5), 'brass' if theme in ('rich', 'mid') else p.metal, 3, bevel=0.5)
    for k in range(4):
        x = 8 + k * 6
        t.slab(D(x, 20, 1.8), 'chrome', 6, profile='cyl')
    t.slab(B(4, 17, 30, 21, 1), 'dark_steel', 1)
    for k, x in enumerate((38, 46, 54)):
        t.slab(D(x, 30, 3), 'glass', 4, profile='cyl')
        t.paint(D(x, 30, 2), ['beer_a', 'tea_amber', 'clear'][(k + v) % 3])
    t.slab(B(14, 32, 26, 38, 1), 'paper', 0.8)
    lit(t, p, rng, B(1, 44, 62, 45), p.glow)
    return finish(t, theme, rng)


def booth_seat(theme, rng, v):
    t, p = piece(), P(theme, v)
    frame = {'rich': 'wood_dark', 'rural': 'wood'}.get(theme, 'body2')
    t.slab(B(0, 6, 63, 14), frame, 16, bevel=1)
    back = cushion(t, B(0, 12, 63, 24, 3), p.uph, 6, on_=8)
    seat = cushion(t, B(0, 24, 63, 46, 4), p.uph, 7)
    run(t)
    if v == 0:          # channel stitching
        t.mark((back | seat) & (XX % 12 == 5), -1)
    elif v == 1:        # buttons
        for x in range(6, 64, 12):
            t.mark(D(x, 18, 1), -2)
            t.mark(D(x, 35, 1), -2)
    t.mark(B(0, 24, 63, 24), -1)
    tape(t, p, rng, seat, 3)
    return finish(t, theme, rng)


def jukebox(theme, rng, v):
    t, p = piece(), P(theme, v)
    shell = ['wood_dark', p.enamel, 'graphite'][v]
    m = B(12, 22, 51, 56, 2) | D(32, 24, 20, 14)
    t.slab(m, shell, 16, bevel=1.5)
    arcs = (np.abs(np.hypot(XX - 32, (YY - 26) * 1.35) - 15) < 1.2) & m
    lit(t, p, rng, arcs, p.glow if v != 1 else 'neon_amber')
    t.paint(D(32, 26, 11, 8), 'glass')
    for k in range(5):
        t.mark(D(32, 26, 11, 8) & (np.abs(XX - 22 - k * 5) < 1), -1)
    grille = B(17, 42, 46, 52, 1)
    t.paint(grille, 'dark_steel')
    t.mark(grille & ((YY % 2) == 0), -1)
    t.emit(B(18, 36, 45, 37), 'neon_pink' if v == 0 else 'neon_cyan')
    return finish(t, theme, rng)


def pool_table(theme, rng, v):
    t, p = piece(), P(theme, v)
    felt = ['felt_g', 'felt_b', 'felt_r'][v]
    rail = {'rich': 'wood_dark', 'industry': 'dark_steel', 'slum': 'wood'}.get(theme, 'wood')
    legs(t, 6, 16, 57, 47, rail, r=2.5, h=6)
    m = body(t, 2, 12, 61, 51, 10, rail, None, r=3)
    bed = B(7, 17, 56, 46)
    t.paint(bed, felt)
    t.h[bed] -= 1.5
    for x, y in ((6, 16), (32, 15), (57, 16), (6, 47), (32, 48), (57, 47)):
        t.paint(D(x, y, 2.6), 'ink')
    cols = ['paint_y', 'fabric_b', 'plastic_r', 'velvet_v', 'container_o', 'fabric_g', 'leather_ox', 'ink']
    for k in range(7):
        x, y = 30 + (k % 3) * 4 + (k // 3) * 3, 26 + (k % 3) * 4 - (k // 3) * 2
        if v == 2:
            x, y = rng.int(12, 50), rng.int(22, 42)
        t.slab(D(x, y, 1.8), cols[k], 2, profile='dome')
    t.slab(D(16, 32, 1.8), 'paint_w', 2, profile='dome')
    t.slab(L(4, 54, 52, 40, 1.6), 'wood_light', 1.5, bevel=0)
    if p.poor:
        t.mark(blotches(rng.int(0, 1 << 20), 0.12) & bed, -1)
    return finish(t, theme, rng)


def card_table(theme, rng, v):
    t, p = piece(), P(theme, v)
    felt = ['felt_g', 'felt_b', 'felt_r'][v]
    rim = 'wood_dark' if theme in ('rich', 'rural') else p.body
    oct_ = Tile.poly_mask([(20, 6), (44, 6), (58, 20), (58, 44), (44, 58), (20, 58), (6, 44), (6, 20)])
    t.slab(oct_, rim, 9, bevel=1.5)
    inner = Tile.poly_mask([(22, 10), (42, 10), (54, 22), (54, 42), (42, 54), (22, 54), (10, 42), (10, 22)])
    t.paint(inner, felt)
    t.h[inner] -= 1
    for k in range(5):
        x, y = 32 + math.cos(k * 1.25) * 14, 32 + math.sin(k * 1.25) * 14
        c = B(x - 2, y - 3, x + 2, y + 3)
        t.slab(c, 'paper', 0.7, bevel=0)
        t.mark(c & ~B(x - 1, y - 2, x + 1, y + 2), -1)
    for k, (x, y) in enumerate(((28, 30), (36, 34), (32, 27))):
        t.slab(D(x, y, 2.4), ['plastic_r', 'paint_w', 'fabric_b'][k], 3, profile='cyl')
        t.mark(D(x, y, 2.4) & (YY == y), -1)
    return finish(t, theme, rng)


def barrel(theme, rng, v):
    t, p = piece(), P(theme, v)
    if v == 0:          # oak cask on end
        t.slab(D(32, 32, 21), 'wood', 14, bevel=2)
        t.paint(D(32, 32, 21) & ~D(32, 32, 19), 'dark_steel')
        t.mark(D(32, 32, 17) & (XX % 7 == 0), -1)
        t.mark(D(32, 32, 17) & ~D(32, 32, 16), -1)
        t.slab(D(40, 26, 2), 'wood_dark', 1, profile='cyl')
    elif v == 1:        # steel drum
        mat = p.enamel
        t.slab(D(32, 32, 20), mat, 16, bevel=1.2)
        t.paint(D(32, 32, 18) & ~D(32, 32, 17), 'dark_steel')
        t.slab(D(24, 26, 2.5), 'dark_steel', 1, profile='cyl')
        t.slab(D(40, 38, 1.5), 'dark_steel', 1, profile='cyl')
    else:               # plastic keg, blue
        t.slab(D(32, 32, 19), 'plastic_b', 15, bevel=2)
        t.mark(D(32, 32, 15) & ~D(32, 32, 14), -1)
        t.slab(D(32, 32, 4), 'plastic_w', 2, profile='cyl')
    return finish(t, theme, rng)


def crate_stack(theme, rng, v):
    t, p = piece(), P(theme, v)
    spots = [(6, 18, 34, 46, 0), (28, 8, 58, 36, 0), (30, 32, 58, 58, 0), (24, 14, 46, 38, 1)]
    for k, (x0, y0, x1, y1, lvl) in enumerate(spots):
        if v == 0:
            m = B(x0, y0, x1, y1, 1)
            t.slab(m, 'wood_light' if k % 2 else 'wood', 9 + lvl * 2, bevel=1)
            t.mark(m & ~B(x0 + 2, y0 + 2, x1 - 2, y1 - 2), -1)
            t.mark(m & (((XX - x0) % 7) == 0) & B(x0 + 2, y0 + 2, x1 - 2, y1 - 2), -1)
        elif v == 1:
            m = B(x0, y0, x1, y1, 2)
            col = ['container_b', 'paint_y', 'container_g', 'container_o'][k]
            t.slab(m, col, 9 + lvl * 2, bevel=1)
            holes = B(x0 + 3, y0 + 3, x1 - 3, y1 - 3) & (((XX - x0) % 5) < 2) & (((YY - y0) % 5) < 2)
            t.mark(holes, -2)
        else:
            m = B(x0, y0, x1, y1, 0.5)
            t.slab(m, 'kraft', 9 + lvl * 2, bevel=0.8)
            t.paint(B((x0 + x1) // 2 - 2, y0, (x0 + x1) // 2 + 2, y1) & m, 'paper' if k % 2 else 'kraft')
            t.mark(B((x0 + x1) // 2 - 2, y0, (x0 + x1) // 2 + 2, y1) & m, 1)
    return finish(t, theme, rng)


def sofa_form(t, p, rng, x0, x1, seats, mat, arms=True, back_h=14, y0=10, y1=50, tuft=False):
    t.slab(B(x0, y0, x1, y0 + 9, 3), mat, back_h, bevel=1.5)
    if arms:
        t.slab(B(x0, y0, x0 + 7, y1, 3), mat, 10, bevel=1.5)
        t.slab(B(x1 - 7, y0, x1, y1, 3), mat, 10, bevel=1.5)
    ix0, ix1 = (x0 + 8, x1 - 8) if arms else (x0, x1)
    w = (ix1 - ix0 + 1) / seats
    for k in range(seats):
        a = int(ix0 + k * w)
        b = int(ix0 + (k + 1) * w) - 1
        cushion(t, B(a, y0 + 9, b, y1 - 2, 3), mat, 7)
        if tuft:
            for yy in (y0 + 18, y0 + 28):
                t.mark(D((a + b) / 2, yy, 1), -2)
    tape(t, p, rng, B(ix0, y0 + 9, ix1, y1), 2)


def lounge_sofa(theme, rng, v):
    t, p = piece(), P(theme, v)
    mat = ['velvet_v', 'leather_k', 'velvet_teal'][v] if theme in ('rich', 'mid') else p.uph
    sofa_form(t, p, rng, 0, 63, 3, mat, arms=False, back_h=12, y0=8, y1=46)
    run(t)
    t.slab(B(0, 47, 63, 50), 'body2', 3, bevel=0.5)
    lit(t, p, rng, B(0, 50, 63, 51) & t.solid | B(0, 49, 63, 49), p.glow)
    return finish(t, theme, rng)


def dj_booth(theme, rng, v):
    t, p = piece(), P(theme, v)
    body(t, 0, 12, 63, 46, 13, ['graphite', 'velvet_v', 'wood_dark' if theme == 'rural' else 'alu'][v], 'dark_steel', r=1)
    run(t)
    for x in (13, 51):
        t.slab(B(x - 10, 16, x + 10, 38, 2), ['body2', 'alu', 'wood_light'][v], 2)
        t.slab(D(x, 27, 9), 'ink', 1.5, profile='cyl')
        t.mark(D(x, 27, 7) & ~D(x, 27, 6.4), 1)
        t.slab(D(x, 27, 1.5), 'chrome', 1)
        t.slab(L(x + 7, 19, x + 3, 33, 1.2), 'chrome', 2, bevel=0)
    mixer = B(25, 17, 39, 38, 1)
    t.slab(mixer, 'dark_steel', 2)
    for k in range(3):
        t.slab(B(27 + k * 4, 22, 28 + k * 4, 34), 'ink', 0.5)
        t.slab(B(27 + k * 4, 26 + (k * 3 + v) % 6, 28 + k * 4, 27 + (k * 3 + v) % 6), 'paint_w', 1)
    t.emit(D(36, 20, 1), 'neon_green')
    t.emit(D(28, 20, 1), 'neon_cyan')
    lit(t, p, rng, B(1, 45, 62, 46), p.glow)
    return finish(t, theme, rng)


def speaker_stack(theme, rng, v):
    t, p = piece(), P(theme, v)
    cab = ['graphite', 'wood_dark', 'alu'][v]
    body(t, 10, 6, 53, 58, 20, cab, cab, r=2, inset=3)
    for cy, r in ((22, 11), (46, 8)):
        t.slab(D(32, cy, r + 1), 'dark_steel', 1)
        t.carve(D(32, cy, r), 2)
        t.paint(D(32, cy, r), 'ink')
        t.mark(D(32, cy, r * 0.6) & ~D(32, cy, r * 0.5), 1)
        t.paint(D(32, cy, r * 0.25), 'dark_steel')
    t.mark(B(10, 34, 53, 34), -2)
    if v == 0:
        lit(t, p, rng, B(14, 55, 49, 55), p.glow)
    return finish(t, theme, rng)


def bakery_case(theme, rng, v):
    t, p = piece(), P(theme, v)
    body(t, 0, 14, 63, 48, 12, p.body, 'glass', r=1)
    run(t)
    goods = [('crust', 'dough'), ('cream', 'chocolate'), ('dough', 'berry')][v]
    for row, y in enumerate((22, 34)):
        for k in range(6):
            x = 6 + k * 10
            mat = goods[(k + row) % 2]
            sh = D(x + 2, y + 2, 4, 3) if (k + row + v) % 3 else B(x - 1, y, x + 5, y + 5, 1)
            t.slab(sh, mat, 2.5, profile='dome', on=11)
    t.mark(L(2, 16, 61, 46, 1) & B(0, 14, 63, 48), 2)
    band(t, p, B(0, 46, 63, 48))
    lit(t, p, rng, B(1, 15, 62, 15), 'lamp')
    return finish(t, theme, rng)


def bread_rack(theme, rng, v):
    t, p = piece(), P(theme, v)
    frame = p.wood if v != 1 else p.metal
    body(t, 0, 6, 63, 36, 15, frame, 'wood_light' if v != 1 else 'dark_steel', r=1)
    run(t)
    if v == 1:
        t.mark(B(2, 8, 61, 34) & (XX % 4 == 0), -1)
    for k in range(5):
        x = 3 + k * 12
        kind = (k + v) % 3
        if kind == 0:
            t.slab(D(x + 5, 16, 5, 4), 'crust', 3, profile='dome')
            t.mark(L(x + 2, 14, x + 7, 18, 1) & D(x + 5, 16, 5, 4), 1)
        elif kind == 1:
            t.slab(L(x + 1, 13, x + 10, 19, 4), 'crust', 3, profile='dome')
        else:
            t.slab(D(x + 5, 16, 4.5), 'bread_dark', 3, profile='dome')
        t.slab(D(x + 5, 28, 4, 3.5), 'dough' if kind else 'crust', 3, profile='dome')
    t.slab(B(8, 40, 30, 54, 3), 'kraft', 6, bevel=1)
    t.mark(B(8, 40, 30, 54) & ((XX + YY) % 3 == 0), -1)
    t.slab(D(16, 47, 4), 'crust', 2.5, profile='dome')
    return finish(t, theme, rng)


def karaoke_booth(theme, rng, v):
    t, p = piece(), P(theme, v)
    shell = ['graphite', p.enamel, 'plastic_w'][v]
    m = B(4, 4, 59, 59, 8)
    t.slab(m, shell, 22, bevel=2)
    t.mark(m & ((YY % 8) == 0) & B(10, 8, 53, 40), -1)
    t.slab(B(40, 10, 52, 22, 2), 'dark_steel', 2)
    t.mark(B(42, 12, 50, 20) & ((XX % 2) == 0), -1)
    win = B(10, 44, 34, 55, 2)
    t.paint(win, 'glass')
    t.mark(L(12, 54, 22, 45, 1) & win, 2)
    t.slab(B(38, 47, 40, 52), 'chrome', 1)
    rim = m & ~B(6, 6, 57, 57, 7)
    lit(t, p, rng, rim, ['neon_pink', 'neon_violet', 'neon_cyan'][v])
    t.emit(win & D(22, 50, 6, 4), 'neon_violet' if v != 2 else 'neon_pink')
    return finish(t, theme, rng)


# ================================================================================================ retail
def clothing_rack(theme, rng, v):
    t, p = piece(), P(theme, v)
    t.slab(B(2, 28, 7, 36, 2) | B(56, 28, 61, 36, 2), p.metal, 5, bevel=0.8)
    t.slab(L(4, 32, 59, 32, 2), p.metal, 22, bevel=0.5)
    pal = {'rich': ['leather_k', 'fabric_cream', 'graphite', 'paint_w'], 'mid': ['fabric_b', 'fabric_grey', 'fabric_mustard', 'paint_w', 'fabric_g'],
           'slum': ['vinyl_r', 'fabric_g', 'paint_y', 'velvet_v', 'container_b', 'fabric_o'],
           'rural': ['fabric_indigo', 'linen', 'fabric_o', 'kraft'], 'industry': ['canvas_bag', 'enamel_o', 'fabric_grey', 'kevlar']}[theme]
    gw = {'rich': 7, 'slum': 4}.get(theme, 5)
    x, k = 9, 0
    while x + gw <= 55:
        if p.rich and k % 2:
            x += 3
        col = pal[(k // 2 + v) % len(pal)] if not p.poor else rng.pick(pal)
        g = B(x, 17 + (k % 2), x + gw - 1, 47 - (k % 3), 2)
        t.slab(g, col, 17 - (k % 2), profile='dome', on=4)
        t.mark(B(x, 17, x, 47) & g, -1)
        x += gw
        k += 1
    t.slab(L(4, 32, 59, 32, 1.2), p.metal, 23, bevel=0)
    return finish(t, theme, rng)


def mannequin(theme, rng, v):
    """a shop dummy standing upright, seen like the people of the game: head, shoulders, arms, the garment it shows,
    legs on a stand.  Featureless and pale (or graphite downtown), so it never reads as a person"""
    t, p = piece(), P(theme, v)
    skin = 'graphite' if (p.rich and v == 1) else 'skin_dummy'
    garment = {'rich': ['fabric_cream', 'velvet_teal', 'leather_k'], 'mid': ['fabric_b', 'fabric_mustard', 'fabric_grey'],
               'slum': ['velvet_v', 'fabric_g', 'vinyl_r'], 'rural': ['fabric_indigo', 'linen', 'fabric_o'],
               'industry': ['canvas_bag', 'enamel_o', 'kevlar']}[theme][v]
    t.slab(D(32, 58, 11, 3.5), p.metal, 2, bevel=0.8)
    t.slab(B(31, 50, 33, 58), p.metal, 4, bevel=0)
    legs_m = B(25, 36, 30, 54, 1) | B(34, 36, 39, 54, 1)
    t.slab(legs_m, skin if v == 0 else ('fabric_indigo' if garment != 'fabric_indigo' else 'graphite'), 6, profile='dome')
    t.mark(B(31, 36, 33, 54) & legs_m, -1)
    arms = B(15, 18, 19, 38, 2) | B(45, 18, 49, 38, 2)
    t.slab(arms, skin, 6, profile='dome')
    if v == 0:      # a dress: flares from the waist
        body_m = Tile.poly_mask([(20, 16), (44, 16), (41, 30), (47, 47), (17, 47), (23, 30)])
    elif v == 1:    # a jacket to the hip
        body_m = Tile.poly_mask([(19, 16), (45, 16), (43, 40), (21, 40)])
    else:           # a long coat, open at the front
        body_m = Tile.poly_mask([(18, 16), (46, 16), (45, 52), (19, 52)])
    t.slab(body_m, garment, 9, profile='dome')
    if v != 0:
        t.slab(B(15, 16, 19, 32, 2) | B(45, 16, 49, 32, 2), garment, 8, profile='dome')      # sleeves
    t.mark(L(32, 17, 32, 40 if v else 30, 1) & body_m, -1)
    if v == 2:
        t.paint(L(32, 18, 32, 52, 2) & body_m, skin)
    t.slab(B(30, 11, 34, 16), skin, 7, bevel=0.5)
    t.slab(D(32, 8, 5.5, 6.5), skin, 9, profile='dome')
    return finish(t, theme, rng)


def shoe_wall(theme, rng, v):
    t, p = piece(), P(theme, v)
    wall_run(t, p, 2, 30, 18)
    cols = {'rich': ['leather_k', 'leather_br', 'paint_w', 'graphite'], 'industry': ['rubber', 'kraft', 'leather_br']}.get(
        theme, ['paint_w', 'fabric_b', 'plastic_r', 'leather_br', 'paint_y', 'rubber'])
    for row, y in enumerate((8, 21)):
        t.mark(B(0, y + 7, 63, y + 7), -1)
        for k in range(4):
            if p.poor and rng.chance(0.25):
                continue
            x = 3 + k * 16
            c = cols[(k + row * 2 + v) % len(cols)]
            t.slab(D(x + 4, y + 2, 3, 4.5), c, 3, profile='dome')
            t.slab(D(x + 10, y + 2, 3, 4.5), c, 3, profile='dome')
            t.paint(D(x + 4, y + 4, 1.5, 2) | D(x + 10, y + 4, 1.5, 2), 'paint_w' if c != 'paint_w' else 'rubber')
    if p.rich:
        lit(t, p, rng, B(0, 29, 63, 29), 'lamp')
    return finish(t, theme, rng)


def mirror(theme, rng, v):
    t, p = piece(), P(theme, v)
    frame = ['gold' if p.rich else p.wood, p.metal, 'lacquer_black'][v]
    if v == 1:
        m = D(32, 30, 16, 23)
        t.slab(m, frame, 10, bevel=1)
        glass = D(32, 30, 13, 20)
    else:
        m = B(16, 6, 47, 54, 2)
        t.slab(m, frame, 10, bevel=1)
        glass = B(19, 9, 44, 51, 1)
    t.paint(glass, 'mirror')
    t.mark(L(22, 22, 34, 10, 2) & glass, 2)
    t.mark(L(28, 34, 42, 18, 1) & glass, 1)
    if p.poor:
        t.mark(cracks(rng.int(0, 1 << 20), 1, 14, wrap=False, region=glass) & glass, -2)
    t.slab(B(14, 54, 22, 58, 1) | B(41, 54, 49, 58, 1), frame, 3, bevel=0.5)
    return finish(t, theme, rng)


def display_case(theme, rng, v):
    t, p = piece(), P(theme, v)
    m = body(t, 4, 12, 59, 50, 13, p.body, 'glass', r=1, inset=3)
    inside = B(8, 16, 55, 46)
    t.paint(inside, 'fabric_indigo' if p.rich else 'linen' if v == 1 else 'velvet_v')
    t.h[inside] -= 2
    for k in range(5):
        x = 13 + k * 9
        kind = (k + v) % 3
        if kind == 0:
            t.slab(D(x, 26, 3), 'gold', 2, profile='dome')
            t.paint(D(x, 26, 1.5), 'velvet_v' if p.rich else 'plastic_w')
        elif kind == 1:
            t.slab(D(x, 26, 3.5) & ~D(x, 26, 2), 'chrome', 1.5)
        else:
            t.slab(B(x - 3, 23, x + 3, 29, 1), 'card_k', 1.5)
        t.slab(B(x - 3, 36, x + 3, 40, 1), ['gold', 'chrome', 'brass'][(k + v) % 3], 1, profile='dome')
    t.paint(B(5, 13, 58, 15), 'glass')
    t.mark(L(8, 47, 30, 16, 1) & inside, 2)
    band(t, p, m)
    lit(t, p, rng, B(8, 16, 55, 16), 'lamp_cold')
    return finish(t, theme, rng)


def electronics_shelf(theme, rng, v):
    t, p = piece(), P(theme, v)
    shelf_run(t, p, 6, 34, 16, 'graphite' if theme in ('rich', 'mid') else p.body, 'body2')
    for row, y in enumerate((10, 22)):
        x = 3
        while x < 58:
            w = rng.int(6, 11)
            if x + w > 61:
                break
            kind = rng.int(0, 2)
            if kind == 0:
                on(t, B(x, y, x + w - 1, y + 8, 1), 'dark_steel', 3)
                lit(t, p, rng, B(x + 1, y + 1, x + w - 2, y + 5), rng.pick(['screen_glow', 'neon_cyan', 'neon_violet']))
            elif kind == 1:
                on(t, B(x, y, x + w - 1, y + 8, 1), rng.pick(['paint_w', 'plastic_b', 'enamel_teal']), 3)
                t.mark(B(x + 1, y + 2, x + w - 2, y + 3), -1)
            else:
                on(t, D(x + w / 2, y + 4, 3.5), 'card_k', 3, profile='dome')
            x += w + 2
    return finish(t, theme, rng)


def tv_wall(theme, rng, v):
    t, p = piece(), P(theme, v)
    wall_run(t, p, 2, 38, 20, 'graphite')
    hues = [['screen_glow', 'neon_cyan', 'neon_violet'], ['neon_pink', 'screen_glow', 'neon_amber'], ['neon_green', 'neon_cyan', 'screen_glow']][v]
    for r_ in range(2):
        for c_ in range(3):
            x0, y0 = 2 + c_ * 21, 5 + r_ * 16
            fr = B(x0, y0, x0 + 18, y0 + 13)
            t.slab(fr, 'ink', 1)
            scr = B(x0 + 1, y0 + 1, x0 + 17, y0 + 12)
            if p.poor and rng.chance(0.3):
                t.paint(scr, 'screen')
                t.mark(cracks(rng.int(0, 1 << 20), 1, 8, wrap=False, region=scr) & scr, 2)
                continue
            t.emit(scr, hues[(r_ + c_) % 3])
            t.mark(scr & ((YY - y0) % 3 == 0), -1)
            t.mark(D(x0 + 6 + (c_ * 5 + r_ * 3) % 8, y0 + 6, 3) & scr, 2)
    return finish(t, theme, rng)


def office_shelf(theme, rng, v):
    t, p = piece(), P(theme, v)
    shelf_run(t, p, 6, 34, 16, p.enamel if v == 2 else p.body, p.top if v != 2 else p.enamel)
    stock(t, rng, 2, 62, 9, 18, ['paper', 'paper', 'kraft'], (6, 10), 3)
    stock(t, rng, 2, 62, 22, 31, [['fabric_b', 'paint_y', 'graphite'], ['fabric_g', 'plastic_r', 'paper'], ['enamel_teal', 'kraft', 'graphite']][v], (3, 5), 2.5, gap=0,
          miss=0.15 if p.poor else 0.0)
    return finish(t, theme, rng)


def copier(theme, rng, v):
    t, p = piece(), P(theme, v)
    shell = ['plastic_w', 'enamel_grey', 'enamel_cream'][v]
    body(t, 8, 10, 51, 52, 16, shell, shell, r=3)
    t.slab(B(12, 14, 47, 36, 1), 'dark_steel', 1.5)
    t.paint(B(14, 16, 45, 34), 'glass')
    t.slab(B(12, 40, 36, 48, 1), 'graphite', 1)
    lit(t, p, rng, B(14, 42, 22, 46), 'screen_glow')
    for k in range(4):
        t.slab(D(26 + k * 3, 44, 1), 'paint_w' if k else 'neon_green', 1)
    t.emit(D(26, 44, 1), 'neon_green')
    t.slab(B(52, 18, 60, 40, 1), shell, 9, bevel=0.6)
    t.slab(B(53, 20, 59, 38), 'paper', 1)
    return finish(t, theme, rng)


def filing_cabinet(theme, rng, v):
    t, p = piece(), P(theme, v)
    shell = [p.enamel, 'enamel_grey' if not p.rich else 'graphite', p.wood][v]
    for x0 in ((14,) if v == 0 else (4, 33)):
        m = body(t, x0, 8, x0 + 27 if v else x0 + 35, 54, 18, shell, shell, r=1)
        x1 = x0 + 27 if v else x0 + 35
        for k in range(4):
            y = 10 + k * 11
            t.mark(B(x0 + 1, y + 10, x1 - 1, y + 10), -2)
            t.slab(B((x0 + x1) // 2 - 4, y + 4, (x0 + x1) // 2 + 4, y + 6, 0.5), 'chrome', 1)
            t.paint(B((x0 + x1) // 2 - 3, y + 1, (x0 + x1) // 2 + 3, y + 2), 'paper')
    if p.poor:
        t.slab(B(20, 36, 44, 46), 'paper', 1)
    return finish(t, theme, rng)


def weapon_rack(theme, rng, v):
    """practice weapons on a wall rack: two pieces on two pegs, a plain board"""
    t, p = piece(), P(theme, v)
    wood = 'wood_dark' if theme in ('rich', 'rural') else 'wood'
    wall_run(t, p, 4, 30, 8, wood)
    peg = 'wood_light' if wood == 'wood_dark' else 'wood_dark'
    for x in (12, 52):
        for y in (12, 23):
            t.slab(B(x - 2, y - 2, x + 2, y + 2, 1), peg, 10, bevel=0.5)
    items = [('sword', 'staff'), ('staff', 'pad'), ('pad', 'sword')][v]
    for k, kind in enumerate(items):
        y = 12 + k * 11
        if kind == 'sword':         # wooden sword: blade, guard, wrapped grip
            t.slab(B(16, y - 2, 60, y + 1, 1.5), 'wood_light', 12, bevel=1)
            t.slab(B(13, y - 4, 15, y + 3, 1), 'lacquer_black', 13, bevel=0.5)
            t.slab(B(3, y - 2, 12, y + 1, 1.5), 'fabric_indigo', 12, bevel=1)
        elif kind == 'staff':
            t.slab(B(1, y - 2, 62, y + 1, 1.5), 'wood', 12, bevel=1)
        else:                       # padded practice blade
            t.slab(B(17, y - 3, 59, y + 2, 2.5), 'rubber' if theme != 'rich' else 'leather_k', 12, bevel=1.5)
            t.slab(B(5, y - 2, 16, y + 1, 1.5), 'leather_br', 12, bevel=1)
    t.norim |= t.h > 9                  # the weapons and pegs: outline and light only, no rim on every thin edge
    return finish(t, theme, rng)


def training_dummy(theme, rng, v):
    t, p = piece(), P(theme, v)
    if v == 0:          # wooden post with three arms and a leg
        t.slab(B(14, 44, 50, 54, 2), 'wood_dark', 4)
        t.slab(L(20, 22, 10, 14, 4), 'wood_light', 16, bevel=0.8)
        t.slab(L(44, 22, 54, 14, 4), 'wood_light', 16, bevel=0.8)
        t.slab(L(32, 38, 32, 54, 5), 'wood_light', 12, bevel=0.8)
        t.slab(D(32, 30, 13), 'wood', 22, profile='dome')
        t.mark(D(32, 30, 12) & (((YY - 30) % 6) == 0), -1)
    elif v == 1:        # padded torso on a base
        t.slab(D(32, 34, 15), 'dark_steel', 3)
        t.slab(D(32, 34, 13, 10), 'canvas_w' if theme != 'slum' else 'kraft', 18, profile='dome')
        t.slab(D(32, 30, 7), 'canvas_w' if theme != 'slum' else 'kraft', 24, profile='dome')
        t.mark(D(32, 34, 13, 10) & (np.abs(XX - 32) < 1), -1)
        tape(t, p, rng, D(32, 34, 13, 10), 3)
    else:               # tyres on a post
        for k, r in enumerate((17, 14, 11)):
            ring = D(32, 32, r) & ~D(32, 32, r - 5)
            t.slab(ring, 'rubber', 6 + k * 5, profile='dome')
        t.slab(D(32, 32, 4), 'wood', 22, profile='cyl')
    return finish(t, theme, rng)


def punching_bag(theme, rng, v):
    t, p = piece(), P(theme, v)
    mat = ['leather_ox', 'leather_k', 'canvas_bag'][v]
    for x, y in ((14, 14), (50, 14), (14, 50), (50, 50)):
        t.slab(L(32, 32, x, y, 1), p.metal, 26, bevel=0, obj=False)
    t.slab(D(32, 32, 14), mat, 22, profile='dome')
    t.mark(D(32, 32, 14) & ~D(32, 32, 13), -1)
    t.slab(D(32, 32, 3), p.metal, 25, profile='cyl')
    t.mark(D(32, 32, 10) & ~D(32, 32, 9), -1)
    tape(t, p, rng, D(32, 32, 13), 3)
    return finish(t, theme, rng)


def pawn_cage(theme, rng, v):
    t, p = piece(), P(theme, v)
    body(t, 0, 24, 63, 50, 11, p.body, p.top, r=1)
    run(t)
    cage = B(0, 8, 63, 22)
    t.slab(cage, 'dark_steel', 24, bevel=0.5, obj=True)
    hole = cage & ~(((XX % 6) == 0) | ((YY % 6) == 2))
    t.clear(hole)
    t.slab(B(26, 22, 38, 25), 'dark_steel', 13)
    for k in range(4):
        x = 6 + k * 15
        t.slab(B(x, 30, x + 8, 36, 1), ['gold', 'card_k', 'chrome', 'brass'][(k + v) % 4], 1.5, profile='dome')
    t.slab(B(44, 38, 56, 46, 1), 'paper', 0.8)
    return finish(t, theme, rng)


def safe(theme, rng, v):
    t, p = piece(), P(theme, v)
    shell = ['graphite', 'enamel_g' if theme != 'rich' else 'enamel_cream', 'dark_steel'][v]
    m = body(t, 12, 10, 51, 54, 18, shell, shell, r=2)
    t.mark(B(15, 13, 48, 51) & ~B(16, 14, 47, 50), -1)
    t.slab(D(26, 32, 6), 'chrome', 2, profile='dome')
    t.mark(D(26, 32, 6) & ((np.round(np.arctan2(YY - 32, XX - 26) * 4) % 2) == 0) & ~D(26, 32, 4), -1)
    t.slab(L(38, 26, 38, 38, 2.5), 'chrome', 2)
    if p.rich:
        t.paint(B(14, 52, 49, 54), 'accent')
    for x, y in ((16, 14), (47, 14), (16, 50), (47, 50)):
        t.paint(D(x, y, 1), 'chrome')
    return finish(t, theme, rng)


def gun_rack(theme, rng, v):
    """long guns standing in a wall rack: three silhouettes, barrel up, on a plain board"""
    t, p = piece(), P(theme, v)
    wall_run(t, p, 2, 44, 12, ['graphite', 'wood_dark', 'olive_d'][v])
    t.slab(B(0, 36, 63, 42), p.metal, 15, bevel=0.6)
    stock_m = ['wood', 'rubber', 'kevlar'][v]
    for k in range(3):
        x = 12 + k * 20
        if p.poor and k == 1:
            continue
        t.slab(B(x - 1, 5, x + 1, 26, 0.5), 'dark_steel', 16, bevel=0.5)                                   # barrel
        t.slab(Tile.poly_mask([(x - 3, 24), (x + 3, 24), (x + 4, 44), (x - 4, 44)]), stock_m, 16, bevel=1)   # body and stock
        t.slab(B(x - 2, 26, x + 2, 32, 1), 'dark_steel', 17, bevel=0.5)                                    # receiver
    t.norim |= t.h > 13
    return finish(t, theme, rng)


def hardware_rack(theme, rng, v):
    t, p = piece(), P(theme, v)
    shelf_run(t, p, 6, 36, 16, p.metal if theme != 'rural' else 'wood', 'dark_steel')
    for k in range(4):
        x = 2 + k * 16
        kind = (k + v) % 4
        if kind == 0:
            for j in range(3):
                t.slab(D(x + 7, 14 + j * 7, 5) & ~D(x + 7, 14 + j * 7, 2), 'kraft', 3 + j, profile='dome')
        elif kind == 1:
            for j in range(2):
                on(t, B(x + 1, 10 + j * 12, x + 13, 19 + j * 12, 1), 'enamel_b' if j else 'container_o', 3)
                t.mark(B(x + 3, 12 + j * 12, x + 11, 13 + j * 12), 1)
        elif kind == 2:
            for j in range(2):
                for i in range(3):
                    t.slab(D(x + 3 + i * 5, 15 + j * 11, 2.2), 'paint_w' if (i + j) % 2 else 'paint_y', 4, profile='cyl')
        else:
            t.slab(B(x + 1, 10, x + 13, 32, 1), 'rubber', 2)
            for j in range(4):
                t.slab(L(x + 3, 13 + j * 5, x + 11, 13 + j * 5, 1.6), 'chrome', 3, bevel=0)
    return finish(t, theme, rng)


def tool_wall(theme, rng, v):
    t, p = piece(), P(theme, v)
    board = ['kraft', 'enamel_grey', 'paint_w'][v]
    wall_run(t, p, 2, 46, 12, board)
    t.mark(B(0, 2, 63, 46) & ((XX % 4) == 2) & ((YY % 4) == 0), -1)
    hd = p.metal
    # hammer, wrench, saw, pliers, screwdrivers
    t.slab(L(8, 8, 8, 34, 2.5), 'wood', 14, bevel=0.4)
    t.slab(B(3, 6, 13, 10, 1), hd, 15, bevel=0.4)
    t.slab(L(20, 8, 24, 36, 2.5), hd, 14, bevel=0.4)
    t.slab(D(20, 8, 3.5) & ~D(20, 6, 2), hd, 14, bevel=0.4)
    saw = Tile.poly_mask([(30, 10), (46, 10), (46, 22), (30, 38)])
    t.slab(saw, 'steel', 13, bevel=0.4)
    t.mark(saw & L(30, 38, 46, 22, 1.5) & ((XX + YY) % 2 == 0), -1)
    t.slab(B(42, 6, 50, 12, 2), 'paint_y' if v != 2 else 'plastic_r', 14, bevel=0.5)
    for k in range(3):
        x = 52 + k * 4
        t.slab(L(x, 8, x, 18, 2.4), ['plastic_r', 'paint_y', 'container_b'][k], 14, bevel=0.4)
        t.slab(L(x, 18, x, 30, 1.2), 'chrome', 14, bevel=0)
    return finish(t, theme, rng)


def lumber_stack(theme, rng, v):
    t, p = piece(), P(theme, v)
    for k, x0 in enumerate((0,)):
        t.slab(B(0, 12, 63, 16), 'wood_dark', 3, bevel=0.5)
        t.slab(B(0, 46, 63, 50), 'wood_dark', 3, bevel=0.5)
    for j in range(5):
        y = 10 + j * 9
        lvl = 4 + (j % 2) * 4 + (2 if j == 2 else 0)
        m = B(0, y, 63, y + 7)
        t.slab(m, ['wood_light', 'wood', 'wood_light'][(j + v) % 3], lvl, bevel=0.8)
        t.mark(m & ((((XX * 3 + j * 17) % 23) == 0)), -1)
        t.mark(m & (YY == y + 3) & ((XX + j * 9) % 9 < 4), -1)
    run(t)
    if v == 2:
        t.slab(B(4, 24, 60, 26), 'kraft', 13, bevel=0.3)
    return finish(t, theme, rng)


def pharmacy_shelf(theme, rng, v):
    t, p = piece(), P(theme, v)
    shelf_run(t, p, 6, 34, 16, 'plastic_w' if theme != 'slum' else p.body, 'laminate_w')
    meds = ['paint_w', 'paint_w', 'fabric_b', 'enamel_teal', 'laminate_g', 'paint_y', 'container_o']
    stock(t, rng, 2, 62, 9, 17, meds, (3, 6), 3, miss=0.2 if p.poor else 0.0)
    stock(t, rng, 2, 62, 22, 30, meds, (2, 4), 3.5, prof='cyl', miss=0.2 if p.poor else 0.0)
    lit(t, p, rng, B(0, 33, 63, 33), 'neon_green')
    return finish(t, theme, rng)


def scale(theme, rng, v):
    t, p = piece(), P(theme, v)
    body(t, 10, 22, 53, 54, 5, p.metal, 'dark_steel', r=2)
    t.mark(B(13, 25, 50, 51) & (((XX + YY) % 4) == 0), -1)
    t.slab(B(26, 8, 37, 22, 1), p.enamel, 14, bevel=0.6)
    t.slab(B(22, 4, 41, 12, 2), 'graphite', 16, bevel=0.8)
    lit(t, p, rng, B(25, 6, 38, 9), 'neon_green')
    if v == 0:
        t.slab(B(16, 28, 44, 48, 1), 'kraft', 9, bevel=0.8)
        t.paint(B(28, 28, 32, 48), 'paper')
    elif v == 2:
        t.slab(B(18, 26, 46, 50, 2), 'container_b', 8, bevel=0.8)
        t.mark(B(18, 26, 46, 50) & ((XX % 5) == 0), -1)
    return finish(t, theme, rng)


def bookshelf(theme, rng, v):
    t, p = piece(), P(theme, v)
    shelf_run(t, p, 4, 36, 18, p.wood if v != 2 else p.body, 'wood_dark' if v != 2 else p.top)
    spines = [['leather_ox', 'fabric_indigo', 'leather_br', 'fabric_g', 'paper'], ['fabric_mustard', 'leather_k', 'kraft', 'fabric_indigo', 'paper'],
              ['enamel_teal', 'fabric_o', 'paint_w', 'leather_br', 'fabric_b']][v]
    for y0 in (7, 21):
        x = 2
        while x < 61:
            w = rng.int(2, 4)
            if rng.chance(0.08 if not p.poor else 0.25):
                t.slab(L(x, y0 + 10, x + 7, y0 + 3, 2.5), rng.pick(spines), 3, bevel=0.5)
                x += 9
                continue
            if x + w > 61:
                break
            on(t, B(x, y0, x + w - 1, y0 + 11), rng.pick(spines), 3 + rng.range(0, 1.5), bevel=0.4)
            t.mark(B(x, y0 + 2, x + w - 1, y0 + 2), 1)
            x += w
    return finish(t, theme, rng)


def armchair(theme, rng, v):
    t, p = piece(), P(theme, v)
    mat = p.uph if v != 1 or not p.rich else 'leather_br'
    t.slab(B(10, 10, 53, 20, 4), mat, 15, bevel=2)
    t.slab(B(10, 12, 18, 54, 4), mat, 11, bevel=2)
    t.slab(B(45, 12, 53, 54, 4), mat, 11, bevel=2)
    seat = cushion(t, B(19, 20, 44, 52, 4), mat, 7)
    if p.rich and v == 0:
        for x, y in ((25, 15), (32, 15), (39, 15)):
            t.mark(D(x, y, 1), -2)
    if theme == 'rural' or v == 2:
        t.slab(B(12, 54, 15, 57) | B(48, 54, 51, 57), 'wood_dark', 3, bevel=0.3)
    tape(t, p, rng, seat, 2)
    return finish(t, theme, rng)


def car_plinth(theme, rng, v):
    t, p = piece(), P(theme, v)
    m = D(32, 32, 30)
    t.slab(m, ['steel', 'alu', 'graphite'][v], 4, bevel=1.5)
    t.paint(D(32, 32, 26), 'top' if v == 0 else 'dark_steel')
    ring = D(32, 32, 28) & ~D(32, 32, 26.6)
    lit(t, p, rng, ring, 'neon_cyan' if p.rich else p.glow)
    t.mark(D(32, 32, 26) & ((np.round(np.arctan2(YY - 32, XX - 32) * 6) % 2) == 0) & ~D(32, 32, 20), -1)
    return finish(t, theme, rng)


def tire_rack(theme, rng, v):
    t, p = piece(), P(theme, v)
    shelf_run(t, p, 6, 40, 4, [p.metal, 'enamel_b', 'enamel_o'][v], 'dark_steel')
    for row, y in enumerate((10, 26)):
        for k in range(5 - (v == 2)):
            x = 2 + k * (12 + 3 * (v == 2)) + (row * 3) + v
            if x > 54:
                break
            m = B(x, y, x + 9, y + 12, 3)
            t.slab(m, 'rubber', 9 + row, profile='dome')
            t.mark(m & ((YY - y) % 3 == 0), -1)
            t.paint(B(x + 3, y, x + 6, y + 1) & m, p.metal)
    return finish(t, theme, rng)


def desk_form(t, p, x0, y0, x1, y1, h=10):
    legs(t, x0 + 3, y0 + 3, x1 - 3, y1 - 3, p.metal if p.theme != 'rural' else 'wood_dark', r=1.5, h=h - 2)
    return body(t, x0, y0, x1, y1, h, p.body, p.top, r=1.5)


def monitor(t, p, rng, x0, y0, w=16, glow='screen_glow'):
    t.slab(B(x0 + w // 2 - 2, y0 + 6, x0 + w // 2 + 2, y0 + 9), 'dark_steel', 3)
    t.slab(B(x0, y0, x0 + w, y0 + 5), 'graphite', 8, bevel=0.5)
    lit(t, p, rng, B(x0 + 1, y0 + 4, x0 + w - 1, y0 + 5), glow)


def desk(theme, rng, v):
    t, p = piece(), P(theme, v)
    desk_form(t, p, 4, 14, 59, 46)
    if v != 2:
        monitor(t, p, rng, 10, 18, 18)
        t.slab(B(10, 32, 30, 37, 1), 'dark_steel' if v == 0 else 'plastic_w', 1)
    else:
        t.slab(B(10, 20, 30, 34, 1), 'card_k', 1)
        lit(t, p, rng, B(12, 21, 28, 30), 'screen_glow')
    t.slab(B(38, 22, 52, 40), 'paper', 0.6)
    t.slab(B(40, 20, 54, 38), 'paper', 0.6)
    t.slab(D(48, 18, 2.5), 'paint_w', 3, profile='cyl')
    return finish(t, theme, rng)


def lift_hoist(theme, rng, v):
    t, p = piece(), P(theme, v)
    paint_ = ['hazard_y', 'enamel_b', 'enamel_o'][v]
    for x in (4, 50):
        t.slab(B(x, 4, x + 9, 15, 1), paint_, 24, bevel=1)
        t.paint(B(x + 2, 6, x + 7, 13), 'dark_steel')
    for x in (10, 44):
        m = B(x, 18, x + 9, 60, 1)
        t.slab(m, paint_ if v else 'dark_steel', 5, bevel=1)
        t.mark(m & ((YY % 4) == 0), -1)
    t.slab(L(13, 12, 22, 22, 3), paint_, 6)
    t.slab(L(50, 12, 41, 22, 3), paint_, 6)
    haz = B(0, 61, 63, 63) & ((((XX + YY) // 4) % 2) == 0)
    t.ground('hazard_y', B(0, 61, 63, 63))
    t.paint(haz, 'hazard_k')
    return finish(t, theme, rng)


def tool_chest(theme, rng, v):
    t, p = piece(), P(theme, v)
    shell = ['enamel_b', 'enamel_o', 'graphite'][v] if theme != 'slum' else ['enamel_g', 'rust', 'enamel_grey'][v]
    body(t, 10, 10, 53, 50, 16, shell, shell, r=2)
    t.paint(B(13, 13, 50, 20, 1), 'rubber')
    for k in range(4):
        y = 22 + k * 7
        t.mark(B(11, y, 52, y), -2)
        t.slab(B(22, y + 2, 41, y + 3), 'chrome', 1)
    for x in (14, 49):
        wheel(t, x, 53, 2.5)
    t.slab(B(16, 14, 30, 18, 1), 'dark_steel', 1.5)
    t.slab(L(34, 15, 46, 17, 2), p.metal, 2)
    return finish(t, theme, rng)


def workbench(theme, rng, v):
    t, p = piece(), P(theme, v)
    top = ['wood_light', 'wood', 'dark_steel'][v]
    legs(t, 6, 16, 57, 48, p.metal if v else 'wood_dark', r=2, h=8)
    body(t, 2, 12, 61, 50, 10, top, top, r=1)
    run(t)
    t.mark(B(2, 12, 61, 50) & ((YY % 8) == 4) & (top != 'dark_steel'), -1)
    t.slab(B(4, 14, 14, 24, 1), 'enamel_b' if theme != 'industry' else 'enamel_o', 4, bevel=0.5)
    t.slab(B(6, 24, 12, 30), 'dark_steel', 3)
    t.slab(L(24, 30, 40, 22, 2.4), p.metal, 1.5, bevel=0)
    t.slab(B(44, 32, 56, 44), 'wood_light', 2, bevel=0.4)
    t.slab(D(30, 40, 2), 'brass', 1, profile='cyl')
    t.slab(D(34, 42, 1.5), 'brass', 1, profile='cyl')
    if theme in ('slum', 'industry'):
        t.paint(blotches(rng.int(0, 1 << 20), 0.12) & B(2, 12, 61, 50), 'oil')
    return finish(t, theme, rng)


# ================================================================================================ services
def teller_window(theme, rng, v):
    t, p = piece(), P(theme, v)
    body(t, 0, 28, 63, 54, 11, p.body, p.top, r=1)
    run(t)
    t.slab(B(0, 24, 63, 28), 'glass', 26, bevel=0.5)
    t.mark(B(0, 24, 63, 24), 2)
    t.clear(B(24, 26, 39, 28))
    t.slab(B(24, 26, 39, 28), 'dark_steel', 11.5)
    t.slab(B(4, 8, 59, 22), p.body, 8, bevel=1)
    monitor(t, p, rng, 8, 8, 16)
    t.slab(B(30, 12, 42, 20), 'paper', 0.6)
    t.slab(B(48, 12, 54, 16), 'note_g', 1)
    band(t, p, B(0, 52, 63, 54))
    return finish(t, theme, rng)


def queue_rail(theme, rng, v):
    t, p = piece(), P(theme, v)
    beltm = ['fabric_b', 'velvet_v' if p.rich else 'fabric_r', 'graphite'][v]
    rope = p.rich and v == 1
    post = 'gold' if rope else ['chrome', 'brass', 'graphite'][v]
    for x in (6, 57):
        t.slab(D(x, 32, 5), post, 3, bevel=0.6)
        t.slab(D(x, 32, 2.5), post, 22, profile='cyl')
    if rope:
        t.slab(L(0, 32, 63, 32, 3.5), 'velvet_v', 19, profile='dome')
    else:
        t.slab(B(0, 31, 63, 33), beltm, 20, bevel=0)
    run(t)
    return finish(t, theme, rng)


def deposit_boxes(theme, rng, v):
    t, p = piece(), P(theme, v)
    face = ['brass', 'steel', 'graphite'][v]
    wall_run(t, p, 2, 44, 18, face)
    for r_ in range(4):
        for c_ in range(6):
            x0, y0 = 1 + c_ * 10 + (r_ % 2) * 0, 4 + r_ * 10
            d = B(x0, y0, x0 + 8, y0 + 8)
            t.mark(d & ~B(x0 + 1, y0 + 1, x0 + 7, y0 + 7), -1)
            t.mark(D(x0 + 4, y0 + 4, 1), -2)
            t.mark(B(x0 + 2, y0 + 7, x0 + 6, y0 + 7), 1)
    if p.poor:
        t.carve(B(21, 24, 29, 32), 3)
    return finish(t, theme, rng)


def atm(theme, rng, v):
    t, p = piece(), P(theme, v)
    shell = [p.enamel if p.enamel != 'graphite' else 'enamel_cream', 'graphite', 'alu'][v]
    body(t, 12, 8, 51, 50, 20, shell, shell, r=3)
    t.slab(B(16, 12, 47, 28, 1), 'ink', 1)
    lit(t, p, rng, B(18, 14, 45, 26), 'screen_glow')
    t.mark(B(18, 14, 45, 26) & ((YY % 3) == 0), -1)
    for r_ in range(3):
        for c_ in range(3):
            t.slab(B(20 + c_ * 5, 32 + r_ * 4, 23 + c_ * 5, 34 + r_ * 4), 'chrome', 1)
    t.emit(B(38, 33, 46, 34), 'neon_green')
    t.slab(B(37, 40, 47, 44), 'dark_steel', 1)
    if p.poor:
        t.mark(cracks(rng.int(0, 1 << 20), 1, 10, wrap=False, region=B(18, 14, 45, 26)) & B(18, 14, 45, 26), 2)
    return finish(t, theme, rng)


def vault_door(theme, rng, v):
    t, p = piece(), P(theme, v)
    t.slab(B(0, 0, 63, 12), 'dark_steel', 20, bevel=1)
    m = D(32, 32, 28)
    t.slab(m, 'steel' if v != 2 else 'graphite', 14, bevel=2)
    t.mark(D(32, 32, 24) & ~D(32, 32, 23), -1)
    for k in range(8):
        a = k * math.pi / 4
        t.slab(D(32 + math.cos(a) * 26, 32 + math.sin(a) * 26, 2), 'chrome', 1, profile='dome')
    t.slab(D(32, 32, 9) & ~D(32, 32, 6), 'chrome', 4, bevel=0.5)
    for k in range(3):
        a = k * 2 * math.pi / 3 + v
        t.slab(L(32, 32, 32 + math.cos(a) * 14, 32 + math.sin(a) * 14, 2.5), 'chrome', 4, bevel=0.4)
    t.slab(D(32, 32, 3), 'brass' if p.rich else 'chrome', 5, profile='dome')
    run(t)
    return finish(t, theme, rng)


def police_desk(theme, rng, v):
    t, p = piece(), P(theme, v)
    front = ['enamel_b', 'graphite', 'fabric_indigo'][v]
    body(t, 0, 12, 63, 40, 10, p.body, p.top, r=1)
    t.slab(B(0, 40, 63, 52), front, 15, bevel=1)
    t.mark(B(0, 46, 63, 46), 1)
    run(t)
    monitor(t, p, rng, 6, 16, 16)
    monitor(t, p, rng, 40, 16, 16, 'neon_cyan')
    t.slab(B(26, 24, 36, 34), 'paper', 0.6)
    lit(t, p, rng, B(0, 42, 63, 43), 'neon_cyan' if theme != 'slum' else 'lamp_cold')
    return finish(t, theme, rng)


def holding_cell(theme, rng, v):
    t, p = piece(), P(theme, v)
    t.slab(B(0, 28, 63, 31), 'dark_steel', 5, bevel=0.5)
    bar = ['dark_steel', 'steel', 'enamel_b'][v]
    if v == 2:
        t.slab(B(8, 2, 40, 14, 2), 'canvas_w', 6, bevel=1)
        t.slab(B(10, 4, 18, 12, 2), 'paper', 8, profile='dome')
    for x in range(3, 64, 6):
        t.slab(B(x - 1, 22, x + 1, 37, 1), bar, 26, profile='cyl')
    t.slab(B(0, 22, 63, 24), 'dark_steel', 27, bevel=0.3)
    run(t)
    if v == 1:
        t.slab(B(16, 26, 22, 34), 'brass', 22, bevel=0.3)
    return finish(t, theme, rng)


def evidence_locker(theme, rng, v):
    t, p = piece(), P(theme, v)
    shell = [p.enamel, 'enamel_grey', 'dark_steel'][v]
    wall_run(t, p, 2, 30, 22, shell)
    for c_ in range(4):
        x0 = c_ * 16
        t.mark(B(x0, 2, x0, 30), -2)
        for r_ in range(2):
            y0 = 3 + r_ * 14
            t.mark(B(x0 + 1, y0 + 12, x0 + 15, y0 + 12), -2)
            t.slab(B(x0 + 4, y0 + 3, x0 + 11, y0 + 6), 'paper' if (c_ + r_ + v) % 3 else 'paint_y', 0.8)
            t.slab(D(x0 + 13, y0 + 8, 1.2), 'chrome', 0.8)
    return finish(t, theme, rng)


def notice_board(theme, rng, v):
    t, p = piece(), P(theme, v)
    fr = p.wood if v != 2 else p.metal
    wall_run(t, p, 2, 40, 10, fr)
    cork = B(2, 4, 61, 38)
    t.paint(cork, 'kraft')
    t.mark(cork & speckle(rng.int(0, 1 << 20), 0.12), -1)
    cols = ['paper', 'paper', 'paint_y', 'laminate_g', 'paint_w', 'blossom']
    for k in range(7):
        x, y = rng.int(4, 50), rng.int(6, 28)
        w, h = rng.int(8, 13), rng.int(8, 11)
        n = B(x, y, x + w, y + h)
        t.slab(n, rng.pick(cols), 0.6, bevel=0)
        for j in range(2, h - 1, 3):
            t.mark(B(x + 2, y + j, x + w - 2 - (j % 4), y + j), -1)
        t.slab(D(x + w / 2, y + 1, 1), rng.pick(['plastic_r', 'container_b', 'paint_y']), 1, profile='dome')
    return finish(t, theme, rng)


def service_window(theme, rng, v):
    t, p = piece(), P(theme, v)
    body(t, 0, 30, 63, 54, 11, p.body, p.top, r=1)
    run(t)
    t.slab(B(0, 8, 8, 30) | B(55, 8, 63, 30), p.body, 26, bevel=1)
    t.slab(B(8, 8, 55, 12), p.body, 26, bevel=1)
    t.slab(B(9, 26, 54, 29), 'glass', 22, bevel=0.3)
    t.slab(B(22, 14, 41, 22), 'graphite', 24, bevel=0.5)
    lit(t, p, rng, B(24, 16, 39, 20), 'neon_amber' if theme != 'rich' else 'neon_cyan')
    t.slab(B(12, 36, 24, 46), 'paper', 0.6)
    t.slab(D(48, 41, 3), 'dark_steel', 2, profile='cyl')
    return finish(t, theme, rng)


def waiting_bench(theme, rng, v):
    t, p = piece(), P(theme, v)
    t.slab(B(0, 38, 63, 41), p.metal, 4, bevel=0.5)
    run(t)
    seat_m = [p.enamel, 'plastic_b' if theme != 'rich' else 'leather_k', 'wood_light' if theme != 'slum' else 'wood'][v]
    for k in range(3):
        x0 = 1 + k * 21
        t.slab(B(x0, 14, x0 + 19, 21, 3), seat_m, 13, bevel=1.2)
        t.slab(B(x0, 21, x0 + 19, 44, 4), seat_m, 7, bevel=1.5)
        if p.poor and k == (v + 1) % 3:
            t.mark(cracks(rng.int(0, 1 << 20), 1, 10, wrap=False, region=B(x0, 21, x0 + 19, 44)) & B(x0, 21, x0 + 19, 44), -2)
    return finish(t, theme, rng)


def parcel_shelf(theme, rng, v):
    t, p = piece(), P(theme, v)
    shelf_run(t, p, 4, 40, 4, p.metal if v != 1 else p.wood, 'dark_steel' if v != 1 else p.wood)
    x = 1
    while x < 60:
        w = rng.int(9, 16)
        if x + w > 62:
            w = 62 - x
        if w < 5:
            break
        d = rng.int(14, 30)
        m = B(x, 8, x + w - 1, 8 + d, 0.5)
        t.slab(m, rng.pick(['kraft', 'kraft', 'paper', 'container_b' if theme != 'rural' else 'kraft']), rng.range(6, 12), bevel=0.8)
        t.mark(B(x + w // 2 - 1, 8, x + w // 2, 8 + d) & m, 1)
        if rng.chance(0.5):
            t.slab(B(x + 2, 10, x + 6, 13), 'paint_w', 0.4)
        x += w + 1
    return finish(t, theme, rng)


def mail_sorter(theme, rng, v):
    t, p = piece(), P(theme, v)
    m = wall_run(t, p, 2, 40, 18, p.wood if v != 1 else p.enamel)
    for r_ in range(4):
        for c_ in range(8):
            x0, y0 = 1 + c_ * 8, 4 + r_ * 9
            cell = B(x0, y0, x0 + 6, y0 + 7)
            t.carve(cell, 2)
            t.mark(cell, -1)
            if rng.chance(0.6):
                t.slab(B(x0 + 1, y0 + 2, x0 + 5, y0 + 6), rng.pick(['paper', 'paper', 'kraft', 'paint_w']), 1.5, bevel=0)
    return finish(t, theme, rng)


def parcel_trolley(theme, rng, v):
    t, p = piece(), P(theme, v)
    base = B(10, 12, 53, 52, 2)
    t.slab(base, p.metal if v != 1 else 'enamel_b', 4, bevel=0.8)
    t.slab(B(8, 8, 55, 11, 1), p.metal, 16, bevel=0.4)
    for x, y in ((12, 54), (51, 54), (12, 12), (51, 12)):
        wheel(t, x, y, 2.5)
    for k, (x0, y0, x1, y1) in enumerate(((13, 16, 33, 32), (34, 16, 50, 30), (15, 34, 46, 49), (20, 20, 40, 40))):
        if k == 3 and v == 2:
            continue
        m = B(x0, y0, x1, y1, 0.5)
        t.slab(m, ['kraft', 'container_b', 'paper'][(k + v) % 3] if v else ('kraft' if k % 2 == 0 else 'paper'), 7 + (k == 3) * 7, bevel=0.8)
        t.mark(B((x0 + x1) // 2 - 1, y0, (x0 + x1) // 2, y1) & m, 1)
    return finish(t, theme, rng)


def key_rack(theme, rng, v):
    t, p = piece(), P(theme, v)
    wall_run(t, p, 2, 30, 10, p.wood if v != 1 else p.metal)
    t.slab(B(4, 4, 59, 28), 'wood_dark' if p.rich else p.top, 1, bevel=0.5)
    for r_ in range(2):
        for c_ in range(7):
            x, y = 7 + c_ * 8, 7 + r_ * 11
            t.slab(D(x, y, 1), 'brass', 2, profile='dome')
            if rng.chance(0.75):
                t.slab(L(x, y, x, y + 5, 1.4), 'brass', 1.5, bevel=0)
                t.slab(B(x - 2, y + 5, x + 2, y + 8, 1), ['plastic_r', 'container_b', 'paint_y', 'fabric_g'][(c_ + r_ + v) % 4], 1.5, bevel=0)
    return finish(t, theme, rng)


def luggage_cart(theme, rng, v):
    t, p = piece(), P(theme, v)
    frame = 'brass' if theme in ('rich', 'mid') else p.metal
    t.slab(B(8, 18, 55, 54, 2), 'carpet_red' if theme != 'slum' else 'fabric_g', 4, bevel=0.6)
    t.paint(B(8, 18, 55, 54, 2) & ~B(10, 20, 53, 52), frame)
    for x, y in ((10, 55), (53, 55)):
        wheel(t, x, y, 2.5)
    t.slab(L(10, 18, 10, 10, 2.5) | L(53, 18, 53, 10, 2.5) | L(10, 10, 53, 10, 2.5), frame, 26, bevel=0, obj=True)
    cases = [((13, 22, 34, 50), 'leather_br'), ((36, 24, 51, 44), 'graphite'), ((18, 30, 44, 44), 'enamel_teal')]
    for k, ((x0, y0, x1, y1), mat) in enumerate(cases[: 2 + (v != 2)]):
        m = B(x0, y0, x1, y1, 2)
        t.slab(m, [mat, 'leather_ox', 'alu'][(k + v) % 3], 8 + k * 4, bevel=1)
        t.slab(B((x0 + x1) // 2 - 3, y0 + 1, (x0 + x1) // 2 + 3, y0 + 3), 'dark_steel', 1)
    return finish(t, theme, rng)


def lobby_sofa(theme, rng, v):
    t, p = piece(), P(theme, v)
    mat = ['leather_k', 'velvet_teal', 'fabric_cream'][v] if theme in ('rich', 'mid') else p.uph
    sofa_form(t, p, rng, 2, 61, 2, mat, arms=True, back_h=14, y0=10, y1=50, tuft=(v == 0))
    if p.rich:
        t.slab(B(4, 50, 8, 54) | B(55, 50, 59, 54), 'gold', 3, bevel=0.3)
    return finish(t, theme, rng)


def capsule_bed(theme, rng, v):
    t, p = piece(), P(theme, v)
    shell = ['plastic_w', 'enamel_cream', 'graphite'][v] if theme != 'slum' else ['enamel_grey', 'plastic_w', 'enamel_teal'][v]
    m = B(0, 6, 63, 58, 6)
    t.slab(m, shell, 22, bevel=2.5)
    run(t)
    t.mark(B(0, 10, 63, 10) | B(0, 54, 63, 54), -1)
    hatch = B(44, 14, 60, 50, 4)
    t.carve(hatch, 4)
    t.paint(hatch, 'linen')
    t.slab(B(48, 18, 58, 26, 3), 'paper', 3, profile='dome')
    t.paint(B(46, 30, 59, 48, 3), p.uph if theme != 'slum' else 'fabric_g')
    lit(t, p, rng, B(42, 18, 43, 46), 'lamp_cold' if v != 2 else p.glow)
    t.slab(B(8, 18, 26, 26, 2), 'dark_steel', 1)
    t.emit(D(12, 22, 1), 'neon_green')
    return finish(t, theme, rng)


def treadmill(theme, rng, v):
    t, p = piece(), P(theme, v)
    frame = ['graphite', 'enamel_grey', 'plastic_w'][v]
    m = B(14, 12, 49, 60, 3)
    t.slab(m, frame, 6, bevel=1)
    belt = B(19, 20, 44, 58)
    t.paint(belt, 'rubber')
    t.h[belt] -= 1
    t.mark(belt & ((YY % 6) == 0), -1)
    t.slab(L(14, 12, 14, 20, 3) | L(49, 12, 49, 20, 3), p.metal, 18, bevel=0.3)
    t.slab(B(14, 6, 49, 14, 3), frame, 22, bevel=1)
    lit(t, p, rng, B(22, 8, 41, 11), 'screen_glow' if v != 1 else 'neon_green')
    return finish(t, theme, rng)


def barbell(t, x0, x1, y, h, plate='rubber'):
    t.slab(L(x0, y, x1, y, 2), 'chrome', h, bevel=0)
    for x in (x0 + 4, x1 - 4):
        t.slab(B(x - 2, y - 8, x + 2, y + 8, 1.5), plate, h + 2, bevel=0.6)
        t.slab(B(x + (3 if x > 32 else -5), y - 6, x + (5 if x > 32 else -3), y + 6, 1), plate, h + 1, bevel=0.6)


def weight_bench(theme, rng, v):
    t, p = piece(), P(theme, v)
    pad = ['vinyl_k', 'vinyl_r', 'enamel_b'][v] if theme != 'rich' else ['leather_k', 'leather_br', 'graphite'][v]
    t.slab(L(32, 14, 32, 58, 6), p.metal, 4, bevel=0.5)
    cushion(t, B(24, 20, 39, 58, 4), pad, 9)
    t.slab(D(20, 14, 3) | D(43, 14, 3), p.metal, 18, profile='cyl')
    barbell(t, 2, 61, 12, 20, ['rubber', 'plastic_b', 'chrome'][v])
    tape(t, p, rng, B(24, 20, 39, 58), 2)
    return finish(t, theme, rng)


def squat_rack(theme, rng, v):
    t, p = piece(), P(theme, v)
    frame = ['graphite', 'enamel_o', 'alu'][v]
    for x, y in ((10, 12), (50, 12), (10, 50), (50, 50)):
        t.slab(B(x - 3, y - 3, x + 3, y + 3), frame, 28, bevel=0.5)
        t.mark(B(x - 2, y - 2, x + 2, y + 2) & ((YY % 3) == 0), -1)
    t.slab(L(10, 12, 50, 12, 3) | L(10, 50, 50, 50, 3), frame, 28, bevel=0)
    t.slab(B(12, 20, 51, 44), 'rubber', 1)
    barbell(t, 0, 63, 22, 18, ['rubber', 'plastic_r', 'paint_y'][v])
    run(t)
    return finish(t, theme, rng)


def dumbbell_rack(theme, rng, v):
    t, p = piece(), P(theme, v)
    shelf_run(t, p, 6, 40, 8, p.metal if v != 2 else 'graphite', 'dark_steel')
    for row, y in enumerate((14, 30)):
        for k in range(5):
            x = 2 + k * 12
            hd = [['chrome', 'rubber'], ['rubber', 'plastic_b'], ['plastic_r', 'chrome']][v][row]
            r = 3 + row + (k % 2) * 0.5
            t.slab(L(x + 2, y, x + 9, y, 2), 'chrome', 10, bevel=0)
            t.slab(D(x + 2, y, r), hd, 11, profile='dome')
            t.slab(D(x + 9, y, r), hd, 11, profile='dome')
    return finish(t, theme, rng)


def locker(theme, rng, v):
    t, p = piece(), P(theme, v)
    shell = [p.enamel, 'enamel_teal' if theme != 'rich' else 'graphite', 'enamel_grey' if theme != 'rural' else 'wood'][v]
    wall_run(t, p, 2, 24, 26, shell)
    for c_ in range(4):
        x0 = c_ * 16
        t.mark(B(x0, 2, x0, 24), -2)
        for j in range(3):
            t.mark(B(x0 + 4, 5 + j * 2, x0 + 11, 5 + j * 2), -1)
        t.slab(B(x0 + 12, 13, x0 + 13, 19), 'chrome', 0.8)
        if p.poor and (c_ + v) % 3 == 0:
            t.mark(B(x0 + 1, 3, x0 + 15, 23) & blotches(rng.int(0, 1 << 20), 0.4), -1)
    t.slab(B(0, 32, 63, 38), 'wood_light' if theme != 'industry' else 'dark_steel', 6, bevel=0.6)
    return finish(t, theme, rng)


def shoe_shelf(theme, rng, v):
    t, p = piece(), P(theme, v)
    m = body(t, 0, 6, 63, 28, 12, p.wood if v != 2 else p.body, None, r=1)
    run(t)
    for c_ in range(5):
        x0 = 1 + c_ * 13
        cub = B(x0, 8, x0 + 11, 26)
        t.carve(cub, 4)
        t.mark(cub, -1)
        if rng.chance(0.8):
            c = rng.pick(['paint_w', 'rubber', 'fabric_b', 'leather_br', 'canvas_w'])
            t.slab(D(x0 + 3, 17, 2.4, 6), c, 3, profile='dome')
            t.slab(D(x0 + 8, 17, 2.4, 6), c, 3, profile='dome')
    return finish(t, theme, rng)


def barber_chair(theme, rng, v):
    t, p = piece(), P(theme, v)
    seat_m = ['leather_ox', 'leather_k', 'vinyl_teal'][v] if theme != 'slum' else ['vinyl_r', 'vinyl_teal', 'vinyl_k'][v]
    t.slab(D(32, 36, 15), p.metal, 3, bevel=1)
    t.slab(B(20, 8, 43, 16, 4), seat_m, 20, bevel=1.5)
    t.slab(B(26, 4, 37, 9, 3), seat_m, 22, bevel=1)
    t.slab(B(16, 18, 21, 42, 2) | B(42, 18, 47, 42, 2), 'chrome', 15, bevel=0.6)
    cushion(t, B(21, 16, 42, 42, 4), seat_m, 13)
    t.slab(B(24, 46, 39, 54, 1), 'chrome', 5, bevel=0.5)
    tape(t, p, rng, B(21, 16, 42, 42), 2)
    return finish(t, theme, rng)


def salon_sink(theme, rng, v):
    t, p = piece(), P(theme, v)
    body(t, 6, 6, 57, 34, 14, 'graphite' if v != 1 else p.body, 'graphite' if v != 1 else p.top, r=2)
    t.slab(D(32, 24, 14, 10), 'plastic_w' if not p.rich else 'paint_w', 3, bevel=1.5)
    t.carve(D(32, 24, 10, 7), 3)
    t.mark(D(32, 26, 2), -2)
    t.slab(L(32, 10, 32, 16, 2.4), 'chrome', 6, bevel=0)
    t.slab(D(32, 10, 2), 'chrome', 6, profile='dome')
    chair_basic(t, p, 20, 38, 43, 60, ['leather_k', 'vinyl_teal', 'fabric_grey'][v], 'graphite', back=False)
    return finish(t, theme, rng)


def salon_mirror(theme, rng, v):
    t, p = piece(), P(theme, v)
    wall_run(t, p, 2, 34, 10, p.body)
    glass = B(4, 4, 59, 26, 2 if v == 1 else 0)
    t.paint(glass, 'mirror')
    t.mark(L(10, 22, 22, 6, 2) & glass, 2)
    t.mark(L(34, 24, 46, 8, 1) & glass, 1)
    if v != 2:
        for k in range(8):
            lit(t, p, rng, D(5 + k * 7.6, 3, 1.5), 'lamp')
    else:
        lit(t, p, rng, B(4, 27, 59, 27), 'lamp_cold')
    t.slab(B(0, 30, 63, 38), p.top, 2)
    for k in range(5):
        t.slab(D(8 + k * 11, 34, 2.2), ['plastic_w', 'enamel_teal', 'blossom', 'paint_y', 'container_b'][(k + v) % 5], 4, profile='cyl')
    return finish(t, theme, rng)


def hair_dryer(theme, rng, v):
    t, p = piece(), P(theme, v)
    seat_m = ['vinyl_teal', 'leather_k', 'fabric_mustard'][v]
    chair_basic(t, p, 16, 22, 47, 54, seat_m, 'chrome')
    t.slab(L(32, 22, 32, 8, 2.5), 'chrome', 20, bevel=0)
    hood = D(32, 18, 14, 11)
    t.slab(hood, ['plastic_w', 'blossom', 'enamel_cream'][v], 24, profile='dome')
    t.mark(D(32, 18, 10, 7) & ~D(32, 18, 9, 6), -1)
    lit(t, p, rng, D(40, 12, 1.2), 'neon_amber')
    return finish(t, theme, rng)


def washer_form(t, p, rng, shell, door, panel_glow):
    body(t, 8, 8, 55, 56, 16, shell, shell, r=3)
    t.slab(B(10, 10, 53, 18, 1), shell, 1)
    t.mark(B(10, 18, 53, 18), -1)
    lit(t, p, rng, B(40, 12, 50, 15), panel_glow)
    t.slab(D(18, 14, 2), 'chrome', 1, profile='dome')
    t.slab(D(32, 37, 15), 'chrome', 2, bevel=0.6)
    t.paint(D(32, 37, 12), door)
    t.mark(L(24, 34, 32, 28, 2) & D(32, 37, 12), 2)


def washing_machine(theme, rng, v):
    t, p = piece(), P(theme, v)
    shell = ['plastic_w', 'enamel_grey', 'enamel_cream'][v] if theme != 'industry' else 'enamel_grey'
    washer_form(t, p, rng, shell, 'glass', 'screen_glow')
    t.mark(D(32, 39, 10) & ~D(32, 39, 9), -1)
    if theme in ('slum', 'mid') and rng.chance(0.5):
        t.paint(D(32, 41, 8, 5) & D(32, 37, 12), 'foam')
    return finish(t, theme, rng)


def dryer(theme, rng, v):
    t, p = piece(), P(theme, v)
    shell = ['enamel_grey', 'plastic_w', 'enamel_b'][v]
    washer_form(t, p, rng, shell, 'dark_steel', 'neon_amber')
    t.mark(D(32, 37, 12) & (((XX + YY) % 4) == 0), 1)
    t.slab(B(26, 50, 38, 53), 'dark_steel', 1)
    return finish(t, theme, rng)


def folding_table(theme, rng, v):
    t, p = piece(), P(theme, v)
    legs(t, 6, 14, 57, 48, p.metal, r=1.5, h=7)
    body(t, 2, 10, 61, 52, 9, ['laminate_w', p.top, 'plastic_w'][v], ['laminate_w', p.top, 'plastic_w'][v], r=1)
    run(t)
    cols = ['paint_w', 'fabric_b', 'fabric_grey', 'blossom', 'fabric_mustard', 'linen']
    for k in range(4):
        x = 5 + k * 14
        n = rng.int(1, 3)
        for j in range(n):
            c = rng.pick(cols)
            t.slab(B(x, 16 + j, x + 11, 28 + j, 1), c, 2, bevel=0.6)
            t.mark(B(x, 22 + j, x + 11, 22 + j), -1)
    t.slab(B(10, 34, 40, 48, 3), 'plastic_b' if v != 1 else 'linen', 7, bevel=1)
    t.carve(B(13, 37, 37, 45, 2), 4)
    t.paint(B(13, 37, 37, 45, 2) & blotches(rng.int(0, 1 << 20), 0.6), rng.pick(cols))
    return finish(t, theme, rng)


def arcade_cabinet(theme, rng, v):
    t, p = piece(), P(theme, v)
    shell = ['velvet_v', 'graphite', 'enamel_b'][v]
    body(t, 12, 6, 51, 58, 22, shell, shell, r=2)
    t.slab(B(15, 9, 48, 14, 1), 'ink', 1)
    lit(t, p, rng, B(16, 10, 47, 13), ['neon_pink', 'neon_cyan', 'neon_amber'][v])
    t.slab(B(15, 16, 48, 36, 1), 'ink', 0.5)
    lit(t, p, rng, B(17, 18, 46, 34), 'screen_glow')
    t.mark(B(17, 18, 46, 34) & ((YY % 2) == 0), -1)
    t.mark(D(24 + v * 6, 26, 3) & B(17, 18, 46, 34), 2)
    t.slab(B(12, 40, 51, 54, 1), 'dark_steel', 1)
    t.slab(D(22, 47, 2.5), 'plastic_r' if v != 1 else 'paint_y', 4, profile='dome')
    for k, c in enumerate(('paint_y', 'container_b', 'fabric_g', 'paint_w')):
        t.slab(D(32 + k * 4, 45 + (k % 2) * 3, 1.5), c, 2, profile='dome')
    return finish(t, theme, rng)


def pachinko_machine(theme, rng, v):
    t, p = piece(), P(theme, v)
    shell = ['chrome', 'gold', 'velvet_v'][v]
    body(t, 10, 4, 53, 58, 22, shell, shell, r=2)
    face = B(14, 8, 49, 44, 3)
    t.paint(face, 'glass')
    pins = face & ((XX % 4) == 0) & ((YY % 4) == ((XX // 4) % 2) * 2)
    t.paint(pins, 'brass')
    t.emit(D(32, 24, 5) & face, ['neon_pink', 'neon_cyan', 'neon_amber'][v])
    lit(t, p, rng, face & ~B(16, 10, 47, 42, 2), ['neon_cyan', 'neon_pink', 'neon_green'][v])
    for k in range(6):
        t.slab(D(18 + k * 5, 52, 2), 'chrome', 2, profile='dome')
    t.slab(B(15, 47, 48, 50), 'dark_steel', 1)
    return finish(t, theme, rng)


def claw_machine(theme, rng, v):
    t, p = piece(), P(theme, v)
    shell = ['enamel_teal', 'blossom', 'plastic_w'][v]
    m = body(t, 6, 6, 57, 57, 24, shell, 'glass', r=3, inset=4)
    inside = B(10, 10, 53, 53)
    t.h[inside] -= 6
    toys = ['blossom', 'paint_y', 'fabric_b', 'fabric_g', 'paint_w', 'container_o', 'velvet_v']
    for k in range(9):
        x, y = rng.int(15, 48), rng.int(22, 48)
        t.slab(D(x, y, 4.5), rng.pick(toys), 3, profile='dome', on=18)
        t.mark(D(x - 1.5, y - 1.5, 0.8) | D(x + 1.5, y - 1.5, 0.8), -2)
    t.slab(L(10, 16, 53, 16, 2), p.metal, 3, bevel=0, on=22)
    t.slab(D(36, 16, 3), 'chrome', 4, profile='dome', on=22)
    t.mark(L(12, 50, 30, 12, 1) & inside, 2)
    lit(t, p, rng, m & ~B(8, 8, 55, 55, 3), ['neon_pink', 'neon_cyan', 'neon_violet'][v])
    return finish(t, theme, rng)


# ================================================================================================ industry
def pallet(t, x0, y0, x1, y1, h, mat='wood_light'):
    m = B(x0, y0, x1, y1)
    t.slab(m, mat, h, bevel=0.6)
    t.mark(m & ((((XX - x0) % 7) == 6)), -2)
    return m


def pallet_rack(theme, rng, v):
    t, p = piece(), P(theme, v)
    up = ['enamel_o', 'enamel_b', 'hazard_y'][v] if theme != 'rich' else ['graphite', 'alu', 'enamel_b'][v]
    for x in (1, 62):
        t.slab(B(x - 1, 4, x + 1, 44), up, 30, bevel=0.3)
    t.slab(B(0, 4, 63, 6) | B(0, 42, 63, 44), up, 26, bevel=0.3)
    run(t)
    pallet(t, 4, 8, 30, 40, 4)
    pallet(t, 34, 8, 59, 40, 4)
    kind = v % 2
    t.slab(B(5, 10, 29, 38, 1), 'kraft' if v != 2 else 'container_b', 12, bevel=0.8)
    t.mark(B(16, 10, 18, 38), 1)
    if kind == 0:
        for x, y in ((41, 16), (52, 16), (41, 31), (52, 31)):
            t.slab(D(x, y, 5.5), rng.pick(['container_b', 'enamel_o', 'enamel_g']), 14, bevel=1)
            t.mark(D(x, y, 3.5) & ~D(x, y, 2.8), -1)
    else:
        t.slab(B(35, 10, 58, 38, 1), 'plastic_w', 13, bevel=0.6)
        t.mark(B(35, 10, 58, 38) & (((XX + YY) % 5) == 0), 1)
    return finish(t, theme, rng)


def pallet_stack(theme, rng, v):
    t, p = piece(), P(theme, v)
    n = 3 + v
    for k in range(n):
        dx, dy = rng.int(-2, 2), rng.int(-2, 2)
        pallet(t, 6 + dx, 8 + dy, 57 + dx, 55 + dy, 3, ['wood_light', 'wood', 'enamel_b'][v if v < 2 else (k % 2) * 2])
    t.mark(B(6, 8, 57, 55) & ((YY % 16) < 2), -1)
    return finish(t, theme, rng)


def conveyor(theme, rng, v):
    t, p = piece(), P(theme, v)
    frame = ['enamel_grey', 'enamel_g', 'enamel_b'][v] if theme != 'rich' else 'graphite'
    t.slab(B(0, 16, 63, 48), frame, 10, bevel=0.6)
    belt = B(0, 20, 63, 44)
    t.paint(belt, 'rubber')
    t.mark(belt & ((XX % 6) == 0), -1)
    t.mark(belt & ((XX % 6) == 1), 1)
    t.slab(B(0, 16, 63, 19) | B(0, 45, 63, 48), frame, 12, bevel=0.4)
    run(t)
    for k in range(2):
        x = rng.int(4, 22) + k * 30
        m = B(x, 23, x + rng.int(12, 18), 41, 0.5)
        t.slab(m, rng.pick(['kraft', 'kraft', 'container_b', 'plastic_w']), 9, bevel=0.6)
        t.mark(B(x, 31, x + 18, 32) & m, 1)
    t.paint(B(0, 49, 63, 51) & ((((XX + YY) // 3) % 2) == 0), 'hazard_k')
    return finish(t, theme, rng)


def parts_bin(theme, rng, v):
    t, p = piece(), P(theme, v)
    shelf_run(t, p, 4, 40, 6, p.metal, 'dark_steel')
    col = ['container_b', 'enamel_o', 'paint_y'][v]
    for r_ in range(3):
        for c_ in range(5):
            x0, y0 = 1 + c_ * 12 + r_ % 2, 6 + r_ * 11
            m = B(x0, y0, x0 + 10, y0 + 9, 1)
            t.slab(m, col, 6 + r_ * 2, bevel=0.6)
            t.carve(B(x0 + 2, y0 + 3, x0 + 8, y0 + 8), 2)
            t.paint(B(x0 + 2, y0 + 3, x0 + 8, y0 + 8) & speckle(rng.int(0, 1 << 20), 0.5), rng.pick(['brass', 'chrome', 'dark_steel', 'copper']))
            t.slab(B(x0 + 3, y0, x0 + 7, y0 + 1), 'paper', 0.5)
    return finish(t, theme, rng)


def lathe(theme, rng, v):
    t, p = piece(), P(theme, v)
    paint_ = ['enamel_g', 'enamel_b', 'enamel_grey'][v]
    body(t, 0, 20, 63, 50, 12, paint_, 'steel', r=1)
    run(t)
    t.slab(B(0, 18, 18, 52, 2), paint_, 20, bevel=1)              # headstock
    t.slab(D(22, 34, 8), 'chrome', 18, profile='cyl')               # chuck
    t.mark(D(22, 34, 8) & ~D(22, 34, 6), -1)
    t.slab(L(26, 34, 50, 34, 4), 'steel', 17, profile='dome')       # work
    t.slab(B(50, 26, 60, 42, 1), paint_, 18, bevel=0.6)             # tailstock
    t.slab(B(32, 38, 44, 48, 1), 'dark_steel', 15, bevel=0.5)       # carriage
    t.paint(speckle(rng.int(0, 1 << 20), 0.06) & B(24, 40, 60, 50), 'brass')
    lit(t, p, rng, B(4, 22, 8, 24), 'neon_green')
    return finish(t, theme, rng)


def mill(theme, rng, v):
    t, p = piece(), P(theme, v)
    paint_ = ['enamel_g', 'enamel_o', 'enamel_cream'][v]
    t.slab(B(16, 4, 47, 20, 3), paint_, 30, bevel=1.5)            # column and head
    t.slab(D(32, 24, 6), 'chrome', 26, profile='cyl')               # spindle
    body(t, 6, 28, 57, 50, 14, paint_, 'steel', r=1)               # table
    t.mark(B(8, 30, 55, 48) & ((YY % 5) == 0), -2)
    t.slab(B(24, 32, 40, 44, 1), 'dark_steel', 6, bevel=0.6)
    t.slab(D(6, 40, 4) | D(57, 40, 4), 'chrome', 13, profile='dome')
    t.slab(B(48, 8, 56, 16, 1), 'graphite', 26, bevel=0.5)
    lit(t, p, rng, B(50, 10, 54, 13), 'neon_amber')
    return finish(t, theme, rng)


def scrap_pile(theme, rng, v):
    t, p = piece(), P(theme, v)
    mats = ['rust', 'dark_steel', 'steel', 'rust', 'container_g', 'copper', 'rubber', 'container_b']
    heap = D(32, 34, 26, 21)
    t.slab(heap, 'rust' if v != 1 else 'dark_steel', 10, profile='dome')
    t.mark(heap & speckle(rng.int(0, 1 << 20), 0.15), -1)
    for k in range(16 + v * 3):
        a = rng.range(0, 2 * math.pi)
        d = rng.range(0, 18)
        x, y = 32 + math.cos(a) * d, 34 + math.sin(a) * d * 0.8
        s = rng.range(5, 10)
        b = rng.range(0, math.pi)
        pts = [(x + math.cos(b + j * 2.1 + rng.range(-0.4, 0.4)) * s, y + math.sin(b + j * 2.1 + rng.range(-0.4, 0.4)) * s * 0.7) for j in range(3)]
        t.slab(Tile.poly_mask(pts) & heap, rng.pick(mats), 1.5 + (18 - d) * 0.15, bevel=0.6)
    for k in range(3):
        a = rng.range(0, 2 * math.pi)
        t.slab(L(32, 34, 32 + math.cos(a) * 28, 34 + math.sin(a) * 24, 2.5), 'steel', 3, bevel=0)
    t.slab(D(22 + v * 8, 40, 5) & ~D(22 + v * 8, 40, 2.5), 'rubber', 3, profile='dome')
    return finish(t, theme, rng)


def baler(theme, rng, v):
    t, p = piece(), P(theme, v)
    paint_ = ['enamel_o', 'enamel_b', 'hazard_y'][v]
    body(t, 4, 4, 59, 40, 26, paint_, 'dark_steel', r=2)
    t.slab(B(16, 10, 47, 34, 1), 'dark_steel', 3)
    t.slab(D(32, 22, 6), 'chrome', 4, profile='cyl')
    haz = B(4, 38, 59, 40) & ((((XX + YY) // 3) % 2) == 0)
    t.paint(B(4, 38, 59, 40), 'hazard_y')
    t.paint(haz, 'hazard_k')
    bale = B(14, 44, 49, 60, 1)
    t.slab(bale, ['rust', 'container_b', 'steel'][v], 10, bevel=0.6)
    t.paint(bale & blotches(rng.int(0, 1 << 20), 0.5), rng.pick(['steel', 'container_b', 'dark_steel']))
    t.slab((B(21, 44, 22, 60) | B(41, 44, 42, 60)) & bale, 'chrome', 10.5, bevel=0)
    lit(t, p, rng, B(50, 8, 55, 11), 'neon_amber')
    return finish(t, theme, rng)


def shredder(theme, rng, v):
    t, p = piece(), P(theme, v)
    paint_ = ['enamel_g', 'enamel_o', 'graphite'][v]
    m = body(t, 4, 4, 59, 59, 24, paint_, None, r=3)
    hop = B(10, 10, 53, 53, 2)
    t.carve(hop, 8)
    t.paint(hop, 'dark_steel')
    t.mark(hop & ~B(14, 14, 49, 49, 2), 1)
    for k in range(2):
        y = 26 + k * 12
        t.slab(B(14, y - 4, 49, y + 4, 2), 'steel', 2, profile='dome')
        t.mark(B(14, y - 4, 49, y + 4) & ((XX % 5) < 2), -2)
    t.paint(m & ~B(6, 6, 57, 57, 3) & ((((XX + YY) // 4) % 2) == 0), 'hazard_y')
    t.paint(speckle(rng.int(0, 1 << 20), 0.08) & hop, 'rust')
    return finish(t, theme, rng)


def press_machine(theme, rng, v):
    t, p = piece(), P(theme, v)
    paint_ = ['enamel_b', 'enamel_g', 'enamel_grey'][v]
    t.slab(B(2, 8, 13, 56, 2) | B(50, 8, 61, 56, 2), paint_, 30, bevel=1)
    t.slab(B(2, 6, 61, 18, 2), paint_, 32, bevel=1)
    body(t, 14, 30, 49, 54, 10, 'dark_steel', 'steel', r=1)
    t.slab(B(16, 18, 47, 28, 1), 'chrome', 24, bevel=0.5)
    t.paint(B(14, 54, 49, 56) & ((((XX + YY) // 3) % 2) == 0), 'hazard_y')
    t.ground('hazard_y', B(14, 57, 49, 59))
    t.paint(B(14, 57, 49, 59) & ((((XX + YY) // 3) % 2) == 0), 'hazard_k')
    lit(t, p, rng, D(56, 12, 2), 'neon_amber')
    lit(t, p, rng, D(8, 12, 2), 'neon_green')
    return finish(t, theme, rng)


# ================================================================================================ homes
def bed_form(t, p, rng, x0, x1, pillows, blanket, frame, y0=4, y1=60):
    t.slab(B(x0, y0, x1, y0 + 6, 1), frame, 14, bevel=1)
    t.slab(B(x0, y0, x1, y1, 2), frame, 6, bevel=1)
    mat_ = B(x0 + 2, y0 + 5, x1 - 2, y1 - 2, 3)
    t.slab(mat_, 'linen', 3, bevel=1.5)
    w = (x1 - x0 - 6) / pillows
    for k in range(pillows):
        a = x0 + 3 + k * w
        t.slab(B(a + 1, y0 + 8, a + w - 1, y0 + 17, 4), 'paper' if p.theme != 'slum' else 'linen', 3, profile='dome')
    bl = B(x0 + 2, y0 + 22, x1 - 2, y1 - 2, 3)
    t.paint(bl, blanket)
    t.h[bl] += 1
    t.slab(Tile.poly_mask([(x1 - 2, y0 + 22), (x1 - 14, y0 + 22), (x1 - 2, y0 + 34)]) & bl, 'linen', 1.5)
    t.mark(bl & (YY == y0 + 22), 1)
    tape(t, p, rng, bl, 0)


def blanket_of(p):
    return {'rich': ['fabric_cream', 'leather_k', 'velvet_teal'], 'mid': ['fabric_b', 'fabric_grey', 'fabric_mustard'],
            'slum': ['fabric_g', 'velvet_v', 'fabric_o'], 'rural': ['fabric_indigo', 'fabric_o', 'linen'],
            'industry': ['fabric_grey', 'olive_d', 'canvas_bag']}[p.theme][p.v % 3].replace('leather_k', 'graphite')


def bed_single(theme, rng, v):
    t, p = piece(), P(theme, v)
    bed_form(t, p, rng, 15, 48, 1, blanket_of(p), p.wood if v != 2 else p.metal)
    return finish(t, theme, rng)


def bed_double(theme, rng, v):
    t, p = piece(), P(theme, v)
    bed_form(t, p, rng, 3, 60, 2, blanket_of(p), p.wood if v != 2 else ('graphite' if p.rich else p.metal))
    if p.rich:
        t.paint(B(3, 4, 60, 10, 1) & ~B(5, 6, 58, 8), 'accent')
    return finish(t, theme, rng)


def bunk_bed(theme, rng, v):
    t, p = piece(), P(theme, v)
    frame = [p.metal, p.wood, 'enamel_b' if theme != 'rich' else 'graphite'][v]
    bed_form(t, p, rng, 14, 49, 1, blanket_of(p), frame)
    for x, y in ((14, 4), (49, 4), (14, 60), (49, 60)):
        t.slab(B(x - 2, y - 2, x + 2, y + 2), frame, 26, bevel=0.4)
    t.slab(L(14, 4, 14, 60, 2.5) | L(49, 4, 49, 60, 2.5), frame, 24, bevel=0)
    for k in range(4):
        t.slab(L(49, 30 + k * 6, 56, 30 + k * 6, 2), frame, 12, bevel=0)
    t.slab(L(56, 28, 56, 52, 2.5), frame, 14, bevel=0)
    return finish(t, theme, rng)


def wardrobe(theme, rng, v):
    t, p = piece(), P(theme, v)
    mat = [p.wood, 'enamel_cream' if theme != 'industry' else 'enamel_grey', 'lacquer_black' if theme in ('rich', 'rural') else p.enamel][v]
    body(t, 4, 4, 59, 30, 30, mat, mat, r=1, inset=2)
    t.mark(B(31, 4, 32, 30), -2)
    t.slab(B(28, 18, 29, 26) | B(34, 18, 35, 26), 'chrome' if v != 0 else 'brass', 1)
    if theme == 'rural':
        t.mark(B(4, 4, 59, 30) & (((XX % 8) == 0) | ((YY % 8) == 0)), -1)
    if p.poor:
        t.slab(B(36, 30, 58, 34), mat, 26, bevel=0.6)
    return finish(t, theme, rng)


def dresser(theme, rng, v):
    t, p = piece(), P(theme, v)
    mat = [p.wood, p.body, 'wood_light'][v]
    body(t, 6, 6, 57, 34, 14, mat, mat, r=1)
    for k in range(3):
        y = 7 + k * 9
        t.mark(B(7, y + 8, 56, y + 8), -2)
        t.slab(D(22, y + 4, 1.4) | D(41, y + 4, 1.4), 'brass' if v != 1 else 'chrome', 1, profile='dome')
    t.slab(D(14, 12, 4), 'plastic_w', 6, profile='dome')
    lit(t, p, rng, D(14, 12, 2), 'lamp')
    t.slab(B(42, 9, 52, 15, 1), 'lacquer_red' if v == 0 else 'paper', 2)
    return finish(t, theme, rng)


def sofa(theme, rng, v):
    t, p = piece(), P(theme, v)
    sofa_form(t, p, rng, 1, 62, 3 if v != 1 else 2, p.uph, arms=True, back_h=14, y0=8, y1=50)
    t.slab(D(16, 30, 5), 'fabric_mustard' if p.uph != 'fabric_mustard' else 'fabric_b', 4, profile='dome')
    return finish(t, theme, rng)


def coffee_table(theme, rng, v):
    t, p = piece(), P(theme, v)
    if v == 2:
        t.slab(D(32, 32, 18, 14), 'glass' if not p.poor else p.body, 6, bevel=1)
        t.mark(D(32, 32, 18, 14) & ~D(32, 32, 17, 13), 1)
    else:
        legs(t, 14, 18, 49, 45, p.wood if v == 0 else p.metal, r=1.6, h=4)
        body(t, 10, 14, 53, 49, 6, 'graphite' if v else p.wood, 'glass' if v else p.wood, r=2)
    t.slab(B(16, 22, 30, 34), rng.pick(['paint_w', 'fabric_b', 'paper']), 0.6)
    t.slab(D(40, 28, 3), 'paint_w', 3, profile='cyl')
    t.paint(D(40, 28, 1.8), 'tea_amber')
    if p.poor:
        t.slab(D(36, 40, 2.5), 'plastic_r', 2.5, profile='cyl')
    return finish(t, theme, rng)


def tv_stand(theme, rng, v):
    t, p = piece(), P(theme, v)
    mat = ['laminate_w', 'wood_light', 'graphite'][v]
    body(t, 4, 18, 59, 44, 8, mat, mat, r=1)
    t.mark(B(22, 18, 22, 44) | B(41, 18, 41, 44), -1)
    if v == 2 or p.poor:      # an old box set
        t.slab(B(16, 14, 47, 40, 2), 'graphite', 16, bevel=1.5)
        lit(t, p, rng, B(19, 17, 44, 26), 'screen_glow')
    else:
        t.slab(B(26, 22, 37, 26), 'dark_steel', 10)
        t.slab(B(6, 14, 57, 20, 1), 'ink', 18, bevel=0.5)
        lit(t, p, rng, B(7, 19, 56, 20), 'screen_glow')
    t.emit(D(52, 40, 1), 'neon_green')
    return finish(t, theme, rng)


def kitchen_counter(theme, rng, v):
    t, p = piece(), P(theme, v)
    top = ['stone', 'wood_light', 'laminate_w' if theme != 'slum' else 'laminate_y'][v]
    t.slab(B(0, 2, 63, 8), 'tile_w' if theme != 'rural' else 'wood', 20, bevel=0.5)
    t.mark(B(0, 2, 63, 8) & ((XX % 8) == 0), -1)
    body(t, 0, 8, 63, 40, 12, p.body, top, r=0)
    run(t)
    t.slab(B(8, 16, 26, 30, 1), 'wood_light', 1.5)
    t.slab(D(16, 22, 3), 'tomato', 2, profile='dome')
    t.slab(L(30, 20, 40, 24, 1.6), 'chrome', 1, bevel=0)
    t.slab(D(50, 20, 6), p.metal, 6, profile='cyl')
    t.paint(D(50, 20, 4), 'dark_steel')
    t.slab(D(56, 32, 2.5), ['container_b', 'plastic_w', 'paint_y'][v], 5, profile='cyl')
    t.mark(B(0, 40, 63, 40), -2)
    return finish(t, theme, rng)


def kitchen_sink(theme, rng, v):
    t, p = piece(), P(theme, v)
    top = ['stone', 'wood_light', 'laminate_w' if theme != 'slum' else 'laminate_y'][v]
    t.slab(B(0, 2, 63, 8), 'tile_w' if theme != 'rural' else 'wood', 20, bevel=0.5)
    t.mark(B(0, 2, 63, 8) & ((XX % 8) == 0), -1)
    body(t, 0, 8, 63, 40, 12, p.body, top, r=0)
    run(t)
    t.slab(B(8, 12, 55, 36, 2), p.metal if not p.rich else 'chrome', 0.5)
    for x0, x1 in ((10, 30), (33, 53)):
        t.carve(B(x0, 14, x1, 34, 2), 4)
        t.mark(D((x0 + x1) / 2, 28, 1.5), -2)
    t.slab(L(31, 10, 31, 20, 2.4), 'chrome', 6, bevel=0)
    t.slab(D(31, 10, 2), 'chrome', 6, profile='dome')
    if theme in ('slum', 'mid'):
        t.slab(D(20, 24, 6), 'plastic_w', 3, bevel=1)
        t.slab(D(42, 22, 4), 'paint_w', 2, bevel=0.8)
    return finish(t, theme, rng)


def toilet(theme, rng, v):
    t, p = piece(), P(theme, v)
    cer = ['paint_w', 'paint_w', 'enamel_cream'][v] if not p.poor else ['linen', 'paint_w', 'enamel_cream'][v]
    t.slab(B(20, 6, 43, 16, 2), cer, 16, bevel=1)
    t.slab(D(32, 34, 12, 15), cer, 9, bevel=1.5)
    t.carve(D(32, 36, 8, 10), 4)
    t.paint(D(32, 38, 5, 6), 'water')
    if v == 1:
        t.slab(B(22, 6, 41, 14, 2), 'graphite' if p.rich else cer, 16.5, bevel=0.5)
        lit(t, p, rng, B(26, 9, 37, 10), 'neon_cyan')
    t.slab(D(32, 11, 2), 'chrome', 17, profile='dome')
    if p.poor:
        t.mark(blotches(rng.int(0, 1 << 20), 0.25) & t.obj, -1)
    return finish(t, theme, rng)


def shower(theme, rng, v):
    t, p = piece(), P(theme, v)
    tray = B(4, 4, 59, 59, 2)
    t.slab(tray, ['tile_w', 'tile_blue', 'stone_dark'][v], 2, bevel=0.6)
    t.mark(B(6, 6, 57, 57) & (((XX % 8) == 0) | ((YY % 8) == 0)), -1)
    t.carve(D(32, 32, 3), 1)
    t.mark(D(32, 32, 3) & ((XX % 2) == 0), -2)
    t.slab(B(4, 56, 59, 59), 'glass', 24, bevel=0.3)
    t.slab(B(56, 4, 59, 59), 'glass', 24, bevel=0.3)
    t.slab(D(14, 10, 4), 'chrome', 22, profile='dome')
    t.slab(L(14, 4, 14, 10, 2), 'chrome', 22, bevel=0)
    if p.poor:
        t.paint(blotches(rng.int(0, 1 << 20), 0.08, cells=8) & tray, 'moss')
    return finish(t, theme, rng)


def bathtub(theme, rng, v):
    t, p = piece(), P(theme, v)
    shell = ['paint_w', 'enamel_cream', 'graphite' if p.rich else 'enamel_teal'][v]
    if theme == 'rural':
        shell = 'wood_light'           # a cedar ofuro
    m = B(10, 2, 53, 61, 10 if v != 1 else 4)
    t.slab(m, shell, 12, bevel=1.5)
    inner = B(15, 7, 48, 56, 8 if v != 1 else 3)
    t.carve(inner, 5)
    t.paint(inner, 'water' if v != 2 else 'foam')
    t.mark(inner & L(20, 20, 34, 12, 2), 2)
    t.slab(L(32, 2, 32, 8, 2.4), 'chrome' if not p.rich else 'gold', 14, bevel=0)
    if theme == 'rural':
        t.mark(m & ~inner & ((XX % 6) == 0), -1)
    return finish(t, theme, rng)


def kotatsu(theme, rng, v):
    t, p = piece(), P(theme, v)
    quilt = ['fabric_indigo', 'fabric_o', 'fabric_g'][v] if theme != 'rich' else ['fabric_cream', 'velvet_teal', 'fabric_indigo'][v]
    q = B(2, 2, 61, 61, 8)
    t.slab(q, quilt, 5, profile='dome')
    if v == 0:
        t.mark(q & ((((XX // 8) + (YY // 8)) % 2) == 0) & ~B(14, 14, 49, 49), 1)
    t.slab(B(12, 12, 51, 51, 1), 'wood_light' if v != 2 else 'lacquer_black', 3, bevel=0.6, on=8)
    for k, (x, y) in enumerate(((26, 26), (31, 24), (28, 30))):
        t.slab(D(x, y, 3), 'orange_f', 2.5, profile='dome')
    t.slab(D(40, 38, 3.5), 'paint_w', 3, profile='cyl')
    t.paint(D(40, 38, 2.2), 'tea_green')
    return finish(t, theme, rng)


def futon(theme, rng, v):
    t, p = piece(), P(theme, v)
    cover = ['fabric_indigo', 'fabric_cream' if theme != 'slum' else 'fabric_g', 'fabric_o'][v]
    t.slab(B(12, 4, 51, 60, 4), 'linen', 4, profile='dome')
    t.slab(B(18, 6, 45, 15, 4), 'paper' if v != 2 else 'fabric_g', 3, profile='dome', on=4)
    q = B(12, 20, 51, 60, 4)
    t.slab(q, cover, 3, profile='dome', on=4)
    if v == 0:
        t.mark(q & (((XX + YY) % 10) < 2), 1)
    elif v == 1:
        t.mark(q & ((((XX - 12) // 6) % 2) == 0), -1)
    tape(t, p, rng, q, 1)
    return finish(t, theme, rng)


def home_shrine(theme, rng, v):
    t, p = piece(), P(theme, v)
    if v == 0:          # butsudan: black lacquer cabinet with gold
        body(t, 10, 4, 53, 34, 24, 'lacquer_black', 'lacquer_black', r=1)
        t.paint(B(18, 8, 45, 28), 'icon_gold')
        t.paint(B(24, 12, 39, 26), 'lacquer_black')
        t.slab(D(32, 18, 3), 'gold', 2, profile='dome')
    elif v == 1:        # kamidana shelf
        t.slab(B(4, 4, 59, 14), 'wood_light', 22, bevel=0.6)
        t.slab(Tile.poly_mask([(22, 2), (42, 2), (46, 14), (18, 14)]), 'wood_light', 26, bevel=0.6)
        t.slab(L(6, 16, 58, 16, 1.5), 'paper', 20, bevel=0)
        for x in (12, 52):
            t.slab(D(x, 10, 2.5), 'leaf', 24, profile='dome')
    else:               # icon corner: a small shelf with an icon and a lamp
        t.slab(B(16, 4, 47, 14), 'wood_dark', 22, bevel=0.6)
        t.slab(B(22, 2, 41, 12, 1), 'icon_gold', 24, bevel=0.5)
        t.paint(B(26, 4, 37, 10, 1), 'wood_light')
    t.slab(B(14, 38, 49, 52, 1), 'wood_dark' if v != 1 else 'wood_light', 8, bevel=0.6)
    for x in (20, 43):
        t.slab(D(x, 44, 2), 'wax', 11, profile='cyl')
        lit(t, p, rng, D(x, 44, 1), 'fire' if v != 2 else 'lamp')
    t.slab(D(32, 45, 3), 'brass', 10, profile='cyl')
    t.paint(D(32, 45, 1.8), 'ink')
    return finish(t, theme, rng)


def shoe_rack(theme, rng, v):
    t, p = piece(), P(theme, v)
    t.slab(B(4, 14, 59, 46, 1), p.wood if v != 1 else p.metal, 6, bevel=0.6)
    t.mark(B(4, 14, 59, 46) & ((YY % 8) == 6), -2)
    cols = ['paint_w', 'rubber', 'leather_br', 'fabric_b', 'canvas_w', 'blossom', 'leather_k']
    for k in range(4):
        x = 7 + k * 13
        c = cols[(k * 3 + v) % len(cols)]
        for dx in (0, 6):
            t.slab(D(x + dx + 2, 24, 2.6, 7), c, 3, profile='dome')
            t.paint(D(x + dx + 2, 21, 1.5, 3), 'ink' if c != 'rubber' else 'paint_w')
    if theme == 'rural' or v == 2:
        t.slab(D(22, 40, 3, 5), 'wood_light', 2, profile='dome')
        t.slab(D(30, 40, 3, 5), 'wood_light', 2, profile='dome')
    return finish(t, theme, rng)


# ================================================================================================ offices
def desk_workstation(theme, rng, v):
    t, p = piece(), P(theme, v)
    desk_form(t, p, 0, 14, 63, 48)
    run(t)
    n = 2 if v != 2 else 1
    for k in range(n):
        monitor(t, p, rng, 10 + k * 24 if n == 2 else 20, 16, 20 if n == 2 else 24, ['screen_glow', 'neon_cyan'][k])
    t.slab(B(18, 30, 42, 35, 1), 'dark_steel' if v != 1 else 'plastic_w', 1)
    t.mark(B(19, 31, 41, 34) & ((XX % 2) == 0), 1)
    t.slab(D(48, 33, 2, 3), 'dark_steel', 1.5, profile='dome')
    t.slab(D(8, 38, 3), 'paint_w', 3, profile='cyl')
    t.paint(D(8, 38, 1.8), 'coffee')
    if p.poor:
        t.slab(B(50, 38, 60, 46), 'paper', 0.6)
    return finish(t, theme, rng)


def desk_executive(theme, rng, v):
    t, p = piece(), P(theme, v)
    wood = ['wood_dark', 'lacquer_black', 'wood' if theme != 'industry' else 'graphite'][v]
    body(t, 2, 12, 61, 52, 12, wood, wood, r=2)
    t.slab(B(16, 26, 46, 42, 1), 'leather_k' if v != 0 else 'leather_ox', 0.8)
    t.slab(D(10, 20, 4), 'brass', 3, profile='cyl')
    t.slab(D(10, 20, 6), 'fabric_cream', 8, profile='dome')
    lit(t, p, rng, D(10, 20, 2.5), 'lamp')
    t.slab(B(48, 16, 58, 24, 1), 'graphite', 2)
    t.slab(L(36, 34, 42, 30, 1.4), 'gold', 1.5, bevel=0)
    t.slab(B(20, 16, 40, 22, 0.5), 'card_k', 0.8)
    lit(t, p, rng, B(21, 17, 39, 21), 'screen_glow')
    if p.rich:
        t.paint(B(2, 50, 61, 52), 'accent')
    return finish(t, theme, rng)


def office_chair(theme, rng, v):
    t, p = piece(), P(theme, v)
    seat_m = ['leather_k' if p.rich else 'fabric_grey', 'fabric_b' if theme != 'rich' else 'fabric_cream', 'vinyl_teal'][v]
    for k in range(5):
        a = k * 2 * math.pi / 5 + 0.3
        t.slab(L(32, 34, 32 + math.cos(a) * 18, 34 + math.sin(a) * 18, 2.5), 'dark_steel', 3, bevel=0)
        wheel(t, 32 + math.cos(a) * 18, 34 + math.sin(a) * 18, 2)
    cushion(t, D(32, 36, 13, 12), seat_m, 7, on_=4)
    t.slab(B(19, 14, 44, 22, 5), seat_m, 18, bevel=1.5)
    if v == 0 or p.rich:
        t.slab(B(16, 28, 19, 44, 1) | B(45, 28, 48, 44, 1), 'dark_steel', 13, bevel=0.5)
    tape(t, p, rng, D(32, 36, 12, 11), 2)
    return finish(t, theme, rng)


def meeting_table(theme, rng, v):
    t, p = piece(), P(theme, v)
    top = ['glass' if p.rich else p.top, p.wood, 'graphite' if theme != 'rural' else 'wood_dark'][v]
    body(t, 0, 12, 63, 52, 10, p.body if v != 1 else p.wood, top, r=0)
    run(t)
    t.slab(B(8, 18, 22, 30), 'paper', 0.6)
    t.slab(B(40, 34, 54, 46), 'paper', 0.6)
    t.slab(D(32, 32, 4), 'graphite', 2, profile='dome')
    t.emit(D(32, 32, 1.5), 'neon_cyan')
    t.slab(D(48, 20, 2.5), 'glass', 4, profile='cyl')
    t.paint(D(48, 20, 1.5), 'water')
    return finish(t, theme, rng)


def server_rack(theme, rng, v):
    t, p = piece(), P(theme, v)
    body(t, 4, 4, 59, 46, 30, 'graphite' if v != 2 else 'rubber', 'dark_steel', r=1, inset=2)
    t.mark(B(6, 6, 57, 44) & ((XX % 3) == 0), -1)
    run(t)
    for r_ in range(6):
        y = 8 + r_ * 6
        t.mark(B(6, y + 5, 57, y + 5), -2)
        for k in range(6):
            x = 9 + k * 8 + (r_ * 3) % 5
            if rng.chance(0.7 if not p.poor else 0.45):
                t.emit(B(x, y + 1, x + 2, y + 3), rng.pick(['neon_green', 'neon_green', 'neon_cyan', 'neon_amber']))
    t.slab(L(6, 48, 57, 50, 2), 'container_b', 2, bevel=0)
    t.slab(L(10, 50, 50, 48, 2), 'paint_y', 2, bevel=0)
    return finish(t, theme, rng)


def cubicle_divider(theme, rng, v):
    t, p = piece(), P(theme, v)
    panel = ['fabric_grey', 'fabric_b' if theme != 'rich' else 'fabric_cream', 'laminate_g' if theme != 'industry' else 'enamel_grey'][v]
    m = B(0, 24, 63, 39)
    t.slab(m, panel, 26, bevel=1.5)
    t.slab(B(0, 24, 63, 25), p.metal, 27, bevel=0.3)
    t.mark(m & ((YY % 3) == 0) & B(0, 27, 63, 37), -1)
    t.mark(m & ((XX % 32) == 0), -2)
    run(t)
    t.slab(B(10, 28, 18, 36), 'paper', 0.6)
    t.slab(B(40, 29, 46, 35), 'paint_y', 0.6)
    return finish(t, theme, rng)


def whiteboard(theme, rng, v):
    t, p = piece(), P(theme, v)
    wall_run(t, p, 2, 38, 8, p.metal)
    brd = B(2, 4, 61, 34)
    t.paint(brd, 'paint_w')
    cols = ['fabric_b', 'fabric_g', 'ink', 'plastic_r']
    for k in range(5):
        x, y = rng.int(6, 40), rng.int(8, 28)
        x1, y1 = x + rng.int(8, 18), y + rng.int(-5, 5)
        t.paint(L(x, y, x1, y1, 1) & brd, cols[(k + v) % 4])
    t.paint((np.abs(np.hypot(XX - 48, YY - 18) - 7) < 0.7) & brd, cols[v % 4])
    t.slab(B(8, 36, 56, 39), p.metal, 9, bevel=0.3)
    for k, c in enumerate(cols[:3]):
        t.slab(L(14 + k * 8, 37, 19 + k * 8, 37, 1.6), c, 10, bevel=0)
    return finish(t, theme, rng)


def mailboxes(theme, rng, v):
    t, p = piece(), P(theme, v)
    face = ['brass', 'steel', 'enamel_grey'][v]
    wall_run(t, p, 2, 36, 16, face)
    for r_ in range(4):
        for c_ in range(5):
            x0, y0 = 1 + c_ * 13, 4 + r_ * 8
            d = B(x0, y0, x0 + 11, y0 + 6)
            t.mark(d & ~B(x0 + 1, y0 + 1, x0 + 10, y0 + 5), -1)
            t.mark(B(x0 + 3, y0 + 2, x0 + 8, y0 + 2), -2)
            t.mark(D(x0 + 9, y0 + 4, 0.8), -2)
            if p.poor and rng.chance(0.25):
                t.slab(B(x0 + 2, y0 + 1, x0 + 9, y0 + 3), 'paper', 1, bevel=0)
    return finish(t, theme, rng)


def directory_board(theme, rng, v):
    t, p = piece(), P(theme, v)
    t.slab(B(8, 4, 55, 44, 2), p.metal if v != 1 else 'brass', 22, bevel=1)
    panel = B(11, 7, 52, 41, 1)
    t.paint(panel, 'screen')
    glow = ['screen_glow', 'neon_cyan', 'lamp_cold'][v]
    for k in range(7):
        y = 10 + k * 4
        w = rng.int(16, 34)
        lit(t, p, rng, B(14, y, 14 + w, y), glow)
        t.emit(B(48, y, 49, y), 'neon_amber' if k % 3 == 0 else glow)
    t.slab(B(28, 44, 35, 58, 1), p.metal if v != 1 else 'brass', 6, bevel=0.6)
    return finish(t, theme, rng)


# ================================================================================================ floors (ground: they wrap)
def floor_concrete(theme, rng, v):
    t = Tile('conc_bare' if v != 2 else 'concrete')
    seam = (XX % 64 == 0) | (YY % 64 == 0) if v != 1 else ((XX % 32 == 0) | (YY % 32 == 0))
    T._slab_seams(t, seam, 0.6)
    t.mark(speckle(rng.int(0, 1 << 20), 0.05), -1)
    t.mark(speckle(rng.int(0, 1 << 20), 0.03), 1)
    if theme == 'rich':
        t.mark(blotches(rng.int(0, 1 << 20), 0.2, cells=2), 1)       # polished sheen
    else:
        T.wear(t, theme, rng, scale=0.8, seams=seam)
    if v == 2 and theme in ('industry', 'slum', 'mid'):
        t.paint((XX % 64 >= 28) & (XX % 64 < 32), 'paint_y')
    return t


def floor_dance(theme, rng, v):
    t = Tile('dance_k')
    seam, cell = grid(16, 16, 1)
    T._slab_seams(t, seam, 0.4)
    hues = [['neon_violet', 'neon_pink', 'neon_cyan'], ['neon_cyan', 'neon_violet', 'neon_amber'], ['neon_pink', 'neon_amber', 'neon_green']][v]
    for k in range(16):
        cx, cy = k % 4, k // 4
        h = (cx * 7 + cy * 13 + v * 5) % 9
        tile = B(cx * 16 + 2, cy * 16 + 2, cx * 16 + 14, cy * 16 + 14, 1)
        if h < 3:
            if theme == 'slum' and h == 0:
                t.paint(tile, 'lamp_dead')
            else:
                t.emit(tile, hues[h])
        elif h < 5:
            t.mark(tile, 1)
    return t


def floor_rubber(theme, rng, v):
    """interlocking rubber gym tiles: plain, a fine bevel at each joint, no flecks"""
    t = Tile(['rubber_floor', 'rubber_blue', 'rubber_green'][v])
    seam, cell = grid(32, 32, 1)
    T._slab_seams(t, seam, 0.4)
    t.mark(np.roll(seam, 1, 0) | np.roll(seam, 1, 1), 1)
    return t


def floor_mat(theme, rng, v):
    a, b = [('mat_red', 'mat_blue'), ('mat_blue', 'mat_blue'), ('mat_red', 'mat_red')][v]
    if theme == 'rural' and v != 2:
        a, b = ('tatami', 'tatami')
    t = Tile(a)
    seam, cell = grid(32, 32, 1)
    T._slab_seams(t, seam, 0.6)
    t.paint(((cell // 1000 + cell) % 2 == 1) & ~seam, b)
    if a == 'tatami':
        t.mark((XX % 3 == 0) & ~seam, -1)
        if v == 1:
            t.paint(seam | np.roll(seam, 1, 0) | np.roll(seam, 1, 1), 'fabric_indigo')
    else:
        t.mark(((XX + YY) % 4 == 0) & ~seam, -1)
    if theme == 'slum':
        T.wear(t, theme, rng, scale=0.3)
    return t


def floor_carpet_grey(theme, rng, v):
    mat = ['carpet_grey', 'carpet_blue', 'carpet_warm'][v]
    t = Tile(mat)
    seam, cell = grid(32, 32, 1)
    t.mark(seam, -1)
    alt = ((cell // 1000 + cell) % 2 == 1) & ~seam
    t.mark(alt & ((XX % 2) == 0), 1)
    t.mark(~alt & ~seam & ((YY % 2) == 0), 1)
    t.mark(speckle(rng.int(0, 1 << 20), 0.06), -1)
    if v == 2:
        t.paint(((XX % 32) == 16) & ~seam, 'enamel_teal' if theme != 'slum' else 'fabric_grey')
    if theme in ('slum', 'industry', 'mid'):
        T.wear(t, theme, rng, scale=0.2)
    return t


def floor_tile(theme, rng, v):
    w = [8, 16, 8][v]
    t = Tile('tile_w')
    seam, cell = grid(w, w, 1)
    t.paint(seam, 'grout')
    t.carve(seam, 0.4)
    if v == 2:
        t.paint((((cell // 1000) + cell) % 5 == 0) & ~seam, 'tile_blue')
    if theme == 'rich':
        t.mark(~seam & (((XX + YY) % w) == 2), 1)
    if theme in ('slum', 'industry'):
        T.wear(t, theme, rng, scale=0.6, seams=seam)
        miss = ((cell * 37) % 23 == v) & ~seam
        t.paint(miss, 'conc_bare')
        t.carve(miss, 0.6)
    return t


def floor_lino(theme, rng, v):
    a = ['lino', 'lino2', 'lino'][v]
    t = Tile(a)
    if v == 2:          # a sheet with a printed check
        seam, cell = grid(16, 16, 0)
        t.paint((((cell // 1000) + cell) % 2 == 1), 'lino2')
    else:
        seam = (XX % 64 == 0)
        t.mark(seam, -1)
        t.mark(((XX + YY * 3) % 32 == 0) | ((XX * 3 - YY) % 32 == 0), -1)
    t.mark(speckle(rng.int(0, 1 << 20), 0.03), 1)
    if theme != 'rich':
        T.wear(t, theme, rng, scale=0.2)
    return t


def floor_parquet(theme, rng, v):
    a, b = ('parquet', 'parquet2') if theme != 'rich' else ('parquet2', 'wood_dark')
    t = Tile(a)
    if v == 0:          # herringbone, period 32
        u = (XX + YY) % 32
        w = (XX - YY) % 32
        seam = ((XX % 16) == 0) & (((YY // 16) + (XX // 16)) % 2 == 0) | ((YY % 16) == 0) & (((YY // 16) + (XX // 16)) % 2 == 1)
        alt = ((XX // 16 + YY // 16) % 2) == 0
        t.paint(alt, b)
        sub = np.where(alt, (YY % 16) // 4, (XX % 16) // 4)
        t.mark((np.where(alt, YY % 4, XX % 4) == 0), -1)
        t.mark(seam, -1)
    elif v == 1:        # long boards running the other way
        seam, cell = planks(8, 32, 1, vertical=True, seed=v + 5)
        T._slab_seams(t, seam, 0.4)
        t.paint((cell * 7 % 3 == 1) & ~seam, b)
    else:               # long strips
        seam, cell = planks(6 if 64 % 6 else 8, 32, 1, seed=v + 11)
        T._slab_seams(t, seam, 0.4)
        t.paint((cell * 5 % 3 == 0) & ~seam, b)
    if theme in ('slum', 'rural'):
        T.wear(t, theme, rng, scale=0.5)
    return t


def station_clock(theme, rng, v):
    """a platform clock and departure board on the tunnel wall (the game reads the timetable from it)"""
    t, p = piece(), P(theme, v)
    wall_run(t, p, 2, 22, 18, 'graphite')
    t.slab(D(14, 20, 11), p.metal, 22, bevel=1)
    t.paint(D(14, 20, 8.5), 'paint_w')
    for k in range(12):
        a = k * math.pi / 6
        t.paint(D(14 + math.cos(a) * 7, 20 + math.sin(a) * 7, 0.7), 'ink')
    t.paint(L(14, 20, 14, 14, 1.4) | L(14, 20, 19, 22, 1.2), 'ink')
    board = B(28, 6, 61, 20)
    t.slab(board, 'ink', 19, bevel=0.5)
    for k in range(3):
        lit(t, p, rng, B(30, 8 + k * 4, 30 + 10 + (k * 7) % 18, 9 + k * 4), 'neon_amber')
        t.emit(B(56, 8 + k * 4, 59, 9 + k * 4), 'neon_green' if k else 'neon_amber')
    return finish(t, theme, rng)


EXTRA = {'station_clock': station_clock}

# ------------------------------------------------------------------------------------------------ facings
# Every piece is drawn facing south (its back, or the wall it stands on, to the north).  The other three facings are
# the same piece turned before it is lit, so the light still comes from the top left and the shadow still falls to
# the bottom right.  Sprite ids: f_trl_<id> faces south, f_trl_<id>_fn north, _fe east, _fw west.
FACINGS = (('_fn', 2), ('_fe', 1), ('_fw', -1))
NO_TURN = {'mannequin'}          # drawn upright like the people, the same from every side


def turned(t, k):
    for name in ('h', 'm', 'obj', 'd', 'glow', 'solid', 'noline', 'norim'):
        setattr(t, name, np.ascontiguousarray(np.rot90(getattr(t, name), k)))
    t.shadow = np.zeros_like(t.shadow)
    t.drop_shadow(t.solid.copy(), 3, 3, 0.42)
    return t

FURN = {
    'coffee_bar': coffee_bar, 'cafe_table': cafe_table, 'cafe_chair': cafe_chair, 'coffee_machine': coffee_machine,
    'bar_counter': bar_counter, 'booth_seat': booth_seat, 'jukebox': jukebox, 'pool_table': pool_table, 'card_table': card_table,
    'barrel': barrel, 'crate_stack': crate_stack, 'lounge_sofa': lounge_sofa, 'dj_booth': dj_booth, 'speaker_stack': speaker_stack,
    'bakery_case': bakery_case, 'bread_rack': bread_rack, 'karaoke_booth': karaoke_booth,
    'clothing_rack': clothing_rack, 'mannequin': mannequin, 'shoe_wall': shoe_wall, 'mirror': mirror, 'display_case': display_case,
    'electronics_shelf': electronics_shelf, 'tv_wall': tv_wall, 'office_shelf': office_shelf, 'copier': copier,
    'filing_cabinet': filing_cabinet, 'weapon_rack': weapon_rack, 'training_dummy': training_dummy, 'punching_bag': punching_bag,
    'pawn_cage': pawn_cage, 'safe': safe, 'gun_rack': gun_rack, 'hardware_rack': hardware_rack, 'tool_wall': tool_wall,
    'lumber_stack': lumber_stack, 'pharmacy_shelf': pharmacy_shelf, 'scale': scale, 'bookshelf': bookshelf, 'armchair': armchair,
    'car_plinth': car_plinth, 'tire_rack': tire_rack, 'desk': desk, 'lift_hoist': lift_hoist, 'tool_chest': tool_chest,
    'workbench': workbench,
    'teller_window': teller_window, 'queue_rail': queue_rail, 'deposit_boxes': deposit_boxes, 'atm': atm, 'vault_door': vault_door,
    'police_desk': police_desk, 'holding_cell': holding_cell, 'evidence_locker': evidence_locker, 'notice_board': notice_board,
    'service_window': service_window, 'waiting_bench': waiting_bench, 'parcel_shelf': parcel_shelf, 'mail_sorter': mail_sorter,
    'parcel_trolley': parcel_trolley, 'key_rack': key_rack, 'luggage_cart': luggage_cart, 'lobby_sofa': lobby_sofa,
    'capsule_bed': capsule_bed, 'treadmill': treadmill, 'weight_bench': weight_bench, 'squat_rack': squat_rack,
    'dumbbell_rack': dumbbell_rack, 'locker': locker, 'shoe_shelf': shoe_shelf, 'barber_chair': barber_chair,
    'salon_sink': salon_sink, 'salon_mirror': salon_mirror, 'hair_dryer': hair_dryer, 'washing_machine': washing_machine,
    'dryer': dryer, 'folding_table': folding_table, 'arcade_cabinet': arcade_cabinet, 'pachinko_machine': pachinko_machine,
    'claw_machine': claw_machine,
    'pallet_rack': pallet_rack, 'pallet_stack': pallet_stack, 'conveyor': conveyor, 'parts_bin': parts_bin, 'lathe': lathe,
    'mill': mill, 'scrap_pile': scrap_pile, 'baler': baler, 'shredder': shredder, 'press_machine': press_machine,
    'bed_single': bed_single, 'bed_double': bed_double, 'bunk_bed': bunk_bed, 'wardrobe': wardrobe, 'dresser': dresser,
    'sofa': sofa, 'coffee_table': coffee_table, 'tv_stand': tv_stand, 'kitchen_counter': kitchen_counter,
    'kitchen_sink': kitchen_sink, 'toilet': toilet, 'shower': shower, 'bathtub': bathtub, 'kotatsu': kotatsu, 'futon': futon,
    'home_shrine': home_shrine, 'shoe_rack': shoe_rack,
    'desk_workstation': desk_workstation, 'desk_executive': desk_executive, 'office_chair': office_chair,
    'meeting_table': meeting_table, 'server_rack': server_rack, 'cubicle_divider': cubicle_divider, 'whiteboard': whiteboard,
    'mailboxes': mailboxes, 'directory_board': directory_board,
}
FLOORS = {'floor_concrete': floor_concrete, 'floor_dance': floor_dance, 'floor_rubber': floor_rubber, 'floor_mat': floor_mat,
          'floor_carpet_grey': floor_carpet_grey, 'floor_tile': floor_tile, 'floor_lino': floor_lino, 'floor_parquet': floor_parquet}
VARIANTS = 3
