"""Every outfit and worn item the game draws on people (DollSpec layer ids), redrawn for the standing dolls in the
approved C/A language (t64_wear): cylinder-lit cloth on hue-shifted ramps, real neck openings, sleeves with the
arm-to-torso gap, armor carried over the shoulders.  Colours come from the old top-down layers so factions and
residents still read the same.

Each entry returns {layer key: (image, z)}.  z follows the stack:
    1 back items, 10 body, 15 underwear, 20 outfit, 25 coat, 30 body armor, 32 leg armor, 40 arms, 45 sleeves,
    48 arm armor, 50 held, 60 hands, 70 eyes, 72 hair, 80 head gear"""
import colorsys
import numpy as np
import t64_figure as F
import t64_wear as W
from t64_figure import A, col, lit, mix, px, limb_paint, ramp_paint, crisp, px_mask
from t64_wear import seg, lerp, grow, speck, trousers, shoes, top, sleeve_far_upper, sleeve_near, sleeve_far_fore, yoke, strap

Z = {'back': 1, 'outfit': 20, 'coat': 25, 'armor': 30, 'legs': 32, 'sleeve': 45, 'arm': 48, 'head': 80}


def ramp_from(base, n=7):
    """a 7-step ramp around `base` (index 3): shadows lean toward violet-black, highlights toward warm white"""
    c = col(base)
    out = []
    for k in range(n):
        if k < 3:
            t = (3 - k) / 3.0
            out.append(mix(c, col('#160f22'), 0.82 * t ** 0.9))
        elif k == 3:
            out.append(c)
        else:
            t = (k - 3) / 3.0
            out.append(mix(c, col('#fff2da'), 0.5 * t))
    return ['#%02x%02x%02x' % tuple(int(round(v * 255)) for v in x) for x in out]


def R(name_or_hex):
    """register a ramp for a base colour in the shared table and return its name"""
    if name_or_hex in W.RAMPS:
        return name_or_hex
    key = 'c' + name_or_hex.lstrip('#')
    if key not in W.RAMPS:
        W.RAMPS[key] = ramp_from(name_or_hex)
    return key


def T(ramp, i):
    return W.T(R(ramp), i)


def arm_layer(b, fn, ramp):
    return W.arm_layer(b, fn, R(ramp))


# ------------------------------------------------------------------------------------------------ garment recipe
def garment(b, top_c, legs_c, shoe='sneaker', sole='#c9c4b8', neck='crew', depth=1.8, length=21.5, sleeves='long',
            tall=0.0, toe=None, lining=None, wide=1.0, extra_top=0.7, hem=1, knee=None, pocket=False, sleeve_extra=1.2):
    """the shared shape of an outfit: trousers, shoes, a top with a neck opening, sleeves.  Returns (a, arm, m, hole)."""
    a = A()
    tc, lc = R(top_c), R(legs_c)
    if sleeves != 'none':
        sleeve_far_upper(a, b, tc, extra=sleeve_extra)
    trousers(a, b, lc, wide=wide, knee_patch=R(knee) if knee else None, pocket=pocket)
    shoes(a, b, shoe, tall=tall, sole=sole, toe_cap=toe)
    m, hole = top(a, b, tc, length=length, extra=extra_top, hem=hem, neck=neck, depth=depth)
    if lining:
        a.fill(grow(a, hole, 0.8) & m, lining)
    if sleeves == 'long':
        arm = arm_layer(b, lambda a2: (sleeve_near(a2, b, tc, extra=sleeve_extra, cuff=1), sleeve_far_fore(a2, b, tc, extra=sleeve_extra, cuff=1)), tc)
    elif sleeves == 'rolled':
        arm = arm_layer(b, lambda a2: (sleeve_near(a2, b, tc, to=0.0, roll=True, extra=sleeve_extra), None), tc)
    else:
        arm = None
    return a, arm, m, hole


def zip_line(a, b, c, y0=1.4, y1=21.0):
    t = b.top
    a.fill(a.line(b.X(0.3), t + y0, b.X(0.3), t + y1, 0.5), c)


