"""Melee weapons for the 64px tileset: 25 designs x 3 grades (plain, forged '_f', masterwork '_m'), side view, tip to the right."""
import numpy as np
from PIL import Image
from art64 import Art, col, lit, mix
from t64_guns import rng_for, led

GRADES = {
    '': dict(steel='#a9b3bf', steel2='#7c8794', brass='#9c8c6a', wrap='#4f5f70', wrap2='#33404d', wood='#7e5c3a', wood2='#4f3822', gem=None),
    '_f': dict(steel='#d3dbe5', steel2='#9aa6b4', brass='#d3ac58', wrap='#8c2f33', wrap2='#5a1c20', wood='#5c3b28', wood2='#3a2418', gem=None),
    '_m': dict(steel='#eaf5ff', steel2='#b4c9dc', brass='#f2d070', wrap='#1a1c24', wrap2='#0c0d12', wood='#2f2530', wood2='#181119', gem='#35d7ff'),
}


def A():
    return Art(64, 64, 4)


class P:
    def __init__(self, it, grade, a):
        self.it = it
        self.grade = grade
        self.g = GRADES[grade]
        self.r = rng_for(it['id'])
        self.a = a
        L = it['length_mm']
        self.n = float(np.clip(L / 1800 * 50 + 12, 18, 60))
        self.x0 = 32 - self.n / 2
        self.y = 32.0


def paint(a, m, c, bevel=1.4, strength=0.9, spec=0.5, grain=0.0, **kw):
    a.shade(m, c, bevel=bevel, strength=strength, spec=spec, grain=grain, **kw)


def blade(p, x0, x1, y, w_base, w_tip, curve=0.0, taper_from=0.0, point=3.0, fuller=False, edge_down=True, double=False):
    """a blade from x0 to x1 about y; curve bows the tip up; returns the full mask"""
    a, g = p.a, p.g
    n = 16
    top, bot, mid = [], [], []
    for i in range(n + 1):
        t = i / n
        x = x0 + (x1 - x0) * t
        w = w_base + (w_tip - w_base) * max(0.0, (t - taper_from) / (1 - taper_from)) ** 1.2
        if t > 1 - point / (x1 - x0):
            k = (1 - t) / (point / (x1 - x0))
            w *= max(k, 0.05)
        cy = y - curve * t * t
        mid.append((x, cy))
        top.append((x, cy - w * (0.5 if double else 0.28)))
        bot.append((x, cy + w * 0.5))
    full = a.poly(top + bot[::-1])
    a.shadow(full, 1.4, 2.0, 1.6, 0.45)
    # spine half (darker) and edge half (lighter, the bevel)
    spine = a.poly(top + mid[::-1])
    edge = a.poly(mid + bot[::-1])
    paint(a, full, g['steel2'], bevel=1.8, strength=0.8, spec=0.7)
    paint(a, edge, g['steel'], bevel=1.1, strength=0.9, spec=0.9)
    if p.grade:
        # temper line: a wavy lighter band between the halves
        for i in range(n):
            t = i / n
            (xa, ya), (xb, yb) = mid[i], mid[i + 1]
            wav = np.sin(t * 38 + p.r.random()) * 0.5
            a.fill(a.line(xa, ya + 0.7 + wav * 0.25, xb, yb + 0.7 + wav * 0.25, 0.55), '#ffffff', 0.7)
    if p.grade == '_m':
        # mirror polish glint + cyan edge light
        for i in range(n):
            (xa, ya), (xb, yb) = bot[i], bot[i + 1]
            a.fill(a.line(xa, ya - 0.2, xb, yb - 0.2, 0.7), '#35d7ff', 0.85)
        a.glow((x0 + x1) / 2, y + 1, (x1 - x0) / 2.6, '#35d7ff', 0.14)
    if fuller:
        for i in range(2, n - 2):
            (xa, ya), (xb, yb) = mid[i], mid[i + 1]
            a.fill(a.line(xa, ya - 0.1, xb, yb - 0.1, 0.9), '#5d6773', 0.8)
    return full


