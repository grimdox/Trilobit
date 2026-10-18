"""Side-view paper dolls (proposal stage).  Every layer is a 64x64 image of the figure facing RIGHT (the game mirrors it for
left), feet on y=61, drawn by the same Art renderer as the rest of the 64px set.  Three base designs (D1 Runner, D2 Hauler,
D3 Climber) share one hold pose so any gun, blade or working tool lines up with the same two hands.

Layer order (back to front):  shadow, arm_far, body (legs, torso, head, underwear), hair, equipment 'under', held item,
arm_near, hand_far, equipment 'over'.
Skin layers are drawn in light grey and multiplied by the skin colour; hair likewise.

Two styles: 'bouma' (full palette, shaded, dirty) and 'moku' (three inks: ink, paper, neon; flat fills, hatching)."""
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from art64 import Art, col, mix, lit, tint

W = 64
HAND_NEAR = (46.0, 29.0)   # support hand
HAND_FAR = (40.0, 30.5)    # trigger / lower hand

STYLES = {
    'bouma': dict(ink='#14141c', paper='#d9d6cf', neon='#19e0d0', skin='#cfcfcf', hair='#8a8a8a'),
    'moku': dict(ink='#0d0d12', paper='#f1eee4', neon='#ff2f7d', skin='#f1eee4', hair='#0d0d12'),
}

SKINS = {          # multiplied over the grey skin layer (task 2: five tones)
    'pale': (1.00, 0.84, 0.74), 'tan_white': (0.97, 0.76, 0.58), 'tanned': (0.86, 0.62, 0.42),
    'dark': (0.60, 0.40, 0.27), 'near_black': (0.30, 0.20, 0.15),
}

# ---------------------------------------------------------------------------------- three designs
DOLLS = {
    'D1': dict(name='Runner', head=(35.0, 9.5, 4.3, 5.0), neck=(34.0, 15.0), lw=(6.2, 5.2, 4.0), aw=(4.3, 3.7, 3.1),
               torso=[(29, 19), (36, 19), (37.8, 23), (36.8, 29), (35.6, 35), (36, 38.5), (27.2, 38.5), (27.6, 34), (27.8, 28), (27.4, 22.5)],
               nl=[(31.5, 37), (37.5, 47), (36.5, 57), (43.5, 61)], fl=[(28.5, 37), (24.5, 47), (21.5, 57), (28.5, 61)],
               na=[(33.2, 21), (38.0, 29.5), HAND_NEAR], fa=[(31.0, 21), (35.0, 31), HAND_FAR],
               hair='crop', brief=(35.0, 42.5), band=None, beard=False),
    'D2': dict(name='Hauler', head=(36.0, 10.0, 4.8, 5.2), neck=(35.0, 15.5), lw=(7.8, 6.4, 5.0), aw=(5.4, 4.6, 3.8),
               torso=[(27.5, 18.5), (38, 18.8), (40.4, 23), (39.4, 29.5), (38, 35), (38, 39), (24.8, 39), (25.4, 34), (25.2, 28), (25.0, 22.5)],
               nl=[(32, 38), (38, 47), (37, 56.5), (44.5, 61)], fl=[(28.5, 38), (24, 47), (21, 56.5), (28.5, 61)],
               na=[(34.0, 21.5), (39.0, 30), HAND_NEAR], fa=[(30.5, 21.5), (35.0, 31.5), HAND_FAR],
               hair='bald', brief=(36.0, 43.5), band=None, beard=True),
    'D3': dict(name='Climber', head=(34.5, 8.6, 4.0, 4.8), neck=(33.7, 14.2), lw=(5.2, 4.4, 3.4), aw=(3.7, 3.2, 2.7),
               torso=[(29.2, 18), (35.4, 18.2), (36.9, 22.5), (35.9, 28), (34.6, 33.5), (34.8, 37), (27.6, 37), (28, 32), (28.2, 27), (27.9, 22)],
               nl=[(31, 36), (37, 46.5), (36, 57.5), (42.5, 61)], fl=[(29, 36), (24.5, 46.5), (21.5, 57.5), (28.5, 61)],
               na=[(33, 20), (37.6, 28.5), HAND_NEAR], fa=[(31, 20), (35.0, 30.5), HAND_FAR],
               hair='tail', brief=(34.0, 40.5), band=(21.0, 27.0), beard=False),
}


def new():
    return Art(W, W, 4)


