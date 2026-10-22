"""64x64 furniture and floor sprites for the venues (restaurants, groceries, implant shops, clinics, churches, temples)."""
import numpy as np
from scipy import ndimage as ndi
from PIL import Image
from art64 import Art, fbm, col, mix, lit, hx
import t64_terrain as TT

WOOD = '#9a6a3c'
WOOD_D = '#5b3a20'
WOOD_L = '#c08b52'
STEEL = '#aeb6c0'
STEEL_D = '#59626d'
ENAMEL = '#e6eaee'
BLACK = '#17191d'
GLOW_C = '#35d7ff'
GLOW_M = '#ff3fa4'


def A():
    return Art(64, 64, 4)


def done(a, outline=0.85):
    return a.image(outline=outline)


def box(a, x, y, w, h, c, r=2.0, bevel=3.0, shadow=True, **kw):
    m = a.rrect(x, y, w, h, r)
    if shadow:
        a.shadow(m, 1.6, 2.4, 2.2, 0.5)
    a.shade(m, c, bevel=bevel, **kw)
    return m


def disc(a, cx, cy, r, c, bevel=None, shadow=True, **kw):
    m = a.ellipse(cx, cy, r)
    if shadow:
        a.shadow(m, 1.6, 2.4, 2.2, 0.5)
    a.shade(m, c, bevel=bevel or r * 0.7, **kw)
    return m


# ------------------------------------------------------------------------------------------------ floors
def _floor_base(c, lo, hi, scale, seed):
    a = Art(64, 64, 2, wrap=True)
    n = fbm(a.H, a.W, scale * a.ss, seed, 3, True)
    a.rgb[:] = col(c)[None, None, :] * (lo + (hi - lo) * n)[..., None]
    a.a[:] = 1
    return a


def f_checker():
    a = _floor_base('#e9e9ee', 0.93, 1.03, 14, 201)
    s = a.ss
    dark = np.zeros((a.H, a.W), bool)
    for i in range(4):
        for j in range(4):
            if (i + j) % 2:
                dark[j * 16 * s:(j + 1) * 16 * s, i * 16 * s:(i + 1) * 16 * s] = True
    a.rgb[dark] = col('#1d1e24')[None, :] * (0.9 + 0.2 * fbm(a.H, a.W, 10 * s, 5, 2, True))[dark][:, None]
    TT._grid_lines(a, 16, '#101114', '#ffffff', 0.6)
    # gloss streak
    yy, xx = np.mgrid[0:a.H, 0:a.W]
    g = np.exp(-(((xx + yy) / s % 64 - 30) ** 2) / 40.0) * 0.07
    a.rgb = np.clip(a.rgb + g[..., None], 0, 1)
    return a.image()


def f_church():
    a = _floor_base('#a79d8c', 0.88, 1.08, 14, 202)
    TT._specks(a, 21, 0.02, '#6d6556', 0.2, 0.6)
    TT._specks(a, 22, 0.01, '#d6ccb8', 0.2, 0.6)
    s = a.ss
    # large flags with a dark border inlay
    TT._grid_lines(a, 32, '#4e473c', '#ffffff', 1.4)
    for (cx, cy) in ((32, 32),):
        pass
    a.rgb[16 * s:48 * s, 16 * s:48 * s] *= 0.97
    # diamond inlay in the centre of the tile
    m = a.poly([(32, 20), (44, 32), (32, 44), (20, 32)])
    a.rgb[m] = a.rgb[m] * 0.78 + col('#6a2f2a') * 0.22
    m2 = a.poly([(32, 25), (39, 32), (32, 39), (25, 32)])
    a.rgb[m2] = a.rgb[m2] * 0.8 + col('#c9a14a') * 0.2
    return a.image()


