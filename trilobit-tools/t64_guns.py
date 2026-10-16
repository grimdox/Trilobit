"""Guns for the 64px tileset: a lit side-view icon (ground item) and a top-down 'hold' sprite (in the doll's hands) for every model.
Designs are built from parts (receiver, barrel, handguard, magazine, stock, optic, muzzle device) chosen by class, maker and the model's id,
so siblings differ.  Everything points to the right in the icon and up in the hold sprite."""
import hashlib, random
import numpy as np
from PIL import Image
from art64 import Art, col, lit, mix, hx

# makers: first letter of the model code
MAKER = {
    'H': dict(body='#46566f', trim='#2c3646', acc='#35d7ff', wood='#8a6a48', steel='#9aa7b6', name='Hoshikawa'),
    'S': dict(body='#5d5f6b', trim='#3b3d46', acc='#ff9a30', wood='#7a5c3c', steel='#a5aab4', name='Sakurai'),
    'V': dict(body='#3f4a35', trim='#2a3123', acc='#d9bf4a', wood='#8f5a2c', steel='#8d948f', name='Volkov'),
    'Z': dict(body='#34402c', trim='#222a1c', acc='#e05050', wood='#9a6334', steel='#8d948f', name='Zaytsev'),
    'G': dict(body='#2c2d33', trim='#1d1e22', acc='#c9b07a', wood='#5a4a38', steel='#9ba0a8', name='Grant'),
    'L': dict(body='#7a8592', trim='#515b66', acc='#50e090', wood='#7a6a50', steel='#c0c8d0', name='Lin'),
    'F': dict(body='#5a4a68', trim='#3a2f46', acc='#ff58b0', wood='#6a5a4a', steel='#b0a6bd', name='Fujimoto'),
}


def rng_for(s):
    return random.Random(int(hashlib.md5(s.encode()).hexdigest()[:8], 16))


class G:
    """a gun being drawn: holds the Art, palette and accumulates masks for the shadow"""

    def __init__(self, it, r):
        self.it = it
        self.r = r
        code = it['name'].split(' ')[0]
        self.code = code
        self.mk = MAKER.get(code[0], MAKER['G'])
        d = (r.random() - 0.5) * 0.3
        self.body = lit(self.mk['body'], 1 + d)
        self.trim = lit(self.mk['trim'], 1 + d * 0.5)
        self.acc = self.mk['acc']
        self.wood = self.mk['wood']
        self.steel = self.mk['steel']
        self.cls = it['tags'][1]
        self.mag = it['gun'].get('mag', 10)
        self.L = it['length_mm']
        self.masks = []


def paint(a, g, mask, c, bevel=2.0, strength=0.9, spec=0.35, grain=0.12, seed=1, **kw):
    a.shade(mask, c, bevel=bevel, strength=strength, spec=spec, grain=grain, seed=seed, **kw)


def led(a, x, y, c, r=0.9, glow=7):
    a.fill(a.ellipse(x, y, r), c, 1.0)
    a.glow(x, y, glow, c, 0.7)


def strip(a, x0, y0, x1, y1, c, w=1.0, glow=6):
    a.fill(a.line(x0, y0, x1, y1, w), c, 0.95)
    a.glow((x0 + x1) / 2, (y0 + y1) / 2, glow + abs(x1 - x0) / 3, c, 0.35)


def rail(a, x0, x1, y, h=1.6, c='#16181b'):
    m = a.rect(x0, y, x1 - x0, h)
    a.shade(m, c, bevel=0.6, strength=0.6, spec=0.2)
    for k in np.arange(x0 + 0.8, x1 - 0.5, 1.8):
        a.fill(a.rect(k, y - 0.4, 0.8, 0.6), '#0b0c0e', 0.9)


# ------------------------------------------------------------------------------------------------ parts
def optic(a, g, x, y, kind):
    """x: left, y: sits above the rail line at y (top of the receiver)"""
    if kind == 'dot':
        m = a.rrect(x, y - 5.4, 8, 5.4, 1.4)
        paint(a, g, m, '#23262c', bevel=1.2, spec=0.5)
        a.fill(a.rrect(x + 4.6, y - 4.6, 2.6, 3.8, 0.8), '#6ad8ff', 0.6)
        a.fill(a.ellipse(x + 5.9, y - 2.7, 0.7), '#ff3b3b', 1.0)
    elif kind == 'holo':
        a.fill(a.rect(x, y - 1.5, 7, 1.5), '#1b1d21')
        m = a.rrect(x + 1, y - 7.4, 6, 6, 1.2)
        paint(a, g, m, '#1c1e23', bevel=1.2, spec=0.4)
        a.fill(a.rect(x + 2.2, y - 6.4, 3.6, 4), '#7fe8ff', 0.55)
        a.fill(a.ellipse(x + 4, y - 4.4, 0.6), '#ff3b3b', 1.0)
    elif kind == 'scope':
        m = a.rrect(x, y - 7.2, 16, 5.4, 2.4)
        paint(a, g, m, '#1c1e23', bevel=2.2, spec=0.7)
        a.fill(a.ellipse(x + 15.2, y - 4.5, 2.6, 2.8), '#10161c', 1.0)
        a.fill(a.ellipse(x + 15.6, y - 4.5, 1.6, 1.8), '#4a8aa8', 0.9)
        a.fill(a.ellipse(x + 15.0, y - 5.0, 0.6), '#ffffff', 0.8)
        for dx in (3.0, 11.0):
            a.shade(a.rect(x + dx, y - 1.9, 2, 1.9), '#2a2d33', bevel=0.6)
    elif kind == 'long_scope':
        m = a.rrect(x, y - 8.0, 24, 6.4, 2.8)
        paint(a, g, m, '#1c1e23', bevel=2.6, spec=0.8)
        a.fill(a.rrect(x + 3, y - 9.6, 4.6, 3, 1), '#2a2d33')
        a.fill(a.ellipse(x + 23, y - 4.8, 3.2, 3.2), '#10161c')
        a.fill(a.ellipse(x + 23.4, y - 4.8, 2.0, 2.0), '#4a9bb8', 0.9)
        a.fill(a.ellipse(x + 22.6, y - 5.6, 0.7), '#ffffff', 0.85)
        for dx in (4.0, 17.0):
            a.shade(a.rect(x + dx, y - 1.8, 2.4, 1.8), '#2a2d33', bevel=0.6)
        a.fill(a.rect(x + 9, y - 8.2, 6, 1), '#c9a14a', 0.6)
    elif kind == 'iron':
        a.fill(a.rect(x, y - 3.0, 1.6, 3.0), '#15171a')
        a.fill(a.rect(x + 6, y - 2.4, 1.2, 2.4), '#15171a')
        a.fill(a.rect(x + 6, y - 2.6, 1.2, 0.8), '#e9e9e9', 0.9)


