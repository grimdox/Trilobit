"""Held sprites for every gun, melee weapon and tool in data/items.json, for the standing dolls.  Drawn in the
approved G1-G3 / P1-P2 language (t64_wear): crisp parts laid along the hold, a flat tone per part, a lit top edge and
a shaded underside.

Guns: one template per class, coloured by the maker's palette (t64_guns.MAKER) and varied per model from its id
(stock, magazine, optic, muzzle, barrel length), length from length_mm.  Rifles and longer guns are held across the
body; pistols and revolvers at low ready, muzzle down.
Melee: one drawing per weapon type in three grades: plain steel, forged (dark body, bright edge line), masterwork
(brass fittings, coloured wrap).  Long hafts and swords are held across the body, short blades and one-hand weapons
low, kastet over the fist (z above the hands).
Tools: the field repair kit and the trauma patch, held low."""
import hashlib, random, math
import numpy as np
import t64_figure as F
import t64_wear as W
import t64_kit as K
from t64_figure import A, col, lit, mix, px, crisp
from t64_wear import Hold, gpart, PISTOL_DOWN

B = -1.6                                     # bore line across the hold


def rng(s):
    return random.Random(int(hashlib.md5(s.encode()).hexdigest()[:8], 16))


def maker_palette(it):
    from t64_guns import MAKER
    code = it['name'].split(' ')[0]
    mk = MAKER.get(code[0], MAKER['G'])
    return {'body': K.ramp_from(mk['body']), 'trim': K.ramp_from(mk['trim']), 'acc': mk['acc'],
            'wood': W.WOOD if code[0] in 'VZ' else K.ramp_from(mk['wood']), 'steel': W.STEEL, 'code': code}


def P(a, h, pts, ramp, top=None):
    return gpart(a, h, pts, ramp, top)


def rect(a, h, s0, s1, n0, n1, ramp, top=None):
    return gpart(a, h, [(s0, n0), (s1, n0), (s1, n1), (s0, n1)], ramp, top)


def strip(a, h, s0, s1, n, c, w=0.6):
    p0, p1 = h.p(s0, n), h.p(s1, n)
    a.fill(a.line(p0[0], p0[1], p1[0], p1[1], w), c)


# ------------------------------------------------------------------------------------------------ gun parts
def stock(a, h, kind, s_end, pal):
    if kind == 'wood':
        P(a, h, [(s_end, B - 1.0), (-2.5, B - 1.2), (-2.5, B + 1.6), (s_end + 1.0, B + 3.0), (s_end, B + 2.8)], pal['wood'])
    elif kind == 'poly':
        P(a, h, [(s_end, B - 1.2), (-2.5, B - 1.2), (-2.5, B + 1.4), (s_end + 0.8, B + 2.6), (s_end, B + 2.6)], pal['trim'])
        rect(a, h, s_end, s_end + 0.8, B - 1.2, B + 2.6, W.STEEL)                         # butt pad
    elif kind == 'skeleton':
        for n in (B - 1.0, B + 2.0):
            rect(a, h, s_end, -2.5, n - 0.4, n + 0.4, pal['trim'])
        rect(a, h, s_end, s_end + 1.0, B - 1.4, B + 2.6, pal['trim'])
    elif kind == 'wire':
        for n in (B - 0.8, B + 1.0):
            rect(a, h, s_end, -2.0, n - 0.35, n + 0.35, W.STEEL)
        rect(a, h, s_end - 0.6, s_end + 0.4, B - 1.0, B + 1.6, W.STEEL)


def magazine(a, h, kind, s0, pal, length=6.0):
    if kind == 'curved':
        P(a, h, [(s0, B + 1.2), (s0 + 3.2, B + 1.2), (s0 + 3.8, B + 4.0), (s0 + 2.6, B + 1.2 + length), (s0 + 0.4, B + length), (s0 + 1.0, B + 3.6)], W.STEEL)
    elif kind == 'straight':
        rect(a, h, s0, s0 + 2.4, B + 1.2, B + 1.2 + length, W.STEEL)
    elif kind == 'drum':
        c = h.p(s0 + 1.8, B + 4.2)
        m = a.ellipse(c[0], c[1], 3.4 * h.k, 3.4 * h.k)
        F.ramp_paint(a, m, W.STEEL, bevel=1.4, strength=1.0)
    elif kind == 'box':
        rect(a, h, s0, s0 + 4.6, B + 1.2, B + 5.6, pal['trim'])
        rect(a, h, s0, s0 + 4.6, B + 1.2, B + 2.0, W.STEEL)


