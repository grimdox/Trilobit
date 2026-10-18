"""Top-down paper doll for the 64px tileset.  Every layer is a 96x96 image of the figure facing UP, centred on (48, 48);
the game rotates the whole stack to the facing.  Skin and hair layers are drawn in grey so the game can tint them."""
import numpy as np
from PIL import Image
from art64 import Art, col, mix, lit, tint, hx

CX, CY = 48, 48
SZ = 96


def A():
    return Art(SZ, SZ, 4)


def done(a, outline=0.8):
    return a.image(outline=outline)


# anatomy ------------------------------------------------------------------------------------------
def shoulders(a, fem=False):
    rx = 13.5 if fem else 16.0
    t = a.ellipse(CX, CY + 1, rx, 10.5)
    b = a.ellipse(CX, CY + 3, rx - 3, 12.5 if not fem else 13.5)
    return t | b


def arm_masks(a, fem=False, long_sleeve=True, reach=1.0):
    """upper arm + forearm capsules for both sides; hands at (CX +- 6, CY - 17)"""
    sx = 13.0 if fem else 15.0
    out = {}
    for side, s in (('l', -1), ('r', 1)):
        sh = (CX + s * sx, CY + 2)
        el = (CX + s * (sx + 1.8), CY - 6)
        hd = (CX + s * 5.2, CY - 18.5 * reach)
        out[side] = (sh, el, hd)
    return out


def limb(a, p0, p1, w):
    return a.line(p0[0], p0[1], p1[0], p1[1], w)


def hands_pos():
    return [(CX - 5.2, CY - 18.5), (CX + 5.2, CY - 18.5)]


# base layers --------------------------------------------------------------------------------------
def shadow():
    a = A()
    sh = a.ellipse(CX + 2, CY + 5, 19, 16)
    a.fill(sh, '#000000', 0.0)
    import scipy.ndimage as ndi
    m = ndi.gaussian_filter(sh.astype(np.float32), 5 * a.ss / 2) * 0.55
    a.rgb[:] = 0
    a.a[:] = m
    return a.image()


def legs(kind='base', chrome=False):
    a = A()
    cloth = '#3d4556'
    boot = '#23252b'
    # left leg stepping forward, right leg trailing
    for (x, y0, y1, bx, by, sgn) in ((CX - 7, CY + 4, CY - 10, CX - 7, CY - 14, 1), (CX + 7, CY + 6, CY + 21, CX + 7, CY + 25, -1)):
        m = a.line(x, y0, x, y1, 10.5)
        a.shadow(m, 1.4, 1.8, 1.8, 0.35)
        a.shade(m, '#9aa3ad' if chrome else cloth, bevel=4.2, strength=0.9, spec=0.7 if chrome else 0.1, grain=0.0 if chrome else 0.2)
        bm = a.ellipse(bx, by, 6.0, 8.6)
        a.shade(bm, '#cfd6de' if chrome else boot, bevel=4, strength=1.0, spec=0.8 if chrome else 0.35)
        if not chrome:
            a.fill(a.ellipse(bx - 1.2, by - 3.2, 2.0, 2.6), '#3a3d44', 0.9)       # toe cap sheen
        else:
            a.fill(a.ellipse(bx, by, 2.2), '#35d7ff', 0.9)
    return done(a, 0.75)


def torso(fem=False):
    a = A()
    tee = '#8493a8'
    m = shoulders(a, fem)
    a.shadow(m, 1.2, 2.0, 2.2, 0.4)
    a.shade(m, tee, bevel=7.5, strength=1.0, grain=0.25, rough=1.1, seed=3 if fem else 4)
    # short sleeves
    for s in (-1, 1):
        sx = CX + s * (13.0 if fem else 15.0)
        sm = a.line(sx, CY + 2, sx + s * 1.8, CY - 6, 7.2)
        a.shade(sm, tee, bevel=3.2, strength=1.0, grain=0.2)
    # neckline
    a.fill(a.ellipse(CX, CY - 5, 4.8, 3.6), '#2a313b', 0.9)
    return done(a, 0.75)


def arms_skin(fem=False):
    """forearms in grey for tinting"""
    a = A()
    arms = arm_masks(a, fem)
    for side in ('l', 'r'):
        sh, el, hd = arms[side]
        m = limb(a, el, hd, 5.4)
        a.shadow(m, 1.0, 1.4, 1.4, 0.3)
        a.shade(m, '#ffffff', bevel=2.6, strength=0.85)
    return done(a, 0.5)


def hands(glove=None):
    a = A()
    for (x, y) in hands_pos():
        m = a.ellipse(x, y, 3.6, 3.8)
        a.shade(m, glove or '#ffffff', bevel=2.4, strength=0.9)
    return done(a, 0.55)


