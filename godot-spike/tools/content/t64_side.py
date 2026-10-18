"""Side-view paper doll, version 2: realistic proportions (about 7 heads) in the shaded, gritty style of the reference the
designer supplied.  One body, three stances.  Every layer is a 64x64 image of the figure facing RIGHT (the game mirrors it).

A Rig is a set of joints (head, neck, shoulders, elbows, hands, hips, knees, ankles, toes) for one stance.  The body, clothes, armor
and held items are all built from the same joints, so anything lines up in every stance.  Held items attach to the two hand points:
the line far hand -> near hand is the item's axis (barrel, blade, haft).

Layer order (back to front): shadow, arm_far, leg_far, torso+leg_near+head, underwear, hair, armor 'under', held, arm_near,
hands, armor 'over'.   Skin and hair layers are grey and are multiplied by the skin / hair colour.
Styles: 'bouma' (full colour, shaded, dirty) and 'moku' (three inks: ink, paper, neon; flat fills, hatching)."""
import math
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from art64 import Art, col

W = 64
STYLES = {
    'bouma': dict(ink='#14141c', paper='#d9d6cf', neon='#19e0d0', skin='#d2d2d2', hair='#8c8c8c'),
    'moku': dict(ink='#0d0d12', paper='#f1eee4', neon='#ff2f7d', skin='#f1eee4', hair='#0d0d12'),
}
SKINS = {          # five tones, multiplied over the grey skin layer
    'pale': (1.00, 0.84, 0.74), 'tan_white': (0.97, 0.76, 0.58), 'tanned': (0.86, 0.62, 0.42),
    'dark': (0.60, 0.40, 0.27), 'near_black': (0.30, 0.20, 0.15),
}

# ---------------------------------------------------------------------------------------------- stances
# all points are (x, y) in the 64x64 tile, feet at y=61, facing right
STANCES = {
    'ready': dict(label='Ready',             # upright, weight forward, both hands up front
                  head=(34.0, 8.2), neck=(33.2, 12.4), sh_n=(33.0, 15.0), sh_f=(31.6, 15.2), hip=(30.0, 34.0),
                  el_n=(36.5, 22.0), hand_n=(45.0, 22.6), el_f=(33.0, 23.0), hand_f=(39.5, 24.6),
                  hn=(32.5, 34.5), kn_n=(37.0, 46.0), an_n=(35.5, 57.2), toe_n=(42.5, 60.8),
                  hf=(29.0, 34.5), kn_f=(26.0, 46.5), an_f=(22.0, 57.0), toe_f=(28.5, 60.8)),
    'guard': dict(label='Guard',             # wide braced stance, weapon held across the body, rear hand high
                  head=(36.0, 10.0), neck=(34.8, 14.2), sh_n=(34.2, 16.8), sh_f=(32.6, 17.0), hip=(29.5, 35.0),
                  el_n=(40.0, 23.0), hand_n=(47.5, 18.0), el_f=(34.5, 25.5), hand_f=(40.0, 21.0),
                  hn=(32.5, 35.5), kn_n=(40.0, 46.5), an_n=(40.0, 57.4), toe_n=(47.0, 60.8),
                  hf=(27.5, 35.5), kn_f=(22.5, 47.0), an_f=(17.5, 57.0), toe_f=(24.0, 60.8)),
    'crouch': dict(label='Crouch',           # low, knees deep, hunched behind the weapon
                   head=(37.5, 17.0), neck=(35.6, 20.8), sh_n=(34.0, 22.6), sh_f=(32.4, 22.8), hip=(26.5, 40.0),
                   el_n=(38.0, 29.0), hand_n=(46.0, 28.4), el_f=(34.0, 31.0), hand_f=(40.5, 29.8),
                   hn=(28.5, 40.5), kn_n=(38.5, 46.5), an_n=(34.0, 57.6), toe_n=(41.5, 60.8),
                   hf=(25.0, 40.5), kn_f=(31.0, 51.5), an_f=(22.0, 57.6), toe_f=(26.0, 60.8)),
}


def new():
    return Art(W, W, 4)


def pal(style):
    return {k: col(v) for k, v in STYLES[style].items()}


