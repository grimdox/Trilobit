"""Icons for worn gear, clothes, implants, nano chips and healing items: the cyberpunk end of the catalogue.
Same renderer as items.py (top-down, lit, outlined, about 48 px).  Neon is the accent: a thin emissive line or core on a
dark, scuffed body, the way the street clothes and the ghost-in-the-shell hardware are lit in the city."""
from canvas import XX, YY
from items import piece, D, B, L, box, dots
from canvas import Tile

GLOW = {1: 'neon_amber', 2: 'neon_cyan', 3: 'neon_violet'}


def _scuff(t, m, step=7):
    t.mark(m & (((XX * 3 + YY * 5) % step) == 0), -1)


# ------------------------------------------------------------------------------------------------ tiered armor
GRADE = {1: ('rubber', 'dark_steel', None), 2: ('fabric_b', 'dark_steel', 'neon_cyan'), 3: ('kevlar', 'steel', 'neon_green'),
         4: ('steel', 'chrome', 'neon_violet'), 5: ('lacquer_black', 'mirror', 'neon_pink')}


def tier_armor(t, slot, n):
    body, trim, glow = GRADE[n]
    if slot == 'head':
        m = D(32, 33, 21, 23)
        t.slab(m, body, 16, profile='dome')
        _scuff(t, m)
        t.slab(B(14, 32, 50, 44, 5) & m, 'glass' if n > 1 else 'rubber', 18, profile='dome')
        t.slab(B(26, 10, 38, 16, 2), trim, 19, bevel=0.5)
        if glow:
            t.emit(B(18, 37, 46, 39), glow)
            t.emit(D(32, 13, 1.6), glow)
        if n >= 4:
            t.slab(B(8, 28, 13, 42, 2) | B(51, 28, 56, 42, 2), trim, 14, bevel=0.5)
    elif slot == 'chest':
        m = Tile.poly_mask([(14, 8), (25, 13), (39, 13), (50, 8), (54, 56), (10, 56)])
        t.slab(m, body, 11, bevel=2)
        t.carve(D(32, 6, 9) & m, 4)
        _scuff(t, m)
        t.slab(B(18, 20, 46, 42, 3), trim, 14, bevel=1)
        for y in (46, 51):
            t.slab(B(14, y, 50, y + 3, 1), body, 13, bevel=0.5)
        if glow:
            t.emit(B(31, 18, 33, 44), glow)
            t.emit(B(22, 30, 42, 31), glow)
        t.slab(B(12, 10, 20, 18, 2) | B(44, 10, 52, 18, 2), trim, 14, bevel=0.6)
    else:
        ln = 20 if slot == 'arms' else 24
        for x in (19, 45):
            m = B(x - 8, 32 - ln, x + 8, 32 + ln, 6)
            t.slab(m, body, 11, profile='dome')
            _scuff(t, m)
            t.slab(B(x - 9, 32 - ln + 5, x + 9, 32 - ln + 9) | B(x - 9, 32 + ln - 9, x + 9, 32 + ln - 5), trim, 13, bevel=0.4)
            t.slab(D(x, 32, 5, 7), trim, 14, profile='dome')
            if glow:
                t.emit(B(x - 1, 32 - ln + 12, x + 1, 32 + ln - 12), glow)


# ------------------------------------------------------------------------------------------------ clothes
def _tee(t, mat, sleeve=8, collar=None, trim=None):
    m = Tile.poly_mask([(20, 8), (28, 12), (36, 12), (44, 8), (58, 22), (50, 30), (46, 26), (46, 56), (18, 56), (18, 26), (14, 30), (6, 22)])
    t.slab(m, mat, 9, bevel=1.5)
    t.carve(D(32, 9, 7) & m, 3)
    t.mark(m & ((YY % 9) == 0), -1)
    if trim:
        t.emit(B(18, 52, 46, 53), trim)
    return m