def muzzle(a, g, x, y, kind):
    """x: where the barrel ends; y: bore centre"""
    if kind == 'supp':
        m = a.rrect(x - 1, y - 2.8, 14, 5.6, 2.2)
        paint(a, g, m, '#262a30', bevel=2.4, spec=0.45, grain=0.3)
        for k in range(4):
            a.fill(a.rect(x + 1.5 + k * 3, y - 2.6, 0.6, 5.2), '#0e1013', 0.8)
        return x + 13
    if kind == 'brake':
        m = a.rrect(x - 1, y - 2.4, 6, 4.8, 1)
        paint(a, g, m, g.trim, bevel=1.2, spec=0.5)
        for k in range(2):
            a.fill(a.rect(x + 0.6 + k * 2.2, y - 2.8, 0.9, 5.6), '#0b0c0e', 0.9)
        return x + 5
    if kind == 'hider':
        m = a.rrect(x - 1, y - 2.0, 6, 4, 1)
        paint(a, g, m, '#20232a', bevel=1.2, spec=0.4)
        for k in range(3):
            a.fill(a.rect(x + 0.4 + k * 1.5, y - 2.0, 0.5, 4), '#0b0c0e', 0.9)
        return x + 5
    if kind == 'bell':
        m = a.poly([(x - 1, y - 1.6), (x + 3, y - 3.2), (x + 5, y - 3.2), (x + 5, y + 3.2), (x + 3, y + 3.2), (x - 1, y + 1.6)])
        paint(a, g, m, '#2a2d33', bevel=1.2, spec=0.5)
        a.fill(a.ellipse(x + 5, y, 0.8, 2.0), '#050506', 1.0)
        return x + 5
    return x


def mag_box(a, g, x, y, w, h, curve, c=None, base=None, tilt=0.0):
    """magazine hanging from y (top), x left edge; curve bends it forward (+x) towards the bottom"""
    c = c or lit(g.trim, 1.25)
    pts_l, pts_r = [], []
    n = 8
    for i in range(n + 1):
        t = i / n
        off = curve * t * t * h + tilt * t * h
        pts_l.append((x + off, y + t * h))
        pts_r.append((x + w + off, y + t * h))
    poly = pts_l + pts_r[::-1]
    m = a.poly(poly)
    paint(a, g, m, c, bevel=1.6, strength=0.9, spec=0.3, grain=0.3, seed=11)
    # witness holes / ribs
    for k in range(1, 5):
        t = k / 5
        off = curve * t * t * h + tilt * t * h
        a.fill(a.rect(x + off + 1, y + t * h, w - 2, 0.5), '#000000', 0.35)
    off = curve * h + tilt * h
    pad = a.rrect(x + off - 0.6, y + h - 1.2, w + 1.2, 2.2, 0.8)
    paint(a, g, pad, base or g.acc, bevel=0.8, spec=0.4)
    return m


def grip(a, g, x, y, w, h, tilt, c=None, wood=False, tex=True):
    pts = [(x, y), (x + w, y), (x + w + tilt, y + h), (x + tilt - 0.4, y + h + 0.5)]
    m = a.poly(pts)
    c = c or (g.wood if wood else '#25272c')
    paint(a, g, m, c, bevel=2.0, strength=0.9, spec=0.15, grain=0.55 if wood else 0.3, seed=7)
    if tex and not wood:
        a.speckle(m, '#454850', 14, 3, 0.8, 0.8)
    if wood:
        for k in range(3):
            a.fill(a.line(x + 0.6, y + 2 + k * h / 3.4, x + w - 0.6, y + 3 + k * h / 3.4 + 0.5, 0.35), '#000000', 0.22)
    return m


def trigger_guard(a, g, x0, x1, y, depth=4.5):
    pts = []
    n = 10
    for i in range(n + 1):
        t = i / n
        pts.append((x0 + (x1 - x0) * t, y + np.sin(t * np.pi) * depth))
    for (p, q) in zip(pts, pts[1:]):
        a.fill(a.line(p[0], p[1], q[0], q[1], 1.1), lit(g.trim, 0.9), 1.0)
    a.fill(a.line(x0 + (x1 - x0) * 0.45, y + 0.4, x0 + (x1 - x0) * 0.42, y + depth * 0.65, 0.9), '#0d0d0f', 1.0)       # trigger


