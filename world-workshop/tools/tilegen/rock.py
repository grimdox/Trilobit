"""Rock: mountains, red cliffs, the rock the tunnels are cut through, and rough rocky ground.

A rock mass is drawn by which of its sides are open (bits 1 north, 2 east, 4 south, 8 west, as for walls): 16 shapes,
three variants each.  Its top is one height field for every tile of a kind (big forms, ridged facets, stepped into
ledges), periodic at 64 px so neighbouring cells join without a seam; where a side is open the mass ends in a jagged
edge that drops away to the ground beyond, with scree at its foot.  The edge is a curve along the side that is also
periodic, so a run of cells shares one continuous cliff line.  Variants differ in moss, roots, cracks and mineral
veins, never in the height field, so any variant meets any other.  Past the edge the cell is transparent: the game
draws the neighbouring ground under it."""
import math

import numpy as np

from canvas import Tile, N, XX, YY, Rng, periodic_noise, cracks, speckle, blotches, _hash
from themes import style

KINDS = {
    'grey': dict(mat='rock', seed=101, roots=1.0, moss=1.0),
    'red': dict(mat='rock_red', seed=202, roots=0.5, moss=0.45),
    'under': dict(mat='rock_dark', seed=303, roots=0.0, moss=0.3),
}
FACE = 16               # the height of a cliff seen on the south side of a mass
P = 256                 # a rock mass is one 256 px field (4 x 4 cells) that repeats; each cell is cut from it
PAD = 10                # lit with this many px of its neighbours round it, then cut out (render.to_rgba crop)
CELLS = (P // N) ** 2   # 16 cut positions: the game picks one by the cell's world position


def _vnoise(seed, grid, octaves=1):
    """value noise over the 256 field, wrapping"""
    yy, xx = np.mgrid[0:P, 0:P].astype(np.float32)
    out = np.zeros((P, P), np.float32)
    amp = tot = 0.0
    a = 1.0
    for o in range(octaves):
        g = grid * 2 ** o
        r = Rng(seed, 'vn', o)
        val = np.array([[r.u() for _ in range(g)] for _ in range(g)], np.float32)
        fx, fy = xx * g / P, yy * g / P
        x0, y0 = np.floor(fx).astype(int) % g, np.floor(fy).astype(int) % g
        tx, ty = fx - np.floor(fx), fy - np.floor(fy)
        tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
        x1, y1 = (x0 + 1) % g, (y0 + 1) % g
        v = (val[y0, x0] * (1 - tx) + val[y0, x1] * tx) * (1 - ty) + (val[y1, x0] * (1 - tx) + val[y1, x1] * tx) * ty
        out += v * a
        tot += a
        a *= 0.5
    return out / tot


def _vnoise_col(seed, g):
    """0..1 along x at field position g (wrapping at 256): for the ragged foot of a cliff face"""
    r = Rng(seed, 'col')
    e = np.full(g.shape, 0.5, np.float32)
    for k, amp in ((2, 0.25), (5, 0.15), (11, 0.1)):
        e += amp * np.sin(2 * math.pi * k * g / P + r.range(0, 6.3))
    return np.clip(e, 0, 1)


def _facets(seed, n, stretch, angle, tilt, lift, soft=0.9):
    """a wrapping Voronoi pattern of tilted planes over the field, cells stretched along the rock's grain.  The planes
    blend over a couple of pixels where cells meet (a soft minimum), so faces meet in sharp folds that the light
    picks out, not in steps that would cast lines of shadow"""
    yy, xx = np.mgrid[0:P, 0:P].astype(np.float32)
    r = Rng(seed, 'facets', n)
    ca, sa = math.cos(angle), math.sin(angle)
    dmin = np.full((P, P), 1e9, np.float32)
    ds, hs = [], []
    for i in range(n):
        px, py = r.range(0, P), r.range(0, P)
        gx, gy, c0 = r.range(-tilt, tilt), r.range(-tilt, tilt), r.range(0, lift)
        dx = (xx - px + P / 2) % P - P / 2
        dy = (yy - py + P / 2) % P - P / 2
        d = np.hypot((dx * ca + dy * sa) * stretch, -dx * sa + dy * ca)
        ds.append(d)
        hs.append(c0 + gx * dx + gy * dy)
        dmin = np.minimum(dmin, d)
    wsum = np.zeros((P, P), np.float32)
    hsum = np.zeros((P, P), np.float32)
    for d, h in zip(ds, hs):
        w = np.exp(-(d - dmin) / soft)
        wsum += w
        hsum += w * h
    return hsum / wsum


_FIELDS = {}


def field(kind):
    """the kind's 256 px rock top (height), its crevices, moss, cracks and veins: computed once"""
    if kind in _FIELDS:
        return _FIELDS[kind]
    seed = KINDS[kind]['seed']
    r = Rng(seed, 'grain')
    angle = r.range(0, math.pi)
    swell = _vnoise(seed, 4, 3)
    ridge = 1 - np.abs(2 * _vnoise(seed + 5, 6, 2) - 1)
    h = 10 + 18 * swell + 8 * ridge ** 3
    h += _facets(seed, 32, 0.5, angle, 0.28, 2.4)                     # big faces along the grain
    h += 0.6 * _facets(seed + 9, 150, 0.8, angle + 0.7, 0.22, 1.6)     # smaller ones breaking them up
    gy, gx = np.gradient(h)
    slope = np.hypot(gx, gy)
    crev = slope > 1.9
    moss = (_vnoise(seed + 21, 16, 2) > 0.7) & (slope < 0.7)
    moss |= crev & (_vnoise(seed + 22, 32, 1) > 0.6)
    crack = np.zeros((P, P), bool)
    rc = Rng(seed, 'cracks')
    for k in range(6):
        x, y, ang = rc.range(0, P), rc.range(0, P), rc.range(0, 2 * math.pi)
        for s_ in range(int(rc.range(10, 26))):
            ang += rc.range(-0.5, 0.5)
            x += math.cos(ang)
            y += math.sin(ang)
            crack[int(y) % P, int(x) % P] = True
    tufts = np.zeros((P, P), bool)
    rt = Rng(seed, 'tufts')
    yy, xx = np.mgrid[0:P, 0:P].astype(np.float32)
    for k in range(36):
        x, y = rt.range(0, P), rt.range(0, P)
        if slope[int(y), int(x)] < 1.0:
            dx = (xx - x + P / 2) % P - P / 2
            dy = (yy - y + P / 2) % P - P / 2
            tufts |= (dx / rt.range(1.6, 3.0)) ** 2 + (dy / rt.range(1.2, 2.2)) ** 2 <= 1
    vein = np.zeros((P, P), bool)
    for k in range(4):
        x, y, ang = rc.range(0, P), rc.range(0, P), rc.range(0, 2 * math.pi)
        for s_ in range(int(rc.range(20, 50))):
            ang += rc.range(-0.25, 0.25)
            x += math.cos(ang)
            y += math.sin(ang)
            vein[int(y) % P, int(x) % P] = True
    h *= 0.72                     # gentler slopes: broad lit faces, an outline only where a face really steps down
    _FIELDS[kind] = dict(h=h.astype(np.float32), crev=crev, moss=moss, crack=crack, tufts=tufts, vein=vein)
    return _FIELDS[kind]


def _edge_curve(seed, g):
    """0..1 along a side at global position g (wrapping at 256): slow waves and a fine jag; a run of cells along one
    open side shares one continuous broken line"""
    r = Rng(seed)
    e = np.full(g.shape, 0.5, np.float32)
    for k, amp in ((1, 0.18), (3, 0.14), (7, 0.08), (13, 0.05)):
        e += amp * np.sin(2 * math.pi * (k * g / P) + r.range(0, 2 * math.pi))
    step = np.array([(_hash(seed, i) & 255) / 255.0 for i in range(P // 3 + 2)], np.float32)
    jag = step[(np.floor(g / 3.0).astype(int)) % (P // 3 + 2)]
    e += (jag - 0.5) * 0.16
    return np.clip(e, 0, 1)


def face_foot(face):
    """the pixels just below a cliff face (where scree gathers)"""
    out = np.zeros_like(face)
    for k in range(1, 6):
        out[k:, :] |= face[:-k, :]
    return out & ~face


class Big:
    """a Tile-like piece larger than a cell, lit whole and cut down to the cell by render.to_rgba"""

    def __init__(self, M, crop):
        self.h = np.zeros((M, M), np.float32)
        self.m = np.full((M, M), '', object)
        self.obj = np.zeros((M, M), bool)
        self.d = np.zeros((M, M), np.int8)
        self.glow = np.zeros((M, M), bool)
        self.shadow = np.zeros((M, M), np.float32)
        self.solid = np.zeros((M, M), bool)
        self.noline = np.zeros((M, M), bool)
        self.norim = np.zeros((M, M), bool)
        self.periodic = False
        self.crop = crop
        self.line_drop = 2.5


def _depth(seed, bit, along):
    c = _edge_curve(seed * 31 + bit, along)
    return (FACE + 3 + 12 * c) if bit == 4 else (4 + 22 * c)


CORNERS = ((1, 'NE', 1, 2), (2, 'SE', 4, 2), (4, 'SW', 4, 8), (8, 'NW', 1, 8))      # corner bit, name, its two sides


def corner_sets(bits):
    """the corner combinations a shape can have: a corner counts only where both its sides are closed (rock carries on
    beside the cell) but the cell diagonally beyond is open, so the mass turns an inside corner there"""
    rel = [cb for cb, _, a, b in CORNERS if not bits & a and not bits & b]
    out = []
    for m in range(1 << len(rel)):
        out.append(sum(cb for i, cb in enumerate(rel) if m >> i & 1))
    return out


def massif(kind, theme, rng, v, bits, corners=0):
    """one cell of a rock mass: cut position v (0..15, the cell's place in the 4 x 4 field), open sides bits, inside
    corners (1 NE, 2 SE, 4 SW, 8 NW): where the cell diagonally beyond is open the mass is notched by the curve of the
    neighbouring cells' edges, so it turns the corner with them"""
    k = KINDS[kind]
    F = field(kind)
    M = N + 2 * PAD
    gx0, gy0 = (v % 4) * N - PAD, (v // 4) * N - PAD
    iy = (np.arange(M) + gy0) % P
    ix = (np.arange(M) + gx0) % P
    win = lambda a: a[np.ix_(iy, ix)]
    H = win(F['h'])
    yy, xx = np.mgrid[0:M, 0:M].astype(np.float32)
    ly, lx = yy - PAD, xx - PAD                              # cell-local coordinates (0..63 inside the cell)
    gxx, gyy = (lx + (v % 4) * N) % P, (ly + (v // 4) * N) % P   # field coordinates
    # distance in from the open sides, each measured from its own broken edge line; where two open sides meet the
    # distances blend (a smooth minimum) so the corner rounds off instead of meeting square
    ds = []
    south = None
    for bit, d, along in ((1, ly, gxx), (2, N - 1 - lx, gyy), (4, N - 1 - ly, gxx), (8, lx, gyy)):
        if bits & bit:
            b = (4 + 22 * _edge_curve(k['seed'] * 31 + bit, along)) if bit != 4 else (FACE + 3 + 12 * _edge_curve(k['seed'] * 31 + bit, along))
            ds.append(d - b)
            if bit == 4:
                south = d - b
    for cb, name, sa, sb in CORNERS:
        if corners & cb:
            cx = N - 1 if 'E' in name else 0
            cy = N - 1 if 'S' in name else 0
            gcx = (cx + (v % 4) * N) % P
            gcy = (cy + (v // 4) * N) % P
            # the depth of the neighbours' edges where they meet this corner: the cell beside us across sa has its
            # side (E or W) open, the one across sb its side (N or S) open
            rx = float(_depth(k['seed'], sb, np.array([gcy], np.float32))[0])
            ry = float(_depth(k['seed'], sa, np.array([gcx], np.float32))[0])
            nx = (lx - cx) / max(rx, 1)
            ny = (ly - cy) / max(ry, 1)
            ds.append((np.sqrt(nx * nx + ny * ny) - 1) * min(rx, ry))
    if ds:
        kk = 6.0
        e = sum(np.exp(-np.clip(x, -40, 60) / kk) for x in ds)
        dist = -kk * np.log(e)
    else:
        dist = np.full((M, M), 99.0, np.float32)
    keep = dist >= 0
    ramp = np.clip(dist / 13.0, 0, 1)
    lip = np.where(dist < 0, -dist, 99.0)
    H = H * (0.45 + 0.55 * np.sqrt(ramp))
    t = Big(M, PAD)
    t.line_drop = 7.0            # a line only where the rock really steps down (its edges), not at every facet
    mat = k['mat']
    t.h = np.where(keep, H, 0).astype(np.float32)
    t.m[keep] = mat
    t.solid = keep.copy()
    t.obj = keep.copy()
    crack = win(F['crack']) & keep
    t.d[crack] = np.clip(t.d[crack] - 1, -3, 3)
    # the south face: where the mass ends to the south we see its cliff, like the face under a wall: a band of
    # vertical rock below the top's edge, darker (it faces away from the light), split by vertical joints and
    # bedding, roots and moss hanging down it
    face = np.zeros((M, M), bool)
    if south is not None:
        # how far down from the top's edge, measured on the south edge line only
        fd = -south
        other = np.ones((M, M), bool)
        for x in ds:
            if x is not south:
                other &= x > -2
        face = (~keep) & (fd > 0) & (fd <= FACE + 4 * _vnoise_col(k['seed'], gxx)) & other
        top_h = np.where(keep, t.h, 0)
        edge_h = H * 0.45 - 1.0
        t.h = np.where(face, np.maximum(edge_h - fd * 0.3, 0.5), t.h).astype(np.float32)
        t.m[face] = mat
        t.solid |= face
        t.obj |= face
        joint = face & ((np.floor(gxx / 5.0 + 0.6 * np.sin(gyy * 0.7 + gxx * 0.13)) % 3) == 0) & ((gxx % 5) < 1)
        t.d[joint] = -1
        bed = face & ((fd.astype(int) % 7) == 3) & (_vnoise_col(k['seed'] + 3, gxx) > 0.45)
        t.d[bed] = np.clip(t.d[bed] - 1, -3, 3)
        lit = face & (fd < 2)
        t.d[lit] = 1

    wet = {'rich': 0.5, 'mid': 0.6, 'slum': 0.7, 'rural': 1.0, 'industry': 0.55}[theme] * k['moss']
    if wet > 0:
        moss = win(F['moss']) & keep & (ramp > 0.25)
        if wet < 0.8:
            moss &= win(F['crev']) | (win(_FIELDS[kind]['h']) % 7 < 7 * wet)
        t.m[moss] = 'moss'
        tufts = win(F['tufts']) & keep & (ramp > 0.4)
        if wet >= 0.5:
            t.m[tufts] = 'leaf_dark'
            t.h[tufts] += 1.2
    if kind == 'under':
        vein = win(F['vein']) & keep
        t.m[vein] = 'mineral'
    # roots spilling over the open edges, scree at the foot of the drop: only inside this cell
    cell = (lx >= 0) & (lx < N) & (ly >= 0) & (ly < N)
    if k['roots'] > 0 and bits and theme == 'rural' or (k['roots'] > 0 and bits and wet > 0.5):
        r3 = Rng(k['seed'], v, bits, 'root')
        for bit in (1, 2, 4, 8):
            if not bits & bit or not r3.chance(0.65 * k['roots']):
                continue
            for j in range(r3.int(1, 2)):
                a = r3.range(10, 54)
                depth = r3.range(12, 22)
                prev = None
                for s_ in range(12):
                    u = s_ / 11.0
                    off = math.sin(u * 4 + j * 2) * 2.5
                    dd = depth * (1 - u) - 5 * u
                    if bit == 1:
                        p_ = (a + off, dd)
                    elif bit == 4:
                        p_ = (a + off, N - 1 - dd)
                    elif bit == 8:
                        p_ = (dd, a + off)
                    else:
                        p_ = (N - 1 - dd, a + off)
                    if prev:
                        seg = (np.hypot(lx - (prev[0] + p_[0]) / 2, ly - (prev[1] + p_[1]) / 2) <= 1.4) | \
                              (np.hypot(lx - p_[0], ly - p_[1]) <= 1.2)
                        on = seg & keep
                        t.m[on] = 'root'
                        t.h[on] += 0.6
                        hang = seg & ~keep & cell
                        t.m[hang] = 'root'
                        t.solid |= hang
                        t.h[hang] = 1.5
                    prev = p_
    lip = np.where(t.solid, 99.0, np.where(dist < 0, -dist, 99.0))
    if south is not None:
        lip = np.where(~t.solid & face_foot(face), 2.0, lip)
    if bits:
        r4 = Rng(k['seed'], v, bits, 'scree')
        for i in range(18):
            x, y = r4.range(1, 62), r4.range(1, 62)
            l = lip[int(y) + PAD, int(x) + PAD]
            if 1 < l < 9:
                st_ = (((lx - x) / r4.range(1.2, 2.8)) ** 2 + ((ly - y) / r4.range(1.0, 2.2)) ** 2 <= 1) & ~keep
                hh = r4.range(1.5, 3.5)
                t.h[st_] = hh
                t.m[st_] = mat
                t.solid |= st_
                t.obj |= st_
        sh = np.zeros((M, M), bool)
        sh[4:, 4:] = (keep | face)[:-4, :-4]
        sh &= ~t.solid
        t.shadow = np.where(sh, 0.45, 0).astype(np.float32)
    return t


def rocky_ground(theme, rng, v):
    """rough rocky ground (coasts, mountain feet): grit, set stones of every size, a few roots and moss in the gaps"""
    st = style(theme)
    t = Tile('gravel')
    t.mark(speckle(rng.int(0, 1 << 20), 0.05), -1)
    t.mark(speckle(rng.int(0, 1 << 20), 0.03), 1)
    r = Rng('rocky', v)
    for k in range(9):
        x, y = r.range(0, 64), r.range(0, 64)
        rx, ry = r.range(3, 9), r.range(2.5, 7)
        m = np.zeros((N, N), bool)
        for ox in (-64, 0, 64):
            for oy in (-64, 0, 64):
                m |= Tile.disk_mask(x + ox, y + oy, rx, ry)
        jag = blotches(_hash('rj', v, k), 0.75, cells=16)
        m &= jag | Tile.disk_mask(x, y, rx * 0.6, ry * 0.6)
        t.slab(m, 'rock' if k % 3 else 'stone_dark', r.range(2, 4.5), bevel=1.6, obj=False, wrap=True)
        t.mark(m & cracks(_hash('rc', v, k), n=1, length=8) , -1)
    gaps = blotches(_hash('rg', v), 0.14, cells=8) & (t.h < 0.5)
    t.paint(gaps, 'moss' if theme != 'industry' else 'grime')
    if theme in ('rural', 'mid', 'rich'):
        for k in range(2):
            pts = [(r.range(0, 64), r.range(0, 64))]
            for s in range(8):
                px, py = pts[-1]
                pts.append((px + r.range(-4, 6), py + r.range(-3, 3)))
            for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
                seg = np.zeros((N, N), bool)
                for ox in (-64, 0, 64):                 # drawn once per wrap, so a root crossing the edge carries on
                    for oy in (-64, 0, 64):
                        seg |= Tile.line_mask(x0 % 64 + ox, y0 % 64 + oy, x0 % 64 + (x1 - x0) + ox, y0 % 64 + (y1 - y0) + oy, 1.4)
                t.slab(seg, 'root', 0.8, bevel=0, obj=False)
    return t
