"""64x64 terrain tiles for the Trilobit tileset: tileable ground textures, floors, doors, autotiling walls."""
import numpy as np
from scipy import ndimage as ndi
from art64 import Art, fbm, vnoise, hx, col, mix, lit

SS = 2


def _new(seed_wrap=True):
    return Art(64, 64, SS, wrap=seed_wrap)


def _tex(a, base, lo=0.8, hi=1.2, scale=8, seed=1, oct=4):
    n = fbm(a.H, a.W, scale * a.ss, seed, oct, True)
    a.rgb[:] = col(base)[None, None, :] * (lo + (hi - lo) * n)[..., None]
    a.a[:] = 1.0
    return n


def _specks(a, seed, density, c, lo=0.0, hi=1.0, size=1):
    rng = np.random.default_rng(seed)
    m = rng.random((a.H, a.W)) < density
    if size > 1:
        m = ndi.binary_dilation(m, iterations=size - 1)
    k = (lo + (hi - lo) * rng.random((a.H, a.W)))[..., None]
    a.rgb[m] = a.rgb[m] * (1 - k[m]) + col(c)[None, :] * k[m]


def _crack(a, seed, c=(0.04, 0.04, 0.05), width=1.0, alpha=0.9, length=40):
    rng = np.random.default_rng(seed)
    x, y = rng.uniform(8, 56), rng.uniform(8, 56)
    ang = rng.uniform(0, 6.28)
    for i in range(length):
        ang += rng.normal(0, 0.45)
        nx, ny = x + np.cos(ang) * 1.6, y + np.sin(ang) * 1.6
        m = a.line(x % 64, y % 64, nx % 64, ny % 64, width) if abs(nx - x) < 8 and abs(ny - y) < 8 else None
        if m is not None:
            a.fill(m, c, alpha)
        x, y = nx, ny
        if rng.random() < 0.06:
            ang += rng.choice([-1, 1]) * 0.9


def _blot(a, seed, c, scale, thresh, alpha, soft=0.12):
    n = fbm(a.H, a.W, scale * a.ss, seed, 3, True)
    k = np.clip((n - thresh) / soft, 0, 1) * alpha
    a.rgb = a.rgb * (1 - k[..., None]) + col(c)[None, None, :] * k[..., None]


def _grid_lines(a, step, joint, hi, width=1.0, seed=0, wobble=0.0):
    """dark joint lines at the tile's right/bottom edges every `step` px with a bright lip: tiles seamlessly"""
    s = a.ss
    for k in range(0, 64, step):
        for (ix, iy) in ((k + step - width, None), (None, k + step - width)):
            pass
    jx = np.zeros((a.H, a.W), bool)
    jy = np.zeros((a.H, a.W), bool)
    w = int(width * s)
    for k in range(step, 65, step):
        x0 = (k * s - w) % a.W
        for d in range(w):
            jx[:, (x0 + d) % a.W] = True
            jy[(x0 + d) % a.H, :] = True
    j = jx | jy
    lip = np.roll(j, -w, axis=1) | np.roll(j, -w, axis=0)
    lip &= ~j
    a.rgb[j] = a.rgb[j] * 0.0 + col(joint)
    a.rgb[lip] = np.clip(a.rgb[lip] * 1.0 + col(hi) * 0.12, 0, 1)


# ------------------------------------------------------------------------------------------------ ground
def sidewalk(v):
    a = _new()
    _tex(a, '#9a9ca0', 0.82, 1.14, 10, 10 + v, 4)
    _specks(a, 100 + v, 0.020, '#5b5c62', 0.2, 0.7)
    _specks(a, 140 + v, 0.012, '#d2d2d6', 0.2, 0.6)
    _blot(a, 120 + v, '#6d6e72', 14, 0.62, 0.45)
    if v % 2 == 0:
        _crack(a, 7 + v, (0.22, 0.22, 0.24), 0.8, 0.8, 22)
    if v == 3:
        _blot(a, 5, '#7a6d52', 6, 0.7, 0.4)
    # expansion joints (every tile edge): dark seam with a lit lip so the grid reads at distance
    _grid_lines(a, 64, '#4b4c52', '#ffffff', 1.5)
    # mid-slab control joint
    s = a.ss
    for d in range(s):
        a.rgb[:, 32 * s + d] *= 0.78
        a.rgb[32 * s + d, :] *= 0.78
    return a.image()


def road(v):
    a = _new()
    n = _tex(a, '#4a4c54', 0.88, 1.12, 9, 20 + v, 3)
    # aggregate: pale and dark chips
    _specks(a, 200 + v, 0.025, '#8a8c93', 0.2, 0.5)
    _specks(a, 230 + v, 0.015, '#25262b', 0.2, 0.5)
    _specks(a, 260 + v, 0.004, '#c3c5cc', 0.3, 0.6, 2)
    # tyre-worn polished bands
    band = np.exp(-((np.arange(a.W) - (20 + 6 * (v % 3)) * a.ss) / (7 * a.ss)) ** 2)
    band2 = np.exp(-((np.arange(a.W) - (44 + 3 * (v % 2)) * a.ss) / (7 * a.ss)) ** 2)
    k = ((band + band2) * 0.10)[None, :, None]
    a.rgb = np.clip(a.rgb * (1 - k) + col('#1a1b1f') * k, 0, 1)
    _blot(a, 300 + v, '#3a3c43', 14, 0.66, 0.25)
    if v % 3 == 0:
        _blot(a, 310 + v, '#3a4a60', 10, 0.74, 0.3, 0.12)      # wet patch with a cold sheen
        _specks(a, 320 + v, 0.003, '#7fd8ff', 0.3, 0.8, 1)
    if v == 1:
        _crack(a, 40 + v, (0.2, 0.2, 0.22), 1.0, 0.6, 30)
    if v == 5:
        _blot(a, 77, '#2a2a30', 16, 0.76, 0.45, 0.12)         # oil
    return a.image()