# ---------------------------------------------------------------------------------------------- geometry
def chain(a, pts, ws):
    m = None
    for i in range(len(pts) - 1):
        s = a.line(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], (ws[i] + ws[i + 1]) / 2.0)
        m = s if m is None else (m | s)
    return m


def torso_poly(r, grow=0.0):
    """ribcage, waist and pelvis from the shoulder-hip axis, with chest forward and glutes back"""
    sx, sy = (r['sh_n'][0] + r['sh_f'][0]) / 2, (r['sh_n'][1] + r['sh_f'][1]) / 2
    hx, hy = r['hip']
    ax, ay = hx - sx, hy - sy
    ln = math.hypot(ax, ay)
    ax, ay = ax / ln, ay / ln
    px, py = ay * -1, ax          # perpendicular, pointing to +x (front) when the axis points down
    if px < 0:
        px, py = -px, -py
    prof = [(-0.04, 2.6, 3.0), (0.08, 4.4, 4.2), (0.30, 4.6, 4.0), (0.58, 3.5, 3.1), (0.82, 3.8, 4.4), (1.0, 3.7, 4.9)]
    front, back = [], []
    for t, f, b in prof:
        cx, cy = sx + ax * ln * t, sy + ay * ln * t
        front.append((cx + px * (f + grow), cy + py * (f + grow)))
        back.append((cx - px * (b + grow), cy - py * (b + grow)))
    return front + back[::-1]


def rig_masks(r):
    a = new()
    M = {}
    M['torso'] = a.poly(torso_poly(r))
    M['leg_n'] = chain(a, [r['hn'], r['kn_n'], r['an_n']], (7.0, 5.0, 3.4)) | a.ellipse(
        (r['kn_n'][0] + r['an_n'][0]) / 2 - 0.6, (r['kn_n'][1] + r['an_n'][1]) / 2 - 1.4, 2.7, 4.6)
    M['leg_f'] = chain(a, [r['hf'], r['kn_f'], r['an_f']], (7.0, 5.0, 3.4)) | a.ellipse(
        (r['kn_f'][0] + r['an_f'][0]) / 2 - 0.6, (r['kn_f'][1] + r['an_f'][1]) / 2 - 1.4, 2.6, 4.4)
    for s in ('n', 'f'):
        ax_, ay_ = r['an_' + s]
        tx, ty = r['toe_' + s]
        M['foot_' + s] = a.poly([(ax_ - 2.6, ay_ - 1.8), (ax_ + 2.0, ay_ - 2.0), (tx - 2.0, ty - 3.0), (tx + 1.4, ty - 1.2), (tx + 1.4, ty + 0.5),
                                 (ax_ - 3.6, ty + 0.5)])
    M['arm_n'] = chain(a, [r['sh_n'], r['el_n'], r['hand_n']], (4.6, 3.8, 2.8))
    M['arm_f'] = chain(a, [r['sh_f'], r['el_f'], r['hand_f']], (4.4, 3.6, 2.7))
    M['hand_n'] = a.ellipse(r['hand_n'][0] + 0.4, r['hand_n'][1], 2.3, 2.0)
    M['hand_f'] = a.ellipse(r['hand_f'][0] + 0.4, r['hand_f'][1], 2.2, 1.9)
    hx_, hy_ = r['head']
    M['head'] = a.ellipse(hx_, hy_ - 0.4, 3.9, 4.2) | a.poly(
        [(hx_ - 1.5, hy_ + 1.5), (hx_ + 3.2, hy_ + 1.0), (hx_ + 3.0, hy_ + 3.6), (hx_ + 1.0, hy_ + 4.6), (hx_ - 2.0, hy_ + 3.6)])
    M['neck'] = chain(a, [(r['neck'][0] - 0.2, r['neck'][1] - 1.0), (r['neck'][0] - 0.6, r['neck'][1] + 3.0)], (3.8, 4.2))
    M['nose'] = a.tri((hx_ + 3.3, hy_ - 0.6), (hx_ + 5.0, hy_ + 1.6), (hx_ + 3.0, hy_ + 1.9))
    return M