def optic(a, h, kind, s0, pal):
    if kind == 'dot':
        rect(a, h, s0, s0 + 3.6, B - 3.2, B - 1.6, W.STEEL)
        px(a, *h.p(s0 + 1.8, B - 2.6), '#ff9a30')
    elif kind == 'scope':
        rect(a, h, s0 - 1.0, s0 + 8.0, B - 3.6, B - 2.0, W.STEEL)
        rect(a, h, s0 - 1.6, s0 - 0.6, B - 4.0, B - 1.6, W.STEEL)
        rect(a, h, s0 + 7.6, s0 + 8.6, B - 4.0, B - 1.6, W.STEEL)
        px(a, *h.p(s0 + 8.4, B - 2.8), '#5aa6c8')
    elif kind == 'holo':
        rect(a, h, s0, s0 + 3.0, B - 3.6, B - 1.6, pal['trim'])
        px(a, *h.p(s0 + 1.4, B - 2.8), '#35d7ff')


def muzzle(a, h, kind, s0, pal):
    if kind == 'brake':
        P(a, h, [(s0, B - 1.0), (s0 + 2.0, B - 0.7), (s0 + 2.0, B + 0.9), (s0, B + 0.9)], W.STEEL)
    elif kind == 'suppressor':
        rect(a, h, s0, s0 + 5.0, B - 1.2, B + 1.2, W.STEEL)
    elif kind == 'flash':
        rect(a, h, s0, s0 + 1.6, B - 0.8, B + 0.8, W.STEEL)
        px(a, *h.p(s0 + 1.0, B), W.STEEL[0])


def grip(a, h, pal, wood=False):
    P(a, h, [(-0.6, B + 1.0), (1.4, B + 1.0), (1.0, B + 4.4), (-0.6, B + 4.0)], pal['wood'] if wood else pal['trim'])


# ------------------------------------------------------------------------------------------------ gun classes
def g_rifle(a, h, it, pal, r):
    russian = pal['code'][0] in 'VZ'
    end = h.Lm
    st = 'wood' if russian and r.random() < 0.75 else r.choice(['poly', 'skeleton', 'poly'])
    stock(a, h, st, -12.5, pal)
    rect(a, h, -2.8, 8.5, B - 1.5, B + 1.4, pal['body'] if not russian else W.STEEL)
    magazine(a, h, 'curved' if russian else 'straight', 5.0, pal, length=5.6 if it['gun'].get('mag', 30) <= 30 else 7.0)
    hg_end = end - 10.0
    rect(a, h, 8.5, hg_end, B - 1.3, B + 1.4, pal['wood'] if st == 'wood' else pal['trim'])
    if russian:
        rect(a, h, 8.5, hg_end - 1.5, B - 2.1, B - 1.3, W.STEEL)                                # gas tube
    else:
        rect(a, h, -1.0, hg_end, B - 2.0, B - 1.5, W.STEEL)                                   # top rail
    rect(a, h, hg_end, end - 2.0, B - 0.5, B + 0.6, W.STEEL)                                    # barrel
    mz = r.choice(['brake', 'flash', 'suppressor'] if not russian else ['brake', 'brake', 'suppressor'])
    if mz == 'suppressor':
        rect(a, h, end - 6.0, end, B - 1.2, B + 1.2, W.STEEL)
    else:
        muzzle(a, h, mz, end - 2.0, pal)
    rect(a, h, hg_end + 1.6, hg_end + 2.4, B - 2.8, B - 0.5, W.STEEL)                            # front sight
    op = r.choice(['dot', 'holo', 'scope', 'none'] if not russian else ['none', 'dot', 'none'])
    if op != 'none':
        optic(a, h, op, 1.0, pal)
    grip(a, h, pal, wood=st == 'wood')
    strip(a, h, 0.0, 6.0, B + 0.2, pal['acc'], 0.5) if pal['code'][0] in 'HLF' else None


