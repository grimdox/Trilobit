"""Three-quarter-view human doll, proposal stage.  The figure is drawn on a 128x128 master (about 118 px tall, 7.3 heads) so there is
room for anatomy and a face; `down()` area-resamples it to the 64x64 the game uses.  Skin is flat grey with anatomy lines (no
shading yet) and is multiplied by a skin colour; hair is grey and tinted.  The figure turns about 40 degrees to screen right.

Rig: joints per pose.  Everything (body, underwear, later clothes/armor/guns) is built from the same joints so layers line up."""
import math
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from art64 import Art, col

N = 128
HS = 1.17      # head scale relative to the first draft
SKIN_BASE = '#dcdcdc'
LINE = '#8d8d8d'
LINE_D = '#5f5f5f'

SKINS = {'pale': (1.00, 0.84, 0.74), 'tan_white': (0.97, 0.76, 0.58), 'tanned': (0.86, 0.62, 0.42),
         'dark': (0.60, 0.40, 0.27), 'near_black': (0.30, 0.20, 0.15)}

POSES = {
    'A': dict(label='Low ready: both hands forward',
              head=(65, 14), lean=0.0,
              sh_n=(47, 31), sh_f=(77, 30), el_n=(47, 51), hand_n=(64, 50), el_f=(84, 46), hand_f=(97, 41), grip_n='fist', grip_f='fist',
              hip_n=(54, 68), hip_f=(68, 68), kn_n=(50, 95), an_n=(44, 117), toe_n=(58, 120), kn_f=(77, 95), an_f=(81, 117), toe_f=(95, 121)),
    'B': dict(label='Guard: one arm out, one at the chin',
              head=(69, 15), lean=3.0,
              sh_n=(50, 32), sh_f=(80, 31), el_n=(45, 52), hand_n=(60, 43), el_f=(98, 34), hand_f=(115, 36), grip_n='fist', grip_f='fist',
              hip_n=(52, 69), hip_f=(67, 69), kn_n=(46, 96), an_n=(38, 117), toe_n=(52, 120), kn_f=(82, 96), an_f=(88, 117), toe_f=(103, 121)),
    'C': dict(label='Relaxed: hands low, weight on one leg',
              head=(64, 14), lean=-1.0,
              sh_n=(47, 32), sh_f=(77, 29), el_n=(44, 52), hand_n=(47, 71), el_f=(81, 50), hand_f=(84, 70), grip_n='fist', grip_f='open',
              hip_n=(53, 67), hip_f=(68, 69), kn_n=(52, 95), an_n=(49, 117), toe_n=(61, 120), kn_f=(75, 96), an_f=(78, 117), toe_f=(92, 121)),
}


def new():
    return Art(N, N, 3)


def catmull(pts, n=10, closed=True):
    P = [np.array(p, float) for p in pts]
    out = []
    m = len(P)
    rng = range(m) if closed else range(m - 1)
    for i in rng:
        p0, p1, p2, p3 = P[(i - 1) % m], P[i], P[(i + 1) % m], P[(i + 2) % m]
        if not closed:
            p0 = P[max(i - 1, 0)]
            p3 = P[min(i + 2, m - 1)]
        for k in range(n):
            t = k / n
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    return [tuple(q) for q in out]


def blob(a, pts, n=10):
    return a.poly(catmull(pts, n))


def tube(a, pts, ws, n=3):
    """smooth tapered tube along pts with widths ws"""
    sp = catmull(pts, 8, closed=False) if len(pts) > 2 else [pts[0], pts[1]]
    k = len(sp)
    wsi = np.interp(np.linspace(0, 1, k), np.linspace(0, 1, len(ws)), ws)
    m = None
    for i in range(k - 1):
        s = a.line(sp[i][0], sp[i][1], sp[i + 1][0], sp[i + 1][1], (wsi[i] + wsi[i + 1]) / 2)
        m = s if m is None else (m | s)
    return m


def ln(a, pts, w=0.8, c=LINE, alpha=0.9, smooth=True):
    sp = catmull(pts, 6, closed=False) if (smooth and len(pts) > 2) else pts
    for i in range(len(sp) - 1):
        a.fill(a.line(sp[i][0], sp[i][1], sp[i + 1][0], sp[i + 1][1], w), c, alpha)


def flat(a, mask, c, alpha=1.0):
    a.fill(mask, c, alpha)


