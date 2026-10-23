"""New world objects for the five districts: street trees, hedges and wild shrubs, statues and fountains, columns,
street lights (working and broken), benches, neon signs in every colour, spills and rubbish, fuel tanks, drums,
machinery, robot arms, pipe runs, pallets, rural wood piles, wells, hay and fences, and a few new grounds (plaza,
cobbles, dirt road, rice paddy).  Ids carry the colour or state they show (f_trl_neon_green is green, a _broken light
is broken); every theme draws its own version."""
import math

import numpy as np

from canvas import Tile, N, XX, YY, Rng, blotches, speckle, cracks, periodic_noise
from themes import style
import furniture as F
import terrain as T


def tree_street(theme, rng):
    """a street tree in a grate"""
    t = F.piece()
    grate = Tile.disk_mask(32, 34, 16) & ~Tile.disk_mask(32, 34, 13)
    t.slab(grate, 'dark_steel' if theme != 'rural' else 'stone', 1.0, bevel=0, obj=False)
    t.mark(grate & (((XX + YY) % 4) == 0), -1)
    soil = Tile.disk_mask(32, 34, 13)
    t.ground('soil', soil, h=-0.5)
    tr = F.tree(theme, rng, 0)
    keep = tr.solid
    for a in ('h', 'm', 'obj', 'd', 'glow', 'noline'):
        getattr(t, a)[keep] = getattr(tr, a)[keep]
    t.solid |= keep
    t.shadow = np.maximum(t.shadow, tr.shadow)
    t.shadow[t.solid] = 0
    return t


def hedge(theme, rng):
    t = F.piece()
    m = Tile.box_mask(0, 14, 63, 49, 0)
    mat = 'leaf' if theme in ('rich', 'mid') else 'leaf_dark'
    if theme in ('rich', 'mid'):
        t.slab(m, mat, 14, bevel=3)
        t.mark(m & speckle(rng.int(0, 1 << 20), 0.12), 1)
        t.mark(m & speckle(rng.int(0, 1 << 20), 0.08), -1)
        t.noline |= (XX == 0) | (XX == 63)
    else:
        for k in range(8):
            t.slab(Tile.disk_mask(rng.range(0, 63), rng.range(18, 46), rng.range(9, 14)), mat if k % 2 else 'leaf', rng.range(9, 15), profile='dome')
    return F.finish(t, theme, rng)


def shrub_wild(theme, rng):
    t = F.piece()
    for k in range(11):
        a = rng.range(0, 2 * math.pi)
        d = rng.range(0, 18)
        t.slab(Tile.disk_mask(32 + math.cos(a) * d, 32 + math.sin(a) * d, rng.range(5, 10)),
               rng.pick(['leaf', 'leaf_dark', 'grass_dry']), rng.range(6, 12), profile='dome')
    for k in range(5):
        a = rng.range(0, 2 * math.pi)
        t.slab(Tile.line_mask(32, 32, 32 + math.cos(a) * 28, 32 + math.sin(a) * 28, 1.2) & ~t.obj, 'bark', 5, bevel=0)
    return F.finish(t, theme, rng)


def flowerbed(theme, rng):
    t = F.piece()
    edge = 'kerb' if theme != 'rural' else 'stone'
    m = Tile.box_mask(4, 4, 59, 59, 6)
    t.slab(m, edge, 4, bevel=1)
    soil = Tile.box_mask(8, 8, 55, 55, 4)
    t.paint(soil, 'soil')
    for k in range(26):
        x, y = rng.range(11, 52), rng.range(11, 52)
        t.slab(Tile.disk_mask(x, y, rng.range(2.5, 4.5)) & soil, 'leaf' if k % 3 else 'leaf_dark', 3, profile='dome', obj=False)
    for k in range(18):
        x, y = rng.range(11, 52), rng.range(11, 52)
        t.slab(Tile.disk_mask(x, y, 1.6) & soil, rng.pick(['blossom', 'paint_y', 'paint_w', 'fabric_r']), 4, profile='dome', obj=False)
    return F.finish(t, theme, rng)