def g_smg(a, h, it, pal, r):
    end = h.Lm
    stock(a, h, r.choice(['wire', 'wire', 'poly', 'none']), -8.0, pal)
    rect(a, h, -2.4, end - 6.5, B - 1.9, B + 1.8, pal['body'])
    magazine(a, h, 'straight', 3.2 if r.random() < 0.6 else 0.0, pal, length=6.4 if it['gun'].get('mag', 27) > 25 else 5.4)
    if r.random() < 0.6:
        P(a, h, [(end - 6.0, B + 1.4), (end - 4.0, B + 1.4), (end - 4.4, B + 4.6), (end - 5.8, B + 4.6)], pal['trim'])   # fore grip
    rect(a, h, end - 6.5, end - 2.0, B - 0.7, B + 0.7, W.STEEL)
    if r.random() < 0.4:
        rect(a, h, end - 2.0, end + 2.5, B - 1.1, B + 1.1, W.STEEL)                           # suppressor
    else:
        rect(a, h, end - 2.0, end, B - 1.1, B + 1.1, W.STEEL)
    optic(a, h, r.choice(['dot', 'holo', 'none']), 4.0, pal)
    strip(a, h, 1.0, end - 8.0, B + 0.2, pal['acc'], 0.6)
    grip(a, h, pal)


def g_shotgun(a, h, it, pal, r):
    end = h.Lm
    russian = pal['code'][0] in 'VZ'
    stock(a, h, 'wood' if russian or r.random() < 0.3 else 'poly', -12.5, pal)
    rect(a, h, -2.8, 6.0, B - 1.6, B + 1.6, pal['body'])
    rect(a, h, 6.0, end - 1.0, B - 1.0, B + 0.4, W.STEEL)                                       # barrel
    rect(a, h, 6.0, end - 4.0, B + 0.4, B + 1.6, W.STEEL)                                       # tube magazine
    fe = 11.0 + r.random() * 3.0
    rect(a, h, fe, fe + 5.0, B - 0.2, B + 2.4, pal['wood'] if russian else pal['trim'])           # pump forend
    for k in range(3):
        px(a, *h.p(fe + 1.0 + k * 1.4, B + 1.4), pal['trim'][1])
    if it['gun'].get('mag', 7) <= 5 and not russian:
        magazine(a, h, 'box', 2.0, pal)
    elif russian:
        magazine(a, h, 'straight', 3.0, pal, length=4.6)
    rect(a, h, end - 1.4, end, B - 1.3, B + 0.7, W.STEEL)
    grip(a, h, pal, wood=russian)


def g_sniper(a, h, it, pal, r):
    end = h.Lm
    st = 'wood' if pal['code'][0] in 'VZ' else r.choice(['skeleton', 'poly'])
    stock(a, h, st, -13.5, pal)
    rect(a, h, -2.8, 7.0, B - 1.4, B + 1.4, pal['body'])
    rect(a, h, 7.0, 15.0, B - 1.2, B + 1.6, pal['wood'] if st == 'wood' else pal['trim'])
    rect(a, h, 15.0, end - 2.5, B - 0.45, B + 0.45, W.STEEL)
    muzzle(a, h, 'brake', end - 2.5, pal)
    optic(a, h, 'scope', 0.0, pal)
    magazine(a, h, 'straight', 3.6, pal, length=3.4)
    px(a, *h.p(5.0, B - 1.8), W.STEEL[5])                                                        # bolt knob
    for k in (0.0, 1.0):                                                                       # folded bipod
        rect(a, h, 12.5, 17.0, B + 1.6 + k * 0.6, B + 2.0 + k * 0.6, W.STEEL)
    grip(a, h, pal, wood=st == 'wood')


def g_mg(a, h, it, pal, r, heavy=False):
    end = h.Lm
    stock(a, h, 'poly' if not heavy else 'skeleton', -12.0, pal)
    rect(a, h, -2.8, 10.0, B - 2.0, B + 1.8, pal['body'])
    rect(a, h, 2.0, 8.0, B - 3.0, B - 2.0, W.STEEL)                                              # carry handle / cover
    magazine(a, h, 'drum' if not heavy and r.random() < 0.5 else 'box', 3.0, pal)
    sh_end = end - 6.0
    rect(a, h, 10.0, sh_end, B - 1.3, B + 1.3, pal['trim'])                                      # barrel shroud
    for k in np.arange(11.0, sh_end - 1.0, 2.0):
        px(a, *h.p(k, B), W.STEEL[0])                                                            # cooling holes
    rect(a, h, sh_end, end - 1.5, B - 0.7 - (0.3 if heavy else 0), B + 0.7 + (0.3 if heavy else 0), W.STEEL)
    muzzle(a, h, 'flash', end - 1.5, pal)
    for k in (0.0, 1.0):
        rect(a, h, sh_end - 4.0, sh_end + 1.0, B + 1.3 + k * 0.6, B + 1.8 + k * 0.6, W.STEEL)       # bipod
    grip(a, h, pal)