def concrete(v):
    a = _new()
    _tex(a, '#8d8f92', 0.85, 1.12, 12, 40 + v, 4)
    _specks(a, 400 + v, 0.03, '#595a5e', 0.2, 0.7)
    _specks(a, 420 + v, 0.01, '#c8c8cb', 0.2, 0.5)
    _blot(a, 440 + v, '#6c6d70', 16, 0.6, 0.5)
    # form-tie holes in the corners
    for (x, y) in ((8, 8), (56, 8), (8, 56), (56, 56)):
        m = a.ellipse(x, y, 1.6)
        a.fill(m, '#4d4e52')
        a.fill(a.ellipse(x - .4, y - .4, 0.7), '#7d7e82')
    _grid_lines(a, 64, '#575a5e', '#ffffff', 1.0)
    if v % 2:
        _crack(a, 33 + v, (0.25, 0.25, 0.27), 0.9, 0.8, 24)
    return a.image()


def floor_tile(v):
    """interior floor: scuffed composite tiles in a cool grey with a faint grid"""
    a = _new()
    _tex(a, '#7d8087', 0.9, 1.08, 14, 60 + v, 3)
    # four tiles, each with a slightly different tone
    s = a.ss
    rng = np.random.default_rng(600 + v)
    for i in range(2):
        for j in range(2):
            tone = 0.95 + 0.1 * rng.random()
            a.rgb[j * 32 * s:(j + 1) * 32 * s, i * 32 * s:(i + 1) * 32 * s] *= tone
    _specks(a, 610 + v, 0.012, '#4a4c52', 0.2, 0.6)
    _blot(a, 620 + v, '#5d6066', 12, 0.66, 0.45)
    _grid_lines(a, 32, '#43464c', '#ffffff', 1.0)
    return a.image()


def metal_floor(v):
    a = _new()
    _tex(a, '#5a6068', 0.9, 1.1, 10, 70 + v, 3)
    _specks(a, 700 + v, 0.012, '#2a2c30', 0.2, 0.6)
    _grid_lines(a, 32, '#2c2f34', '#ffffff', 1.2)
    # bolts
    for (x, y) in ((4, 4), (28, 4), (4, 28), (28, 28), (36, 4), (60, 4), (36, 28), (60, 28), (4, 36), (28, 36), (4, 60), (28, 60), (36, 36), (60, 36), (36, 60), (60, 60)):
        a.fill(a.ellipse(x, y, 1.3), '#2e3136')
        a.fill(a.ellipse(x - .3, y - .3, 0.8), '#9aa1ab')
    # anti-slip diamonds on two plates
    for (px, py) in ((0, 0), (32, 32)):
        for i in range(5):
            for j in range(5):
                cx, cy = px + 6 + i * 5, py + 6 + j * 5
                if (i + j) % 2 == 0:
                    a.fill(a.poly([(cx, cy - 1.6), (cx + 1.6, cy), (cx, cy + 1.6), (cx - 1.6, cy)]), '#7d848d')
    return a.image()


def grating(v):
    """gangway / catwalk: steel mesh over a dark void"""
    a = _new()
    a.rgb[:] = col('#0b0c10')
    a.a[:] = 1
    s = a.ss
    # cross bars
    for i in range(0, 64, 8):
        m = a.rect(i, 0, 3.2, 64)
        a.shade(m, '#7e8791', bevel=1.2, strength=0.8, flat=False)
    for j in range(0, 64, 8):
        m = a.rect(0, j + 3.2, 64, 2.6)
        a.shade(m, '#5c646d', bevel=1.0, strength=0.7)
    # load bars
    for j in (0, 32):
        m = a.rect(0, j, 64, 3.4)
        a.shade(m, '#9ba4af', bevel=1.4, strength=0.9)
    # frame lip
    a.shade(a.rect(0, 0, 64, 2), '#a6afba', bevel=0.8)
    return a.image()


