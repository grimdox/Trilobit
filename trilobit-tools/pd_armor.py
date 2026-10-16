"""Armor and container icons (32x32, front view) and the paper-doll layers (32x36, drawn over the base person sprite).
Base sprite anatomy (x, rows): head 10-21 x 1-12 (eyes row 7), torso 10-21 x 13-24, arms 7-9 and 22-24 x 13-22, legs 11-15 / 17-21 x 26-31."""
from pdlib import C, hx, lit, dark
from pd_weapons import rng_for

def ell(c, cx, cy, rx, ry, col):
    for y in range(int(cy - ry - 1), int(cy + ry + 2)):
        for x in range(int(cx - rx - 1), int(cx + rx + 2)):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                c.px(x, y, col)

# ------------------------------------------------------------------ icons
def icon_helmet(c, col=hx('566a48'), strap=hx('2a2a2e')):
    ell(c, 16, 15, 9, 8, col)
    c.rect(7, 16, 25, 19, col)
    c.rect(6, 19, 26, 20, dark(col, 0.25))
    c.rect(11, 20, 12, 25, strap); c.rect(20, 20, 21, 25, strap); c.rect(11, 25, 21, 25, strap)
    c.rect(13, 9, 19, 10, lit(col, 0.2))

def icon_trl_helmet(c, r):
    icon_helmet(c)
    c.rect(14, 12, 18, 13, hx('2e3a28'))          # net cover tab
    for x in (11, 15, 19):
        c.px(x, 17, hx('8a9a70'))

def icon_trl_visor(c, r):
    col = hx('2c3440')
    ell(c, 16, 13, 9, 7, col)
    c.rect(7, 14, 25, 16, col)
    c.rect(8, 17, 24, 25, hx('7ad8f0'))           # clear riot shield
    c.rect(8, 17, 24, 17, hx('c8f4ff'))
    c.rect(10, 19, 14, 21, hx('b0ecff'))
    c.rect(7, 17, 7, 25, col); c.rect(25, 17, 25, 25, col)
    c.rect(12, 8, 20, 8, hx('50e8ff'))

def icon_trl_helm_tac(c, r):
    col = hx('2c3036')
    ell(c, 16, 15, 9, 8, col)
    c.rect(7, 17, 25, 20, col)
    c.rect(14, 8, 18, 12, hx('3a3e46'))           # NVG mount
    c.rect(15, 9, 17, 11, hx('202226'))
    c.glow(16, 10, hx('60ff90'))
    c.rect(6, 15, 7, 19, hx('4a4e58')); c.rect(25, 15, 26, 19, hx('4a4e58'))   # rails
    c.rect(11, 21, 12, 26, hx('202226')); c.rect(20, 21, 21, 26, hx('202226'))

def icon_trl_balaclava(c, r):
    col = hx('26262c')
    ell(c, 16, 15, 8, 10, col)
    c.rect(9, 13, 23, 16, col)
    c.rect(10, 13, 22, 14, hx('1a1a1e'))
    c.rect(11, 14, 21, 15, hx('d8b898'))          # eye slot
    c.rect(11, 14, 13, 14, hx('101012')); c.rect(19, 14, 21, 14, hx('101012'))
    c.rect(8, 23, 24, 26, hx('34343c'))

def icon_trl_vest(c, r):
    col = hx('3e4652')
    c.rect(8, 8, 24, 26, col)
    c.rect(8, 8, 12, 12, dark(col, 0.2)); c.rect(20, 8, 24, 12, dark(col, 0.2))   # shoulders
    c.rect(13, 8, 19, 10, hx('202428'))           # neck hole
    c.rect(11, 13, 21, 22, hx('59636f'))          # plate
    c.rect(11, 13, 21, 13, lit(hx('59636f'), 0.3))
    c.line(16, 14, 16, 22, hx('2c323a'))
    c.rect(8, 23, 24, 25, hx('2c323a'))