# ---------------------------------------------------------------------------------------------- painting
def paint(a, mask, base, style, seed, bevel=1.8, strength=0.36, grain=0.08, hatch=True):
    if mask is None or not mask.any():
        return
    if style == 'moku':
        a.shade(mask, base, bevel=bevel, flat=True)
        if hatch:
            sh = mask & ~np.roll(np.roll(mask, -2 * a.ss, 0), -2 * a.ss, 1)
            sh = sh | (mask & ~np.roll(mask, -2 * a.ss, 0))
            pat = (((a.xx + a.yy) * 1.0) % 2.0) < 1.0
            a.fill(sh & pat & mask, STYLES['moku']['ink'], 1.0)
    else:
        a.shade(mask, base, bevel=bevel, strength=strength, grain=grain, seed=seed)


def finish(a, style):
    if style == 'moku':
        return a.image(outline=1.0, outline_col=col(STYLES['moku']['ink']))
    return a.image(outline=0.85)


def mul(c, k, style):
    return c * k if style == 'bouma' else c


def shadow_layer(style):
    a = new()
    if style == 'moku':
        m = a.ellipse(33, 61.6, 16, 1.6)
        a.fill(m & (((a.xx * 2) % 2) < 1.0), STYLES['moku']['ink'])
        return a.image()
    m = a.ellipse(33, 61.5, 17, 2.4)
    k = ndi.gaussian_filter(m.astype(np.float32), 3.0) * 0.5
    a.rgb[:] = 0
    a.a[:] = k
    return a.image()


def skin_cap(a, M, r, p, style, seed):
    """the bare body (skin)"""
    sk = p['skin']
    paint(a, M['leg_f'] | M['foot_f'], mul(sk, 0.78, style), style, seed)
    paint(a, M['leg_n'] | M['foot_n'], mul(sk, 0.95, style), style, seed + 1)
    paint(a, M['neck'], mul(sk, 0.9, style), style, seed + 2, bevel=1.2)
    paint(a, M['torso'], sk, style, seed + 3, bevel=2.6)
    paint(a, M['head'], sk, style, seed + 4, bevel=2.2)
    paint(a, M['nose'], sk, style, seed + 5, bevel=0.7, hatch=False)
    hx_, hy_ = r['head']
    ink = p['ink']
    a.fill(a.ellipse(hx_ + 2.3, hy_ - 0.2, 0.65, 0.5), ink)                                  # eye
    a.fill(a.line(hx_ + 1.4, hy_ - 1.5, hx_ + 3.4, hy_ - 1.2, 0.5), ink, 0.9)                # brow
    a.fill(a.line(hx_ + 1.6, hy_ + 2.5, hx_ + 3.1, hy_ + 2.4, 0.4), ink, 0.75)               # mouth


def layer_arm_far(r, M, style, p):
    a = new()
    paint(a, M['arm_f'], mul(p['skin'], 0.74, style), style, 1, bevel=1.6)
    return finish(a, style)


def layer_body(r, M, style, p, seed=3):
    a = new()
    skin_cap(a, M, r, p, style, seed)
    # basic underwear: boxer shorts and a thin sleeveless undershirt
    u = col('#4b5a78') if style == 'bouma' else p['neon']
    t = M['torso']
    hy = r['hip'][1]
    shorts = (t & a.rect(0, hy - 3.2, W, 9)) | ((M['leg_n'] | M['leg_f']) & a.rect(0, hy - 3.2, W, 9.5))
    paint(a, shorts & (t | M['leg_n'] | M['leg_f']), u, style, seed + 6, bevel=1.4, hatch=False)
    a.fill(a.rect(0, hy - 3.3, W, 0.9) & t, '#22202b' if style == 'bouma' else p['ink'], 0.9)
    ut = col('#8b8f98') if style == 'bouma' else p['paper']
    sx, sy = r['sh_n']
    shirt = t & a.rect(0, sy - 2.6, W, hy - sy - 1.4)
    paint(a, shirt, ut, style, seed + 7, bevel=1.6, hatch=False)
    if style == 'bouma':
        a.speckle(shirt | shorts, '#2b2823', 3.2, seed + 8, 1.2, 0.5)
        a.fill(a.line(sx - 0.5, sy - 2.2, sx + 3.0, sy - 2.0, 0.7), '#2b2823', 0.7)
    return finish(a, style)