def stock(a, g, x, y, kind, h=7.0):
    """butt-stock ending at x (its front end) with its top at y; extends left"""
    if kind == 'wood':
        m = a.poly([(x, y), (x - 15, y + 1.8), (x - 17, y + h + 2.5), (x - 15, y + h + 3.0), (x, y + h - 0.6)])
        paint(a, g, m, g.wood, bevel=2.4, strength=0.9, spec=0.25, grain=0.6, seed=5)
        for k in range(4):
            a.fill(a.line(x - 1, y + 1.6 + k * 1.6, x - 14, y + 2.8 + k * 1.8, 0.35), '#000000', 0.22)
        a.fill(a.rect(x - 17, y + 2.4, 1.6, h + 0.6), '#17181b', 0.95)
    elif kind == 'solid':
        m = a.poly([(x, y), (x - 13, y + 1.6), (x - 15, y + h + 2.0), (x - 13, y + h + 2.6), (x, y + h - 0.4)])
        paint(a, g, m, '#26282d', bevel=2.2, strength=0.9, spec=0.3, grain=0.35, seed=6)
        a.fill(a.rect(x - 15.2, y + 2.2, 1.8, h + 0.4), '#111214', 0.95)
    elif kind == 'skel':
        for (p, q) in (((x, y + 0.5), (x - 14, y + 1.8)), ((x - 14, y + 1.8), (x - 15, y + h + 2)), ((x, y + h - 1), (x - 15, y + h + 2))):
            a.fill(a.line(p[0], p[1], q[0], q[1], 1.5), '#2a2d33', 1.0)
        a.shade(a.rect(x - 16, y + 1.6, 2.4, h + 1.2), '#17181b', bevel=0.8)
    elif kind == 'folded':
        m = a.rrect(x - 4, y + 0.4, 4.2, h - 0.6, 1)
        paint(a, g, m, '#26282d', bevel=1.2, spec=0.4)
        a.fill(a.rect(x - 4.8, y + 1, 1.4, h - 1.6), '#111214', 0.9)
    elif kind == 'thumb':
        m = a.poly([(x, y), (x - 15, y + 1.6), (x - 18, y + h + 3.0), (x - 14, y + h + 3.4), (x - 10, y + h + 1.6), (x - 2, y + h + 4.0), (x, y + h)])
        paint(a, g, m, g.wood, bevel=2.2, strength=0.9, spec=0.25, grain=0.5, seed=8)
        a.fill(a.ellipse(x - 8, y + h * 0.65, 2.0, 1.8), '#00000000' if False else '#14161a', 0.9)
        a.fill(a.rect(x - 18.2, y + 2.6, 1.8, h + 0.6), '#17181b', 0.95)
    elif kind == 'pad':
        m = a.rrect(x - 12, y + 0.6, 12.4, h + 1.6, 2.4)
        paint(a, g, m, '#2b2d32', bevel=2.2, strength=0.9, spec=0.3)
        a.fill(a.rect(x - 12.4, y + 1.4, 1.8, h), '#101113', 0.95)
        a.fill(a.line(x - 10, y + h * 0.5 + 1, x - 2, y + h * 0.5 + 1, 0.6), g.acc, 0.8)


# ------------------------------------------------------------------------------------------------ classes
def pistol(a, g):
    r = g.r
    x0 = 14 + r.randint(0, 3)
    sl = r.randint(20, 25)
    y = 22
    sh = 8.4 + r.random() * 1.2
    slide = a.rrect(x0, y, sl, sh, 2.2)
    frame = a.poly([(x0 + 0.5, y + sh - 1.0), (x0 + sl - 5, y + sh - 1.0), (x0 + sl - 6, y + sh + 3.2), (x0 + 12, y + sh + 3.2), (x0 + 11, y + sh + 6), (x0 + 3, y + sh + 6), (x0 + 1, y + sh + 2)])
    barrel = a.rect(x0 + sl - 0.5, y + 1.6, 4 + r.randint(0, 3), 3.2)
    a.shadow(slide | frame | barrel, 1.8, 2.8, 2.4, 0.5)
    gt = r.choice([3.0, 4.0, 5.5])
    gw = 9.5
    gm = grip(a, g, x0 + 1.5, y + sh + 0.5, gw, 17, gt, wood=(g.mk['name'] in ('Sakurai', 'Volkov')) and r.random() < 0.5)
    paint(a, g, frame, lit(g.trim, 1.0), bevel=1.8, strength=0.9, spec=0.3, grain=0.2, seed=4)
    paint(a, g, barrel, g.steel, bevel=1.2, spec=0.7)
    paint(a, g, slide, g.body, bevel=2.2, strength=0.95, spec=0.55, grain=0.1, seed=2)
    # slide detail: serrations, ejection port, cut-outs, top stripe
    for k in range(r.choice([4, 5, 6])):
        a.fill(a.rect(x0 + 2.0 + k * 1.5, y + 1.0, 0.7, sh - 2.0), '#0f1114', 0.85)
    port = a.rect(x0 + sl * 0.45, y + 1.6, sl * 0.3, 2.4)
    a.fill(port, '#0a0b0d', 0.95)
    a.fill(a.rect(x0 + sl * 0.5, y + 2.6, sl * 0.14, 1.2), '#b6a44a', 0.9)
    if r.random() < 0.5:
        for k in range(3):
            a.fill(a.rect(x0 + sl * 0.2 + k * 1.2, y + 0.9, 0.5, sh * 0.5), '#0a0b0d', 0.7)
    a.fill(a.rect(x0 + 1.5, y + 0.9, sl - 3, 0.9), lit(g.body, 1.5), 0.7)
    trigger_guard(a, g, x0 + 13, x0 + 22, y + sh + 3.0, 4.2)
    # sights
    a.fill(a.rect(x0 + sl - 2.4, y - 1.4, 1.6, 1.6), '#0f1114')
    a.fill(a.rect(x0 + sl - 2.4, y - 1.4, 0.8, 0.8), '#e9e9e9', 0.9)
    a.fill(a.rect(x0 + 1.0, y - 1.2, 2.0, 1.4), '#0f1114')
    if r.random() < 0.45:
        optic(a, g, x0 + 7, y, 'dot')
    # mag base plate and accent
    if r.random() < 0.6:
        a.fill(a.rect(x0 + 0.6 + gt * 1.0, y + sh + 17, gw + 0.4, 2.2), g.acc, 1.0)
    else:
        a.shade(a.rrect(x0 + 0.6 + gt * 1.0, y + sh + 17, gw + 0.4, 2.4, 0.8), g.steel, bevel=0.8, spec=0.6)
    led(a, x0 + sl - 4.5, y + 6.4, g.acc, 0.6, 5)
    if r.random() < 0.5:
        strip(a, x0 + 3, y + sh - 1.4, x0 + 12, y + sh - 1.4, g.acc, 0.7, 3)
    if r.random() < 0.4:
        muzzle(a, g, x0 + sl + 3, y + 3.2, 'supp')
    return 'pistol'