def g_launcher(a, h, it, pal, r):
    end = h.Lm
    stock(a, h, 'poly', -10.0, pal)
    if pal['code'][0] == 'G':
        c = h.p(4.0, B + 0.6)
        m = a.ellipse(c[0], c[1], 3.6, 3.6)                                                     # revolving drum
        F.ramp_paint(a, m, pal['body'], bevel=1.4, strength=1.0)
        for k in range(6):
            ang = k * math.pi / 3
            px(a, c[0] + 2.0 * math.cos(ang), c[1] + 2.0 * math.sin(ang), pal['body'][0])
        rect(a, h, 7.0, end, B - 1.6, B + 2.0, pal['body'])
    else:
        rect(a, h, -2.8, end, B - 2.0, B + 2.2, pal['body'])                                     # fat single tube
        rect(a, h, end - 1.2, end, B - 2.3, B + 2.5, W.STEEL)
    rect(a, h, 6.0, 9.0, B + 2.0, B + 5.0, pal['trim'])                                          # fore grip
    optic(a, h, 'holo', 0.5, pal)
    strip(a, h, 9.0, end - 2.0, B - 1.2, pal['acc'], 0.5)
    grip(a, h, pal)


def g_laser(a, h, it, pal, r):
    end = h.Lm
    acc = pal['acc']
    glow = K.ramp_from(acc)
    P(a, h, [(-10.0, B - 1.6), (end - 12.0, B - 2.2), (end - 11.0, B + 0.2), (end - 12.5, B + 2.0), (-10.0, B + 2.2)], pal['body'])
    cell = rect(a, h, -9.2, -4.8, B - 0.6, B + 1.4, glow)
    a.fill(cell, acc)
    a.glow(*h.p(-7.0, B + 0.4), 4.0, acc, 0.25)
    for k in range(4):
        s = end - 11.0 + k * 2.3
        rect(a, h, s, s + 1.1, B - 1.5, B + 1.3, W.STEEL)
        px(a, *h.p(s + 0.5, B), acc)
    rect(a, h, end - 11.0, end - 1.6, B - 0.6, B + 0.6, W.STEEL)
    P(a, h, [(end - 1.6, B - 1.0), (end, B - 0.6), (end, B + 0.6), (end - 1.6, B + 1.0)], pal['body'])
    px(a, *h.p(end - 0.2, B), '#ffffff')
    a.glow(*h.p(end, B), 3.0, acc, 0.4)
    rect(a, h, 2.0, 6.0, B - 3.2, B - 2.0, W.STEEL)
    grip(a, h, pal)


def g_pistol(a, h, it, pal, r):
    end = h.Lm
    rect(a, h, -2.0, end, B - 1.4, B + 0.6, pal['body'] if r.random() < 0.5 else W.STEEL)       # slide
    rect(a, h, -1.4, end - 0.8, B + 0.6, B + 1.6, pal['trim'])
    P(a, h, [(-1.2, B + 1.4), (1.6, B + 1.4), (1.0, B + 5.0), (-1.4, B + 4.6)], pal['trim'])
    rect(a, h, 1.6, 3.6, B + 1.6, B + 2.6, W.STEEL)
    for k in range(3):
        px(a, *h.p(end - 4.6 + k * 1.2, B - 0.6), '#121418')
    if r.random() < 0.4:
        rect(a, h, end, end + 2.0, B - 1.0, B + 0.2, W.STEEL)                                   # compensator
    px(a, *h.p(-1.4, B - 1.8), pal['acc'])


