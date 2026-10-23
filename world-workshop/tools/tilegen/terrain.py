"""Ground tiles: walkways, roads, floors, grass, water, natural ground, rails and the utility pieces (stairs,
elevators, ladders, manholes).  Each builder is (theme, rng, variant) -> Tile and draws the theme's version: the same
id is marble downtown, saw-cut concrete in mid-town, cracked and patched in the slums, earth in the country and steel
plate in the docks.  Every ground tile wraps at its edges."""
import math

import numpy as np

from canvas import Tile, N, XX, YY, Rng, pavers, grid, planks, hexes, cracks, speckle, blotches, periodic_noise
from themes import style


# ------------------------------------------------------------------------------------------------ wear
def wear(t, theme, rng, region=None, scale=1.0, seams=None):
    """the theme's wear on a surface: cracks, grime, moss in the seams, rust stains, litter, puddles"""
    st = style(theme)
    region = t.solid & ~t.obj if region is None else region
    s = rng.int(0, 1 << 20)
    if st['cracks'] * scale > 0.05 and rng.chance(min(1.0, st['cracks'] * scale * 1.3)):
        c = cracks(s, n=1 + int(st['cracks'] * scale * 3), length=10 + 24 * st['cracks'] * scale, region=region) & region
        t.carve(c, 1.2)
        t.mark(c, -1)
    if st['grime'] * scale > 0.02:
        g = blotches(s + 1, st['grime'] * scale * 0.6, cells=4) & region
        t.mark(g, -1)
    if seams is not None and st['moss'] * scale > 0.05:
        m = seams & blotches(s + 2, min(0.9, st['moss'] * scale * 0.8), cells=4) & region
        t.paint(m, 'moss')
    if st['litter'] * scale > 0.02:
        lit = speckle(s + 3, st['litter'] * scale * 0.012) & region
        t.paint(lit, rng.pick(['paper', 'plastic_r', 'plastic_b', 'grime']))
    return t


def _slab_seams(t, seam, depth=0.8, d=-1):
    t.carve(seam, depth)
    t.mark(seam, d)