def handle(p, x0, x1, y, w=3.8, wrap=True, color=None, ends=True):
    a, g = p.a, p.g
    m = a.rrect(x0, y - w / 2, x1 - x0, w, w * 0.4)
    a.shadow(m, 1.2, 1.6, 1.4, 0.4)
    paint(a, m, g['wrap'] if color is None else color, bevel=1.4, strength=0.95, spec=0.2, grain=0.35, seed=3)
    if wrap:
        k = x0 + 0.8
        j = 0
        while k < x1 - 0.8:
            a.fill(a.line(k, y - w * 0.45, k + 1.3, y + w * 0.45, 0.45), g['wrap2'], 0.8)
            a.fill(a.line(k + 1.3, y - w * 0.45, k, y + w * 0.45, 0.45), g['wrap2'], 0.6)
            k += 1.7
    return m


def guard(p, x, y, h=9.0, w=2.2, kind='disc'):
    a, g = p.a, p.g
    if kind == 'disc':
        m = a.ellipse(x, y, w, h / 2)
    elif kind == 'bar':
        m = a.rrect(x - w / 2, y - h / 2, w, h, 1.0)
    else:
        m = a.poly([(x - w / 2, y - h / 2), (x + w / 2, y - h / 2 + 1), (x + w / 2, y + h / 2 - 1), (x - w / 2, y + h / 2)])
    a.shadow(m, 1.0, 1.4, 1.2, 0.35)
    paint(a, m, g['brass'], bevel=1.2, strength=1.0, spec=0.9)
    if p.grade == '_m':
        a.fill(a.ellipse(x, y, 0.8), g['gem'], 1.0)
    return m


def pommel(p, x, y, r=2.0):
    a, g = p.a, p.g
    m = a.ellipse(x, y, r, r * 0.9)
    paint(a, m, g['brass'], bevel=r * 0.7, strength=1.0, spec=0.9)
    if p.grade == '_m':
        led(a, x, y, g['gem'], 0.7, 5)


def pole(p, x0, x1, y, w=2.8, color=None, tip_cap=True):
    a, g = p.a, p.g
    m = a.rrect(x0, y - w / 2, x1 - x0, w, w * 0.5)
    a.shadow(m, 1.2, 1.6, 1.4, 0.4)
    paint(a, m, g['wood'] if color is None else color, bevel=1.3, strength=0.95, spec=0.25, grain=0.55, seed=5)
    for k in np.arange(x0 + 3, x1 - 2, 5.5):
        a.fill(a.line(k, y - w * 0.4, k + 0.6, y + w * 0.4, 0.3), g['wood2'], 0.6)
    return m


# ------------------------------------------------------------------------------------------------ designs
def sword(p, length_frac=1.0, curve=2.5, width=4.4, tsuba='disc', double=False, fuller=False, sheath=False, pom=True, hilt_frac=0.24):
    n, x0, y = p.n, p.x0, p.y
    hl = n * hilt_frac
    handle(p, x0, x0 + hl, y + 1.0, 3.6)
    if pom:
        pommel(p, x0 - 0.6, y + 1.0, 2.0)
    if tsuba:
        guard(p, x0 + hl, y + 0.6, 8.0, 2.0, tsuba)
    blade(p, x0 + hl + 1, x0 + n, y, width, width * 0.55, curve=curve, taper_from=0.35, point=5.0, fuller=fuller, double=double)


def d_katana(p): sword(p, curve=3.0, width=4.4)
def d_wakizashi(p): sword(p, curve=2.0, width=4.0, hilt_frac=0.26)
def d_nodachi(p): sword(p, curve=4.5, width=4.8, hilt_frac=0.26)
def d_shashka(p):
    n, x0, y = p.n, p.x0, p.y
    hl = n * 0.2
    handle(p, x0, x0 + hl, y + 2.2, 3.4, color=p.g['wood'], wrap=False)
    # hilt with a drooping knob, no guard
    a = p.a
    m = a.poly([(x0 + hl, y + 0.4), (x0 + hl + 1.6, y + 0.4), (x0 + hl + 1.6, y + 4.2), (x0 + hl, y + 4.2)])
    paint(a, m, p.g['brass'], bevel=0.8)
    pommel(p, x0 - 0.8, y + 3.2, 2.4)
    blade(p, x0 + hl + 1.6, x0 + n, y, 4.0, 3.0, curve=3.2, taper_from=0.4, point=4.0)