# ------------------------------------------------------------------------------------------------ parts
def torso_mask(a, r):
    sh_n, sh_f = r['sh_n'], r['sh_f']
    hn, hf = r['hip_n'], r['hip_f']
    hc = ((hn[0] + hf[0]) / 2, (hn[1] + hf[1]) / 2)
    L = r['lean']
    pts = [(sh_n[0] - 1.2, sh_n[1] + 0.5), (sh_n[0] + 6, sh_n[1] - 3.0), (sh_n[0] + 15, sh_n[1] - 3.6 + L * 0.0), (sh_f[0] - 5, sh_f[1] - 3.0),
           (sh_f[0] + 1.2, sh_f[1] + 0.6), (sh_f[0] + 0.4, sh_f[1] + 9), (sh_f[0] + 1.6 + L * 0.3, 42), (hc[0] + 8.0 + L * 0.5, 53),
           (hf[0] + 5.5, 63), (hf[0] + 3.5, hf[1] + 5), (hc[0] + 1, 75), (hn[0] - 3.0, hn[1] + 5),
           (hn[0] - 4.2, 63), (hc[0] - 8.2, 52), (sh_n[0] + 0.2, sh_n[1] + 12)]
    return blob(a, pts, 8)


def leg_masks(a, r):
    out = {}
    for s, (hk, kn, an, toe) in (('n', ('hip_n', 'kn_n', 'an_n', 'toe_n')), ('f', ('hip_f', 'kn_f', 'an_f', 'toe_f'))):
        h, k, an_, t = r[hk], r[kn], r[an], r[toe]
        thigh = tube(a, [(h[0], h[1] + 2), ((h[0] + k[0]) / 2 + (0.5 if s == 'f' else -0.5), (h[1] + k[1]) / 2), k], (16.5, 14.0, 10.5))
        calf = tube(a, [(k[0], k[1]), (k[0] * 0.55 + an_[0] * 0.45 - 0.6, k[1] * 0.55 + an_[1] * 0.45), (an_[0], an_[1] - 2)], (10.5, 9.8, 6.0))
        calf |= a.ellipse(k[0] * 0.62 + an_[0] * 0.38 - 1.6, k[1] * 0.62 + an_[1] * 0.38 - 2, 4.4, 8.4)
        ankle = a.ellipse(an_[0], an_[1] - 1, 3.8, 4.2)
        foot = blob(a, [(an_[0] - 4.2, an_[1] - 3), (an_[0] + 3.6, an_[1] - 4), (an_[0] + 7, an_[1] - 1.2), (t[0] - 3, t[1] - 3.6), (t[0] + 2.2, t[1] - 2.6),
                        (t[0] + 3.4, t[1] - 0.6), (t[0] + 1.0, t[1] + 1.8), (an_[0] + 2, t[1] + 2.2), (an_[0] - 4.6, t[1] + 2.0), (an_[0] - 5.5, an_[1] + 1)], 6)
        out[s] = dict(thigh=thigh, calf=calf, ankle=ankle, foot=foot, all=thigh | calf | ankle | foot)
    return out


def arm_masks(a, r):
    out = {}
    for s in ('n', 'f'):
        sh, el, hd = r['sh_' + s], r['el_' + s], r['hand_' + s]
        up = tube(a, [sh, ((sh[0] + el[0]) / 2 + (1.0 if s == 'n' else -0.6), (sh[1] + el[1]) / 2 - 0.5), el], (9.2, 7.8, 6.4))
        delt = a.ellipse(sh[0] + (0.6 if s == 'f' else -0.6), sh[1] + 2.6, 4.9, 5.8)
        fa = tube(a, [el, ((el[0] + hd[0]) / 2, (el[1] + hd[1]) / 2 - 0.8), hd], (6.8, 6.0, 4.6))
        out[s] = dict(up=up, delt=delt, fore=fa, all=up | delt | fa)
    return out