def head(fem=False):
    a = A()
    r = 8.2 if fem else 8.8
    for s_ in (-1, 1):
        a.shade(a.ellipse(CX + s_ * (r - 0.2), CY - 1.0, 1.9, 2.8), '#f0f0f0', bevel=1.4, strength=0.8)
    a.shade(a.ellipse(CX, CY + 2.8, 4.6, 3.6), '#d0d0d0', bevel=2, strength=0.7)
    m = a.ellipse(CX, CY - 1.6, r, r + 0.8)
    a.shadow(m, 1.2, 1.8, 2.0, 0.4)
    a.shade(m, '#f4f4f4', bevel=5.0, strength=0.8)
    a.fill(a.ellipse(CX, CY - 9.2, 2.6, 1.3), '#d6d6d6', 0.8)      # nose
    return done(a, 0.7)


def hair(style):
    a = A()
    r = 9.4
    cy = CY + 0.4
    if style == 'short':
        m = a.ellipse(CX, cy, r, 9.0)
        a.shade(m, '#e6e6e6', bevel=4.5, strength=1.0, grain=0.6, rough=1.0, seed=3)
    elif style == 'long':
        m = a.ellipse(CX, cy, r, 9.0) | a.rrect(CX - 10, CY + 1, 20, 19, 8)
        a.shade(m, '#e6e6e6', bevel=5, strength=1.0, grain=0.6, rough=1.0, seed=5)
        a.fill(a.line(CX, CY - 6, CX, CY + 16, 0.9), '#000000', 0.2)
    elif style == 'bob':
        m = a.ellipse(CX, cy, r + 1.4, 9.8) | a.rrect(CX - 10.8, CY - 2, 21.6, 12, 6)
        a.shade(m, '#e6e6e6', bevel=5, strength=1.0, grain=0.55, rough=1.0, seed=6)
    elif style == 'ponytail':
        m = a.ellipse(CX, cy, r, 9.0)
        a.shade(m, '#e6e6e6', bevel=4.5, strength=1.0, grain=0.55, seed=7)
        a.shade(a.line(CX, CY + 7, CX + 1, CY + 20, 4.0), '#e6e6e6', bevel=2, strength=1.0, grain=0.55, seed=8)
        a.shade(a.ellipse(CX, CY + 7, 2.4), '#9a9a9a', bevel=1.4)
    elif style == 'mohawk':
        m = a.rrect(CX - 3.0, CY - 11, 6, 24, 3)
        a.shade(m, '#e6e6e6', bevel=2.6, strength=1.0, grain=0.5, seed=9)
    elif style == 'buzz':
        m = a.ellipse(CX, cy + 0.6, r - 0.6, 8.4)
        a.shade(m, '#e6e6e6', bevel=3, strength=0.5, grain=0.9, rough=0.8, seed=10)
        a.fill(m, '#000000', 0.38)
    elif style == 'bun':
        m = a.ellipse(CX, cy, r, 9.0)
        a.shade(m, '#e6e6e6', bevel=4.5, strength=1.0, grain=0.55, seed=11)
        a.shade(a.ellipse(CX, CY + 5, 4.8), '#d4d4d4', bevel=3.6, strength=1.0, grain=0.5, seed=12)
    else:
        return Image.new('RGBA', (SZ, SZ), (0, 0, 0, 0))
    return done(a, 0.6)


# outfits ------------------------------------------------------------------------------------------
def _torso_arms(a, c, c2=None, fem=False, sleeve=True, collar=None, bevel=6.5, grain=0.3, seed=1, spec=0.0, long=True):
    m = shoulders(a, fem)
    a.shadow(m, 1.2, 2.0, 2.2, 0.4)
    a.shade(m, c, bevel=bevel, strength=1.0, grain=grain, rough=1.1, seed=seed, spec=spec)
    arms = arm_masks(a, fem)
    for side in ('l', 'r'):
        sh, el, hd = arms[side]
        up = limb(a, sh, el, 7.6)
        a.shade(up, c, bevel=3.4, strength=1.0, grain=grain, seed=seed + 1, spec=spec)
        if sleeve:
            fo = limb(a, el, hd, 6.0)
            a.shade(fo, c2 or c, bevel=2.8, strength=1.0, grain=grain, seed=seed + 2, spec=spec)
    if collar:
        a.fill(a.ellipse(CX, CY - 5, 5.2, 3.8), collar, 0.95)
    return m


def outfit_jacket(c, trim='#d8d8d8', fem=False):
    a = A()
    _torso_arms(a, c, grain=0.35, seed=21)
    # zipper line, collar, pockets, cuffs
    a.fill(a.line(CX, CY - 4, CX, CY + 14, 0.9), trim, 0.8)
    a.fill(a.ellipse(CX, CY - 5, 5.4, 3.6), lit(c, 0.7), 0.95)
    a.fill(a.ellipse(CX, CY - 5.4, 3.4, 2.1), '#1c1e22', 0.9)
    for s in (-1, 1):
        a.fill(a.rrect(CX + s * 8 - 3, CY + 5, 6, 3, 1), lit(c, 0.65), 0.9)
        el = (CX + s * 16.8, CY - 6)
        hd = (CX + s * 5.2, CY - 18.5)
        a.fill(a.line(hd[0] + s * 0.8, hd[1] + 2.5, hd[0] + s * 2.3, hd[1] + 5.2, 5.4), lit(c, 0.7), 0.9)     # cuff
    return done(a)