def pal(style):
    p = STYLES[style]
    return {k: col(v) for k, v in p.items()}


def limb_mask(a, pts, w0, w1=None):
    """tapered chain of capsules; w0 may be a list of per-joint widths (then w1 is ignored)"""
    if isinstance(w0, (tuple, list)):
        ws = list(w0)[:len(pts)]
    else:
        w1 = w0 * 0.8 if w1 is None else w1
        ws = [w0 + (w1 - w0) * i / max(len(pts) - 1, 1) for i in range(len(pts))]
    m = None
    for i in range(len(pts) - 1):
        seg = a.line(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], (ws[i] + ws[i + 1]) / 2)
        m = seg if m is None else (m | seg)
    return m


def paint(a, mask, base, style, seed, bevel=2.0, strength=0.34, grain=0.1, hatch=True):
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
    return a.image(outline=0.8)


def parts(d):
    a = new()
    return dict(
        torso=a.poly(d['torso']),
        nl=limb_mask(a, d['nl'][:3], d['lw']) | a.poly(foot(d['nl'])),
        fl=limb_mask(a, d['fl'][:3], d['lw']) | a.poly(foot(d['fl'])),
        head=a.ellipse(d['head'][0], d['head'][1], d['head'][2], d['head'][3]),
        neck=limb_mask(a, [d['neck'], (d['neck'][0] - 0.5, d['neck'][1] + 4)], 3.0, 3.4),
        na=limb_mask(a, d['na'], d['aw']),
        fa=limb_mask(a, d['fa'], d['aw']),
        nose=a.tri((d['head'][0] + d['head'][2] - 0.6, d['head'][1] - 0.6),
                   (d['head'][0] + d['head'][2] + 1.5, d['head'][1] + 1.4),
                   (d['head'][0] + d['head'][2] - 0.8, d['head'][1] + 1.8)),
        hand_n=a.ellipse(HAND_NEAR[0] + 0.2, HAND_NEAR[1], 2.6, 2.3),
        hand_f=a.ellipse(HAND_FAR[0] + 0.2, HAND_FAR[1], 2.4, 2.1),
    )


def foot(leg):
    ax, ay = leg[2]
    tx, ty = leg[3]
    return [(ax - 2.0, ay - 1.0), (ax + 2.0, ay - 1.0), (tx + 1.0, ty - 2.4), (tx + 1.0, ty + 0.4), (ax - 2.5, ty + 0.4)]


# ---------------------------------------------------------------------------------- base layers
def shadow_layer(style='bouma'):
    a = new()
    if style == 'moku':
        m = a.ellipse(33, 61.6, 16, 1.6)
        a.fill(m & ((((a.xx * 2) % 2) < 1.0)), STYLES['moku']['ink'])
        return a.image()
    m = a.ellipse(33, 61.5, 17, 2.4)
    a.fill(m, '#000000', 0.0)
    k = ndi.gaussian_filter(m.astype(np.float32), 3.0) * 0.5
    a.rgb[:] = 0
    a.a[:] = k
    return a.image()


def layer_arm_far(dk, style, p):
    a = new()
    P = parts(dk)
    paint(a, P['fa'], p['skin'] * (0.78 if style == 'bouma' else 1.0), style, 1)
    return finish(a, style)


def underwear_mask(a, dk, P):
    y0, y1 = dk['brief']
    band = a.rect(0, y0 - 3.5, W, y1 - y0 + 3.5)
    legs = (P['nl'] | P['fl'])
    short = P['torso'] & a.rect(0, y0 - 3.5, W, 3.6 + 3.0) | (legs & a.rect(0, y0 - 3.5, W, y1 - y0 + 3.5))
    return short & (P['torso'] | legs)