def g_revolver(a, h, it, pal, r):
    end = h.Lm
    rect(a, h, -1.6, 3.0, B - 1.4, B + 1.0, W.STEEL)
    rect(a, h, 1.4, 4.8, B - 1.8, B + 1.8, W.STEEL)
    for k in (2.2, 3.4):
        px(a, *h.p(k, B), W.STEEL[1])
    rect(a, h, 4.8, end, B - 1.0, B + 0.7, pal['body'] if pal['code'][0] in 'GS' else W.STEEL)
    rect(a, h, 4.8, end, B - 1.7, B - 1.0, W.STEEL, top=W.STEEL[6])
    P(a, h, [(-1.4, B + 1.0), (1.4, B + 1.0), (0.4, B + 5.2), (-2.2, B + 4.6)], pal['wood'])
    rect(a, h, -2.4, -1.4, B - 2.2, B - 1.2, W.STEEL)


GUN_CLASS = {'rifle': (g_rifle, 900, 27.5, 1.0), 'smg': (g_smg, 450, 19.0, 1.0), 'shotgun': (g_shotgun, 950, 27.0, 1.0),
             'sniper': (g_sniper, 1100, 30.5, 1.0), 'mg': (g_mg, 1000, 28.5, 1.0),
             'heavy_mg': (lambda a, h, it, p, r: g_mg(a, h, it, p, r, True), 1300, 31.0, 1.0),
             'launcher': (g_launcher, 800, 24.0, 1.0), 'laser': (g_laser, 700, 24.5, 1.0),
             'pistol': (g_pistol, 200, 8.6, 1.35), 'revolver': (g_revolver, 220, 11.0, 1.3)}


def gun(b, it):
    cls = it['tags'][1]
    fn, ref_mm, ref_len, k = GUN_CLASS[cls]
    r = rng(it['id'])
    a = A()
    h = Hold(b, k=k, direction=PISTOL_DOWN if cls in ('pistol', 'revolver') else None)
    h.Lm = ref_len * (0.9 + 0.1 * it['length_mm'] / ref_mm) + (r.random() - 0.5) * 1.6
    fn(a, h, it, maker_palette(it), r)
    return crisp(a)


# ------------------------------------------------------------------------------------------------ melee
GRADES = {'': dict(blade=K.ramp_from('#8a94a0'), fit=W.STEEL, wrap='#24262c'),                         # polished steel
          '_f': dict(blade=K.ramp_from('#4e5660'), fit=W.STEEL, wrap='#2a1c14', edge='#eef4f8'),          # dark forged body, bright edge
          '_m': dict(blade=K.ramp_from('#a3afbc'), fit=K.ramp_from('#b08a3a'), wrap=None, edge='#ffffff')}  # bright, brass fittings
WRAP_M = {'japanese': '#7a2030', 'russian': '#4a2c1a'}
HAFT = W.WOOD


def _blade(a, h, s0, s1, w0, w1, g, curve=0.0, edge_low=True):
    """a blade from s0 to s1 along the hold, w0 -> w1 wide, optional curve (toward n-), forged/masterwork edge line"""
    pts_top, pts_bot = [], []
    n = 8
    for i in range(n + 1):
        t = i / n
        s = s0 + (s1 - s0) * t
        bend = -curve * (t ** 2)
        w = w0 + (w1 - w0) * t
        pts_top.append((s, B + bend - w / 2))
        pts_bot.append((s, B + bend + w / 2))
    pts_top[-1] = (s1 + 0.8, B - curve - 0.0)
    m = P(a, h, pts_top + pts_bot[::-1], g['blade'], top=g['blade'][6])
    if 'edge' in g:
        e = [(s, n_ + (0.3 if edge_low else -0.3)) for s, n_ in (pts_bot if edge_low else pts_top)]
        for (s_a, n_a), (s_b, n_b) in zip(e[:-1], e[1:]):
            p0, p1 = h.p(s_a, n_a - (0.5 if edge_low else -0.5)), h.p(s_b, n_b - (0.5 if edge_low else -0.5))
            a.fill(a.line(p0[0], p0[1], p1[0], p1[1], 0.45) & m, g['edge'])
    return m


def _hilt(a, h, s0, s1, g, origin, w=1.8):
    wrap = g['wrap'] or WRAP_M[origin]
    m = rect(a, h, s0, s1, B - w / 2, B + w / 2, K.ramp_from(wrap))
    for s in np.arange(s0 + 0.6, s1, 1.2):
        px(a, *h.p(s, B), K.ramp_from(wrap)[1])
    return m


def _guard(a, h, s, g, half=2.2, thick=0.9):
    rect(a, h, s - thick / 2, s + thick / 2, B - half, B + half, g['fit'])