def d_tanto(p): sword(p, curve=0.3, width=3.8, tsuba='bar', hilt_frac=0.32, pom=False)
def d_kinzhal(p): sword(p, curve=0.8, width=4.8, tsuba='bar', double=True, fuller=True, hilt_frac=0.28)


def d_finka(p):
    n, x0, y = p.n, p.x0, p.y
    a = p.a
    hl = n * 0.34
    m = a.rrect(x0, y - 0.6, hl, 4.4, 1.4)
    a.shadow(m, 1.2, 1.6, 1.4, 0.4)
    paint(a, m, p.g['wood'], bevel=1.6, strength=0.9, spec=0.3, grain=0.5, seed=4)
    for k in range(5):
        a.fill(a.rect(x0 + 1.5 + k * hl / 6, y - 0.4, 0.5, 4.0), p.g['wood2'], 0.8)
    guard(p, x0 + hl, y + 1.6, 6.6, 1.8, 'bar')
    blade(p, x0 + hl + 1, x0 + n, y + 1.4, 4.4, 3.0, curve=0.0, taper_from=0.5, point=5.0, fuller=True)
    pommel(p, x0 - 0.2, y + 1.6, 1.8)


def d_kunai(p):
    n, x0, y = p.n, p.x0, p.y
    a = p.a
    ring = a.ellipse(x0 + 3, y, 3.4)
    a.shadow(ring, 1, 1.4, 1.2, 0.35)
    a.fill(ring, p.g['steel2'])
    a.fill(a.ellipse(x0 + 3, y, 1.9), '#00000000') if False else None
    paint(a, ring, p.g['steel2'], bevel=1.0, spec=0.8)
    a.fill(a.ellipse(x0 + 3, y, 1.8), '#0a0b0d', 0.0)
    a.fill(a.ellipse(x0 + 3, y, 1.8), '#1a1c20', 1.0)
    handle(p, x0 + 6, x0 + 14, y, 2.4)
    blade(p, x0 + 14, x0 + n, y, 6.0, 1.0, taper_from=0.0, point=7.0, fuller=True, double=True)


def d_kama(p):
    n, x0, y = p.n, p.x0, p.y
    a = p.a
    pole(p, x0, x0 + n * 0.74, y + 6, 3.0)
    pommel(p, x0, y + 6, 1.8)
    ex = x0 + n * 0.74
    # sickle blade: a hook rising from the shaft end
    pts_out, pts_in = [], []
    for i in range(14):
        t = i / 13
        ang = -0.2 - t * 2.6
        r_o = 11.0
        cx, cy = ex + 1.0, y + 6 - 9.0
        pts_out.append((cx + np.cos(ang + 1.2) * r_o * (1 - 0.1 * t), cy + np.sin(ang + 1.2) * r_o * (1 - 0.1 * t)))
        pts_in.append((cx + np.cos(ang + 1.2) * (r_o - 3.4 * (1 - t * 0.85)), cy + np.sin(ang + 1.2) * (r_o - 3.4 * (1 - t * 0.85))))
    m = a.poly(pts_out + pts_in[::-1])
    a.shadow(m, 1.4, 2, 1.6, 0.45)
    paint(a, m, p.g['steel'], bevel=1.5, strength=0.95, spec=0.9)
    guard(p, ex, y + 6, 6, 1.6, 'bar')
    if p.grade == '_m':
        for (u, v), (s, t) in zip(pts_in, pts_in[1:]):
            a.fill(a.line(u, v, s, t, 0.7), '#35d7ff', 0.85)


