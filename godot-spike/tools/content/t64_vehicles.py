"""Painted top-down vehicle bodies at 64 px per footprint cell, facing UP.  Each kind is three layers: 'u' (shadow, wheels, skids: below),
'p' (the paint, drawn near-white so the game can tint it with the vehicle's colour) and 'o' (glass, lights, trim, outline: on top).
Sprite ids: veh_<kind>_<layer>.  Sizes follow the footprints in vehicles.gd KINDS."""
import numpy as np
from art64 import Art, col, lit

SS = 3
GLASS = '#0d2736'
STEEL = '#aab3bd'
DARK = '#16181d'
CY = '#35d7ff'
MG = '#ff3fa4'


class V:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.u, self.p, self.o = Art(w, h, SS), Art(w, h, SS), Art(w, h, SS)

    def images(self):
        return [self.u.image(), self.p.image(), self.o.image()]


def paint(v, m, bevel=8, strength=0.75, spec=0.5, base='#eef0f2', seed=1):
    v.p.shade(m, base, bevel=bevel, strength=strength, spec=spec, grain=0.06, seed=seed)


def glass(v, m, streak=True):
    v.o.shade(m, GLASS, bevel=3, strength=0.5, spec=1.0, emit=0.12)


def edge(v, m, w=1.8):
    v.o.stroke(m, '#0b0c10', w, 0.95)


def lamp(v, x, y, w, h, c, glow=14):
    m = v.o.rrect(x, y, w, h, min(w, h) / 2.2)
    v.o.shade(m, c, bevel=min(w, h) / 3, strength=0.2, emit=1.0)
    v.o.glow(x + w / 2, y + h / 2, glow, c, 0.8)


def wheel(v, x, y, w, h):
    m = v.u.rrect(x, y, w, h, 7)
    v.u.shade(m, '#1b1d22', bevel=5, strength=0.7, spec=0.2, grain=0.2, seed=int(x + y))
    for k in range(5):
        v.u.fill(v.u.rect(x + 2, y + 6 + k * (h - 12) / 4.0, w - 4, 2), '#0a0b0d', 0.8)
    v.u.shade(v.u.rrect(x + w * 0.2, y + h * 0.3, w * 0.6, h * 0.4, 4), '#6a7480', bevel=3, strength=0.4, spec=0.8) if False else None


# ------------------------------------------------------------------------------------------------ car 3x5
def car():
    v = V(192, 320)
    u, p, o = v.u, v.p, v.o
    body = p.rrect(16, 5, 160, 310, 38)
    u.shadow(body, 3, 5, 7, 0.5)
    for (x, y) in ((0, 56), (170, 56), (0, 222), (170, 222)):
        wheel(v, x, y, 22, 48)
    paint(v, body, bevel=11, seed=2)
    roof = p.rrect(38, 104, 116, 116, 22)
    paint(v, roof, bevel=6, strength=0.6, seed=5)
    # glass
    glass(v, o.poly([(44, 104), (148, 104), (140, 70), (52, 70)]))
    glass(v, o.poly([(45, 220), (147, 220), (140, 250), (52, 250)]))
    glass(v, o.rrect(27, 112, 11, 100, 5))
    glass(v, o.rrect(154, 112, 11, 100, 5))
    o.fill(o.line(64, 94, 112, 77, 2.0), '#6fb7d4', 0.55)
    # bonnet and boot detail
    for k in range(4):
        o.fill(o.rect(68, 20 + k * 8, 56, 3), '#1a1c21', 0.85)
    o.fill(o.rect(94, 7, 4, 63), '#1a1c21', 0.35)
    o.fill(o.rect(94, 250, 4, 58), '#1a1c21', 0.35)
    # door seams and mirrors
    for y in (142, 193):
        o.fill(o.rect(22, y, 4, 2), '#1a1c21', 0.7)
    for (x, y) in ((8, 94), (174, 94)):
        o.shade(o.rrect(x, y, 11, 14, 4), '#aab3bd', bevel=3, strength=0.5, spec=0.8)
    # lamps, light strips
    lamp(v, 27, 5, 34, 12, '#f6fcff')
    lamp(v, 131, 5, 34, 12, '#f6fcff')
    lamp(v, 25, 300, 40, 10, '#ff2a3a')
    lamp(v, 127, 300, 40, 10, '#ff2a3a')
    o.shade(o.rect(70, 302, 52, 4), MG, bevel=1.2, strength=0.1, emit=1.0)
    o.shade(o.rrect(18, 122, 4, 80, 2), CY, bevel=1.0, strength=0.1, emit=1.0)
    o.shade(o.rrect(170, 122, 4, 80, 2), CY, bevel=1.0, strength=0.1, emit=1.0)
    # antenna
    o.shade(o.rrect(93, 168, 6, 6, 3), '#222', bevel=2)
    edge(v, body)
    return v