def _haft(a, h, s0, s1, w=1.5, ramp=None):
    rect(a, h, s0, s1, B - w / 2, B + w / 2, ramp or HAFT)


def m_sword(length, curve, width, hilt=6.0, guard='disc', origin='japanese', up=True, two_hand=False):
    def f(a, h, g):
        hl = h.L + 3.5 if two_hand else hilt                     # two-handed: the grip runs from the right hand to the left
        _hilt(a, h, -3.0, hl - 3.0, g, origin)
        if guard == 'disc':
            _guard(a, h, hl - 3.0, g, half=2.0, thick=1.0)
        elif guard == 'bar':
            _guard(a, h, hl - 3.0, g, half=1.6, thick=0.8)
        _blade(a, h, hl - 2.5, hl - 2.5 + length, width, width * 0.55, g, curve=curve)
        rect(a, h, -3.8, -3.0, B - 1.1, B + 1.1, g['fit'])                                         # pommel / cap
    f.up = up
    f.mode = 'two' if two_hand else 'upright'
    return f


def m_pole(head, length=24.0, back=-9.0):
    def f(a, h, g):
        _haft(a, h, back, length)
        rect(a, h, back - 0.8, back, B - 0.9, B + 0.9, g['fit'])                                 # butt cap
        head(a, h, g, length)
    f.up = True
    f.mode = 'two'
    return f


def head_naginata(a, h, g, L):
    rect(a, h, L - 1.2, L, B - 1.1, B + 1.1, g['fit'])
    _blade(a, h, L, L + 8.0, 2.4, 1.2, g, curve=1.8)


def head_yari(a, h, g, L):
    rect(a, h, L - 1.0, L, B - 1.0, B + 1.0, g['fit'])
    P(a, h, [(L, B - 1.3), (L + 6.5, B), (L, B + 1.3)], g['blade'], top=g['blade'][6])


def head_staff(a, h, g, L):
    rect(a, h, L - 1.2, L, B - 0.9, B + 0.9, g['fit'])


def head_axe(size, kind):
    def f(a, h, g, L):
        if kind == 'ono':
            P(a, h, [(L - 3.0, B - 0.8), (L - 0.4, B - 0.8), (L + 0.8, B - 1.0 - size), (L - 4.6, B - 1.0 - size)], g['blade'], top=g['blade'][6])
        elif kind == 'topor':
            P(a, h, [(L - 2.6, B - 0.8), (L - 0.2, B - 0.8), (L + 0.6, B - size), (L - 3.8, B - size + 0.6)], g['blade'], top=g['blade'][6])
        elif kind == 'chekan':
            rect(a, h, L - 1.6, L + 0.2, B - 2.8, B + 0.8, g['blade'])
            P(a, h, [(L - 1.4, B + 0.8), (L - 0.2, B + 0.8), (L - 0.8, B + 4.2)], g['blade'])
        elif kind == 'lopata':
            P(a, h, [(L - 0.6, B - 2.2), (L + 5.4, B - 2.4), (L + 6.4, B), (L + 5.4, B + 2.4), (L - 0.6, B + 2.2)], K.ramp_from('#4f5a48'))
            if 'edge' in g:
                strip(a, h, L + 5.4, L + 6.2, B, g['edge'], 0.5)
        rect(a, h, L - 1.0, L + 0.2, B - 1.0, B + 1.0, g['fit'])
    return f


def m_low(draw, mode='upright'):
    """a one-hand weapon in the near hand, standing straight up ('upright') or hanging straight down ('hang')"""
    draw.up = False
    draw.mode = mode
    return draw


def d_short_blade(length, width, guard='bar', origin='japanese', curve=0.0, ring=False):
    def f(a, h, g):
        _hilt(a, h, -2.4, 2.6, g, origin, w=1.7)
        if ring:
            c = h.p(-3.6, B)
            ring_ = a.ellipse(c[0], c[1], 1.6, 1.6) & ~a.ellipse(c[0], c[1], 0.8, 0.8)
            a.fill(ring_, col(g['fit'][4]))
        if guard:
            _guard(a, h, 2.6, g, half=1.6 if guard == 'bar' else 1.2, thick=0.8)
        _blade(a, h, 3.0, 3.0 + length, width, width * 0.5, g, curve=curve)
    return m_low(f)