def revolver(a, g):
    r = g.r
    x0 = 14
    y = 24
    bl = r.randint(14, 24)
    frame = a.poly([(x0, y), (x0 + 15, y), (x0 + 15, y + 9), (x0 + 9, y + 10), (x0 + 4, y + 14), (x0, y + 6)])
    cyl = a.rrect(x0 + 6, y - 1.8, 11, 12.4, 2.4)
    barrel = a.rect(x0 + 15, y + 0.8, bl, 4.2)
    shroud = a.rect(x0 + 15, y + 5.4, bl * 0.7, 3.0)
    a.shadow(frame | cyl | barrel | shroud, 1.8, 2.8, 2.4, 0.5)
    gm = grip(a, g, x0 - 2.5, y + 5, 10.5, 19, -3.5, wood=True)
    paint(a, g, frame, g.body, bevel=2.2, strength=0.95, spec=0.6, seed=5)
    paint(a, g, barrel, lit(g.steel, 0.85), bevel=1.6, spec=0.8)
    paint(a, g, shroud, g.trim, bevel=1.4, spec=0.5)
    paint(a, g, cyl, g.steel, bevel=2.4, strength=0.95, spec=0.8, grain=0.1)
    for k in range(6):
        ang = k / 6 * 6.283
        a.fill(a.ellipse(x0 + 11.5 + 0.0, y + 4.2 + (k - 2.5) * 1.8, 0.5, 0.9), '#14161a', 0.75)
    for k in range(5):
        a.fill(a.rect(x0 + 8.2 + k * 1.9, y - 0.8, 0.5, 10.6), '#16181b', 0.55)      # flutes
    trigger_guard(a, g, x0 + 4, x0 + 12, y + 10.2, 4.8)
    a.fill(a.rect(x0 + 0.2, y - 2.0, 3.4, 3.0), lit(g.body, 0.8))     # hammer
    a.fill(a.rect(x0 + 15 + bl - 3, y - 0.8, 2, 1.8), '#e9e9e9', 0.9)
    if r.random() < 0.5:
        rail(a, x0 + 17, x0 + 14 + bl, y - 0.6, 1.4)
    strip(a, x0 + 17, y + 3.0, x0 + 14 + bl, y + 3.0, g.acc, 0.6, 3)
    led(a, x0 + 2.5, y + 2.6, g.acc, 0.6, 4)
    if r.random() < 0.35:
        muzzle(a, g, x0 + 15 + bl, y + 2.9, 'brake')


def smg(a, g):
    r = g.r
    x0 = 18
    y = 22
    rl = r.randint(18, 22)
    bl = r.randint(6, 12)
    recv = a.rrect(x0, y, rl, 10.0, 2.6)
    hguard = a.rrect(x0 + rl - 1, y + 0.8, 11, 8.4, 2.0)
    barrel = a.rect(x0 + rl + 9, y + 3.6, bl, 2.8)
    a.shadow(recv | hguard | barrel | a.rect(x0 - 12, y, 12, 12), 1.8, 2.8, 2.4, 0.5)
    stk = r.choice(['folded', 'skel', 'pad', 'none'])
    if stk != 'none':
        stock(a, g, x0 + 0.5, y + 1.0, stk, 6.6)
    gt = r.choice([1.5, 3.0])
    grip(a, g, x0 + 3.5, y + 9, 8.2, 14, gt, wood=g.mk['name'] == 'Volkov')
    # magazine: straight and long for an SMG
    ml = 11 + g.mag * 0.35
    mag_box(a, g, x0 + rl * 0.55, y + 9.2, 6.4, min(ml, 24), r.choice([0.0, 0.1, 0.25]), tilt=0.0)
    paint(a, g, hguard, lit(g.trim, 1.0), bevel=2.0, strength=0.95, spec=0.35, grain=0.2, seed=4)
    for k in range(6):
        a.fill(a.ellipse(x0 + rl + 1.8 + k * 1.6, y + 4.8, 0.55, 0.9) if False else a.rect(x0 + rl + 1.4 + k * 1.6, y + 2.2, 0.8, 1.6), '#08090a', 0.9)
        a.fill(a.rect(x0 + rl + 1.4 + k * 1.6, y + 6.4, 0.8, 1.6), '#08090a', 0.9)
    paint(a, g, barrel, g.steel, bevel=1.0, spec=0.7)
    paint(a, g, recv, g.body, bevel=2.6, strength=1.0, spec=0.5, seed=2)
    a.fill(a.rect(x0 + 1, y + 1.0, rl - 2, 0.9), lit(g.body, 1.5), 0.7)
    a.fill(a.rect(x0 + rl * 0.35, y + 2.6, rl * 0.3, 2.2), '#0a0b0d', 0.95)      # ejection port
    a.fill(a.rect(x0 + rl * 0.42, y + 3.4, 2.6, 1.0), '#b6a44a', 0.9)
    trigger_guard(a, g, x0 + 10, x0 + 18.5, y + 10.0, 4.4)
    a.shade(a.rect(x0 + rl * 0.62 - 4.4, y - 2.2, 4.6, 2.4), lit(g.trim, 1.1), bevel=0.8)   # charging handle
    o = r.choice(['dot', 'holo', 'iron', 'iron'])
    optic(a, g, x0 + 4, y, o)
    led(a, x0 + 4.6, y + 7.4, g.acc, 0.65, 5)
    strip(a, x0 + 8, y + 8.6, x0 + rl - 3, y + 8.6, g.acc, 0.6, 3)
    mz = r.choice(['supp', 'brake', 'hider', 'none'])
    muzzle(a, g, x0 + rl + 9 + bl, y + 5.0, mz)