def hand_mask(a, hd, direction, grip):
    """fist or open hand at hd; direction = unit vector the forearm points along"""
    dx, dy = direction
    px, py = -dy, dx
    cx, cy = hd[0] + dx * 2.5, hd[1] + dy * 2.5
    if grip == 'fist':
        m = a.ellipse(cx, cy, 4.7, 4.3)
        m |= a.ellipse(cx + dx * 2.2, cy + dy * 2.2, 3.7, 3.7)
    else:
        m = blob(a, [(hd[0] - px * 3.2, hd[1] - py * 3.2), (hd[0] + px * 3.4, hd[1] + py * 3.4), (hd[0] + px * 3.6 + dx * 6, hd[1] + py * 3.6 + dy * 6),
                     (hd[0] - px * 3.0 + dx * 6, hd[1] - py * 3.0 + dy * 6)], 5)
        for k, off in enumerate((-2.6, -0.9, 0.8, 2.5)):
            m |= tube(a, [(hd[0] + px * off + dx * 5, hd[1] + py * off + dy * 5), (hd[0] + px * off + dx * (9.5 - abs(off) * 0.4), hd[1] + py * off + dy * (9.5 - abs(off) * 0.4)),
                          (hd[0] + px * off * 1.1 + dx * (12.5 - abs(off) * 0.5), hd[1] + py * off * 1.1 + dy * (12.5 - abs(off) * 0.5) + 0.6)], (2.4, 2.1, 1.7))
        m |= tube(a, [(hd[0] - px * 3.0 + dx * 1, hd[1] - py * 3.0 + dy * 1), (hd[0] - px * 4.6 + dx * 4, hd[1] - py * 4.6 + dy * 4), (hd[0] - px * 4.0 + dx * 8, hd[1] - py * 4.0 + dy * 8)], (2.8, 2.4, 1.8))
    return m


def head_masks(a, r):
    hx, hy = r['head']
    sk = blob(a, [(hx - 8.0 * HS, hy - 1.0 * HS), (hx - 6.5 * HS, hy - 7.2 * HS), (hx - 1.5 * HS, hy - 9.8 * HS), (hx + 4.5 * HS, hy - 8.4 * HS), (hx + 8.2 * HS, hy - 3.6 * HS), (hx + 8.6 * HS, hy + 1.0 * HS),
                  (hx + 7.4 * HS, hy + 5.0 * HS), (hx + 5.2 * HS, hy + 8.4 * HS), (hx + 1.0 * HS, hy + 10.0 * HS), (hx - 3.4 * HS, hy + 9.0 * HS), (hx - 6.4 * HS, hy + 5.0 * HS)], 8)
    nose = blob(a, [(hx + 7.0 * HS, hy - 1.2 * HS), (hx + 10.8 * HS, hy + 3.6 * HS), (hx + 9.6 * HS, hy + 5.2 * HS), (hx + 6.6 * HS, hy + 4.6 * HS)], 6)
    ear = a.ellipse(hx - 6.6 * HS, hy + 1.2 * HS, 1.9, 3.1)
    neck = blob(a, [(hx - 5.0 * HS, hy + 6 * HS), (hx + 4.4 * HS, hy + 6.4 * HS), (hx + 5.6 * HS, hy + 14.5 * HS), (hx + 8.0 * HS, hy + 17.5 * HS), (hx - 9 * HS, hy + 17.5 * HS), (hx - 6.0 * HS, hy + 14 * HS)], 6)
    return dict(skull=sk, nose=nose, ear=ear, neck=neck)


# ------------------------------------------------------------------------------------------------ layers
def finish(a, outline=0.9, ink=(0.10, 0.07, 0.07)):
    return a.image(outline=outline, outline_col=ink)


def L_shadow():
    a = new()
    m = a.ellipse(66, 121.5, 36, 4.0)
    k = ndi.gaussian_filter(m.astype(np.float32), 6.0) * 0.5
    a.rgb[:] = 0
    a.a[:] = k
    return a.image()


def L_arm_far(r):
    a = new()
    A = arm_masks(a, r)
    m = A['f']['all']
    flat(a, m, SKIN_BASE)
    # delt/biceps/triceps and forearm muscle lines
    sh, el, hd = r['sh_f'], r['el_f'], r['hand_f']
    ln(a, [(sh[0] + 2, sh[1] + 6), ((sh[0] + el[0]) / 2 + 1, (sh[1] + el[1]) / 2), (el[0] + 1, el[1] - 3)], 0.7)
    ln(a, [(el[0] - 1, el[1] + 3), ((el[0] + hd[0]) / 2, (el[1] + hd[1]) / 2 + 2), (hd[0] - 2, hd[1] + 2)], 0.6, LINE, 0.7)
    d = np.array(hd, float) - np.array(el, float)
    d /= np.linalg.norm(d)
    h = hand_mask(a, hd, tuple(d), r['grip_f'])
    flat(a, h, SKIN_BASE)
    _hand_lines(a, hd, tuple(d), r['grip_f'])
    return finish(a)