def d_kama(a, h, g):
    _haft(a, h, -2.4, 7.0, w=1.5)
    P(a, h, [(6.2, B - 0.8), (7.2, B - 0.8), (5.6, B - 6.0), (4.6, B - 5.4)], g['blade'], top=g['blade'][6])


def d_kusarigama(a, h, g):
    d_kama(a, h, g)
    for k in range(6):                                                                         # chain hanging from the butt
        px(a, *h.p(-3.0 - k * 1.2, B), W.STEEL[4 if k % 2 else 2])
    c = h.p(-10.4, B)
    a.fill(a.ellipse(c[0], c[1], 1.3, 1.3), col(W.STEEL[3]))


def d_nunchaku(a, h, g):
    _haft(a, h, -2.4, 6.0, w=1.6)
    rect(a, h, 6.0, 6.6, B - 0.9, B + 0.9, g['fit'])
    for k in range(3):
        px(a, *h.p(6.8 + k * 0.7, B), W.STEEL[4])
    p0, p1 = h.p(9.0, B + 0.6), h.p(15.0, B + 0.6)
    a2 = a.line(p0[0], p0[1], p1[0], p1[1], 1.6)
    F.ramp_paint(a, a2, HAFT, bevel=0.8, strength=1.0)


def d_sai(a, h, g, jitte=False):
    _hilt(a, h, -2.4, 2.4, g, 'japanese', w=1.5)
    rect(a, h, 2.4, 13.0 if not jitte else 12.0, B - 0.45, B + 0.45, g['blade'])
    if jitte:
        P(a, h, [(3.2, B - 0.4), (5.6, B - 0.4), (5.6, B - 2.4), (5.0, B - 2.4), (5.0, B - 0.9), (3.2, B - 0.9)], g['fit'])
    else:
        for sgn in (-1, 1):
            P(a, h, [(2.4, B + sgn * 0.4), (3.0, B + sgn * 0.4), (5.2, B + sgn * 2.8), (4.6, B + sgn * 3.0)], g['blade'])


def d_tessen(a, h, g):
    for k in range(5):                                                                        # closed iron fan, ribs
        rect(a, h, -2.4, 10.0, B - 1.6 + k * 0.7, B - 1.0 + k * 0.7, g['blade'] if k % 2 else K.ramp_from('#2a2c32'))
    rect(a, h, -2.8, -2.0, B - 1.8, B + 1.8, g['fit'])


def d_tonfa(a, h, g):
    _haft(a, h, -2.4, 1.6, w=1.4)
    p = h.p(1.0, B)
    q = (p[0] - 7.5, p[1] - 6.0)
    m = a.line(p[0] + 1.0, p[1] + 0.6, q[0], q[1], 1.8)                                         # the long arm along the forearm
    F.ramp_paint(a, m, K.ramp_from('#2a2c30'), bevel=0.8, strength=1.0)


def d_kistien(a, h, g):
    _hilt(a, h, -2.4, 5.0, g, 'russian', w=1.7)
    for k in range(5):
        px(a, *h.p(5.4 + k * 1.0, B), W.STEEL[4 if k % 2 else 2])
    c = h.p(11.4, B)
    m = a.ellipse(c[0], c[1], 1.6, 1.6)
    F.ramp_paint(a, m, g['blade'], bevel=1.0, strength=1.0)


def d_kastet(a, h, g):
    """knuckle duster over the closed fist (drawn above the hands layer)"""
    c = h.o
    m = a.rrect(c[0] - 2.8, c[1] - 2.2, 5.2, 1.6, 0.6)
    F.ramp_paint(a, m, g['blade'] if g['fit'] is W.STEEL else g['fit'], bevel=0.8, strength=1.0)
    for k in range(4):
        px(a, c[0] - 2.4 + k * 1.3, c[1] - 2.6, W.STEEL[6])