def statue(theme, rng, broken=False):
    """a figure on a plinth, seen from above: shoulders, arms, head (headless and cracked when broken)"""
    t = F.piece()
    stone = {'rich': 'wall', 'mid': 'stone', 'slum': 'stone_dark', 'rural': 'stone', 'industry': 'dark_steel'}[theme]
    plinth = Tile.box_mask(10, 10, 53, 53, 2)
    t.slab(plinth, 'stone_dark' if theme != 'rich' else 'floor2', 10, bevel=1.5)
    if theme == 'rich':
        t.paint(plinth & ~Tile.box_mask(12, 12, 51, 51), 'gold')
    body_ = Tile.disk_mask(32, 34, 13, 9)
    t.slab(body_, stone, 14, profile='dome', on=10)
    arm = Tile.line_mask(20, 34, 12, 44, 5) | Tile.line_mask(44, 34, 54, 22, 5)
    t.slab(arm, stone, 12, profile='dome', on=10)
    if not broken:
        t.slab(Tile.disk_mask(32, 30, 6), stone, 22, profile='dome', on=10)
    else:
        t.slab(Tile.disk_mask(32, 31, 4), 'stone_dark', 15, profile='cyl', on=10)
        t.mark(cracks(rng.int(0, 1 << 20), 3, 14, region=t.obj) & t.obj, -1)
        for k in range(4):
            t.slab(Tile.disk_mask(rng.range(14, 50), rng.range(48, 60), rng.range(1.5, 3)), stone, 3, profile='dome', on=0)
        t.paint(blotches(rng.int(0, 1 << 20), 0.3, cells=4) & t.obj, 'grime')
    if theme in ('rural', 'slum'):
        t.paint(blotches(rng.int(0, 1 << 20), 0.2, cells=4) & t.obj, 'moss')
    return F.finish(t, theme, rng)


def fountain(theme, rng):
    t = F.piece()
    rim = Tile.disk_mask(32, 32, 30)
    t.slab(rim, 'wall' if theme == 'rich' else 'stone', 7, bevel=1.5)
    w = Tile.disk_mask(32, 32, 26)
    t.paint(w, 'water' if theme in ('rich', 'mid', 'rural') else 'water_murk')
    t.h[w] = 3
    ripple = w & (np.abs(np.hypot(XX - 32, YY - 32) % 7 - 3.5) < 0.8)
    t.mark(ripple, 1)
    t.slab(Tile.disk_mask(32, 32, 7), 'wall' if theme == 'rich' else 'stone', 12, bevel=1.5)
    t.paint(Tile.disk_mask(32, 32, 3.5), 'foam')
    t.slab(Tile.disk_mask(32, 32, 2), 'foam', 16, profile='dome')
    if theme == 'rich':
        t.emit(w & (np.abs(np.hypot(XX - 32, YY - 32) - 24.5) < 0.8), 'neon_cyan')
    if theme == 'slum':
        t.paint(w & blotches(rng.int(0, 1 << 20), 0.3, cells=4), 'grime')
    return F.finish(t, theme, rng)


def column(theme, rng, broken=False):
    t = F.piece()
    stone = 'wall' if theme == 'rich' else 'stone'
    t.slab(Tile.box_mask(12, 12, 51, 51, 2), stone, 6, bevel=1)
    shaft = Tile.disk_mask(32, 32, 14)
    t.slab(shaft, stone, 28 if not broken else 14, profile='dome')
    flute = shaft & ((np.arctan2(YY - 32, XX - 32) * 12 / math.pi).astype(int) % 2 == 0) & ~Tile.disk_mask(32, 32, 10)
    t.mark(flute, -1)
    if broken:
        t.carve(Tile.disk_mask(28, 28, 6) & shaft, 4)
        t.mark(cracks(rng.int(0, 1 << 20), 2, 12, region=shaft) & shaft, -1)
        for k in range(3):
            t.slab(Tile.disk_mask(rng.range(40, 58), rng.range(40, 58), rng.range(2, 4)), stone, 4, profile='dome', on=0)
    return F.finish(t, theme, rng)