# ------------------------------------------------------------------------------------------------ truck 6x12
def truck():
    v = V(384, 768)
    u, p, o = v.u, v.p, v.o
    hood = p.rrect(40, 6, 304, 160, 34)
    cab = p.rrect(26, 150, 332, 176, 30)
    cargo = p.rrect(18, 336, 348, 424, 14)
    body = hood | cab | cargo
    u.shadow(body, 5, 8, 10, 0.5)
    u.shade(u.rect(120, 300, 144, 60), '#23262c', bevel=3, strength=0.4)            # chassis between cab and box
    for (x, y) in ((4, 70), (350, 70), (0, 470), (354, 470), (0, 610), (354, 610)):
        wheel(v, x, y, 30, 70)
    paint(v, hood, bevel=14, seed=3)
    paint(v, cab, bevel=12, seed=4)
    paint(v, cargo, bevel=6, strength=0.55, spec=0.3, base='#e3e6e9', seed=6)
    # cargo ribs and doors
    for k in range(1, 9):
        o.fill(o.rect(18 + k * 38.5, 342, 3, 412), '#1b1d22', 0.35)
    o.fill(o.rect(18, 340, 348, 6), '#1b1d22', 0.6)
    o.fill(o.rect(18, 752, 348, 6), '#1b1d22', 0.6)
    o.shade(o.rect(188, 700, 5, 52), '#111', bevel=0.5, strength=0.2)
    # cab glass
    glass(v, o.poly([(46, 172), (338, 172), (324, 216), (60, 216)]))
    glass(v, o.rrect(28, 226, 14, 70, 6))
    glass(v, o.rrect(342, 226, 14, 70, 6))
    o.fill(o.line(100, 190, 220, 180, 3), '#6fb7d4', 0.5)
    # grille, bonnet, exhausts
    for k in range(5):
        o.fill(o.rect(110, 24 + k * 12, 164, 4), '#14161a', 0.85)
    for x in (36, 328):
        o.shade(o.rrect(x, 250, 14, 80, 6), '#8a929c', bevel=4, strength=0.8, spec=0.9)
    lamp(v, 54, 6, 56, 16, '#f6fcff')
    lamp(v, 274, 6, 56, 16, '#f6fcff')
    lamp(v, 28, 742, 66, 12, '#ff2a3a')
    lamp(v, 290, 742, 66, 12, '#ff2a3a')
    for x in (150, 180, 210):
        lamp(v, x, 156, 14, 8, '#ffb020', glow=8)                                     # cab marker lights
    o.shade(o.rect(20, 520, 5, 130), CY, bevel=1, strength=0.1, emit=1.0)
    o.shade(o.rect(359, 520, 5, 130), CY, bevel=1, strength=0.1, emit=1.0)
    edge(v, body)
    return v


