"""Light a Tile (canvas.py) into a 64 x 64 RGBA sprite.

The rules, the same for every tile in every theme:
  light     one key light from the top left, high (top-down world); flat ground sits on the middle shade (3)
  bands     lit value cut into the material's five ramp shades (1-5); shade 0 is its line colour
  marks     painted shade steps (seams, scratches) added to the band, clamped to the ramp
  creases   pixels lower than their surroundings (joints, gutters, the foot of a wall) one shade darker
  shadows   raised shapes cast a short shadow to the bottom right, onto lower pixels (one or two shades)
  outline   raised objects get a 1 px line where they meet lower ground or the empty background; not where an object
            runs on into the next cell
  rim       a cyan back light (shade 6) on the bottom-right inside edge of objects whose material takes it
  glint     glossy materials (metal, glass, polished stone) take shade 7 where the light strikes hardest
  glow      emissive pixels ignore the light: their glow ramp, brightest at the core
  cleanup   lone pixels (no neighbour of the same colour in 8 directions) take their neighbours' shade
"""
import numpy as np
from scipy import ndimage as ndi

from canvas import N

LIGHT = np.array([-0.5, -0.62, 0.9], np.float32)
LIGHT /= np.linalg.norm(LIGHT)
FLAT = float(LIGHT[2])
STEP = 0.105          # lit value per shade band


def _shift(a, dy, dx, wrap, fill):
    if wrap:
        return np.roll(np.roll(a, dy, 0), dx, 1)
    out = np.full_like(a, fill)
    ys = slice(max(dy, 0), N + min(dy, 0))
    yd = slice(max(-dy, 0), N + min(-dy, 0))
    xs = slice(max(dx, 0), N + min(dx, 0))
    xd = slice(max(-dx, 0), N + min(-dx, 0))
    out[ys, xs] = a[yd, xd]
    return out


def _edge(a, dy, dx, wrap):
    """neighbour value with the tile edge replicated (objects continue past the edge) or wrapped (ground)"""
    if wrap:
        return np.roll(np.roll(a, -dy, 0), -dx, 1)
    p = np.pad(a, 1, mode='edge')
    return p[1 + dy:1 + dy + N, 1 + dx:1 + dx + N]