def layer_body(dk, style, p, seed=3):
    a = new()
    P = parts(dk)
    skin = p['skin']
    paint(a, P['fl'], skin * (0.80 if style == 'bouma' else 1.0), style, seed)
    paint(a, P['neck'], skin * (0.92 if style == 'bouma' else 1.0), style, seed + 1, bevel=1.2)
    paint(a, P['nl'], skin * (0.96 if style == 'bouma' else 1.0), style, seed + 2)
    paint(a, P['torso'], skin, style, seed + 3, bevel=3.0)
    paint(a, P['head'], skin, style, seed + 4, bevel=2.5)
    paint(a, P['nose'], skin, style, seed + 5, bevel=0.8, hatch=False)
    # face: eye, brow and mouth are marks, not shading
    hx_, hy_, rx, ry = dk['head']
    ink = p['ink']
    a.fill(a.ellipse(hx_ + rx * 0.45, hy_ - 0.6, 0.7, 0.55), ink)
    a.fill(a.line(hx_ + rx * 0.25, hy_ - 1.9, hx_ + rx * 0.8, hy_ - 1.6, 0.45), ink, 0.9)
    a.fill(a.line(hx_ + rx * 0.45, hy_ + 2.3, hx_ + rx * 0.95, hy_ + 2.2, 0.4), ink, 0.8)
    # underwear (basic briefs / shorts, plus a chest band on D3)
    uw = underwear_mask(a, dk, P)
    ucol = col('#4a5a78') if style == 'bouma' else p['neon']
    paint(a, uw, ucol, style, seed + 6, bevel=1.5, hatch=False)
    if style == 'bouma':
        a.speckle(uw, '#2a2622', 3.0, seed + 8, 1.2, 0.5)
        a.fill(a.rect(0, dk['brief'][0] - 3.6, W, 0.9) & uw, '#232029', 0.9)
    if dk['band']:
        y0, y1 = dk['band']
        bm = P['torso'] & a.rect(0, y0, W, y1 - y0)
        paint(a, bm, ucol, style, seed + 7, bevel=1.2, hatch=False)
    return finish(a, style)


def layer_hair(dk, style, p, seed=5):
    a = new()
    hx_, hy_, rx, ry = dk['head']
    hc = p['hair'] if style == 'bouma' else p['ink']
    kind = dk['hair']
    if kind == 'crop':
        m = a.ellipse(hx_ - 0.3, hy_ - 1.4, rx + 0.5, ry - 0.2) & a.rect(0, 0, W, hy_ - 1.0)
        m |= a.ellipse(hx_ - 2.8, hy_ + 0.8, 2.0, 3.2)
        paint(a, m, hc, style, seed, bevel=1.4, hatch=False)
    elif kind == 'tail':
        m = a.ellipse(hx_ - 0.2, hy_ - 1.2, rx + 0.5, ry) & a.rect(0, 0, W, hy_ + 0.5) & ~a.rect(hx_ + 1.6, hy_ - 1.5, 8, 6)
        m |= a.ellipse(hx_ - 2.8, hy_ + 1.2, 2.1, 3.4)
        paint(a, m, hc, style, seed, bevel=1.4, hatch=False)
        tail = a.poly([(hx_ - 3.6, hy_ - 1.5), (hx_ - 8.5, hy_ + 1.0), (hx_ - 13.0, hy_ + 7.0), (hx_ - 11.2, hy_ + 11.5),
                       (hx_ - 8.0, hy_ + 6.2), (hx_ - 4.2, hy_ + 3.5)])
        paint(a, tail, hc * 0.9, style, seed + 1, bevel=1.2, hatch=False)
        a.fill(a.ellipse(hx_ - 4.2, hy_ - 0.6, 1.1, 1.4), p['neon'])
    elif kind == 'bald':
        m = a.ellipse(hx_ + 0.2, hy_ + 3.0, rx - 0.5, 2.5) & a.rect(hx_ - 1, hy_ + 2.2, 9, 5)      # beard
        m |= a.ellipse(hx_ + rx * 0.2, hy_ + 3.6, rx * 0.8, 2.3)
        paint(a, m & ~a.rect(0, 0, W, hy_ + 1.8), hc * 0.7 if style == 'bouma' else hc, style, seed, bevel=0.8, hatch=False)
    return finish(a, style)


def layer_arm_near(dk, style, p, seed=11):
    a = new()
    P = parts(dk)
    paint(a, P['na'], p['skin'], style, seed, bevel=1.8)
    paint(a, P['hand_n'], p['skin'] * (0.98 if style == 'bouma' else 1.0), style, seed + 1, bevel=1.0, hatch=False)
    return finish(a, style)


def layer_hand_far(dk, style, p, seed=12):
    a = new()
    P = parts(dk)
    paint(a, P['hand_f'], p['skin'] * (0.9 if style == 'bouma' else 1.0), style, seed, bevel=1.0, hatch=False)
    return finish(a, style)