def _hand_lines(a, hd, d, grip):
    dx, dy = d
    px, py = -dy, dx
    cx, cy = hd[0] + dx * 2.5, hd[1] + dy * 2.5
    if grip == 'fist':
        for k in (-2.4, -0.8, 0.8, 2.4):
            ln(a, [(cx + dx * 1.2 + px * k, cy + dy * 1.2 + py * k), (cx + dx * 4.4 + px * k * 0.9, cy + dy * 4.4 + py * k * 0.9)], 0.45, LINE_D, 0.8, smooth=False)
        ln(a, [(cx - dx * 2.5 + px * 3.4, cy - dy * 2.5 + py * 3.4), (cx + dx * 2.5 + px * 3.6, cy + dy * 2.5 + py * 3.6)], 0.7, LINE, 0.9, smooth=False)
    else:
        for off in (-1.7, 0.0, 1.7):
            ln(a, [(hd[0] + px * off + dx * 5.2, hd[1] + py * off + dy * 5.2), (hd[0] + px * off + dx * 11.2, hd[1] + py * off + dy * 11.2)], 0.4, LINE_D, 0.7, smooth=False)


def L_leg(r, side):
    a = new()
    Lg = leg_masks(a, r)[side]
    flat(a, Lg['all'], SKIN_BASE)
    k = r['kn_' + side]
    an = r['an_' + side]
    h = r['hip_' + side]
    # kneecap, quad and calf lines, shin ridge, ankle bone, toes
    a.fill(a.ellipse(k[0] + 1.2, k[1] - 0.6, 3.3, 3.8), LINE, 0.35)
    ln(a, [(h[0] + 2.5, h[1] + 10), (k[0] + 3.4, k[1] - 6), (k[0] + 2.8, k[1] - 3)], 0.7)
    ln(a, [(h[0] - 3.6, h[1] + 12), (k[0] - 3.2, k[1] - 5)], 0.6, LINE, 0.7)
    ln(a, [(k[0] + 1.0, k[1] + 4), (an[0] + 2.0, an[1] - 5)], 0.6, LINE, 0.8)
    ln(a, [(k[0] - 3.8, k[1] + 4), (k[0] - 4.6, k[1] + 12), (an[0] - 2.4, an[1] - 5)], 0.6, LINE, 0.7)
    a.fill(a.ellipse(an[0] - 0.4, an[1] - 1.0, 1.0, 1.0), LINE, 0.7)
    t = r['toe_' + side]
    for i, off in enumerate((-2.6, -0.8, 1.0, 2.8)):
        ln(a, [(t[0] - 2.2 + i * 0.1, t[1] - 3.0 + i * 1.4), (t[0] + 1.8, t[1] - 2.2 + i * 1.3)], 0.35, LINE_D, 0.8, smooth=False)
    return finish(a)