def shade_map(t, mats):
    """per-pixel (material name, shade 0-7) and the translucent shadow alpha"""
    wrap = t.periodic
    h = t.h.astype(np.float32)
    hx = (_edge(h, 0, 1, wrap) - _edge(h, 0, -1, wrap)) * 0.5
    hy = (_edge(h, 1, 0, wrap) - _edge(h, -1, 0, wrap)) * 0.5
    # smooth normals within an object so bevels read as volume, not stair steps
    hx = ndi.uniform_filter(hx, 2, mode='wrap' if wrap else 'nearest')
    hy = ndi.uniform_filter(hy, 2, mode='wrap' if wrap else 'nearest')
    nrm = np.stack([-hx, -hy, np.ones_like(h)], -1)
    nrm /= np.linalg.norm(nrm, axis=-1, keepdims=True)
    v = nrm @ LIGHT
    shade = np.clip(np.round(3 + (v - FLAT) / STEP), 1, 5).astype(np.int16)
    # per-material texture: roughness lets a field of noise move the band by one (stone, rust), smooth materials hold
    rough = np.zeros((N, N), np.float32)
    gloss = np.zeros((N, N), np.float32)
    rim = np.zeros((N, N), np.float32)
    names = [n for n in np.unique(t.m[t.solid]) if n]
    for n in names:
        sel = t.m == n
        mt = mats(n)
        rough[sel] = mt.get('rough', 0.0)
        gloss[sel] = mt.get('gloss', 0.0)
        rim[sel] = mt.get('rim', 0.6)
        shade[sel] = np.clip(shade[sel] + mt.get('bias', 0), 1, 5)
    if rough.any():
        from canvas import periodic_noise
        nz = periodic_noise(_seed_of(t), 16, 2)
        shade += np.where(nz > 1 - rough * 0.22, 1, 0).astype(np.int16) - np.where(nz < rough * 0.22, 1, 0).astype(np.int16)
        shade = np.clip(shade, 1, 5)
    # creases: lower than the 5 x 5 mean by more than a pixel
    mean = ndi.uniform_filter(h, 5, mode='wrap' if wrap else 'nearest')
    crease = (mean - h) > 0.9
    shade = np.where(crease & t.solid, shade - 1, shade)
    # cast shadows to the bottom right
    sh = np.zeros((N, N), np.int16)
    for k in range(1, 7):
        hk = _shift(h, k, k, wrap, -1e9)
        sh = np.maximum(sh, np.where(hk > h + 1.2 * k, 1 if k > 3 else 2, 0).astype(np.int16))
    shade = shade - np.where(t.obj, np.minimum(sh, 1), sh)
    shade = np.clip(shade + t.d, 1, 5)
    # glint
    spec = (v > FLAT + 2.2 * STEP) & (gloss > 0.5)
    shade = np.where(spec, 7, shade)
    # outline: an object pixel next to empty space, ground, or a much lower pixel (not where it runs past the tile edge)
    line = np.zeros((N, N), bool)
    rimm = np.zeros((N, N), bool)
    for dy, dx in ((0, 1), (1, 0), (0, -1), (-1, 0)):
        nsolid = _edge(t.solid, dy, dx, wrap)
        nobj = _edge(t.obj, dy, dx, wrap)
        nh = _edge(h, dy, dx, wrap)
        edge = t.obj & (~nsolid | ~nobj | (nh < h - 2.5))
        if not wrap:
            # the tile border itself: the replicated neighbour is the pixel itself, so no line unless marked
            pass
        line |= edge & ~t.noline
        if (dy, dx) in ((0, 1), (1, 0)):
            rimm |= edge
    # rim: the pixel just inside the bottom-right outline
    inner = np.zeros((N, N), bool)
    for dy, dx in ((0, 1), (1, 0)):
        inner |= _edge(line, dy, dx, wrap) & t.obj & ~line
    shade = np.where(inner & (rim > 0.5) & (shade <= 3), 6, shade)
    shade = np.where(line, 0, shade)
    # glow: banded by distance from the emissive edge
    if t.glow.any():
        dist = ndi.distance_transform_edt(t.glow)
        lab, nl = ndi.label(t.glow)
        sizes = ndi.sum(t.glow, lab, range(1, nl + 1))
        small = np.isin(lab, 1 + np.nonzero(sizes <= 6)[0])
        gs = np.clip(2 + dist.astype(int), 2, 5)
        gs = np.where(small, 5, gs)
        shade = np.where(t.glow, gs, shade)
    shade = _strays(t.m, shade, t.solid, t.glow | line, wrap)
    return shade, t.shadow


def _seed_of(t):
    return int(abs(float(t.h.sum())) * 13 + len(np.unique(t.m))) & 0xffff


def _strays(mat, shade, solid, keep, wrap=False):
    _, inv = np.unique(mat.astype(str), return_inverse=True)          # a stable index per material name
    code = np.where(solid, inv.reshape(mat.shape) * 8 + shade, -1)
    same = np.zeros((N, N), np.int16)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dy or dx:
                same += _shift(code, dy, dx, wrap, -2) == code
    lone = solid & (same == 0) & (shade >= 1) & (shade <= 5) & ~keep
    if not lone.any():
        return shade
    out = shade.copy()
    ys, xs = np.nonzero(lone)
    for y, x in zip(ys, xs):
        votes = {}
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                yy, xx = y + dy, x + dx
                if wrap:
                    yy, xx = yy % N, xx % N
                if (dy or dx) and 0 <= yy < N and 0 <= xx < N and solid[yy, xx] and mat[yy, xx] == mat[y, x] and 1 <= shade[yy, xx] <= 5:
                    votes[shade[yy, xx]] = votes.get(shade[yy, xx], 0) + 1
        if votes:
            out[y, x] = max(votes.items(), key=lambda kv: (kv[1], -abs(kv[0] - shade[y, x])))[0]
    return out


def to_rgba(t, mats):
    """the finished sprite: an RGBA uint8 array"""
    shade, shadow = shade_map(t, mats)
    out = np.zeros((N, N, 4), np.uint8)
    names = [n for n in np.unique(t.m[t.solid]) if n]
    for n in names:
        ramp = mats(n)['ramp']
        sel = (t.m == n) & t.solid
        cols = np.array([[int(c[1:3], 16), int(c[3:5], 16), int(c[5:7], 16)] for c in ramp], np.uint8)
        out[sel, :3] = cols[np.clip(shade[sel], 0, 7)]
        out[sel, 3] = 255
    sh = (shadow > 0) & ~t.solid
    out[sh] = [8, 6, 16, 0]
    out[sh, 3] = (shadow[sh] * 255).astype(np.uint8)
    return out