MELEE = {
    'katana': m_sword(11.0, 2.0, 2.0, two_hand=True),
    'nodachi': m_sword(13.5, 2.6, 2.2, two_hand=True),
    'wakizashi': m_sword(12.0, 1.2, 1.9, up=False),
    'shashka': m_sword(14.0, 1.8, 2.0, guard=None, origin='russian', up=False),
    'naginata': m_pole(head_naginata, length=21.0, back=-9.0),
    'yari': m_pole(head_yari, length=22.0, back=-9.0),
    'bo': m_pole(head_staff, length=20.0, back=-13.0),
    'jo': m_pole(head_staff, length=20.0, back=-8.0),
    'ono': m_pole(head_axe(5.0, 'ono'), length=20.0, back=-5.0),
    'topor': m_low(lambda a, h, g: (_haft(a, h, -3.0, 11.0), head_axe(4.0, 'topor')(a, h, g, 11.0))),
    'chekan': m_low(lambda a, h, g: (_haft(a, h, -3.0, 12.0), head_axe(3.0, 'chekan')(a, h, g, 12.0))),
    'lopata': m_low(lambda a, h, g: (_haft(a, h, -3.0, 9.0), head_axe(3.0, 'lopata')(a, h, g, 9.0))),
    'tanto': d_short_blade(7.0, 1.6, 'bar'),
    'kunai': d_short_blade(6.0, 1.8, None, ring=True),
    'kinzhal': d_short_blade(8.5, 2.0, 'bar', origin='russian'),
    'finka': d_short_blade(7.0, 1.6, 'bar', origin='russian', curve=-0.4),
    'kama': m_low(d_kama),
    'kusarigama': m_low(d_kusarigama),
    'nunchaku': m_low(d_nunchaku, 'hang'),
    'sai': m_low(lambda a, h, g: d_sai(a, h, g)),
    'jitte': m_low(lambda a, h, g: d_sai(a, h, g, jitte=True)),
    'tessen': m_low(d_tessen),
    'tonfa': m_low(d_tonfa),
    'kistien': m_low(d_kistien, 'hang'),
    'kastet': m_low(d_kastet),
}
OVER_HANDS = {'kastet'}


def melee(b, it):
    base = it['id'][len('trl_mel_'):]
    grade = ''
    for gsuf in ('_f', '_m'):
        if base.endswith(gsuf):
            grade, base = gsuf, base[:-2]
    fn = MELEE[base]
    g = dict(GRADES[grade])
    origin = it['tags'][2] if len(it['tags']) > 2 else 'japanese'
    if grade == '_m':
        g['wrap'] = WRAP_M.get(origin, '#4a2c1a')
    a = A()
    mode = getattr(fn, 'mode', 'two')
    # two-handed: across the body through both hands; one-handed: straight up from the grip hand, chains hang down
    h = Hold(b, direction={'two': None, 'upright': (0.0, -1.0), 'hang': (0.0, 1.0)}[mode])
    h.L = Hold(b).L
    fn(a, h, g)
    return crisp(a), base in OVER_HANDS


# ------------------------------------------------------------------------------------------------ tools
def t_repair(b):
    """field repair kit: a compact tool case hanging from the near hand, a wrench clipped to its side"""
    a = A()
    x, y = b.H_n
    case = a.rrect(x - 3.4, y + 1.6, 7.6, 5.4, 1.0)
    F.ramp_paint(a, case, K.ramp_from('#b08a3a'), bevel=1.2, strength=1.0)
    a.fill(a.rect(x - 3.4, y + 3.6, 7.6, 0.6), '#5a4418')
    px(a, x - 0.4, y + 3.0, '#2a2c30', w=2)
    w_ = a.line(x + 2.6, y + 2.2, x + 4.8, y + 6.2, 0.9)
    a.fill(w_, col(W.STEEL[5]))
    return crisp(a)


def t_medkit(b):
    """trauma patch: a sealed white pouch with a teal band (no cross), held in the near hand"""
    a = A()
    x, y = b.H_n
    pouch = a.rrect(x - 2.6, y + 1.4, 5.4, 4.6, 0.8)
    F.ramp_paint(a, pouch, K.ramp_from('#d8dcdc'), bevel=1.0, strength=1.0)
    a.fill(a.rect(x - 2.6, y + 3.2, 5.4, 1.0), '#2aa0a0')
    return crisp(a)


TOOLS = {'trl_kit_repair': t_repair, 'trl_medkit': t_medkit}


def all_held(b, items):
    """{item id: (image, z)} for every gun, melee weapon and tool"""
    out = {}
    for it in items:
        t = it.get('tags', [])
        if 'gun' in t:
            out[it['id']] = (gun(b, it), 50)
        elif t and t[0] == 'melee':
            im, over = melee(b, it)
            out[it['id']] = (im, 62 if over else 50)
        elif it['id'] in TOOLS:
            out[it['id']] = (TOOLS[it['id']](b), 50)
    return out