def outfit_labcoat():
    a = A()
    _torso_arms(a, '#e6eaee', bevel=7, grain=0.2, seed=22)
    a.fill(a.line(CX, CY - 4, CX, CY + 15, 0.9), '#a8b0ba', 0.9)
    for s in (-1, 1):
        a.fill(a.poly([(CX, CY - 5), (CX + s * 9, CY - 4), (CX + s * 6, CY + 3)]), '#cfd6de', 0.95)       # lapels
        a.fill(a.rrect(CX + s * 9 - 3, CY + 6, 7, 4, 1), '#cfd6de', 0.9)
    a.fill(a.rect(CX + 6, CY + 1, 5, 2.4), '#35d7ff', 0.9)       # name badge
    return done(a)


def outfit_chef():
    a = A()
    _torso_arms(a, '#f4f2ec', bevel=7, grain=0.2, seed=23)
    for s in (-1, 1):
        a.fill(a.ellipse(CX + s * 3.4, CY + 3, 1.2), '#8a8478', 0.9)
        a.fill(a.ellipse(CX + s * 3.4, CY + 8, 1.2), '#8a8478', 0.9)
    a.fill(a.line(CX - 3.4, CY - 4, CX - 3.4, CY + 14, 0.8), '#d8d4c8', 0.9)
    a.fill(a.line(CX + 3.4, CY - 4, CX + 3.4, CY + 14, 0.8), '#d8d4c8', 0.9)
    # apron
    a.shade(a.rrect(CX - 8, CY + 4, 16, 13, 3), '#cbbfa6', bevel=2.6, strength=0.8)
    a.fill(a.ellipse(CX, CY - 5, 5, 3.4), '#d8d4c8', 0.95)
    a.fill(a.ellipse(CX, CY - 5.4, 3, 2), '#2a2a2a', 0.8)
    return done(a)


def outfit_robe(c, trim, stole=None):
    a = A()
    # long robe: wide shoulders, flared hem behind
    hem = a.ellipse(CX, CY + 10, 17, 17)
    a.shadow(hem | shoulders(a), 1.4, 2.2, 2.4, 0.45)
    a.shade(hem, lit(c, 0.9), bevel=9, strength=1.0, grain=0.35, seed=24)
    _torso_arms(a, c, bevel=7, grain=0.3, seed=25)
    # wide sleeves
    arms = arm_masks(a)
    for side in ('l', 'r'):
        sh, el, hd = arms[side]
        s = -1 if side == 'l' else 1
        slv = a.poly([(el[0] - 4, el[1] - 2), (el[0] + 4, el[1] - 2), (hd[0] + s * 4.5, hd[1] + 6), (hd[0] - s * 1.5, hd[1] + 6)])
        a.shade(slv, c, bevel=2.6, strength=0.9, grain=0.3, seed=26)
    a.fill(a.ellipse(CX, CY - 5, 5.4, 3.8), trim, 0.95)
    a.fill(a.line(CX, CY - 3, CX, CY + 25, 1.2), trim, 0.8)
    if stole:
        for s in (-1, 1):
            a.fill(a.line(CX + s * 3.4, CY - 6, CX + s * 2.4, CY + 20, 2.6), stole, 0.95)
    return done(a)


def outfit_suit(c='#2c2f3a', accent='#35d7ff', shirt='#e9e9ee'):
    a = A()
    _torso_arms(a, c, bevel=6.5, grain=0.2, seed=27, spec=0.1)
    a.fill(a.poly([(CX - 4, CY - 5), (CX + 4, CY - 5), (CX, CY + 6)]), shirt, 0.95)
    a.fill(a.poly([(CX - 1, CY - 3), (CX + 1, CY - 3), (CX + 0.8, CY + 5), (CX - 0.8, CY + 5)]), accent, 0.95)
    for s in (-1, 1):
        a.fill(a.poly([(CX + s * 4, CY - 5), (CX + s * 10, CY - 4), (CX + s * 5, CY + 8)]), lit(c, 1.35), 0.9)
    a.fill(a.line(CX - 14, CY + 1, CX + 14, CY + 1, 0.6), accent, 0.35)
    return done(a)