def streetlight(theme, rng, broken=False):
    """a lamp post from above: the base, the arm over the street and the lamp head; a pool of light when lit"""
    t = F.piece()
    pool = Tile.disk_mask(44, 30, 18, 14)
    lit = not broken
    t.slab(Tile.disk_mask(14, 32, 7), 'dark_steel' if theme != 'rich' else 'chrome', 8, profile='dome')
    arm = Tile.line_mask(14, 32, 42, 30, 3.5)
    t.slab(arm, 'dark_steel' if theme != 'rich' else 'chrome', 30, bevel=0.6)
    head = Tile.box_mask(34, 22, 58, 38, 5)
    t.slab(head, 'dark_steel' if theme != 'rich' else 'chrome', 31, bevel=1.2)
    lens = Tile.box_mask(37, 25, 55, 35, 4)
    if lit:
        t.emit(lens, 'lamp_cold' if theme in ('rich', 'industry') else 'lamp')
    else:
        t.paint(lens, 'lamp_dead')
        t.mark(Tile.line_mask(41, 28, 47, 32, 1) & lens, 2)
    if theme == 'rural':
        t.m[arm] = 'wood_dark'
    t.drop_shadow(t.solid.copy(), 5, 5, 0.35)
    if broken and theme in ('slum', 'industry'):
        t.paint(blotches(rng.int(0, 1 << 20), 0.4, cells=4) & t.obj & ~lens, 'rust')
    return t


def bench(theme, rng, broken=False):
    t = F.piece()
    for x in (8, 52):
        t.slab(Tile.box_mask(x, 20, x + 3, 44), 'kerb' if theme == 'rich' else 'dark_steel', 7, bevel=0.5)
    slat_mat = 'wood' if theme not in ('industry',) else 'dark_steel'
    for k, y in enumerate((22, 28, 34, 40)):
        if broken and k == 2:
            t.slab(Tile.line_mask(6, y + 1, 30, y + 4, 3), slat_mat, 4, bevel=0.5, on=0)
            continue
        t.slab(Tile.box_mask(4, y, 59, y + 4, 1), slat_mat, 9, bevel=0.6)
    return F.finish(t, theme, rng)


def neon(colour):
    return lambda theme, rng: F.neon_sign(theme, rng, colour)


def spill(theme, rng, kind='chem'):
    """a puddle at the foot of a wall (a decal: no height, walkable)"""
    t = Tile('', periodic=False)
    m = np.zeros((N, N), bool)
    for k in range(5):
        m |= Tile.disk_mask(rng.range(14, 50), rng.range(20, 50), rng.range(6, 13), rng.range(4, 9))
    mat = {'chem': 'spill_g', 'oil': 'oil', 'water': 'water_murk'}[kind]
    t.ground(mat, m, h=0)
    edge = m & ~(np.roll(m, 1, 0) & np.roll(m, -1, 0) & np.roll(m, 1, 1) & np.roll(m, -1, 1))
    t.mark(edge, -1)
    t.mark(m & Tile.disk_mask(26, 28, 4), 2)
    if kind == 'chem':
        t.emit(m & speckle(rng.int(0, 1 << 20), 0.05), 'neon_green')
    return t


def trash(theme, rng):
    t = F.piece()
    for k in range(5):
        t.slab(Tile.disk_mask(rng.range(14, 50), rng.range(16, 48), rng.range(7, 11), rng.range(6, 9)),
               rng.pick(['rubber', 'plastic_b', 'rubber']), rng.range(6, 10), profile='dome')
        t.mark(Tile.disk_mask(rng.range(14, 50), rng.range(16, 48), 1.5) & t.obj, 2)
    for k in range(6):
        t.slab(Tile.box_mask(*[int(v) for v in (rng.range(4, 56), rng.range(4, 56))], 0, 0) | Tile.disk_mask(rng.range(6, 58), rng.range(6, 58), 1.8),
               rng.pick(['paper', 'plastic_r', 'container_o']), 1, bevel=0)
    return F.finish(t, theme, rng)


def fuel_tank(theme, rng):
    t = F.piece()
    tank = Tile.disk_mask(32, 32, 29)
    t.slab(tank, 'tank_w', 30, profile='dome')
    for r in (22, 14):
        t.mark(np.abs(np.hypot(XX - 32, YY - 32) - r) < 0.7, -1)
    t.slab(Tile.disk_mask(32, 32, 4), 'dark_steel', 33, profile='cyl', on=0)
    lad = Tile.box_mask(50, 30, 61, 34)
    t.slab(lad, 'paint_y', 26, bevel=0)
    t.mark(lad & ((XX % 3) == 0), -1)
    band = np.abs(np.hypot(XX - 32, YY - 32) - 27) < 1.5
    t.paint(band & tank & (((np.arctan2(YY - 32, XX - 32) * 16 / math.pi).astype(int)) % 2 == 0), 'hazard_y')
    t.paint(band & tank & (((np.arctan2(YY - 32, XX - 32) * 16 / math.pi).astype(int)) % 2 == 1), 'hazard_k')
    t.paint(blotches(rng.int(0, 1 << 20), style(theme)['rust'] * 0.4, cells=4) & tank, 'rust')
    return F.finish(t, theme, rng)