def d_kusarigama(p):
    n, x0, y = p.n, p.x0, p.y
    a = p.a
    pole(p, x0, x0 + n * 0.4, y + 7, 2.6)
    ex = x0 + n * 0.4
    a.shade(a.rrect(ex - 1, y + 5.4, 3, 3.2, 0.8), p.g['brass'], bevel=0.8, spec=0.8)
    pts_out, pts_in = [], []
    for i in range(12):
        t = i / 11
        ang = -0.2 - t * 2.4
        cx, cy = ex + 1.0, y + 7 - 7.0
        pts_out.append((cx + np.cos(ang + 1.2) * 9, cy + np.sin(ang + 1.2) * 9))
        pts_in.append((cx + np.cos(ang + 1.2) * (9 - 3.0 * (1 - t * 0.85)), cy + np.sin(ang + 1.2) * (9 - 3.0 * (1 - t * 0.85))))
    m = a.poly(pts_out + pts_in[::-1])
    a.shadow(m, 1.4, 2, 1.6, 0.45)
    paint(a, m, p.g['steel'], bevel=1.3, strength=0.95, spec=0.9)
    # chain with a weight, loosely curled below
    prev = (x0 + 3, y + 8)
    for k in range(1, 15):
        t = k / 14
        pt = (x0 + 3 + t * (n - 8), y + 11 + np.sin(t * 5.5) * 2.4)
        a.fill(a.line(prev[0], prev[1], pt[0], pt[1], 1.3), '#6d7682', 1.0)
        a.fill(a.ellipse(pt[0], pt[1], 0.9), '#aab4c0', 1.0)
        prev = pt
    w = a.ellipse(prev[0] + 1.5, prev[1], 3.4)
    a.shadow(w, 1.2, 1.6, 1.4, 0.4)
    paint(a, w, '#3a3f47', bevel=2.6, spec=0.8)


def _spearhead(p, x, y, length, wide, curve=0.0, kind='leaf'):
    a, g = p.a, p.g
    if kind == 'leaf':
        pts = [(x, y - 1.0), (x + length * 0.25, y - wide / 2), (x + length * 0.6, y - wide * 0.38), (x + length, y), (x + length * 0.6, y + wide * 0.38), (x + length * 0.25, y + wide / 2), (x, y + 1.0)]
    else:   # naginata: single-edged, curved
        pts = [(x, y - 1.2), (x + length * 0.5, y - wide * 0.34 - curve * 0.25), (x + length, y - curve), (x + length * 0.5, y + wide * 0.5 - curve * 0.15), (x, y + 1.2)]
    m = a.poly(pts)
    a.shadow(m, 1.4, 2, 1.6, 0.45)
    paint(a, m, g['steel'], bevel=1.7, strength=0.95, spec=0.9)
    a.fill(a.line(x + 1, y, x + length * 0.9, y - (curve if kind != 'leaf' else 0), 0.6), g['steel2'], 0.8)
    if p.grade == '_m':
        a.fill(a.line(x + 1, y + 0.4, x + length * 0.9, y - (curve if kind != 'leaf' else 0) + 0.4, 0.5), '#35d7ff', 0.9)
        a.glow(x + length / 2, y, length / 2, '#35d7ff', 0.14)


def d_naginata(p):
    n, x0, y = p.n, p.x0, p.y
    pole(p, x0, x0 + n - 14, y + 1.0, 2.8)
    pommel(p, x0, y + 1.0, 1.9)
    guard(p, x0 + n - 14, y + 1.0, 6.4, 1.8, 'disc')
    for k in range(3):
        a = p.a
        a.fill(a.rect(x0 + n * 0.12 + k * 1.6, y - 0.4, 0.7, 2.8), p.g['wrap'], 0.95)
    _spearhead(p, x0 + n - 13, y + 1.0, 13, 5.6, curve=3.2, kind='curved')


def d_yari(p):
    n, x0, y = p.n, p.x0, p.y
    pole(p, x0, x0 + n - 12, y, 2.8)
    pommel(p, x0, y, 1.9)
    guard(p, x0 + n - 12, y, 5.4, 1.8, 'disc')
    _spearhead(p, x0 + n - 11, y, 11, 4.6)


