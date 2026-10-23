"""Held items: every gun, melee weapon and tool of the game, drawn at any grip angle.

The approved weapon designs (godot-spike/tools/content/t64_held.py: one template per gun class with maker palettes,
25 melee types in three grades, two tools) are drawn part by part along a hold frame.  Here that frame is given the
pose's projected grip point and axis, so each design is drawn natively at the angle it is held (no sprite rotation,
so lines stay crisp), foreshortened along its length when it points toward or away from the viewer.

Held sprites are full colour (they keep their makers' palettes) and anchored on the grip: the pixel where the near
fist closes.  Cache key: (item id, angle in 3 degree steps, foreshortening in 0.08 steps, hand spacing in 1 px steps).
"""
import math
import os
import sys

import numpy as np

_CONTENT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..', 'godot-spike', 'tools', 'content')
sys.path.insert(0, os.path.abspath(_CONTENT))
import t64_figure as F          # noqa: E402
F.SZ = 128                      # a bigger canvas: long hafts and rifles must fit at every angle
import t64_held as HD           # noqa: E402

CANVAS = 128
ORIGIN = (64.0, 64.0)
SCALE = 1.0


def set_lod(lod):
    """the 32 px world set draws the same designs at half scale (guns and blades natively; tools reduced by 2)"""
    global SCALE
    SCALE = 1.0 if lod == 64 else 0.5


class Hold:
    """drop-in for t64_wear.Hold: s along the item (scaled by the foreshortening fs), n across it"""

    def __init__(self, o, u, k=1.0, fs=1.0, L=10.0):
        self.o = o
        self.u = u
        self.v = (-u[1], u[0])
        self.k = k
        self.fs = fs
        self.L = L

    def p(self, s, n):
        s, n = s * self.k * self.fs, n * self.k
        return (self.o[0] + s * self.u[0] + n * self.v[0], self.o[1] + s * self.u[1] + n * self.v[1])

    def n_of(self, a):
        return ((a.xx - self.o[0]) * self.v[0] + (a.yy - self.o[1]) * self.v[1]) / self.k


class _FB:
    """the minimal body the tool drawings read (the near hand position)"""

    def __init__(self):
        self.H_n = ORIGIN
        self.H_f = (ORIGIN[0] + 10, ORIGIN[1])


def kind_of(it):
    t = it.get('tags', [])
    if 'gun' in t:
        cls = t[1]
        return 'pistol' if cls in ('pistol', 'revolver') else 'rifle'
    if t and t[0] == 'melee':
        base = it['id'][len('trl_mel_'):]
        for g in ('_f', '_m'):
            if base.endswith(g):
                base = base[:-2]
        fn = HD.MELEE[base]
        mode = getattr(fn, 'mode', 'two')
        return {'two': 'melee2', 'upright': 'melee1', 'hang': 'melee1'}[mode]
    if it['id'] in HD.TOOLS:
        return 'tool'
    return None


def quant(angle, fs, L):
    return int(round(math.degrees(angle) / 3.0)) * 3, round(round(fs / 0.08) * 0.08, 2), int(round(L))


def draw(it, angle_deg, fs, L):
    """RGBA PIL image (CANVAS square) of item `it` held at screen angle `angle_deg` (0 = pointing right, y down),
    foreshortening fs (0..1) and hand spacing L (pixels); the grip is at ORIGIN"""
    a = F.A()
    ang = math.radians(angle_deg)
    u = (math.cos(ang), math.sin(ang))
    t = it.get('tags', [])
    over = False
    if 'gun' in t:
        cls = t[1]
        fn, ref_mm, ref_len, k = HD.GUN_CLASS[cls]
        r = HD.rng(it['id'])
        h = Hold(ORIGIN, u, k=k * SCALE, fs=max(0.35, fs), L=L)
        h.Lm = ref_len * (0.9 + 0.1 * it['length_mm'] / ref_mm) + (r.random() - 0.5) * 1.6
        fn(a, h, it, HD.maker_palette(it), r)
    elif t and t[0] == 'melee':
        base = it['id'][len('trl_mel_'):]
        grade = ''
        for gsuf in ('_f', '_m'):
            if base.endswith(gsuf):
                grade, base = gsuf, base[:-2]
        fn = HD.MELEE[base]
        g = dict(HD.GRADES[grade])
        origin = t[2] if len(t) > 2 else 'japanese'
        if grade == '_m':
            g['wrap'] = HD.WRAP_M.get(origin, '#4a2c1a')
        if getattr(fn, 'mode', 'two') == 'hang':
            u = (0.0, 1.0)                              # chains hang whatever the hand does
        h = Hold(ORIGIN, u, k=SCALE, fs=max(0.35, fs), L=L / SCALE)
        fn(a, h, g)
        over = base in HD.OVER_HANDS
    elif it['id'] in HD.TOOLS:
        im = _opaque(HD.TOOLS[it['id']](_FB()))
        if SCALE != 1.0:
            im = _halve(im)
        return im, False
    else:
        return None, False
    return _opaque(F.crisp(a)), over


def _halve(im):
    """reduce a drawing by 2 around ORIGIN: each 2x2 block takes its most common opaque colour (no blending)"""
    from PIL import Image
    a = np.array(im)
    H, W = a.shape[:2]
    out = np.zeros_like(a)
    oy, ox = int(ORIGIN[1]), int(ORIGIN[0])
    for y in range(0, H - 1, 2):
        for x in range(0, W - 1, 2):
            blk = a[y:y + 2, x:x + 2].reshape(4, 4)
            op = [tuple(p) for p in blk if p[3] > 0]
            if len(op) < 2:
                continue
            best = max(set(op), key=op.count)
            ty, tx = oy + (y - oy) // 2, ox + (x - ox) // 2
            if 0 <= ty < H and 0 <= tx < W:
                out[ty, tx] = best
    return Image.fromarray(out, 'RGBA')


def _opaque(im):
    """pixel art is opaque: the old drawings' 235-alpha outline becomes solid (no blending, identical on every renderer)"""
    arr = np.array(im)
    arr[..., 3] = np.where(arr[..., 3] > 0, 255, 0)
    from PIL import Image
    return Image.fromarray(arr, 'RGBA')