def layer_hair(r, style, p, seed=5):
    a = new()
    hx_, hy_ = r['head']
    hc = p['hair'] if style == 'bouma' else p['ink']
    cap = a.ellipse(hx_ - 0.5, hy_ - 1.2, 4.5, 4.7) & a.rect(0, 0, W, hy_ - 1.3)
    side = a.ellipse(hx_ - 2.4, hy_ + 0.4, 2.0, 3.0)
    nape = a.poly([(hx_ - 4.2, hy_ - 1.0), (hx_ - 1.2, hy_ - 1.2), (hx_ - 1.4, hy_ + 3.0), (hx_ - 3.6, hy_ + 2.4)])
    paint(a, cap | side | nape, hc, style, seed, bevel=1.4, hatch=False)
    return finish(a, style)


def layer_arm_near(r, M, style, p, seed=11):
    a = new()
    paint(a, M['arm_n'], p['skin'], style, seed, bevel=1.7)
    return finish(a, style)


def layer_hands(r, M, style, p, seed=12):
    a = new()
    paint(a, M['hand_f'], mul(p['skin'], 0.9, style), style, seed, bevel=1.0, hatch=False)
    paint(a, M['hand_n'], mul(p['skin'], 0.98, style), style, seed + 1, bevel=1.0, hatch=False)
    return finish(a, style)


# ---------------------------------------------------------------------------------------------- armor
ARMOR = {
    'A1': dict(label='Plasteel plate', bouma=('#7d8ba0', '#38414f', '#e8782a')),
    'A2': dict(label='Riot shell', bouma=('#555c76', '#232735', '#e0405a')),
    'A3': dict(label='Weave and plates', bouma=('#868260', '#44412f', '#27d2c4')),
}


def armor_layers(key, r, M, style, p, seed=21):
    main, dark, acc = (col(c) for c in ARMOR[key]['bouma'])
    if style == 'moku':
        main, dark, acc = p['paper'], p['ink'], p['neon']
    u, o = new(), new()
    hx_, hy_ = r['head']
    t = M['torso']
    sy = r['sh_n'][1]
    hy = r['hip'][1]
    tp = Art(W, W, 4)
    chest = Art(W, W, 4).poly(torso_poly(r, 0.9))
    plate = chest & u.rect(0, sy - 2.4, W, (hy - sy) * 0.78)
    paint(u, plate, main, style, seed, bevel=2.4, strength=0.5)
    # plate seams and a front panel
    for k in (0.28, 0.55):
        yy = sy - 2.4 + (hy - sy) * 0.78 * k
        u.fill(u.rect(0, yy, W, 0.7) & plate, dark)
    cx = (r['sh_n'][0] + r['hip'][0]) / 2 + 1.2
    u.fill(u.rect(cx, sy, 1.0, (hy - sy) * 0.7) & plate, acc)
    # belt and tassets
    belt = chest & u.rect(0, hy - 4.6, W, 2.0)
    paint(u, belt, dark, style, seed + 1, bevel=0.9, hatch=False)
    # shoulder pauldron
    paint(u, u.ellipse(r['sh_n'][0] - 0.4, r['sh_n'][1] + 0.2, 4.8, 4.2), main * 1.06 if style == 'bouma' else main, style, seed + 2, bevel=2.0, strength=0.5)
    # helmet and visor slit
    sk = u.ellipse(hx_ - 0.3, hy_ - 0.9, 5.2, 5.3) & u.rect(0, 0, W, hy_ + 1.8)
    paint(u, sk, main, style, seed + 3, bevel=2.0, strength=0.5)
    u.fill(u.rect(hx_ + 0.2, hy_ - 1.5, 5.4, 1.7) & u.ellipse(hx_ + 0.4, hy_, 5.0, 4.6), acc)
    # knee and shin guards (both legs; the far one is darker)
    for s, k in (('f', 0.78), ('n', 1.0)):
        kx, ky = r['kn_' + s]
        ax_, ay_ = r['an_' + s]
        im = u if s == 'f' else o
        paint(im, chain(im, [(kx + 0.2, ky - 1.0), (kx + (ax_ - kx) * 0.15, ky + (ay_ - ky) * 0.35), (ax_ + 0.2, ay_ - 2.6)], (5.2, 5.0, 3.8)), dark * k if style == 'bouma' else dark, style, seed + 4 + (s == 'n'), bevel=1.2)
        paint(im, im.ellipse(kx + 0.8, ky - 0.2, 2.9, 2.9), main * k if style == 'bouma' else main, style, seed + 6 + (s == 'n'), bevel=1.2, strength=0.5)
    # forearm guard and glove
    paint(o, chain(o, [(r['el_n'][0] * 0.6 + r['hand_n'][0] * 0.4, r['el_n'][1] * 0.6 + r['hand_n'][1] * 0.4), r['hand_n']], (4.4, 3.6)), dark, style, seed + 8, bevel=1.2)
    o.fill(o.rect(r['el_n'][0] + 1.0, r['el_n'][1] - 2.0, 0.9, 4.0) & o.a.astype(bool) if False else o.line(r['el_n'][0] + 1.2, r['el_n'][1] - 1.6, r['el_n'][0] + 1.2, r['el_n'][1] + 1.6, 0.8), acc, 0.9)
    if style == 'bouma':
        for im_ in (u, o):
            m = im_.a > 0.5
            im_.speckle(m, '#1b1a18', 2.6, seed + 9, 1.3, 0.45)
            im_.speckle(m, '#8a7a5c', 1.0, seed + 10, 1.0, 0.22)
    return finish(u, style), finish(o, style)