def f_hinoki():
    a = _floor_base('#d8b982', 0.9, 1.08, 20, 203)
    s = a.ss
    rng = np.random.default_rng(23)
    for i in range(0, 64, 16):
        a.rgb[:, i * s:(i + 1) * s] *= (0.95 + 0.1 * rng.random())
        a.rgb[:, i * s:i * s + s // 2 + 1] *= 0.7
    yy = np.arange(a.H)[:, None] / s
    xx = np.arange(a.W)[None, :] / s
    g = fbm(a.H, a.W, 3 * s, 24, 2, True)
    grain = np.sin((xx + g * 7) * 1.9) * 0.5 + 0.5
    a.rgb *= (0.94 + 0.1 * grain)[..., None]
    # stagger butt joints
    for i in range(4):
        y = (13 + i * 19) % 64
        x0 = i * 16
        a.rgb[y * s:y * s + s // 2 + 1, x0 * s:(x0 + 16) * s] *= 0.72
    return a.image()


def f_clean():
    a = _floor_base('#dfe8ec', 0.95, 1.04, 16, 204)
    TT._grid_lines(a, 32, '#9aa7ad', '#ffffff', 0.7)
    s = a.ss
    yy, xx = np.mgrid[0:a.H, 0:a.W]
    g = np.exp(-(((xx - yy) / s % 64 - 20) ** 2) / 60.0) * 0.08
    a.rgb = np.clip(a.rgb + g[..., None] * col('#bfe9ff')[None, None, :] * 4, 0, 1)
    TT._specks(a, 25, 0.003, '#b7c3c9', 0.3, 0.6)
    return a.image()


def f_marble():
    a = _floor_base('#e7e0d4', 0.92, 1.05, 18, 205)
    s = a.ss
    n = fbm(a.H, a.W, 20 * s, 206, 3, True)
    veins = np.exp(-((n - 0.5) / 0.02) ** 2)
    n2 = fbm(a.H, a.W, 9 * s, 207, 3, True)
    v2 = np.exp(-((n2 - 0.45) / 0.015) ** 2) * 0.6
    a.rgb = a.rgb * (1 - (veins + v2)[..., None] * 0.35) + col('#8b8478')[None, None, :] * (veins + v2)[..., None] * 0.35
    TT._grid_lines(a, 32, '#9a9285', '#ffffff', 0.8)
    return a.image()


def f_steel():
    a = _floor_base('#8d96a0', 0.9, 1.08, 10, 208)
    s = a.ss
    yy = np.arange(a.H)[:, None]
    brush = fbm(a.H, a.W, 1.2 * s, 209, 1, True)
    a.rgb *= (0.92 + 0.14 * brush)[..., None]
    TT._grid_lines(a, 32, '#40464e', '#ffffff', 1.2)
    for (x, y) in ((4, 4), (28, 4), (4, 28), (28, 28), (36, 4), (60, 4), (36, 28), (60, 28), (4, 36), (28, 36), (4, 60), (28, 60), (36, 36), (60, 36), (36, 60), (60, 60)):
        m = a.ellipse(x * 1.0, y * 1.0, 1.2)
        a.fill(m, '#40464e')
        a.fill(a.ellipse(x - 0.3, y - 0.3, 0.7), '#cfd6de')
    return a.image()


def f_wood():
    a = _floor_base('#a8743f', 0.88, 1.1, 22, 210)
    s = a.ss
    rng = np.random.default_rng(26)
    for j in range(4):
        a.rgb[j * 16 * s:(j + 1) * 16 * s, :] *= (0.9 + 0.2 * rng.random())
        a.rgb[j * 16 * s:j * 16 * s + s // 2 + 1, :] *= 0.62
        off = int(rng.integers(0, 64))
        a.rgb[j * 16 * s:(j + 1) * 16 * s, (off * s) % a.W:(off * s) % a.W + s // 2 + 1] *= 0.66
    g = fbm(a.H, a.W, 2.5 * s, 211, 2, True)
    xx = np.arange(a.W)[None, :] / s
    yy = np.arange(a.H)[:, None] / s
    grain = np.sin((yy + g * 6) * 2.4) * 0.5 + 0.5
    a.rgb *= (0.92 + 0.12 * grain)[..., None]
    for j in range(4):
        for k in (6, 58):
            a.rgb[int((j * 16 + 8) * s):int((j * 16 + 8) * s) + 2, k * s:k * s + 2] = col('#3a2412')
    return a.image()


def f_tatami():
    a = _floor_base('#bcc07c', 0.9, 1.08, 6, 212)
    s = a.ss
    yy = np.arange(a.H)[:, None] / s
    xx = np.arange(a.W)[None, :] / s
    weave = (np.sin(xx * 3.4) * np.sin(yy * 1.0) * 0.5 + 0.5)
    fine = np.sin(xx * 6.8 + (yy * 0.5)) * 0.5 + 0.5
    a.rgb *= (0.92 + 0.08 * weave + 0.05 * fine)[..., None]
    # woven rush runs along x; dark fabric border top and bottom, mat seam at the side
    for (y0, y1) in ((0, 5), (59, 64)):
        a.rgb[y0 * s:y1 * s, :] = col('#26241c')[None, None, :] * (0.9 + 0.2 * fbm(a.H, a.W, 2 * s, 213, 1, True)[y0 * s:y1 * s, :, None])
    a.rgb[5 * s:6 * s, :] *= 0.7
    a.rgb[58 * s:59 * s, :] *= 0.7
    return a.image()


def f_carpet():
    a = _floor_base('#7e1d2a', 0.85, 1.12, 3, 214)
    s = a.ss
    TT._specks(a, 27, 0.15, '#a63443', 0.2, 0.5)
    TT._specks(a, 28, 0.12, '#4d0f19', 0.2, 0.5)
    # a gold lattice
    for k in (0, 32):
        a.rgb[:, k * s:k * s + s // 2 + 1] = np.clip(a.rgb[:, k * s:k * s + s // 2 + 1] * 0.5 + col('#c79b3c') * 0.5, 0, 1)
        a.rgb[k * s:k * s + s // 2 + 1, :] = np.clip(a.rgb[k * s:k * s + s // 2 + 1, :] * 0.5 + col('#c79b3c') * 0.5, 0, 1)
    m = a.poly([(16, 8), (24, 16), (16, 24), (8, 16)])
    a.rgb[m] = a.rgb[m] * 0.6 + col('#c79b3c') * 0.4
    m = a.poly([(48, 40), (56, 48), (48, 56), (40, 48)])
    a.rgb[m] = a.rgb[m] * 0.6 + col('#c79b3c') * 0.4
    return a.image()


# ------------------------------------------------------------------------------------------------ restaurant
def counter(kind='shop'):
    a = A()
    top = a.rect(0, 10, 64, 40)
    base = a.rect(0, 50, 64, 6)
    a.shadow(a.rect(0, 12, 64, 44), 0, 3, 2.5, 0.5)
    a.shade(base, '#2a2d33', bevel=1.5, strength=0.7)
    if kind == 'noodle':
        a.shade(top, '#5a2a1a', bevel=2.2, strength=0.8, grain=0.35, rough=1.2, seed=3, spec=0.3)
        a.fill(a.rect(0, 10, 64, 2), '#9d5a38', 0.8)
        # bowls with steam and chopsticks
        for cx in (14, 40):
            disc(a, cx, 28, 8.5, '#e6e1d4', spec=0.4)
            a.fill(a.ellipse(cx, 28, 6.8), '#c1752b')
            a.fill(a.ellipse(cx, 28, 5.5), '#e5b45a')
            for k in range(5):
                a.fill(a.line(cx - 4 + k * 1.8, 25, cx - 3 + k * 1.8, 31, 0.7), '#f2d98b', 0.9)
            a.fill(a.ellipse(cx + 2, 26, 1.3), '#e0e8d0')
            a.fill(a.line(cx + 3, 18, cx + 9, 34, 0.9), '#2a1a12')
            a.fill(a.line(cx + 5, 18, cx + 11, 34, 0.9), '#2a1a12')
        a.fill(a.rect(52, 20, 6, 12), '#18181b')
        a.fill(a.ellipse(55, 24, 1.6), '#d92b3a')
    else:
        a.shade(top, '#4b5058', bevel=2.2, strength=0.85, grain=0.15, spec=0.5)
        a.fill(a.rect(0, 10, 64, 2.4), '#d3d9e0', 0.85)
        a.fill(a.rect(0, 47.6, 64, 2.4), '#2b2f35', 0.8)
        # till, tray, receipt strip
        box(a, 8, 20, 20, 14, '#272a30', r=1.5, bevel=2, spec=0.3)
        a.fill(a.rect(10, 22, 16, 5), '#35d7ff', 0.8)
        a.fill(a.rect(10, 29, 16, 3), '#6a7280')
        box(a, 38, 22, 16, 10, '#7a2a24', r=2, bevel=2)
        a.fill(a.rect(40, 24, 12, 6), '#c99b3c')
        a.fill(a.rect(46, 34, 4, 8), '#f4f4f0')
    return done(a)


def kitchen_range():
    a = A()
    box(a, 3, 5, 58, 54, STEEL, r=2.5, bevel=3, spec=0.5, grain=0.1)
    a.fill(a.rect(3, 5, 58, 2.5), '#e9edf1', 0.7)
    for (cx, cy, hot) in ((19, 20, True), (45, 20, False), (19, 44, False), (45, 44, True)):
        disc(a, cx, cy, 10.5, '#16181b', bevel=1.5, shadow=False)
        a.stroke(a.ellipse(cx, cy, 10.5), '#6a7078', 1.4)
        if hot:
            for k in range(14):
                t = k / 14 * 6.283
                a.fill(a.ellipse(cx + np.cos(t) * 6.2, cy + np.sin(t) * 6.2, 0.9), '#6fd0ff')
            a.glow(cx, cy, 14, '#2d88ff', 0.45)
        # grate bars
        a.fill(a.line(cx - 9, cy, cx + 9, cy, 1.2), '#2d3036', 0.9)
        a.fill(a.line(cx, cy - 9, cx, cy + 9, 1.2), '#2d3036', 0.9)
    # cast-iron pot on a hot ring
    disc(a, 19, 20, 8, '#1a1a1d', spec=0.3, bevel=3)
    a.fill(a.ellipse(19, 20, 5.8), '#8d2a1c')
    a.fill(a.ellipse(17.5, 18.5, 1.6), '#ffd49a', 0.7)
    # control knobs along the front
    for k in range(5):
        disc(a, 10 + k * 11, 56, 2, '#222', shadow=False, bevel=1.2)
        a.fill(a.line(10 + k * 11, 56, 10 + k * 11 + 1, 54.5, 0.7), '#e6e6e6')
    return done(a)


def fridge():
    a = A()
    box(a, 6, 4, 52, 56, '#dfe4e9', r=3, bevel=3.5, spec=0.5)
    a.fill(a.rect(8, 30, 48, 1.6), '#8a949e', 0.9)       # door seam
    a.shade(a.rrect(11, 12, 3.6, 14, 1.5), '#9aa3ad', bevel=1.2, spec=0.5)
    a.shade(a.rrect(11, 36, 3.6, 18, 1.5), '#9aa3ad', bevel=1.2, spec=0.5)
    # top vents
    for k in range(6):
        a.fill(a.rect(30 + k * 4, 8, 2, 8), '#b5bcc4', 0.9)
    a.shade(a.rrect(42, 20, 12, 5, 1.5), '#14161a', bevel=1)
    a.fill(a.rect(44, 21.5, 8, 2), '#35d7ff', 0.9)
    a.fill(a.ellipse(51, 44, 1.2), '#35d7ff')
    return done(a)


def sushi_case():
    a = A()
    box(a, 0, 8, 64, 48, '#2b2e34', r=2, bevel=2.5, spec=0.3)
    glass = a.rect(3, 12, 58, 34)
    a.fill(glass, '#9ed6e6', 1.0)
    # ice bed
    a.shade(a.rect(5, 14, 54, 30), '#d9f1f7', bevel=2, strength=0.5, grain=0.4, rough=1.4)
    rng = np.random.default_rng(33)
    kinds = [('#f4f1e8', '#e8643f'), ('#f4f1e8', '#f09a8b'), ('#f4f1e8', '#e9c24d'), ('#262b22', '#f6f3ea')]
    for j in range(2):
        for i in range(5):
            x, y = 9 + i * 10.4, 18 + j * 13
            rice, top = kinds[(i + j) % 4]
            a.shade(a.rrect(x, y + 1, 8, 6, 2), rice, bevel=2, strength=0.7)
            a.shade(a.rrect(x - 0.5, y - 1, 9, 4.6, 2), top, bevel=1.6, strength=0.8, spec=0.35)
    # glass reflection
    yy, xx = a.yy, a.xx
    g = np.exp(-(((xx + yy * 0.7) % 40) - 8) ** 2 / 6.0) * glass
    a.rgb = np.clip(a.rgb + g[..., None] * 0.22, 0, 1)
    a.stroke(glass, '#e9f7fb', 1.2, 0.6)
    a.fill(a.rect(0, 46, 64, 8), '#1c1e23')
    a.fill(a.rect(6, 49, 14, 2), '#35d7ff', 0.9)
    return done(a)


def pizza_oven():
    a = A()
    m = a.rrect(4, 4, 56, 56, 6)
    a.shadow(m, 2, 3, 3, 0.5)
    a.shade(m, '#8c4a38', bevel=7, strength=0.9, grain=0.45, rough=1.2, seed=8)
    # brick courses
    for j in range(6):
        for i in range(6):
            x = 8 + i * 9 + (j % 2) * 4.5
            y = 8 + j * 8.5
            a.fill(a.rect(x, y, 8.3, 0.8), '#4f2a20', 0.7)
        a.fill(a.rect(6, 8 + j * 8.5 + 7.6, 52, 0.8), '#4f2a20', 0.7)
    # dome
    dome = a.ellipse(32, 30, 17)
    a.shade(dome, '#b86a4a', bevel=14, strength=1.0, grain=0.4, rough=1.1, seed=9)
    # fire mouth
    mouth = a.rrect(24, 44, 16, 11, 4)
    a.fill(mouth, '#120807')
    a.shade(a.rrect(26, 47, 12, 7, 3), '#ff6a1a', bevel=3, strength=0.2, emit=0.4)
    a.glow(32, 50, 18, '#ff7a1a', 0.7)
    a.fill(a.ellipse(32, 51, 3), '#ffd27a', 0.9)
    a.shade(a.rect(46, 12, 7, 18), '#3a3d42', bevel=2, spec=0.3)         # chimney
    return done(a)


def dining_table():
    a = A()
    m = a.rrect(5, 5, 54, 54, 6)
    a.shadow(m, 2, 3, 3, 0.55)
    a.shade(m, WOOD, bevel=3, strength=0.8, grain=0.45, rough=1.6, seed=14, spec=0.15)
    for k in range(1, 4):
        a.fill(a.rect(6, 5 + k * 13.5, 52, 0.8), '#5b3a20', 0.6)
    a.shade(a.rrect(8, 8, 48, 48, 4), '#a97646', bevel=1.5, strength=0.3, grain=0.3, rough=1.8, seed=15, flat=True)
    # runner, plates, chopsticks
    a.fill(a.rect(26, 6, 12, 52), '#7a1f2c', 0.9)
    a.fill(a.rect(26, 6, 1, 52), '#c79b3c', 0.8)
    a.fill(a.rect(37, 6, 1, 52), '#c79b3c', 0.8)
    for (x, y) in ((14, 18), (50, 18), (14, 46), (50, 46)):
        disc(a, x, y, 6, '#eceae2', spec=0.5, bevel=2)
        a.stroke(a.ellipse(x, y, 3.6), '#c9c4b5', 0.8, 0.8)
    disc(a, 32, 32, 4, '#2d6a8e', spec=0.5)
    return done(a)


def table_plastic():
    a = A()
    m = a.rrect(8, 8, 48, 48, 5)
    a.shadow(m, 2, 3, 3, 0.5)
    a.shade(m, '#e8e2d2', bevel=2.5, strength=0.55, spec=0.45, grain=0.1)
    a.stroke(m, '#a49d89', 1.2, 0.8)
    # napkin holder, soy bottle, condiments
    disc(a, 22, 24, 3.4, '#9a1f23', spec=0.5)
    a.fill(a.ellipse(22, 24, 1.3), '#2a0a0c')
    box(a, 34, 20, 6, 8, '#6c7a8a', r=1.2, bevel=1.5, spec=0.3)
    disc(a, 46, 26, 2.2, '#b52b2b', spec=0.5)
    a.fill(a.rect(30, 38, 12, 7), '#f6f6f0', 0.9)
    return done(a)


def tea_table():
    a = A()
    m = a.rrect(8, 14, 48, 36, 3)
    a.shadow(m, 2, 3, 3, 0.5)
    a.shade(m, '#3a2616', bevel=3, strength=0.9, grain=0.45, rough=1.5, seed=18, spec=0.4)
    a.stroke(m, '#a67c4d', 1.3, 0.5)
    disc(a, 22, 32, 6.4, '#a8c4b0', spec=0.55, bevel=3)          # teapot body
    a.shade(a.rrect(26, 30, 9, 3, 1.2), '#8eaa98', bevel=1)       # spout
    a.fill(a.ellipse(22, 32, 2.2), '#6c8a76')
    for (x, y) in ((42, 25), (46, 36)):
        disc(a, x, y, 3.4, '#efe9db', spec=0.5)
        a.fill(a.ellipse(x, y, 2), '#a8c24c')
    return done(a)


def stool_plastic():
    a = A()
    disc(a, 32, 32, 17, '#b4262b', bevel=5, strength=0.9, spec=0.55)
    a.stroke(a.ellipse(32, 32, 17), '#6e1215', 1.4, 0.6)
    a.fill(a.ellipse(32, 32, 7), '#8f1c20', 0.55)
    return done(a)


def bar_stool():
    a = A()
    disc(a, 32, 32, 17, '#cfd6de', bevel=3, strength=0.9, spec=0.7)
    disc(a, 32, 32, 14, '#8a1f2d', bevel=5.5, strength=0.9, spec=0.5, shadow=False)
    a.fill(a.ellipse(32, 32, 3), '#5e121d', 0.9)
    return done(a)


def menu_board():
    a = A()
    # A-frame board seen from above: two slanted boards on a hinge with glowing menu on the face
    box(a, 10, 6, 44, 52, '#26282d', r=2.5, bevel=3, spec=0.2)
    a.shade(a.rect(13, 9, 38, 46), '#14161a', bevel=1.5, strength=0.3)
    cols = ['#ff3fa4', '#35d7ff', '#ffd23f', '#35d7ff', '#ff3fa4', '#ffd23f']
    for k in range(6):
        w = 20 + (k * 7) % 14
        a.fill(a.rect(16, 13 + k * 6.6, w, 2.4), cols[k], 0.95)
        a.fill(a.rect(44, 13 + k * 6.6, 4, 2.4), '#e9e9e9', 0.8)
    a.glow(32, 32, 28, '#35d7ff', 0.18)
    return done(a)


def samovar():
    a = A()
    disc(a, 32, 32, 19, '#a87a2a', bevel=9, strength=1.0, spec=0.8, grad='v', base2='#6d4a14')
    a.fill(a.ellipse(32, 32, 12), '#8a621c', 0.55)
    disc(a, 32, 32, 11, '#c89a3c', bevel=8, strength=1.0, spec=0.9, shadow=False)
    disc(a, 32, 32, 3.5, '#6d4a14', shadow=False, bevel=2, spec=0.7)
    # handles and the tap
    for ang in (0.5, 3.64):
        a.shade(a.line(32 + np.cos(ang) * 17, 32 + np.sin(ang) * 17, 32 + np.cos(ang) * 24, 32 + np.sin(ang) * 24, 3), '#5c3c10', bevel=1.2)
    a.shade(a.line(50, 40, 59, 44, 2.6), '#d6a640', bevel=1.2, spec=0.7)
    a.fill(a.ellipse(59, 44, 1.6), '#4a2c0c')
    return done(a)


def liquor_shelf():
    a = A()
    box(a, 0, 6, 64, 28, '#3a2616', r=1.5, bevel=2, grain=0.3, spec=0.2)
    rng = np.random.default_rng(37)
    cols = ['#2b7a46', '#8a3a1b', '#c8d0d4', '#a62b2b', '#1c4f8f', '#d2a52c', '#3a2a58', '#e9e0c4']
    x = 3
    for i in range(10):
        c = cols[i % len(cols)]
        r = rng.uniform(2.8, 4.0)
        disc(a, x + r, 20, r, c, bevel=r * 0.8, spec=0.6, shadow=False)
        a.fill(a.ellipse(x + r, 20, r * 0.35), '#101010')
        a.fill(a.ellipse(x + r - r * 0.35, 20 - r * 0.35, r * 0.2), '#ffffff', 0.6)
        x += r * 2 + 0.8
    a.fill(a.rect(0, 33, 64, 2), '#201409')
    for i in range(3):
        a.fill(a.rect(8 + i * 22, 38, 14, 10), '#d3c9a4', 0.0)
    return done(a)


def hot_plate():
    a = A()
    box(a, 8, 10, 48, 44, '#3a3d44', r=3, bevel=3, spec=0.4)
    disc(a, 32, 32, 14, '#101114', bevel=2, shadow=False)
    for k in range(5):
        a.stroke(a.ellipse(32, 32, 13 - k * 2.4), '#ff5a1a', 0.9, 0.9)
    a.glow(32, 32, 20, '#ff5a1a', 0.5)
    # frying pan
    disc(a, 30, 32, 11, '#2a2c30', spec=0.45, bevel=4)
    a.fill(a.ellipse(30, 32, 8.4), '#17181b')
    a.fill(a.ellipse(27, 30, 3), '#e8d9b0')
    a.fill(a.ellipse(34, 34, 2.4), '#e8a04a')
    a.shade(a.rrect(40, 30.5, 17, 3.6, 1.5), '#16171a', bevel=1.2, spec=0.3)
    return done(a)


# ------------------------------------------------------------------------------------------------ grocery
def shelf_clean():
    a = A()
    box(a, 0, 6, 64, 52, '#cfd4da', r=1.5, bevel=2, spec=0.3)
    a.fill(a.rect(0, 30, 64, 2), '#8c949d', 0.9)
    rng = np.random.default_rng(41)
    pal = ['#d9373b', '#2b78c9', '#e8c53a', '#3d9b5a', '#f0f0ea', '#8a4fc0', '#ee8a2a']
    for row, y0 in enumerate((9, 35)):
        x = 3
        while x < 58:
            w = rng.uniform(6, 10)
            h = rng.uniform(15, 19)
            c = pal[rng.integers(len(pal))]
            box(a, x, y0, w, h, c, r=1, bevel=1.5, shadow=False, spec=0.25)
            a.fill(a.rect(x + 1, y0 + h * 0.3, w - 2, h * 0.2), '#ffffff', 0.55)
            x += w + 0.8
    return done(a)


def produce_bin():
    a = A()
    box(a, 4, 6, 56, 52, '#8a6334', r=3, bevel=4, grain=0.4, rough=1.4, seed=43)
    a.shade(a.rrect(9, 11, 46, 42, 2), '#2a1d10', bevel=2, strength=0.3, flat=True)
    rng = np.random.default_rng(44)
    for i in range(22):
        x, y = rng.uniform(13, 51), rng.uniform(15, 49)
        k = i % 4
        c = ['#d62b2b', '#f0a02a', '#6ab04c', '#8c2f8f'][k]
        disc(a, x, y, rng.uniform(3.2, 4.4), c, bevel=3, spec=0.7, shadow=False)
        a.fill(a.ellipse(x - 1.2, y - 1.2, 0.8), '#ffffff', 0.65)
        if k == 0:
            a.fill(a.ellipse(x + 0.3, y - 2.4, 0.7), '#3b2a14')
    return done(a)


def freezer_case():
    a = A()
    box(a, 0, 5, 64, 54, '#e4e9ee', r=2.5, bevel=3, spec=0.4)
    inner = a.rect(4, 9, 56, 46)
    a.shade(inner, '#9fd0e4', bevel=2, strength=0.4, grain=0.3, rough=1.3, seed=46, flat=True)
    rng = np.random.default_rng(47)
    pal = ['#e8643f', '#35d7ff', '#f0f0f0', '#e8c53a', '#6ab04c']
    for j in range(3):
        for i in range(5):
            c = pal[(i + j) % 5]
            box(a, 7 + i * 10.6, 12 + j * 14, 9, 11, c, r=1.2, bevel=1.5, shadow=False, spec=0.3)
    # frosted glass lid with frost patches
    n = fbm(a.H, a.W, 6 * 4, 48, 3)
    k = np.clip((n - 0.55) * 3, 0, 1) * inner * 0.7
    a.rgb = a.rgb * (1 - k[..., None]) + col('#ffffff')[None, None, :] * k[..., None]
    a.stroke(inner, '#ffffff', 1.4, 0.8)
    a.glow(32, 32, 34, '#9ae6ff', 0.15)
    return done(a)


def checkout():
    a = A()
    a.shadow(a.rect(0, 10, 64, 44), 0, 3, 2.5, 0.5)
    a.shade(a.rect(0, 8, 64, 48), '#555c66', bevel=2, strength=0.8, spec=0.3)
    # conveyor belt
    a.shade(a.rect(2, 18, 40, 22), '#17181b', bevel=1.5, strength=0.5)
    for k in range(10):
        a.fill(a.rect(5 + k * 4, 19, 1.0, 20), '#2c2e33', 0.9)
    # scanner glass + red line
    a.shade(a.rect(44, 18, 14, 22), '#9fd0e4', bevel=1.4, spec=0.7)
    a.fill(a.rect(44, 28.6, 14, 1.2), '#ff3b3b', 0.95)
    a.glow(51, 29, 9, '#ff3b3b', 0.35)
    # register pod
    box(a, 4, 44, 22, 10, '#202329', r=2, bevel=2)
    a.fill(a.rect(7, 46, 16, 5), '#35d7ff', 0.75)
    box(a, 30, 44, 12, 9, '#8a4f2a', r=1.5, bevel=1.5)
    return done(a)


def vending():
    a = A()
    box(a, 8, 6, 48, 52, '#1c4fa8', r=3, bevel=4, spec=0.5)
    a.shade(a.rect(12, 10, 40, 6), '#e9eef6', bevel=1.2)
    a.fill(a.rect(14, 12, 36, 2), '#ff3fa4', 0.9)
    a.shade(a.rect(12, 18, 30, 30), '#0f1e3c', bevel=1.4, strength=0.4)
    rng = np.random.default_rng(50)
    pal = ['#d62b3a', '#f0c42c', '#35d7ff', '#6ab04c', '#ff8a2a']
    for j in range(3):
        for i in range(4):
            a.fill(a.rect(14 + i * 7, 20 + j * 9, 5.6, 7), pal[rng.integers(5)], 0.95)
    yy, xx = a.yy, a.xx
    g = np.exp(-(((xx + yy * 0.7) % 36) - 6) ** 2 / 6.0) * a.rect(12, 18, 30, 30)
    a.rgb = np.clip(a.rgb + g[..., None] * 0.2, 0, 1)
    a.shade(a.rect(44, 18, 8, 12), '#242830', bevel=1.2)
    a.fill(a.rect(45.5, 20, 5, 3), '#35d7ff', 0.9)
    a.shade(a.rect(44, 34, 8, 4), '#0b0d10', bevel=1)
    a.shade(a.rect(14, 50, 36, 5), '#0c1018', bevel=1.2)
    a.glow(26, 32, 26, '#35d7ff', 0.18)
    return done(a)


def water_cooler():
    a = A()
    box(a, 16, 26, 32, 32, '#dfe3e8', r=3, bevel=3.5, spec=0.5)
    a.fill(a.rect(20, 46, 8, 3), '#2b7ae0')
    a.fill(a.rect(34, 46, 8, 3), '#e0443f')
    jug = a.ellipse(32, 22, 14)
    a.shadow(jug, 1.5, 2, 2, 0.4)
    a.shade(jug, '#8fd0ee', bevel=10, strength=0.9, spec=0.9, grad='v', base2='#4a9cc8')
    a.fill(a.ellipse(32, 22, 5), '#bfe9fb', 0.6)
    a.fill(a.ellipse(28, 17, 2), '#ffffff', 0.8)
    return done(a)


# ------------------------------------------------------------------------------------------------ implant shop & clinic
def implant_chair():
    a = A()
    base = a.rrect(14, 6, 36, 54, 5)
    a.shadow(base, 2, 3, 3, 0.55)
    a.shade(base, '#2a2e36', bevel=3, strength=0.8, spec=0.3)
    # reclined padded seat, back, leg rest
    a.shade(a.rrect(18, 10, 28, 15, 6), '#3a4252', bevel=5, strength=1.0, spec=0.5)         # headrest
    a.shade(a.rrect(17, 24, 30, 20, 4), '#46506a', bevel=5, strength=1.0, spec=0.45)       # back/seat
    a.shade(a.rrect(19, 44, 26, 13, 4), '#3a4252', bevel=4, strength=0.9, spec=0.4)        # leg rest
    a.fill(a.rect(31, 12, 2, 44), '#242a35', 0.55)
    # arm clamps with LEDs and a surgical arm
    for x in (6, 50):
        box(a, x, 20, 8, 22, '#7a828d', r=2, bevel=2.5, spec=0.6)
        a.fill(a.rect(x + 2, 24, 4, 2), GLOW_C, 0.95)
        a.fill(a.rect(x + 2, 30, 4, 2), GLOW_M, 0.95)
    a.shade(a.line(50, 12, 60, 4, 2.6), '#9aa3ad', bevel=1.2, spec=0.7)
    a.shade(a.line(60, 4, 56, 14, 2.0), '#9aa3ad', bevel=1.0, spec=0.7)
    a.glow(10, 31, 12, GLOW_C, 0.25)
    return done(a)


def implant_printer():
    a = A()
    box(a, 4, 4, 56, 56, '#2b2f38', r=4, bevel=4, spec=0.4)
    dome = a.ellipse(32, 32, 20)
    a.shade(dome, '#12161d', bevel=2, strength=0.3, flat=True)
    # printed organic lattice inside the dome
    for k in range(7):
        ang = k / 7 * 6.283
        a.fill(a.line(32, 32, 32 + np.cos(ang) * 14, 32 + np.sin(ang) * 14, 1.2), '#ff6fb8', 0.8)
    a.fill(a.ellipse(32, 32, 6), '#ff3fa4', 0.9)
    a.fill(a.ellipse(32, 32, 3), '#ffd1ea', 0.95)
    a.glow(32, 32, 26, GLOW_M, 0.55)
    # gantry rail + head
    a.shade(a.rect(10, 29, 44, 5), '#9aa3ad', bevel=1.5, spec=0.7)
    box(a, 28, 25, 9, 13, '#c3cad3', r=2, bevel=2, spec=0.8)
    a.fill(a.rect(31, 36, 3, 6), '#ff3fa4')
    # dome glass sheen
    yy, xx = a.yy, a.xx
    g = np.exp(-(((xx + yy) % 30) - 6) ** 2 / 8.0) * dome * 0.28
    a.rgb = np.clip(a.rgb + g[..., None], 0, 1)
    a.stroke(dome, '#cfe9f6', 1.4, 0.6)
    for (x, y) in ((8, 8), (56, 8), (8, 56), (56, 56)):
        a.fill(a.ellipse(x, y, 1.3), '#7a828d')
    return done(a)


def limb_bin():
    a = A()
    box(a, 4, 8, 56, 50, '#3a3f47', r=3, bevel=4, spec=0.3)
    a.shade(a.rrect(8, 12, 48, 42, 2), '#111317', bevel=2, strength=0.3, flat=True)
    rng = np.random.default_rng(55)
    for i in range(6):
        x, y = rng.uniform(14, 48), rng.uniform(18, 48)
        ang = rng.uniform(0, 3.14)
        L = rng.uniform(14, 22)
        dx, dy = np.cos(ang) * L / 2, np.sin(ang) * L / 2
        c = ['#cfd6de', '#e0b79a', '#8a929c', '#35d7ff'][i % 4]
        m = a.line(x - dx, y - dy, x + dx, y + dy, 4.2)
        a.shade(m, c, bevel=2, strength=0.95, spec=0.8)
        a.shade(a.ellipse(x + dx, y + dy, 3.2), '#8a929c', bevel=2, spec=0.7)
        a.fill(a.ellipse(x - dx, y - dy, 1.4), '#202328')
    a.fill(a.rect(6, 54, 52, 2), '#ff3fa4', 0.6)
    return done(a)


def autodoc():
    a = A()
    pod = a.rrect(8, 3, 48, 58, 14)
    a.shadow(pod, 2, 3, 3, 0.55)
    a.shade(pod, '#e8ecf0', bevel=6, strength=0.9, spec=0.6)
    glass = a.rrect(13, 10, 38, 44, 10)
    a.shade(glass, '#26425a', bevel=3, strength=0.7, spec=0.7, grad='v', base2='#0f2030')
    # patient silhouette + scan lines
    a.fill(a.ellipse(32, 20, 4.6), '#1b6f94', 0.85)
    a.fill(a.rrect(26, 26, 12, 22, 4), '#1b6f94', 0.85)
    for k in range(5):
        a.fill(a.rect(15, 14 + k * 8, 34, 0.9), '#35d7ff', 0.6)
    a.glow(32, 32, 22, '#35d7ff', 0.3)
    yy, xx = a.yy, a.xx
    g = np.exp(-(((xx + yy * 0.8) % 34) - 7) ** 2 / 7.0) * glass * 0.4
    a.rgb = np.clip(a.rgb + g[..., None], 0, 1)
    a.shade(a.rrect(22, 54, 20, 5, 2), '#14171c', bevel=1.2)
    a.fill(a.rect(25, 55.4, 14, 2), '#35d7ff', 0.9)
    return done(a)


def hospital_bed(tone='#6aa0c8', pillow='#f4f6f8'):
    a = A()
    frame = a.rrect(12, 3, 40, 58, 3)
    a.shadow(frame, 2, 3, 3, 0.5)
    a.shade(frame, '#a8b0ba', bevel=2.5, strength=0.8, spec=0.5)
    a.shade(a.rrect(15, 6, 34, 52, 3), '#f2f4f6', bevel=3, strength=0.5, spec=0.2)
    a.shade(a.rrect(18, 7, 28, 12, 5), pillow, bevel=4, strength=0.9, spec=0.2)
    blanket = a.rrect(16, 22, 32, 34, 3)
    a.shade(blanket, tone, bevel=4, strength=0.8, grain=0.3, rough=2, seed=58)
    a.fill(a.rect(16, 22, 32, 4), '#f4f6f8', 0.85)
    for k in range(3):
        a.fill(a.line(22 + k * 8, 30, 22 + k * 8 + 1, 54, 0.7), '#000000', 0.12)
    # side rails and a call button cord
    for x in (10, 52):
        a.shade(a.rrect(x, 18, 3, 32, 1.4), '#c9d0d8', bevel=1.2, spec=0.7)
    a.fill(a.ellipse(54, 12, 1.4), '#ff3b52')
    return done(a)


def scanner():
    a = A()
    # gantry ring over a table
    a.shade(a.rrect(18, 4, 28, 56, 3), '#bfc6ce', bevel=2.5, strength=0.8, spec=0.4)
    a.fill(a.rect(30, 6, 4, 52), '#8f98a2', 0.5)
    ring = a.rrect(4, 18, 56, 26, 8)
    a.shadow(ring, 2, 3, 3, 0.55)
    a.shade(ring, '#eef1f4', bevel=6, strength=0.95, spec=0.55)
    hole = a.rrect(14, 22, 36, 18, 6)
    a.shade(hole, '#0e1217', bevel=2, strength=0.3, flat=True)
    a.stroke(hole, '#35d7ff', 1.0, 0.7)
    a.glow(32, 31, 16, '#35d7ff', 0.4)
    a.fill(a.rect(8, 20.5, 8, 2), '#35d7ff', 0.9)
    a.fill(a.ellipse(54, 24, 1.3), '#ff3b52')
    return done(a)


def med_cabinet():
    a = A()
    box(a, 6, 6, 52, 52, '#e8ecf0', r=3, bevel=3.5, spec=0.5)
    a.fill(a.rect(30, 8, 1.6, 48), '#8a949e', 0.9)
    a.fill(a.rect(25.5, 24, 13, 4), '#d93a3a')
    a.fill(a.rect(30, 19.5, 4, 13), '#d93a3a')
    for k in range(3):
        a.fill(a.rect(10, 38 + k * 6, 16, 3), '#cbd3da', 0.9)
    a.shade(a.rrect(27, 40, 2.8, 8, 1), '#7a828d', bevel=1, spec=0.6)
    a.shade(a.rrect(33, 40, 2.8, 8, 1), '#7a828d', bevel=1, spec=0.6)
    return done(a)


def iv_stand():
    a = A()
    for k in range(5):
        ang = k / 5 * 6.283 - 1.5
        a.shade(a.line(32, 32, 32 + np.cos(ang) * 20, 32 + np.sin(ang) * 20, 3.2), '#9aa3ad', bevel=1.2, spec=0.7)
        disc(a, 32 + np.cos(ang) * 20, 32 + np.sin(ang) * 20, 2.6, '#1c1f24', bevel=1.2, shadow=False)
    disc(a, 32, 32, 4.6, '#c3cad3', bevel=3, spec=0.9)
    # hanging bag drawn over the pole top
    bag = a.rrect(36, 20, 14, 20, 5)
    a.shadow(bag, 2, 3, 2, 0.4)
    a.shade(bag, '#e6f4fa', bevel=4, strength=0.7, spec=0.8)
    a.fill(a.rrect(38, 27, 10, 11, 3), '#7fd4f0', 0.8)
    a.fill(a.line(32, 32, 42, 40, 0.7), '#bfe9fb', 0.9)
    return done(a)


def reception():
    a = A()
    top = a.rect(0, 8, 64, 44)
    a.shadow(top, 0, 3, 3, 0.5)
    a.shade(top, '#d6dbe0', bevel=2.4, strength=0.8, spec=0.5)
    a.fill(a.rect(0, 8, 64, 3), '#ffffff', 0.7)
    a.shade(a.rect(0, 48, 64, 8), '#6a727d', bevel=1.5)
    # terminal, tray, clipboard
    box(a, 8, 18, 18, 14, '#1c1f26', r=2, bevel=2.2, spec=0.4)
    a.fill(a.rect(10, 20, 14, 8), '#35d7ff', 0.85)
    a.fill(a.rect(10, 21, 9, 1.4), '#ffffff', 0.7)
    box(a, 34, 22, 12, 9, '#d93a3a', r=2, bevel=1.5, spec=0.4)
    a.fill(a.rect(36, 24, 8, 5), '#f6f6f0')
    a.shade(a.rect(50, 20, 9, 14), '#c9a14a', bevel=1.2)
    a.fill(a.rect(51.5, 24, 6, 8), '#f6f6f0')
    return done(a)


def exam_couch():
    a = A()
    base = a.rrect(14, 4, 36, 56, 4)
    a.shadow(base, 2, 3, 3, 0.5)
    a.shade(base, '#6a727d', bevel=2.5, strength=0.8, spec=0.4)
    a.shade(a.rrect(17, 7, 30, 50, 4), '#3f6f95', bevel=5, strength=1.0, spec=0.5)
    a.shade(a.rrect(18, 8, 28, 11, 5), '#4a80ab', bevel=4, strength=0.9, spec=0.45)
    a.fill(a.rect(17, 40, 30, 1.2), '#2a4d6a', 0.8)
    # paper roll across the head
    a.shade(a.rrect(16, 20, 32, 5, 2.5), '#f4f5f1', bevel=2, strength=0.8)
    a.fill(a.ellipse(54, 14, 2.2), '#d93a3a')
    return done(a)


# ------------------------------------------------------------------------------------------------ church
def church_bench():
    a = A()
    top = a.rrect(0, 14, 64, 36, 3)
    a.shadow(top, 0, 3, 3, 0.55)
    a.shade(top, '#5a3820', bevel=2.2, strength=0.9, grain=0.5, rough=1.6, seed=62, spec=0.2)
    a.shade(a.rect(0, 14, 64, 8), '#6e4527', bevel=2, strength=0.9, grain=0.4, seed=63)      # back rail
    a.fill(a.rect(0, 22, 64, 1.0), '#2c1a0e', 0.9)
    a.fill(a.rect(2, 46, 60, 1.4), '#2c1a0e', 0.7)
    for x in (0, 58):
        a.shade(a.rrect(x, 12, 6, 40, 2), '#4a2d19', bevel=2, strength=0.9, grain=0.3)
    # a hymn book on the seat
    a.shade(a.rect(26, 32, 9, 6), '#7a1f2c', bevel=1.2)
    a.fill(a.rect(27, 33, 6, 1), '#c79b3c', 0.8)
    return done(a)


def iconostasis():
    a = A()
    box(a, 0, 6, 64, 52, '#4a2d19', r=1.5, bevel=2, grain=0.3)
    cols = ['#b6862c', '#c9a14a']
    for i in range(4):
        x = 3 + i * 15.5
        panel = a.rrect(x, 10, 13, 44, 6)
        a.shade(panel, '#c79b3c', bevel=2.8, strength=0.9, spec=0.6)
        a.shade(a.rrect(x + 2, 14, 9, 36, 4), '#7a2a2a', bevel=1.6, strength=0.5)
        # a saint: halo + body
        a.fill(a.ellipse(x + 6.5, 22, 3.6), '#f3cf6a', 0.95)
        a.fill(a.ellipse(x + 6.5, 22, 2.2), '#e8c9a0')
        a.fill(a.rrect(x + 3.2, 27, 6.6, 20, 3), ['#2a4c8f', '#3d6a3f', '#5a2a6a', '#8a3a1a'][i], 0.95)
    a.fill(a.rect(0, 6, 64, 2.4), '#e8c25a', 0.8)
    return done(a)


def candle_stand():
    a = A()
    base = a.ellipse(32, 36, 20, 17)
    a.shadow(base, 2, 3, 3, 0.5)
    a.shade(base, '#9c6f2a', bevel=6, strength=0.9, spec=0.7)
    a.fill(a.ellipse(32, 36, 15, 12), '#2a1d10')
    a.fill(a.ellipse(32, 36, 14, 11), '#8a5e22', 0.55)
    rng = np.random.default_rng(66)
    for i in range(13):
        ang = rng.uniform(0, 6.283)
        rr = rng.uniform(0, 12)
        x, y = 32 + np.cos(ang) * rr, 36 + np.sin(ang) * rr * 0.8
        a.fill(a.ellipse(x, y, 1.9), '#f6efd9')
        a.fill(a.ellipse(x, y - 0.4, 0.9), '#ffb52b')
        a.glow(x, y, 6, '#ffa21a', 0.35)
    return done(a)


def analoy():
    a = A()
    box(a, 14, 8, 36, 48, '#5a3820', r=3, bevel=3.5, grain=0.5, rough=1.5, seed=68, spec=0.2)
    slope = a.rrect(18, 12, 28, 38, 2)
    a.shade(slope, '#6e4527', bevel=2, strength=0.9, grain=0.35)
    # gold cloth + an open gospel book
    a.fill(a.rect(18, 12, 28, 6), '#c79b3c', 0.9)
    a.shade(a.rrect(21, 22, 22, 22, 2), '#7a1f2c', bevel=2, strength=0.9)
    a.shade(a.rect(23, 24, 8.4, 18), '#f1e6c8', bevel=1.2, strength=0.5)
    a.shade(a.rect(32.6, 24, 8.4, 18), '#f1e6c8', bevel=1.2, strength=0.5)
    for k in range(6):
        a.fill(a.rect(24.5, 27 + k * 2.6, 5.4, 0.6), '#5a4326', 0.8)
        a.fill(a.rect(34, 27 + k * 2.6, 5.4, 0.6), '#5a4326', 0.8)
    a.fill(a.rect(31.2, 24, 1.4, 18), '#8a6a2c', 0.9)
    return done(a)


def baptismal_font():
    a = A()
    disc(a, 32, 32, 22, '#a8a294', bevel=8, strength=0.95, grain=0.4, rough=1.6, seed=69)
    disc(a, 32, 32, 16, '#7c776b', bevel=3, strength=0.8, shadow=False, grain=0.3)
    wat = a.ellipse(32, 32, 14)
    a.shade(wat, '#4a86aa', bevel=3, strength=0.4, flat=True)
    n = fbm(a.H, a.W, 6 * 4, 70, 3)
    r = np.exp(-((n - 0.5) / 0.04) ** 2) * wat
    a.rgb = np.clip(a.rgb + r[..., None] * 0.35, 0, 1)
    a.fill(a.ellipse(26, 26, 2.4), '#e9f7ff', 0.5)
    return done(a)


def icon_lamp():
    a = A()
    disc(a, 32, 32, 14, '#9c6f2a', bevel=5, spec=0.7)
    disc(a, 32, 32, 8.5, '#b81d28', bevel=6, spec=0.6, shadow=False)
    a.fill(a.ellipse(32, 32, 3.6), '#ffb59a', 0.95)
    a.glow(32, 32, 28, '#ff2a2a', 0.65)
    return done(a)


def worship_cross():
    a = A()
    a.shadow(a.rect(26, 6, 12, 52), 2, 3, 2, 0.4)
    gold = '#d6aa4a'
    a.shade(a.rrect(28, 6, 8, 52, 2), gold, bevel=3, strength=1.0, spec=0.8)
    a.shade(a.rrect(14, 16, 36, 7, 2), gold, bevel=3, strength=1.0, spec=0.8)
    a.shade(a.rrect(20, 9, 24, 4.5, 1.8), gold, bevel=2, strength=1.0, spec=0.8)
    a.shade(a.rrect(21, 44, 22, 5, 1.8), gold, bevel=2, strength=1.0, spec=0.8)      # slanted foot rail, flat
    a.shade(a.rrect(24, 54, 16, 6, 2), '#5a3820', bevel=2, grain=0.3)
    a.fill(a.ellipse(32, 19.5, 1.5), '#8a1f2c')
    return done(a)


def shrine():
    a = A()
    base = a.rrect(8, 22, 48, 38, 3)
    a.shadow(base, 2, 3, 3, 0.55)
    a.shade(base, '#d8c9a8', bevel=2.5, strength=0.9, grain=0.4, seed=72)
    # pitched roof seen from above: two sloped planes with a ridge, red-lacquer trim
    left = a.poly([(4, 24), (32, 24), (32, 4), (4, 4)])
    a.shadow(a.rect(4, 4, 56, 22), 2, 3, 3, 0.4)
    a.shade(a.rect(4, 4, 28, 22), '#3b3f45', bevel=2.4, strength=0.9, grain=0.3, spec=0.3)
    a.shade(a.rect(32, 4, 28, 22), '#2c2f34', bevel=2.4, strength=0.9, grain=0.3)
    for k in range(7):
        a.fill(a.rect(4, 5 + k * 3, 56, 0.6), '#1b1d21', 0.8)
    a.shade(a.rect(30.5, 3, 3, 24), '#b8292d', bevel=1.2, strength=0.9)
    # doors, rope and a shide paper
    a.shade(a.rrect(18, 34, 28, 22, 2), '#8c2a2d', bevel=2, strength=0.8, spec=0.3)
    a.fill(a.rect(31.2, 35, 1.6, 20), '#3d1214', 0.9)
    a.fill(a.line(12, 30, 52, 30, 1.8), '#e9dcb4', 0.95)
    for x in (22, 32, 42):
        a.fill(a.poly([(x - 1.5, 30), (x + 1.5, 30), (x + 2, 38), (x, 36), (x - 2, 38)]), '#f6f3e8', 0.95)
    return done(a)


def offering_table():
    a = A()
    top = a.rrect(4, 10, 56, 44, 3)
    a.shadow(top, 2, 3, 3, 0.5)
    a.shade(top, '#7d4a2a', bevel=2.4, strength=0.9, grain=0.45, rough=1.6, seed=74, spec=0.2)
    a.fill(a.rect(10, 16, 44, 32), '#e9dcb4', 0.5)
    disc(a, 18, 26, 5.4, '#e6e2d6', spec=0.6)
    a.fill(a.ellipse(18, 26, 3.6), '#d93a3a')            # a persimmon on a plate
    disc(a, 34, 22, 3.4, '#f2efe6', spec=0.7)             # sake cup
    a.fill(a.ellipse(34, 22, 2.2), '#d8e8f0')
    box(a, 42, 30, 8, 14, '#2d6a8e', r=3, bevel=2.5, spec=0.8)       # sake bottle
    a.fill(a.rect(44, 34, 4, 6), '#f4f1e8')
    for k in range(3):
        disc(a, 22 + k * 6, 40, 2.4, '#fff8e8', spec=0.5, shadow=False)     # rice cakes
    return done(a)


def saisen_box():
    a = A()
    m = a.rrect(8, 12, 48, 40, 3)
    a.shadow(m, 2, 3, 3, 0.55)
    a.shade(m, '#8a5a30', bevel=3, strength=0.9, grain=0.5, rough=1.4, seed=76)
    for k in range(7):
        a.fill(a.rect(14 + k * 5.2, 14, 1.4, 36), '#1a0f06', 0.95)       # coin slats
    a.fill(a.rect(10, 12, 44, 3), '#6e4527', 0.8)
    a.fill(a.rect(10, 49, 44, 3), '#6e4527', 0.8)
    for (x, y) in ((16, 54), (47, 54)):
        pass
    a.fill(a.ellipse(36, 32, 1.3), '#e0c26a')
    return done(a)


def komainu():
    a = A()
    plinth = a.rrect(10, 8, 44, 50, 3)
    a.shadow(plinth, 2, 3, 3, 0.5)
    a.shade(plinth, '#8d8b84', bevel=3, strength=0.9, grain=0.45, seed=78)
    # a seated guardian lion-dog from above: body, haunches, head with mane and open mouth
    a.shade(a.ellipse(32, 36, 14, 16), '#a7a59d', bevel=8, strength=1.0, grain=0.4, seed=79)
    a.shade(a.ellipse(21, 42, 6, 8), '#9a988f', bevel=4, strength=1.0, grain=0.3)
    a.shade(a.ellipse(43, 42, 6, 8), '#9a988f', bevel=4, strength=1.0, grain=0.3)
    mane = a.ellipse(32, 20, 12, 10)
    a.shade(mane, '#b4b2a9', bevel=6, strength=1.0, grain=0.5, rough=1.2, seed=80)
    for k in range(9):
        ang = k / 9 * 6.283
        a.fill(a.line(32, 20, 32 + np.cos(ang) * 11, 20 + np.sin(ang) * 9, 1.0), '#7c7a72', 0.8)
    a.shade(a.ellipse(32, 20, 6.5, 6), '#c0beb5', bevel=4, strength=1.0, grain=0.3)
    a.fill(a.ellipse(32, 23, 3, 2), '#2a2927', 0.9)
    for x in (29.5, 34.5):
        a.fill(a.ellipse(x, 18, 1.0), '#2a2927')
    return done(a)


def lantern_stone():
    a = A()
    base = a.rrect(14, 14, 36, 36, 3)
    a.shadow(base, 2, 3, 3, 0.5)
    a.shade(base, '#8a8981', bevel=4, strength=0.95, grain=0.45, seed=82)
    roof = a.poly([(8, 32), (32, 8), (56, 32), (32, 56)])
    a.shadow(roof, 2, 3, 3, 0.4)
    a.shade(roof, '#7b7a73', bevel=10, strength=1.0, grain=0.45, seed=83)
    a.shade(a.ellipse(32, 32, 7), '#6d6c65', bevel=4, strength=1.0, grain=0.3)
    a.fill(a.ellipse(32, 32, 3), '#ffd27a', 0.95)
    a.glow(32, 32, 26, '#ffb340', 0.6)
    return done(a)


def chozuya():
    a = A()
    m = a.rrect(8, 14, 48, 38, 6)
    a.shadow(m, 2, 3, 3, 0.55)
    a.shade(m, '#9a978e', bevel=5, strength=0.95, grain=0.5, seed=85)
    wat = a.rrect(14, 20, 36, 26, 4)
    a.shade(wat, '#3e7a96', bevel=2.4, strength=0.5, flat=True)
    n = fbm(a.H, a.W, 6 * 4, 86, 3)
    a.rgb = np.clip(a.rgb + (np.exp(-((n - 0.5) / 0.04) ** 2) * wat)[..., None] * 0.3, 0, 1)
    # bamboo ladle laid across
    a.shade(a.line(14, 44, 54, 18, 2.2), '#b7a35a', bevel=1.2, strength=0.9, spec=0.4)
    a.shade(a.ellipse(18, 42, 3.2), '#a89348', bevel=2, spec=0.4)
    for x in (24, 36, 46):
        a.fill(a.ellipse(x, 40 - (x - 24) * 0.3, 0.8), '#6d5f2c')
    return done(a)


def ema_rack():
    a = A()
    box(a, 2, 6, 60, 16, '#6a4224', r=2, bevel=2, grain=0.5, seed=88)
    box(a, 2, 42, 60, 16, '#6a4224', r=2, bevel=2, grain=0.5, seed=89)
    rng = np.random.default_rng(90)
    for j, y in enumerate((14, 50)):
        for i in range(7):
            x = 5 + i * 8.4
            ema = a.poly([(x, y + 3), (x + 2.6, y - 5), (x + 7, y - 5), (x + 7, y + 6), (x, y + 6)])
            a.shadow(ema, 1, 1.5, 1.2, 0.4)
            a.shade(ema, '#d9b57a', bevel=1.4, strength=0.9, grain=0.3)
            a.fill(a.line(x + 3, y - 1, x + 6, y - 3, 0.7), ['#c0392b', '#2b6ca3', '#2a2a2a'][(i + j) % 3], 0.9)
    return done(a)


def torii():
    a = A()
    # kasagi top lintel (long), nuki below, two pillars: seen from above as long bars with shadows
    red = '#c8302a'
    a.shadow(a.rect(2, 4, 60, 14), 2, 4, 3, 0.5)
    a.shade(a.rrect(1, 4, 62, 14, 3), '#2a2a2e', bevel=3, strength=0.9, spec=0.3)         # kasagi black cap
    a.shade(a.rrect(3, 6, 58, 10, 2), red, bevel=3, strength=0.9, spec=0.3, grain=0.2)
    a.shade(a.rrect(8, 22, 48, 6, 2), red, bevel=2, strength=0.9, spec=0.3)              # nuki
    a.fill(a.rect(30, 6, 4, 22), '#e9d28a', 0.9)                                          # plaque
    for x in (13, 51):
        disc(a, x, 44, 7, red, bevel=4, strength=0.9, spec=0.35)
        disc(a, x, 44, 7.6, '#1a1a1d', bevel=1, shadow=False) if False else None
        a.fill(a.ellipse(x, 52, 8, 3), '#2a2a2e', 0.9)
    a.shadow(a.rect(8, 22, 48, 6), 2, 5, 3, 0.35)
    return done(a)


def shimenawa_pole():
    a = A()
    disc(a, 32, 38, 7, '#a8905a', bevel=5, strength=1.0, spec=0.3, grain=0.4, seed=94)
    # heavy rope curled round, with paper shide
    for k in range(5):
        ang = k * 1.256
        a.shade(a.line(32 + np.cos(ang) * 12, 38 + np.sin(ang) * 12, 32 + np.cos(ang + 1.0) * 12, 38 + np.sin(ang + 1.0) * 12, 3.2), '#e0d2a0', bevel=1.4, strength=0.9, grain=0.6, seed=k)
    for x, y in ((18, 22), (32, 18), (46, 22)):
        a.fill(a.poly([(x - 1.6, y), (x + 1.6, y), (x + 2.4, y + 9), (x, y + 6), (x - 2.4, y + 9)]), '#f8f6ee', 0.95)
    return done(a)


def bonsai():
    a = A()
    pot = a.rrect(16, 20, 32, 28, 4)
    a.shadow(pot, 2, 3, 3, 0.5)
    a.shade(pot, '#6a4a34', bevel=3.4, strength=0.9, grain=0.4, spec=0.3)
    a.shade(a.rrect(19, 23, 26, 22, 3), '#2a1e14', bevel=2, strength=0.4, flat=True)
    a.shade(a.line(32, 40, 28, 28, 3.4), '#5a3a22', bevel=1.4, strength=0.9)
    rng = np.random.default_rng(97)
    for (cx, cy, r) in ((24, 24, 8), (36, 22, 9), (30, 14, 8), (40, 32, 6.4), (21, 34, 6)):
        a.shade(a.ellipse(cx, cy, r), '#3a7a3a', bevel=r * 0.8, strength=0.9, grain=0.4, rough=1.2, seed=int(cx))
    for i in range(12):
        x, y = rng.uniform(16, 44), rng.uniform(8, 38)
        a.fill(a.ellipse(x, y, 1.0), '#9ccd6a', 0.8)
    return done(a)


def fern():
    a = A()
    pot = a.ellipse(32, 34, 13)
    a.shadow(pot, 2, 3, 3, 0.5)
    a.shade(pot, '#a65a38', bevel=5, strength=0.9, spec=0.3)
    for k in range(12):
        ang = k / 12 * 6.283
        x1, y1 = 32 + np.cos(ang) * 24, 32 + np.sin(ang) * 24
        a.shade(a.line(32, 32, x1, y1, 4.4), ['#3e8a45', '#2f7236', '#52a252'][k % 3], bevel=1.6, strength=0.9, spec=0.2)
        for t in np.linspace(0.3, 0.95, 5):
            px, py = 32 + (x1 - 32) * t, 32 + (y1 - 32) * t
            a.fill(a.ellipse(px, py, 2.2 * (1 - t * 0.5)), '#6ec06e', 0.6)
    a.fill(a.ellipse(32, 32, 3), '#2a5a2e')
    return done(a)


def aquarium():
    a = A()
    frame = a.rrect(2, 8, 60, 48, 3)
    a.shadow(frame, 2, 3, 3, 0.5)
    a.shade(frame, '#1d2026', bevel=2, spec=0.3)
    water = a.rect(5, 11, 54, 42)
    a.shade(water, '#2a90c4', bevel=3, strength=0.35, grad='v', base2='#0e4d7a')
    a.glow(32, 30, 34, '#35d7ff', 0.4)
    rng = np.random.default_rng(100)
    # gravel + plants
    a.shade(a.rect(5, 46, 54, 7), '#cdbb8a', bevel=1.5, strength=0.5, grain=0.5, rough=1)
    for x in (12, 50, 36):
        for k in range(4):
            a.fill(a.line(x, 48, x + rng.uniform(-3, 3), 48 - rng.uniform(8, 16), 1.5), '#3ba85a', 0.95)
    for i, (x, y, c) in enumerate(((22, 26, '#ff8a2a'), (40, 34, '#f4f1e8'), (30, 18, '#ff3fa4'))):
        a.fill(a.ellipse(x, y, 4.4, 2.4), c)
        a.fill(a.poly([(x - 4, y), (x - 8, y - 3), (x - 8, y + 3)]), c, 0.9)
        a.fill(a.ellipse(x + 2, y - 0.6, 0.6), '#101010')
    yy, xx = a.yy, a.xx
    g = np.exp(-(((xx + yy * 0.6) % 30) - 5) ** 2 / 5.0) * water * 0.25
    a.rgb = np.clip(a.rgb + g[..., None], 0, 1)
    a.fill(a.rect(4, 10, 56, 2.2), '#8fd0ee', 0.5)
    return done(a)


def charm_counter():
    a = A()
    top = a.rect(0, 12, 64, 38)
    a.shadow(top, 0, 3, 2.5, 0.5)
    a.shade(top, '#7d4a2a', bevel=2.2, strength=0.9, grain=0.45, rough=1.5, seed=102, spec=0.25)
    a.fill(a.rect(0, 12, 64, 2), '#c08b52', 0.8)
    cols = ['#c8302a', '#2b78c9', '#e8c53a', '#3d9b5a', '#f06fa8', '#8a4fc0']
    for i in range(7):
        x = 5 + i * 8.4
        for j in range(2):
            y = 19 + j * 14
            bag = a.rrect(x, y, 6, 9, 1.4)
            a.shade(bag, cols[(i + j * 3) % 6], bevel=1.6, strength=0.9, spec=0.35)
            a.fill(a.rect(x + 1, y + 1, 4, 1.2), '#e0c26a', 0.9)
            a.fill(a.rect(x + 2.6, y - 1.8, 0.8, 2.4), '#e0c26a', 0.9)
    return done(a)


def cabinet_lacquer():
    a = A()
    box(a, 4, 6, 56, 52, '#161316', r=3, bevel=3.5, spec=0.8)
    a.fill(a.rect(31, 8, 1.6, 48), '#c79b3c', 0.9)
    for (x, y) in ((8, 10), (36, 10), (8, 34), (36, 34)):
        a.fill(a.rect(x, y, 20, 20), '#8a1f2c', 0.9)
        a.stroke(a.rect(x, y, 20, 20), '#c79b3c', 1.0, 0.9)
        a.fill(a.poly([(x + 10, y + 3), (x + 17, y + 10), (x + 10, y + 17), (x + 3, y + 10)]), '#c79b3c', 0.6)
    for x in (27, 34):
        a.shade(a.ellipse(x, 32, 1.6), '#d6aa4a', bevel=1.2, spec=0.8)
    return done(a)


def neon_pink():
    a = A()
    box(a, 4, 18, 56, 28, '#14131a', r=3, bevel=2.5, spec=0.2)
    # tubes forming a stylised word-ish glyph row
    tubes = [[(10, 40), (10, 24), (18, 24), (18, 32), (10, 32)],
             [(24, 24), (24, 40)], [(24, 24), (32, 24), (32, 32), (24, 32)],
             [(38, 24), (38, 40), (46, 40)], [(52, 24), (52, 40)]]
    for tb in tubes:
        for (p, q) in zip(tb, tb[1:]):
            a.glow((p[0] + q[0]) / 2, (p[1] + q[1]) / 2, 11, GLOW_M, 0.55)
    for tb in tubes:
        for (p, q) in zip(tb, tb[1:]):
            a.fill(a.line(p[0], p[1], q[0], q[1], 2.6), '#ff5fb6', 1.0)
            a.fill(a.line(p[0], p[1], q[0], q[1], 1.1), '#ffe1f2', 1.0)
    return done(a, 0.6)


def chair():
    a = A()
    seat = a.rrect(14, 16, 36, 36, 5)
    a.shadow(seat, 2, 3, 3, 0.5)
    a.shade(seat, '#6d5a48', bevel=4, strength=0.9, grain=0.3, spec=0.2)
    a.shade(a.rrect(14, 8, 36, 10, 4), '#4a3a2c', bevel=3, strength=0.9, grain=0.3, spec=0.2)
    a.fill(a.rect(16, 18, 32, 1.1), '#2a2018', 0.7)
    return done(a)


def table_generic():
    a = A()
    m = a.rrect(6, 6, 52, 52, 4)
    a.shadow(m, 2, 3, 3, 0.55)
    a.shade(m, '#7c8089', bevel=3, strength=0.85, grain=0.2, spec=0.4)
    a.shade(a.rrect(9, 9, 46, 46, 3), '#8a8e97', bevel=1.4, strength=0.4, flat=True, grain=0.2)
    return done(a)


# ------------------------------------------------------------------------------------------------ mission terminal, portal, site machinery
def mission_terminal():
    a = A()
    base = box(a, 14, 38, 36, 20, '#2a2f38', r=3, bevel=3, spec=0.4)
    a.shade(a.rrect(17, 47, 30, 8, 2), '#14171c', bevel=1.2, strength=0.5)
    for i in range(7):
        a.fill(a.rect(19 + i * 4, 49, 3, 2), '#55606e', 0.9)
    box(a, 18, 8, 28, 32, '#1b1f27', r=3, bevel=2.5, spec=0.5)
    scr = a.rect(21, 11, 22, 24)
    a.shade(scr, '#06151c', bevel=1.2, strength=0.4)
    for j in range(6):
        w = 8 + (j * 7) % 13
        a.fill(a.rect(23, 13 + j * 3.6, w, 1.6), GLOW_C, 0.9)
    a.fill(a.rect(23, 33, 4, 1.4), GLOW_M, 0.95)
    a.glow(32, 22, 22, GLOW_C, 0.22)
    a.fill(a.ellipse(48, 52, 1.6), GLOW_M, 0.9)
    return done(a)


def mission_portal():
    a = A()
    ring = a.ellipse(32, 32, 24)
    a.glow(32, 32, 30, '#7a4dff', 0.55)
    a.shade(ring, '#2a1a66', bevel=6, strength=0.9, spec=0.6)
    inner = a.ellipse(32, 32, 17)
    a.shade(inner, '#0a0624', bevel=4, strength=0.5)
    yy, xx = a.yy, a.xx
    r = np.sqrt((xx - 32) ** 2 + (yy - 32) ** 2)
    ang = np.arctan2(yy - 32, xx - 32)
    swirl = (0.5 + 0.5 * np.sin(ang * 3 + r * 0.45)) * inner
    a.rgb = np.clip(a.rgb + swirl[..., None] * np.array([0.25, 0.9, 1.0]) * 0.55, 0, 1)
    a.glow(32, 32, 14, GLOW_C, 0.5)
    a.fill(a.ellipse(32, 32, 3.5), '#e9fbff', 0.9)
    return done(a)


def mission_device():
    a = A()
    box(a, 10, 12, 44, 44, '#59626d', r=3, bevel=4, spec=0.5, grain=0.2)
    a.shade(a.rrect(14, 16, 36, 20, 2), '#2b3038', bevel=1.5, strength=0.5)
    for i in range(3):
        a.fill(a.ellipse(21 + i * 11, 26, 3.4), ['#ff8a2a', '#35d7ff', '#6ab04c'][i], 0.95)
    a.shade(a.rect(14, 40, 36, 4), '#17191d', bevel=1)
    a.shade(a.rect(14, 47, 36, 4), '#17191d', bevel=1)
    a.fill(a.rect(40, 40, 8, 11), '#d62b3a', 0.9)
    a.glow(32, 28, 20, '#ff8a2a', 0.12)
    return done(a)


def charging_post():
    """A government implant charging post: a squat white-and-blue pillar with a lit panel, a yellow bolt and a coiled lead."""
    a = A()
    box(a, 12, 52, 40, 8, '#4a4f57', r=2, bevel=2, spec=0.3)
    box(a, 18, 10, 28, 46, '#d9dee4', r=4, bevel=3.5, spec=0.5)
    a.shade(a.rect(18, 10, 28, 9), '#1f4f9e', bevel=1.5, strength=0.6)
    scr = a.rect(22, 22, 20, 14)
    a.shade(scr, '#06151c', bevel=1.2, strength=0.4)
    for j in range(3):
        a.fill(a.rect(24, 24 + j * 4, 6 + (j * 5) % 9, 2), GLOW_C, 0.9)
    a.fill(a.poly([(37, 38), (32, 47), (36, 47), (33, 55), (42, 44), (38, 44), (41, 38)]), '#ffd21f', 0.95)
    a.glow(32, 29, 18, GLOW_C, 0.18)
    a.fill(a.ellipse(46, 50, 3.4), '#222831', 0.95)
    a.fill(a.ellipse(46, 50, 1.6), '#5ec1ff', 0.9)
    return done(a)


def gunsmith_table():
    """A gunsmithing table: a steel-topped bench with a vise, a half-stripped pistol, loose parts and a lamp."""
    a = A()
    box(a, 6, 14, 52, 38, '#5b3a20', r=3, bevel=3, spec=0.2)
    box(a, 9, 17, 46, 32, '#aeb6c0', r=2, bevel=2.5, spec=0.5)
    box(a, 11, 20, 12, 10, '#2b3038', r=1.5, bevel=2, spec=0.6)
    box(a, 14, 30, 6, 4, '#59626d', r=1, bevel=1.5)
    a.fill(a.rect(28, 28, 20, 5), '#17191d', 0.95)
    a.fill(a.rect(28, 28, 6, 12), '#17191d', 0.95)
    a.fill(a.rect(36, 30, 10, 2), '#6b7480', 0.9)
    for k, (px, py) in enumerate([(30, 42), (36, 44), (42, 41), (47, 44)]):
        a.fill(a.ellipse(px, py, 1.6), '#c8a24a' if k % 2 else '#8a919b', 0.95)
    a.fill(a.ellipse(48, 22, 4.2), '#e9c46a', 0.95)
    a.glow(48, 22, 14, '#ffd98a', 0.22)
    return done(a)


def _ev_charger_big():
    """A two-by-two vehicle charging bank (128 x 128): a green-and-white plinth with two pillars, lit screens, a bolt and two heavy cables."""
    a = Art(128, 128, 4)
    box(a, 8, 96, 112, 24, '#4a4f57', r=4, bevel=3, spec=0.3)
    for x0 in (14, 74):
        box(a, x0, 12, 40, 90, '#e4e8ec', r=5, bevel=4, spec=0.5)
        a.shade(a.rect(x0, 12, 40, 14), '#1f9e5a', bevel=2, strength=0.6)
        scr = a.rect(x0 + 6, 32, 28, 22)
        a.shade(scr, '#06151c', bevel=1.5, strength=0.4)
        for j in range(3):
            a.fill(a.rect(x0 + 9, 36 + j * 6, 8 + (j * 7) % 13, 3), '#4dff9a', 0.9)
        a.glow(x0 + 20, 43, 26, '#4dff9a', 0.16)
        a.fill(a.ellipse(x0 + 20, 74, 9), '#17191d', 0.95)
        a.fill(a.poly([(x0 + 23, 64), (x0 + 15, 76), (x0 + 20, 76), (x0 + 17, 86), (x0 + 28, 72), (x0 + 22, 72), (x0 + 26, 64)]), '#ffd21f', 0.95)
    a.fill(a.rect(56, 70, 16, 6), '#222831', 0.95)
    a.fill(a.ellipse(64, 73, 4), '#5ec1ff', 0.9)
    return a.image(outline=0.85)


def _ev_part(qx, qy):
    im = _ev_charger_big()
    return im.crop((qx * 64, qy * 64, qx * 64 + 64, qy * 64 + 64))


FLOORS = {'t_trl_checker': f_checker, 't_trl_floor_church': f_church, 't_trl_floor_hinoki': f_hinoki, 't_trl_floor_clean': f_clean,
          't_trl_marble': f_marble, 't_trl_floor_steel': f_steel, 't_trl_floor_wood': f_wood, 't_trl_tatami': f_tatami, 't_trl_carpet_red': f_carpet}

FURN = {
    'f_trl_shop_counter': lambda: counter('shop'), 'f_trl_counter_noodle': lambda: counter('noodle'),
    'f_trl_kitchen_range': kitchen_range, 'f_trl_kitchen_fridge': fridge, 'f_trl_sushi_case': sushi_case, 'f_trl_pizza_oven': pizza_oven,
    'f_trl_dining_table': dining_table, 'f_trl_table_plastic': table_plastic, 'f_trl_tea_table': tea_table,
    'f_trl_stool_plastic': stool_plastic, 'f_trl_bar_stool': bar_stool, 'f_trl_menu_board': menu_board, 'f_trl_samovar': samovar,
    'f_trl_liquor_shelf': liquor_shelf, 'f_trl_hot_plate': hot_plate,
    'f_trl_shelf_clean': shelf_clean, 'f_trl_produce_bin': produce_bin, 'f_trl_freezer_case': freezer_case, 'f_trl_checkout': checkout,
    'f_trl_vending': vending, 'f_trl_water_cooler': water_cooler,
    'f_trl_charger': charging_post, 'f_trl_gunsmith_table': gunsmith_table,
    'f_trl_ev_nw': lambda: _ev_part(0, 0), 'f_trl_ev_ne': lambda: _ev_part(1, 0), 'f_trl_ev_sw': lambda: _ev_part(0, 1), 'f_trl_ev_se': lambda: _ev_part(1, 1), 'f_trl_terminal': mission_terminal, 'f_trl_portal': mission_portal, 'f_trl_device': mission_device,
    'f_trl_implant_chair': implant_chair, 'f_trl_implant_printer': implant_printer, 'f_trl_limb_bin': limb_bin,
    'f_trl_autodoc_imp_m': autodoc, 'f_trl_hospital_bed': hospital_bed, 'f_trl_ward_bed': lambda: hospital_bed('#7fae8a'),
    'f_trl_scanner': scanner, 'f_trl_med_cabinet': med_cabinet, 'f_trl_iv_stand': iv_stand, 'f_trl_reception': reception, 'f_trl_exam_couch': exam_couch,
    'f_trl_church_bench': church_bench, 'f_trl_iconostasis': iconostasis, 'f_trl_candle_stand': candle_stand, 'f_trl_analoy': analoy,
    'f_trl_baptismal_font': baptismal_font, 'f_trl_icon_lamp': icon_lamp, 'f_trl_worship_cross': worship_cross,
    'f_trl_shrine': shrine, 'f_trl_offering_table': offering_table, 'f_trl_saisen_box': saisen_box, 'f_trl_komainu': komainu,
    'f_trl_lantern_stone': lantern_stone, 'f_trl_chozuya': chozuya, 'f_trl_ema_rack': ema_rack, 'f_trl_torii': torii,
    'f_trl_shimenawa_pole': shimenawa_pole, 'f_trl_bonsai': bonsai, 'f_trl_fern': fern, 'f_trl_aquarium': aquarium,
    'f_trl_charm_counter': charm_counter, 'f_trl_cabinet_lacquer': cabinet_lacquer, 'f_trl_neon_pink': neon_pink,
    'f_chair': chair, 'f_table': table_generic,
}


def sprites(items=None):
    out = []
    for k, f in FLOORS.items():
        out.append((k, f()))
    for k, f in FURN.items():
        out.append((k, f()))
    return out, {}