def L_torso(r):
    a = new()
    T = torso_mask(a, r)
    H = head_masks(a, r)
    flat(a, T, SKIN_BASE)
    flat(a, H['neck'], SKIN_BASE)
    hx, hy = r['head']
    sh_n, sh_f = r['sh_n'], r['sh_f']
    cx = (sh_n[0] + sh_f[0]) / 2
    L = r['lean']
    # collarbones, trapezius, sternum, pectorals, ribs, abdomen, navel, obliques
    ln(a, [(sh_n[0] + 5, sh_n[1] - 1.5), (cx - 1, sh_n[1] - 3.4)], 0.7)
    ln(a, [(cx + 1, sh_n[1] - 3.4), (sh_f[0] - 4, sh_f[1] - 1.8)], 0.7)
    ln(a, [(cx + 2.4, sh_n[1] - 2), (cx + 3.4, sh_n[1] + 16), (cx + 4.2 + L * 0.2, sh_n[1] + 22)], 0.55, LINE, 0.7)           # sternum (turned toward screen right)
    a.fill(blob(a, [(cx - 12, sh_n[1] + 7), (cx - 4, sh_n[1] + 5.4), (cx + 4, sh_n[1] + 7.5), (cx + 3.2, sh_n[1] + 12.5), (cx - 4, sh_n[1] + 15), (cx - 11.5, sh_n[1] + 12.5)], 6), LINE, 0.18)
    a.fill(blob(a, [(cx + 5.6, sh_n[1] + 7.8), (cx + 12, sh_n[1] + 6.4), (cx + 17, sh_n[1] + 9), (cx + 16, sh_n[1] + 14), (cx + 10, sh_n[1] + 15.4), (cx + 5.6, sh_n[1] + 13)], 6), LINE, 0.12)
    ln(a, [(cx - 13, sh_n[1] + 13.5), (cx - 4, sh_n[1] + 16.6), (cx + 3, sh_n[1] + 14.4)], 0.8, LINE_D, 0.55)                 # underside of near pec
    ln(a, [(cx + 5.5, sh_n[1] + 14.4), (cx + 11, sh_n[1] + 16.4), (cx + 17, sh_n[1] + 13.4)], 0.8, LINE_D, 0.55)
    a.fill(a.ellipse(cx - 6.4, sh_n[1] + 11.6, 0.9, 0.9), LINE_D, 0.7)
    a.fill(a.ellipse(cx + 11.4, sh_n[1] + 11.6, 0.8, 0.8), LINE_D, 0.6)
    for k in range(3):
        y = sh_n[1] + 19 + k * 3.6
        ln(a, [(cx - 11 + k * 0.7, y), (cx - 4, y + 1.0)], 0.5, LINE, 0.4)
        ln(a, [(cx + 6.5, y + 0.6), (cx + 14 - k * 1.0, y - 0.4)], 0.5, LINE, 0.35)
    ab0 = sh_n[1] + 22
    ln(a, [(cx + 3.8, ab0), (cx + 4.4, ab0 + 17)], 0.55, LINE, 0.6)
    for k in range(3):
        y = ab0 + 2 + k * 5.2
        ln(a, [(cx - 6.6, y), (cx + 1, y + 0.8), (cx + 4.2, y + 0.8)], 0.55, LINE, 0.55)
        ln(a, [(cx + 5, y + 0.8), (cx + 11, y + 0.2)], 0.55, LINE, 0.5)
    a.fill(a.ellipse(cx + 4.4, ab0 + 17.5, 1.2, 1.6), LINE_D, 0.7)                                                          # navel
    ln(a, [(cx - 11, ab0 + 3), (cx - 9, ab0 + 14)], 0.5, LINE, 0.4)
    # neck: sternocleidomastoid and Adam's apple
    ln(a, [(hx - 3.6, hy + 8), (cx - 2.4, sh_n[1] - 2.4)], 0.6)
    ln(a, [(hx + 4.0, hy + 9), (cx + 3.6, sh_n[1] - 2.4)], 0.6)
    a.fill(a.ellipse(hx + 2.2, hy + 14, 1.0, 1.4), LINE, 0.4)
    return finish(a)


def L_underwear(r):
    a = new()
    T = torso_mask(a, r)
    Lg = leg_masks(a, r)
    hc_y = (r['hip_n'][1] + r['hip_f'][1]) / 2
    top = hc_y - 5.0
    band = a.rect(0, top, N, 8)
    boxer = ((T & a.rect(0, top, N, 80 - top)) | ((Lg['n']['thigh'] | Lg['f']['thigh']) & a.rect(0, top, N, 91 - top)))
    boxer &= (T | Lg['n']['thigh'] | Lg['f']['thigh'])
    # cut the hem across each thigh slightly lower on the lead leg
    boxer &= ~(a.rect(0, 84.5, N, 20) & Lg['n']['thigh']) & ~(a.rect(0, 88.0, N, 20) & Lg['f']['thigh'])
    a.shade(boxer, '#3d4a66', bevel=2.4, strength=0.5, grain=0.2, seed=4)
    a.shade(boxer & band & T, '#272c3b', bevel=1.2, strength=0.4, seed=5)
    a.fill(a.rect(0, top + 7.0, N, 0.6) & boxer & T, '#1a1d28', 0.8)
    ln(a, [(r['hip_n'][0] + 1, hc_y + 6), (r['hip_n'][0] + 6, hc_y + 10), (r['hip_n'][0] + 9, hc_y + 15)], 0.7, '#222633', 0.7)
    ln(a, [(r['hip_f'][0] - 2, hc_y + 8), (r['hip_f'][0] - 9, hc_y + 13)], 0.7, '#222633', 0.7)
    ln(a, [(r['hip_f'][0] + 7, hc_y + 10), (r['hip_f'][0] + 4, hc_y + 16)], 0.6, '#222633', 0.6)
    a.speckle(boxer, '#161a24', 2.2, 7, 1.2, 0.5)
    a.fill(a.rect(0, 0, N, 0), '#000000')
    return finish(a)


