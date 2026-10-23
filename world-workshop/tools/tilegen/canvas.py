"""The tile canvas: a 64 x 64 height and material map that the renderer lights (render.py).

Every tile is built, not painted: shapes raise height (a kerb, a bevelled panel, a dome, a cylinder) and set a material
(named by role: 'paver', 'marble', 'rust', 'neon_cyan'); patterns cut seams into it; wear (cracks, grime, moss, rust)
changes material or shade in deterministic, tileable masks.  The renderer then lights the height map from the top left,
bands it into each material's ramp, darkens creases, casts short shadows to the bottom right and outlines objects, so
every tile in every theme is shaded by the same rules.

Coordinates: x right, y down, 0..63.  Heights are in pixels (a kerb 2, a table 8, a wall 14).  Ground tiles are
periodic: every pattern and noise wraps at 64, so neighbouring cells join without seams.
"""
import math

import numpy as np

N = 64
YY, XX = np.mgrid[0:N, 0:N].astype(np.float32)


def _hash(*v):
    """a deterministic 32-bit hash of integers"""
    h = 2166136261
    for x in v:
        if isinstance(x, str):
            for ch in x.encode():
                h = ((h ^ ch) * 16777619) & 0xffffffff
            continue
        h = ((h ^ (int(x) & 0xffffffff)) * 16777619) & 0xffffffff
        h ^= h >> 13
    # murmur3 finaliser: every input bit reaches every output bit (the high bits too)
    h ^= h >> 16
    h = (h * 0x85ebca6b) & 0xffffffff
    h ^= h >> 13
    h = (h * 0xc2b2ae35) & 0xffffffff
    h ^= h >> 16
    return h


class Rng:
    """small deterministic generator (PCG-like), seeded per tile, so a tile never depends on what was drawn before it"""

    def __init__(self, *seed):
        self.s = _hash(*seed) or 1

    def u(self):
        self.s = (self.s * 1103515245 + 12345) & 0x7fffffff
        x = self.s
        x ^= x >> 11
        x = (x * 2654435761) & 0xffffffff
        return (x >> 8) / float(1 << 24)

    def range(self, a, b):
        return a + (b - a) * self.u()

    def int(self, a, b):
        return a + int(self.u() * (b - a + 1)) % (b - a + 1)

    def pick(self, seq):
        return seq[int(self.u() * len(seq)) % len(seq)]

    def chance(self, p):
        return self.u() < p