def d_bo(p):
    n, x0, y = p.n, p.x0, p.y
    pole(p, x0, x0 + n, y, 3.2)
    for k in (0, 1):
        x = x0 + (n - 3.2) * k
        a = p.a
        paint(a, a.rrect(x, y - 1.8, 3.2, 3.6, 1.0), p.g['brass'], bevel=1.0, spec=0.8)
    for x in (n * 0.35, n * 0.65):
        p.a.fill(p.a.rect(x0 + x, y - 1.6, 2.4, 3.2), p.g['wrap'], 0.95)


def d_jo(p):
    n, x0, y = p.n, p.x0, p.y
    pole(p, x0, x0 + n, y, 2.8, color=lit(p.g['wood'], 1.15))
    for k in (0, 1):
        x = x0 + (n - 2.4) * k
        p.a.shade(p.a.rrect(x, y - 1.6, 2.4, 3.2, 0.8), p.g['brass'], bevel=0.8, spec=0.8)


def d_nunchaku(p):
    n, x0, y = p.n, p.x0, p.y
    a = p.a
    s = n * 0.38
    m1 = a.rrect(x0 + 2, y + 3, s, 3.6, 1.6)
    m2 = a.rrect(x0 + n - s - 2, y - 7, s, 3.6, 1.6)
    a.shadow(m1 | m2, 1.2, 1.6, 1.4, 0.4)
    paint(a, m1, p.g['wood'], bevel=1.4, spec=0.3, grain=0.5, seed=3)
    paint(a, m2, p.g['wood'], bevel=1.4, spec=0.3, grain=0.5, seed=4)
    prev = (x0 + 2 + s, y + 4.8)
    end = (x0 + n - s - 2, y - 5.2)
    for k in range(1, 7):
        t = k / 6
        pt = (prev[0] + (end[0] - prev[0]) * t, prev[1] + (end[1] - prev[1]) * t + np.sin(t * 3.14) * 3)
        a.fill(a.ellipse(pt[0], pt[1], 1.0), '#b8c2cc', 1.0)
    for x in (x0 + 2 + s - 0.8, x0 + n - s - 2 + 0.8):
        a.fill(a.ellipse(x, y + 4.8 if x < 32 else y - 5.2, 1.5), p.g['brass'], 1.0)
    for m in (m1, m2):
        pass
    a.fill(a.rect(x0 + 3.2, y + 3.2, 1.2, 3.2), p.g['wrap'], 0.9)
    a.fill(a.rect(x0 + n - 4.4, y - 6.8, 1.2, 3.2), p.g['wrap'], 0.9)


def d_sai(p):
    n, x0, y = p.n, p.x0, p.y
    a = p.a
    handle(p, x0, x0 + n * 0.28, y, 3.2)
    pommel(p, x0 - 0.5, y, 1.8)
    # cross guard with two tines
    cg = a.rrect(x0 + n * 0.28, y - 6.8, 2.4, 13.6, 1.0)
    a.shadow(cg, 1, 1.4, 1.2, 0.4)
    paint(a, cg, p.g['steel2'], bevel=1.0, spec=0.9)
    for s in (-1, 1):
        t = a.poly([(x0 + n * 0.28, y + s * 6.6), (x0 + n * 0.28 + 1.5, y + s * 7.2), (x0 + n * 0.28 + 10, y + s * 6.4), (x0 + n * 0.28 + 10, y + s * 5.4), (x0 + n * 0.28 + 1.5, y + s * 5.2)])
        a.shadow(t, 1, 1.4, 1.2, 0.35)
        paint(a, t, p.g['steel'], bevel=0.9, spec=0.9)
    blade(p, x0 + n * 0.28 + 2, x0 + n, y, 2.8, 1.6, taper_from=0.6, point=3.5)