# ---------------------------------------------------------------------------------------------- held items
def _axis(r):
    fx, fy = r['hand_f']
    nx, ny = r['hand_n']
    d = math.hypot(nx - fx, ny - fy)
    return (fx, fy), (nx, ny), ((nx - fx) / d, (ny - fy) / d)


def _quad(a, f, d, n, x0, x1, h0, h1):
    """quad along the item axis: from x0 to x1 along d (relative to the far hand), thickness h0..h1 perpendicular"""
    nx, ny = -d[1], d[0]
    pts = []
    for x, h in ((x0, h0), (x1, h1)):
        pts.append((f[0] + d[0] * x + nx * h, f[1] + d[1] * x + ny * h))
    for x, h in ((x1, h1), (x0, h0)):
        pts.append((f[0] + d[0] * x - nx * h * 0 + nx * (-h if h > 0 else h), f[1] + d[1] * x + ny * (-h if h > 0 else h)))
    return a.poly(pts)


def box(a, f, d, x0, x1, up, down):
    """rectangle along the axis, `up` toward the top of the sprite (negative perpendicular), `down` toward the bottom"""
    nx, ny = -d[1], d[0]            # perpendicular pointing 'down' when d points right
    return a.poly([(f[0] + d[0] * x0 - nx * up, f[1] + d[1] * x0 - ny * up),
                   (f[0] + d[0] * x1 - nx * up, f[1] + d[1] * x1 - ny * up),
                   (f[0] + d[0] * x1 + nx * down, f[1] + d[1] * x1 + ny * down),
                   (f[0] + d[0] * x0 + nx * down, f[1] + d[1] * x0 + ny * down)])