def clothes(t, k):
    if k == 'tee':
        _tee(t, 'linen', trim='neon_cyan')
    elif k == 'oxford':
        m = _tee(t, 'paper')
        t.paint(B(31, 12, 33, 56) & m, 'ink')
        dots(t, [(32, 20), (32, 30), (32, 40), (32, 50)], 'chrome', 1.2, 10)
        t.slab(Tile.poly_mask([(25, 9), (32, 18), (39, 9), (36, 8), (32, 12), (28, 8)]), 'linen', 10, bevel=0.3)
    elif k == 'hoodie':
        m = _tee(t, 'fabric_grey', trim='neon_pink')
        t.slab(D(32, 14, 11, 8), 'fabric_grey', 12, profile='dome')
        t.carve(D(32, 14, 6, 4), 3)
        t.slab(B(22, 36, 42, 48, 3), 'fabric_grey', 11, bevel=0.6)
        t.slab(L(28, 18, 27, 30, 0.8) | L(36, 18, 37, 30, 0.8), 'rubber', 11, bevel=0)
    elif k in ('leather_jacket', 'blazer', 'suit_jacket', 'armored_suit'):
        mat = {'leather_jacket': 'leather_k', 'blazer': 'fabric_indigo', 'suit_jacket': 'lacquer_black', 'armored_suit': 'fabric_grey'}[k]
        m = _tee(t, mat)
        t.slab(Tile.poly_mask([(22, 8), (32, 36), (42, 8), (46, 12), (36, 40), (28, 40), (18, 12)]), mat, 12, bevel=0.6)
        t.carve(L(32, 36, 32, 56, 0.8) & m, 2)
        if k == 'leather_jacket':
            t.slab(L(30, 12, 30, 56, 1.4), 'chrome', 11, bevel=0)
            t.slab(B(10, 24, 16, 36, 1) | B(48, 24, 54, 36, 1), 'chrome', 10, bevel=0.3)
            t.emit(L(20, 52, 44, 52, 0.8), 'neon_red')
        elif k == 'blazer':
            dots(t, [(32, 40), (32, 47)], 'gold', 1.6, 12)
        elif k == 'suit_jacket':
            t.emit(L(24, 11, 31, 33, 0.7), 'neon_cyan')
            dots(t, [(32, 42)], 'chrome', 1.6, 12)
        else:
            t.slab(B(18, 20, 28, 42, 2) | B(36, 20, 46, 42, 2), 'dark_steel', 13, bevel=0.8)
            t.emit(L(24, 11, 31, 33, 0.7), 'neon_violet')
            t.emit(B(13, 28, 17, 29), 'neon_violet')
            t.emit(B(47, 28, 51, 29), 'neon_violet')
    elif k == 'kimono':
        m = Tile.poly_mask([(16, 6), (28, 8), (34, 8), (48, 6), (60, 24), (60, 34), (48, 56), (16, 56), (4, 34), (4, 24)])
        t.slab(m, 'silk_b', 9, bevel=2)
        t.slab(Tile.poly_mask([(22, 6), (34, 48), (40, 48), (30, 6)]), 'silk_r', 11, bevel=0.5)
        t.slab(B(14, 38, 50, 46, 1), 'gold', 12, bevel=0.5)
        t.emit(D(46, 20, 2), 'neon_pink')
        t.emit(D(14, 24, 2), 'neon_pink')
        t.mark(m & ((XX % 7) == 0), 1)
    elif k in ('jeans', 'cargo', 'slacks', 'tailored_trousers'):
        mat = {'jeans': 'fabric_indigo', 'cargo': 'olive_d', 'slacks': 'fabric_grey', 'tailored_trousers': 'lacquer_black'}[k]
        m = Tile.poly_mask([(16, 6), (48, 6), (50, 58), (35, 58), (32, 24), (29, 58), (14, 58)])
        t.slab(m, mat, 9, bevel=1.5)
        t.slab(B(16, 6, 48, 11), mat, 11, bevel=0.5)
        t.carve(L(32, 12, 32, 24, 0.8) & m, 2)
        _scuff(t, m)
        if k == 'cargo':
            t.slab(B(17, 32, 27, 44, 1) | B(37, 32, 47, 44, 1), 'olive_d', 12, bevel=0.4)
        elif k == 'jeans':
            t.mark(B(18, 40, 28, 41) | B(36, 40, 46, 41), 1)
            t.emit(B(15, 57, 28, 58), 'neon_cyan')
        elif k == 'tailored_trousers':
            t.emit(L(21, 12, 20, 56, 0.6) | L(43, 12, 44, 56, 0.6), 'neon_cyan')
        t.slab(B(15, 6, 49, 9), 'rubber', 12, bevel=0.3)
    elif k == 'cap':
        t.slab(D(30, 34, 19, 18), 'fabric_r', 14, profile='dome')
        t.slab(Tile.poly_mask([(40, 28), (60, 32), (60, 40), (40, 44)]), 'rubber', 11, bevel=0.5)
        t.emit(D(26, 30, 2.4), 'neon_cyan')
        t.mark(D(30, 34, 19, 18) & ((XX % 8) == 0), -1)
    elif k == 'fedora':
        t.slab(D(32, 32, 26, 22), 'lacquer_black', 8, profile='dome')
        t.slab(D(32, 32, 15, 13), 'lacquer_black', 13, profile='dome')
        t.carve(L(26, 32, 38, 32, 1.4), 3)
        t.paint(D(32, 32, 16, 14) & ~D(32, 32, 13, 11), 'fabric_r')
        t.emit(D(46, 32, 1.8), 'neon_amber')
    elif k == 'beret':
        t.slab(D(32, 32, 23, 20), 'fabric_r', 12, profile='dome')
        t.slab(D(32, 18, 3), 'ink', 14, profile='dome')
        t.mark(D(32, 32, 23, 20) & (((XX + YY) % 6) == 0), -1)
        t.emit(D(46, 38, 2), 'neon_pink')
    elif k in ('shades', 'glasses'):
        for x in (19, 45):
            if k == 'shades':
                t.slab(D(x, 34, 12, 9), 'ink', 12, profile='dome')
                t.emit(L(x - 8, 31, x + 6, 36, 1.0), 'neon_pink')
            else:
                t.slab(D(x, 34, 12, 10) & ~D(x, 34, 9, 7), 'gold', 12, bevel=0.5)
                t.slab(D(x, 34, 9, 7), 'glass', 9, profile='dome')
        t.slab(B(30, 31, 34, 34), 'gold' if k == 'glasses' else 'ink', 12, bevel=0)
        t.slab(L(7, 33, 3, 24, 1.4) | L(57, 33, 61, 24, 1.4), 'rubber', 11, bevel=0)
    elif k in ('leather_gloves', 'dress_gloves'):
        mat = 'leather_k' if k == 'leather_gloves' else 'linen'
        for x, flip in ((18, 1), (46, -1)):
            t.slab(D(x, 38, 11, 13), mat, 10, profile='dome')
            for i, dx in enumerate((-8, -3, 3, 8)):
                t.slab(L(x + dx, 28, x + dx - flip * (2 - abs(i - 1.5)), 12 + abs(i - 1.5) * 4, 3.2), mat, 11, bevel=0.2)
            t.slab(B(x - 8, 48, x + 8, 54, 1), 'rubber' if k == 'leather_gloves' else 'silk_b', 11, bevel=0.4)
            if k == 'leather_gloves':
                t.emit(D(x, 38, 1.8), 'neon_red')
    else:
        box(t, 'fabric_grey')