def grass(v):
    a = _new()
    n = _tex(a, '#3f6b2f', 0.72, 1.28, 12, 80 + v, 4)
    # tonal drift towards dry olive and deep green
    dry = fbm(a.H, a.W, 18 * a.ss, 81 + v, 2, True)
    k = np.clip((dry - 0.55) * 3, 0, 1)[..., None] * 0.5
    a.rgb = a.rgb * (1 - k) + col('#7d7a35') * k
    rng = np.random.default_rng(800 + v)
    # blades: short strokes in a few greens
    greens = ['#2c5424', '#4f8a3a', '#6aa84a', '#35632b', '#8fb45a']
    for i in range(130):
        x, y = rng.uniform(0, 64), rng.uniform(0, 64)
        ang = -1.57 + rng.normal(0, 0.45)
        L = rng.uniform(2.2, 4.5)
        c = greens[rng.integers(len(greens))]
        for (ox, oy) in ((0, 0), (64, 0), (-64, 0), (0, 64), (0, -64)):
            xx, yy = x + ox, y + oy
            if -6 < xx < 70 and -6 < yy < 70:
                a.fill(a.line(xx, yy, xx + np.cos(ang) * L, yy + np.sin(ang) * L, 0.9), c, 0.95)
    if v == 1:
        for i in range(4):
            x, y = rng.uniform(6, 58), rng.uniform(6, 58)
            a.fill(a.ellipse(x, y, 1.4), '#f1f0e0')
            a.fill(a.ellipse(x, y, 0.6), '#e6c93c')
    if v == 2:
        for i in range(3):
            x, y = rng.uniform(6, 58), rng.uniform(6, 58)
            a.fill(a.ellipse(x, y, 1.2), '#d9769a')
    _blot(a, 850 + v, '#243f1d', 20, 0.66, 0.45)
    return a.image()


def grass_grazed(v):
    a = _new()
    _tex(a, '#6a7a38', 0.78, 1.2, 10, 90 + v, 4)
    rng = np.random.default_rng(900 + v)
    for i in range(70):
        x, y = rng.uniform(0, 64), rng.uniform(0, 64)
        ang = -1.57 + rng.normal(0, 0.6)
        L = rng.uniform(1.5, 3)
        c = ['#8a8a45', '#5a6a30', '#9c9650'][rng.integers(3)]
        for (ox, oy) in ((0, 0), (64, 0), (-64, 0), (0, 64), (0, -64)):
            xx, yy = x + ox, y + oy
            if -6 < xx < 70 and -6 < yy < 70:
                a.fill(a.line(xx, yy, xx + np.cos(ang) * L, yy + np.sin(ang) * L, 0.8), c, 0.9)
    _blot(a, 950 + v, '#8c7a50', 14, 0.62, 0.55)   # bare earth patches
    _specks(a, 960 + v, 0.006, '#5e4e34', 0.3, 0.8, 1)
    return a.image()


def sand(v):
    a = _new()
    _tex(a, '#cdb98a', 0.88, 1.1, 14, 110 + v, 3)
    # wind ripples
    yy = np.arange(a.H)[:, None] / a.ss
    xx = np.arange(a.W)[None, :] / a.ss
    n = fbm(a.H, a.W, 20 * a.ss, 111 + v, 2, True)
    rip = np.sin((yy * 0.55 + n * 6.0) * 1.0 + xx * 0.12 * 0) * 0.5 + 0.5
    a.rgb *= (0.93 + 0.12 * rip)[..., None]
    _specks(a, 1100 + v, 0.02, '#8b7650', 0.2, 0.6)
    _specks(a, 1130 + v, 0.012, '#efe2bb', 0.2, 0.6)
    if v == 2:
        _specks(a, 1140, 0.0015, '#7d7d7d', 0.5, 0.9, 2)
    return a.image()


def gravel(v):
    a = _new()
    _tex(a, '#6e6a64', 0.7, 1.2, 5, 120 + v, 3)
    rng = np.random.default_rng(1200 + v)
    pal = ['#9b9892', '#7d7a74', '#5a5750', '#b0aca5', '#4a4741', '#86837c']
    for i in range(190):
        x, y = rng.uniform(0, 64), rng.uniform(0, 64)
        r = rng.uniform(1.0, 2.6)
        c = pal[rng.integers(len(pal))]
        for (ox, oy) in ((0, 0), (64, 0), (-64, 0), (0, 64), (0, -64), (64, 64), (-64, -64), (64, -64), (-64, 64)):
            xx, yy = x + ox, y + oy
            if -4 < xx < 68 and -4 < yy < 68:
                m = a.ellipse(xx, yy, r, r * rng.uniform(0.7, 1.0))
                a.shade(m, c, bevel=r * 0.9, strength=0.9)
    return a.image()


def rock_floor(v):
    a = _new()
    _tex(a, '#6b6862', 0.78, 1.15, 9, 130 + v, 4)
    _blot(a, 1300 + v, '#4a4843', 10, 0.58, 0.55)
    _specks(a, 1310 + v, 0.02, '#3b3a36', 0.2, 0.7)
    _specks(a, 1320 + v, 0.01, '#9a978f', 0.2, 0.6)
    rng = np.random.default_rng(1330 + v)
    for i in range(7):
        x, y = rng.uniform(4, 60), rng.uniform(4, 60)
        r = rng.uniform(2, 5)
        m = a.ellipse(x, y, r, r * 0.8)
        a.shade(m, '#7a766e', bevel=r * 0.8, strength=0.9, grain=0.2, seed=int(x * 3))
    return a.image()