def periodic_noise(seed, cells=8, octaves=2):
    """value noise in 0..1 that wraps at 64 (cells per side must divide 64)"""
    out = np.zeros((N, N), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        c = cells * (2 ** o)
        g = np.array([[_hash(seed, o, i, j) / 4294967295.0 for i in range(c)] for j in range(c)], np.float32)
        fx = XX * c / N
        fy = YY * c / N
        x0 = np.floor(fx).astype(int) % c
        y0 = np.floor(fy).astype(int) % c
        tx = fx - np.floor(fx)
        ty = fy - np.floor(fy)
        tx = tx * tx * (3 - 2 * tx)
        ty = ty * ty * (3 - 2 * ty)
        x1, y1 = (x0 + 1) % c, (y0 + 1) % c
        v = (g[y0, x0] * (1 - tx) + g[y0, x1] * tx) * (1 - ty) + (g[y1, x0] * (1 - tx) + g[y1, x1] * tx) * ty
        out += v * amp
        tot += amp
        amp *= 0.5
    return out / tot


class Tile:
    """one 64 x 64 sprite under construction"""

    def __init__(self, base='', h=0.0, periodic=True, alpha=True):
        self.h = np.full((N, N), h, np.float32)          # height
        self.m = np.full((N, N), base, object)           # material role per pixel ('' = empty)
        self.obj = np.zeros((N, N), bool)                # raised object pixels (outlined, cast shadows)
        self.d = np.zeros((N, N), np.int8)               # painted shade offsets (seams, scratches, grime)
        self.glow = np.zeros((N, N), bool)               # emissive
        self.shadow = np.zeros((N, N), np.float32)       # translucent contact shadow on empty pixels (0..1)
        self.periodic = periodic                         # ground tiles wrap; objects do not
        self.solid = np.full((N, N), bool(base), bool)   # drawn at all (False: transparent)
        self.noline = np.zeros((N, N), bool)             # object pixels that join the next cell (no outline there)

    # ---------------------------------------------------------------- masks
    @staticmethod
    def box_mask(x0, y0, x1, y1, r=0.0):
        """inclusive pixel box, corners rounded by r"""
        cx = np.clip(XX, x0 + r, x1 - r)
        cy = np.clip(YY, y0 + r, y1 - r)
        if r <= 0:
            return (XX >= x0) & (XX <= x1) & (YY >= y0) & (YY <= y1)
        return (np.hypot(XX - cx, YY - cy) <= r + 0.25) & (XX >= x0) & (XX <= x1) & (YY >= y0) & (YY <= y1)

    @staticmethod
    def disk_mask(cx, cy, r, ry=None):
        ry = r if ry is None else ry
        return ((XX - cx) / max(r, 0.01)) ** 2 + ((YY - cy) / max(ry, 0.01)) ** 2 <= 1.0

    @staticmethod
    def line_mask(x0, y0, x1, y1, w=1.0):
        dx, dy = x1 - x0, y1 - y0
        L2 = dx * dx + dy * dy
        if L2 == 0:
            return Tile.disk_mask(x0, y0, w / 2)
        t = np.clip(((XX - x0) * dx + (YY - y0) * dy) / L2, 0, 1)
        return np.hypot(XX - (x0 + t * dx), YY - (y0 + t * dy)) <= w / 2.0

    @staticmethod
    def poly_mask(pts):
        m = np.zeros((N, N), bool)
        n = len(pts)
        px, py = XX + 0.5, YY + 0.5
        j = n - 1
        for i in range(n):
            xi, yi = pts[i]
            xj, yj = pts[j]
            cross = ((yi > py) != (yj > py)) & (px < (xj - xi) * (py - yi) / ((yj - yi) if yj != yi else 1e-6) + xi)
            m ^= cross
            j = i
        return m

    # ---------------------------------------------------------------- shapes
    def ground(self, mat, mask=None, h=0.0):
        mask = np.ones((N, N), bool) if mask is None else mask
        self.m[mask] = mat
        self.h[mask] = h
        self.solid |= mask
        self.obj[mask] = False
        return mask

    def slab(self, mask, mat, height, bevel=1.5, on=None, obj=True, profile='bevel', wrap=False):
        """raise a shape: flat top at `height` above `on` (default: what is under it), edges bevelled over `bevel` px.
        profile 'dome' rounds it fully (a cushion, a shrub), 'cyl' gives a hard edge"""
        if not mask.any():
            return mask
        from scipy import ndimage as ndi
        if wrap:
            # distance to the shape's edge measured on the torus, so a shape cut by the tile edge is one shape
            big = np.tile(mask, (3, 3))
            dist = ndi.distance_transform_edt(big)[N:2 * N, N:2 * N]
        else:
            dist = ndi.distance_transform_edt(mask)
        if profile == 'dome':
            r = max(dist.max(), 1.0)
            prof = np.sqrt(np.clip(1 - (1 - dist / r) ** 2, 0, 1))
        elif profile == 'cyl' or bevel <= 0:
            prof = np.ones_like(dist)
        else:
            prof = np.clip(dist / bevel, 0, 1)
            prof = np.sqrt(prof)
        base = self.h if on is None else np.full((N, N), float(on), np.float32)
        top = np.max(np.where(mask, base, -1e9)) if on is None else float(on)
        newh = top + height * prof
        self.h = np.where(mask, np.maximum(newh, self.h if on is None else newh), self.h).astype(np.float32)
        self.m[mask] = mat
        self.solid |= mask
        if obj:
            self.obj |= mask
        return mask

    def paint(self, mask, mat):
        """change the material without changing the height (inlays, stains, stripes)"""
        mask = mask & self.solid
        self.m[mask] = mat
        return mask

    def mark(self, mask, d=-1):
        """a painted shade step (seams, scratches, panel lines); d -1 darker, +1 lighter"""
        mask = mask & self.solid
        self.d[mask] = np.clip(self.d[mask].astype(int) + d, -3, 3)
        return mask

    def carve(self, mask, depth=1.0):
        """lower the height (grooves, joints, cracks): they shade by occlusion as well as by mark"""
        mask = mask & self.solid
        self.h[mask] -= depth
        return mask

    def emit(self, mask, mat):
        """emissive material (neon, screens, lamps): not lit, banded by distance from its edge"""
        mask = mask & self.solid
        self.m[mask] = mat
        self.glow |= mask
        return mask

    def drop_shadow(self, mask, dx=3, dy=3, strength=0.45):
        """a translucent shadow on empty pixels to the bottom right of an object (furniture on any floor)"""
        sh = np.zeros((N, N), bool)
        sh[dy:, dx:] = mask[:N - dy, :N - dx]
        sh &= ~self.solid
        self.shadow = np.maximum(self.shadow, sh.astype(np.float32) * strength)

    def clear(self, mask):
        self.solid[mask] = False
        self.obj[mask] = False
        self.m[mask] = ''
        self.h[mask] = 0
        self.glow[mask] = False


# -------------------------------------------------------------------- tileable patterns (masks of seams / cells)
def pavers(w, h, gap=1, offset=0.5, ox=0, oy=0):
    """running-bond pavers: (seam mask, cell id per pixel); w and h divide 64"""
    row = ((YY + oy) // h).astype(int)
    shift = (row % 2) * int(w * offset)
    col = ((XX + ox + shift) // w).astype(int)
    seam = (((YY + oy) % h) < gap) | (((XX + ox + shift) % w) < gap)
    return seam, row * 1000 + col % (N // w)


def grid(w, h=None, gap=1, ox=0, oy=0):
    h = h or w
    seam = (((YY + oy) % h) < gap) | (((XX + ox) % w) < gap)
    return seam, ((YY + oy) // h).astype(int) * 1000 + ((XX + ox) // w).astype(int)


def planks(w, length=32, gap=1, vertical=False, seed=0):
    """floorboards: long seams between boards, staggered butt joints"""
    a, b = (XX, YY) if vertical else (YY, XX)
    board = (a // w).astype(int)
    stag = np.array([(_hash(seed, k) % length) for k in range(N // w + 1)])[board]
    seam = ((a % w) < gap) | (((b + stag) % length) < gap)
    return seam, board * 100 + (((b + stag) // length).astype(int) % (N // length))      # piece numbers wrap too


def hexes(r):
    """hexagonal tiling seams (r divides cleanly enough at 64 for ground: used for parks and plazas)"""
    q = XX / (r * 1.5)
    s = YY / (r * math.sqrt(3))
    col = np.floor(q)
    off = (col % 2) * 0.5
    row = np.floor(s - off)
    cx = (col + 0.5) * r * 1.5
    cy = (row + 0.5 + off) * r * math.sqrt(3)
    d = np.maximum(np.abs(XX - cx) * 0.866 + np.abs(YY - cy) * 0.5, np.abs(YY - cy))
    return d > r * 0.8, (row * 1000 + col).astype(int)


def cracks(seed, n=3, length=26, branch=0.25, wrap=True, region=None):
    """jagged hairline cracks (random walks that wrap): a mask"""
    rng = Rng(seed, 77)
    m = np.zeros((N, N), bool)
    for k in range(n):
        x, y = rng.range(0, N), rng.range(0, N)
        if region is not None:
            ys, xs = np.nonzero(region)
            if len(xs) == 0:
                return m
            i = rng.int(0, len(xs) - 1)
            x, y = float(xs[i]), float(ys[i])
        ang = rng.range(0, 2 * math.pi)
        stack = [(x, y, ang, length)]
        while stack:
            x, y, ang, L = stack.pop()
            for s in range(int(L)):
                ang += rng.range(-0.6, 0.6)
                x += math.cos(ang)
                y += math.sin(ang)
                xi, yi = int(x) % N if wrap else int(x), int(y) % N if wrap else int(y)
                if 0 <= xi < N and 0 <= yi < N:
                    m[yi, xi] = True
                if rng.chance(branch / L * 6) and L > 6:
                    stack.append((x, y, ang + rng.pick([-1.0, 1.0]), L * 0.45))
    return m


def speckle(seed, density, cells=16):
    """sparse tileable specks (gravel, dust, litter): a mask with about density of pixels set, in small clusters"""
    nz = periodic_noise(seed, cells, 1)
    fine = np.array([[_hash(seed, 9, x, y) & 1023 for x in range(N)] for y in range(N)]) / 1023.0
    return (fine < density * 2 * nz)


def blotches(seed, cover, cells=4, octaves=3):
    """soft tileable blotches (grime, moss, rust patches, puddles) covering about `cover` of the tile"""
    nz = periodic_noise(seed, cells, octaves)
    t = np.quantile(nz, 1.0 - cover) if cover > 0 else 2.0
    return nz >= t