def skirt(a, b, ramp, hem_y, flare=2.5, split=False, length_from=17.5):
    """a long hem below the hips (coat tails, robes): drawn over the trousers"""
    t = b.top
    rr = R(ramp)
    if split:
        for sgn in (-1, 1):
            x_in = b.X(sgn * 0.6)
            x_out = b.X(sgn * (b.hip + 1.2)) + sgn * flare
            pts = [(b.X(sgn * (b.waist + 1.0)), t + length_from), (x_in, t + length_from), (x_in + sgn * 0.6, hem_y), (x_out, hem_y)]
            m = a.poly(pts)
            ramp_paint(a, m, W.RAMPS[rr], bevel=2.4, strength=1.0)
            a.rgb[m & (a.yy > hem_y - 1.2)] = col(W.T(rr, 1))
    else:
        pts = [(b.X(-b.waist - 1.0), t + length_from), (b.X(b.waist + 1.0), t + length_from), (b.X(b.hip + 1.0) + flare, hem_y), (b.X(-b.hip - 1.0) - flare, hem_y)]
        m = a.poly(pts)
        ramp_paint(a, m, W.RAMPS[rr], bevel=3.0, strength=1.0)
        for k in (-2.0, 2.6):                                                               # folds
            a.fill(a.line(b.X(k), t + length_from + 3, b.X(k * 1.3), hem_y - 1, 0.5), W.T(rr, 2))
        a.rgb[m & (a.yy > hem_y - 1.2)] = col(W.T(rr, 1))


# ------------------------------------------------------------------------------------------------ outfits (z 20)
RESIDENT = ['#3d6a8e', '#8e4a3d', '#4f7a4c', '#7a5a8e', '#b08a3a', '#5e6672']


def o_resident(i):
    def f(b):
        shoe, sole = (('sneaker', '#c9c4b8'), ('shoe', '#060607'), ('boot', '#140c08'))[i % 3]
        a, arm, m, hole = garment(b, RESIDENT[i], ['denim', 'slate', '#4a4038', 'denim', 'slate', '#3c4a3a'][i], shoe=shoe, sole=sole,
                                  lining='#1a1c20', pocket=i % 2 == 0, knee='slate' if i == 3 else None, tall=3.0 if shoe == 'boot' else 0)
        zip_line(a, b, '#a0a6ac')
        if i in (1, 4):
            a.fill(a.rect(b.X(-b.sh + 2.2), b.top + 3.0, 2.4, 2.0), T(RESIDENT[i], 1))     # a worn patch
        speck(a, m, T(RESIDENT[i], 1), 0.04, 100 + i)
        return {'jacket_%d' % i: (crisp(a), Z['outfit']), 'jacket_%d_arm' % i: (arm, Z['sleeve'])}
    return f


def o_thug(b):
    """Bratva: red leather bomber, dark collar, the yellow brotherhood patch, black trousers, boots"""
    a, arm, m, hole = garment(b, '#d02a38', 'slate', shoe='boot', sole='#0c0806', tall=3.5, lining='#4a0f15')
    t = b.top
    zip_line(a, b, '#c9b07a')
    for y in (t + 5.0, t + 11.0):
        a.fill(a.line(b.X(-b.chest + 1.2), y + 1.2, b.X(-1.0), y, 0.6) & m, T('#d02a38', 5))   # leather sheen
    p = a.ellipse(b.X(-5.2), t + 4.8, 1.8)
    a.fill(p, '#e8c53a')
    a.fill(a.ellipse(b.X(-5.2), t + 4.8, 0.9), '#a31f2a')
    a.fill(a.rect(b.X(-b.waist - 1.0), t + 20.2, b.X(b.waist + 1.0) - b.X(-b.waist - 1.0), 1.4) & m, T('#d02a38', 1))   # hem band
    speck(a, m, T('#d02a38', 1), 0.05, 110)
    return {'thug': (crisp(a), Z['outfit']), 'thug_arm': (arm, Z['sleeve'])}


def o_nap(b):
    """NAP: navy duty uniform, white shoulder flash, cyan stripe, duty belt with pouches, cyan trouser stripe"""
    a, arm, m, hole = garment(b, '#2f5083', '#203a60', shoe='shoe', sole='#050506', lining='#14253d', tall=2.0)
    t = b.top
    zip_line(a, b, '#14253d', y1=17.0)
    for sgn in (-1, 1):
        px(a, b.X(sgn * 4.2) - 1.5, t + 5.0, '#14253d', w=3, h=3)                               # chest pockets
    a.fill(a.line(b.X(-b.chest + 1.0), t + 8.2, b.X(b.chest - 1.0), t + 8.2, 0.5) & m, '#35d7ff')
    belt = a.rect(b.X(-b.waist - 1.0), t + 16.2, b.X(b.waist + 1.0) - b.X(-b.waist - 1.0), 2.0)
    a.fill(belt, '#0b1422')
    for x in (-5.4, -2.4, 3.6):
        px(a, b.X(x), t + 16.4, '#2a2e35', w=2, h=3)
    a.fill(a.line(b.P_n[0] - 2.6, b.P_n[1] + 2, b.K_n[0] - 2.4, b.K_n[1] - 1, 0.5), '#35d7ff')   # trouser stripe
    am = lambda a2: (sleeve_near(a2, b, R('#2f5083'), cuff=1), sleeve_far_fore(a2, b, R('#2f5083'), cuff=1),
                     a2.fill(a2.ellipse(b.S_n[0] - 0.2, b.S_n[1] + 1.4, 1.8, 1.0), '#e8e8e8'),
                     a2.fill(a2.ellipse(b.S_n[0] - 0.2, b.S_n[1] + 2.6, 1.8, 0.5), '#35d7ff'))
    arm = arm_layer(b, am, '#2f5083')
    return {'nap': (crisp(a), Z['outfit']), 'nap_arm': (arm, Z['sleeve'])}