def barrels(theme, rng):
    t = F.piece()
    for x, y in ((20, 20), (44, 22), (24, 44), (46, 46)):
        d = Tile.disk_mask(x + rng.range(-2, 2), y + rng.range(-2, 2), 10)
        col = rng.pick(['container_b', 'container_o', 'container_r', 'paint_y'])
        t.slab(d, col, 14, bevel=1.5)
        t.mark(d & ~Tile.disk_mask(x, y, 8) & Tile.disk_mask(x, y, 9), -1)
        t.slab(Tile.disk_mask(x + 4, y - 3, 1.8), 'dark_steel', 15, profile='cyl')
        t.paint(blotches(rng.int(0, 1 << 20), style(theme)['rust'] * 0.4, cells=4) & d, 'rust')
    return F.finish(t, theme, rng)


def machinery(theme, rng):
    """a press: a heavy frame, a ram, gears, a control box with a lit panel"""
    t = F.piece()
    F.body(t, 4, 8, 59, 55, 16, 'body2', 'body', r=2)
    t.slab(Tile.box_mask(18, 16, 45, 47, 2), 'dark_steel', 22, bevel=1)
    t.slab(Tile.box_mask(24, 22, 39, 41, 1), 'chrome', 24, bevel=1)
    for cx, cy, r in ((12, 18, 6), (12, 44, 5)):
        g = Tile.disk_mask(cx, cy, r)
        teeth = g & ~Tile.disk_mask(cx, cy, r - 1.5) & ((np.arctan2(YY - cy, XX - cx) * 6 / math.pi).astype(int) % 2 == 0)
        t.slab(Tile.disk_mask(cx, cy, r - 1.5) | teeth, 'steel', 20, bevel=0.6)
    hz = Tile.box_mask(4, 8, 59, 11) & (((XX + YY) % 8) < 4)
    t.paint(hz, 'hazard_y')
    t.emit(Tile.box_mask(50, 40, 55, 44), 'neon_amber')
    t.emit(Tile.box_mask(50, 46, 52, 48), 'neon_red')
    return F.finish(t, theme, rng)


def robot_arm(theme, rng):
    t = F.piece()
    base = Tile.disk_mask(20, 44, 12)
    t.slab(base, 'body2', 8, bevel=1.5)
    t.paint(base & ~Tile.disk_mask(20, 44, 10), 'hazard_y')
    seg1 = Tile.line_mask(20, 44, 38, 24, 7)
    t.slab(seg1, 'container_o', 20, profile='dome')
    t.slab(Tile.disk_mask(38, 24, 5), 'dark_steel', 22, profile='dome')
    seg2 = Tile.line_mask(38, 24, 52, 32, 5)
    t.slab(seg2, 'container_o', 24, profile='dome')
    t.slab(Tile.line_mask(52, 32, 56, 38, 2) | Tile.line_mask(52, 32, 58, 30, 2), 'chrome', 25, bevel=0.4)
    t.emit(Tile.disk_mask(20, 44, 2.5), 'neon_cyan')
    return F.finish(t, theme, rng)


def pipes(theme, rng):
    t = F.piece()
    for k, (y, r) in enumerate(((22, 7), (40, 5))):
        p = Tile.box_mask(0, y - r, 63, y + r)
        t.slab(p, 'steel' if k == 0 else 'copper', 10 + r, profile='dome')
        for x in (10, 42):
            fl = Tile.box_mask(x, y - r - 1, x + 3, y + r + 1)
            t.slab(fl, 'dark_steel', 11 + r, bevel=0.5)
    t.noline |= (XX == 0) | (XX == 63)
    t.paint(blotches(rng.int(0, 1 << 20), style(theme)['rust'] * 0.4 + 0.05, cells=4) & t.obj, 'rust')
    return F.finish(t, theme, rng)


def pallet(theme, rng):
    t = F.piece()
    for x in (8, 30, 52):
        t.slab(Tile.box_mask(x, 8, x + 4, 55), 'wood', 4, bevel=0.5)
    for y in range(8, 56, 8):
        t.slab(Tile.box_mask(6, y, 57, y + 4), 'wood_light', 6, bevel=0.5)
    t.slab(Tile.box_mask(14, 14, 49, 49, 2), 'container_b' if rng.chance(0.5) else 'paper', 16, bevel=1.5)
    t.mark(Tile.box_mask(14, 30, 49, 31), -1)
    return F.finish(t, theme, rng)


