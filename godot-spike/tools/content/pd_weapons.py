"""Weapon icons for the paper-doll sheet: one drawn icon per gun and melee weapon (and its forged / masterwork grades).
Every icon points to the right (muzzle / blade tip at the right) so the game can rotate it into a hand."""
import random, hashlib
from pdlib import C, hx, lit, dark

# makers by the first letter of the model code
MAKER = {
    'H': dict(body=hx('4a5668'), acc=hx('38d8ff'), wood=hx('8a6a48')),   # Hoshikawa: blue steel, cyan
    'S': dict(body=hx('5c5c68'), acc=hx('ff9a30'), wood=hx('7a5c3c')),   # Sakurai: grey, orange
    'V': dict(body=hx('3e4636'), acc=hx('d8c050'), wood=hx('8c5a34')),   # Volkov: olive, brass, wood
    'Z': dict(body=hx('36402e'), acc=hx('e05050'), wood=hx('96623a')),   # Zaytsev: dark green, red
    'G': dict(body=hx('2c2c32'), acc=hx('c8b080'), wood=hx('5a4a38')),   # Grant: black, tan
    'L': dict(body=hx('66707c'), acc=hx('50e090'), wood=hx('7a6a50')),   # Lin: light steel, jade
    'F': dict(body=hx('504a5a'), acc=hx('ff58b0'), wood=hx('6a5a4a')),   # Fujimoto: plum, magenta
}

def rng_for(id_):
    return random.Random(int(hashlib.md5(id_.encode()).hexdigest()[:8], 16))

def marks(c, r, x0, x1, y0, y1, col, n=3):
    """serial-number dashes: a few accent pixels placed from the id, so no two icons match"""
    for _ in range(n):
        x = r.randint(x0, x1)
        y = r.randint(y0, y1)
        c.px(x, y, col)

def gun_icon(it, variant=0):
    id_ = it['id']
    cls = it['tags'][1]
    r = rng_for(id_ + str(variant))
    code = it['name'].split(' ')[0]
    mk = MAKER.get(code[0], MAKER['G'])
    body, acc, wood = mk['body'], mk['acc'], mk['wood']
    # body shade drifts a little with the model so siblings differ
    k = (r.random() - 0.5) * 0.25
    body = lit(body, k) if k > 0 else dark(body, -k)
    L = it['length_mm']
    mag = it['gun'].get('mag', 10)
    heavy = it['weight_g'] > 6000
    c = C()
    cy = 14
    steel = hx('9aa4b0')
    grip = hx('2a2a30')
    FN = {'pistol': _pistol, 'revolver': _revolver, 'smg': _smg, 'rifle': _rifle, 'shotgun': _shotgun, 'sniper': _sniper,
          'mg': _mg, 'heavy_mg': _hmg, 'launcher': _launcher, 'laser': _laser}[cls]
    FN(c, r, dict(body=body, acc=acc, wood=wood, steel=steel, grip=grip, L=L, mag=mag, w=it['weight_g'], code=code, heavy=heavy))
    marks(c, r, 6, 24, cy - 1, cy + 1, acc, 2)
    return c