def rock(v, tint=(0.52, 0.50, 0.48), tone='rock'):
    """impassable rock: a lit boulder field seen from above"""
    base = np.array(tint)
    a = _new()
    _tex(a, base * 0.8, 0.7, 1.15, 7, 140 + v, 4)
    rng = np.random.default_rng(1400 + v)
    slabs = []
    for i in range(9):
        x, y = rng.uniform(0, 64), rng.uniform(0, 64)
        w, h = rng.uniform(14, 26), rng.uniform(12, 22)
        ang = rng.uniform(0, 3.14)
        pts = []
        for k in range(7):
            t = k / 7 * 6.283 + rng.normal(0, 0.18)
            rr = rng.uniform(0.7, 1.0)
            px = np.cos(t) * w * 0.5 * rr
            py = np.sin(t) * h * 0.5 * rr
            pts.append((px * np.cos(ang) - py * np.sin(ang), px * np.sin(ang) + py * np.cos(ang)))
        for (ox, oy) in ((0, 0), (64, 0), (-64, 0), (0, 64), (0, -64), (64, 64), (-64, -64), (64, -64), (-64, 64)):
            P = [(x + ox + px, y + oy + py) for px, py in pts]
            if max(p[0] for p in P) < -2 or min(p[0] for p in P) > 66 or max(p[1] for p in P) < -2 or min(p[1] for p in P) > 66:
                continue
            m = a.poly(P)
            c = base * (0.75 + 0.5 * rng.random())
            a.shade(m, c, bevel=5.5, strength=0.95, grain=0.35, seed=i * 7 + v, rough=1.5)
    _specks(a, 1450 + v, 0.01, '#222', 0.3, 0.8)
    return a.image()


def rock_red(v):
    return rock(v, tint=(0.62, 0.38, 0.28))


def water_deep(v, murky=False):
    a = _new()
    if murky:
        base, deep, glint = '#2a4a46', '#14292a', '#8fd0c4'
    else:
        base, deep, glint = '#1c4f78', '#0a2540', '#9fe3ff'
    n = fbm(a.H, a.W, 18 * a.ss, 150 + v, 3, True)
    a.rgb[:] = (col(deep)[None, None, :] * (1 - n[..., None]) + col(base)[None, None, :] * n[..., None])
    a.a[:] = 1
    yy = np.arange(a.H)[:, None] / a.ss
    xx = np.arange(a.W)[None, :] / a.ss
    w1 = fbm(a.H, a.W, 9 * a.ss, 151 + v, 2, True)
    w2 = fbm(a.H, a.W, 5 * a.ss, 152 + v, 2, True)
    # caustic ridges: thin bright lines where two fields cross
    ridge = np.exp(-((w1 - 0.5) / 0.035) ** 2) * 0.85 + np.exp(-((w2 - 0.5) / 0.03) ** 2) * 0.5
    a.rgb = np.clip(a.rgb + ridge[..., None] * col(glint)[None, None, :] * 0.45, 0, 1)
    # dark troughs
    tr = np.exp(-((w1 - 0.30) / 0.05) ** 2)
    a.rgb *= (1 - 0.25 * tr)[..., None]
    _specks(a, 1500 + v, 0.0016, '#ffffff', 0.5, 1.0, 1)
    if murky:
        _blot(a, 1550 + v, '#33573a', 14, 0.66, 0.5)
    return a.image()


# ------------------------------------------------------------------------------------------------ sprites with transparency
def _on(ground_fn, v, draw):
    """draw an object on a ground tile"""
    img = ground_fn(v)
    a = Art(64, 64, 4)
    draw(a)
    over = a.image(outline=0.85)
    img.alpha_composite(over)
    return img


def sprite_overlay(draw, ss=4, outline=0.85):
    a = Art(64, 64, ss)
    draw(a)
    return a.image(outline=outline)


def tree(v):
    def draw(a):
        rng = np.random.default_rng(1600 + v)
        # soft canopy shadow on the ground
        sh = a.ellipse(34, 36, 27, 25)
        a.shadow(sh, 3, 4, 5, 0.5)
        greens = [('#2d5a27', '#1d3d1b'), ('#3f7a30', '#295a24'), ('#528f3a', '#35692b')]
        # layered leaf clumps back to front
        for layer in range(3):
            for i in range(11 - layer * 2):
                ang = rng.uniform(0, 6.283)
                rr = rng.uniform(4, 20 - layer * 5)
                cx = 32 + np.cos(ang) * rr
                cy = 31 + np.sin(ang) * rr
                r = rng.uniform(6, 10) - layer * 1.2
                m = a.ellipse(cx, cy, r, r * 0.92)
                c = greens[layer][0] if rng.random() < 0.7 else greens[layer][1]
                a.shade(m, c, bevel=r * 0.8, strength=0.85, grain=0.25, seed=int(cx * 3 + cy), rough=1.4)
        # highlight leaves
        for i in range(24):
            ang = rng.uniform(0, 6.283)
            rr = rng.uniform(0, 17)
            cx = 30 + np.cos(ang) * rr
            cy = 29 + np.sin(ang) * rr
            a.fill(a.ellipse(cx, cy, rng.uniform(1.0, 2.2)), '#9ccd6a', 0.8)
    return sprite_overlay(draw, 4, 0.0)