# ------------------------------------------------------------------------------------------------ mech 5x5
def mech():
    v = V(320, 320)
    u, p, o = v.u, v.p, v.o
    torso = p.rrect(78, 70, 164, 140, 26)
    sh_l = p.rrect(14, 74, 64, 114, 16)
    sh_r = p.rrect(242, 74, 64, 114, 16)
    u.shadow(torso | sh_l | sh_r, 5, 8, 10, 0.55)
    for x in (30, 190):                                                                 # feet
        u.shade(u.rrect(x, 196, 100, 108, 12), '#2d323a', bevel=8, strength=0.8, spec=0.5, grain=0.15, seed=x)
        for k in range(3):
            u.fill(u.rect(x + 8, 230 + k * 22, 84, 4), '#101216', 0.7)
        u.shade(u.rrect(x + 26, 168, 48, 44, 8), '#444b55', bevel=5, strength=0.7, spec=0.6)      # lower leg
    paint(v, torso, bevel=12, seed=7)
    paint(v, sh_l, bevel=9, base='#dfe2e6', seed=8)
    paint(v, sh_r, bevel=9, base='#dfe2e6', seed=9)
    # arm cannons pointing forward
    for x in (26, 256):
        o.shade(o.rrect(x, 8, 36, 96, 8), '#555d68', bevel=6, strength=0.9, spec=0.8)
        o.shade(o.rrect(x + 8, 0, 20, 26, 4), '#16181d', bevel=3, strength=0.6)
        o.fill(o.rect(x + 14, 4, 8, 12), '#05070a', 0.9)
    # cockpit canopy, head sensor
    glass(v, o.rrect(116, 92, 88, 52, 22))
    o.fill(o.line(130, 104, 176, 98, 3), '#7fd3ee', 0.6)
    o.shade(o.rrect(138, 56, 44, 24, 10), '#3a3f47', bevel=5, strength=0.8, spec=0.7)
    o.shade(o.rect(146, 64, 28, 6), '#ff3b30', bevel=0.8, strength=0.1, emit=1.0)
    o.glow(160, 67, 22, '#ff3b30', 0.9)
    # reactor core and vents on the back
    o.shade(o.ellipse(160, 178, 22), '#0a2a38', bevel=7, strength=0.5, spec=0.8, emit=0.35)
    o.shade(o.ellipse(160, 178, 11), CY, bevel=3, strength=0.1, emit=1.0)
    o.glow(160, 178, 40, CY, 0.8)
    for k in range(4):
        o.fill(o.rect(92, 150 + k * 9, 36, 4), '#17191e', 0.85)
        o.fill(o.rect(192, 150 + k * 9, 36, 4), '#17191e', 0.85)
    for x in (30, 258):
        o.shade(o.rect(x + 4, 120, 22, 6), '#ffb020', bevel=0.6, strength=0.1, emit=0.9)      # hazard stripe on the shoulders
    edge(v, torso | sh_l | sh_r)
    return v


# ------------------------------------------------------------------------------------------------ heli 6x9  (mast at x=192, y=218)
HELI_MAST = (192, 218)


def heli():
    v = V(384, 576)
    u, p, o = v.u, v.p, v.o
    fus = p.ellipse(192, 214, 86, 196)
    boom = p.poly([(176, 360), (208, 360), (200, 548), (184, 548)])
    fin = p.poly([(184, 500), (200, 500), (232, 566), (152, 566)])
    stab = p.rrect(140, 508, 104, 16, 6)
    body = fus | boom | fin | stab
    u.shadow(body, 6, 10, 12, 0.5)
    for x in (94, 280):                                                                   # skids
        u.shade(u.rrect(x, 128, 12, 300, 6), '#2d323a', bevel=4, strength=0.8, spec=0.6)
        u.shade(u.rect(x - 4 + (0 if x < 190 else 8), 190, 20, 8), '#2d323a', bevel=2)
        u.shade(u.rect(x - 4 + (0 if x < 190 else 8), 330, 20, 8), '#2d323a', bevel=2)
    paint(v, fus, bevel=24, strength=0.8, seed=11)
    paint(v, boom, bevel=7, seed=12)
    paint(v, fin, bevel=6, base='#dfe2e6', seed=13)
    paint(v, stab, bevel=5, base='#dfe2e6', seed=14)
    glass(v, o.ellipse(192, 96, 62, 78))                                                 # canopy
    o.fill(o.line(150, 62, 200, 40, 3), '#7fd3ee', 0.6)
    o.fill(o.rect(188, 24, 8, 150), '#16181d', 0.55)                                      # canopy frame
    # engine cowl round the mast, intakes, exhausts
    o.shade(o.rrect(140, 188, 104, 120, 30), '#d4d8dc', bevel=12, strength=0.7, spec=0.7)
    for k in range(5):
        o.fill(o.rect(156, 240 + k * 10, 72, 3), '#17191e', 0.85)
    o.shade(o.ellipse(192, 218, 16), '#2d323a', bevel=7, strength=0.8, spec=0.9)
    for x in (126, 258):
        o.shade(o.rrect(x, 250, 18, 54, 8), '#3a3f47', bevel=5, strength=0.8, spec=0.6)
    # nose light, side lamps, tail rotor
    lamp(v, 168, 18, 48, 12, '#f6fcff', glow=12)
    o.shade(o.ellipse(112, 190, 6), '#ff2a3a', bevel=2, strength=0.1, emit=1.0)
    o.shade(o.ellipse(272, 190, 6), '#2aff6a', bevel=2, strength=0.1, emit=1.0)
    o.glow(112, 190, 14, '#ff2a3a', 0.7)
    o.glow(272, 190, 14, '#2aff6a', 0.7)
    o.fill(o.ellipse(206, 540, 26), '#c8d2dc', 0.12)
    o.fill(o.line(206, 516, 206, 564, 5), '#8a929c', 0.55)
    o.shade(o.ellipse(206, 540, 6), '#3a3f47', bevel=3, strength=0.8)
    lamp(v, 176, 556, 16, 8, '#ff2a3a', glow=8)
    edge(v, fus)
    return v