def d_jitte(p):
    n, x0, y = p.n, p.x0, p.y
    a = p.a
    handle(p, x0, x0 + n * 0.28, y + 0.6, 3.0)
    pommel(p, x0 - 0.5, y + 0.6, 1.7)
    hk = a.poly([(x0 + n * 0.28, y - 1.4), (x0 + n * 0.28 + 1.4, y - 7.0), (x0 + n * 0.28 + 4.0, y - 7.0), (x0 + n * 0.28 + 3.4, y - 1.4)])
    a.shadow(hk, 1, 1.4, 1.2, 0.35)
    paint(a, hk, p.g['steel2'], bevel=0.9, spec=0.9)
    guard(p, x0 + n * 0.28, y + 0.6, 6.4, 1.8, 'bar')
    blade(p, x0 + n * 0.28 + 1, x0 + n, y + 0.6, 2.8, 2.2, taper_from=0.8, point=2.0)
    a.fill(a.line(x0 + n * 0.4, y + 0.6, x0 + n - 3, y + 0.6, 0.6), p.g['brass'], 0.0)


def d_tessen(p):
    n, x0, y = p.n, p.x0, p.y
    a = p.a
    cx, cy = x0 + 6, y + 6
    ribs = []
    for k in range(9):
        ang = -2.5 + k * 0.5
        ex, ey = cx + np.cos(ang) * (n * 0.78), cy + np.sin(ang) * (n * 0.78)
        ribs.append((ex, ey))
    fan = a.poly([(cx, cy)] + ribs)
    a.shadow(fan, 1.6, 2.2, 1.8, 0.45)
    for k in range(8):
        sub = a.poly([(cx, cy), ribs[k], ribs[k + 1]])
        paint(a, sub, lit(p.g['steel'], 1.1 if k % 2 else 0.9), bevel=1.0, strength=0.9, spec=0.8)
    for e in ribs:
        a.fill(a.line(cx, cy, e[0], e[1], 0.7), p.g['steel2'], 0.9)
    a.fill(a.ellipse(cx, cy, 2.2), p.g['brass'], 1.0)
    if p.grade == '_m':
        a.fill(a.ellipse(cx, cy, 1.0), p.g['gem'], 1.0)
        a.glow(cx + n * 0.3, cy - n * 0.3, n * 0.5, '#35d7ff', 0.12)


def _axe_head(p, x, y, size, kind='single'):
    a, g = p.a, p.g
    if kind == 'single':
        pts = [(x, y - 1.8), (x + 3.4, y - 1.8), (x + size * 0.7, y - size * 0.6), (x + size, y - size * 0.7), (x + size * 1.02, y + size * 0.7), (x + size * 0.7, y + size * 0.6), (x + 3.4, y + 1.8), (x, y + 1.8)]
    m = a.poly(pts)
    a.shadow(m, 1.5, 2.2, 1.8, 0.45)
    paint(a, m, g['steel'], bevel=2.0, strength=0.95, spec=0.85)
    a.fill(a.line(x + size * 1.0, y - size * 0.6, x + size * 1.0, y + size * 0.6, 0.8), '#ffffff', 0.55)
    if p.grade == '_m':
        a.fill(a.line(x + size * 1.0, y - size * 0.62, x + size * 1.02, y + size * 0.65, 0.6), '#35d7ff', 0.95)
    return m


def d_ono(p):
    n, x0, y = p.n, p.x0, p.y
    pole(p, x0, x0 + n - 4, y, 3.0)
    pommel(p, x0, y, 1.9)
    for k in range(4):
        p.a.fill(p.a.rect(x0 + 3 + k * 1.6, y - 1.3, 0.7, 2.6), p.g['wrap'], 0.95)
    _axe_head(p, x0 + n - 11, y, 11)
    guard(p, x0 + n - 11, y, 5, 2.2, 'bar')


def d_topor(p):
    n, x0, y = p.n, p.x0, p.y
    pole(p, x0, x0 + n - 3, y + 0.5, 3.0)
    pommel(p, x0, y + 0.5, 1.9)
    _axe_head(p, x0 + n - 10, y + 0.5, 9)
    a = p.a
    a.fill(a.rect(x0 + n - 11, y - 2.5, 2, 6.4), p.g['steel2'], 0.95)