def generator(theme, rng):
    t = F.piece()
    F.body(t, 6, 12, 57, 51, 14, 'container_g' if theme != 'rich' else 'body2', 'body', r=3)
    vent = Tile.box_mask(12, 18, 36, 45) & ((YY % 4) < 2)
    t.mark(vent, -1)
    t.slab(Tile.disk_mask(46, 26, 5), 'dark_steel', 18, profile='cyl')
    t.emit(Tile.box_mask(42, 38, 50, 42), 'neon_green')
    return F.finish(t, theme, rng)


def woodpile(theme, rng):
    t = F.piece()
    for row in range(3):
        for k in range(6):
            x = 8 + k * 8 + (row % 2) * 4
            y = 18 + row * 10
            log = Tile.disk_mask(x, y, 4.5)
            t.slab(log, 'wood', 8 + row * 2, profile='dome')
            t.paint(Tile.disk_mask(x, y, 2.5), 'wood_light')
            t.mark(Tile.disk_mask(x, y, 1), -1)
    return F.finish(t, theme, rng)


def well(theme, rng):
    t = F.piece()
    ring = Tile.disk_mask(32, 34, 20) & ~Tile.disk_mask(32, 34, 13)
    t.slab(ring, 'stone', 10, bevel=1.5)
    t.mark(ring & ((np.arctan2(YY - 34, XX - 34) * 8 / math.pi).astype(int) % 2 == 0), -1)
    inner = Tile.disk_mask(32, 34, 13)
    t.ground('water_murk', inner, h=-6)
    t.mark(inner, -2)
    roof_ = Tile.box_mask(10, 8, 53, 20, 2)
    t.slab(roof_, 'roof' if theme == 'rural' else 'wood_dark', 22, bevel=2)
    t.mark(roof_ & ((XX % 6) == 0), -1)
    if theme != 'rich':
        t.paint(blotches(rng.int(0, 1 << 20), 0.25, cells=4) & ring, 'moss')
    return F.finish(t, theme, rng)


def haystack(theme, rng):
    t = F.piece()
    m = Tile.disk_mask(32, 34, 24, 20)
    t.slab(m, 'grass_dry', 18, profile='dome')
    t.mark(m & speckle(rng.int(0, 1 << 20), 0.25), -1)
    t.mark(m & speckle(rng.int(0, 1 << 20), 0.15), 1)
    t.slab(Tile.disk_mask(32, 30, 3), 'wood_dark', 22, profile='cyl')
    return F.finish(t, theme, rng)


def fence(theme, rng, broken=False):
    t = F.piece()
    mat = 'wood' if theme in ('rural', 'slum') else 'dark_steel'
    for x in (4, 36):
        t.slab(Tile.box_mask(x, 28, x + 5, 35, 1), mat, 12, bevel=0.6)
    for y in (29, 33):
        rail_ = Tile.box_mask(0, y, 63, y + 2)
        if broken and y == 33:
            rail_ &= XX < 30
        t.slab(rail_, mat, 9, bevel=0.4)
    t.noline |= (XX == 0) | (XX == 63)
    return F.finish(t, theme, rng)


def bamboo(theme, rng):
    t = F.piece()
    for k in range(9):
        x, y = rng.range(10, 54), rng.range(10, 54)
        t.slab(Tile.disk_mask(x, y, 2.4), 'grass', 26, profile='cyl')
        t.mark(Tile.disk_mask(x, y, 2.4) & Tile.disk_mask(x - 1, y - 1, 1), 1)
    for k in range(10):
        a = rng.range(0, 2 * math.pi)
        x, y = rng.range(12, 52), rng.range(12, 52)
        t.slab(Tile.line_mask(x, y, x + math.cos(a) * 9, y + math.sin(a) * 9, 2.5), 'leaf', 28, profile='dome')
    return F.finish(t, theme, rng)


def vending_neon(theme, rng):
    t = F.vending(theme, rng)
    t.emit(Tile.box_mask(10, 8, 53, 9), style(theme)['neon'][0])
    return t