# ------------------------------------------------------------------------------------------------ plane 12x10
def plane():
    v = V(768, 640)
    u, p, o = v.u, v.p, v.o
    fus = p.rrect(332, 14, 104, 610, 52)
    wing_l = p.poly([(0, 262), (338, 214), (338, 340), (0, 310)])
    wing_r = p.poly([(768, 262), (430, 214), (430, 340), (768, 310)])
    tail = p.poly([(120, 588), (340, 560), (340, 626), (120, 626)]) | p.poly([(648, 588), (428, 560), (428, 626), (648, 626)])
    body = fus | wing_l | wing_r | tail
    u.shadow(body, 8, 12, 14, 0.5)
    for x in (230, 504):                                                                  # wheels under the wings
        u.shade(u.rrect(x, 330, 24, 56, 8), '#1b1d22', bevel=5, strength=0.7)
    paint(v, fus, bevel=26, strength=0.8, seed=21)
    paint(v, wing_l, bevel=9, base='#e6e9ec', seed=22)
    paint(v, wing_r, bevel=9, base='#e6e9ec', seed=23)
    paint(v, tail, bevel=7, base='#e6e9ec', seed=24)
    glass(v, o.rrect(352, 96, 64, 120, 30))                                              # canopy
    o.fill(o.line(366, 120, 392, 106, 3), '#7fd3ee', 0.55)
    for x in (110, 220, 540, 650):                                                        # panel lines on the wings
        o.fill(o.rect(x, 232 if x < 384 else 232, 3, 96), '#1b1d22', 0.3)
    o.fill(o.rect(14, 288, 300, 3), '#1b1d22', 0.35)
    o.fill(o.rect(454, 288, 300, 3), '#1b1d22', 0.35)
    o.shade(o.rrect(334, 4, 100, 40, 18), '#3a3f47', bevel=8, strength=0.8, spec=0.7)     # engine cowl
    o.shade(o.ellipse(384, 12, 14), '#8a929c', bevel=7, strength=0.8, spec=0.9)
    o.fill(o.ellipse(384, 10, 74), '#c8d2dc', 0.10)                                       # propeller disc
    o.fill(o.line(310, 10, 458, 10, 7), '#7e8792', 0.6)
    o.shade(o.ellipse(8, 262, 7), '#ff2a3a', bevel=2, strength=0.1, emit=1.0)
    o.shade(o.ellipse(760, 262, 7), '#2aff6a', bevel=2, strength=0.1, emit=1.0)
    o.glow(8, 262, 16, '#ff2a3a', 0.8)
    o.glow(760, 262, 16, '#2aff6a', 0.8)
    o.shade(o.rect(380, 520, 8, 90), '#16181d', bevel=1, strength=0.2)
    edge(v, body)
    return v