def manhole(v):
    def draw(a):
        a.shadow(a.ellipse(32, 32, 22), 0, 1, 2, 0.5)
        m = a.ellipse(32, 32, 22)
        a.shade(m, '#3b3f45', bevel=3, strength=0.8, grain=0.3, spec=0.2)
        a.fill(a.ellipse(32, 32, 19.5), '#262a2f')
        a.shade(a.ellipse(32, 32, 18.5), '#4a4f56', bevel=2, strength=0.7, grain=0.2)
        # raised lattice
        for k in range(-3, 4):
            a.fill(a.line(32 + k * 5, 14, 32 + k * 5, 50, 1.4), '#2c3036', 0.9)
            a.fill(a.line(14, 32 + k * 5, 50, 32 + k * 5, 1.4), '#2c3036', 0.9)
        a.fill(a.line(20, 20, 44, 44, 1.2), '#7a8089', 0.6)
        a.fill(a.ellipse(32, 32, 4.5), '#2a2d32')
        a.shade(a.ellipse(32, 32, 3.8), '#555b63', bevel=1.5)
        a.fill(a.ellipse(32, 32, 1.4), '#15171a')
    return sprite_overlay(draw, 4, 0.6)


def hazard_stripe(a, x, y, w, h, ang=1):
    pass


def crate(v):
    def draw(a):
        a.shadow(a.rrect(7, 7, 50, 50, 2), 2, 3, 3, 0.5)
        body = a.rrect(6, 6, 52, 52, 2.5)
        a.shade(body, '#7b5c3a' if v == 0 else '#5f6e4c', bevel=4, strength=0.8, grain=0.4, rough=1.2, seed=5 + v)
        # lid planks
        for i in range(1, 5):
            a.fill(a.rect(8, 6 + i * 10.4, 48, 0.9), '#2e2013' if v == 0 else '#2b3322', 0.85)
        # edge battens and cross brace
        for r in (a.rect(6, 6, 6, 52), a.rect(52, 6, 6, 52), a.rect(6, 6, 52, 6), a.rect(6, 52, 52, 6)):
            a.shade(r, '#8d6c45' if v == 0 else '#738558', bevel=2, strength=0.8, grain=0.3, seed=11)
        a.fill(a.line(11, 11, 53, 53, 5), '#6d4f31' if v == 0 else '#586747', 1)
        a.stroke(a.line(11, 11, 53, 53, 5), '#2e2013', 0.8, 0.7)
        # stencil + nails
        for (x, y) in ((9, 9), (55, 9), (9, 55), (55, 55)):
            a.fill(a.ellipse(x, y, 1.1), '#bfb8a8')
        a.fill(a.rect(24, 28, 16, 3), '#d9c44a' if v == 0 else '#e8e8e8', 0.7)
    return sprite_overlay(draw, 4, 0.8)


def dumpster(v):
    def draw(a):
        a.shadow(a.rrect(5, 9, 54, 46, 3), 2, 3, 3, 0.5)
        body = a.rrect(5, 9, 54, 46, 3)
        a.shade(body, '#2f5b49' if v == 0 else '#3a4f78', bevel=4, strength=0.9, grain=0.2, spec=0.25)
        # lids: two hinged halves with ribs
        for (x0, x1) in ((7, 32), (33, 57)):
            lid = a.rrect(x0, 11, x1 - x0, 42, 2)
            a.shade(lid, '#33664f' if v == 0 else '#44598a', bevel=2.5, strength=0.9, grain=0.15)
            for k in range(5):
                a.fill(a.rect(x0 + 1.5, 15 + k * 8, x1 - x0 - 3, 1.1), '#1c3a2e' if v == 0 else '#27375a', 0.9)
            a.shade(a.rrect((x0 + x1) / 2 - 3, 8, 6, 3, 1.2), '#1a1d21', bevel=1)
        # rust and grime streaks, a lock
        a.speckle(body, '#6d4a2a', 25, 12 + v, 1.0, 0.6)
        a.fill(a.rect(31, 11, 2, 42), '#122219' if v == 0 else '#16213a', 0.9)
    return sprite_overlay(draw, 4, 0.8)


def planter(v):
    def draw(a):
        a.shadow(a.rrect(6, 6, 52, 52, 4), 2, 3, 3, 0.5)
        rim = a.rrect(6, 6, 52, 52, 4)
        a.shade(rim, '#9b9ea3', bevel=4, strength=0.85, grain=0.3)
        soil = a.rrect(13, 13, 38, 38, 3)
        a.shade(soil, '#3a2a1e', bevel=3, strength=0.5, grain=0.5, rough=1.2)
        rng = np.random.default_rng(1700 + v)
        # shrubs
        for i in range(10):
            ang = rng.uniform(0, 6.28)
            rr = rng.uniform(0, 12)
            cx, cy = 32 + np.cos(ang) * rr, 32 + np.sin(ang) * rr
            r = rng.uniform(4, 7)
            a.shade(a.ellipse(cx, cy, r), ['#3c7a3a', '#2f6a30', '#4f9444'][rng.integers(3)], bevel=r * 0.8, strength=0.85, grain=0.3, rough=1.4)
        for i in range(6):
            cx, cy = rng.uniform(18, 46), rng.uniform(18, 46)
            c = ['#e8527a', '#f2d24a', '#f6f1e6', '#b97be8'][(i + v) % 4]
            a.fill(a.ellipse(cx, cy, 1.5), c)
            a.fill(a.ellipse(cx, cy, 0.6), '#f6e09a')
    return sprite_overlay(draw, 4, 0.8)