def icon_trl_vest_heavy(c, r):
    col = hx('4a5040')
    c.rect(7, 7, 25, 27, col)
    c.rect(7, 7, 12, 12, dark(col, 0.25)); c.rect(20, 7, 25, 12, dark(col, 0.25))
    c.rect(13, 7, 19, 9, hx('202428'))
    c.rect(10, 12, 22, 21, hx('77806a'))          # big front plate
    c.rect(10, 12, 22, 12, lit(hx('77806a'), 0.3))
    c.rect(10, 21, 22, 21, dark(hx('77806a'), 0.3))
    for x in (9, 13, 17, 21):
        c.rect(x, 23, x + 2, 26, hx('2e3328')); c.px(x + 1, 23, hx('c8c070'))     # pouches
    c.rect(7, 22, 25, 22, hx('2e3328'))

def icon_trl_vest_corp(c, r):
    col = hx('1c1e26')
    c.rect(9, 7, 23, 26, col)
    c.rect(9, 7, 12, 11, dark(col, 0.1)); c.rect(20, 7, 23, 11, dark(col, 0.1))
    c.rect(13, 7, 19, 9, hx('0e0e12'))
    c.line(16, 10, 16, 26, hx('30e8ff'))
    c.line(11, 13, 14, 20, hx('30e8ff')); c.line(21, 13, 18, 20, hx('30e8ff'))
    c.rect(9, 25, 23, 26, hx('30e8ff'))

def icon_trl_jacket(c, r):
    col = hx('5a3e2c')
    c.rect(6, 7, 26, 26, col)
    c.rect(2, 8, 6, 22, dark(col, 0.1)); c.rect(26, 8, 30, 22, dark(col, 0.1))     # sleeves
    c.rect(13, 7, 19, 9, hx('1c1c20'))
    c.line(16, 9, 16, 26, hx('b0b0b8'))                                          # zip
    c.rect(6, 24, 26, 26, dark(col, 0.25))
    c.rect(8, 13, 12, 14, hx('d0a040')); c.rect(20, 13, 24, 14, hx('d0a040'))

def icon_trl_coat(c, r):
    col = hx('34343e')
    c.rect(7, 5, 25, 28, col)
    c.rect(2, 6, 7, 24, dark(col, 0.12)); c.rect(25, 6, 30, 24, dark(col, 0.12))
    c.rect(13, 5, 19, 8, hx('15151a'))
    c.line(16, 8, 16, 28, hx('15151a'))
    c.rect(7, 16, 25, 17, hx('15151a')); c.px(16, 16, hx('c8b060'))               # belt
    c.rect(9, 6, 13, 12, lit(col, 0.12)); c.rect(19, 6, 23, 12, lit(col, 0.12))   # lapels
    c.rect(7, 26, 25, 28, dark(col, 0.2))

def _pair(c, f):
    f(c, 4)
    f(c, 17)

def icon_trl_bracers(c, r):
    col = hx('566470')
    def one(c, x):
        c.rect(x, 5, x + 8, 25, col)
        c.rect(x, 5, x + 8, 7, lit(col, 0.25))
        for y in (10, 15, 20):
            c.rect(x + 1, y, x + 7, y + 1, dark(col, 0.25))
        c.rect(x + 3, 8, x + 5, 24, hx('6c7a86'))
    _pair(c, one)

def icon_trl_bracers_heavy(c, r):
    col = hx('3e4234')
    def one(c, x):
        c.rect(x, 4, x + 8, 26, col)
        c.rect(x - 1, 4, x + 9, 8, hx('5a6048'))             # elbow cop
        c.rect(x, 9, x + 8, 22, hx('4c5240'))
        for y in (11, 15, 19):
            c.rect(x, y, x + 8, y, hx('7a8266'))
        c.rect(x + 1, 24, x + 7, 26, hx('2a2e22'))
        c.px(x + 4, 6, hx('d8d078'))
    _pair(c, one)

def icon_trl_greaves(c, r):
    col = hx('4a5460')
    def one(c, x):
        c.rect(x + 1, 3, x + 7, 27, col)
        c.rect(x, 3, x + 8, 8, hx('62707c'))                  # knee
        c.rect(x + 2, 10, x + 6, 25, dark(col, 0.12))
        c.line(x + 4, 10, x + 4, 25, hx('6c7a86'))
        c.rect(x, 14, x + 8, 15, hx('26262c')); c.rect(x, 20, x + 8, 21, hx('26262c'))
    _pair(c, one)