def L_arm_near(r):
    a = new()
    A = arm_masks(a, r)
    m = A['n']['all']
    flat(a, m, SKIN_BASE)
    sh, el, hd = r['sh_n'], r['el_n'], r['hand_n']
    ln(a, [(sh[0] + 3, sh[1] + 5), ((sh[0] + el[0]) / 2 + 2, (sh[1] + el[1]) / 2), (el[0] + 2, el[1] - 3)], 0.7)
    ln(a, [(sh[0] - 3, sh[1] + 8), ((sh[0] + el[0]) / 2 - 3, (sh[1] + el[1]) / 2 + 2)], 0.55, LINE, 0.55)
    a.fill(a.ellipse(el[0] - 0.4, el[1] + 0.4, 3.0, 3.2), LINE, 0.22)
    ln(a, [(el[0] - 1, el[1] + 3), ((el[0] + hd[0]) / 2, (el[1] + hd[1]) / 2 + 2), (hd[0] - 2, hd[1] + 2)], 0.6, LINE, 0.7)
    ln(a, [(el[0] + 2, el[1] + 1), ((el[0] + hd[0]) / 2 + 1, (el[1] + hd[1]) / 2 - 1.5), (hd[0] - 3, hd[1] - 2.4)], 0.55, LINE, 0.6)
    d = np.array(hd, float) - np.array(el, float)
    d /= np.linalg.norm(d)
    h = hand_mask(a, hd, tuple(d), r['grip_n'])
    flat(a, h, SKIN_BASE)
    _hand_lines(a, hd, tuple(d), r['grip_n'])
    return finish(a)


def L_head(r):
    a = new()
    H = head_masks(a, r)
    hx, hy = r['head']
    flat(a, H['ear'], SKIN_BASE)
    flat(a, H['skull'], SKIN_BASE)
    flat(a, H['nose'], SKIN_BASE)
    ink = '#1d1414'
    # brows, eyes (far eye smaller and narrower: the head is turned), nose shadow line, mouth, chin, ear
    ln(a, [(hx + 0.4 * HS, hy - 3.4 * HS), (hx + 3.0 * HS, hy - 4.2 * HS), (hx + 5.6 * HS, hy - 3.6 * HS)], 1.1, ink, 0.85)
    ln(a, [(hx + 6.6 * HS, hy - 3.6 * HS), (hx + 8.2 * HS, hy - 3.2 * HS)], 0.9, ink, 0.8)
    a.fill(a.ellipse(hx + 3.0 * HS, hy - 1.4 * HS, 1.9, 1.15), '#f4f4f4')
    a.fill(a.ellipse(hx + 3.6 * HS, hy - 1.4 * HS, 0.95, 0.95), ink)
    a.fill(a.ellipse(hx + 7.2 * HS, hy - 1.2 * HS, 1.1, 0.95), '#f4f4f4')
    a.fill(a.ellipse(hx + 7.5 * HS, hy - 1.2 * HS, 0.5, 0.6), ink)
    ln(a, [(hx + 1.6 * HS, hy - 1.9 * HS), (hx + 3.2 * HS, hy - 2.3 * HS), (hx + 4.6 * HS, hy - 1.8 * HS)], 0.5, ink, 0.8)
    ln(a, [(hx + 6.4 * HS, hy - 1.8 * HS), (hx + 8.0 * HS, hy - 1.6 * HS)], 0.4, ink, 0.7)
    ln(a, [(hx + 5.8 * HS, hy - 0.6 * HS), (hx + 6.4 * HS, hy + 3.0 * HS), (hx + 7.6 * HS, hy + 4.4 * HS)], 0.6, LINE_D, 0.7)
    a.fill(a.ellipse(hx + 8.8 * HS, hy + 4.7 * HS, 0.7, 0.55), LINE_D, 0.8)
    a.fill(a.ellipse(hx + 6.8 * HS, hy + 4.8 * HS, 0.6, 0.5), LINE_D, 0.8)
    ln(a, [(hx + 3.2 * HS, hy + 7.3 * HS), (hx + 5.4 * HS, hy + 7.0 * HS), (hx + 7.8 * HS, hy + 6.7 * HS)], 0.7, '#4a2f2f', 0.9)
    ln(a, [(hx + 4.0 * HS, hy + 7.9 * HS), (hx + 6.2 * HS, hy + 7.8 * HS)], 0.4, LINE, 0.5)
    ln(a, [(hx + 2.6 * HS, hy + 9.4 * HS), (hx + 5.2 * HS, hy + 9.1 * HS)], 0.5, LINE, 0.4)
    ln(a, [(hx + 0.4 * HS, hy + 6.6 * HS), (hx + 1.6 * HS, hy + 9.0 * HS)], 0.4, LINE, 0.5)
    ln(a, [(hx - 7.0 * HS, hy - 0.6 * HS), (hx - 6.0 * HS, hy + 2.8 * HS)], 0.5, LINE_D, 0.8)
    ln(a, [(hx - 2.2 * HS, hy + 3.5 * HS), (hx - 1.0 * HS, hy + 8.0 * HS)], 0.5, LINE, 0.4)                                                  # cheek / jaw line
    return finish(a)