def rifle(a, g):
    r = g.r
    style = 'bullpup' if g.mk['name'] == 'Lin' and r.random() < 0.7 else ('ak' if g.mk['name'] in ('Volkov', 'Zaytsev') else 'ar')
    y = 22
    if style == 'bullpup':
        x0 = 12
        recv = a.rrect(x0, y, 32, 12, 4)
        grp = grip(a, g, x0 + 20, y + 10, 8, 12, 2.4)
        a.shadow(recv | a.rect(x0 + 30, y + 3, 24, 4), 1.8, 2.8, 2.4, 0.5)
        barrel = a.rect(x0 + 31, y + 3.6, 22, 2.8)
        mag_box(a, g, x0 + 12, y + 11.5, 7.2, 13 + g.mag * 0.25, 0.1)
        paint(a, g, barrel, g.steel, bevel=1.0, spec=0.7)
        paint(a, g, recv, g.body, bevel=3.2, strength=1.0, spec=0.55, grain=0.1, seed=2)
        pad = a.rrect(x0 - 1, y + 1, 5, 11, 2.4)
        paint(a, g, pad, '#25272c', bevel=1.6, spec=0.3)
        a.fill(a.rect(x0 + 30, y + 1, 3, 8), g.trim, 0.95)
        a.fill(a.rect(x0 + 5, y + 4, 12, 2.2), '#0a0b0d', 0.9)
        trigger_guard(a, g, x0 + 16, x0 + 24, y + 11.4, 4.2)
        optic(a, g, x0 + 10, y, r.choice(['holo', 'dot', 'scope']))
        a.fill(a.line(x0 + 4, y + 8, x0 + 30, y + 8, 0.7), g.acc, 0.9)
        led(a, x0 + 28, y + 5, g.acc, 0.7, 5)
        muzzle(a, g, x0 + 53, y + 5.0, r.choice(['hider', 'brake', 'supp']))
        return
    x0 = 20
    rl = 18 if style == 'ar' else 20
    recv = a.rrect(x0, y, rl, 11, 2.4)
    hg_len = r.randint(16, 20)
    hguard = a.rrect(x0 + rl - 2, y + 0.4, hg_len, 10, 2.8 if style == 'ar' else 1.6)
    brl = a.rect(x0 + rl - 2 + hg_len - 1, y + 3.8, 6 + r.randint(0, 2), 2.4)
    stk_kind = r.choice(['wood', 'solid', 'skel']) if style == 'ak' else r.choice(['solid', 'skel', 'pad'])
    if style == 'ak':
        stk_kind = 'wood' if g.mk['name'] in ('Volkov', 'Zaytsev') and r.random() < 0.8 else 'skel'
    a.shadow(recv | hguard | a.rect(x0 - 17, y, 17, 14) | brl | a.rect(x0 + 6, y + 11, 8, 22), 1.8, 2.8, 2.4, 0.5)
    stock(a, g, x0 + 0.5, y + 0.8, stk_kind, 7.0)
    grip(a, g, x0 + 3, y + 10, 8, 13, 3.0, wood=style == 'ak' and r.random() < 0.6)
    ml = 10 + g.mag * 0.36
    mag_box(a, g, x0 + rl * 0.55, y + 10.4, 7.0, min(ml, 24), 0.28 if style == 'ak' else r.choice([0.0, 0.08]), tilt=0.0)
    if style == 'ak':
        hg_c, rc = g.wood, g.body
    else:
        hg_c, rc = lit(g.trim, 1.0), g.body
    paint(a, g, hguard, hg_c, bevel=2.2, strength=0.95, spec=0.25, grain=0.55 if style == 'ak' else 0.2, seed=4)
    for k in range(5):
        a.fill(a.rect(x0 + rl + 1 + k * 3.0, y + 1.2, 1.2, 2.0), '#08090a', 0.85)
        a.fill(a.rect(x0 + rl + 1 + k * 3.0, y + 7.6, 1.2, 2.0), '#08090a', 0.85)
    paint(a, g, brl, g.steel, bevel=1.0, spec=0.7)
    paint(a, g, recv, rc, bevel=2.4, strength=1.0, spec=0.55, grain=0.1, seed=2)
    a.fill(a.rect(x0 + 1, y + 0.9, rl - 2, 0.9), lit(rc, 1.5), 0.7)
    a.fill(a.rect(x0 + rl * 0.4, y + 2.6, rl * 0.3, 2.4), '#0a0b0d', 0.95)
    a.fill(a.rect(x0 + rl * 0.46, y + 3.5, 2.6, 1.0), '#b6a44a', 0.9)
    trigger_guard(a, g, x0 + 9, x0 + 17.5, y + 10.4, 4.4)
    a.shade(a.rect(x0 + rl * 0.55, y - 1.8, 4.2, 2.2), lit(g.trim, 1.1), bevel=0.8)
    if style == 'ar':
        rail(a, x0, x0 + rl + hg_len - 2, y - 1.5, 1.6)
        o = r.choice(['dot', 'holo', 'scope', 'iron'])
        optic(a, g, x0 + 5, y - 1.5, o)
        if r.random() < 0.5:
            a.shade(a.rect(x0 + rl + hg_len * 0.45, y + 10.4, 3.4, 5.5), '#1d1f23', bevel=1.0, spec=0.4)    # foregrip
    else:
        a.fill(a.line(x0 + rl, y + 1.2, x0 + rl + hg_len - 2, y + 1.2, 1.0), '#17181b', 0.8)         # gas tube
        optic(a, g, x0 + 4, y, r.choice(['iron', 'iron', 'dot']))
        a.shade(a.rect(x0 + rl + hg_len + 3, y + 1.6, 1.6, 4.4), '#17181b', bevel=0.6)    # gas block / front sight
    led(a, x0 + 3.6, y + 8, g.acc, 0.65, 5)
    strip(a, x0 + 8, y + 9.0, x0 + rl - 2, y + 9.0, g.acc, 0.6, 3)
    muzzle(a, g, x0 + rl - 2 + hg_len + 5 + 5.4, y + 5.0, r.choice(['hider', 'brake', 'supp', 'hider']))