def stairs(v):
    a = Art(64, 64, 4)
    base = a.rect(0, 0, 64, 64)
    a.shade(base, '#6a6d72', bevel=2, strength=0.4, grain=0.25, flat=True)
    # five treads, each a lit step edge, getting brighter towards the top
    for i in range(6):
        y0 = 4 + i * 10
        m = a.rect(3, y0, 58, 9)
        a.shade(m, '#8f9298' if i % 2 else '#858890', bevel=1.8, strength=0.9, grain=0.2)
        a.fill(a.rect(3, y0 + 7.4, 58, 1.6), '#34363b', 0.9)
        a.fill(a.rect(3, y0, 58, 1.0), '#c6c9ce', 0.6)
    # safety nosing + side rails
    for x in (0, 59):
        a.shade(a.rect(x, 0, 5, 64), '#4a4d53', bevel=1.2, strength=0.9)
    # up arrow
    a.fill(a.poly([(32, 8), (42, 22), (36, 22), (36, 36), (28, 36), (28, 22), (22, 22)]), '#5be0ff', 0.9)
    a.glow(32, 22, 18, '#2ab6e0', 0.35)
    return a.image()


def elevator(v):
    a = Art(64, 64, 4)
    a.shade(a.rect(0, 0, 64, 64), '#4a4f58', bevel=2, strength=0.5, grain=0.2)
    # two sliding doors
    for (x0, x1) in ((6, 31), (33, 58)):
        m = a.rect(x0, 8, x1 - x0, 48)
        a.shade(m, '#aab2bd', bevel=2, strength=0.8, grain=0.15, spec=0.4)
        for k in range(4):
            a.fill(a.rect(x0 + 1.5, 12 + k * 11, x1 - x0 - 3, 0.9), '#6a727c', 0.8)
    a.fill(a.rect(31, 8, 2, 48), '#1a1d22')
    # call button and floor indicator
    a.shade(a.rrect(2, 28, 3.6, 8, 1), '#262a30', bevel=1)
    a.fill(a.ellipse(3.8, 31, 0.9), '#5be0ff')
    a.fill(a.ellipse(3.8, 34, 0.9), '#ff4d6d')
    a.shade(a.rrect(22, 2, 20, 5, 1), '#101216', bevel=1)
    a.fill(a.poly([(30, 5.8), (32, 3), (34, 5.8)]), '#5be0ff')
    a.glow(32, 4.5, 8, '#2ab6e0', 0.3)
    return a.image()


def ladder(v):
    a = Art(64, 64, 4)
    a.shade(a.rect(0, 0, 64, 64), '#1a1c20', bevel=1, strength=0.3, flat=True)
    a.fill(a.rect(8, 8, 48, 48), '#050607')
    a.shade(a.rect(5, 5, 54, 3.5), '#6b727b', bevel=1.3)
    a.shade(a.rect(5, 55.5, 54, 3.5), '#6b727b', bevel=1.3)
    a.shade(a.rect(5, 5, 3.5, 54), '#6b727b', bevel=1.3)
    a.shade(a.rect(55.5, 5, 3.5, 54), '#6b727b', bevel=1.3)
    for x in (20, 44):
        a.shade(a.rect(x - 2, 6, 4, 52), '#9aa2ad', bevel=1.6, strength=0.9, spec=0.4)
    for k in range(7):
        a.shade(a.rect(20, 11 + k * 7, 24, 2.6), '#c0c7d0', bevel=1.1, strength=0.9)
    a.fill(a.poly([(32, 3), (35, 8), (29, 8)]), '#f6c52b')
    return a.image()


def door_closed(v, vertical=False, locked=False):
    """a door in a wall, closed; `vertical` = the wall runs up and down"""
    a = Art(64, 64, 4)
    # frame across the full tile, door panel in the middle
    if vertical:
        frame = a.rect(18, 0, 28, 64)
    else:
        frame = a.rect(0, 18, 64, 28)
    a.shade(frame, '#2c3036', bevel=2, strength=0.8, grain=0.2)
    if vertical:
        panel = a.rect(22, 4, 20, 56)
    else:
        panel = a.rect(4, 22, 56, 20)
    c = '#71353b' if locked else '#8d98a6'
    a.shade(panel, c, bevel=2.2, strength=0.85, grain=0.2, spec=0.3)
    # ribs
    for k in range(5):
        if vertical:
            a.fill(a.rect(23.5, 9 + k * 10, 17, 1.0), '#3b2226' if locked else '#5a636f', 0.9)
        else:
            a.fill(a.rect(9 + k * 10, 23.5, 1.0, 17), '#3b2226' if locked else '#5a636f', 0.9)
    # handle / keypad
    if vertical:
        hx_, hy_ = 38, 32
    else:
        hx_, hy_ = 32, 38
    if locked:
        a.shade(a.rrect(hx_ - 3, hy_ - 5 if not vertical else hy_ - 3, 7, 10 if not vertical else 7, 1.2), '#16181b', bevel=1)
        a.fill(a.ellipse(hx_, hy_ - 2 if not vertical else hy_, 1.2), '#ff3b52')
        a.glow(hx_, hy_, 7, '#ff3b52', 0.3)
    else:
        a.shade(a.rrect(hx_ - 2, hy_ - 2, 4, 4, 1.2), '#e3e7ec', bevel=1, spec=0.4)
        a.fill(a.ellipse(hx_ + 5 if not vertical else hx_, hy_ - 12 if vertical else hy_ - 15, 1.0), '#5be0ff')
    return a.image()