def outfit_thug():
    a = A()
    _torso_arms(a, '#d02a38', c2='#a31f2a', bevel=7, grain=0.45, seed=28, spec=0.15)
    # leather bomber: collar, shoulder seams, hem
    a.fill(a.ellipse(CX, CY - 5, 6.2, 4.2), '#4a0f15', 0.95)
    a.fill(a.ellipse(CX, CY - 5.4, 3.4, 2.1), '#17080a', 0.9)
    a.fill(a.line(CX, CY - 2, CX, CY + 15, 1.2), '#2a0a0e', 0.9)
    for s in (-1, 1):
        a.fill(a.line(CX + s * 9, CY - 6, CX + s * 14, CY - 1, 0.8), '#5a1219', 0.9)
        a.fill(a.line(CX + s * 15, CY + 6, CX + s * 17, CY - 2, 0.0001), '#000000', 0.0)
    a.fill(a.rect(CX - 11, CY + 12.5, 22, 2.6), '#4a0f15', 0.9)
    # a stitched brotherhood patch on the back
    a.fill(a.ellipse(CX, CY + 8, 4.2), '#e8c53a', 0.9)
    a.fill(a.ellipse(CX, CY + 8, 2.6), '#a31f2a', 0.95)
    return done(a)


def outfit_nap():
    a = A()
    _torso_arms(a, '#2f5083', bevel=7, grain=0.25, seed=29)
    a.fill(a.ellipse(CX, CY - 5, 5.4, 3.8), '#2d4a72', 0.95)
    a.fill(a.line(CX, CY - 3, CX, CY + 14, 0.9), '#0f1d30', 0.9)
    for s in (-1, 1):
        a.fill(a.rrect(CX + s * 7.5 - 3.2, CY - 1, 6.4, 5, 1.2), '#14253d', 0.95)
        a.fill(a.rect(CX + s * 15 - 2.4, CY - 5, 4.8, 1.6), '#e8e8e8', 0.9)      # shoulder flash
        a.fill(a.rect(CX + s * 15 - 2.4, CY - 3, 4.8, 1.2), '#35d7ff', 0.9)
    a.fill(a.rect(CX - 11, CY + 8, 22, 2.8), '#0b1422', 0.95)                  # duty belt
    for x in (-8, -3, 4, 9):
        a.fill(a.rrect(CX + x - 1.4, CY + 7.4, 3, 4, 0.8), '#2a2e35', 0.95)
    return done(a)


def outfit_nasim():
    a = A()
    _torso_arms(a, '#2a2c36', bevel=7, grain=0.15, seed=30, spec=0.3)
    for s in (-1, 1):
        a.fill(a.line(CX + s * 3, CY - 4, CX + s * 8, CY + 14, 0.7), '#8a1fe0', 0.8)
        a.fill(a.line(CX + s * 15.5, CY + 2, CX + s * 17, CY - 6, 0.7), '#8a1fe0', 0.8)
    a.fill(a.ellipse(CX, CY - 5, 5, 3.5), '#2a2c34', 0.95)
    a.fill(a.ellipse(CX, CY - 5.4, 3, 2), '#0a0a0c', 0.9)
    a.fill(a.line(CX - 12, CY + 6, CX + 12, CY + 6, 0.6), '#8a1fe0', 0.55)
    return done(a)


def outfit_overalls():
    a = A()
    _torso_arms(a, '#6e7d94', bevel=7, grain=0.4, seed=31)
    a.shade(a.rrect(CX - 9.5, CY - 2, 19, 16, 3), '#3d5a8c', bevel=3, strength=0.8, grain=0.4, seed=32)
    for s in (-1, 1):
        a.fill(a.line(CX + s * 6.5, CY - 5, CX + s * 6.5, CY - 1, 2.0), '#3d5a8c', 0.95)
        a.fill(a.ellipse(CX + s * 6.5, CY - 1.4, 1.2), '#e0c26a', 0.95)
    a.fill(a.rrect(CX - 4, CY + 3, 8, 5, 1), '#2e4670', 0.95)
    return done(a)


def outfit_courier():
    a = A()
    _torso_arms(a, '#e0a02a', bevel=7, grain=0.3, seed=33, spec=0.15)
    a.fill(a.line(CX, CY - 3, CX, CY + 14, 0.9), '#7a540f', 0.9)
    for s in (-1, 1):
        a.fill(a.rect(CX + s * 15 - 3, CY - 2, 6, 1.6), '#e9e9e9', 0.95)       # reflective bands
        a.fill(a.rect(CX + s * 9 - 3, CY + 6, 6, 1.6), '#e9e9e9', 0.95)
    a.fill(a.ellipse(CX, CY - 5, 5.2, 3.6), '#8a5e12', 0.95)
    # a satchel strap
    a.fill(a.line(CX - 12, CY - 3, CX + 9, CY + 13, 2.4), '#2b2218', 0.95)
    return done(a)


RESIDENT = ['#3d6a8e', '#8e4a3d', '#4f7a4c', '#7a5a8e', '#b08a3a', '#5e6672']