def o_nasim(b):
    """Nasim: black fitted suit with violet seams, black shirt in a V, slim trousers, black shoes"""
    a, arm, m, hole = garment(b, '#2a2c36', '#1e2028', shoe='shoe', sole='#050506', neck='v', depth=5.5, wide=0.6, extra_top=0.5, hem=2)
    t = b.top
    c = b.centre()
    shirt = hole & ~a.ellipse(c, t - 1.6, 3.0, 2.8) & (a.yy > t - 1.0)
    a.fill(shirt, '#121218')
    a.a[shirt] = 1.0
    for sgn in (-1, 1):
        a.fill(a.line(b.X(sgn * 3.0), t + 4.0, b.X(sgn * 6.0), t + 22.0, 0.5) & m, '#8a1fe0')
    a.fill(a.line(b.P_n[0] - 2.4, b.P_n[1] + 2, b.K_n[0] - 2.2, b.K_n[1], 0.5), '#8a1fe0')
    return {'nasim': (crisp(a), Z['outfit']), 'nasim_arm': (arm, Z['sleeve'])}


def o_suit(b):
    """corporate suit: charcoal jacket with lapels, white shirt, cyan pocket square, black shoes (C2 cut)"""
    a, arm, m, hole = garment(b, '#2c2f3a', '#23262f', shoe='shoe', sole='#050506', neck='v', depth=6.5, wide=0.6, extra_top=0.5, hem=2, sleeve_extra=0.9)
    t = b.top
    c = b.centre()
    shirt = hole & ~a.ellipse(c, t - 1.6, 3.0, 2.8) & (a.yy > t - 1.0)
    a.fill(shirt, '#e9e9ee')
    a.fill(shirt & (a.yy < t + 1.2), '#c9cfd6')
    a.a[shirt] = 1.0
    a.fill(a.line(c, t + 1.0, c + 0.2, t + 6.0, 0.6), '#5a2a3a')                              # tie
    for sgn, x0 in ((-1, c - 3.6), (1, c + 3.4)):
        a.fill(a.line(x0, t - 0.4, c + 0.1, t + 6.5, 1.1) & m, T('#2c2f3a', 5))
    px(a, b.X(-6.0), t + 6.0, '#35d7ff', w=2)                                                  # pocket square
    for y in (t + 9.0, t + 13.5):
        px(a, b.X(1.4), y, T('#2c2f3a', 1))
    return {'suit': (crisp(a), Z['outfit']), 'suit_arm': (arm, Z['sleeve'])}


def o_labcoat(b):
    """lab coat: white to the knee, lapels, a cyan badge (no text), pens in the pocket; slate trousers"""
    a, arm, m, hole = garment(b, '#e6eaee', 'slate', shoe='shoe', sole='#050506', neck='v', depth=6.0, length=22.0, sleeve_extra=1.4)
    t = b.top
    skirt(a, b, '#e6eaee', 50.0, flare=1.6, split=True)
    c = b.centre()
    shirt = hole & ~a.ellipse(c, t - 1.6, 3.0, 2.8) & (a.yy > t - 1.0)
    a.fill(shirt, '#7d8ea3')
    a.a[shirt] = 1.0
    a.fill(a.rect(b.X(3.2), t + 6.0, 2.6, 1.4), '#35d7ff')
    px(a, b.X(-5.0), t + 5.6, '#2a5a9a', h=2)
    px(a, b.X(-4.0), t + 5.6, '#c03a3a', h=2)
    a.fill(a.line(b.X(0.4), t + 6.0, b.X(0.5), 50.0, 0.5), T('#e6eaee', 2))
    speck(a, a.a > 0.5, T('#e6eaee', 2), 0.02, 120)                                            # a few stains
    return {'labcoat': (crisp(a), Z['outfit']), 'labcoat_arm': (arm, Z['sleeve'])}