# ------------------------------------------------------------------------------------------------ train carriage 4x6, a cutaway
# Lanes across (64 px each): 0 and 3 are the side walls (windows, sliding doors at positions 2-3 along the car), 1 and 2 the floor (benches
# along the walls, handrails by the doors).  Position 0 (the top) is the front.  The game draws one 64 px tile of this per carriage cell, turned
# to the train's heading.  'train' has the doors shut; 'trainopen' shows the doorways while the train is stopped.
def train(open_doors=False):
    v = V(256, 384)
    u, p, o = v.u, v.p, v.o
    body = p.rrect(2, 2, 252, 380, 12)
    u.shadow(body, 3, 5, 6, 0.55)
    # the floor: deck plates with seams, a darker aisle, hazard-striped door thresholds
    u.shade(u.rect(60, 2, 136, 380), '#3b414b', bevel=2.0, strength=0.3, grain=0.14, seed=31)
    for k in range(1, 12):
        u.fill(u.rect(60, k * 32, 136, 1.4), '#15181d', 0.5)
    u.fill(u.rect(112, 6, 32, 372), '#2f343d', 0.55)
    for y in (128, 240):
        for k in range(8):
            u.fill(u.poly([(64 + k * 16, y), (72 + k * 16, y), (64 + k * 16, y + 16), (56 + k * 16, y + 16)]), '#e0b020', 0.55)
    # the wall strips: dark under-skin (the thickness of the car side) on both edges
    for (x0, x1) in ((0, 64), (192, 256)):
        u.shade(u.rect(x0, 2, 64, 380), '#262a31', bevel=2.0, strength=0.5, grain=0.12, seed=x0 + 3)
    # benches: along the wall side of each floor lane, between the door positions
    for (y0, y1) in ((8, 120), (264, 376)):
        for (bx, flip) in ((64, False), (152, True)):
            seat = u.rrect(bx + 2, y0, 38, y1 - y0, 7)
            u.shade(seat, '#232a3a', bevel=4.0, strength=0.6, spec=0.2, grain=0.1, seed=y0 + bx)
            cush = p.rrect(bx + (7 if not flip else 12), y0 + 6, 24, y1 - y0 - 12, 6)
            paint(v, cush, bevel=5, strength=0.55, base='#c9d0da', seed=y0 + bx + 1)
            for k in range(3):
                o.fill(o.rect(bx + (8 if not flip else 13), y0 + 6 + (k + 1) * (y1 - y0 - 12) / 4.0, 22, 1.6), '#0b0d12', 0.5)
    # the side walls: livery skin, a lighter roof-rail edge, window band, door leaves
    for (x0, flip) in ((0, False), (192, True)):
        pieces = [(2, 380)] if not open_doors else [(2, 124), (258, 124)]       # with the doors open there is no skin across the doorway
        for (py0, ph) in pieces:
            skin = p.rrect(x0 + (2 if not flip else 0), py0, 62, ph, 6)
            paint(v, skin, bevel=7, strength=0.7, base='#eceff2', seed=x0 + 5 + py0)
            o.fill(o.rect(x0 + (2 if not flip else 56), py0, 6, ph), '#0b0c10', 0.55)
            # livery stripe along the car
            sx = x0 + (30 if not flip else 22)
            o.fill(o.rect(sx, py0 + 4, 6, ph - 8), '#101216', 0.28)
        for y0 in (0, 64, 256, 320):
            win = o.rrect(x0 + (14 if not flip else 14), y0 + 9, 36, 46, 5)
            glass(v, win)
            o.fill(o.line(x0 + 18, y0 + 14, x0 + 44, y0 + 12, 2.4), '#7fd3ee', 0.45)
            o.fill(o.rect(x0 + 14, y0 + 54, 36, 1.6), '#06080b', 0.6)
        if open_doors:
            for y0 in (128, 192):
                # the doorway: the floor shows through, a livery sill on the outer edge
                u.shade(u.rect(x0 + 2, y0 + 4, 60, 56), '#363c46', bevel=1.5, strength=0.3, grain=0.12, seed=x0 + y0)
                o.fill(o.rect(x0 + (2 if not flip else 56), y0 + 4, 6, 56), '#101216', 0.5)
                o.fill(o.rect(x0 + (52 if not flip else 2), y0 + 4, 8, 56), '#f0f2f4', 0.14)
            for y0 in (124, 252):
                o.fill(o.rect(x0 + 4, y0, 58, 4), '#0b0c10', 0.8)           # door frame ends
        else:
            for y0 in (128, 192):
                leaf = o.rrect(x0 + 6, y0 + 6, 52, 52, 5)
                o.shade(leaf, '#69727f', bevel=3.0, strength=0.5, spec=0.5)
                glass(v, o.rrect(x0 + 14, y0 + 14, 36, 14, 4))
                o.fill(o.line(x0 + 20, y0 + 18, x0 + 40, y0 + 17, 1.8), '#7fd3ee', 0.5)
                o.fill(o.rect(x0 + 8, y0 + 44, 48, 2), '#0b0c10', 0.5)
            o.fill(o.rect(x0 + 4, 191, 56, 2.6), '#07080b', 0.85)            # the meeting seam of the two leaves
            for y0 in (136, 214):
                o.shade(o.rrect(x0 + (44 if not flip else 14), y0, 6, 20, 3), '#aab3bd', bevel=2, strength=0.6, spec=0.8)
    # handrails by the doors
    for (hx, hy) in ((92, 150), (92, 234), (164, 150), (164, 234)):
        o.shade(o.ellipse(hx, hy, 6), '#aab3bd', bevel=3, strength=0.7, spec=0.9)
        o.fill(o.ellipse(hx + 2, hy + 3, 7), '#000000', 0.18)
    o.fill(o.line(92, 150, 92, 234, 2.6), '#c9d1da', 0.7)
    o.fill(o.line(164, 150, 164, 234, 2.6), '#c9d1da', 0.7)
    # the roof ribs seen through the cutaway, and the ends: bulkheads with a connecting door, a coupler
    for y in (0, 378):
        o.shade(o.rect(2, y, 252, 6), '#0f1116', bevel=1.2, strength=0.5)
        o.shade(o.rrect(88, y - (0 if y == 0 else 2), 80, 8, 3), '#2a2f38', bevel=2.5, strength=0.7, spec=0.5)
    o.fill(o.rect(126, 4, 4, 28), '#050608', 0.8)
    o.fill(o.rect(126, 352, 4, 28), '#050608', 0.8)
    # lit panels and neon trim: a cyan light strip along each wall's inner edge, a magenta route sign at the ends
    o.shade(o.rect(60, 14, 3, 360), CY, bevel=0.8, strength=0.1, emit=0.8)
    o.shade(o.rect(193, 14, 3, 360), CY, bevel=0.8, strength=0.1, emit=0.8)
    for y in (46, 322):
        o.shade(o.rrect(108, y, 40, 8, 3), MG, bevel=1.2, strength=0.1, emit=0.9)
        o.glow(128, y + 4, 22, MG, 0.35)
    # grime: dirt along the floor edges and the door zones, scratches on the skin
    v.u.speckle(u.rect(60, 2, 136, 380), '#0a0b0d', 14.0, 41, size=2.0, alpha=0.22)
    v.o.speckle(o.rect(0, 0, 256, 384), '#0a0b0d', 6.0, 43, size=1.4, alpha=0.18)
    edge(v, body)
    return v