def d_chekan(p):
    n, x0, y = p.n, p.x0, p.y
    a = p.a
    pole(p, x0, x0 + n - 2, y + 1.0, 3.0)
    pommel(p, x0, y + 1.0, 1.9)
    hx0 = x0 + n - 14
    head = a.poly([(hx0, y - 2.2), (hx0 + 5, y - 2.4), (hx0 + 5, y + 4.4), (hx0, y + 4.2)])
    pick = a.poly([(hx0 + 5, y - 1.6), (hx0 + 13, y + 1.0), (hx0 + 5, y + 3.6)])
    a.shadow(head | pick, 1.5, 2.2, 1.8, 0.45)
    paint(a, pick, p.g['steel'], bevel=1.6, strength=0.95, spec=0.9)
    paint(a, head, p.g['steel2'], bevel=1.8, strength=0.95, spec=0.8)
    a.fill(a.rect(hx0 - 1.4, y - 2.8, 1.6, 7.6), p.g['steel'], 0.95)        # hammer face
    a.fill(a.rect(hx0 + 1.4, y - 0.4, 2.2, 3.6), '#0a0b0d', 0.7)           # eye
    if p.grade == '_m':
        a.fill(a.line(hx0 + 6, y + 1.0, hx0 + 12.5, y + 1.0, 0.6), '#35d7ff', 0.95)


def d_tonfa(p):
    n, x0, y = p.n, p.x0, p.y
    a = p.a
    m = a.rrect(x0, y + 1.2, n, 4.4, 1.8)
    a.shadow(m, 1.4, 2, 1.6, 0.45)
    paint(a, m, p.g['wood'], bevel=1.7, strength=0.95, spec=0.3, grain=0.55, seed=4)
    side = a.rrect(x0 + n * 0.22, y - 7, 3.4, 8.6, 1.4)
    paint(a, side, p.g['wood2'], bevel=1.4, spec=0.3, grain=0.5, seed=5)
    for x in (x0, x0 + n - 3):
        a.shade(a.rrect(x, y + 0.9, 3, 5.0, 1), p.g['brass'], bevel=0.9, spec=0.8)
    if p.grade == '_m':
        a.fill(a.rect(x0 + 5, y + 2.8, n - 12, 1.0), '#35d7ff', 0.95)
        a.glow(x0 + n * 0.5, y + 3.4, n * 0.4, '#35d7ff', 0.18)
    elif p.grade == '_f':
        a.fill(a.rect(x0 + 5, y + 2.8, n - 12, 0.8), p.g['brass'], 0.95)


def d_lopata(p):
    n, x0, y = p.n, p.x0, p.y
    a = p.a
    pole(p, x0 + 3, x0 + n - 14, y + 1, 3.0)
    t = a.rrect(x0, y - 4.4, 3.6, 10.8, 1.4)
    paint(a, t, p.g['wood'], bevel=1.4, spec=0.3, grain=0.5, seed=6)
    ex = x0 + n - 15
    blade_m = a.poly([(ex, y - 1.2), (ex + 4, y - 6.4), (ex + 15, y - 6.4), (ex + 15.8, y + 8.4), (ex + 4, y + 8.4), (ex, y + 3.2)])
    a.shadow(blade_m, 1.5, 2.2, 1.8, 0.45)
    paint(a, blade_m, p.g['steel'], bevel=2.0, strength=0.95, spec=0.85, grain=0.15, seed=7)
    a.fill(a.rect(ex + 5, y + 0.5, 8, 1.2), p.g['steel2'], 0.9)                 # rib
    a.fill(a.rect(ex + 15, y - 6.4, 0.9, 14.8), '#ffffff', 0.55)
    if p.grade == '_m':
        a.fill(a.rect(ex + 15, y - 6.4, 0.9, 14.8), '#35d7ff', 0.95)
    guard(p, ex + 1, y + 1.0, 5.0, 2.0, 'bar')


