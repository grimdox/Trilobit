"""Clothes, armor and held guns for the standing dolls (t64_figure).  Every wearable is two 64x64 layers that slot into
the doll's stack so the arm in front of the torso stays in front:
    shadow, body, under, CLOTH, ARMOR, arms, CLOTH_ARM, ARMOR_ARM, HELD, hands
Clothing and armor are lit with the same cylinder model as the skin (one light from the top left) on their own
hand-picked colour ramps.  Held guns are drawn part by part in the hold axis between the two hands.
Step 3 candidates: C1-C3 clothes, A1-A3 armor, G1-G3 guns."""
import math
import numpy as np
from PIL import Image
import t64_figure as F
from t64_figure import A, col, lit, mix, px, limb_paint, ramp_paint, crisp, px_mask

# ------------------------------------------------------------------------------------------------ palettes (dark -> light)
RAMPS = {
    'olive':    ['#14160e', '#202418', '#2c3122', '#3b412e', '#4c533c', '#626a4f', '#7c8566'],
    'denim':    ['#111317', '#1a1e24', '#252a32', '#313741', '#3f4652', '#525a68', '#69727f'],
    'corp':     ['#2a323e', '#434d5b', '#5f6a7a', '#7d8999', '#9ba7b8', '#bac5d3', '#dae2ec'],
    'slate':    ['#0f1217', '#181c23', '#222730', '#2d333e', '#3a414e', '#4a5262', '#5d6676'],
    'rust':     ['#29150b', '#44230f', '#633513', '#84491b', '#a36127', '#bd7c3a', '#d49855'],
    'leather':  ['#150c08', '#24150e', '#362015', '#4a2c1c', '#5f3a25', '#764a31', '#8f5d40'],
    'scrap':    ['#1c1210', '#321f19', '#4b2f23', '#673f2e', '#86573b', '#a47357', '#c09479'],
    'navy':     ['#0a0e16', '#121925', '#1b2535', '#253247', '#32415a', '#435577', '#5a6f95'],
    'quilt':    ['#0b0a0f', '#15131b', '#201d29', '#2c2838', '#3a3549', '#4b455e', '#605876'],
    'sneaker':  ['#1a1b1e', '#2c2e33', '#43464d', '#5d6169', '#7b7f88', '#a3a7ae', '#d4d6d8'],
    'shoe':     ['#08090b', '#121418', '#1c1f25', '#272b33', '#353a44', '#4b5260', '#6b7486'],
    'boot':     ['#120a06', '#1f130b', '#2e1d11', '#3f2918', '#523621', '#68462c', '#80583a'],
}
CYAN, AMBER, VIOLET, RUSTC = '#35d7ff', '#ffad4a', '#8a1fe0', '#b5562a'


def T(name, i):
    r = RAMPS[name]
    return r[max(0, min(len(r) - 1, i))]


def grow(a, m, px_):
    from scipy import ndimage as ndi
    return ndi.binary_dilation(m, iterations=max(1, int(px_ * a.ss)))


def seg(a, p0, p1, w0, w1, ramp, dim=0, rim=None, **kw):
    return limb_paint(a, p0, p1, w0, w1, ramp=RAMPS[ramp], dim=dim, rim_dir=rim, **kw)


def lerp(p, q, t):
    return (p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t)