def trainopen():
    return train(True)


BUILD = {'car': car, 'truck': truck, 'mech': mech, 'heli': heli, 'plane': plane}
BUILD.update({'train': train, 'trainopen': trainopen})
SIZES = {'car': (3, 5), 'truck': (6, 12), 'mech': (5, 5), 'heli': (6, 9), 'plane': (12, 10), 'train': (4, 6), 'trainopen': (4, 6)}


def sprites(items=None):
    out = []
    for k, f in BUILD.items():
        u, p, o = f().images()
        out.append(('veh_%s_u' % k, u, 'vehicles'))
        out.append(('veh_%s_p' % k, p, 'vehicles'))
        out.append(('veh_%s_o' % k, o, 'vehicles'))
    return out, {}


if __name__ == '__main__':
    import sys, time
    from PIL import Image
    t = time.time()
    names = sys.argv[1:] or list(BUILD)
    for k in names:
        u, p, o = BUILD[k]().images()
        tint = (200, 60, 70)
        comp = Image.new('RGBA', u.size, (60, 64, 72, 255))
        comp.alpha_composite(u)
        pt = p.copy()
        px = np.asarray(pt).astype(np.float32)
        px[..., 0] *= tint[0] / 255.0 * 1.15
        px[..., 1] *= tint[1] / 255.0 * 1.15
        px[..., 2] *= tint[2] / 255.0 * 1.15
        comp.alpha_composite(Image.fromarray(np.clip(px, 0, 255).astype(np.uint8), 'RGBA'))
        comp.alpha_composite(o)
        comp.save('/tmp/claude-0/veh_%s.png' % k)
        print(k, comp.size, time.time() - t)