def outfit_resident(i):
    a = A()
    c = RESIDENT[i % len(RESIDENT)]
    _torso_arms(a, c, bevel=6.8, grain=0.35, seed=40 + i)
    a.fill(a.ellipse(CX, CY - 5, 5.2, 3.6), lit(c, 0.7), 0.95)
    a.fill(a.ellipse(CX, CY - 5.4, 3.1, 2), '#1a1c20', 0.85)
    a.fill(a.line(CX, CY - 3, CX, CY + 14, 0.8), lit(c, 0.6), 0.8)
    if i % 2:
        a.fill(a.rect(CX - 12, CY + 11.4, 24, 2.2), lit(c, 0.65), 0.9)
    else:
        for s in (-1, 1):
            a.fill(a.rrect(CX + s * 8.2 - 3, CY + 5, 6, 3.2, 1), lit(c, 0.65), 0.9)
    return done(a)


# worn armor & containers --------------------------------------------------------------------------
def armor_vest(heavy=False, corp=False):
    a = A()
    base = '#5c7050' if not corp else '#262a33'
    chest = a.rrect(CX - 12.5 - (2 if heavy else 0), CY - 6, 25 + (4 if heavy else 0), 22, 5)
    a.shadow(chest, 1.2, 2.0, 2.0, 0.4)
    a.shade(chest, base, bevel=5.5, strength=1.0, grain=0.4, rough=1.0, seed=50)
    # shoulder straps
    for s in (-1, 1):
        strap = a.line(CX + s * 8, CY - 8, CX + s * 8, CY - 2, 4.4)
        a.shade(strap, lit(base, 0.9), bevel=2, strength=1.0, grain=0.3)
    # front plate and cummerbund MOLLE webbing
    plate = a.rrect(CX - 8, CY - 3, 16, 14, 3)
    a.shade(plate, lit(base, 1.25) if not corp else '#343944', bevel=3.4, strength=1.0, spec=0.35 if corp else 0.1)
    for k in range(3):
        a.fill(a.rect(CX - 11, CY + 12 + k * 1.1, 22, 0.5), '#000000', 0.45)
    if corp:
        a.fill(a.line(CX - 8, CY - 2, CX + 8, CY - 2, 0.8), '#35d7ff', 0.95)
        a.fill(a.rect(CX - 2, CY + 2, 4, 5), '#35d7ff', 0.75)
    else:
        for x in (-6, 0, 6):
            a.fill(a.rrect(CX + x - 2.2, CY + 12, 4.4, 4, 1), lit(base, 0.8), 0.95)          # pouches
    if heavy:
        for s in (-1, 1):
            pad = a.ellipse(CX + s * 15.5, CY - 1, 6.0, 7.0)
            a.shade(pad, lit(base, 1.15), bevel=4.4, strength=1.0, grain=0.3, spec=0.2)
            a.fill(a.line(CX + s * 12, CY - 3, CX + s * 18, CY + 1, 0.7), '#000000', 0.4)
    return done(a)


def armor_jacket():
    a = A()
    _torso_arms(a, '#6a5640', c2='#5a4835', bevel=7, grain=0.45, seed=51, spec=0.15)
    a.fill(a.line(CX, CY - 4, CX, CY + 15, 1.0), '#17120d', 0.9)
    for s in (-1, 1):
        a.fill(a.rect(CX + s * 15 - 3, CY - 6, 6, 4, ), '#52463a', 0.9)
        a.fill(a.line(CX + s * 4, CY - 6, CX + s * 12, CY - 7, 2.5), '#52463a', 0.95)
    a.fill(a.ellipse(CX, CY - 5, 5.4, 3.8), '#52463a', 0.95)
    return done(a)


def coat_long(c='#4a5563'):
    a = A()
    hem = a.ellipse(CX, CY + 13, 19, 19) | a.rrect(CX - 17, CY, 34, 28, 12)
    a.shadow(hem | shoulders(a), 1.6, 2.4, 2.6, 0.5)
    a.shade(hem, lit(c, 0.9), bevel=10, strength=1.0, grain=0.4, seed=52)
    _torso_arms(a, c, bevel=7, grain=0.4, seed=53)
    a.fill(a.line(CX, CY - 4, CX, CY + 31, 1.0), '#12151a', 0.9)
    a.fill(a.line(CX - 14, CY + 20, CX + 14, CY + 20, 0.5), '#12151a', 0.4)
    for s in (-1, 1):
        a.fill(a.poly([(CX, CY - 6), (CX + s * 9, CY - 3), (CX + s * 6, CY + 5)]), lit(c, 1.3), 0.95)
        for y in (2, 8):
            a.fill(a.ellipse(CX + s * 1.6, CY + y, 1.0), '#9aa3ad', 0.95)
    return done(a)


def bracers(heavy=False):
    a = A()
    arms = arm_masks(a)
    for side in ('l', 'r'):
        sh, el, hd = arms[side]
        s = -1 if side == 'l' else 1
        # forearm guard: a segmented shell over the forearm
        for k in range(3 if not heavy else 4):
            t0 = 0.12 + k * (0.24 if not heavy else 0.2)
            p0 = (el[0] + (hd[0] - el[0]) * t0, el[1] + (hd[1] - el[1]) * t0)
            p1 = (el[0] + (hd[0] - el[0]) * (t0 + 0.2), el[1] + (hd[1] - el[1]) * (t0 + 0.2))
            m = a.line(p0[0], p0[1], p1[0], p1[1], 7.4 if not heavy else 9)
            a.shade(m, '#5d6878' if not heavy else '#6d7352', bevel=2.6, strength=1.0, spec=0.35, grain=0.2)
        if heavy:
            a.shade(a.ellipse(el[0], el[1], 5.6), '#5a5f46', bevel=3.6, strength=1.0, spec=0.3)       # elbow cop
    return done(a)