def o_chef(b):
    """chef: double-breasted white jacket, two button rows, tan apron to the knee, grey check trousers, black clogs"""
    a, arm, m, hole = garment(b, '#f4f2ec', '#5a5e66', shoe='shoe', sole='#050506', neck='crew', depth=1.0, length=21.0, sleeves='rolled')
    t = b.top
    for sgn in (-1, 1):
        for y in (t + 5.0, t + 9.5, t + 14.0):
            px(a, b.X(sgn * 3.2), y, '#8a8478')
    ap = a.poly([(b.X(-b.waist - 0.5), t + 15.0), (b.X(b.waist + 0.5), t + 15.0), (b.X(b.hip + 0.6), 48.5), (b.X(-b.hip - 0.6), 48.5)])
    ramp_paint(a, ap, W.RAMPS[R('#cbbfa6')], bevel=2.4, strength=1.0)
    a.fill(a.rect(b.X(-b.waist - 0.5), t + 15.0, b.X(b.waist + 0.5) - b.X(-b.waist - 0.5), 1.0), T('#cbbfa6', 1))
    legs = (a.a > 0.5) & (a.yy > 48.5) & (a.yy < 58)
    chk = legs & ((((a.xx // 1.5) + (a.yy // 1.5)) % 2) == 0)
    a.rgb[chk] = a.rgb[chk] * 0.8
    speck(a, ap, '#8a6a4a', 0.04, 121)
    return {'chef': (crisp(a), Z['outfit']), 'chef_arm': (arm, Z['sleeve'])}


def o_robe(key, body_c, trim, stole=None, hakama=None):
    def f(b):
        legs_c = hakama or body_c
        a, arm, m, hole = garment(b, body_c, legs_c, shoe='shoe', sole='#050506', neck='v', depth=4.5, length=22.0, wide=1.6, sleeve_extra=2.4)
        t = b.top
        if hakama:
            skirt(a, b, hakama, 59.0, flare=3.2, length_from=16.5)                              # pleated hakama
            for k in (-1.5, 1.5):
                a.fill(a.line(b.X(k), t + 19.0, b.X(k * 1.6), 58.5, 0.5), T(hakama, 2))
            a.fill(a.rect(b.X(-b.waist - 1.0), t + 15.4, b.X(b.waist + 1.0) - b.X(-b.waist - 1.0), 1.6), stole or trim)   # sash
        else:
            skirt(a, b, body_c, 59.5, flare=2.8)
        for sgn in (-1, 1):                                                                    # crossover collar edges
            a.fill(a.line(b.centre() + sgn * 3.4, t - 0.6, b.centre() + 0.1, t + 4.5, 0.9) & ~hole, trim)
        if stole and not hakama:
            for sgn in (-1, 1):
                a.fill(a.line(b.X(sgn * 2.4), t + 0.5, b.X(sgn * 2.6), 54.0, 1.6), stole)
        return {key: (crisp(a), Z['outfit']), key + '_arm': (arm, Z['sleeve'])}
    return f


def o_overalls(b):
    """dock overalls: grey-blue work shirt, blue bib overalls with brass buttons, boots (C3 language)"""
    a, arm, m, hole = garment(b, '#6e7d94', '#3d5a8c', shoe='boot', sole='#140c08', tall=4.0, toe='#8d8f92', sleeves='rolled', knee='#2e4670')
    t = b.top
    bib = a.rrect(b.X(-b.waist + 0.4), t + 6.0, b.X(b.waist - 0.4) - b.X(-b.waist + 0.4), 14.0, 1.2)
    ramp_paint(a, bib, W.RAMPS[R('#3d5a8c')], bevel=1.8, strength=1.0)
    for sgn in (-1, 1):
        a.fill(a.line(b.X(sgn * 4.0), t + 0.2, b.X(sgn * 3.6), t + 6.4, 1.4), T('#3d5a8c', 3))
        px(a, b.X(sgn * 3.6) - 0.5, t + 6.2, '#e0c26a')
    a.fill(a.rrect(b.X(-2.2), t + 9.0, b.X(2.2) - b.X(-2.2), 3.0, 0.6), T('#3d5a8c', 2))       # bib pocket
    speck(a, a.a > 0.5, '#2a2018', 0.05, 130)
    return {'overalls': (crisp(a), Z['outfit']), 'overalls_arm': (arm, Z['sleeve'])}


def o_courier(b):
    """courier: amber jacket with reflective bands, a messenger bag on a strap across the chest, dark trousers"""
    a, arm, m, hole = garment(b, '#e0a02a', 'denim', lining='#8a5e12')
    t = b.top
    zip_line(a, b, '#7a540f')
    a.fill(a.rect(b.X(-b.waist - 1.0), t + 12.0, b.X(b.waist + 1.0) - b.X(-b.waist - 1.0), 1.2) & m, '#e9e9e9')
    a.fill(a.line(b.X(-b.sh + 3.0), t + 0.4, b.X(b.waist + 0.6), t + 17.0, 1.6), '#2b2218')      # strap
    bag = a.rrect(b.X(b.hip - 1.0), t + 16.0, 5.0, 5.4, 1.0)
    ramp_paint(a, bag, W.RAMPS[R('#3a2e22')], bevel=1.2, strength=1.0)
    a.fill(bag & (a.yy < t + 17.6), T('#3a2e22', 5))
    am = lambda a2: (sleeve_near(a2, b, R('#e0a02a'), cuff=1), sleeve_far_fore(a2, b, R('#e0a02a'), cuff=1),
                     a2.fill(a2.ellipse(*lerp(b.E_n, b.H_n, 0.45), b.arm_w[1] / 2 + 0.8, 0.6), '#e9e9e9'))
    arm = arm_layer(b, am, '#e0a02a')
    return {'courier': (crisp(a), Z['outfit']), 'courier_arm': (arm, Z['sleeve'])}


OUTFITS = {'jacket_%d' % i: o_resident(i) for i in range(6)}
OUTFITS.update({'thug': o_thug, 'nap': o_nap, 'nasim': o_nasim, 'suit': o_suit, 'labcoat': o_labcoat, 'chef': o_chef,
                'priest': o_robe('priest', '#15151a', '#c79b3c', stole='#c79b3c'),
                'kannushi': o_robe('kannushi', '#e8e6dc', '#4a6a9a', stole='#7b3fa0', hakama='#4a6a9a'),
                'overalls': o_overalls, 'courier': o_courier})


# ------------------------------------------------------------------------------------------------ worn gear and armor
def k_coat(b):
    """long coat: charcoal-blue to the knee, open front, collar flaps, belt, sleeves (worn over any outfit)"""
    cc = '#4a5563'
    a = A()
    t = b.top
    rr = R(cc)
    sleeve_far_upper(a, b, rr, extra=1.8)
    skirt(a, b, cc, 52.5, flare=2.6, split=True, length_from=15.0)
    body = grow(a, b.torso(a), 1.1) & (a.yy < t + 17)
    hole = W.neck_hole(a, b, 'open', 7.5)
    front = a.poly([(b.X(-0.6), t + 5.0), (b.X(1.2), t + 5.0), (b.X(1.2), t + 17), (b.X(-0.6), t + 17)])
    m = body & ~hole & ~front
    ramp_paint(a, m, W.RAMPS[rr], bevel=3.0, strength=1.0)
    for sgn in (-1, 1):                                                                      # wide lapels
        lap = a.poly([(b.centre() + sgn * 3.8, t - 1.6), (b.centre() + sgn * 6.4, t + 2.0), (b.centre() + sgn * 1.4, t + 7.8)]) & m
        a.fill(lap, T(cc, 5 if sgn < 0 else 4))
    a.fill(a.rect(b.X(-b.waist - 1.2), t + 14.6, b.X(b.waist + 1.2) - b.X(-b.waist - 1.2), 1.4) & (a.a > 0.5), T(cc, 1))
    for y in (t + 6.0, t + 10.0):
        px(a, b.X(-2.0), y, '#9aa3ad')
    arm = arm_layer(b, lambda a2: (sleeve_near(a2, b, rr, extra=1.8, cuff=1), sleeve_far_fore(a2, b, rr, extra=1.8, cuff=1)), cc)
    return {'coat': (crisp(a), Z['coat']), 'coat_arm': (arm, Z['sleeve'] + 1)}


def k_vest(variant):
    """ballistic vest (soft, olive), plate carrier (olive plates, pouches, shoulder pads) or corporate liner (thin, cyan)"""
    def f(b):
        base = {'vest': '#5c7050', 'vest_heavy': '#4f5f45', 'vest_corp': '#262a33'}[variant]
        a = A()
        t = b.top
        rr = R(base)
        torso_ = a.poly([(b.X(-b.chest - 0.5), t + 2.2), (b.X(b.chest + 0.5), t + 2.2), (b.X(b.waist + 1.0), t + (15.5 if variant != 'vest_corp' else 14.0)),
                         (b.X(-b.waist - 1.0), t + (15.5 if variant != 'vest_corp' else 14.0))])
        ramp_paint(a, torso_, W.RAMPS[rr], bevel=2.2, strength=1.0)
        yoke(a, b, rr)
        if variant == 'vest':
            for y in (t + 6.0, t + 10.0):
                a.fill(a.line(b.X(-b.chest + 1.0), y, b.X(b.chest - 1.0), y, 0.5) & torso_, T(base, 2))
            a.fill(a.rect(b.X(-b.chest + 0.5), t + 12.4, b.X(b.chest - 0.5) - b.X(-b.chest + 0.5), 2.2) & torso_, T(base, 2))     # cummerbund
        elif variant == 'vest_heavy':
            pl = a.rrect(b.X(-5.0), t + 3.6, b.X(5.0) - b.X(-5.0), 6.6, 1.2)
            ramp_paint(a, pl, W.RAMPS[R('#6d7d60')], bevel=1.4, strength=1.0)
            for x in (-4.0, -0.6, 2.8):
                p = a.rrect(b.X(x) - 1.4, t + 10.8, 3.0, 3.6, 0.6)
                a.fill(p, T(base, 2))
                a.fill(p & (a.yy < t + 11.6), T(base, 5))
            speck(a, torso_, T(base, 1), 0.08, 140)
        else:
            a.fill(a.line(b.X(-b.chest + 0.8), t + 4.4, b.X(b.chest - 0.8), t + 4.4, 0.6), '#35d7ff')
            px(a, b.centre() - 1, t + 7.0, '#c9d0d8', w=2, h=2)
        out = {variant: (crisp(a), Z['armor'])}
        if variant == 'vest_heavy':
            arm = A()
            strap(arm, b, rr, w=2.6)
            pn = arm.ellipse(b.S_n[0] - 0.4, b.S_n[1] + 0.6, 3.4, 2.8)
            ramp_paint(arm, pn, W.RAMPS[rr], bevel=1.4, strength=1.0)
            arm.fill(pn & (arm.yy < b.S_n[1] - 0.6), T(base, 5))
            pf = arm.ellipse(b.S_f[0] + 0.8, b.S_f[1] + 0.6, 2.8, 2.4)
            ramp_paint(arm, pf, W.RAMPS[rr], bevel=1.2, strength=1.0)
            out['vest_heavy_arm'] = (crisp(arm), Z['arm'])
        return out
    return f


def k_riot_jacket(b):
    """riot jacket: quilted dark grey padding (A3 language) with shoulder and elbow pads and a reflective band"""
    base = '#3a4048'
    rr = R(base)
    a = A()
    t = b.top
    sleeve_far_upper(a, b, rr, extra=2.0)
    m, hole = top(a, b, rr, length=20.5, extra=1.2, neck='crew', depth=1.6)
    edge = m & ((np.abs(((a.xx + a.yy) / 3.2) % 1 - 0.5) > 0.42) | (np.abs(((a.xx - a.yy) / 3.2) % 1 - 0.5) > 0.42))
    a.rgb[edge] = a.rgb[edge] * 0.75
    a.fill(a.rect(b.X(-b.chest), t + 9.0, b.X(b.chest) - b.X(-b.chest), 1.0) & m, '#d8dde0')
    yoke(a, b, rr)
    arm = A()
    sleeve_near(arm, b, rr, extra=2.0, cuff=1)
    sleeve_far_fore(arm, b, rr, extra=2.0, cuff=1)
    for E in (b.E_n, b.E_f):
        e = arm.ellipse(E[0], E[1], 2.4, 2.0)
        ramp_paint(arm, e, W.RAMPS[R('#2a2e34')], bevel=1.0, strength=1.0)
    pn = arm.ellipse(b.S_n[0] - 0.4, b.S_n[1] + 0.6, 3.4, 2.8)
    ramp_paint(arm, pn, W.RAMPS[R('#2a2e34')], bevel=1.4, strength=1.0)
    strap(arm, b, R('#2a2e34'))
    tor = px_mask(arm, b.torso(arm))
    yy_, xx_ = np.mgrid[0:64, 0:64]
    gap = tor & (yy_ >= b.S_n[1] + 2.5) & (yy_ < b.E_n[1] + 0.5) & (xx_ < b.centre())
    return {'jacket': (crisp(a), Z['armor']), 'jacket_arm': (crisp(arm, no_outline=tor & (yy_ < b.E_n[1] + 0.5) & (xx_ < b.centre()), soft=(gap, tuple(col(T(base, 0))))), Z['arm'])}


def k_bracers(heavy):
    def f(b):
        base = '#4a5560' if heavy else '#5d6a58'
        rr = R(base)
        arm = A()
        for near in (True, False):
            E, H = (b.E_n, b.H_n) if near else (b.E_f, b.H_f)
            limb_paint(arm, lerp(E, H, 0.15), lerp(E, H, 0.78), b.arm_w[1] + 1.4, b.arm_w[1] * 0.85 + 1.2, ramp=W.RAMPS[rr])
            for k in (0.3, 0.55):
                c = lerp(E, H, k)
                arm.fill(arm.ellipse(c[0], c[1], b.arm_w[1] / 2 + 0.8, 0.45), T(base, 1))
            if heavy:
                e = arm.ellipse(E[0], E[1], 2.5, 2.2)
                ramp_paint(arm, e, W.RAMPS[rr], bevel=1.0, strength=1.0)
                arm.fill(e & (arm.yy < E[1] - 0.8), T(base, 6))
        if heavy:
            S0 = (b.S_n[0] + 0.6, b.S_n[1] + 1.2)
            limb_paint(arm, S0, lerp(S0, b.E_n, 0.75), b.arm_w[0] + 1.0, b.arm_w[1] + 1.2, ramp=W.RAMPS[rr], rim_dir=(-1, 0))
        k = 'bracers_heavy' if heavy else 'bracers'
        return {k: (crisp(arm), Z['arm'])}
    return f


def k_greaves(heavy):
    def f(b):
        base = '#4a5560' if heavy else '#5d6a58'
        rr = R(base)
        a = A()
        for near in (False, True):
            P, K, Aa = (b.P_n, b.K_n, b.A_n) if near else (b.P_f, b.K_f, b.A_f)
            d = 0 if near else 1
            seg(a, (K[0], K[1] + 0.8), lerp(K, Aa, 0.82), b.leg_w[1] + 2.0, b.leg_w[1] * 0.78 + 1.8, rr, dim=d)
            a.fill(a.line(K[0] - 0.4, K[1] + 2.0, lerp(K, Aa, 0.75)[0] - 0.4, lerp(K, Aa, 0.75)[1], 0.5), T(base, 5 - d))   # ridge
            if heavy:
                kc = a.ellipse(K[0], K[1] - 0.2, 2.7, 2.3)
                ramp_paint(a, kc, W.RAMPS[rr], bevel=1.0, strength=1.0)
                seg(a, lerp(P, K, 0.25), lerp(P, K, 0.85), b.leg_w[0] + 1.2, b.leg_w[1] + 1.6, rr, dim=d)
                a.fill(a.line(*lerp(P, K, 0.5), *lerp(P, K, 0.5), 0.0001), base, 0.0)
        k = 'greaves_heavy' if heavy else 'greaves'
        return {k: (crisp(a), Z['legs'])}
    return f


def k_kneepads(b):
    a = A()
    for near in (False, True):
        K = b.K_n if near else b.K_f
        kp = a.ellipse(K[0], K[1] - 0.3, 2.7, 2.3)
        ramp_paint(a, kp, W.RAMPS[R('#2b2e33')], bevel=1.0, strength=1.0)
        a.fill(a.line(K[0] - 2.4, K[1] + 1.6, K[0] + 2.4, K[1] + 1.6, 0.6), '#14161a')
    return {'kneepads': (crisp(a), Z['legs'] + 1)}


def k_backpack(b):
    """commuter backpack: the pack shows behind the far shoulder; straps run over the chest"""
    base = '#3e4a5a'
    rr = R(base)
    back = A()
    pk = back.rrect(b.S_f[0] - 3.0, b.top + 1.0, 8.5, 17.0, 2.4)
    ramp_paint(back, pk, W.RAMPS[rr], bevel=2.0, strength=1.0)
    back.fill(back.rect(b.S_f[0] - 2.4, b.top + 8.0, 7.0, 0.6), T(base, 1))
    front = A()
    for sgn, S in ((-1, b.S_n), (1, b.S_f)):
        a0 = (b.centre() + sgn * 3.4, b.top - 0.6)
        a1 = (S[0] - sgn * 0.6, b.top + 12.0)
        front.fill(front.line(a0[0], a0[1], a1[0], a1[1], 1.6), T(base, 2))
        front.fill(front.line(a0[0] - 0.4, a0[1], a1[0] - 0.4, a1[1], 0.5), T(base, 4))
    front.fill(front.rect(b.X(-4.0), b.top + 7.0, b.X(4.0) - b.X(-4.0), 0.8), T(base, 1))       # sternum strap
    px(front, b.centre(), b.top + 6.8, '#9aa3ad')
    return {'backpack_back': (crisp(back), Z['back']), 'backpack': (crisp(front), Z['armor'] + 4)}


def k_holster(b):
    """thigh holster on the near leg: two straps and a holster with a pistol grip showing"""
    a = A()
    P, K = b.P_n, b.K_n
    for k in (0.3, 0.62):
        c = lerp(P, K, k)
        a.fill(a.ellipse(c[0], c[1], b.leg_w[0] / 2 + 1.0, 0.6), '#1c1d22')
    h0 = lerp(P, K, 0.2)
    hol = a.rrect(h0[0] - 3.6, h0[1], 3.6, 8.0, 0.8)
    ramp_paint(a, hol, W.RAMPS[R('#2a2c30')], bevel=1.0, strength=1.0)
    grip = a.rrect(h0[0] - 3.2, h0[1] - 2.6, 2.4, 3.0, 0.6)
    a.fill(grip, '#17191c')
    a.fill(grip & (a.yy < h0[1] - 1.8), '#3d4248')
    return {'holster': (crisp(a), Z['legs'] + 2)}


# ---- head gear (head centre at b.centre(), b.head_cy)
def _head(b):
    return b.centre(), b.head_cy, b.head[0], b.head[1]


def k_helmet(b):
    """ballistic helmet: olive dome to the brow, rim, chin strap"""
    a = A()
    hx, hy, rx, ry = _head(b)
    dome = a.ellipse(hx - 0.2, hy - 1.0, rx + 1.4, ry + 0.4) & (a.yy < hy - 0.6)
    ramp_paint(a, dome, W.RAMPS[R('#4f5f45')], bevel=2.2, strength=1.0)
    a.fill(a.rect(hx - rx - 1.4, hy - 1.4, 2 * rx + 2.6, 1.0) & a.ellipse(hx - 0.2, hy - 1.0, rx + 1.6, ry + 0.6), T('#4f5f45', 1))   # rim
    a.fill(a.line(hx - rx + 0.4, hy - 0.6, hx - rx + 1.2, hy + ry - 1.0, 0.5), '#1c1d22')         # chin strap
    speck(a, dome, T('#4f5f45', 2), 0.08, 150)
    return {'helmet_ball': (crisp(a), Z['head'])}


def k_visor(b):
    """riot visor helmet: navy dome with a tinted visor down over the face"""
    a = A()
    hx, hy, rx, ry = _head(b)
    dome = a.ellipse(hx - 0.2, hy - 1.2, rx + 1.5, ry + 0.6) & (a.yy < hy + 0.4)
    ramp_paint(a, dome, W.RAMPS['navy'], bevel=2.2, strength=1.0)
    vis = a.ellipse(hx + 0.6 * b.turn, hy + 1.0, rx + 0.8, ry - 0.4) & (a.yy > hy - 2.0) & (a.yy < hy + ry - 1.0)
    a.fill(vis, '#1b3a4a')
    a.fill(vis & (a.yy < hy - 0.8), '#5aa6c8')
    a.fill(vis & (a.xx < hx - 1.2) & (a.yy < hy + 1.0), '#3d7a94')                                 # reflection
    a.fill(a.rect(hx - rx - 1.2, hy - 2.4, 2 * rx + 2.4, 0.8), '#35d7ff')
    return {'visor': (crisp(a), Z['head'])}


def k_helm_tac(b):
    """tactical helmet: grey cut-away shell, side rails, a night-vision mount and a small cyan side light"""
    a = A()
    hx, hy, rx, ry = _head(b)
    dome = a.ellipse(hx - 0.2, hy - 1.2, rx + 1.3, ry + 0.3) & (a.yy < hy - 0.6)
    ramp_paint(a, dome, W.RAMPS[R('#4a4f56')], bevel=2.0, strength=1.0)
    a.fill(a.rect(hx - rx - 1.0, hy - 2.2, 2.0, 2.4), T('#4a4f56', 1))                             # rail
    m = a.rect(hx - 1.0 + b.turn, hy - ry - 0.4, 2.6, 2.0)
    a.fill(m, '#1c1d22')
    px(a, hx - rx - 0.6, hy - 1.6, '#35d7ff')
    return {'helm_tac': (crisp(a), Z['head'])}


def k_balaclava(b):
    """balaclava: black knit over head and neck with an open band across the eyes"""
    a = A()
    hx, hy, rx, ry = _head(b)
    head = b.head_mask(a)[0] | a.ellipse(hx, hy - 0.4, rx + 0.5, ry + 0.4) | b.neck(a)
    slot = a.rect(hx - rx + 0.6, hy - 1.6, 2 * rx - 0.4, 2.8)
    m = head & ~slot
    ramp_paint(a, m, W.RAMPS[R('#1e1f24')], bevel=2.0, strength=1.0)
    knit = m & (((a.xx * 2).astype(int) + (a.yy * 2).astype(int)) % 4 == 0)
    a.rgb[knit] = a.rgb[knit] * 0.8
    return {'balaclava': (crisp(a), Z['head'] - 6)}


WORN = {'coat': k_coat, 'vest': k_vest('vest'), 'vest_heavy': k_vest('vest_heavy'), 'vest_corp': k_vest('vest_corp'),
        'jacket': k_riot_jacket, 'bracers': k_bracers(False), 'bracers_heavy': k_bracers(True),
        'greaves': k_greaves(False), 'greaves_heavy': k_greaves(True), 'kneepads': k_kneepads,
        'backpack': k_backpack, 'holster': k_holster, 'helmet_ball': k_helmet, 'visor': k_visor, 'helm_tac': k_helm_tac,
        'balaclava': k_balaclava}


def all_layers(b):
    """every outfit and worn layer for body b: {key: (image, z)}"""
    out = {}
    for k, fn in list(OUTFITS.items()) + list(WORN.items()):
        out.update(fn(b))
    return {k: v for k, v in out.items() if v[0] is not None}