def shotgun(a, g):
    r = g.r
    name = g.code
    y = 24
    x0 = 18
    double = name.startswith('FS-410') or name.startswith('ZS-20') and False
    pump = r.random() < 0.6
    recv = a.rrect(x0, y, 17, 10, 2.4)
    barrel = a.rrect(x0 + 16, y + 1.0, 34, 3.6, 1.6)
    tube = a.rrect(x0 + 16, y + 5.6, 26, 3.0, 1.4)
    fore = a.rrect(x0 + 20, y + 4.6, 16, 6.4, 2.6)
    a.shadow(recv | barrel | tube | fore | a.rect(x0 - 20, y, 20, 14), 1.8, 2.8, 2.4, 0.5)
    stock(a, g, x0 + 0.5, y + 0.6, r.choice(['wood', 'wood', 'solid', 'thumb']), 7.4)
    grip(a, g, x0 + 3.0, y + 9.4, 8.2, 12, 3.0, wood=r.random() < 0.5)
    paint(a, g, barrel, g.steel, bevel=1.4, spec=0.8)
    if not double:
        paint(a, g, tube, lit(g.steel, 0.82), bevel=1.2, spec=0.7)
    else:
        a.shade(a.rrect(x0 + 16, y + 4.4, 34, 3.6, 1.6), g.steel, bevel=1.4, spec=0.8)
    paint(a, g, fore, g.wood if r.random() < 0.7 else '#2a2c31', bevel=2.4, strength=0.95, spec=0.25, grain=0.5, seed=4)
    for k in range(4):
        a.fill(a.rect(x0 + 22 + k * 3.2, y + 5.4, 0.6, 4.4), '#000000', 0.35)
    paint(a, g, recv, g.body, bevel=2.4, strength=1.0, spec=0.55, grain=0.12, seed=2)
    a.fill(a.rect(x0 + 5, y + 2.4, 7, 2.2), '#0a0b0d', 0.95)           # ejection port
    a.fill(a.rect(x0 + 6.4, y + 3.1, 2.4, 0.9), '#c24a3a', 0.95)       # a red shell rim
    trigger_guard(a, g, x0 + 7, x0 + 15, y + 9.8, 4.0)
    a.fill(a.ellipse(x0 + 49.5, y + 1.0, 0.9), '#e9e9e9', 1.0)         # bead sight
    a.fill(a.rect(x0 + 17, y + 0.2, 31, 0.6), lit(g.steel, 1.4), 0.9)  # rib
    muzzle(a, g, x0 + 50, y + 2.8, r.choice(['none', 'none', 'brake']))
    led(a, x0 + 3.2, y + 6.4, g.acc, 0.65, 5)
    strip(a, x0 + 4, y + 8.4, x0 + 15, y + 8.4, g.acc, 0.6, 3)
    if r.random() < 0.5:
        a.shade(a.rect(x0 + 44, y + 5.6, 4.0, 3.2), g.trim, bevel=0.8)       # mag cap