# ------------------------------------------------------------------------------------------------ implants
PARTS = [('head', 4), ('eyes', 3), ('spine', 3), ('chest', 3), ('dermal', 2), ('arms', 3), ('hands', 3), ('legs', 3)]


def implant_part(idx):
    i = idx
    for p, c in PARTS:
        if i < c:
            return p, i
        i -= c
    return 'legs', 0


def implant(t, tier, idx):
    part, v = implant_part(idx)
    g = GLOW[tier]
    shell = ('rubber', 'dark_steel', 'chrome')[tier - 1]
    if part == 'head':                         # a trilobit: three lobes round a lit core
        for ang in (-1, 0, 1):
            t.slab(D(32 + ang * 15, 36 - (1 - abs(ang)) * 4 - 4, 11, 13), shell, 12, profile='dome')
        t.slab(D(32, 34, 9), 'steel', 14, profile='dome')
        t.emit(D(32, 34, 4), g)
        t.slab(L(32, 48, 32, 58, 1.4), 'copper', 8, bevel=0)
        for k in range(v + 1):
            t.emit(D(18 + k * 9, 20, 1.2), g)
    elif part == 'eyes':
        t.slab(D(32, 32, 20), shell, 12, profile='dome')
        t.slab(D(32, 32, 14), 'glass', 14, profile='dome')
        t.emit(D(32, 32, 7 - v), g)
        t.slab(D(32, 32, 2.5), 'ink', 16, profile='dome')
        t.emit(L(10, 32, 16, 32, 0.8) | L(48, 32, 54, 32, 0.8), g)
    elif part == 'spine':
        for i in range(6):
            y = 8 + i * 9
            t.slab(B(22 - (i % 2), y, 42 + (i % 2), y + 6, 2), shell, 11, bevel=0.8)
            t.emit(B(30, y + 2, 34, y + 3), g)
        t.slab(L(32, 6, 32, 58, 1.0), 'copper', 9, bevel=0)
        t.slab(L(18, 20 + v * 8, 46, 20 + v * 8, 1.0), 'steel', 14, bevel=0)
    elif part == 'chest':
        t.slab(B(12, 14, 52, 50, 5), shell, 12, bevel=1.5)
        t.slab(B(18, 20, 46, 44, 3), 'screen', 14, bevel=0.8)
        for i in range(3 + v):
            t.emit(B(21, 24 + i * 5, 43, 26 + i * 5), g)
        t.slab(L(12, 32, 4, 32, 1.4) | L(52, 32, 60, 32, 1.4), 'copper', 9, bevel=0)
    elif part == 'dermal':
        m = B(10, 14, 54, 50, 6)
        t.slab(m, shell, 8, bevel=1.5)
        t.mark(m & ((((XX // 4) + (YY // 4)) % 2) == 0), -1)
        t.emit(B(12, 31, 52, 32), g)
        t.emit(D(32, 32, 2.5), g)
    elif part == 'arms':
        t.slab(B(24, 6, 40, 58, 6), shell, 11, profile='dome')
        for y in (14, 28, 42):
            t.slab(B(20, y, 44, y + 5, 1), 'steel', 13, bevel=0.5)
        t.slab(L(32, 8, 32, 56, 1.2), 'copper', 14, bevel=0)
        t.emit(D(32, 22 + v * 8, 2), g)
    elif part == 'hands':
        t.slab(D(32, 42, 14, 12), shell, 11, profile='dome')
        for dx in (-10, -5, 0, 5, 10):
            t.slab(L(32 + dx, 36, 32 + dx * 1.5, 10 + abs(dx), 2.6), 'steel', 12, bevel=0)
            t.emit(D(32 + dx * 1.5, 10 + abs(dx), 1.3), g)
        t.emit(D(32, 44, 3), g)
    else:                                       # legs: a piston actuator
        t.slab(B(24, 6, 40, 30, 3), shell, 11, bevel=1)
        t.slab(B(28, 28, 36, 58, 1), 'chrome', 13, profile='cyl')
        t.slab(D(32, 14, 7), 'steel', 14, profile='dome')
        t.emit(D(32, 14, 3), g)
        t.slab(L(20, 44, 44, 44, 1.6), 'rubber', 12, bevel=0.3)
        t.emit(L(24, 50 - v * 2, 40, 50 - v * 2, 0.7), g)


# ------------------------------------------------------------------------------------------------ nano chips, belt pack, healing
NANO = {'plating': 'neon_cyan', 'reflex': 'neon_amber', 'shock': 'neon_violet', 'strike': 'neon_red', 'mend': 'neon_green', 'research': 'neon_pink'}


def nano(t, k):
    g = NANO.get(k, 'neon_cyan')
    t.slab(B(14, 14, 50, 50, 3), 'screen', 11, bevel=1.2)
    for p in range(6):
        t.slab(B(8, 18 + p * 6, 14, 20 + p * 6), 'gold', 9, bevel=0)
        t.slab(B(50, 18 + p * 6, 56, 20 + p * 6), 'gold', 9, bevel=0)
    t.slab(B(22, 22, 42, 42, 2), 'ink', 13, bevel=0.6)
    t.emit(L(24, 32, 40, 32, 1.0) | L(32, 24, 32, 40, 1.0), g)
    t.emit(D(32, 32, 3), g)
    t.emit(L(16, 16, 22, 16, 0.6) | L(42, 48, 48, 48, 0.6), g)


def fanny(t):
    t.slab(B(4, 28, 60, 36, 2), 'rubber', 8, bevel=0.8)
    t.slab(B(16, 16, 48, 44, 9), 'fabric_grey', 12, profile='dome')
    t.carve(L(18, 28, 46, 28, 0.8), 2)
    t.slab(B(29, 24, 35, 32, 1), 'chrome', 14, bevel=0.3)
    t.emit(L(18, 40, 46, 40, 0.8), 'neon_cyan')


def heal(t, k):
    if k == 'bandage':
        t.slab(D(32, 32, 16), 'linen', 10, profile='dome')
        t.carve(D(32, 32, 6), 5)
        t.paint(D(32, 32, 16) & ~D(32, 32, 13), 'paper')
        t.slab(B(32, 30, 58, 40, 1), 'linen', 8, bevel=0.3)
        t.paint(B(20, 24, 44, 26), 'red_cross')
    elif k == 'gel':
        t.slab(Tile.poly_mask([(10, 24), (46, 22), (50, 30), (50, 34), (46, 42), (10, 40)]), 'plastic_w', 11, bevel=1.5)
        t.slab(B(46, 26, 58, 38, 2), 'dark_steel', 12, bevel=0.5)
        t.emit(B(14, 28, 40, 36), 'neon_green')
        t.paint(B(10, 24, 14, 40), 'steel')
    elif k == 'stim':
        t.slab(B(10, 26, 44, 38, 5), 'glass', 12, profile='dome')
        t.emit(B(14, 29, 38, 35), 'neon_pink')
        t.slab(B(44, 28, 56, 36, 1), 'chrome', 13, bevel=0.4)
        t.slab(L(56, 32, 62, 32, 0.8), 'chrome', 13, bevel=0)
        t.slab(B(4, 24, 10, 40, 2), 'dark_steel', 13, bevel=0.5)
    else:                                      # suture kit
        box(t, 'plastic_w', 10, 18, 53, 47, 9, 4)
        t.paint(B(29, 22, 34, 43) | B(21, 29, 42, 34), 'red_cross')
        t.slab(L(14, 44, 48, 22, 0.9), 'chrome', 11, bevel=0)
        t.emit(D(48, 22, 1.4), 'neon_cyan')