# ---------------------------------------------------------------------------------- armor (three proposals)
ARMOR = {
    'A1': dict(label='Plasteel plate', bouma=('#8795a6', '#3c4552', '#e8782a'), kind='plate'),
    'A2': dict(label='Riot shell', bouma=('#59607a', '#262a38', '#e0405a'), kind='shell'),
    'A3': dict(label='Weave and plates', bouma=('#8b8760', '#4a4733', '#27d2c4'), kind='weave'),
}


def armor_layers(key, dk, style, p, seed=21):
    """returns (under, over) images"""
    cfg = ARMOR[key]
    main, dark, acc = (col(c) for c in cfg['bouma'])
    if style == 'moku':
        main, dark, acc = p['paper'], p['ink'], p['neon']
    P = parts(dk)
    u = new()
    o = new()
    hx_, hy_, rx, ry = dk['head']
    tors = P['torso']
    chest = tors & u.rect(0, 17, W, 17.0)
    kind = cfg['kind']
    if kind == 'plate':
        paint(u, tors & u.rect(0, 18, W, 19.5), main, style, seed, bevel=2.2, strength=0.6)
        paint(u, chest & u.rect(0, 20, W, 8) & u.rect(31, 0, 12, W), main * 1.08, style, seed + 1, bevel=1.6, strength=0.6)
        u.fill(u.rect(25, 28.4, 16, 0.8) & tors, dark)
        u.fill(u.rect(33, 21, 1.1, 13) & tors, acc)
        pauld = u.ellipse(dk['na'][0][0] - 0.6, dk['na'][0][1] - 0.4, 4.6, 4.0)
        paint(u, pauld, main * 1.05, style, seed + 2, bevel=2.0, strength=0.6)
        paint(u, u.rect(0, 30.0, W, 3.0) & limb_mask(u, dk['nl'][:3], dk['lw'][0] + 1.6, dk['lw'][1] + 0.6) & u.rect(0, 36, W, 12), dark, style, seed + 3, bevel=1.0, hatch=False)
        # helmet: shell over the skull with a visor slit
        sk = u.ellipse(hx_ - 0.2, hy_ - 0.8, rx + 1.0, ry + 0.8) & u.rect(0, 0, W, hy_ + 1.6)
        paint(u, sk, main, style, seed + 4, bevel=2.0, strength=0.6)
        u.fill(u.rect(hx_ + 0.6, hy_ - 1.3, rx + 0.4, 1.7) & u.ellipse(hx_, hy_, rx + 0.2, ry), acc)
        paint(o, limb_mask(o, [dk['na'][1], dk['na'][2]], dk['aw'][1] + 1.6, dk['aw'][2] + 1.2) & o.rect(0, 0, W, W), dark, style, seed + 5, bevel=1.4)
        o.fill(o.rect(dk['na'][1][0] + 1.2, dk['na'][1][1] - 2.2, 1.0, 4.4), acc)
        paint(o, limb_mask(o, [dk['nl'][1], (dk['nl'][2][0] + 0.2, dk['nl'][2][1] - 2.0)], dk['lw'][1] + 1.5, dk['lw'][2] + 1.0), dark, style, seed + 6, bevel=1.4)
    elif kind == 'shell':
        paint(u, tors & u.rect(0, 17.5, W, 20.5), main, style, seed, bevel=2.8, strength=0.65)
        for yy in (23.5, 27.5, 31.5):
            u.fill(u.rect(24, yy, 17, 0.7) & tors, dark)
        u.fill(u.rect(34.5, 19, 4, 3.4) & tors, acc)
        pauld = u.poly([(dk['na'][0][0] - 4.4, dk['na'][0][1] - 3), (dk['na'][0][0] + 3.6, dk['na'][0][1] - 3.2),
                        (dk['na'][0][0] + 4.2, dk['na'][0][1] + 4.2), (dk['na'][0][0] - 3.4, dk['na'][0][1] + 3.0)])
        paint(u, pauld, main * 1.1, style, seed + 2, bevel=1.8, strength=0.65)
        sk = u.ellipse(hx_ - 0.2, hy_ - 0.4, rx + 1.3, ry + 1.2) & u.rect(0, 0, W, hy_ + 3.6)
        paint(u, sk, main, style, seed + 4, bevel=2.2, strength=0.65)
        u.fill(u.rect(hx_ + 0.2, hy_ - 1.6, rx + 1.5, 3.2) & sk, dark)
        u.fill(u.rect(hx_ + 1.6, hy_ - 0.9, rx - 0.4, 0.9) & sk, acc)
        paint(o, limb_mask(o, [dk['na'][0], dk['na'][1], dk['na'][2]], dk['aw'][0] + 1.0, dk['aw'][2] + 0.9), main * 0.95, style, seed + 5, bevel=1.4)
        paint(o, limb_mask(o, dk['nl'][:3], dk['lw'][0] + 1.4, dk['lw'][2] + 0.9) & o.rect(0, 40, W, 24), main * 0.95, style, seed + 6, bevel=1.4)
    else:   # weave: soft jacket with chest, back and knee plates
        paint(u, tors & u.rect(0, 17.8, W, 21.2), main, style, seed, bevel=2.4, strength=0.45, grain=0.35)
        u.fill(u.rect(25, 33.2, 15, 1.1) & tors, dark)
        paint(u, u.rect(31, 21, 8, 8) & tors, dark, style, seed + 1, bevel=1.4)
        u.fill(u.rect(31.8, 22, 6.4, 0.7), acc)
        paint(u, limb_mask(u, [dk['na'][0], dk['na'][1]], dk['aw'][0] + 1.0, dk['aw'][1] + 0.8), main, style, seed + 2, bevel=1.6, strength=0.45, grain=0.3)
        hood = u.ellipse(hx_ - 1.6, hy_ + 0.3, rx + 1.7, ry + 1.2) & ~u.rect(hx_ + 1.2, hy_ - 2.6, 9, 8.6)
        paint(u, hood, main * 0.9, style, seed + 4, bevel=2.2, strength=0.45, grain=0.3)
        u.fill(u.line(hx_ + 1.0, hy_ - 3.4, hx_ + 1.4, hy_ + 3.2, 0.7), dark)
        paint(o, u.ellipse(dk['nl'][1][0] + 0.6, dk['nl'][1][1], 2.9, 3.0), dark, style, seed + 5, bevel=1.4)
        paint(o, limb_mask(o, [dk['na'][1], dk['na'][2]], dk['aw'][1] + 1.0, dk['aw'][2] + 0.8), dark, style, seed + 6, bevel=1.2)
        paint(o, limb_mask(o, [(dk['nl'][1][0] - 0.2, dk['nl'][1][1] + 3.0), (dk['nl'][2][0] + 0.2, dk['nl'][2][1] - 1.0)], dk['lw'][1] + 1.0, dk['lw'][2] + 0.8), dark, style, seed + 7, bevel=1.2)
    if style == 'bouma':
        for im_ in (u, o):
            m = im_.a > 0.5
            im_.speckle(m, '#1b1a18', 2.5, seed + 9, 1.3, 0.45)
            im_.speckle(m, '#8a7a5c', 1.0, seed + 10, 1.0, 0.25)
    return finish(u, style), finish(o, style)