def icon_trl_greaves_heavy(c, r):
    col = hx('3e4234')
    def one(c, x):
        c.rect(x + 1, 3, x + 7, 28, col)
        c.rect(x - 1, 2, x + 9, 9, hx('5a6048'))
        c.rect(x, 11, x + 8, 22, hx('4c5240'))
        c.rect(x, 24, x + 8, 28, hx('2a2e22'))
        for y in (13, 17, 21):
            c.rect(x, y, x + 8, y, hx('7a8266'))
        c.glow(x + 4, 5, hx('ffb840'))
    _pair(c, one)

def icon_trl_kneepads(c, r):
    col = hx('2a2a30')
    def one(c, x):
        c.rect(x + 1, 10, x + 7, 20, col)
        c.rect(x + 2, 12, x + 6, 18, hx('3c3c46'))
        c.rect(x, 14, x + 8, 15, hx('15151a'))
        c.px(x + 4, 16, hx('ff6090'))
    _pair(c, one)

def icon_trl_backpack(c, r):
    col = hx('3a4a5c')
    c.rect(8, 5, 24, 27, col)
    c.rect(7, 8, 8, 24, dark(col, 0.2)); c.rect(24, 8, 25, 24, dark(col, 0.2))
    c.rect(10, 4, 22, 6, lit(col, 0.2))
    c.rect(10, 14, 22, 22, dark(col, 0.12)); c.line(10, 14, 22, 14, hx('c8c8d0'))
    c.rect(14, 17, 18, 19, hx('2a3440')); c.px(16, 18, hx('30e8ff'))
    c.rect(13, 3, 19, 4, hx('202830'))

def icon_trl_holster(c, r):
    col = hx('4a3a2c')
    c.rect(10, 6, 20, 26, col)
    c.rect(9, 8, 21, 9, hx('2a2018')); c.rect(9, 22, 21, 23, hx('2a2018'))
    c.rect(11, 12, 19, 21, dark(col, 0.25))
    c.rect(12, 6, 18, 7, hx('8a8a92'))
    c.rect(4, 4, 8, 5, hx('2a2018')); c.rect(4, 5, 5, 27, hx('2a2018'))          # belt loop

ARMOR_ICONS = {k[5:]: v for k, v in globals().items() if k.startswith('icon_trl_')}

# ------------------------------------------------------------------ doll layers (32 x 36)
def L():
    return C(32, 36)

def l_helmet_ball():
    c = L(); col = hx('566a48')
    ell(c, 15.5, 4.5, 6.5, 4.2, col)
    c.rect(9, 5, 22, 6, dark(col, 0.2))
    c.rect(10, 7, 10, 11, hx('2a2a2e')); c.rect(21, 7, 21, 11, hx('2a2a2e'))   # chin straps
    c.rect(13, 2, 18, 2, lit(col, 0.25))
    return c

def l_visor():
    c = L(); col = hx('2c3440')
    ell(c, 15.5, 4, 6.5, 3.6, col)
    c.rect(9, 5, 22, 5, col)
    c.rect(10, 6, 21, 11, (120, 220, 255, 110))
    c.top.update({(x, 6): (200, 244, 255, 190) for x in range(10, 22)})
    c.rect(9, 6, 9, 11, col); c.rect(22, 6, 22, 11, col)
    return c

def l_helm_tac():
    c = L(); col = hx('2c3036')
    ell(c, 15.5, 4.5, 6.5, 4.2, col)
    c.rect(9, 5, 22, 6, hx('202226'))
    c.rect(14, 2, 17, 5, hx('3a3e46'))
    c.glow(15, 4, hx('60ff90')); c.glow(16, 4, hx('60ff90'))
    c.rect(8, 4, 9, 7, hx('4a4e58')); c.rect(22, 4, 23, 7, hx('4a4e58'))
    return c

def l_balaclava():
    c = L(); col = hx('26262c')
    ell(c, 15.5, 5.5, 6.7, 5.5, col)
    c.rect(10, 9, 21, 12, col)
    c.rect(12, 7, 19, 8, hx('d0a888'))
    c.rect(12, 7, 13, 7, hx('101012')); c.rect(18, 7, 19, 7, hx('101012'))
    return c