def _pistol(c, r, P):
    b, a, g = P['body'], P['acc'], P['grip']
    sl = r.randint(12, 15)
    x0 = 9 + r.randint(0, 2)
    c.rect(x0, 10, x0 + sl, 13, b)                      # slide
    c.rect(x0 + sl, 11, x0 + sl + 2 + r.randint(0, 2), 12, P['steel'])   # barrel tip
    c.rect(x0, 14, x0 + sl - 3, 15, dark(b, 0.15))      # frame
    tilt = r.choice([1, 2])
    for i in range(7):                                  # grip
        c.rect(x0 + 1 - (i * tilt) // 4, 14 + i, x0 + 4 - (i * tilt) // 4, 14 + i, g)
    c.rect(x0 + 5, 16, x0 + 9, 16, dark(b, 0.2))        # trigger guard
    c.px(x0 + 9, 15, dark(b, 0.2))
    c.px(x0 + 6, 15, P['steel'])
    c.px(x0 + sl, 9, a) if r.random() < 0.5 else None   # front sight
    c.px(x0 + 1, 9, a)
    c.rect(x0 - 1, 20, x0 + 3, 21, a if r.random() < 0.6 else P['steel'])    # mag plate
    if r.random() < 0.4:
        c.rect(x0 + 3, 10, x0 + sl - 2, 10, a)          # slide stripe

def _revolver(c, r, P):
    b, a, g = P['body'], P['acc'], P['grip']
    bl = r.randint(8, 13)
    x0 = 9
    c.rect(x0, 10, x0 + 6, 14, b)                       # frame
    c.rect(x0 + 2, 9, x0 + 5, 15, P['steel'])           # cylinder
    c.rect(x0 + 6, 10, x0 + 6 + bl, 11, b)              # barrel
    c.rect(x0 + 6, 12, x0 + 6 + bl - 2, 12, dark(b, 0.25))   # ejector rod
    c.px(x0 + 6 + bl, 9, a)
    for i in range(7):
        c.rect(x0 - 1 - i // 3, 14 + i, x0 + 2 - i // 3, 14 + i, P['wood'])
    c.px(x0 + 4, 15, dark(b, 0.2)); c.px(x0 + 5, 16, dark(b, 0.2)); c.px(x0 + 3, 16, dark(b, 0.2))
    c.px(x0 + 3, 12, a)

def _stock(c, r, P, x0, y):
    kind = r.choice(['solid', 'skeleton', 'folded', 'wood'])
    col = P['wood'] if kind == 'wood' else P['grip']
    if kind in ('solid', 'wood'):
        for i in range(8):
            c.rect(x0 - 8 + i // 2 - 1, y + (i // 4), x0, y + 2 + i // 3, col)
    elif kind == 'skeleton':
        c.line(x0, y, x0 - 8, y + 1, col); c.line(x0 - 8, y + 1, x0 - 8, y + 5, col); c.line(x0, y + 2, x0 - 8, y + 5, col)
    else:
        c.rect(x0 - 3, y, x0, y + 2, col)
    return kind

def _rifle(c, r, P):
    b, a, g = P['body'], P['acc'], P['grip']
    bl = P['L'] / 900.0
    x0 = 10
    bullpup = r.random() < 0.2
    xr = x0 + r.randint(9, 11)
    c.rect(x0, 11, xr, 14, b)                           # receiver
    c.rect(xr, 12, xr + 6 + r.randint(0, 2), 13, dark(b, 0.15))     # handguard
    barrel_end = 29 - r.randint(0, 1)
    c.rect(xr + 6, 12, barrel_end, 12, P['steel'])      # barrel
    if r.random() < 0.5:
        c.rect(barrel_end - 2, 11, barrel_end, 13, dark(b, 0.1))    # flash hider
    if not bullpup:
        _stock(c, r, P, x0, 11)
    else:
        c.rect(x0 - 5, 11, x0, 15, b)
    # magazine, curved or straight, longer for big mags
    ml = 4 + P['mag'] // 9
    mx = x0 + 6 + r.randint(0, 2)
    for i in range(ml):
        c.rect(mx + i // 4, 15 + i, mx + 2 + i // 4, 15 + i, dark(b, 0.3) if i < ml - 1 else a)
    c.rect(x0 + 3, 15, x0 + 4, 18, g)                   # pistol grip
    if r.random() < 0.55:                               # optic or iron sights
        c.rect(x0 + 5, 9, x0 + 11, 10, g)
        c.px(x0 + 6, 8, hx('50d0ff'))
    else:
        c.px(x0 + 1, 10, a); c.px(xr + 8, 11, a)
    if r.random() < 0.4:
        c.rect(xr + 2, 15, xr + 5, 16, g)                # foregrip

def _smg(c, r, P):
    b, a, g = P['body'], P['acc'], P['grip']
    x0 = 11
    xr = x0 + r.randint(8, 10)
    c.rect(x0, 11, xr, 14, b)
    sup = r.random() < 0.45
    c.rect(xr, 12, xr + (10 if sup else 5), 13 if not sup else 13, dark(b, 0.1) if sup else P['steel'])
    if sup:
        c.rect(xr + 2, 11, xr + 9, 14, dark(b, 0.15))
    ml = 5 + P['mag'] // 6
    for i in range(ml):
        c.rect(x0 + 6 + i // 8, 15 + i, x0 + 8 + i // 8, 15 + i, dark(b, 0.3) if i < ml - 1 else a)
    c.rect(x0 + 2, 15, x0 + 3, 18, g)
    if r.random() < 0.6:
        c.rect(x0 - 5, 12, x0, 13, g); c.rect(x0 - 5, 12, x0 - 5, 15, g)
    c.rect(x0 + 2, 9, x0 + 5, 10, P['steel'])
    if r.random() < 0.5:
        c.px(xr + 3, 15, g); c.px(xr + 3, 16, g)

def _shotgun(c, r, P):
    b, a, g = P['body'], P['acc'], P['grip']
    x0 = 9
    pump = r.random() < 0.65
    xr = x0 + 9
    c.rect(x0, 11, xr, 14, b)
    c.rect(xr, 11, 29, 12, P['steel'])                  # barrel
    c.rect(xr, 13, 27 - r.randint(0, 3), 13, dark(b, 0.2))  # tube
    if pump:
        c.rect(xr + 4, 13, xr + 9, 15, P['wood'] if r.random() < 0.6 else g)
    else:
        c.rect(xr, 13, xr + 7, 14, P['wood'])
    _stock(c, r, dict(P, grip=P['wood']) if r.random() < 0.5 else P, x0, 11)
    c.rect(x0 + 3, 15, x0 + 4, 18, g)
    if P['mag'] > 6 and r.random() < 0.5:
        c.disc(x0 + 6, 18, 3, dark(b, 0.3)); c.px(x0 + 6, 18, a)
    c.px(29, 10, a)

def _sniper(c, r, P):
    b, a, g = P['body'], P['acc'], P['grip']
    x0 = 6
    xr = x0 + 12
    c.rect(x0, 12, xr, 15, b)
    c.rect(xr, 13, 30, 13, P['steel'])
    c.rect(29, 12, 31, 14, dark(b, 0.1))                # muzzle brake
    if P['mag'] < 5:
        c.px(x0 + 6, 11, P['steel']); c.px(x0 + 7, 10, P['steel'])    # bolt
    _stock(c, r, dict(P, grip=P['wood']) if r.random() < 0.5 else P, x0, 12)
    scope_len = r.randint(8, 11)
    sx = x0 + 6 + r.randint(0, 3)
    c.rect(sx, 8, sx + scope_len, 10, dark(b, 0.4))     # scope tube
    c.rect(sx - 1, 7, sx, 11, P['steel'])
    c.rect(sx + scope_len, 7, sx + scope_len + 1, 11, P['steel'])
    lens = r.choice([hx('50e0ff'), hx('ff6090'), hx('90ff80')])
    c.glow(sx + scope_len + 1, 9, lens)
    c.px(sx + 3, 11, g)
    c.line(xr + 2, 14, xr + 5, 19, g); c.line(xr + 3, 14, xr + 8, 19, g)   # bipod
    c.rect(x0 + 5, 16, x0 + 6, 19, g)
    c.rect(x0 + 5, 15, x0 + 5 + (P['mag'] // 3), 16, dark(b, 0.3))

def _mg(c, r, P):
    b, a, g = P['body'], P['acc'], P['grip']
    x0 = 8
    xr = x0 + 11
    c.rect(x0, 10, xr, 14, b)
    c.rect(xr, 11, xr + 5, 13, dark(b, 0.1))
    c.rect(xr + 5, 12, 30, 12, P['steel'])
    for i in range(xr + 1, xr + 5, 2):
        c.px(i, 11, P['steel'])                          # shroud holes
    c.rect(x0 + 4, 15, x0 + 10, 20, dark(b, 0.35))       # belt box
    c.rect(x0 + 4, 20, x0 + 10, 20, a)
    c.line(x0 + 10, 15, x0 + 12, 16, P['steel'])
    c.rect(x0 + 3, 8, x0 + 8, 9, g)                      # carry handle
    _stock(c, r, dict(P, grip=P['wood']) if r.random() < 0.5 else P, x0, 11)
    c.line(xr + 3, 14, xr + 6, 19, g); c.line(xr + 4, 14, xr + 9, 19, g)

def _hmg(c, r, P):
    b, a, g = P['body'], P['acc'], P['grip']
    x0 = 6
    c.rect(x0, 8, x0 + 14, 15, b)
    c.rect(x0 + 14, 10, 27, 13, dark(b, 0.1))
    c.rect(27, 11, 31, 12, P['steel'])
    c.rect(x0 + 3, 16, x0 + 12, 22, dark(b, 0.35))       # ammo can
    c.rect(x0 + 3, 22, x0 + 12, 22, a)
    c.rect(x0 - 3, 10, x0, 14, g)                        # spade grips
    c.rect(x0 + 5, 6, x0 + 11, 7, g)
    c.line(x0 + 15, 16, x0 + 20, 24, g); c.line(x0 + 16, 16, x0 + 24, 24, g); c.px(x0 + 20, 16, P['steel'])
    for i in range(x0 + 15, 26, 3):
        c.px(i, 10, P['steel'])

def _launcher(c, r, P):
    b, a, g = P['body'], P['acc'], P['grip']
    x0 = 6
    c.rect(x0, 10, 27, 15, b)                            # tube
    c.rect(26, 9, 30, 16, dark(b, 0.15))                 # flared muzzle
    c.rect(x0 + 3, 7, x0 + 8, 9, g); c.px(x0 + 5, 6, a)
    c.rect(x0 + 8, 16, x0 + 10, 20, g)                   # grips
    c.rect(x0 + 15, 16, x0 + 16, 19, g)
    if r.random() < 0.5:
        c.disc(x0 + 12, 12, 3, dark(b, 0.3)); c.px(x0 + 12, 12, a)   # drum
    c.rect(x0 - 3, 11, x0, 14, g)
    c.rect(x0 + 14, 11, x0 + 18, 14, a)

def _laser(c, r, P):
    b, a, g = P['body'], P['acc'], P['grip']
    x0 = 8
    c.rect(x0, 10, x0 + 13, 14, b)
    c.rect(x0 + 13, 11, x0 + 20, 13, lit(b, 0.1))
    glo = r.choice([hx('50f0ff'), hx('ff58c8'), hx('a0ff60')])
    c.glow(x0 + 21, 12, glo); c.glow(x0 + 22, 12, lit(glo, 0.5)); c.glow(x0 + 20, 11, glo); c.glow(x0 + 20, 13, glo)
    for i in range(3):
        c.glow(x0 + 3 + i * 3, 12, glo)                  # capacitor cells
    c.rect(x0 + 2, 15, x0 + 3, 18, g)
    c.rect(x0 + 8, 15, x0 + 12, 16, dark(b, 0.3))
    c.rect(x0 - 3, 11, x0, 13, g)
    c.px(x0 + 5, 9, a); c.px(x0 + 10, 9, a)
    if r.random() < 0.5:
        c.rect(x0 + 4, 8, x0 + 9, 9, P['steel'])

# ---------------------------------------------------------------- melee
STEEL = hx('b8c4d0')
def melee_icon(base_id, it, grade):
    """base_id like 'kama'; grade '' / '_f' / '_m'.  Returns a C canvas."""
    r = rng_for(it['id'])
    c = C()
    L = it['length_mm']
    n = max(8, min(28, int(L / 1800 * 28 + 4)))
    steel = {'': STEEL, '_f': hx('d4dce6'), '_m': hx('e8f4ff')}[grade]
    wood = {'': hx('7a5a3a'), '_f': hx('5a3a28'), '_m': hx('2e2428')}[grade]
    brass = {'': hx('8a8070'), '_f': hx('c8a050'), '_m': hx('ffd860')}[grade]
    wrap = {'': hx('4a5a6a'), '_f': hx('803030'), '_m': hx('30c8e8')}[grade]
    cy = 14
    x0 = 2
    f = DRAW[base_id]
    f(c, r, dict(n=n, steel=steel, wood=wood, brass=brass, wrap=wrap, grade=grade, x0=x0, cy=cy))
    if grade == '_m':
        # masterwork: a bright edge glint along the top and a gem in the fittings
        c.glow(x0 + 2, cy, hx('30e0ff'))
    if grade != '':
        marks(c, r, x0, x0 + n - 1, cy - 1, cy + 1, brass, 2)
    return c

def _straight(c, r, P, curve=0, guard=True, width=2, tip=True):
    n, x0, cy = P['n'], P['x0'], P['cy']
    hl = max(4, n // 4)
    for i in range(hl):
        c.rect(x0 + i, cy, x0 + i, cy + 1, P['wrap'] if i % 2 == 0 else dark(P['wrap'], 0.25))
    c.px(x0 - 1, cy, P['brass']); c.px(x0 - 1, cy + 1, P['brass'])
    if guard:
        c.rect(x0 + hl, cy - 2, x0 + hl, cy + 3, P['brass'])
    bl = n - hl - 1
    for i in range(bl):
        yy = cy - (i * curve) // max(1, bl)
        c.rect(x0 + hl + 1 + i, yy, x0 + hl + 1 + i, yy + width - 1, P['steel'])
    if tip:
        c.px(x0 + hl + bl + 1, cy - curve - (1 if curve else 0), P['steel'])
    if P['grade'] != '':
        for i in range(0, bl, 2):
            c.px(x0 + hl + 1 + i, cy - (i * curve) // max(1, bl) + 1, dark(P['steel'], 0.25))   # temper line

def d_katana(c, r, P): _straight(c, r, P, curve=2 + r.randint(0, 1))
def d_wakizashi(c, r, P): _straight(c, r, P, curve=1 + r.randint(0, 1))
def d_nodachi(c, r, P): _straight(c, r, P, curve=3)
def d_tanto(c, r, P): _straight(c, r, P, curve=0, guard=True, width=2)
def d_shashka(c, r, P): _straight(c, r, P, curve=3, guard=False, width=2)
def d_kinzhal(c, r, P):
    n, x0, cy = P['n'], P['x0'], P['cy']
    c.rect(x0, cy, x0 + 3, cy + 1, P['wood']); c.rect(x0 + 4, cy - 1, x0 + 4, cy + 2, P['brass'])
    for i in range(n - 6):
        w = 3 if i < n - 9 else 1
        c.rect(x0 + 5 + i, cy - (1 if w == 3 else 0), x0 + 5 + i, cy + (1 if w == 3 else 0) + 1, P['steel'])
    c.line(x0 + 5, cy + 1, x0 + n - 2, cy + 1, dark(P['steel'], 0.3))
def d_finka(c, r, P):
    n, x0, cy = P['n'], P['x0'], P['cy']
    c.rect(x0, cy, x0 + 3, cy + 2, P['wood'])
    c.rect(x0 + 4, cy - 1, x0 + 4, cy + 3, P['brass'])
    for i in range(n - 6):
        c.rect(x0 + 5 + i, cy, x0 + 5 + i, cy + (2 if i < (n - 6) // 2 else 1), P['steel'])
    c.px(x0 + n - 1, cy + 1, P['steel'])
def d_kunai(c, r, P):
    n, x0, cy = P['n'], P['x0'], P['cy']
    c.disc(x0 + 1, cy + 1, 1.5, P['steel']); c.px(x0 + 1, cy + 1, (0, 0, 0, 0)); c.p.pop((x0 + 1, cy + 1), None)
    c.rect(x0 + 3, cy + 1, x0 + 5, cy + 1, P['wrap'])
    for i in range(n - 7):
        w = 2 if i < (n - 7) - 3 else 1
        c.rect(x0 + 6 + i, cy + 1 - (1 if w == 2 else 0), x0 + 6 + i, cy + 1 + (1 if w == 2 else 0), P['steel'])
def d_kama(c, r, P):
    n, x0, cy = P['n'], P['x0'], P['cy']
    for i in range(n - 6):
        c.rect(x0 + i, cy + 2, x0 + i, cy + 3, P['wood'])
    ex = x0 + n - 6
    c.line(ex, cy + 2, ex + 4, cy - 2, P['steel'], 2)
    c.line(ex + 4, cy - 2, ex + 1, cy - 5, P['steel'])
    c.px(ex, cy + 1, P['brass'])
def d_kusarigama(c, r, P):
    n, x0, cy = P['n'], P['x0'], P['cy']
    for i in range(n // 2 - 2):
        c.rect(x0 + i, cy + 3, x0 + i, cy + 4, P['wood'])
    ex = x0 + n // 2 - 2
    c.line(ex, cy + 3, ex + 4, cy - 1, P['steel'], 2); c.line(ex + 4, cy - 1, ex + 1, cy - 4, P['steel'])
    for i in range(0, n // 2 - 1, 2):
        c.px(x0 + 2 + i, cy + 6 - (i % 4 == 0), P['brass'])
    c.disc(x0 + n - 3, cy + 6, 2, dark(P['steel'], 0.35)); c.px(x0 + n - 3, cy + 5, P['brass'])
def d_naginata(c, r, P):
    n, x0, cy = P['n'], P['x0'], P['cy']
    for i in range(n - 8):
        c.px(x0 + i, cy + 1, P['wood']); c.px(x0 + i, cy + 2, dark(P['wood'], 0.2))
    c.rect(x0 + n - 8, cy, x0 + n - 8, cy + 3, P['brass'])
    for i in range(7):
        yy = cy - (i * 2) // 6
        c.rect(x0 + n - 7 + i, yy, x0 + n - 7 + i, yy + 3 - i // 3, P['steel'])
def d_yari(c, r, P):
    n, x0, cy = P['n'], P['x0'], P['cy']
    for i in range(n - 7):
        c.px(x0 + i, cy + 1, P['wood']); c.px(x0 + i, cy + 2, dark(P['wood'], 0.2))
    c.rect(x0 + n - 7, cy, x0 + n - 7, cy + 3, P['brass'])
    for i in range(6):
        w = 3 - abs(i - 2) // 2
        c.rect(x0 + n - 6 + i, cy + 1 - w // 2, x0 + n - 6 + i, cy + 1 + w // 2 + 1, P['steel'])
def d_bo(c, r, P):
    n, x0, cy = P['n'], P['x0'], P['cy']
    for i in range(n):
        c.px(x0 + i, cy + 1, P['wood']); c.px(x0 + i, cy + 2, dark(P['wood'], 0.2))
    for k in (0, n - 1):
        c.rect(x0 + k, cy + 1, x0 + k, cy + 2, P['brass'])
    if P['grade'] != '':
        for k in (n // 3, 2 * n // 3):
            c.rect(x0 + k, cy + 1, x0 + k, cy + 2, P['wrap'])
def d_jo(c, r, P):
    n, x0, cy = P['n'], P['x0'], P['cy']
    for i in range(n):
        c.px(x0 + i, cy + 1, lit(P['wood'], 0.15))
    for k in (0, n - 1):
        c.px(x0 + k, cy + 1, P['brass'])
    c.rect(x0, cy + 2, x0 + n - 1, cy + 2, dark(P['wood'], 0.2))
def d_nunchaku(c, r, P):
    n, x0, cy = P['n'], P['x0'], P['cy']
    h = max(5, n // 3)
    c.rect(x0, cy + 1, x0 + h, cy + 2, P['wood'])
    c.rect(x0 + h + 3, cy - 2, x0 + h + 3 + h, cy - 1, P['wood'])
    c.line(x0 + h + 1, cy + 1, x0 + h + 3, cy - 1, P['steel'])
    c.px(x0 + h, cy + 1, P['brass']); c.px(x0 + h + 3, cy - 1, P['brass'])
def d_sai(c, r, P):
    n, x0, cy = P['n'], P['x0'], P['cy']
    c.rect(x0, cy + 1, x0 + 3, cy + 2, P['wrap'])
    c.rect(x0 + 4, cy - 2, x0 + 4, cy + 5, P['brass'])
    c.rect(x0 + 5, cy + 1, x0 + n - 2, cy + 2, P['steel'])
    c.rect(x0 + 4, cy - 3, x0 + 8, cy - 3, P['steel']); c.rect(x0 + 4, cy + 6, x0 + 8, cy + 6, P['steel'])
    c.px(x0 + 8, cy - 2, P['steel']); c.px(x0 + 8, cy + 5, P['steel'])
def d_jitte(c, r, P):
    n, x0, cy = P['n'], P['x0'], P['cy']
    c.rect(x0, cy + 1, x0 + 3, cy + 2, P['wrap'])
    c.rect(x0 + 4, cy - 1, x0 + 4, cy + 4, P['brass'])
    c.rect(x0 + 5, cy + 1, x0 + n - 1, cy + 2, P['steel'])
    c.rect(x0 + 6, cy - 2, x0 + 9, cy - 1, P['steel']); c.px(x0 + 6, cy, P['steel'])
def d_tessen(c, r, P):
    n, x0, cy = P['n'], P['x0'], P['cy']
    for i in range(min(n - 2, 10)):
        h = 1 + i // 2
        c.rect(x0 + 2 + i, cy + 2 - h, x0 + 2 + i, cy + 2 + h, P['steel'] if i % 2 == 0 else dark(P['steel'], 0.25))
    c.rect(x0, cy + 2, x0 + 2, cy + 2, P['brass'])
def d_ono(c, r, P):
    n, x0, cy = P['n'], P['x0'], P['cy']
    for i in range(n - 2):
        c.px(x0 + i, cy + 4, P['wood']); c.px(x0 + i, cy + 5, dark(P['wood'], 0.2))
    ex = x0 + n - 7
    c.rect(ex, cy - 1, ex + 5, cy + 9, dark(P['steel'], 0.2)) if False else None
    for j in range(10):
        w = 2 + (j if j < 5 else 9 - j) // 2
        c.rect(ex + (4 - w), cy + j - 1, ex + 4, cy + j - 1, P['steel'])
    c.rect(ex + 4, cy + 3, ex + 4, cy + 6, P['brass'])
def d_topor(c, r, P):
    n, x0, cy = P['n'], P['x0'], P['cy']
    for i in range(n - 2):
        c.px(x0 + i, cy + 4, P['wood']); c.px(x0 + i, cy + 5, dark(P['wood'], 0.2))
    ex = x0 + n - 6
    for j in range(8):
        w = 1 + (j if j < 4 else 7 - j) // 1
        c.rect(ex + 4 - min(w, 4), cy + j, ex + 4, cy + j, P['steel'])
    c.rect(ex + 5, cy + 3, ex + 5, cy + 6, dark(P['steel'], 0.3))
def d_chekan(c, r, P):
    n, x0, cy = P['n'], P['x0'], P['cy']
    for i in range(n - 2):
        c.px(x0 + i, cy + 3, P['wood']); c.px(x0 + i, cy + 4, dark(P['wood'], 0.2))
    ex = x0 + n - 6
    c.rect(ex, cy + 1, ex + 3, cy + 6, dark(P['steel'], 0.1))        # hammer face
    c.rect(ex + 3, cy + 2, ex + 6, cy + 3, P['steel']); c.px(ex + 7, cy + 3, P['steel'])   # pick
    c.rect(ex - 1, cy + 3, ex, cy + 4, P['brass'])
def d_tonfa(c, r, P):
    n, x0, cy = P['n'], P['x0'], P['cy']
    c.rect(x0, cy + 2, x0 + n - 1, cy + 3, P['wood'])
    c.rect(x0 + 4, cy - 2, x0 + 5, cy + 1, P['wood'])
    c.px(x0 + n - 1, cy + 2, P['brass']); c.px(x0, cy + 2, P['brass'])
def d_lopata(c, r, P):
    n, x0, cy = P['n'], P['x0'], P['cy']
    for i in range(n - 7):
        c.px(x0 + i, cy + 3, P['wood']); c.px(x0 + i, cy + 4, dark(P['wood'], 0.2))
    c.rect(x0 - 1, cy + 1, x0 - 1, cy + 6, P['wood'])      # T handle
    ex = x0 + n - 8
    c.rect(ex, cy, ex + 7, cy + 7, P['steel'])
    c.rect(ex + 7, cy + 1, ex + 7, cy + 6, lit(P['steel'], 0.3))
    c.rect(ex + 2, cy + 3, ex + 5, cy + 4, dark(P['steel'], 0.2))
def d_kistien(c, r, P):
    n, x0, cy = P['n'], P['x0'], P['cy']
    h = max(5, n // 2)
    c.rect(x0, cy + 3, x0 + h, cy + 4, P['wood'])
    for i in range(0, 5):
        c.px(x0 + h + 1 + i, cy + 3 - (i % 2) - i // 3, P['steel'])
    bx, by = x0 + h + 7, cy + 1
    c.disc(bx, by, 2.5, dark(P['steel'], 0.3))
    for dx, dy in ((0, -3), (0, 3), (3, 0), (-3, 0)):
        c.px(bx + dx, by + dy, P['steel'])
    c.px(bx, by, P['brass'])
def d_kastet(c, r, P):
    x0, cy = P['x0'], P['cy']
    for i in range(4):
        c.disc(x0 + 4 + i * 4, cy + 3, 2, P['steel'])
        c.p.pop((x0 + 4 + i * 4, cy + 3), None)
    c.rect(x0 + 2, cy + 6, x0 + 17, cy + 6, P['steel'])
    c.rect(x0 + 2, cy, x0 + 17, cy, P['steel'])
    c.rect(x0 + 2, cy + 7, x0 + 3, cy + 8, P['brass'])
    for i in range(4):
        c.px(x0 + 4 + i * 4, cy - 1, P['brass'])

DRAW = {k[2:]: v for k, v in globals().items() if k.startswith('d_')}