def greaves(heavy=False):
    a = A()
    for (x, y0, y1) in ((CX - 7, CY - 4, CY - 12), (CX + 7, CY + 11, CY + 20)):
        m = a.line(x, y0, x, y1, 8.6 if not heavy else 10.4)
        a.shade(m, '#667282' if not heavy else '#767c58', bevel=3.6, strength=1.0, spec=0.4, grain=0.2)
        a.fill(a.rect(x - 3, (y0 + y1) / 2 - 0.4, 6, 0.8), '#000000', 0.4)
    return done(a)


def kneepads():
    a = A()
    for (x, y) in ((CX - 7, CY - 2), (CX + 7, CY + 12)):
        m = a.ellipse(x, y, 4.8, 4)
        a.shade(m, '#3e434d', bevel=3.2, strength=1.0, spec=0.3)
        a.fill(a.ellipse(x, y, 2.2, 1.6), '#4a5260', 0.9)
    return done(a)


def backpack():
    a = A()
    bag = a.rrect(CX - 11, CY + 4, 22, 22, 5)
    a.shadow(bag, 1.4, 2.4, 2.4, 0.5)
    a.shade(bag, '#6b8050', bevel=5.5, strength=1.0, grain=0.5, rough=1.0, seed=60)
    a.fill(a.rect(CX - 11, CY + 14, 22, 1.0), '#1e2518', 0.7)
    for s in (-1, 1):
        a.shade(a.rrect(CX + s * 12.5 - 2.6, CY + 11, 5.2, 11, 2), '#3a4730', bevel=2.2, strength=1.0, grain=0.4)    # side pockets
    a.shade(a.rrect(CX - 4, CY + 18, 8, 6, 2), '#3a4730', bevel=2, strength=1.0, grain=0.4)
    a.fill(a.ellipse(CX, CY + 21, 1), '#c0c0c0', 0.9)
    return done(a)


def holster():
    a = A()
    h = a.rrect(CX + 12, CY + 6, 7, 13, 2.4)
    a.shadow(h, 1, 1.6, 1.6, 0.4)
    a.shade(h, '#1c1b1b', bevel=2.4, strength=1.0, grain=0.35, spec=0.2)
    a.fill(a.rect(CX + 13, CY + 4, 5, 2.2), '#2a2928', 0.95)
    a.fill(a.line(CX - 12, CY + 7, CX + 14, CY + 7, 1.4), '#262524', 0.95)
    return done(a)


# headgear -----------------------------------------------------------------------------------------
def helmet_ball():
    a = A()
    m = a.ellipse(CX, CY - 1.2, 10.4, 11.4)
    a.shadow(m, 1.4, 2.2, 2.4, 0.5)
    a.shade(m, '#59694f', bevel=9, strength=1.05, grain=0.35, rough=1.1, seed=70, spec=0.25)
    a.fill(a.line(CX, CY - 10, CX, CY + 9, 0.8), '#1c231b', 0.55)
    a.shade(a.rrect(CX - 3, CY - 11, 6, 3.4, 1.4), '#5a6a58', bevel=1.4, strength=1.0)        # NVG mount
    a.fill(a.ellipse(CX - 3, CY + 4, 1.1), '#1c231b', 0.8)
    a.fill(a.ellipse(CX + 3, CY + 4, 1.1), '#1c231b', 0.8)
    return done(a)


def visor():
    a = A()
    m = a.ellipse(CX, CY - 1.2, 10.6, 11.6)
    a.shadow(m, 1.4, 2.2, 2.4, 0.5)
    a.shade(m, '#3d4660', bevel=9, strength=1.05, spec=0.5)
    vz = a.rrect(CX - 8.2, CY - 11.6, 16.4, 5.2, 2.4)
    a.shade(vz, '#2b9fd8', bevel=2.4, strength=0.7, spec=0.9)
    a.glow(CX, CY - 9, 11, '#35d7ff', 0.45)
    yy, xx = a.yy, a.xx
    g = np.exp(-(((xx * 1.0 + yy * 0.2) % 14) - 4) ** 2 / 2.5) * vz * 0.35
    a.rgb = np.clip(a.rgb + g[..., None], 0, 1)
    return done(a)