def L_hair(r):
    a = new()
    hx, hy = r['head']
    m = blob(a, [(hx - 8.8 * HS, hy + 2.0 * HS), (hx - 9.0 * HS, hy - 6.0 * HS), (hx - 4.5 * HS, hy - 10.8 * HS), (hx + 2.5 * HS, hy - 10.4 * HS), (hx + 7.6 * HS, hy - 6.4 * HS), (hx + 8.2 * HS, hy - 3.6 * HS),
                 (hx + 4.8 * HS, hy - 5.4 * HS), (hx + 0.5 * HS, hy - 5.0 * HS), (hx - 3.4 * HS, hy - 3.0 * HS), (hx - 4.8 * HS, hy + 0.6 * HS), (hx - 5.8 * HS, hy + 4.4 * HS), (hx - 8.0 * HS, hy + 5.2 * HS)], 8)
    flat(a, m, '#8c8c8c')
    for i in range(6):
        ln(a, [(hx - 6 * HS + i * 2.5, hy - 9.4 * HS + abs(i - 2.5) * 0.4), (hx - 4 * HS + i * 2.7, hy - 6.2 * HS)], 0.4, '#5c5c5c', 0.8, smooth=False)
    return finish(a, 0.9, (0.06, 0.05, 0.05))


# ------------------------------------------------------------------------------------------------ compose + export
def tinted(im, rgb):
    arr = np.asarray(im).astype(np.float32) / 255.0
    arr[..., :3] = np.clip(arr[..., :3] * np.asarray(rgb, np.float32)[None, None, :], 0, 1)
    return Image.fromarray((arr * 255 + 0.5).astype(np.uint8), 'RGBA')


def layers(pose):
    r = POSES[pose]
    return {'shadow': L_shadow(), 'arm_far': L_arm_far(r), 'leg_far': L_leg(r, 'n'), 'leg_near': L_leg(r, 'f'), 'torso': L_torso(r),
            'underwear': L_underwear(r), 'head': L_head(r), 'hair': L_hair(r), 'arm_near': L_arm_near(r)}


ORDER = ['shadow', 'arm_far', 'leg_far', 'leg_near', 'torso', 'underwear', 'head', 'hair', 'arm_near']
SKIN_LAYERS = {'arm_far', 'leg_far', 'leg_near', 'torso', 'head', 'arm_near'}


def compose(pose, skin='tan_white', hair_rgb=(0.42, 0.30, 0.22), lay=None):
    lay = lay or layers(pose)
    cv = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    for k in ORDER:
        im = lay[k]
        if k in SKIN_LAYERS:
            im = tinted(im, SKINS[skin])
        elif k == 'hair':
            im = tinted(im, hair_rgb)
        cv.alpha_composite(im)
    return cv


def down(im):
    """128 master -> 64 game sprite (area resample, premultiplied so edges stay clean)"""
    arr = np.asarray(im).astype(np.float32) / 255.0
    a = arr[..., 3:4]
    pm = arr[..., :3] * a
    pm = pm.reshape(64, 2, 64, 2, 3).mean(axis=(1, 3))
    al = a.reshape(64, 2, 64, 2, 1).mean(axis=(1, 3))
    rgb = pm / np.maximum(al, 1e-4)
    out = np.dstack([np.clip(rgb, 0, 1), al])
    return Image.fromarray((out * 255 + 0.5).astype(np.uint8), 'RGBA')