def l_vest():
    c = L(); col = hx('3e4652')
    c.rect(10, 13, 21, 24, col)
    c.rect(10, 13, 12, 14, dark(col, 0.2)); c.rect(19, 13, 21, 14, dark(col, 0.2))
    c.rect(12, 15, 19, 22, hx('59636f'))
    c.line(15, 15, 15, 22, hx('2c323a')); c.line(16, 15, 16, 22, hx('2c323a'))
    c.rect(10, 23, 21, 24, hx('2c323a'))
    return c

def l_vest_heavy():
    c = L(); col = hx('4a5040')
    c.rect(9, 13, 22, 25, col)
    c.rect(9, 13, 12, 14, dark(col, 0.25)); c.rect(19, 13, 22, 14, dark(col, 0.25))
    c.rect(11, 15, 20, 22, hx('77806a'))
    c.rect(11, 15, 20, 15, lit(hx('77806a'), 0.3))
    for x in (9, 13, 17, 20):
        c.rect(x, 23, x + 1, 25, hx('2e3328')); c.px(x, 23, hx('c8c070'))
    c.rect(9, 22, 22, 22, hx('2e3328'))
    return c

def l_vest_corp():
    c = L(); col = hx('1c1e26')
    c.rect(10, 13, 21, 24, col)
    c.line(15, 14, 15, 24, hx('30e8ff')); c.line(16, 14, 16, 24, hx('30e8ff'))
    c.line(11, 14, 13, 20, hx('30e8ff')); c.line(20, 14, 18, 20, hx('30e8ff'))
    c.rect(10, 24, 21, 24, hx('30e8ff'))
    return c

def l_jacket():
    c = L(); col = hx('5a3e2c')
    c.rect(10, 13, 21, 24, col); c.rect(7, 13, 9, 22, dark(col, 0.1)); c.rect(22, 13, 24, 22, dark(col, 0.1))
    c.line(15, 14, 15, 24, hx('b0b0b8'))
    c.rect(10, 23, 21, 24, dark(col, 0.25))
    c.rect(11, 14, 13, 15, hx('d0a040')); c.rect(18, 14, 20, 15, hx('d0a040'))
    return c

def l_coat():
    c = L(); col = hx('34343e')
    c.rect(10, 13, 21, 27, col); c.rect(7, 13, 9, 22, dark(col, 0.1)); c.rect(22, 13, 24, 22, dark(col, 0.1))
    c.rect(9, 24, 22, 27, dark(col, 0.2))
    c.line(15, 14, 15, 27, hx('15151a')); c.line(16, 14, 16, 27, hx('15151a'))
    c.rect(10, 19, 21, 19, hx('15151a')); c.px(15, 19, hx('c8b060')); c.px(16, 19, hx('c8b060'))
    c.rect(10, 13, 13, 16, lit(col, 0.15)); c.rect(18, 13, 21, 16, lit(col, 0.15))
    return c

def l_bracers():
    c = L(); col = hx('566470')
    for x in (7, 22):
        c.rect(x, 15, x + 2, 21, col); c.rect(x, 15, x + 2, 15, lit(col, 0.25))
        c.rect(x, 17, x + 2, 17, dark(col, 0.3)); c.rect(x, 19, x + 2, 19, dark(col, 0.3))
    return c

def l_bracers_heavy():
    c = L(); col = hx('3e4234')
    for x in (7, 22):
        c.rect(x - 1, 14, x + 3, 16, hx('5a6048'))
        c.rect(x, 17, x + 2, 22, hx('4c5240')); c.rect(x, 19, x + 2, 19, hx('7a8266'))
        c.rect(x - 1, 22, x + 3, 22, hx('2a2e22'))
    return c

def l_greaves():
    c = L(); col = hx('4a5460')
    for x in (11, 17):
        c.rect(x, 26, x + 3, 27, hx('62707c'))      # knees
        c.rect(x, 28, x + 4, 30, col); c.rect(x + 2, 28, x + 2, 30, hx('6c7a86'))
        c.rect(x, 29, x + 4, 29, hx('26262c'))
    return c

def l_greaves_heavy():
    c = L(); col = hx('3e4234')
    for x in (11, 17):
        c.rect(x - 1, 26, x + 4, 27, hx('5a6048'))
        c.rect(x, 28, x + 4, 30, hx('4c5240')); c.rect(x, 28, x + 4, 28, hx('7a8266'))
        c.glow(x + 2, 27, hx('ffb840'))
    return c