def helm_tac():
    a = A()
    m = a.ellipse(CX, CY - 1.2, 10.6, 11.6)
    a.shadow(m, 1.4, 2.2, 2.4, 0.5)
    a.shade(m, '#7a6d54', bevel=9, strength=1.05, grain=0.4, seed=71, spec=0.2)
    # rails, goggle strap, NVG tube
    for s in (-1, 1):
        a.shade(a.rect(CX + s * 8.8 - 1.2, CY - 6, 2.4, 11), '#2a2c30', bevel=1.2)
    a.shade(a.rrect(CX - 5, CY - 12, 10, 4.4, 1.6), '#1b1d21', bevel=1.6, spec=0.4)
    a.fill(a.ellipse(CX - 2.4, CY - 13.5, 1.6), '#4dff8a', 0.9)
    a.fill(a.ellipse(CX + 2.4, CY - 13.5, 1.6), '#4dff8a', 0.9)
    a.glow(CX, CY - 13, 8, '#4dff8a', 0.35)
    a.fill(a.line(CX - 10, CY + 3, CX + 10, CY + 3, 1.0), '#1b1d21', 0.9)
    return done(a)


def balaclava():
    a = A()
    m = a.ellipse(CX, CY - 1, 9.6, 10.6)
    a.shade(m, '#2d2f36', bevel=7, strength=1.0, grain=0.7, rough=0.9, seed=72)
    # eye slit at the front
    a.fill(a.rrect(CX - 6, CY - 9.2, 12, 2.4, 1.0), '#8a6d56', 0.9)
    return done(a)


# implants -----------------------------------------------------------------------------------------
def imp_optics():
    a = A()
    for s in (-1, 1):
        a.fill(a.ellipse(CX + s * 3.6, CY - 8.8, 2.1, 1.3), '#35d7ff', 1.0)
        a.glow(CX + s * 3.6, CY - 9.4, 8, '#35d7ff', 0.8)
    a.fill(a.line(CX - 8, CY - 8, CX + 8, CY - 8, 0.8), '#8fa0b0', 0.8)
    return a.image(outline=0.0)


def imp_thermal():
    a = A()
    a.shade(a.rrect(CX - 8, CY - 11, 16, 4.4, 2), '#2a1818', bevel=1.8, spec=0.5)
    a.fill(a.rrect(CX - 6.4, CY - 10.2, 12.8, 2.4, 1), '#ff5a1a', 0.95)
    a.glow(CX, CY - 9.2, 12, '#ff5a1a', 0.7)
    return a.image(outline=0.0)


def imp_cortex():
    a = A()
    m = a.rrect(CX - 3.6, CY + 2.4, 7.2, 5.6, 1.6)
    a.shade(m, '#aeb6c0', bevel=1.8, strength=1.0, spec=0.8)
    a.fill(a.ellipse(CX - 1.4, CY + 5.2, 0.8), '#ff3fa4', 1.0)
    a.fill(a.ellipse(CX + 1.4, CY + 5.2, 0.8), '#35d7ff', 1.0)
    a.glow(CX, CY + 5.2, 7, '#8a5cff', 0.45)
    return a.image(outline=0.5)


def imp_jets():
    a = A()
    for s in (-1, 1):
        m = a.rrect(CX + s * 7.4 - 3.4, CY + 4, 6.8, 14, 2.8)
        a.shadow(m, 1.2, 2, 2, 0.4)
        a.shade(m, '#5d6670', bevel=3, strength=1.0, spec=0.7)
        a.fill(a.ellipse(CX + s * 7.4, CY + 18, 2.6, 1.8), '#ffa21a', 1.0)
        a.glow(CX + s * 7.4, CY + 19, 9, '#ff7a1a', 0.75)
    return done(a, 0.6)


def imp_reflex():
    a = A()
    a.fill(a.line(CX, CY + 2, CX, CY + 15, 1.2), '#35d7ff', 0.95)
    a.glow(CX, CY + 8, 10, '#35d7ff', 0.55)
    for y in (5, 9, 13):
        a.fill(a.line(CX - 2.4, CY + y, CX + 2.4, CY + y, 0.8), '#35d7ff', 0.9)
    return a.image(outline=0.0)


def imp_synapse():
    a = A()
    for s in (-1, 1):
        a.fill(a.ellipse(CX + s * 9.3, CY - 3.4, 1.4, 2.2), '#ff3fa4', 1.0)
        a.glow(CX + s * 9.3, CY - 3.4, 8, '#ff3fa4', 0.7)
    a.fill(a.line(CX - 9.3, CY - 3.4, CX + 9.3, CY - 3.4, 0.5), '#ff3fa4', 0.45)
    return a.image(outline=0.0)


def imp_dermal():
    a = A()
    arms = arm_masks(a)
    for side in ('l', 'r'):
        sh, el, hd = arms[side]
        m = limb(a, el, hd, 5.8)
        a.shade(m, '#8fa0b4', bevel=2.6, strength=1.0, spec=0.9)
        a.fill(limb(a, el, hd, 1.0), '#35d7ff', 0.7)
    return done(a, 0.5)