def d_kistien(p):
    n, x0, y = p.n, p.x0, p.y
    a = p.a
    pole(p, x0, x0 + n * 0.46, y + 4, 3.0, color=p.g['wood'])
    pommel(p, x0, y + 4, 1.9)
    ex = x0 + n * 0.46
    a.shade(a.rrect(ex - 1, y + 2.6, 3, 3.6, 0.8), p.g['brass'], bevel=0.8, spec=0.8)
    prev = (ex + 1.5, y + 4)
    for k in range(1, 7):
        t = k / 6
        pt = (ex + 2 + t * n * 0.26, y + 4 - np.sin(t * 3.0) * 3.6)
        a.fill(a.line(prev[0], prev[1], pt[0], pt[1], 1.4), '#6a7480', 1.0)
        a.fill(a.ellipse(pt[0], pt[1], 1.0), '#b0bac4', 1.0)
        prev = pt
    ball = a.ellipse(prev[0] + 3, prev[1], 5.0)
    a.shadow(ball, 1.5, 2.2, 1.8, 0.5)
    paint(a, ball, '#4a4f58', bevel=4.0, strength=1.0, spec=0.9, grain=0.2)
    for ang in np.linspace(0, 6.283, 9)[:-1]:
        tx, ty = prev[0] + 3 + np.cos(ang) * 5.4, prev[1] + np.sin(ang) * 5.4
        sp = a.poly([(tx - np.sin(ang) * 1.3 + np.cos(ang) * 0.0, ty + np.cos(ang) * 1.3), (tx + np.sin(ang) * 1.3, ty - np.cos(ang) * 1.3), (tx + np.cos(ang) * 3.4, ty + np.sin(ang) * 3.4)])
        paint(a, sp, p.g['steel'], bevel=0.8, spec=0.9)


def d_kastet(p):
    n, x0, y = p.n, p.x0, p.y
    a = p.a
    cx = 32
    body = a.rrect(cx - 11, y - 2, 22, 6.4, 3.0)
    a.shadow(body, 1.4, 2, 1.6, 0.45)
    paint(a, body, p.g['steel2'], bevel=2.6, strength=0.95, spec=0.9)
    for k in range(4):
        x = cx - 8.4 + k * 5.6
        ring = a.ellipse(x, y + 8, 3.0, 3.4)
        paint(a, ring, p.g['steel'], bevel=1.6, strength=0.95, spec=0.9)
        a.fill(a.ellipse(x, y + 8, 1.6, 2.0), '#0a0b0d', 0.95)
        a.fill(a.line(x, y + 2, x, y + 5, 2.0), p.g['steel'], 1.0)
        spike = a.poly([(x - 1.0, y - 2), (x + 1.0, y - 2), (x, y - 5.0)])
        paint(a, spike, p.g['steel'], bevel=0.7, spec=0.9)
    guard(p, cx, y + 15, 4, 18, 'bar') if False else None
    a.shade(a.rrect(cx - 11, y + 14, 22, 2.4, 1.0), p.g['brass'], bevel=0.8, spec=0.8)
    if p.grade == '_m':
        for k in range(4):
            led(a, cx - 8.4 + k * 5.6, y - 0.4, p.g['gem'], 0.6, 4)


DRAW = {k[2:]: v for k, v in list(globals().items()) if k.startswith('d_')}
# where the hand takes the weapon, as a fraction of its length from the butt (for the top-down hold sprite)
GRIP = {'naginata': 0.30, 'yari': 0.30, 'bo': 0.5, 'jo': 0.5, 'kusarigama': 0.25, 'kistien': 0.2, 'kama': 0.3, 'ono': 0.3, 'topor': 0.3, 'chekan': 0.3,
        'lopata': 0.3, 'tonfa': 0.3, 'kastet': 0.5, 'nunchaku': 0.3}


def melee_icon(base_id, it, grade):
    a = A()
    p = P(it, grade, a)
    DRAW[base_id](p)
    return a.image(outline=0.85, fit=58, zmax=2.0)