def sprite_light(draw, ss=4):
    a = Art(64, 64, ss)
    draw(a)
    return a.image()


# ------------------------------------------------------------------------------------------------ autotiling walls
def wall(mask, v=0, glass=False, ground=None):
    """a wall tile from a 4-bit neighbour mask: 1=N 2=E 4=S 8=W.  The wall is a 34px thick bar through the cell centre."""
    a = Art(64, 64, 4)
    T = 20          # half-thickness*... bar occupies [32-T/2, 32+T/2]
    th = 24
    lo, hi = 32 - th / 2, 32 + th / 2
    parts = [a.rect(lo, lo, th, th)]
    if mask & 1:
        parts.append(a.rect(lo, 0, th, lo + 1))
    if mask & 4:
        parts.append(a.rect(lo, hi - 1, th, 64 - hi + 1))
    if mask & 2:
        parts.append(a.rect(hi - 1, lo, 64 - hi + 1, th))
    if mask & 8:
        parts.append(a.rect(0, lo, lo + 1, th))
    if mask == 0:
        parts = [a.rrect(lo - 2, lo - 2, th + 4, th + 4, 3)]
    m = parts[0]
    for p in parts[1:]:
        m = m | p
    a.shadow(m, 2, 3, 3, 0.55)
    if glass:
        a.shade(m, '#202a33', bevel=2.5, strength=0.7, grain=0.1)
        # a glass strip along each arm
        strip = None
        gparts = []
        gl = 32 - 5
        gparts.append(a.rect(gl, gl, 10, 10))
        if mask & 1:
            gparts.append(a.rect(gl, 0, 10, gl + 1))
        if mask & 4:
            gparts.append(a.rect(gl, 32, 10, 33))
        if mask & 2:
            gparts.append(a.rect(32, gl, 33, 10))
        if mask & 8:
            gparts.append(a.rect(0, gl, gl + 11, 10))
        g = gparts[0]
        for p in gparts[1:]:
            g = g | p
        a.shade(g, '#6fb7d4', bevel=1.8, strength=0.55, grain=0.05, spec=0.5, grad='v', base2='#2f6f93')
        # reflections: diagonal glints
        yy, xx = a.yy, a.xx
        glint = np.exp(-(((xx + yy * 0.6) % 22) - 3) ** 2 / 3.0) * g
        a.rgb = np.clip(a.rgb + glint[..., None] * 0.35, 0, 1)
    else:
        a.shade(m, '#8c9098', bevel=4.0, strength=0.95, grain=0.3, rough=1.3, seed=3 + mask, spec=0.15)
        # inner panel recess + seams so it reads as a built wall top, not a block
        inner = m & ~__import__('scipy.ndimage', fromlist=['x']).binary_erosion(m, iterations=int(5.5 * a.ss))
        inner = __import__('scipy.ndimage', fromlist=['x']).binary_erosion(m, iterations=int(5.5 * a.ss))
        a.fill(inner, '#6f737b', 1.0)
        a.shade(inner, '#777b83', bevel=2.0, strength=0.5, grain=0.4, rough=1.2, seed=9 + mask)
        # utility seams every ~16px along arms
        for k in (16, 48):
            if mask & 1 or mask & 4:
                a.fill(a.rect(lo + 3, k, th - 6, 0.9) & inner, '#484b51', 0.8)
            if mask & 2 or mask & 8:
                a.fill(a.rect(k, lo + 3, 0.9, th - 6) & inner, '#484b51', 0.8)
        # tiny rivets on the cap edge
        rng = np.random.default_rng(3000 + mask + v)
        for i in range(10):
            x, y = rng.uniform(8, 56), rng.uniform(8, 56)
            if m[int(y * a.ss), int(x * a.ss)] and not inner[int(y * a.ss), int(x * a.ss)]:
                a.fill(a.ellipse(x, y, 0.8), '#5a5d63')
        # a thin neon accent line along the top edge on the north-facing side
        if not (mask & 1):
            a.fill(a.rect(lo + 1.5, lo + 0.8, th - 3, 1.0), '#35d7ff', 0.55)
    return a.image(outline=0.8)


def roof(v):
    """flat metal roof: seamed panels with vents and tar patches"""
    a = _new()
    _tex(a, '#6a6e75', 0.88, 1.1, 12, 160 + v, 3)
    s = a.ss
    for i in range(0, 64, 16):
        a.rgb[:, i * s:(i + 1) * s] *= 0.62        # standing seams
        a.rgb[:, (i + 1) * s:(i + 2) * s] *= 1.18
    _blot(a, 1600 + v, '#2c2f33', 14, 0.7, 0.6, 0.05)
    _specks(a, 1610 + v, 0.01, '#3b3e43', 0.2, 0.7)
    if v == 1:
        pass
    return a.image()