# ---------------------------------------------------------------------------------- held items (shared hold pose)
def held(kind, style, p, seed=31):
    a = new()
    metal = col('#6a7080') if style == 'bouma' else p['paper']
    dark = col('#1c1d24') if style == 'bouma' else p['ink']
    acc = col('#e8782a') if style == 'bouma' else p['neon']
    wood = col('#7a5a3c') if style == 'bouma' else p['paper']
    hx0, hy0 = HAND_FAR
    if kind == 'pistol':
        paint(a, a.poly([(hx0 - 2.0, hy0 - 4.0), (hx0 + 12.5, hy0 - 4.0), (hx0 + 13.0, hy0 - 0.2), (hx0 - 2.0, hy0 - 0.2)]), metal, style, seed, bevel=1.0)
        paint(a, a.poly([(hx0 - 1.6, hy0 - 0.5), (hx0 + 3.4, hy0 - 0.5), (hx0 + 1.6, hy0 + 7.0), (hx0 - 2.6, hy0 + 7.0)]), dark, style, seed + 1, bevel=0.8)
        a.fill(a.rect(hx0 + 12.0, hy0 - 4.4, 1.1, 1.0), acc)
        a.fill(a.line(hx0 + 5, hy0 - 4.0, hx0 + 5, hy0 - 0.6, 0.4), dark)
    elif kind == 'rifle':
        paint(a, a.poly([(hx0 - 8.0, hy0 - 7.0), (hx0 - 1.0, hy0 - 4.6), (hx0 - 1.0, hy0 - 0.8), (hx0 - 8.8, hy0 - 3.2)]), dark, style, seed, bevel=1.0)
        paint(a, a.poly([(hx0 - 1.0, hy0 - 5.2), (hx0 + 12.0, hy0 - 5.2), (hx0 + 12.0, hy0 - 0.6), (hx0 - 1.0, hy0 - 0.6)]), metal, style, seed + 1, bevel=1.1)
        paint(a, a.poly([(hx0 + 12.0, hy0 - 4.4), (hx0 + 21.5, hy0 - 4.0), (hx0 + 21.5, hy0 - 2.7), (hx0 + 12.0, hy0 - 2.3)]), metal * 0.8, style, seed + 2, bevel=0.7)
        paint(a, a.poly([(hx0 + 3.0, hy0 - 0.6), (hx0 + 6.4, hy0 - 0.6), (hx0 + 5.2, hy0 + 5.8), (hx0 + 2.0, hy0 + 5.8)]), dark, style, seed + 3, bevel=0.8)
        paint(a, a.rect(hx0 + 2.2, hy0 - 7.6, 6.0, 2.4), dark, style, seed + 4, bevel=0.8)
        a.fill(a.rect(hx0 + 7.2, hy0 - 6.9, 0.9, 1.4), acc)
    elif kind == 'pick':
        # working tool: a pickaxe, haft through both hands, head above the front hand
        top = (HAND_NEAR[0] + 6.0, HAND_NEAR[1] - 13.5)
        paint(a, a.line(hx0 - 7.0, hy0 + 8.0, top[0], top[1], 2.4), wood, style, seed, bevel=0.7, hatch=False)
        head = a.poly([(top[0] - 7.0, top[1] + 4.2), (top[0] - 2.0, top[1] - 1.4), (top[0] + 2.4, top[1] - 1.6),
                       (top[0] + 9.0, top[1] + 3.6), (top[0] + 2.4, top[1] + 0.2), (top[0] - 2.0, top[1] + 1.0)])
        paint(a, head, metal, style, seed + 1, bevel=0.9)
        a.fill(a.line(top[0] - 6.0, top[1] + 3.8, top[0] - 3.6, top[1] + 0.2, 0.5), acc, 0.8)
    if style == 'bouma':
        m = a.a > 0.5
        a.speckle(m, '#0e0e12', 3.0, seed + 9, 1.0, 0.5)
    return finish(a, style)