def held(kind, r, style, p, seed=31):
    a = new()
    f, n, d = _axis(r)
    metal = col('#6e7484') if style == 'bouma' else p['paper']
    dark = col('#23252e') if style == 'bouma' else p['ink']
    acc = col('#e8782a') if style == 'bouma' else p['neon']
    wood = col('#7c5c3e') if style == 'bouma' else p['paper']
    if kind == 'pistol':
        paint(a, box(a, f, d, -2.0, 11.0, 3.4, 0.6), metal, style, seed, bevel=1.0)
        paint(a, box(a, f, d, -1.8, 2.4, 0.2, 7.0), dark, style, seed + 1, bevel=0.8)
        a.fill(box(a, f, d, 10.2, 11.2, 3.8, 3.0), acc)
    elif kind == 'rifle':
        paint(a, box(a, f, d, -9.5, -0.5, 2.0, 2.8), dark, style, seed, bevel=1.0)                  # stock
        paint(a, box(a, f, d, -0.5, 13.0, 2.4, 0.9), metal, style, seed + 1, bevel=1.0)             # receiver and handguard
        paint(a, box(a, f, d, 13.0, 25.0, 1.5, 0.3), dark if style == 'bouma' else metal, style, seed + 2, bevel=0.5)
        paint(a, box(a, f, d, 3.0, 6.0, 0.8, 7.0), dark, style, seed + 3, bevel=0.8)                # magazine
        paint(a, box(a, f, d, 2.0, 8.0, 2.4, 3.6), dark, style, seed + 4, bevel=0.8)                # optic
        a.fill(box(a, f, d, 7.4, 8.4, 3.2, 2.6), acc)
    elif kind == 'blade':
        paint(a, box(a, f, d, -3.0, 0.5, 1.2, 1.2), dark, style, seed, bevel=0.6, hatch=False)      # grip
        paint(a, box(a, f, d, 0.5, 2.0, 2.4, 2.4), metal, style, seed + 1, bevel=0.5, hatch=False)  # guard
        paint(a, box(a, f, d, 2.0, 26.0, 1.6, 0.9), col('#aab4c4') if style == 'bouma' else metal, style, seed + 2, bevel=0.5)
        a.fill(box(a, f, d, 3.0, 24.0, 0.2, 0.0), acc, 0.7)
    elif kind == 'pick':
        paint(a, box(a, f, d, -9.0, 20.0, 1.2, 1.2), wood, style, seed, bevel=0.7, hatch=False)
        paint(a, box(a, f, d, 17.0, 20.0, 4.8, 4.8), metal, style, seed + 1, bevel=0.8)
        paint(a, box(a, f, d, 19.0, 22.0, 4.0, -0.4), metal, style, seed + 2, bevel=0.6)
    if style == 'bouma':
        a.speckle(a.a > 0.5, '#0e0e12', 3.0, seed + 9, 1.0, 0.5)
    return finish(a, style)


# ---------------------------------------------------------------------------------------------- compositing
def tinted(im, rgb):
    arr = np.asarray(im).astype(np.float32) / 255.0
    arr[..., :3] = np.clip(arr[..., :3] * np.asarray(rgb, np.float32)[None, None, :], 0, 1)
    return Image.fromarray((arr * 255 + 0.5).astype(np.uint8), 'RGBA')


def compose(stance, style, skin='tanned', armor=None, item=None, hair_rgb=(0.50, 0.40, 0.32)):
    r = STANCES[stance]
    p = pal(style)
    M = rig_masks(r)
    st = tuple(SKINS[skin]) if style == 'bouma' else (1, 1, 1)
    cv = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    cv.alpha_composite(shadow_layer(style))
    cv.alpha_composite(tinted(layer_arm_far(r, M, style, p), st))
    cv.alpha_composite(tinted(layer_body(r, M, style, p), st))
    hair = layer_hair(r, style, p)
    cv.alpha_composite(tinted(hair, hair_rgb) if style == 'bouma' else hair)
    over = None
    if armor:
        under, over = armor_layers(armor, r, M, style, p)
        cv.alpha_composite(under)
    if item:
        cv.alpha_composite(held(item, r, style, p))
    cv.alpha_composite(tinted(layer_arm_near(r, M, style, p), st))
    cv.alpha_composite(tinted(layer_hands(r, M, style, p), st))
    if over:
        cv.alpha_composite(over)
    return cv


def layers_for_export(stance, style):
    r = STANCES[stance]
    p = pal(style)
    M = rig_masks(r)
    out = {'shadow': shadow_layer(style), 'arm_far': layer_arm_far(r, M, style, p), 'body': layer_body(r, M, style, p),
           'hair': layer_hair(r, style, p), 'arm_near': layer_arm_near(r, M, style, p), 'hands': layer_hands(r, M, style, p)}
    for k in ARMOR:
        out['armor_%s_under' % k], out['armor_%s_over' % k] = armor_layers(k, r, M, style, p)
    for it in ('pistol', 'rifle', 'blade', 'pick'):
        out['held_' + it] = held(it, r, style, p)
    return out