def track(v, vertical=False):
    """railway on ballast: sleepers and two shining rails"""
    a = Art(64, 64, 4, wrap=True)
    g = gravel(0)
    base = Art(64, 64, 4)
    # ballast comes from the gravel tile
    sprite = []

    def draw(a):
        pass
    import PIL.Image as PI
    img = g.copy()
    top = Art(64, 64, 4)
    rng = np.random.default_rng(1800 + v)
    # sleepers
    for k in range(4):
        x0 = k * 16 + 2
        if vertical:
            m = top.rect(6, x0, 52, 8)
        else:
            m = top.rect(x0, 6, 8, 52)
        top.shadow(m, 1.5, 2, 1.5, 0.5)
    for k in range(4):
        x0 = k * 16 + 2
        m = top.rect(6, x0, 52, 8) if vertical else top.rect(x0, 6, 8, 52)
        top.shade(m, '#5b4430', bevel=2.2, strength=0.8, grain=0.5, rough=1.1, seed=k + 5)
    # rails
    for r in (19, 45):
        m = top.rect(r - 2.2, 0, 4.4, 64) if vertical else top.rect(0, r - 2.2, 64, 4.4)
        top.shade(m, '#aab0b8', bevel=1.8, strength=0.95, spec=0.55)
        # chair plates at the sleepers
        for k in range(4):
            x0 = k * 16 + 6
            pm = top.rect(r - 3.4, x0 - 1.5, 6.8, 5) if vertical else top.rect(x0 - 1.5, r - 3.4, 5, 6.8)
            top.shade(pm, '#3b3f45', bevel=1.0, strength=0.8)
    out = top.image(outline=0.0)
    img.alpha_composite(out)
    return img


def glass_railing(v):
    def draw(a):
        # four posts and a glass frame
        a.shadow(a.rect(4, 4, 56, 56), 1.5, 2.5, 2, 0.35)
        pane = a.rect(6, 6, 52, 52)
        a.fill(pane, '#8fd4ee', 0.22)
        a.stroke(pane, '#cdeefa', 1.0, 0.7)
        a.fill(a.line(6, 6, 58, 58, 0.8), '#ffffff', 0.12)
        for (x, y) in ((6, 6), (58, 6), (6, 58), (58, 58)):
            m = a.ellipse(x, y, 3.2)
            a.shade(m, '#7e8791', bevel=2.2, strength=0.9, spec=0.4)
        a.shade(a.rect(6, 5, 52, 2.6), '#aab3be', bevel=1.1, strength=0.9)
        a.shade(a.rect(6, 56.4, 52, 2.6), '#aab3be', bevel=1.1, strength=0.9)
    return sprite_overlay(draw, 4, 0.5)


def _under(ground, fn_over):
    g = ground.copy()
    g.alpha_composite(fn_over)
    return g


def terrain_sprites():
    """-> (list of (sprite id, image), variants dict).  Variant k of id X is stored as 'X.k'."""
    out = []
    variants = {}

    def many(id_, fn, n):
        variants[id_] = n
        for k in range(n):
            out.append((id_ + '.' + str(k), fn(k)))
        out.append((id_, fn(0)))

    many('t_sidewalk', sidewalk, 4)
    many('t_pavement', road, 6)
    many('t_concrete', concrete, 2)
    many('t_floor', floor_tile, 3)
    many('t_metal_floor', metal_floor, 2)
    many('t_floor_metal_gangway', grating, 1)
    many('t_metal_flat_roof', roof, 2)
    many('t_trl_gravel', gravel, 3)
    many('t_grass', grass, 6)
    many('t_grass_grazed', grass_grazed, 3)
    many('t_sand', sand, 3)
    many('t_rock_floor', rock_floor, 3)
    many('t_rock', rock, 3)
    many('t_rock_red', rock_red, 3)
    many('t_water_dp', water_deep, 4)
    many('t_water_sh_murky_underground', lambda k: water_deep(k, True), 3)
    out.append(('t_stairs_up', stairs(0)))
    out.append(('t_elevator', elevator(0)))
    out.append(('t_ladder_up_down', ladder(0)))
    for locked, id_ in ((False, 't_door_c'), (True, 't_door_metal_locked')):
        out.append((id_, door_closed(0, False, locked)))
        out.append((id_ + '.v', door_closed(0, True, locked)))
    out.append(('t_railroad_tie', track(0, False)))
    out.append(('t_railroad_tie.v', track(0, True)))
    road0 = road(2)
    out.append(('t_manhole_cover', _under(road0, manhole(0))))
    side0 = sidewalk(1)
    for k, (id_, fn) in enumerate((('f_crate_c', crate), ('f_dumpster', dumpster), ('f_planter', planter))):
        out.append((id_, _under(side0, fn(0))))
    out.append(('f_crate_c.1', _under(side0, crate(1))))
    out.append(('f_dumpster.1', _under(side0, dumpster(1))))
    out.append(('t_glass_railing', glass_railing(0)))
    out.append(('t_tree', tree(0)))
    out.append(('t_tree.1', tree(1)))
    out.append(('t_tree.2', tree(2)))
    variants['t_tree'] = 3
    for m in range(16):
        out.append(('t_wall.%d' % m, wall(m)))
        out.append(('t_wall_glass.%d' % m, wall(m, glass=True)))
    out.append(('t_wall', wall(0)))
    out.append(('t_wall_glass', wall(0, glass=True)))
    return out, variants