# ---------------------------------------------------------------------------------- compositing
def tinted(im, rgb):
    arr = np.asarray(im).astype(np.float32) / 255.0
    arr[..., :3] = np.clip(arr[..., :3] * np.asarray(rgb, np.float32)[None, None, :], 0, 1)
    return Image.fromarray((arr * 255 + 0.5).astype(np.uint8), 'RGBA')


def compose(dkey, style, skin='tan_white', armor=None, item=None, hair_rgb=(0.55, 0.45, 0.36)):
    dk = DOLLS[dkey]
    p = pal(style)
    st = tuple(SKINS[skin]) if style == 'bouma' else (1, 1, 1)
    canvas = Image.new('RGBA', (W, W), (0, 0, 0, 0))

    def put(im):
        canvas.alpha_composite(im)

    put(shadow_layer(style))
    put(tinted(layer_arm_far(dk, style, p), st))
    put(tinted(layer_body(dk, style, p), st))
    hair = layer_hair(dk, style, p)
    put(tinted(hair, hair_rgb) if style == 'bouma' else hair)
    under = over = None
    if armor:
        under, over = armor_layers(armor, dk, style, p)
        put(under)
    if item:
        put(held(item, style, p))
    put(tinted(layer_arm_near(dk, style, p), st))
    put(tinted(layer_hand_far(dk, style, p), st))
    if over:
        put(over)
    return canvas


def layers_for_export(dkey, style):
    """individual layer images for one design (what the game would stack)"""
    dk = DOLLS[dkey]
    p = pal(style)
    out = {
        'shadow': shadow_layer(style), 'arm_far': layer_arm_far(dk, style, p), 'body': layer_body(dk, style, p),
        'hair': layer_hair(dk, style, p), 'arm_near': layer_arm_near(dk, style, p), 'hand_far': layer_hand_far(dk, style, p),
    }
    for k in ARMOR:
        out['armor_%s_under' % k], out['armor_%s_over' % k] = armor_layers(k, dk, style, p)
    for it in ('pistol', 'rifle', 'pick'):
        out['held_' + it] = held(it, style, p)
    return out