def l_kneepads():
    c = L()
    for x in (11, 17):
        c.rect(x, 26, x + 3, 27, hx('2a2a30')); c.px(x + 1, 26, hx('ff6090'))
    return c

def l_backpack():
    c = L(); col = hx('3a4a5c')
    c.rect(6, 14, 7, 21, dark(col, 0.2)); c.rect(24, 14, 25, 21, dark(col, 0.2))
    c.line(11, 13, 11, 20, hx('202830')); c.line(20, 13, 20, 20, hx('202830'))
    c.rect(11, 13, 12, 14, col); c.rect(19, 13, 20, 14, col)
    return c

def l_holster():
    c = L(); col = hx('4a3a2c')
    c.rect(17, 25, 21, 26, hx('2a2018'))
    c.rect(21, 22, 23, 27, col); c.rect(22, 21, 22, 21, hx('8a8a92'))
    return c

# outfits (cover torso, arms and legs)
def _body_outfit(top, trim, legs, belt=None, hem=25, sleeves=None):
    c = L()
    c.rect(10, 13, 21, hem, top)
    sl = sleeves or top
    c.rect(7, 13, 9, 22, sl); c.rect(22, 13, 24, 22, sl)
    c.rect(7, 21, 9, 22, trim); c.rect(22, 21, 24, 22, trim)
    c.line(15, 14, 15, hem, trim); c.line(16, 14, 16, hem, trim)
    if belt:
        c.rect(10, 19, 21, 19, belt); c.px(15, 19, hx('d8c060')); c.px(16, 19, hx('d8c060'))
    c.rect(11, 26, 14, 28, legs); c.rect(17, 26, 20, 28, legs)
    c.rect(11, 29, 14, 29, dark(legs, 0.2)); c.rect(17, 29, 20, 29, dark(legs, 0.2))
    return c

JACKETS = [('c8483c', 'f0c070', '34384a'), ('3c78c8', 'f0f0f0', '2c2c34'), ('48a060', 'e0e080', '3a3a40'),
           ('9a58c8', 'f0a0e0', '2a2a36'), ('d8a030', '503820', '3c3430'), ('7a8290', 'd0e8f0', '30343c')]
def jacket(i):
    t, tr, lg = JACKETS[i]
    return _body_outfit(hx(t), hx(tr), hx(lg), belt=dark(hx(t), 0.4))

def o_labcoat():
    c = _body_outfit(hx('f0f4f8'), hx('b8c8d8'), hx('4a5a6a'), hem=27)
    c.rect(9, 24, 22, 27, hx('f0f4f8'))
    c.rect(11, 15, 13, 17, hx('30c8e8')); c.px(12, 15, hx('f0f4f8')); c.px(12, 17, hx('f0f4f8')); c.px(11, 16, hx('f0f4f8')); c.px(13, 16, hx('f0f4f8'))
    c.rect(12, 9, 19, 12, (240, 248, 250, 255))                       # surgical mask
    c.rect(12, 9, 19, 9, hx('b8e0f0'))
    return c

def o_chef():
    c = _body_outfit(hx('f4f4f4'), hx('b0b0b8'), hx('38383e'), hem=24)
    c.rect(11, 18, 20, 25, hx('ece8e0'))                              # apron
    c.rect(11, 18, 20, 18, hx('a0a0a8'))
    c.rect(10, 0, 21, 4, hx('f8f8f8')); c.rect(9, 3, 22, 5, hx('e4e4e8'))   # toque
    c.rect(11, 1, 11, 3, hx('d0d0d8')); c.rect(15, 1, 15, 3, hx('d0d0d8')); c.rect(19, 1, 19, 3, hx('d0d0d8'))
    return c

def o_priest():
    c = L(); col = hx('1c1c22')
    c.rect(10, 13, 21, 30, col)
    c.rect(7, 13, 9, 22, col); c.rect(22, 13, 24, 22, col)
    c.rect(9, 26, 22, 31, hx('15151a'))
    c.rect(7, 21, 9, 22, hx('50505c')); c.rect(22, 21, 24, 22, hx('50505c'))
    c.rect(15, 14, 16, 20, hx('e0b848')); c.rect(13, 16, 18, 16, hx('e0b848'))   # pectoral cross
    c.rect(10, 0, 21, 3, col); c.rect(9, 4, 22, 5, hx('15151a'))                   # kamilavka
    c.rect(13, 9, 18, 13, hx('b0b0b8')); c.rect(14, 10, 17, 12, hx('c8c8d0'))     # beard
    c.rect(12, 7, 19, 8, hx('d0a888'))
    c.rect(13, 7, 13, 7, hx('101012')); c.rect(18, 7, 18, 7, hx('101012'))
    return c