# ------------------------------------------------------------------------------------------------ new ground
def plaza(theme, rng, v):
    t = Tile('walk')
    seam, cell = T.hexes(9) if False else T.pavers(16, 16, 1, 0.5)
    T._slab_seams(t, seam, 0.6)
    ring = np.abs(np.hypot((XX - 32), (YY - 32)) - 26) < 1.0
    t.paint(ring, 'inlay')
    t.paint((cell % 3 == v % 3) & ~seam, 'walk2')
    if theme != 'rich':
        T.wear(t, theme, rng, seams=seam)
    return t


def cobbles(theme, rng, v):
    t = Tile('stone')
    for y in range(0, 64, 8):
        for x in range(0, 64, 8):
            ox = 4 if (y // 8) % 2 else 0
            x0 = (x + ox) % 64
            m = Tile.box_mask(x0, y, x0 + 6, y + 6, 2) | Tile.box_mask(x0 - 64, y, x0 - 58, y + 6, 2)    # wraps at the edge
            t.slab(m, rng.pick(['stone', 'stone', 'stone_dark']), 1.5, bevel=1.2, obj=False)
    T.wear(t, theme, rng, scale=0.8, seams=t.h < 0.5)
    return t


def dirt(theme, rng, v):
    t = Tile('soil')
    t.mark(speckle(rng.int(0, 1 << 20), 0.05), -1)
    t.mark(speckle(rng.int(0, 1 << 20), 0.04), 1)
    for k in range(4):
        x, y, r = rng.range(0, 64), rng.range(0, 64), rng.range(1.0, 2.0)
        st = np.zeros((N, N), bool)
        for ox in (-64, 0, 64):
            for oy in (-64, 0, 64):
                st |= Tile.disk_mask(x + ox, y + oy, r)
        t.slab(st, 'gravel', 1, bevel=0.8, obj=False)
    t.paint(blotches(rng.int(0, 1 << 20), 0.12, cells=4), 'grass_dry')
    return t


def paddy(theme, rng, v):
    t = Tile('water')
    t.mark(speckle(rng.int(0, 1 << 20), 0.02), 1)
    for y in range(4, 64, 8):
        for x in range(4, 64, 8):
            sp = Tile.line_mask(x - 1, y + 1, x + 1, y - 2, 1.2) | Tile.line_mask(x + 1, y + 1, x + 2, y - 2, 1.0)
            t.slab(sp, 'leaf', 2, bevel=0, obj=False)
    return t


BUILDERS = {
    'f_trl_tree_street': tree_street, 'f_trl_hedge': hedge, 'f_trl_shrub_wild': shrub_wild, 'f_trl_flowerbed': flowerbed,
    'f_trl_statue': statue, 'f_trl_statue_broken': lambda th, r: statue(th, r, broken=True), 'f_trl_fountain': fountain,
    'f_trl_column': column, 'f_trl_column_broken': lambda th, r: column(th, r, broken=True),
    'f_trl_streetlight': streetlight, 'f_trl_streetlight_broken': lambda th, r: streetlight(th, r, broken=True),
    'f_trl_bench': bench, 'f_trl_bench_broken': lambda th, r: bench(th, r, broken=True),
    'f_trl_neon_cyan': neon('neon_cyan'), 'f_trl_neon_green': neon('neon_green'), 'f_trl_neon_violet': neon('neon_violet'),
    'f_trl_neon_amber': neon('neon_amber'), 'f_trl_neon_red': neon('neon_red'),
    'f_trl_spill_chem': lambda th, r: spill(th, r, 'chem'), 'f_trl_spill_oil': lambda th, r: spill(th, r, 'oil'),
    'f_trl_puddle': lambda th, r: spill(th, r, 'water'), 'f_trl_trash': trash,
    'f_trl_fuel_tank': fuel_tank, 'f_trl_barrels': barrels, 'f_trl_machinery': machinery, 'f_trl_robot_arm': robot_arm,
    'f_trl_pipes': pipes, 'f_trl_pallet': pallet, 'f_trl_generator': generator,
    'f_trl_woodpile': woodpile, 'f_trl_well': well, 'f_trl_haystack': haystack, 'f_trl_fence': fence,
    'f_trl_fence_broken': lambda th, r: fence(th, r, broken=True), 'f_trl_bamboo': bamboo,
}

GROUND = {'t_trl_plaza': plaza, 't_trl_cobbles': cobbles, 't_trl_dirt': dirt, 't_trl_paddy': paddy}