def speck(a, m, c, density, seed):
    rng = np.random.default_rng(seed)
    s = rng.random(m.shape) < density / (a.ss * a.ss)
    from scipy import ndimage as ndi
    s = ndi.binary_dilation(s, iterations=a.ss // 2)
    a.fill(s & m, c)


# ------------------------------------------------------------------------------------------------ garment pieces
def trousers(a, b, ramp, wide=1.0, cuff=None, knee_patch=None, pocket=False, seed=1):
    """both legs (far first) as cloth cylinders a little wider than the leg; returns the near-leg mask"""
    masks = {}
    for near in (False, True):
        P, K, Aa = (b.P_n, b.K_n, b.A_n) if near else (b.P_f, b.K_f, b.A_f)
        f = 1.0 if near else 1 - 0.1 * b.turn
        d = 0 if near else 1
        w0, w1 = b.leg_w
        m = seg(a, P, K, (w0 + 1.4 * wide) * f, (w1 + 1.6 * wide) * f, ramp, dim=d)
        m |= seg(a, K, (Aa[0], Aa[1] - 0.6), (w1 + 1.6 * wide) * f, (w1 * 0.75 + 1.8 * wide) * f, ramp, dim=d)
        a.fill(a.ellipse(K[0] + 0.4, K[1] + 0.4, 1.6, 0.45), T(ramp, 1), 1.0)                # knee crease
        if knee_patch:
            pm = a.rect(K[0] - 1.6, K[1] - 1.8, 3.2, 3.0)
            a.fill(pm, T(knee_patch, 3 - d))
            a.fill(pm & (a.yy < K[1] - 1.2), T(knee_patch, 4 - d))
            for k in range(3):
                px(a, K[0] - 1.6 + k, K[1] - 2.0, T(ramp, 1))                               # stitches
        if pocket and near:
            mid = lerp(P, K, 0.5)
            pk = a.rect(mid[0] - 2.4, mid[1] - 1.5, 3.4, 4.0)
            a.fill(pk, T(ramp, 2))
            a.fill(a.rect(mid[0] - 2.4, mid[1] - 1.5, 3.4, 1.0), T(ramp, 4))                  # flap light
        masks[near] = m
    # crotch / seat joins the two legs
    t = b.top
    seat = a.poly([(b.X(-b.hip + 0.3), t + 19.0), (b.X(b.hip - 0.3), t + 19.0), (b.X(b.hip * 0.5), t + 25.5), (b.X(-b.hip * 0.5), t + 25.5)])
    ramp_paint(a, seat, RAMPS[ramp], bevel=2.5, strength=1.0)
    a.fill(a.line(b.X(0.2), t + 20.0, b.X(0.2), t + 25.0, 0.5), T(ramp, 1))                 # centre seam
    return masks[True]


def shoes(a, b, ramp, tall=0.0, sole='#2a2a2a', toe_cap=None):
    for near in (False, True):
        Aa = b.A_n if near else b.A_f
        d = 0 if near else 1
        if tall > 0:
            seg(a, (Aa[0], Aa[1] - tall), (Aa[0], Aa[1]), b.leg_w[1] * 0.9 + 1.4, b.leg_w[1] * 0.85 + 1.4, ramp, dim=d)
        foot = a.ellipse(Aa[0] + 1.7 + 0.8 * b.turn, 60.3, 4.6, 2.2)
        a.fill(foot, T(ramp, 3 - d))
        a.fill(foot & (a.yy < 59.6), T(ramp, 5 - d))
        a.fill(foot & (a.yy > 61.2), sole)
        if toe_cap:
            a.fill(foot & (a.xx > Aa[0] + 4.0 + 0.8 * b.turn) & (a.yy < 61.0), toe_cap)


def neck_hole(a, b, kind, depth):
    """the neck opening of a garment: 'crew' (round, sits low on the collarbones), 'v' or 'open' (a V to `depth`)"""
    t, c = b.top, b.centre()
    hole = a.ellipse(c, t - 1.6, 3.8, 1.6 + depth)
    if kind in ('v', 'open'):
        hole |= a.poly([(c - 3.4, t - 3.0), (c + 3.2, t - 3.0), (c + 0.1, t + depth)])
    return hole


def top(a, b, ramp, length=24.0, extra=0.7, hem=None, neck='crew', depth=1.6):
    """the torso part of a shirt / jacket / coverall, lit like the body, with a real neck opening (the skin shows
    through it).  Returns (cloth mask, neck opening)."""
    t = b.top
    m = grow(a, b.torso(a), extra) & (a.yy < t + length)
    m |= a.poly([(b.X(-b.hip - 0.8), t + 18.5), (b.X(b.hip + 0.8), t + 18.5), (b.X(b.hip + 0.6), t + length), (b.X(-b.hip - 0.6), t + length)])
    hole = neck_hole(a, b, neck, depth)
    m &= ~hole
    ramp_paint(a, m, RAMPS[ramp], bevel=3.4, strength=1.0)
    a.a[hole & ~m] = 0
    if hem:
        a.fill(m & (a.yy > t + length - 1.4), T(ramp, hem))
    return m, hole


def sleeve_far_upper(a, b, ramp, extra=1.2):
    seg(a, b.S_f, b.E_f, b.arm_w[0] * 0.9 + extra, b.arm_w[1] * 0.95 + extra, ramp, dim=1)


def sleeve_near(a, b, ramp, extra=1.2, to=1.0, cuff=None, roll=False):
    """near sleeve on the arms layer: upper arm and (part of) the forearm; returns mask"""
    S0 = (b.S_n[0] + 1.4, b.S_n[1] - 0.9)
    m = seg(a, S0, b.E_n, b.arm_w[0] + extra, b.arm_w[1] * 0.95 + extra, ramp, rim=(-1, 0), lift_inner=(0.9, 4))
    if to > 0:
        end = lerp(b.E_n, b.H_n, to)
        m |= seg(a, b.E_n, end, b.arm_w[1] + extra, b.arm_w[1] * 0.85 + extra, ramp)
        if cuff:
            c = lerp(b.E_n, b.H_n, to - 0.08)
            a.fill(a.ellipse(c[0], c[1], (b.arm_w[1] * 0.85 + extra) / 2, 1.0) & m, T(ramp, cuff))
    if roll:
        a.fill(a.ellipse(b.E_n[0], b.E_n[1] - 0.6, (b.arm_w[1] + extra) / 2 + 0.3, 1.2), T(ramp, 4))
        a.fill(a.ellipse(b.E_n[0], b.E_n[1] + 0.3, (b.arm_w[1] + extra) / 2 + 0.3, 0.5), T(ramp, 2))
    return m


def sleeve_far_fore(a, b, ramp, extra=1.2, to=1.0, cuff=None):
    end = lerp(b.E_f, b.H_f, to)
    m = seg(a, b.E_f, end, b.arm_w[1] + extra, b.arm_w[1] * 0.85 + extra, ramp)
    if cuff:
        c = lerp(b.E_f, b.H_f, to - 0.08)
        a.fill(a.ellipse(c[0], c[1], (b.arm_w[1] * 0.85 + extra) / 2, 1.0) & m, T(ramp, cuff))
    return m


def arm_layer(b, fn, ramp):
    """an arms-layer garment with the same soft join to the torso as the bare arm: no line at the shoulder, a 1px gap
    in the cloth's darkest tone from the armpit down"""
    a = A()
    fn(a)
    tor = px_mask(a, b.torso(a))
    yy_, xx_ = np.mgrid[0:64, 0:64]
    shoulder = tor & (yy_ < b.S_n[1] + 2.5) & (xx_ < b.centre())
    gap = tor & (yy_ >= b.S_n[1] + 2.5) & (yy_ < b.E_n[1] + 0.5) & (xx_ < b.centre())
    return crisp(a, no_outline=shoulder | gap, soft=(gap, tuple(col(T(ramp, 0)))))


# ------------------------------------------------------------------------------------------------ C1-C3
def c1_street(b):
    """C1 street layers: olive bomber with a rust lining, dark cargo trousers, worn grey trainers"""
    a = A()
    t = b.top
    sleeve_far_upper(a, b, 'olive')
    trousers(a, b, 'denim', pocket=True, knee_patch='slate', seed=11)
    shoes(a, b, 'sneaker', sole='#c9c4b8')
    m, hole = top(a, b, 'olive', length=21.5, hem=1, neck='crew', depth=1.8)
    a.fill(grow(a, hole, 0.8) & m, RUSTC)                                                   # rust collar lining
    a.fill(grow(a, hole, 1.6) & m & ~grow(a, hole, 0.8), T('olive', 2))                   # ribbed band
    a.fill(a.line(b.X(0.3), t + 1.4, b.X(0.3), t + 21.0, 0.5), '#9aa0a6')                 # zip
    for y in (t + 6.0, t + 12.5):
        a.fill(a.line(b.X(-b.chest + 1.6), y, b.X(-1.2), y + 0.3, 0.5), T('olive', 2))    # quilt seams
    a.fill(a.rect(b.X(-b.sh + 2.2), t + 3.0, 2.4, 2.0), '#7a6a3a')                       # a faded patch
    speck(a, m, T('olive', 1), 0.05, 12)
    arm = arm_layer(b, lambda a2: (sleeve_near(a2, b, 'olive', cuff=1), sleeve_far_fore(a2, b, 'olive', cuff=1)), 'olive')
    return crisp(a), arm


def c2_corp(b):
    """C2 corporate: pale grey-blue high-collar jacket, white shirt, slate trousers, black shoes; one smudge"""
    a = A()
    t = b.top
    sleeve_far_upper(a, b, 'corp', extra=0.9)
    trousers(a, b, 'slate', wide=0.7)
    shoes(a, b, 'shoe', sole='#050506')
    m, hole = top(a, b, 'corp', length=23.0, extra=0.5, hem=2, neck='v', depth=6.5)
    c = b.centre()
    shirt = hole & ~a.ellipse(c, t - 1.6, 3.0, 2.8) & (a.yy > t - 1.0)
    a.fill(shirt, '#e8ecef')                                                              # white shirt in the V
    a.fill(shirt & (a.yy < t + 1.2), '#c9cfd6')                                          # shirt collar, a step lower
    a.a[shirt] = 1.0
    for sgn, x0 in ((-1, c - 3.6), (1, c + 3.4)):                                       # lapels along the V
        a.fill(a.line(x0, t - 0.4, c + 0.1, t + 6.5, 1.1) & m, T('corp', 5))
        a.fill(a.line(x0 + sgn * 1.0, t - 0.2, c + 0.1 + sgn * 0.9, t + 6.9, 0.5) & m, T('corp', 2))
    a.fill(a.line(c - 3.9, t - 0.2, c - 0.2, t + 6.2, 0.5) & grow(a, hole, 0.6) & m, CYAN)   # cyan trim on the near lapel
    a.fill(a.line(b.X(0.6), t + 5.0, b.X(0.9), t + 23.0, 0.5), T('corp', 2))             # front edge
    for y in (t + 9.0, t + 14.0):
        px(a, b.X(1.4), y, T('corp', 1))                                                  # buttons
    a.fill(a.ellipse(b.X(-4.0), t + 15.5, 1.2, 0.7), T('corp', 3))                        # the one smudge
    arm = arm_layer(b, lambda a2: (sleeve_near(a2, b, 'corp', extra=0.9, cuff=2), sleeve_far_fore(a2, b, 'corp', extra=0.9, cuff=2)), 'corp')
    return crisp(a), arm


def c3_work(b):
    """C3 dock coverall: rust-ochre canvas, sleeves rolled to the elbow, patched knees, tool belt, heavy boots"""
    a = A()
    t = b.top
    sleeve_far_upper(a, b, 'rust')
    trousers(a, b, 'rust', wide=1.1, knee_patch='leather', seed=31)
    shoes(a, b, 'boot', tall=4.5, sole='#140c08', toe_cap='#8d8f92')
    m, hole = top(a, b, 'rust', length=24.0, neck='open', depth=4.2)
    c = b.centre()
    for sgn in (-1, 1):                                                                   # collar flaps folded open
        flap = a.poly([(c + sgn * 3.6, t - 1.4), (c + sgn * 0.8, t + 3.6), (c + sgn * 4.6, t + 1.6)]) & ~hole
        a.fill(flap, T('rust', 5 if sgn < 0 else 4))
        a.fill(flap & grow(a, hole, 0.6), T('rust', 2))
    a.fill(a.line(b.X(0.3), t + 4.4, b.X(0.3), t + 17.5, 0.5), T('rust', 1))              # placket
    for s in (-1, 1):
        px(a, b.X(s * 4.0) - 1.5, t + 5.0, T('rust', 2), w=3, h=2)                        # chest pockets
        px(a, b.X(s * 4.0) - 1.5, t + 5.0, T('rust', 5), w=3)
    belt = a.rect(b.X(-b.waist - 1.2), t + 16.6, b.X(b.waist + 1.2) - b.X(-b.waist - 1.2), 2.0)
    a.fill(belt, T('leather', 3))
    a.fill(belt & (a.yy < t + 17.1), T('leather', 5))
    for x in (-5.5, -2.0, 4.0):
        p = a.rect(b.X(x) - 1.0, t + 17.4, 2.2, 3.0)
        a.fill(p, T('leather', 2))
        a.fill(p & (a.yy < t + 18.0), T('leather', 4))
    px(a, b.X(0.2) - 0.5, t + 17.0, '#c9b07a', w=2)                                       # buckle
    speck(a, m, T('rust', 1), 0.09, 32)
    speck(a, m, '#3a2a1e', 0.03, 33)                                                       # oil and grime
    arm = arm_layer(b, lambda a2: (sleeve_near(a2, b, 'rust', to=0.0, roll=True), None), 'rust')
    return crisp(a), arm


CLOTHES = {'C1': ('Street layers', c1_street), 'C2': ('Corporate', c2_corp), 'C3': ('Dock coverall', c3_work)}


# ------------------------------------------------------------------------------------------------ A1-A3
def yoke(a, b, ramp, d_far=1):
    """the part of an armor that runs over the shoulders (trapezius) from the collar to each shoulder, so the shoulder
    pieces are carried by the torso piece instead of floating; the neck stays open"""
    t, c = b.top, b.centre()
    near = a.poly([(c - 2.6, t - 1.4), (b.S_n[0] + 1.0, b.S_n[1] - 2.6), (b.S_n[0] - 0.8, b.S_n[1] + 1.8),
                   (b.X(-b.chest + 1.2), t + 4.8), (c - 1.4, t + 3.2)])
    far = a.poly([(c + 2.4, t - 1.4), (b.S_f[0] - 0.6, b.S_f[1] - 2.4), (b.S_f[0] + 1.0, b.S_f[1] + 1.6),
                  (b.X(b.chest - 1.0), t + 4.8), (c + 1.4, t + 3.2)])
    ramp_paint(a, near, RAMPS[ramp], bevel=1.4, strength=1.0)
    ramp_paint(a, far, RAMPS[ramp], bevel=1.4, strength=1.0)
    a.rgb[far] = a.rgb[far] * (0.85 if d_far else 1.0)
    return near | far


def strap(arm, b, ramp, w=2.2):
    """a strap on the arm-armor layer carrying the near shoulder piece in to the yoke, over the top of the arm"""
    m = arm.line(b.S_n[0] - 0.4, b.S_n[1] - 0.2, b.S_n[0] + 3.6, b.S_n[1] - 1.8, w)
    ramp_paint(arm, m, RAMPS[ramp], bevel=0.8, strength=1.0)
    return m



def plate(a, pts, ramp, d=0, rivets=(), spec=None):
    m = a.poly(pts)
    ramp_paint(a, m, RAMPS[ramp], bevel=1.4, strength=1.0)
    if d:
        a.rgb[m] = a.rgb[m] * 0.85
    for (x, y) in rivets:
        px(a, x, y, T(ramp, 6))
    return m


def a1_scrap(b):
    """A1 scrap plate (street gangs): rusted steel sheets riveted over a leather harness, one shoulder plate, knee plates"""
    a = A()
    t = b.top
    harness = a.poly([(b.X(-b.chest + 0.4), t + 2.6), (b.X(b.chest - 0.4), t + 2.6), (b.X(b.waist), t + 16.0), (b.X(-b.waist), t + 16.0)])
    ramp_paint(a, harness, RAMPS['leather'], bevel=1.6, strength=1.0)
    yoke(a, b, 'leather')
    for s in (-1, 1):
        a.fill(a.line(b.X(s * (b.sh - 3.2)), t - 0.6, b.X(s * 1.0), t + 13.0, 1.4), T('leather', 2))   # crossed straps
    m1 = plate(a, [(b.X(-b.chest + 0.6), t + 3.6), (b.X(1.6), t + 2.8), (b.X(2.4), t + 10.4), (b.X(-b.chest + 1.4), t + 11.0)], 'scrap',
               rivets=[(b.X(-b.chest + 1.6), t + 4.4), (b.X(0.8), t + 4.0), (b.X(1.4), t + 9.6), (b.X(-b.chest + 2.2), t + 10.0)])
    m2 = plate(a, [(b.X(0.6), t + 6.0), (b.X(b.chest - 0.8), t + 5.2), (b.X(b.chest - 1.4), t + 13.2), (b.X(0.2), t + 13.6)], 'scrap', d=1,
               rivets=[(b.X(1.4), t + 6.6), (b.X(b.chest - 1.8), t + 6.0), (b.X(b.chest - 2.0), t + 12.4)])
    speck(a, m1 | m2, RUSTC, 0.22, 41)
    speck(a, m1 | m2, '#2a1a12', 0.06, 42)
    a.fill(a.line(b.X(-b.chest + 1.0), t + 7.6, b.X(1.8), t + 7.2, 0.5), T('scrap', 1))   # weld seam
    for near in (False, True):
        K = b.K_n if near else b.K_f
        kp = a.poly([(K[0] - 2.4, K[1] - 2.4), (K[0] + 2.2, K[1] - 2.8), (K[0] + 2.6, K[1] + 1.6), (K[0] - 2.0, K[1] + 2.0)])
        ramp_paint(a, kp, RAMPS['scrap'], bevel=1.0, strength=1.0)
        speck(a, kp, RUSTC, 0.25, 43 + near)
        px(a, K[0], K[1] - 1.6, T('scrap', 6))
    arm = A()
    sp = arm.poly([(b.S_n[0] - 3.8, b.S_n[1] - 1.6), (b.S_n[0] + 2.2, b.S_n[1] - 2.8), (b.S_n[0] + 2.8, b.S_n[1] + 2.8), (b.S_n[0] - 3.4, b.S_n[1] + 4.0)])
    strap(arm, b, 'leather')
    ramp_paint(arm, sp, RAMPS['scrap'], bevel=1.2, strength=1.0)
    speck(arm, sp, RUSTC, 0.25, 45)
    for (x, y) in ((b.S_n[0] - 2.6, b.S_n[1] - 0.6), (b.S_n[0] + 1.4, b.S_n[1] - 1.4), (b.S_n[0] - 2.2, b.S_n[1] + 2.8)):
        px(arm, x, y, T('scrap', 6))
    return crisp(a), crisp(arm)


def a2_tactical(b):
    """A2 tactical plasteel (police-corporate colours): navy matte plates, cyan strip, both shoulders, forearm and shin guards"""
    a = A()
    t = b.top
    vest = a.poly([(b.X(-b.chest - 0.5), t + 1.8), (b.X(b.chest + 0.5), t + 1.8), (b.X(b.waist + 1.0), t + 17.0), (b.X(-b.waist - 1.0), t + 17.0)])
    ramp_paint(a, vest, RAMPS['navy'], bevel=2.4, strength=1.0)
    yoke(a, b, 'navy')
    chest = a.rrect(b.X(-b.chest + 1.2), t + 3.0, b.X(b.chest - 1.2) - b.X(-b.chest + 1.2), 6.6, 1.6)
    ramp_paint(a, chest, RAMPS['navy'], bevel=1.6, strength=1.0)
    a.fill(chest & (a.yy < t + 3.8), T('navy', 6))
    a.fill(a.line(b.X(-b.chest + 1.6), t + 6.4, b.X(b.chest - 1.6), t + 6.4, 0.6), CYAN)
    px(a, b.centre() - 1, t + 7.6, '#d6dbe0', w=2, h=2)                                    # blank id plate
    for r in range(2):                                                                     # segmented abdomen plates
        y = t + 11.0 + r * 2.8
        seg_ = a.rrect(b.X(-b.waist + 0.6), y, b.X(b.waist - 0.6) - b.X(-b.waist + 0.6), 2.2, 0.6)
        a.fill(seg_, T('navy', 3))
        a.fill(seg_ & (a.yy < y + 0.6), T('navy', 5))
    a.fill(a.rect(b.X(-b.waist - 1.0), t + 16.6, b.X(b.waist + 1.0) - b.X(-b.waist - 1.0), 1.6), '#070a10')      # belt
    pf = a.ellipse(b.S_f[0] + 0.8, b.S_f[1] + 0.6, 3.0, 2.6)
    ramp_paint(a, pf, RAMPS['navy'], bevel=1.4, strength=1.0)
    for near in (False, True):
        K = b.K_n if near else b.K_f
        Aa = b.A_n if near else b.A_f
        seg(a, (K[0], K[1] - 1.0), lerp(K, Aa, 0.8), b.leg_w[1] + 1.6, b.leg_w[1] * 0.8 + 1.4, 'navy', dim=0 if near else 1)
        a.fill(a.line(K[0] - 1.6, K[1] + 2.0, K[0] - 0.8, lerp(K, Aa, 0.7)[1], 0.5), CYAN)
    arm = A()
    strap(arm, b, 'navy', w=2.6)
    pn = arm.ellipse(b.S_n[0] - 0.4, b.S_n[1] + 0.6, 3.6, 3.0)
    ramp_paint(arm, pn, RAMPS['navy'], bevel=1.6, strength=1.0)
    arm.fill(pn & (arm.yy < b.S_n[1] - 0.8), T('navy', 6))
    for near in (True, False):
        E, H = (b.E_n, b.H_n) if near else (b.E_f, b.H_f)
        limb_paint(arm, lerp(E, H, 0.15), lerp(E, H, 0.75), b.arm_w[1] + 1.4, b.arm_w[1] * 0.85 + 1.2, ramp=RAMPS['navy'])
        c0, c1 = lerp(E, H, 0.25), lerp(E, H, 0.65)
        arm.fill(arm.line(c0[0], c0[1], c1[0], c1[1], 0.5), CYAN)
    return crisp(a), crisp(arm)


def a3_padded(b):
    """A3 quilted padded armor (anti-augment colours): black weave, violet quilting, high collar, tabards over the thighs"""
    a = A()
    t = b.top
    body = a.poly([(b.X(-b.chest - 0.8), t + 0.6), (b.X(b.chest + 0.8), t + 0.6), (b.X(b.waist + 1.6), t + 19.0), (b.X(-b.waist - 1.6), t + 19.0)])
    for near in (False, True):                                                            # tabards
        P, K = (b.P_n, b.K_n) if near else (b.P_f, b.K_f)
        tab = a.poly([(P[0] - 3.0, P[1] - 3.0), (P[0] + 3.0, P[1] - 3.0), (lerp(P, K, 0.75)[0] + 2.8, lerp(P, K, 0.75)[1]), (lerp(P, K, 0.75)[0] - 2.8, lerp(P, K, 0.75)[1])])
        ramp_paint(a, tab, RAMPS['quilt'], bevel=1.6, strength=1.0)
        a.fill(tab & (a.yy > lerp(P, K, 0.75)[1] - 0.8), VIOLET)
    body |= yoke(a, b, 'quilt')
    ramp_paint(a, body, RAMPS['quilt'], bevel=3.0, strength=1.0)
    q = body & (((np.floor((a.xx + a.yy) / 3.2) + np.floor((a.xx - a.yy) / 3.2)) % 2) == 0)
    edge = body & ((np.abs(((a.xx + a.yy) / 3.2) % 1 - 0.5) > 0.42) | (np.abs(((a.xx - a.yy) / 3.2) % 1 - 0.5) > 0.42))
    a.rgb[edge] = a.rgb[edge] * 0.75                                                       # quilting stitches
    a.fill(edge & (a.yy > t + 4) & (a.yy < t + 5.0), VIOLET)
    collar = a.rrect(b.centre() - 3.6, t - 3.0, 7.2, 4.2, 1.2)
    ramp_paint(a, collar, RAMPS['quilt'], bevel=1.2, strength=1.0)
    a.fill(a.line(b.centre() - 3.4, t + 1.0, b.centre() + 3.4, t + 1.0, 0.5), VIOLET)
    a.fill(a.line(b.X(0.2), t + 1.6, b.X(0.4), t + 19.0, 0.5), VIOLET)                    # violet front seam
    arm = A()
    for near in (True, False):
        E, H = (b.E_n, b.H_n) if near else (b.E_f, b.H_f)
        for k in range(3):                                                                 # arm wraps
            c = lerp(E, H, 0.25 + k * 0.18)
            arm.fill(arm.ellipse(c[0], c[1], b.arm_w[1] / 2 + 0.7, 1.0), T('quilt', 4 - k % 2))
    strap(arm, b, 'quilt', w=2.6)
    pd = arm.ellipse(b.S_n[0] - 0.3, b.S_n[1] + 0.4, 3.4, 2.8)
    ramp_paint(arm, pd, RAMPS['quilt'], bevel=1.4, strength=1.0)
    arm.fill(arm.line(b.S_n[0] - 3.0, b.S_n[1] + 1.2, b.S_n[0] + 2.8, b.S_n[1] + 1.8, 0.5), VIOLET)
    return crisp(a), crisp(arm)


ARMOR = {'A1': ('Scrap plate', a1_scrap), 'A2': ('Tactical plasteel', a2_tactical), 'A3': ('Quilted pad', a3_padded)}


# ------------------------------------------------------------------------------------------------ G1-G3: held guns
class Hold:
    """local frame of the hold: s along the gun (0 at the grip hand, + toward the muzzle), n across it (+ toward the
    gun's underside).  The bore runs at n = -1.6 so the grip hangs into the near hand."""

    def __init__(self, b, k=1.0, direction=None):
        self.k = k                                   # drawing scale (pistols are drawn a little large to read past the fist)
        self.o = b.H_n
        ux, uy = direction if direction else (b.H_f[0] - b.H_n[0], b.H_f[1] - b.H_n[1])
        L = math.hypot(ux, uy)
        self.u = (ux / L, uy / L)
        self.v = (-self.u[1], self.u[0])
        self.L = L

    def p(self, s, n):
        s, n = s * self.k, n * self.k
        return (self.o[0] + s * self.u[0] + n * self.v[0], self.o[1] + s * self.u[1] + n * self.v[1])

    def n_of(self, a):
        return ((a.xx - self.o[0]) * self.v[0] + (a.yy - self.o[1]) * self.v[1]) / self.k


def gpart(a, h, pts, ramp, top=None):
    """one gun part from local (s, n) points: flat mid tone, a lit top edge, a shaded underside"""
    m = a.poly([h.p(s, n) for s, n in pts])
    ns = [n for _, n in pts]
    n0, n1 = min(ns), max(ns)
    nn = h.n_of(a)
    R = RAMPS[ramp] if isinstance(ramp, str) else ramp
    a.fill(m, R[3])
    a.fill(m & (nn < n0 + (n1 - n0) * 0.3), R[5] if top is None else top)
    a.fill(m & (nn > n0 + (n1 - n0) * 0.75), R[1])
    return m


WOOD = ['#2a160a', '#43240f', '#5e3416', '#7c461e', '#985a28', '#b07036', '#c58a4c']
STEEL = ['#0d0e10', '#17191c', '#222529', '#2e3237', '#3d4248', '#535960', '#727a82']
HOSHI = ['#10141b', '#1a202b', '#26303e', '#334052', '#435369', '#586b85', '#7389a6']
SHELL = ['#2a302f', '#3f4746', '#57605f', '#727c7a', '#8d9896', '#a9b4b1', '#c8d1ce']


def g1_rifle(b):
    """G1 Russian-pattern assault rifle: laminated wood stock and handguard, dark steel, curved magazine, slant brake"""
    a = A()
    h = Hold(b)
    B = -1.6
    gpart(a, h, [(-12.5, B - 1.0), (-2.5, B - 1.2), (-2.5, B + 1.6), (-11.5, B + 3.0), (-12.5, B + 2.8)], WOOD)       # stock
    gpart(a, h, [(-2.8, B - 1.5), (8.5, B - 1.5), (8.5, B + 1.4), (-2.8, B + 1.4)], STEEL)                             # receiver
    gpart(a, h, [(5.0, B + 1.2), (8.2, B + 1.2), (8.8, B + 4.0), (7.6, B + 6.6), (5.4, B + 6.0), (6.0, B + 3.6)], STEEL)   # curved magazine
    gpart(a, h, [(8.5, B - 1.3), (17.0, B - 1.1), (17.0, B + 1.3), (8.5, B + 1.4)], WOOD)                              # handguard
    gpart(a, h, [(8.5, B - 2.1), (15.0, B - 2.1), (15.0, B - 1.3), (8.5, B - 1.3)], STEEL)                             # gas tube
    gpart(a, h, [(17.0, B - 0.5), (25.5, B - 0.5), (25.5, B + 0.6), (17.0, B + 0.6)], STEEL)                           # barrel
    gpart(a, h, [(25.5, B - 1.0), (27.5, B - 0.7), (27.5, B + 0.9), (25.5, B + 0.9)], STEEL)                           # slant brake
    gpart(a, h, [(18.4, B - 2.8), (19.2, B - 2.8), (19.2, B - 0.5), (18.4, B - 0.5)], STEEL)                           # front sight
    gpart(a, h, [(-0.6, B + 1.0), (1.4, B + 1.0), (1.0, B + 4.4), (-0.6, B + 4.0)], STEEL)                              # pistol grip
    px(a, *h.p(3.0, B - 0.6), '#7a7f86')                                                                             # selector lever
    return crisp(a)


def g2_smg(b):
    """G2 Japanese-pattern compact SMG: blue-grey polymer box, folded wire stock, straight magazine, cyan status strip,
    small reflex sight"""
    a = A()
    h = Hold(b)
    B = -1.6
    for n in (B - 0.8, B + 1.0):
        gpart(a, h, [(-8.0, n - 0.35), (-2.0, n - 0.35), (-2.0, n + 0.35), (-8.0, n + 0.35)], STEEL)                   # wire stock
    gpart(a, h, [(-8.6, B - 1.0), (-7.6, B - 1.0), (-7.6, B + 1.6), (-8.6, B + 1.6)], STEEL)
    gpart(a, h, [(-2.4, B - 1.9), (12.5, B - 1.9), (12.5, B + 1.8), (-2.4, B + 1.8)], HOSHI)                           # receiver
    gpart(a, h, [(3.2, B + 1.6), (5.4, B + 1.6), (5.4, B + 7.4), (3.2, B + 7.4)], STEEL)                               # magazine
    gpart(a, h, [(13.6, B + 1.4), (15.6, B + 1.4), (15.2, B + 4.6), (13.8, B + 4.6)], HOSHI)                           # fore grip
    gpart(a, h, [(12.5, B - 0.7), (17.0, B - 0.7), (17.0, B + 0.7), (12.5, B + 0.7)], STEEL)                           # barrel shroud
    gpart(a, h, [(17.0, B - 1.1), (19.0, B - 1.1), (19.0, B + 1.1), (17.0, B + 1.1)], STEEL)                           # muzzle
    gpart(a, h, [(4.0, B - 3.4), (7.6, B - 3.4), (7.6, B - 1.9), (4.0, B - 1.9)], STEEL)                               # reflex sight
    px(a, *h.p(5.6, B - 2.8), '#ff9a30')                                                                             # sight dot (amber)
    c0, c1 = h.p(1.0, B + 0.2), h.p(10.5, B + 0.2)
    a.fill(a.line(c0[0], c0[1], c1[0], c1[1], 0.6), CYAN)                                                            # status strip
    a.glow(*h.p(6.0, B + 0.2), 3.0, '#0f6f8a', 0.35)
    gpart(a, h, [(-0.6, B + 1.4), (1.4, B + 1.4), (1.0, B + 4.6), (-0.6, B + 4.2)], HOSHI)                              # pistol grip
    return crisp(a)


def g3_energy(b):
    """G3 bullpup energy rifle: pale ceramic shell, glowing cell at the rear, coil rings down the barrel, emitter tip"""
    a = A()
    h = Hold(b)
    B = -1.6
    gpart(a, h, [(-11.5, B - 1.6), (12.0, B - 2.2), (13.0, B + 0.2), (11.5, B + 2.0), (-11.5, B + 2.2)], SHELL)       # one-piece shell
    cell = gpart(a, h, [(-10.7, B - 0.6), (-6.1, B - 0.6), (-6.1, B + 1.4), (-10.7, B + 1.4)], ['#07261c', '#0b3a2a', '#11563d', '#1a7a55', '#2aa070', '#50e090', '#a8ffd0'])
    a.fill(cell, '#50e090')
    a.glow(*h.p(-8.5, B + 0.4), 4.0, '#1a8a5a', 0.45)
    for k in range(5):                                                                         # coil rings
        s = 14.0 + k * 2.4
        gpart(a, h, [(s, B - 1.5), (s + 1.2, B - 1.5), (s + 1.2, B + 1.3), (s, B + 1.3)], STEEL)
    gpart(a, h, [(13.0, B - 0.6), (26.0, B - 0.6), (26.0, B + 0.6), (13.0, B + 0.6)], STEEL)                           # barrel core
    for k in range(5):
        px(a, *h.p(14.6 + k * 2.4, B), '#50e090')
    tip = gpart(a, h, [(26.0, B - 1.0), (27.6, B - 0.6), (27.6, B + 0.6), (26.0, B + 1.0)], SHELL)
    px(a, *h.p(27.4, B), '#d0ffe8')
    a.glow(*h.p(27.6, B), 3.0, '#1a8a5a', 0.5)
    gpart(a, h, [(-0.6, B + 1.8), (1.4, B + 1.8), (1.0, B + 4.6), (-0.6, B + 4.2)], STEEL)                              # grip
    gpart(a, h, [(2.0, B - 3.2), (6.0, B - 3.2), (6.0, B - 2.0), (2.0, B - 2.0)], STEEL)                               # top rail sight
    return crisp(a)


def p1_compact(b):
    """(held at low ready, muzzle down)  P1 Japanese-pattern compact pistol: graphite slide over a blue-grey polymer frame, cyan rear-sight dots"""
    a = A()
    h = Hold(b, k=1.35, direction=PISTOL_DOWN)
    B = -1.6
    gpart(a, h, [(-2.0, B - 1.4), (8.4, B - 1.4), (8.4, B + 0.6), (-2.0, B + 0.6)], STEEL)                             # slide
    gpart(a, h, [(-1.4, B + 0.6), (7.6, B + 0.6), (7.6, B + 1.6), (-1.4, B + 1.6)], HOSHI)                             # frame
    gpart(a, h, [(-1.2, B + 1.4), (1.6, B + 1.4), (1.0, B + 5.0), (-1.4, B + 4.6)], HOSHI)                              # grip
    gpart(a, h, [(1.6, B + 1.6), (3.6, B + 1.6), (3.6, B + 2.6), (1.6, B + 2.6)], STEEL)                                # trigger guard
    for k in range(3):
        px(a, *h.p(3.0 + k * 1.4, B - 0.6), '#121418')                                                             # slide serrations
    px(a, *h.p(-1.4, B - 1.8), CYAN)
    px(a, *h.p(8.0, B - 1.8), CYAN)
    return crisp(a)


def p2_heavy(b):
    """P2 Russian-pattern heavy revolver: blued steel, long barrel with a top rib, fluted cylinder, worn wood grip"""
    a = A()
    h = Hold(b, k=1.3, direction=PISTOL_DOWN)
    B = -1.6
    gpart(a, h, [(-1.6, B - 1.4), (3.0, B - 1.6), (3.0, B + 1.4), (-1.6, B + 1.0)], STEEL)                             # frame
    cyl = gpart(a, h, [(1.4, B - 1.8), (4.8, B - 1.8), (4.8, B + 1.8), (1.4, B + 1.8)], STEEL)                          # cylinder
    for k in (2.2, 3.4):
        px(a, *h.p(k, B), STEEL[1])                                                                                 # flutes
    gpart(a, h, [(4.8, B - 1.0), (12.0, B - 1.0), (12.0, B + 0.7), (4.8, B + 0.7)], STEEL)                              # barrel
    gpart(a, h, [(4.8, B - 1.7), (12.0, B - 1.7), (12.0, B - 1.0), (4.8, B - 1.0)], STEEL, top=STEEL[6])               # top rib
    gpart(a, h, [(-1.4, B + 1.0), (1.4, B + 1.0), (0.4, B + 5.2), (-2.2, B + 4.6)], WOOD)                               # wood grip
    gpart(a, h, [(-2.4, B - 2.2), (-1.4, B - 2.2), (-1.4, B - 1.2), (-2.4, B - 1.2)], STEEL)                             # hammer
    return crisp(a)


PISTOLS = {'P1': ('Compact pistol, Japanese pattern', p1_compact), 'P2': ('Heavy revolver, Russian pattern', p2_heavy)}


PISTOL_DOWN = (0.56, 0.83)          # low ready: the muzzle angles down and forward from the grip hand


GUNS = {'G1': ('Assault rifle, Russian pattern', g1_rifle), 'G2': ('Compact SMG, Japanese pattern', g2_smg),
        'G3': ('Bullpup energy rifle', g3_energy)}


# ------------------------------------------------------------------------------------------------ dressing a doll
def dress(key='B', cloth=None, armor=None, gun=None, skin=None):
    """compose a doll: body + optional C/A/G option ids; returns the 64x64 image"""
    if skin:
        F.use_skin(skin)
    b = F.BODIES[key]
    L = [F.layer_shadow(b), F.layer_body(b), F.layer_under(b)]
    ca = aa = None
    if cloth:
        c, ca = CLOTHES[cloth][1](b)
        L.append(c)
    if armor:
        ar, aa = ARMOR[armor][1](b)
        L.append(ar)
    L.append(F.layer_arms(b, gap=cloth is None))
    L += [ca, aa]
    if gun:
        L.append((GUNS.get(gun) or PISTOLS[gun])[1](b))
    L.append(F.layer_hands(b))
    out = F.stack(L)
    if skin:
        F.use_skin(F.SKIN_DEFAULT)
    return out