def sniper(a, g):
    r = g.r
    y = 28
    x0 = 18
    bl_ = r.randint(28, 40)
    fl_ = r.randint(12, 22)
    rl_ = r.randint(18, 24)
    recv = a.rrect(x0, y, rl_, 9.4, 2.0)
    barrel = a.rrect(x0 + rl_ - 1, y + 2.6, bl_ + 1, 3.6 if r.random() < 0.6 else 4.6, 1.6)
    fore = a.rrect(x0 + rl_ - 1, y + 1.4, fl_, r.choice([6.2, 7, 8]), 2.2)
    a.shadow(recv | barrel | fore | a.rect(x0 - 17, y, 17, 14) | a.rect(x0 + 4, y + 9, 10, 8), 1.8, 2.8, 2.4, 0.5)
    stock(a, g, x0 + 0.5, y + 0.6, r.choice(['thumb', 'thumb', 'wood']), 7.4)
    grip(a, g, x0 + 2.5, y + 8.8, 8, 12, 3.2, wood=False)
    paint(a, g, fore, lit(g.trim, 1.0), bevel=2.0, strength=0.95, spec=0.3, grain=0.2, seed=4)
    paint(a, g, barrel, g.steel, bevel=1.6, spec=0.85)
    paint(a, g, recv, g.body, bevel=2.2, strength=1.0, spec=0.55, grain=0.1, seed=2)
    mag_box(a, g, x0 + 9, y + 9.0, 6.4, 7 + g.mag * 0.4, 0.0)
    for k in range(int(fl_ / 4)):
        a.fill(a.rect(x0 + rl_ + 1 + k * 3.8, y + 2.6, 1.2, 1.8), '#08090a', 0.85)
    # bolt handle
    a.shade(a.line(x0 + 12, y + 3.6, x0 + 9, y + 0.0, 1.6), lit(g.steel, 1.0), bevel=0.8, spec=0.8)
    a.shade(a.ellipse(x0 + 8.4, y - 0.8, 1.9), '#1d1f23', bevel=1.2, spec=0.5)
    # bipod folded under the fore-end
    if r.random() < 0.6:
        a.shade(a.line(x0 + rl_ + 6, y + 8.2, x0 + rl_ + 16, y + 12.0, 1.4), '#23262b', bevel=0.7, spec=0.5)
        a.shade(a.line(x0 + rl_ + 6, y + 8.2, x0 + rl_ + 16, y + 9.6, 1.4), '#23262b', bevel=0.7, spec=0.5)
    else:
        a.shade(a.rect(x0 + rl_ + 8, y + 7.4, 8, 3.2), '#23262b', bevel=0.8, spec=0.4)       # rail block
    # long scope
    for dx in (2, 14):
        a.shade(a.rect(x0 + dx, y - 3.0, 3, 3.0), '#2a2d33', bevel=0.7)
    optic(a, g, x0 + 1 + r.randint(0, 3), y - 2.4, r.choice(['long_scope', 'long_scope', 'scope']))
    trigger_guard(a, g, x0 + 8, x0 + 16, y + 9.2, 4.0)
    a.fill(a.rect(x0 + 21, y + 1.6, 14, 0.7), lit(g.trim, 1.6), 0.7)
    led(a, x0 + 4.0, y + 6.0, g.acc, 0.65, 5)
    muzzle(a, g, x0 + rl_ + bl_, y + 4.4, r.choice(['brake', 'hider', 'supp', 'bell']))


def mg(a, g, heavy=False):
    r = g.r
    y = 20
    x0 = 14 if not heavy else 10
    recv = a.rrect(x0, y, 24, 15, 3.0)
    shroud = a.rrect(x0 + 22, y + 1.6, 16, 11, 2.6)
    barrel = a.rrect(x0 + 37, y + 4.6, 14 + (4 if heavy else 0), 3.8 if not heavy else 5.0, 1.4)
    box = a.rrect(x0 + 6, y + 14, 16, 13, 2.4)
    a.shadow(recv | shroud | barrel | box | a.rect(x0 - 17, y, 17, 16), 1.8, 2.8, 2.4, 0.5)
    stock(a, g, x0 + 0.5, y + 1.6, r.choice(['solid', 'pad']), 8.0)
    grip(a, g, x0 + 4, y + 14, 8, 12, 3.0)
    paint(a, g, box, lit(g.trim, 1.15), bevel=2.2, strength=0.95, spec=0.3, grain=0.4, seed=8)
    for k in range(3):
        a.fill(a.rect(x0 + 8, y + 17 + k * 3.2, 12, 0.6), '#000000', 0.4)
    # belt of brass feeding in from the box
    for k in range(6):
        a.fill(a.rrect(x0 + 21 - k * 0.2, y + 15 + k * 2.0, 3.2, 1.4, 0.5), '#d6b24a', 0.95)
    paint(a, g, shroud, lit(g.trim, 1.0), bevel=2.6, strength=0.95, spec=0.3, grain=0.25, seed=4)
    for k in range(5):
        for j in range(2):
            a.fill(a.ellipse(x0 + 25 + k * 2.8, y + 4.2 + j * 5.6, 0.9, 0.9), '#08090a', 0.9)
    paint(a, g, barrel, g.steel, bevel=1.6, spec=0.8)
    paint(a, g, recv, g.body, bevel=3.0, strength=1.0, spec=0.5, grain=0.12, seed=2)
    a.fill(a.rect(x0 + 8, y + 4, 9, 3.2), '#0a0b0d', 0.95)
    a.shade(a.rrect(x0 + 6, y - 3.0, 14, 3.4, 1.6), lit(g.trim, 1.1), bevel=1.2, spec=0.4)          # carry handle
    a.shade(a.line(x0 + 26, y + 12.8, x0 + 34, y + 18.4, 1.5), '#23262b', bevel=0.7, spec=0.5)      # bipod legs
    a.shade(a.line(x0 + 26, y + 12.8, x0 + 34, y + 15.2, 1.5), '#23262b', bevel=0.7, spec=0.5)
    trigger_guard(a, g, x0 + 11, x0 + 19, y + 14.4, 3.6)
    optic(a, g, x0 + 22, y + 1.6, 'iron')
    led(a, x0 + 3.0, y + 8.8, g.acc, 0.7, 5)
    strip(a, x0 + 8, y + 12, x0 + 22, y + 12, g.acc, 0.7, 3)
    muzzle(a, g, x0 + 51 + (4 if heavy else 0), y + 6.5, 'hider' if not heavy else 'brake')


