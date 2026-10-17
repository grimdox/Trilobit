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


# ------------------------------------------------------------------------------------------------ car 4x6
def car():
    v = V(256, 384)
    u, p, o = v.u, v.p, v.o
    body = p.rrect(22, 6, 212, 372, 48)
    u.shadow(body, 4, 6, 8, 0.5)
    for (x, y) in ((0, 66), (226, 66), (0, 264), (226, 264)):
        wheel(v, x, y, 30, 58)
    paint(v, body, bevel=14, seed=2)
    roof = p.rrect(50, 124, 156, 140, 26)
    paint(v, roof, bevel=7, strength=0.6, seed=5)
    # glass
    glass(v, o.poly([(58, 124), (198, 124), (186, 84), (70, 84)]))
    glass(v, o.poly([(60, 264), (196, 264), (186, 300), (70, 300)]))
    glass(v, o.rrect(36, 134, 14, 120, 6))
    glass(v, o.rrect(206, 134, 14, 120, 6))
    o.fill(o.line(84, 112, 150, 92, 2.2), '#6fb7d4', 0.55)
    # bonnet and boot detail
    for k in range(4):
        o.fill(o.rect(90, 24 + k * 9, 76, 3), '#1a1c21', 0.85)
    o.fill(o.rect(126, 8, 4, 76), '#1a1c21', 0.35)
    o.fill(o.rect(126, 300, 4, 70), '#1a1c21', 0.35)
    # door seams and mirrors
    for y in (170, 232):
        o.fill(o.rect(30, y, 4, 2), '#1a1c21', 0.7)
    for (x, y) in ((10, 112), (232, 112)):
        o.shade(o.rrect(x, y, 14, 16, 5), '#aab3bd', bevel=3, strength=0.5, spec=0.8)
    # lamps, light strips
    lamp(v, 36, 6, 46, 14, '#f6fcff')
    lamp(v, 174, 6, 46, 14, '#f6fcff')
    lamp(v, 34, 360, 54, 12, '#ff2a3a')
    lamp(v, 168, 360, 54, 12, '#ff2a3a')
    o.shade(o.rect(94, 362, 68, 5), MG, bevel=1.2, strength=0.1, emit=1.0)
    o.shade(o.rrect(24, 146, 5, 96, 2), CY, bevel=1.0, strength=0.1, emit=1.0)
    o.shade(o.rrect(227, 146, 5, 96, 2), CY, bevel=1.0, strength=0.1, emit=1.0)
    # antenna
    o.shade(o.rrect(124, 200, 8, 8, 4), '#222', bevel=2)
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


BUILD = {'car': car, 'truck': truck, 'mech': mech, 'heli': heli, 'plane': plane}
SIZES = {'car': (4, 6), 'truck': (6, 12), 'mech': (5, 5), 'heli': (6, 9), 'plane': (12, 10)}


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


def write(outdir):
    import os
    os.makedirs(outdir, exist_ok=True)
    for k, f in BUILD.items():
        for name, im in zip(('u', 'p', 'o'), f().images()):
            im.save(os.path.join(outdir, 'veh_%s_%s.png' % (k, name)))