def drive_mark(n=96):
    """The "driving" marker on a car's roof: a glossy emerald orb with a bright core, a pale rim, a soft glow and a drop shadow.  n px square."""
    from PIL import Image, ImageFilter
    SSX = 4
    N = n * SSX
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
    cx = cy = N / 2.0
    R = N * 0.30
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    out = np.zeros((N, N, 4), np.float32)
    # shadow on the roof: offset down, blurred
    sh = Image.new('L', (N, N), 0)
    sd = np.asarray(sh).astype(np.float32)
    sd[np.sqrt((xx - cx - N * 0.02) ** 2 + (yy - cy - N * 0.04) ** 2) < R * 1.02] = 255
    sh = Image.fromarray(sd.astype(np.uint8)).filter(ImageFilter.GaussianBlur(N * 0.025))
    sa = np.asarray(sh).astype(np.float32) / 255.0 * 0.55
    out[..., 3] = sa
    # glow
    glow = np.clip(1.0 - (d - R) / (N * 0.17), 0, 1) ** 2.2 * (d >= R * 0.9)
    gcol = np.array([0.20, 1.0, 0.45])
    for k in range(3):
        out[..., k] = np.where(glow > 0, gcol[k], out[..., k])
    out[..., 3] = np.maximum(out[..., 3], glow * 0.55)
    # the orb: a sphere lit from the upper left
    inside = d <= R
    t = np.clip(d / R, 0, 1)
    nz = np.sqrt(np.clip(1 - t * t, 0, 1))
    lx, ly, lz = -0.45, -0.55, 0.70
    nxv = (xx - cx) / R
    nyv = (yy - cy) / R
    lam = np.clip(nxv * lx + nyv * ly + nz * lz, 0, 1)
    base_dark = np.array([0.02, 0.38, 0.17])
    base_lite = np.array([0.45, 1.0, 0.62])
    orb = base_dark[None, None, :] * (1 - lam[..., None]) + base_lite[None, None, :] * lam[..., None]
    rim = np.clip((t - 0.80) / 0.20, 0, 1)[..., None]
    orb = orb * (1 - rim * 0.35) + np.array([0.75, 1.0, 0.85])[None, None, :] * rim * 0.28
    spec = np.exp(-(((xx - (cx - R * 0.34)) / (R * 0.30)) ** 2 + ((yy - (cy - R * 0.40)) / (R * 0.20)) ** 2))
    orb = orb + spec[..., None] * 0.65
    for k in range(3):
        out[..., k] = np.where(inside, np.clip(orb[..., k], 0, 1), out[..., k])
    out[..., 3] = np.where(inside, 1.0, out[..., 3])
    # a thin dark outline and a white inner ring for a clean read on any paint
    ring = (np.abs(d - R) < N * 0.008)
    for k in range(3):
        out[..., k] = np.where(ring, 0.03, out[..., k])
    out[..., 3] = np.where(ring, 1.0, out[..., 3])
    ring2 = (np.abs(d - R * 0.70) < N * 0.006)
    for k in range(3):
        out[..., k] = np.where(ring2, out[..., k] * 0.5 + 0.5, out[..., k])
    im = Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8), 'RGBA')
    return im.resize((n, n), Image.LANCZOS)


def write(outdir):
    import os
    os.makedirs(outdir, exist_ok=True)
    drive_mark().save(os.path.join(outdir, 'veh_drive_mark.png'))
    for k, f in BUILD.items():
        for name, im in zip(('u', 'p', 'o'), f().images()):
            im.save(os.path.join(outdir, 'veh_%s_%s.png' % (k, name)))