def o_kannushi():
    c = L()
    c.rect(10, 13, 21, 24, hx('f4f4f0'))
    c.rect(7, 13, 9, 22, hx('f4f4f0')); c.rect(22, 13, 24, 22, hx('f4f4f0'))
    c.rect(7, 13, 9, 13, hx('d0d0d8')); c.rect(22, 13, 24, 13, hx('d0d0d8'))
    c.line(15, 14, 15, 20, hx('c0c0c8')); c.line(16, 14, 16, 20, hx('c0c0c8'))
    c.rect(10, 21, 21, 30, hx('8aa0c0'))                               # hakama
    c.rect(10, 21, 21, 21, hx('3a4a6a'))
    c.line(15, 22, 15, 30, hx('6a80a0')); c.line(17, 22, 17, 30, hx('6a80a0'))
    c.rect(11, 0, 20, 2, hx('101014')); c.rect(12, 3, 19, 3, hx('101014'))     # eboshi
    return c

def o_suit():
    c = _body_outfit(hx('22242c'), hx('d8d8e0'), hx('22242c'), hem=25)
    c.rect(14, 14, 17, 18, hx('f0f0f4')); c.line(15, 15, 16, 19, hx('c83040')); c.line(16, 15, 16, 20, hx('c83040'))
    return c

def o_thug():
    c = _body_outfit(hx('b02828'), hx('401414'), hx('1c1c22'), belt=hx('1c1c22'))
    c.rect(9, 3, 22, 5, hx('c83030')); c.rect(21, 5, 23, 7, hx('c83030'))            # bandana
    c.rect(12, 6, 19, 6, hx('101014'))
    return c

def o_nap():
    c = _body_outfit(hx('2c3c68'), hx('8aa0d8'), hx('1c2440'), belt=hx('101420'))
    c.rect(11, 15, 12, 16, hx('f0d060'))                                              # badge
    c.rect(9, 2, 22, 5, hx('202c50')); c.rect(9, 5, 22, 6, hx('101830'))               # cap
    c.rect(14, 3, 17, 4, hx('f0d060'))
    return c

def o_nasim():
    c = _body_outfit(hx('15151c'), hx('30e8ff'), hx('15151c'), belt=hx('30e8ff'))
    c.rect(9, 1, 22, 6, hx('15151c'))
    c.rect(9, 7, 10, 12, hx('15151c')); c.rect(21, 7, 22, 12, hx('15151c'))            # hood
    c.glow(7, 15, hx('30e8ff')); c.glow(24, 15, hx('30e8ff'))
    return c

def o_overalls():
    c = _body_outfit(hx('d87820'), hx('50301a'), hx('d87820'), belt=hx('50301a'))
    c.rect(10, 13, 11, 18, hx('d0d0c8')); c.rect(20, 13, 21, 18, hx('d0d0c8'))        # straps over a shirt
    return c

def o_courier():
    c = _body_outfit(hx('2a9cc8'), hx('f0f8ff'), hx('26262e'), belt=hx('f0f8ff'))
    c.rect(9, 3, 22, 4, hx('f0f8ff'))                                                  # cap band
    return c

# implants
def i_optics():
    c = L()
    c.glow(13, 7, hx('30e8ff')); c.glow(18, 7, hx('30e8ff'))
    c.rect(12, 7, 19, 7, (48, 232, 255, 110))
    return c

def i_thermal():
    c = L()
    c.rect(11, 7, 20, 8, (255, 60, 40, 150))
    c.glow(13, 7, hx('ffa060')); c.glow(18, 7, hx('ffa060'))
    return c

