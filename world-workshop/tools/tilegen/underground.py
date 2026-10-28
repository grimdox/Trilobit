"""The underground: subway tunnels and stations, the sewers, maintenance passages and basements.

Drawn only into the industry set, which the game uses below ground.

  linings   the concrete (subway, service tunnels) or brick (sewers) the passages are cut through: 16 shapes by which
            sides open onto a passage, the side facing a passage to the south shows its face like a wall
  floors    tunnel walkway, station platform, subway track (and turned), sewer catwalk, dirty water
  fittings  on the linings, along the passage: pipe runs, cable trays, ductwork, electrical panels, valves, fans,
            caged lamps, graffiti (shapes and colour only, never letters), the platform's tactile edge; on the floor:
            puddles, drains, rubbish.  Each drawn facing south (on a wall to the north of the passage) and turned for
            the other three sides.
"""
import math

import numpy as np

from canvas import Tile, N, XX, YY, Rng, blotches, cracks, speckle, grid, planks, _hash, periodic_noise
from furniture import piece
import terrain as T

FACE = 14
H = 16.0


def D(cx, cy, r, ry=None):
    return Tile.disk_mask(cx, cy, r, ry)


def B(x0, y0, x1, y1, r=0.0):
    return Tile.box_mask(x0, y0, x1, y1, r)


def L(x0, y0, x1, y1, w=1.0):
    return Tile.line_mask(x0, y0, x1, y1, w)


def _block(join, d=0):
    bottom = N - 1 if join & 4 else N - 1 - FACE
    return Tile.box_mask(0 if join & 8 else d, 0 if join & 1 else d, N - 1 if join & 2 else N - 1 - d,
                         bottom if join & 4 else bottom - d)