def imp_mantis():
    a = A()
    arms = arm_masks(a)
    for side in ('l', 'r'):
        sh, el, hd = arms[side]
        s = -1 if side == 'l' else 1
        a.shade(a.line(hd[0], hd[1] + 1, hd[0] + s * 0.6, hd[1] - 30, 3.0), '#dfe6ee', bevel=1.4, strength=1.0, spec=0.95)
        a.fill(a.poly([(hd[0] - 1.6 + s * 0.4, hd[1] - 12), (hd[0] + 1.6 + s * 0.4, hd[1] - 12), (hd[0] + s * 0.6, hd[1] - 33)]), '#f4f8fc', 1.0)
        a.fill(a.line(hd[0] + s * 0.6, hd[1] - 6, hd[0] + s * 0.6, hd[1] - 30, 0.4), '#35d7ff', 0.8)
    return done(a, 0.5)


def imp_legs():
    return legs(chrome=True)


def imp_smartlink():
    a = A()
    a.shade(a.rrect(CX - 3, CY - 20.5, 6, 3, 1), '#1b1d21', bevel=1.4, spec=0.5)
    a.fill(a.rect(CX - 1.6, CY - 19.6, 3.2, 1.2), '#4dff8a', 1.0)
    a.glow(CX, CY - 19, 8, '#4dff8a', 0.5)
    return a.image(outline=0.4)


def imp_heart():
    a = A()
    a.fill(a.ellipse(CX + 5, CY - 3.4, 1.5), '#ff3b52', 1.0)
    a.glow(CX + 5, CY - 3.4, 9, '#ff3b52', 0.6)
    return a.image(outline=0.0)


def imp_grip():
    a = A()
    for (x, y) in hands_pos():
        m = a.ellipse(x, y, 3.8, 4.0)
        a.shade(m, '#9aa3ad', bevel=2.4, strength=1.0, spec=0.9)
        a.fill(a.ellipse(x, y, 1.2), '#35d7ff', 1.0)
    return done(a, 0.5)


# registry -----------------------------------------------------------------------------------------
# z: draw order.  tint: 'skin' / 'hair' layers are recoloured by the game.
def layers():
    L = []

    def add(key, img, z, tintk=''):
        L.append((key, img, z, tintk))
    add('d_shadow', shadow(), 0)
    add('d_legs', legs(), 10)
    add('d_torso_m', torso(False), 20)
    add('d_torso_f', torso(True), 20)
    add('d_arms_m', arms_skin(False), 25, 'skin')
    add('d_arms_f', arms_skin(True), 25, 'skin')
    add('backpack', backpack(), 22)
    add('holster', holster(), 23)
    add('kneepads', kneepads(), 31)
    add('greaves', greaves(), 32)
    add('greaves_heavy', greaves(True), 32)
    add('d_hands', hands(), 60, 'skin')
    add('d_head_m', head(False), 70, 'skin')
    add('d_head_f', head(True), 70, 'skin')
    for st in ('short', 'long', 'bob', 'ponytail', 'mohawk', 'buzz', 'bun'):
        add('d_hair_' + st, hair(st), 72, 'hair')
    # outfits
    add('thug', outfit_thug(), 40)
    add('nap', outfit_nap(), 40)
    add('nasim', outfit_nasim(), 40)
    add('labcoat', outfit_labcoat(), 40)
    add('chef', outfit_chef(), 40)
    add('priest', outfit_robe('#15151a', '#c79b3c', '#c79b3c'), 40)
    add('kannushi', outfit_robe('#e8e6dc', '#4a6a9a', '#7b3fa0'), 40)
    add('suit', outfit_suit(), 40)
    add('overalls', outfit_overalls(), 40)
    add('courier', outfit_courier(), 40)
    for i in range(6):
        add('jacket_%d' % i, outfit_resident(i), 40)
    add('coat', coat_long(), 42)
    add('jacket', armor_jacket(), 43)
    add('vest', armor_vest(), 45)
    add('vest_heavy', armor_vest(True), 45)
    add('vest_corp', armor_vest(False, True), 45)
    add('bracers', bracers(), 50)
    add('bracers_heavy', bracers(True), 50)
    # headgear
    add('helmet_ball', helmet_ball(), 80)
    add('visor', visor(), 80)
    add('helm_tac', helm_tac(), 80)
    add('balaclava', balaclava(), 74)
    # implants
    add('imp_legs', imp_legs(), 11)
    add('imp_dermal', imp_dermal(), 26)
    add('imp_grip', imp_grip(), 61)
    add('imp_mantis', imp_mantis(), 62)
    add('imp_jets', imp_jets(), 24)
    add('imp_reflex', imp_reflex(), 27)
    add('imp_heart', imp_heart(), 46)
    add('imp_smartlink', imp_smartlink(), 63)
    add('imp_cortex', imp_cortex(), 85)
    add('imp_optics', imp_optics(), 86)
    add('imp_thermal', imp_thermal(), 86)
    add('imp_synapse', imp_synapse(), 86)
    return L