# ------------------------------------------------------------------------------------------------ walkways and roads
def sidewalk(theme, rng, v):
    t = Tile('walk')
    if theme == 'rich':
        seam, cell = pavers(32, 16, 1)
        _slab_seams(t, seam, 0.6, -1)
        # alternate slabs in a paler stone, a teal inlay line along every fourth row
        alt = ((cell * 7 + v) % 5 == 0) & ~seam
        t.paint(alt, 'walk2')
        inl = (YY % 32 == 8) & ~seam
        t.paint(inl, 'inlay')
    elif theme == 'mid':
        seam, cell = grid(32, 32, 1)
        _slab_seams(t, seam, 0.8)
        cut = ((YY % 32 == 16) | (XX % 32 == 16)) & ~seam
        t.mark(cut, -1)
        t.paint((cell % 3 == v % 3) & ~seam & ~cut, 'walk2')
        wear(t, theme, rng, seams=seam)
    elif theme == 'slum':
        seam, cell = grid(32, 32, 1)
        _slab_seams(t, seam, 1.0)
        # a patched slab and a sunken one
        p = (cell == (v % 4) * 1000 + (v // 4) % 2) & ~seam
        t.paint(p, 'walk2')
        t.carve(Tile.box_mask(4 + v * 7 % 20, 36, 22 + v * 7 % 20, 50, 3) & ~seam, 0.6)
        wear(t, theme, rng, scale=1.2, seams=seam)
        if rng.chance(0.4):
            pud = blotches(rng.int(0, 1 << 20), 0.06, cells=4)
            t.slab(pud, 'water_murk', 0.0, obj=False)
    elif theme == 'rural':
        t.m[:] = 'walk'
        t.mark(speckle(rng.int(0, 99999), 0.05), -1)
        t.mark(speckle(rng.int(0, 99999), 0.03), 1)
        # stepping stones
        for k in range(2 + v % 2):
            cx, cy = rng.range(10, 54), rng.range(10, 54)
            r = rng.range(6, 9)
            t.slab(Tile.disk_mask(cx, cy, r, r * 0.8), 'walk2', 1.5, bevel=2.0, obj=False)
        g = blotches(rng.int(0, 1 << 20), 0.15, cells=4) & (t.m == 'walk')
        t.paint(g, 'grass')
    else:   # industry: diamond plate walkway
        t.m[:] = 'walk'
        _diamond(t, 'walk')
        seam, cell = grid(32, 32, 1)
        _slab_seams(t, seam, 0.6)
        wear(t, theme, rng, seams=seam)
    return t


def _diamond(t, mat, pitch=8):
    """raised diamond-plate studs"""
    for k in range(2):
        u = (XX + YY + k * pitch // 2) % pitch
        w = (XX - YY + k * pitch // 2) % pitch
        stud = (np.abs(u - pitch / 2) < 1.2) & (np.abs(w - pitch / 2) < 2.6) & (((XX // (pitch // 2) + YY // (pitch // 2)) % 2) == k)
        t.h[stud] += 0.9
        t.mark(stud, 1)


def pavement(theme, rng, v):
    """the road surface; lane paint is added by the game"""
    t = Tile('road')
    agg = speckle(rng.int(0, 1 << 20), 0.06)
    t.mark(agg, 1 if theme != 'rural' else -1)
    agg2 = speckle(rng.int(0, 1 << 20), 0.04)
    t.mark(agg2, -1)
    if theme == 'rich':
        pass
    elif theme == 'mid':
        if v % 3 == 0:
            wear(t, theme, rng, scale=0.6)
    elif theme == 'slum':
        wear(t, theme, rng, scale=0.8)
        if v % 3 == 0:
            # an asphalt patch and a pothole
            p = Tile.box_mask(rng.int(4, 30), rng.int(4, 30), rng.int(34, 58), rng.int(34, 58), 2)
            t.paint(p, 'walk2')
            t.mark(p & ~np.roll(p, 1, 0) | p & ~np.roll(p, 1, 1), -1)
        if v % 6 == 1:
            ph = Tile.disk_mask(rng.range(14, 50), rng.range(14, 50), rng.range(4, 6), rng.range(3, 5))
            t.carve(ph, 2.5)
            t.paint(ph & Tile.disk_mask(32, 32, 64), 'water_murk')
    elif theme == 'rural':
        # a dirt road: two ruts along it, stones, grass at the crown
        rut = (np.abs((YY + 6 * np.sin(XX * 2 * math.pi / 64)) % 64 - 18) < 3) | (np.abs((YY + 6 * np.sin(XX * 2 * math.pi / 64)) % 64 - 46) < 3)
        t.carve(rut, 1.0)
        t.mark(rut, -1)
        crown = np.abs((YY + 6 * np.sin(XX * 2 * math.pi / 64)) % 64 - 32) < 3
        t.paint(crown & blotches(rng.int(0, 1 << 20), 0.5, cells=8), 'grass_dry')
        for k in range(3):
            st = Tile.disk_mask(rng.range(2, 62), rng.range(2, 62), rng.range(1.2, 2.2))
            t.slab(st, 'gravel', 1.0, bevel=1, obj=False)
    else:
        seam, cell = grid(64, 32, 1)
        _slab_seams(t, seam, 0.8)
        oil = blotches(rng.int(0, 1 << 20), 0.08 + 0.04 * (v % 2), cells=4)
        t.paint(oil, 'oil')
        wear(t, theme, rng, scale=0.8)
    return t


def concrete(theme, rng, v):
    t = Tile('concrete')
    seam, cell = grid(32, 32, 1)
    _slab_seams(t, seam, 0.6)
    if theme == 'rich':
        t.paint((cell % 2 == 0) & ~seam, 'walk2')
    else:
        wear(t, theme, rng, seams=seam)
    return t


def floor(theme, rng, v):
    """the generic indoor floor"""
    if theme == 'rich':
        t = Tile('floor')
        seam, cell = grid(32, 32, 1)
        _slab_seams(t, seam, 0.4)
        # marble veins: thin wandering lines in each slab
        vein = cracks(rng.int(0, 1 << 20), n=2, length=30, branch=0.15) & ~seam
        t.paint(vein, 'vein')
        t.paint(((cell // 1000 + cell) % 2 == 1) & ~seam & ~vein, 'floor2')
        return t
    if theme == 'mid':
        t = Tile('floor')
        seam, cell = grid(16, 16, 1)
        _slab_seams(t, seam, 0.4)
        t.paint((cell * 31 % 7 == v % 7) & ~seam, 'floor2')
        wear(t, theme, rng, scale=0.5)
        return t
    if theme == 'slum':
        t = Tile('floor')
        seam, cell = grid(16, 16, 1)
        _slab_seams(t, seam, 0.5)
        miss = (cell * 13 % 17 == v % 17) & ~seam
        t.paint(miss, 'concrete')
        t.carve(miss, 0.8)
        wear(t, theme, rng, scale=0.35, seams=seam)
        return t
    if theme == 'rural':
        return _boards(theme, rng, v, 'floor', 'floor2', 8)
    t = Tile('floor')
    seam, cell = grid(32, 32, 1)
    _slab_seams(t, seam, 0.6)
    _rivets(t, seam, 'floor')
    wear(t, theme, rng, scale=0.7)
    return t


def _rivets(t, seam, mat, inset=3):
    for x in range(inset, N, 32):
        for y in range(inset, N, 32):
            for dx, dy in ((0, 0), (32 - 2 * inset - 1, 0), (0, 32 - 2 * inset - 1), (32 - 2 * inset - 1, 32 - 2 * inset - 1)):
                d = Tile.disk_mask((x + dx) % N + 0.5, (y + dy) % N + 0.5, 1.1)
                t.h[d] += 0.8
                t.mark(d, 1)


def _boards(theme, rng, v, a='wood', b='wood_dark', w=8, vertical=False):
    t = Tile(a)
    seam, cell = planks(w, 32, 1, vertical=vertical, seed=v + 3)
    _slab_seams(t, seam, 0.6)
    t.paint((cell * 7 % 3 == 0) & ~seam, b)
    grain = ((((XX if not vertical else YY) + (cell * 11 % 7) * 5) % 16) == 0) & ~seam        # period 16: wraps
    t.mark(grain, -1)
    return t


def grass(theme, rng, v, grazed=False):
    """grass as small tufts on a flat ground colour (a lit tip over a dark root), never broad blotches; density, dry
    patches and flowers differ by theme"""
    mat = 'grass' if theme != 'slum' or v % 2 else 'grass_dry'
    t = Tile(mat)
    dens = {'rich': 0.10, 'mid': 0.08, 'slum': 0.06, 'rural': 0.12, 'industry': 0.06}[theme]
    if theme == 'rich' and not grazed:
        dens_map = np.where((XX // 16) % 2 == 0, 1.25, 0.75)          # mowing stripes, by tuft density alone
    else:
        dens_map = 1.0
    fine = np.array([[(__import__('canvas')._hash(rng.int(0, 1 << 20) if False else v * 7 + 3, x, y) & 1023) / 1023.0
                      for x in range(N)] for y in range(N)])
    tip = fine < dens * dens_map
    t.mark(tip, 1)
    t.mark(np.roll(tip, 1, 0) & ~tip, -1)
    dark = (fine > 1 - dens * 0.6)
    t.mark(dark, -1)
    if theme == 'rich' and not grazed:
        fl = speckle(rng.int(0, 1 << 20), 0.004, cells=8)
        t.paint(fl, rng.pick(['blossom', 'paint_w']))
    if theme == 'slum':
        bare = blotches(rng.int(0, 1 << 20), 0.18, cells=8, octaves=3)
        t.paint(bare, 'soil')
        t.mark(bare & speckle(rng.int(0, 1 << 20), 0.05), -1)
        lit = speckle(rng.int(0, 1 << 20), 0.004, cells=8)
        t.paint(lit, rng.pick(['paper', 'plastic_r']))
    if theme == 'rural' and not grazed:
        tall = speckle(rng.int(0, 1 << 20), 0.05, cells=4)
        t.mark(tall | np.roll(tall, 1, 0), 1)
        t.mark(np.roll(tall, 2, 0) & ~tall, -1)
        if v % 3 == 0:
            fl = speckle(rng.int(0, 1 << 20), 0.004, cells=8)
            t.paint(fl, rng.pick(['paint_y', 'paint_w', 'blossom']))
    if theme == 'industry':
        t.paint(speckle(rng.int(0, 1 << 20), 0.06, cells=4) | np.roll(speckle(rng.int(0, 1 << 20), 0.06, cells=4), 1, 1), 'moss')
        t.paint(blotches(rng.int(0, 1 << 20), 0.1, cells=8, octaves=3), 'soil')
    if grazed:
        t.paint(blotches(rng.int(0, 1 << 20), 0.22, cells=8, octaves=3), 'grass_dry' if theme != 'rural' else 'soil')
    return t


def water(theme, rng, v, murky=False):
    mat = 'water_murk' if murky or theme in ('slum', 'industry') else 'water'
    t = Tile(mat)
    ph = v * 1.7
    wav = np.sin((XX * 2 * math.pi / 32) + np.sin(YY * 2 * math.pi / 64 + ph) * 2.0) * np.sin((YY * 2 * math.pi / 32) + ph)
    t.h += wav.astype(np.float32) * 0.6
    caust = (np.abs(wav) < 0.08) & (periodic_noise(rng.int(0, 1 << 20), 8, 1) > 0.45)
    t.mark(caust, 1 if mat == 'water' else 0)
    if mat == 'water_murk':
        sheen = blotches(rng.int(0, 1 << 20), 0.12, cells=4)
        t.paint(sheen, 'oil')
        foam = speckle(rng.int(0, 1 << 20), 0.01) & blotches(rng.int(0, 1 << 20), 0.3, cells=4)
        t.paint(foam, 'foam')
    if theme == 'rich':
        t.mark(speckle(rng.int(0, 1 << 20), 0.01), 2)
    return t


def natural(kind, theme, rng, v):
    """sand, gravel, rock floor, rock, red rock"""
    if kind == 'sand':
        t = Tile('sand')
        rip = (np.sin((XX + YY * 0.25) * 2 * math.pi / 16 + np.sin(YY * 2 * math.pi / 64) * 2) > 0.7)     # 64 * 0.25 = one period: wraps
        t.mark(rip, -1)
        t.mark(speckle(rng.int(0, 1 << 20), 0.02), 1)
        return t
    if kind == 'gravel':
        t = Tile('gravel')
        for k in range(70):
            x, y = rng.range(0, 64), rng.range(0, 64)
            r = rng.range(1.0, 2.2)
            m = np.zeros((N, N), bool)
            for ox in (-64, 0, 64):
                for oy in (-64, 0, 64):
                    m |= Tile.disk_mask(x + ox, y + oy, r)          # one stone, wrapped round the tile edge
            t.slab(m, 'gravel' if k % 4 else 'stone', 1.2, bevel=1.0, obj=False)
        return t
    if kind in ('rock_floor',):
        t = Tile('rock')
        seam = cracks(rng.int(0, 1 << 20), n=4, length=30, branch=0.5)
        _slab_seams(t, seam, 1.0)
        t.mark(speckle(rng.int(0, 1 << 20), 0.03), 1)
        if theme in ('industry', 'slum'):
            t.paint(blotches(rng.int(0, 1 << 20), 0.15, cells=4), 'moss')
        return t
    mat = 'rock_red' if kind == 'rock_red' else 'rock'
    t = Tile(mat, periodic=True)
    # boulders: faceted lumps that fill the cell (impassable rock)
    for k in range(6):
        x, y = rng.range(0, 64), rng.range(0, 64)
        r = rng.range(10, 18)
        hgt = rng.range(4, 9)
        m = np.zeros((N, N), bool)
        for ox in (-64, 0, 64):
            for oy in (-64, 0, 64):
                m |= Tile.disk_mask(x + ox, y + oy, r, r * 0.8)
        t.slab(m, mat, hgt, bevel=5, obj=False, profile='dome', wrap=True)
    t.mark(cracks(rng.int(0, 1 << 20), n=3, length=18), -1)
    if theme in ('rural', 'industry'):
        t.paint(blotches(rng.int(0, 1 << 20), 0.12, cells=4) & (t.h > 3), 'moss')
    return t


# ------------------------------------------------------------------------------------------------ metal and utility
def metal_floor(theme, rng, v):
    t = Tile('metalfloor')
    seam, cell = grid(32, 32, 1)
    _slab_seams(t, seam, 0.6)
    _diamond(t, 'metalfloor')
    if theme != 'rich':
        wear(t, theme, rng, scale=0.8, seams=seam)
    return t


def roof(theme, rng, v):
    t = Tile('roof')
    if theme in ('slum', 'rural'):
        # corrugated sheet / tiles
        rib = (XX % 8) < 3 if theme == 'slum' else ((YY % 8) < 2)
        t.h[rib] += 1.0
        t.mark(rib, 1)
        if theme == 'slum':
            t.paint(blotches(rng.int(0, 1 << 20), 0.25, cells=4), 'rust')
        else:
            t.mark((XX + (YY // 8) * 4) % 8 == 0, -1)
    else:
        seam, cell = grid(32, 32, 1)
        _slab_seams(t, seam, 0.6)
        vent = Tile.box_mask(40, 8, 54, 20, 1) if v % 2 == 0 else Tile.box_mask(8, 40, 22, 54, 1)
        t.slab(vent, 'steel', 3, bevel=1)
        t.mark(vent & ((YY % 3) == 0), -1)
        if theme == 'industry':
            wear(t, theme, rng, seams=seam)
    return t


def gangway(theme, rng, v):
    """steel grating over a dark void"""
    t = Tile('dark_steel')
    t.h[:] = -2
    t.mark(np.ones((N, N), bool), -2)
    bars = ((XX % 8) < 2) | ((YY % 16) < 2)
    t.slab(bars, 'metalfloor' if theme != 'rich' else 'steel', 2.0, bevel=0, obj=False)
    t.mark(bars & ((XX % 8) == 0), 1)
    return t


def rail(theme, rng, v, vertical=False):
    t = Tile('gravel')
    t.mark(speckle(rng.int(0, 1 << 20), 0.1), -1)
    t.mark(speckle(rng.int(0, 1 << 20), 0.06), 1)
    a, b = (YY, XX) if vertical else (XX, YY)
    sl = ((a % 16) >= 3) & ((a % 16) < 11)
    t.slab(sl & (b >= 6) & (b <= 57), 'sleeper' if theme != 'rich' else 'concrete', 2.0, bevel=1, obj=False)
    for r0 in (18, 44):
        rl = (b >= r0) & (b <= r0 + 3)
        t.slab(rl, 'rail', 4.0, bevel=1.0, obj=False)
        t.mark(rl & (b == r0 + 1), 1)
    if theme in ('slum', 'industry'):
        t.paint(blotches(rng.int(0, 1 << 20), 0.2, cells=4) & (t.m == 'rail'), 'rust')
    return t


def manhole(theme, rng, v):
    t = sidewalk(theme, Rng(v, 5), 0) if theme != 'industry' else floor(theme, Rng(v, 5), 0)
    t.periodic = True
    lid = Tile.disk_mask(32, 32, 20)
    t.ground('dark_steel', lid, h=0.3)
    t.mark(lid & ~Tile.disk_mask(32, 32, 19), -2)
    ring = Tile.disk_mask(32, 32, 16) & ~Tile.disk_mask(32, 32, 14.5)
    t.mark(ring, 1)
    grip = (np.abs(XX - 32) < 9) & (np.abs(YY - 32) < 9) & (((XX + YY) % 6) < 2)
    t.mark(grip & lid, 1)
    if theme in ('slum', 'industry'):
        t.paint(blotches(rng.int(0, 1 << 20), 0.3, cells=4) & lid, 'rust')
    return t


def stairs_up(theme, rng, v):
    t = floor(theme, rng, v)
    t.periodic = False
    for k in range(6):
        y0 = 6 + k * 9
        step = Tile.box_mask(10, y0, 53, y0 + 8)
        t.slab(step, 'top' if theme != 'industry' else 'metalfloor', 12 - k * 2, bevel=0.8)
        t.mark(step & (YY == y0), 1)
    rail_ = Tile.box_mask(7, 4, 9, 59) | Tile.box_mask(54, 4, 56, 59)
    t.slab(rail_, 'trim', 14, bevel=0.6)
    arrow = Tile.poly_mask([(32, 9), (40, 17), (35, 17), (35, 24), (29, 24), (29, 17), (24, 17)])
    t.emit(arrow, style(theme)['neon'][0])
    return t


def elevator(theme, rng, v):
    t = floor(theme, rng, v)
    t.periodic = False
    frame = Tile.box_mask(6, 6, 57, 57, 3)
    t.slab(frame, 'trim', 3, bevel=1.2)
    doors = Tile.box_mask(10, 10, 31, 53) | Tile.box_mask(33, 10, 53, 53)
    t.slab(doors, 'steel' if theme != 'rural' else 'wood', 2, bevel=0.8)
    t.mark(Tile.box_mask(32, 10, 32, 53), -2)
    t.emit(Tile.box_mask(28, 6, 36, 8), 'lamp_cold' if style(theme)['lights'] > 0.5 else 'lamp_dead')
    return t


def ladder(theme, rng, v):
    t = floor(theme, rng, v)
    t.periodic = False
    hole = Tile.box_mask(12, 4, 51, 59, 2)
    t.ground('ink', hole, h=-6)
    t.mark(hole, -2)
    rails = Tile.box_mask(16, 2, 19, 61) | Tile.box_mask(44, 2, 47, 61)
    t.slab(rails, 'steel', 3, bevel=0.8)
    for y in range(8, 60, 9):
        t.slab(Tile.box_mask(16, y, 47, y + 2), 'steel', 2.5, bevel=0.6)
    if theme in ('slum', 'industry'):
        t.paint(blotches(rng.int(0, 1 << 20), 0.3, cells=4) & t.obj, 'rust')
    return t


def glass_railing(theme, rng, v):
    t = Tile('', periodic=False)
    pane = Tile.box_mask(0, 26, 63, 37)
    t.slab(pane, 'glass', 8, bevel=1)
    t.mark(pane & ((XX + YY) % 11 == 0), 2)
    top = Tile.box_mask(0, 26, 63, 27)
    t.slab(top, 'trim', 9, bevel=0)
    t.noline |= (XX == 0) | (XX == 63)
    return t


# ------------------------------------------------------------------------------------------------ special floors
def special_floor(kind, theme, rng, v):
    if kind == 'checker':
        t = Tile('checker_w')
        cell = ((XX // 16 + YY // 16) % 2) == 1
        t.paint(cell, 'checker_k')
        t.mark((XX % 16 == 0) | (YY % 16 == 0), -1)
    elif kind == 'church':
        t = Tile('stone')
        seam, cell = grid(32, 32, 1)
        _slab_seams(t, seam, 0.5)
        diam = (np.abs(XX % 32 - 16) + np.abs(YY % 32 - 16)) < 8
        t.paint(diam, 'carpet_red' if theme != 'slum' else 'stone_dark')
        t.paint((np.abs(XX % 32 - 16) + np.abs(YY % 32 - 16) < 3), 'gold')
    elif kind == 'hinoki':
        t = _boards(theme, rng, v, 'wood_light', 'wood_light', 10)
    elif kind == 'clean':
        t = Tile('linen')
        seam, cell = grid(32, 32, 1)
        _slab_seams(t, seam, 0.3)
    elif kind == 'marble':
        t = Tile('floor' if theme == 'rich' else 'linen')
        seam, cell = grid(32, 32, 1)
        _slab_seams(t, seam, 0.3)
        vein = cracks(rng.int(0, 1 << 20), n=3, length=40, branch=0.4) & ~seam
        t.paint(vein, 'vein' if theme == 'rich' else 'stone')
    elif kind == 'steel':
        t = metal_floor(theme, rng, v)
    elif kind == 'wood':
        t = _boards(theme, rng, v, 'wood', 'wood_dark', 8)
    elif kind == 'tatami':
        t = Tile('tatami')
        seam = (XX % 64 < 2) | (YY % 32 < 2)
        t.paint(seam, 'fabric_g')
        t.mark((XX % 3 == 0) & ~seam, -1)
    elif kind == 'carpet_red':
        t = Tile('carpet_red')
        t.mark(speckle(rng.int(0, 1 << 20), 0.05), -1)
        border = ((XX % 64) < 4) | ((XX % 64) > 59)
        t.paint(border & ((YY % 8) < 6), 'gold')
    if theme in ('slum',) and kind not in ('steel',):
        wear(t, theme, rng, scale=0.6)
    return t