# ------------------------------------------------------------------------------------------------ linings
def lining(theme, rng, v, opn, brick=False):
    """the solid mass beside a passage; opn = the sides that open onto it (1 N, 2 E, 4 S, 8 W)"""
    join = 15 & ~opn
    t = Tile('', periodic=False)
    m = _block(join)
    mat = 'brick_dark' if brick else 'conc_dark'
    t.slab(m, mat, H, bevel=1.0)
    inner = _block(join, 3)
    edge = m & ~inner
    if brick:
        # brick courses on top, a soldier course along each open edge
        # the top of an old brick wall: dark, slick with slime, a stone coping along the open edges
        course = (YY % 6) == 0
        bond = ((XX + (YY // 6) % 2 * 6) % 12) == 0
        t.mark((course | bond) & inner, -1)
        t.paint(blotches(_hash('bk', v), 0.14, cells=8) & inner, 'moss')
        t.mark(blotches(_hash('bks', v), 0.3, cells=4) & inner, -1)
        cope = m & ~_block(join, 5)
        t.paint(cope, 'conc_struct')
        t.h[cope] += 0.6
        t.mark(cope & ((XX % 12) == 0) & ((YY % 12) == 0), -1)
    else:
        # precast segments: joints every 32 px, bolt pockets in pairs, the grout lines stained
        seam = ((XX % 32) == 0) | ((YY % 32) == 0)
        t.carve(seam & inner, 0.8)
        t.mark(seam & inner, -1)
        for bx in range(8, 64, 32):
            for by in range(8, 64, 32):
                for dx in (0, 16):
                    pk = B(bx + dx, by, bx + dx + 3, by + 3) & inner
                    t.carve(pk, 1.2)
                    t.paint(pk, 'conc_shadow')
                    t.paint(D(bx + dx + 1.5, by + 1.5, 0.9) & pk, 'dark_steel')
        t.paint(edge, 'conc_shadow')
        damp = blotches(_hash('dp', v), 0.22, cells=4) & m
        t.mark(damp, -1)
        t.paint(blotches(_hash('ef', v), 0.025, cells=8) & m & ~seam, 'efflor')
    # the face toward a passage to the south: the lining's wall, streaked by water and rust from the bolts
    if opn & 4:
        face = np.zeros((N, N), bool)
        for k in range(1, FACE + 1):
            sh = np.zeros((N, N), bool)
            sh[k:, :] = m[:N - k, :]
            face |= sh & ~m
        t.m[face] = 'conc_struct' if not brick else 'brick'
        t.solid |= face
        t.obj |= face
        yy = np.zeros((N, N), np.float32)
        for k in range(1, FACE + 1):
            sh = np.zeros((N, N), bool)
            sh[k:, :] = m[:N - k, :]
            yy = np.where(sh & ~m & (yy == 0), k, yy)
        t.h = np.where(face, H - yy * 0.25, t.h).astype(np.float32)
        t.mark(face & np.roll(m, 1, 0), 1)
        r = Rng('streak', v)
        for k in range(5):
            x = r.int(2, 61)
            ln = r.int(3, FACE)
            st = face & (XX >= x) & (XX <= x + (1 if k % 2 else 0)) & (yy <= ln)
            t.paint(st, 'rust' if k % 3 == 0 else 'efflor')
        if brick:
            t.mark(face & ((yy.astype(int) % 3) == 0), -1)
        else:
            t.mark(face & ((XX % 32) == 0), -1)
    for bit, mask in ((1, YY == 0), (2, XX == N - 1), (4, YY == N - 1), (8, XX == 0)):
        if join & bit:
            t.noline |= mask
    t.drop_shadow(t.solid.copy(), 4, 4, 0.4)
    return t


# ------------------------------------------------------------------------------------------------ floors (ground)
def tunnel_floor(theme, rng, v):
    """the service walkway beside the tracks: cast concrete, saw cuts, damp, oil, a cable duct cover in v1"""
    t = Tile('conc_struct')
    seam, cell = grid(32, 64, 1)
    T._slab_seams(t, seam, 0.6)
    t.mark(speckle(_hash('tf', v), 0.04), -1)
    t.mark(blotches(_hash('td', v), 0.25, cells=4), -1)
    t.paint(blotches(_hash('to', v), 0.05, cells=8), 'oil')
    if v == 1:
        # a drain gully across the walkway
        g = (XX >= 28) & (XX < 36)
        t.paint(g, 'dark_steel')
        t.h[g] -= 1.0
        t.mark(g & ((YY % 3) == 0), 1)
    if v == 2:
        t.paint(blotches(_hash('tm', v), 0.12, cells=8), 'moss')
    return t


def platform(theme, rng, v):
    """the station floor: large terrazzo tiles, polished where people walk, grimy at the joints"""
    t = Tile('terrazzo')
    seam, cell = grid(32, 32, 1)
    t.paint(seam, 'grout')
    t.carve(seam, 0.3)
    t.paint(((cell // 1000 + cell) % 2 == 1) & ~seam, 'terrazzo2')
    t.mark(speckle(_hash('tz', v), 0.05) & ~seam, 1)
    t.mark(speckle(_hash('tz2', v), 0.04) & ~seam, -1)
    if v == 1:
        t.mark(blotches(_hash('tw', v), 0.18, cells=4) & ~seam, -1)
    if v == 2:
        # a dark band inlaid round each pair of tiles
        inl = (((XX % 64) == 2) | ((XX % 64) == 61) | ((YY % 64) == 2) | ((YY % 64) == 61))
        t.paint(inl, 'conc_dark')
    return t


def track(theme, rng, v, vertical=False):
    """subway track on a concrete bed: rails on twin-block sleepers, a drain down the middle, the third rail under its
    cover along one side"""
    t = Tile('conc_dark')
    a, b = (YY, XX) if vertical else (XX, YY)
    t.mark(speckle(_hash('tb', v), 0.08), -1)
    drain = (b >= 30) & (b <= 33)
    t.carve(drain, 1.0)
    t.paint(drain, 'sludge' if v != 1 else 'oil')
    sl = ((a % 16) >= 4) & ((a % 16) < 12)
    for b0, b1 in ((10, 24), (40, 54)):
        t.slab(sl & (b >= b0) & (b <= b1), 'conc_struct', 1.6, bevel=0.8, obj=False)
    for r0 in (15, 45):
        rl = (b >= r0) & (b <= r0 + 3)
        t.slab(rl & sl & (b >= r0 - 2), 'dark_steel', 2.2, bevel=0, obj=False)
        t.slab(rl, 'rail', 4.0, bevel=1.0, obj=False)
        t.mark(rl & (b == r0 + 1), 2)
    # the third rail: a steel bar on insulators, a yellow cover over it
    tr = (b >= 2) & (b <= 6)
    t.slab(tr, 'insul', 3.0, bevel=0.6, obj=False)
    t.mark(tr & (b == 2), 1)
    t.mark(tr & ((a % 32) == 0), -2)
    if v == 2:
        t.paint(blotches(_hash('tr', v), 0.2, cells=4) & (t.m == 'rail'), 'rust')
    return t


def sewer_walk(theme, rng, v):
    """the catwalk along a sewer channel: old brick paving, a steel grating over a gully in v1, slime in the joints"""
    t = Tile('brick')
    seam, cell = T.pavers(16, 8, 1)
    t.paint(seam, 'mortar')
    t.carve(seam, 0.5)
    t.paint(((cell * 7) % 5 == 0) & ~seam, 'brick_worn')
    t.mark(((cell * 3) % 4 == 0) & ~seam, 1)
    t.paint(blotches(_hash('sw', v), 0.18, cells=4) & seam, 'moss')
    t.mark(blotches(_hash('swd', v), 0.3, cells=4), -1)
    if v == 1:
        g = (XX >= 20) & (XX < 44)
        t.paint(g, 'dark_steel')
        t.h[g] -= 1.5
        bars = g & ((XX % 4) < 2)
        t.slab(bars, 'metalfloor', 1.5, bevel=0, obj=False)
    return t


def sludge(theme, rng, v):
    """the sewer channel: slow black-green water, a skin of foam and oil drifting with the flow, rubbish caught in it"""
    t = Tile('sludge')
    flow = np.sin((XX * 2 * math.pi / 64) * 2 + np.sin(YY * 2 * math.pi / 64 * 2 + v) * 1.2)
    t.mark(flow > 0.75, 1)
    t.mark(flow < -0.8, -1)
    deep = periodic_noise(_hash('sd', v), 4, 2) > 0.6
    t.paint(deep, 'sludge_deep')
    foam = (periodic_noise(_hash('sf', v), 8, 2) > 0.72) & (flow > 0.2)
    t.paint(foam, 'foam')
    t.mark(foam & speckle(_hash('sff', v), 0.3), 1)
    sheen = (periodic_noise(_hash('so', v), 8, 1) > 0.8)
    t.paint(sheen & ~foam, 'oil')
    t.mark(sheen & ~foam & ((XX + YY) % 5 == 0), 2)
    r = Rng('sl', v)
    for k in range(2 + v):
        x, y = r.range(8, 56), r.range(8, 56)
        kind = r.int(0, 2)
        if kind == 0:
            t.slab(B(x, y, x + 5, y + 3, 1), 'plastic_w', 0.8, bevel=0.3, obj=False)
        elif kind == 1:
            t.slab(D(x, y, 2.2), 'kraft', 0.8, profile='dome', obj=False)
        else:
            t.slab(L(x, y, x + 6, y + 2, 1.6), 'plastic_b', 0.8, bevel=0, obj=False)
    return t


# ------------------------------------------------------------------------------------------------ fittings (objects)
# all drawn for a wall to the north of the passage: the fitting lies along the wall's south edge (y 40..63), over its
# face; the catalogue turns them for walls to the east, south and west of the passage
def _run(t):
    t.noline |= (XX == 0) | (XX == N - 1)


def pipes(theme, rng, v):
    """a run of pipes along the wall: two or three bores, brackets every 16 px, a flange joint, lagging on one"""
    t = piece()
    cols = [('pipe_g', 'pipe_b', 'duct'), ('pipe_y', 'pipe_g', None), ('duct', 'pipe_b', 'pipe_y')][v % 3]
    ys = (40, 50, 58)
    for k, (y, col) in enumerate(zip(ys, cols)):
        if col is None:
            continue
        r = 4.6 if k == 0 else 3.6
        m = B(0, y - r, 63, y + r)
        t.slab(m, col, 10 - k * 2, profile='cyl' if False else 'dome')
        t.mark(m & (np.abs(YY - (y - r * 0.4)) < 0.6), 1)
        fl = m & (((XX + k * 9) % 32) < 2)
        t.slab(B(0, y - r - 1, 63, y + r + 1) & (((XX + k * 9) % 32) < 2), 'dark_steel', 11 - k * 2, bevel=0.3)
    br = ((XX % 16) == 8) | ((XX % 16) == 9)
    t.slab(B(0, 34, 63, 63) & br & (t.h < 1), 'dark_steel', 5, bevel=0.3)        # brackets, under the pipes
    if v == 2:
        lag = B(18, 34, 46, 46, 3)
        t.slab(lag, 'canvas_w', 11, profile='dome')
        t.mark(lag & ((XX % 4) == 0), -1)
    _run(t)
    return _wear(t, v)


def cables(theme, rng, v):
    """a cable tray along the wall, its cables in colours, a junction box"""
    t = piece()
    tray = B(0, 38, 63, 60)
    t.slab(tray, 'duct', 4, bevel=0.5)
    t.carve(B(0, 40, 63, 58), 2)
    t.mark(tray & ((XX % 12) == 0), -1)
    cols = ['rubber', 'pipe_y', 'rubber', 'pipe_b', 'rubber', 'pipe_g', 'rubber']
    for k, c in enumerate(cols):
        y = 41.5 + k * 2.4
        wob = np.sin(XX * 2 * math.pi / 64 * (1 + k % 2) + k) * 0.7
        m = (np.abs(YY - y - wob) < 1.1) & B(0, 40, 63, 58)
        t.slab(m, c, 3.5, bevel=0, obj=False)
        t.mark(m & (np.abs(YY - y - wob + 0.6) < 0.4), 1)
    if v == 1:
        jb = B(22, 30, 42, 60, 1)
        t.slab(jb, 'enamel_grey', 9, bevel=0.6)
        t.mark(jb & ~B(26, 40, 38, 56), -1)
        t.emit(D(36, 42, 1), 'neon_green')
    _run(t)
    return _wear(t, v)


def duct(theme, rng, v):
    """galvanised ductwork: a square duct along the wall, seams every 16 px, a branch dropping into the passage"""
    t = piece()
    m = B(0, 30, 63, 60)
    t.slab(m, 'duct', 12, bevel=1.0)
    t.mark(m & ((XX % 16) == 0), -2)
    t.mark(m & ((XX % 16) == 1), 1)
    t.mark(m & (YY == 35), 1)
    for x in range(4, 64, 8):
        t.paint(D(x, 32, 0.8) & m, 'dark_steel')
    if v == 1:
        grille = B(20, 40, 44, 56)
        t.paint(grille, 'dark_steel')
        t.mark(grille & ((YY % 2) == 0), 1)
    if v == 2:
        hang = B(26, 30, 30, 40)
        t.slab(hang, 'dark_steel', 13, bevel=0.3)
    _run(t)
    return _wear(t, v)


def panel(theme, rng, v):
    """an electrical panel on the wall: a steel cabinet, breaker lights, conduit up into the lining, a warning stripe"""
    t = piece()
    body = B(10, 24, 54, 62, 1)
    col = ['enamel_grey', 'enamel_g', 'graphite'][v % 3]
    t.slab(body, col, 12, bevel=1.0)
    t.mark(body & ~B(12, 26, 52, 60), -1)
    t.mark(B(31, 26, 32, 58), -1)
    for k in range(6):
        lit = ['neon_green', 'neon_green', 'neon_amber', 'neon_green', 'neon_cyan', 'neon_green'][(k + v) % 6]
        t.emit(B(15 + k * 6, 30, 17 + k * 6, 31), lit)
    t.slab(B(36, 38, 50, 50, 1), 'dark_steel', 13, bevel=0.4)
    t.emit(B(38, 40, 48, 45), 'screen_glow')
    t.slab(B(14, 40, 26, 46, 1), 'chrome', 13, bevel=0.4)
    haz = B(10, 56, 54, 61) & ((((XX + YY) // 3) % 2) == 0)
    t.paint(B(10, 56, 54, 61), 'hazard_y')
    t.paint(haz, 'hazard_k')
    for x in (16, 22, 44):
        t.slab(B(x, 8, x + 2, 24), 'duct', 10, bevel=0)
    return _wear(t, v)


def valve(theme, rng, v):
    """a valve station: a riser pipe, a handwheel, a gauge"""
    t = piece()
    t.slab(B(0, 46, 63, 56), 'pipe_g' if v != 1 else 'pipe_b', 9, profile='dome')
    t.slab(B(24, 30, 40, 60, 2), 'dark_steel', 11, bevel=0.6)
    wheel = D(32, 42, 13) & ~D(32, 42, 10.5)
    t.slab(wheel, 'pipe_y' if v != 2 else 'enamel_b', 14, bevel=0.4)
    for a in (0.3, math.pi / 2 + 0.3, math.pi / 4 + 0.3):
        t.slab(L(32 - math.cos(a) * 11, 42 - math.sin(a) * 11, 32 + math.cos(a) * 11, 42 + math.sin(a) * 11, 1.8), 'pipe_y' if v != 2 else 'enamel_b', 13.5, bevel=0)
    t.slab(D(32, 42, 3), 'chrome', 15, profile='dome')
    t.slab(D(52, 36, 6), 'chrome', 12, bevel=0.5)
    t.paint(D(52, 36, 4.4), 'paint_w')
    t.paint(L(52, 36, 55, 33, 0.9), 'ink')
    t.noline |= (XX == 0) | (XX == N - 1)
    return _wear(t, v)


def fan(theme, rng, v):
    """an extract fan in the wall: a ring, the blades, a mesh guard"""
    t = piece()
    cy = 44
    t.slab(B(12, cy - 20, 52, 63, 2), 'duct', 6, bevel=0.6)
    t.carve(D(32, cy, 17), 3)
    t.paint(D(32, cy, 17), 'ink')
    for k in range(5):
        a = k * 2 * math.pi / 5 + v * 0.4
        bl = Tile.poly_mask([(32, cy), (32 + math.cos(a) * 16, cy + math.sin(a) * 16), (32 + math.cos(a + 0.55) * 14, cy + math.sin(a + 0.55) * 14)])
        t.slab(bl, 'steel', 4.5, bevel=0.3)
    t.slab(D(32, cy, 3.5), 'dark_steel', 5, profile='dome')
    guard = D(32, cy, 17) & ((((XX - 32) % 4) == 0) | (((YY - cy) % 4) == 0))
    t.slab(guard, 'dark_steel', 7, bevel=0)
    return _wear(t, v)


def lamp(theme, rng, v):
    """a caged bulkhead lamp, its light pooled on the wall below it (some dead)"""
    t = piece()
    t.slab(B(22, 34, 42, 60, 5), 'dark_steel', 9, bevel=0.6)
    lens = B(25, 37, 39, 57, 4)
    if v == 2:
        t.paint(lens, 'lamp_dead')
    else:
        t.emit(lens, 'lamp' if v == 0 else 'lamp_cold')
    cage = B(24, 36, 40, 58) & ((((XX - 24) % 4) == 0) | (((YY - 36) % 6) == 0))
    t.slab(cage, 'dark_steel', 10.5, bevel=0)
    t.slab(B(0, 45, 22, 46), 'rubber', 8, bevel=0)
    t.noline |= XX == 0
    return _wear(t, v)


def graffiti(theme, rng, v):
    """paint on the lining's face and the wall foot: shapes and colour, never letters.  v0 a bubble throw-up (rounded
    blobs outlined, a highlight), v1 drips and arrows, v2 a stencilled eye in a ring"""
    t = piece()
    # the paint sits on the wall as a film: no height, no outline, only its own colours
    pal = [('spray_p', 'spray_c', 'spray_k'), ('spray_y', 'spray_k', 'spray_w'), ('spray_c', 'spray_w', 'spray_k')][v]
    if v == 0:
        blobs = D(14, 50, 11, 9) | D(30, 48, 10, 11) | D(45, 51, 11, 8) | D(56, 47, 7, 9)
        out = blobs & ~(D(14, 50, 9.5, 7.5) | D(30, 48, 8.5, 9.5) | D(45, 51, 9.5, 6.5) | D(56, 47, 5.5, 7.5))
        t.solid |= blobs
        t.m[blobs] = pal[0]
        t.m[out] = pal[2]
        t.m[blobs & ~out & ((YY - XX * 0.3) < 39)] = pal[1]
        t.m[D(24, 46, 1.5) | D(40, 47, 1.2)] = 'spray_w'
        for x in (14, 31, 45):
            d = B(x, 56, x + 1, 56 + (x % 5) + 2) & ~blobs
            t.solid |= d
            t.m[d] = pal[0]
    elif v == 1:
        for k, x in enumerate((8, 22, 36, 50)):
            ar = Tile.poly_mask([(x, 44), (x + 8, 50), (x, 56), (x + 2, 50)])
            t.solid |= ar
            t.m[ar] = pal[k % 2]
            d = B(x + 1, 56, x + 1, 56 + (k * 3) % 6 + 1)
            t.solid |= d
            t.m[d] = pal[k % 2]
        bar = B(4, 60, 60, 61)
        t.solid |= bar
        t.m[bar] = pal[2]
    else:
        ring = D(32, 48, 14) & ~D(32, 48, 12)
        eye = D(32, 48, 10, 5.5) & ~D(32, 48, 3.5)
        pupil = D(32, 48, 2.6)
        for m_, c in ((ring, pal[0]), (eye, pal[0]), (pupil, pal[1])):
            t.solid |= m_
            t.m[m_] = c
        for x in (12, 52):
            sp = speckle(_hash('sp', x), 0.4, cells=16) & D(x, 50, 5)
            t.solid |= sp
            t.m[sp] = pal[0]
    t.h[t.solid] = 0.3
    t.obj[:] = False
    return t


def edge_strip(theme, rng, v):
    """the platform edge, the track to the south: a white line, a yellow tactile strip with raised dots, the coping"""
    t = piece()
    cop = B(0, 58, 63, 63)
    t.slab(cop, 'conc_struct', 0.6, bevel=0, obj=False)
    t.mark(cop & (YY == 58), 1)
    strip = B(0, 46, 63, 55)
    t.slab(strip, 'tactile', 0.5, bevel=0, obj=False)
    dots = strip & (((XX % 4) == 1) & ((YY % 4) == 2))
    t.h[dots] += 0.5
    t.mark(dots, 1)
    line = B(0, 42, 63, 43)
    t.slab(line, 'paint_w', 0.3, bevel=0, obj=False)
    if v == 1:
        t.paint(blotches(_hash('es', v), 0.2, cells=8) & strip, 'grime')
    t.noline |= (XX == 0) | (XX == N - 1)
    return t


def puddle(theme, rng, v):
    t = piece()
    r = Rng('pd', v)
    m = np.zeros((N, N), bool)
    for k in range(4):
        m |= D(r.range(20, 44), r.range(22, 42), r.range(8, 14), r.range(5, 9))
    t.solid |= m
    t.m[m] = 'water_murk'
    t.h[m] = 0.2
    t.mark(m & ~np.roll(m, 2, 0), 1)
    t.mark(m & speckle(_hash('pdg', v), 0.05), 2)
    return t


def drain(theme, rng, v):
    t = piece()
    g = B(20, 20, 43, 43, 1)
    t.slab(g, 'dark_steel', 0.6, bevel=0, obj=False)
    t.mark(g & ~B(22, 22, 41, 41), -1)
    slots = B(23, 23, 40, 40) & ((XX % 3) == 0)
    t.carve(slots, 1)
    t.paint(slots, 'ink')
    if v == 1:
        t.paint(blotches(_hash('dr', v), 0.3, cells=8) & D(32, 32, 16) & ~g, 'grime')
        t.solid |= blotches(_hash('dr', v), 0.3, cells=8) & D(32, 32, 16) & ~g
        t.m[t.solid & (t.m == '')] = 'grime'
    return t


def rubbish(theme, rng, v):
    t = piece()
    r = Rng('rb', v)
    for k in range(6):
        x, y = r.range(10, 54), r.range(14, 50)
        kind = r.int(0, 3)
        if kind == 0:
            t.slab(B(x, y, x + r.range(4, 8), y + r.range(3, 6), 1), 'kraft', 1.5, bevel=0.5)
        elif kind == 1:
            t.slab(D(x, y, 2.2, 1.6), r.pick(['plastic_r', 'plastic_b', 'container_g']), 2, profile='dome')
        elif kind == 2:
            t.slab(B(x, y, x + 5, y + 2), 'paper', 0.6, bevel=0)
        else:
            t.slab(D(x, y, 5, 4), 'rubber', 4, profile='dome')
    t.drop_shadow(t.solid.copy(), 2, 2, 0.35)
    return t


def _wear(t, v):
    t.mark(t.obj & blotches(_hash('uw', v), 0.18, cells=8), -1)
    t.paint(t.obj & blotches(_hash('ur', v), 0.1, cells=8) & np.isin(t.m, ['dark_steel', 'duct', 'pipe_g']), 'rust')
    t.drop_shadow(t.solid.copy(), 2, 3, 0.4)
    return t


WALL_FITTINGS = {'pipes': pipes, 'cables': cables, 'duct': duct, 'panel': panel, 'valve': valve, 'fan': fan,
                 'lamp': lamp, 'graffiti': graffiti}
FLOOR_FITTINGS = {'puddle': puddle, 'drain': drain, 'rubbish': rubbish}