def i_cortex():
    c = L()
    for (x, y) in ((9, 6), (22, 6), (9, 8), (22, 8)):
        c.glow(x, y, hx('30e8ff'))
    c.rect(9, 5, 9, 9, hx('68727e')); c.rect(22, 5, 22, 9, hx('68727e'))
    c.glow(15, 1, hx('30e8ff')); c.glow(16, 1, hx('30e8ff'))
    return c

def i_jets():
    c = L()
    for x in (8, 22):
        c.rect(x, 10, x + 1, 13, hx('78828e')); c.glow(x, 9, hx('ff9a30')); c.glow(x + 1, 9, hx('ffd060'))
    return c

def i_reflex():
    c = L()
    c.line(12, 12, 12, 13, hx('30e8ff')); c.line(19, 12, 19, 13, hx('30e8ff'))
    for x in (8, 23):
        c.line(x, 14, x, 21, hx('30e8ff'))
    return c

def i_synapse():
    c = L()
    for (x, y) in ((10, 3), (10, 5), (21, 3), (21, 5)):
        c.glow(x, y, hx('ff58c8'))
    c.line(10, 3, 12, 1, hx('ff58c8')); c.line(21, 3, 19, 1, hx('ff58c8'))
    c.line(15, 13, 15, 24, (255, 88, 200, 140)); c.line(16, 13, 16, 24, (255, 88, 200, 140))
    c.glow(15, 13, hx('ffd0f0')); c.glow(16, 13, hx('ffd0f0'))
    return c

def i_dermal():
    c = L(); col = (176, 188, 202, 150)
    for y in (15, 18, 21):
        c.rect(10, y, 21, y, col)
    c.line(15, 13, 15, 24, col)
    for x in (8, 23):
        c.rect(x, 15, x, 20, col)
    c.rect(11, 28, 14, 28, col); c.rect(17, 28, 20, 28, col)
    return c

def i_mantis():
    c = L(); st = hx('d8e4f0')
    for x, dx in ((8, -1), (23, 1)):
        c.line(x, 22, x + dx, 31, st); c.line(x + dx, 31, x + dx, 33, hx('ffffff'))
        c.px(x, 23, hx('8a96a4'))
    return c

def i_legs():
    c = L()
    for x in (12, 18):
        c.rect(x, 26, x + 2, 26, hx('30e8ff')); c.rect(x - 1, 27, x - 1, 29, hx('68727e')); c.rect(x + 3, 27, x + 3, 29, hx('68727e'))
    return c

def i_smartlink():
    c = L()
    c.glow(8, 22, hx('30e8ff')); c.glow(23, 22, hx('30e8ff'))
    return c

def i_heart():
    c = L()
    c.glow(13, 16, hx('ff4060')); c.glow(14, 16, hx('ff8090')); c.glow(13, 17, hx('ff4060'))
    return c

def i_grip():
    c = L()
    for x in (7, 24):
        c.glow(x, 22, hx('90ff90'))
    return c

LAYERS = {
    'helmet_ball': l_helmet_ball, 'visor': l_visor, 'helm_tac': l_helm_tac, 'balaclava': l_balaclava,
    'vest': l_vest, 'vest_heavy': l_vest_heavy, 'vest_corp': l_vest_corp, 'jacket': l_jacket, 'coat': l_coat,
    'bracers': l_bracers, 'bracers_heavy': l_bracers_heavy, 'greaves': l_greaves, 'greaves_heavy': l_greaves_heavy, 'kneepads': l_kneepads,
    'backpack': l_backpack, 'holster': l_holster,
    'labcoat': o_labcoat, 'chef': o_chef, 'priest': o_priest, 'kannushi': o_kannushi, 'suit': o_suit, 'thug': o_thug, 'nap': o_nap,
    'nasim': o_nasim, 'overalls': o_overalls, 'courier': o_courier,
    'imp_optics': i_optics, 'imp_thermal': i_thermal, 'imp_cortex': i_cortex, 'imp_jets': i_jets, 'imp_reflex': i_reflex,
    'imp_synapse': i_synapse, 'imp_dermal': i_dermal, 'imp_mantis': i_mantis, 'imp_legs': i_legs, 'imp_smartlink': i_smartlink,
    'imp_heart': i_heart, 'imp_grip': i_grip,
}
for _i in range(len(JACKETS)):
    LAYERS['jacket_%d' % _i] = (lambda i=_i: jacket(i))