def launcher(a, g):
    r = g.r
    y = 22
    x0 = 12
    brl = a.rrect(x0 + 14, y + 2, 38, 10.5, 4.0)
    drum = a.rrect(x0 + 15, y - 0.8, 14, 15, 4.0)
    recv = a.rrect(x0 + 1, y + 3, 16, 10, 2.4)
    a.shadow(brl | drum | recv | a.rect(x0 - 12, y + 3, 12, 12), 1.8, 2.8, 2.4, 0.5)
    stock(a, g, x0 + 1.5, y + 3.4, r.choice(['solid', 'skel']), 7.0)
    grip(a, g, x0 + 6.0, y + 12, 8, 12, 3.0)
    paint(a, g, brl, lit(g.body, 1.0), bevel=4.0, strength=1.0, spec=0.6, grain=0.2, seed=3)
    paint(a, g, drum, lit(g.trim, 1.25), bevel=4.4, strength=1.0, spec=0.5, grain=0.3, seed=5)
    for k in range(6):
        ang = k / 6 * 6.283
        a.fill(a.ellipse(x0 + 22, y + 6.7, 0.1, 0.1) if False else a.rect(x0 + 15 + k * 2.4, y + 1.0, 0.6, 12.4), '#000000', 0.3)
    paint(a, g, recv, g.body, bevel=2.4, strength=1.0, spec=0.5, seed=2)
    a.fill(a.ellipse(x0 + 52, y + 7.2, 3.6, 4.8), '#050506', 1.0)           # bore
    a.fill(a.ellipse(x0 + 51.6, y + 7.2, 2.4, 3.4), '#16181d', 1.0)
    a.fill(a.rect(x0 + 32, y + 4.4, 14, 1.0), g.acc, 0.9)
    a.shade(a.rect(x0 + 28, y - 3.6, 9, 3.6), '#25272c', bevel=1.2, spec=0.4)         # leaf sight
    a.fill(a.rect(x0 + 29.4, y - 3.0, 6, 0.8), g.acc, 0.95)
    a.shade(a.line(x0 + 36, y + 12, x0 + 38, y + 17, 2.2), '#25272c', bevel=1.0)       # fore handle
    trigger_guard(a, g, x0 + 9, x0 + 16, y + 12, 3.6)
    led(a, x0 + 4.0, y + 8.2, g.acc, 0.7, 5)


def laser(a, g):
    r = g.r
    y = 24
    x0 = 14
    cell = a.rrect(x0 + 1, y + 1, 14, 9.4, 3.0)
    recv = a.rrect(x0 + 13, y, 18, 10.4, 3.0)
    emit = a.rrect(x0 + 30, y + 2.0, 20, 6.4, 3.0)
    a.shadow(cell | recv | emit | a.rect(x0 + 10, y + 10, 8, 14), 1.8, 2.8, 2.4, 0.5)
    grip(a, g, x0 + 14, y + 9.6, 8, 14, 3.0)
    paint(a, g, emit, lit(g.body, 1.1), bevel=2.8, strength=1.0, spec=0.7, grain=0.1, seed=3)
    # glowing coils along the emitter
    for k in range(5):
        a.fill(a.rect(x0 + 32.4 + k * 3.4, y + 2.2, 1.6, 6.0), g.acc, 0.95)
        a.glow(x0 + 33.2 + k * 3.4, y + 5.2, 6, g.acc, 0.32)
    a.fill(a.ellipse(x0 + 50, y + 5.2, 2.4, 3.4), '#e8fbff', 1.0)
    a.glow(x0 + 50, y + 5.2, 10, g.acc, 0.8)
    paint(a, g, recv, g.body, bevel=3.0, strength=1.0, spec=0.55, grain=0.1, seed=2)
    paint(a, g, cell, lit(g.trim, 1.3), bevel=3.0, strength=1.0, spec=0.5, seed=4)
    a.fill(a.rect(x0 + 3, y + 3.2, 10, 3.6), '#0b1013', 0.95)
    for k in range(g.mag // 3):
        a.fill(a.rect(x0 + 3.5 + k * 2.2, y + 3.8, 1.4, 2.4), g.acc, 0.95)
    a.glow(x0 + 8, y + 5.0, 10, g.acc, 0.3)
    trigger_guard(a, g, x0 + 15, x0 + 23, y + 10.0, 4.0)
    optic(a, g, x0 + 16, y, 'holo')
    led(a, x0 + 27, y + 4.0, g.acc, 0.8, 6)
    strip(a, x0 + 16, y + 8.4, x0 + 29, y + 8.4, g.acc, 0.7, 3)


CLASSES = {'pistol': pistol, 'revolver': revolver, 'smg': smg, 'rifle': rifle, 'shotgun': shotgun, 'sniper': sniper,
           'mg': lambda a, g: mg(a, g, False), 'heavy_mg': lambda a, g: mg(a, g, True), 'launcher': launcher, 'laser': laser}


def gun_icon(it, variant=0):
    r = rng_for(it['id'] + str(variant))
    a = Art(64, 64, 4)
    g = G(it, r)
    CLASSES[g.cls](a, g)
    ys = {'rifle': 0.80, 'sniper': 0.80, 'shotgun': 0.84, 'mg': 0.84, 'heavy_mg': 0.84, 'smg': 0.9}.get(g.cls, 1.0)
    return a.image(outline=0.85, ys=ys, yc=34, fit=60, zmax=1.55)


def hold_from_icon(icon, grip_xy, length_px=None):
    """a top-down 'hold' layer from a side-view icon: rotated to point up with its grip at the doll's hands"""
    SZ = 96
    bb = icon.getbbox()
    ic = icon.crop(bb)
    # squash the side view a little: from above a gun is slimmer than it looks from the side
    w, h = ic.size
    ic = ic.resize((w, max(4, int(h * 0.62))), Image.LANCZOS)
    up = ic.rotate(90, expand=True, resample=Image.BICUBIC)       # tip to the top
    gx = (grip_xy[0] - bb[0]) / max(w, 1)
    gy = (grip_xy[1] - bb[1]) / max(h, 1)
    out = Image.new('RGBA', (SZ, SZ), (0, 0, 0, 0))
    # the grip sits at (gx fraction along the length from the rear): after rotation, rear is at the bottom
    px = 48 - up.width // 2
    py = int(29 - up.height * (1 - gx))
    out.alpha_composite(up, (px, py))
    return out
