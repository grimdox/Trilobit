"""Visible implants for the standing dolls (in review): examples for the head, arms, torso and legs, each a layer that
stacks on the base body like clothing.  Named for the implants in src/implants.gd (DollSpec.IMPLANT_LAYER keys).
Chrome and graphite with cyan lights; thermal uses amber.  No red: danger red is for hostiles.
Keys and draw order:
  head   imp_cortex (z 73, over hair), imp_optics (z 71), imp_thermal (z 71)
  arms   imp_mantis (z 49, over sleeves), imp_smartlink (z 41 traces under sleeves) + imp_smartlink_hand (z 61), imp_grip (z 61)
  torso  imp_dermal (z 12), imp_heart (z 12), imp_jets (z 2, behind the body)
  legs   imp_legs (z 33, braces over trousers), imp_legs_seam (z 12, under the skin)"""
import numpy as np
import t64_figure as F
import t64_kit as K
from t64_figure import A, col, mix, px, crisp, ramp_paint, limb_paint

CHROME = K.ramp_from('#9aa6b4')
GRAPH = K.ramp_from('#3c424c')
CYAN, CYAN_D = '#35d7ff', '#1f8fb0'
AMBER, AMBER_D = '#ffb54a', '#a0601c'
SEAM = '#1c2028'


def _eyes(b):
    hx, cy = b.centre(), b.head_cy
    fx = hx + 1.2 * b.turn
    sep = 2.2 * (1 - 0.2 * b.turn)
    ey0 = int(round(cy + 0.2 - 1.4))
    near = int(round(fx - (sep + 0.4) - 1.0))
    far = int(round(fx + (sep + 0.4) - 0.5))
    return near, far, ey0


# ------------------------------------------------------------------------------------------------ head
def cortex(b):
    """Neural Link: a chrome skull plate on the temple in front of the ear, two jack ports and a seam running back"""
    a = A()
    hx, cy, (rx, ry) = b.centre(), b.head_cy, b.head
    plate = a.poly([(hx - rx + 0.4, cy - 3.2), (hx - rx + 3.0, cy - 3.6), (hx - rx + 3.2, cy - 0.6), (hx - rx + 1.2, cy + 0.2), (hx - rx + 0.2, cy - 1.0)])
    ramp_paint(a, plate, CHROME, bevel=1.0)
    a.stroke(plate, SEAM, 0.3, 0.9)
    for dy in (-2.2, -0.8):
        px(a, hx - rx + 1.4, cy + dy, '#14181e')
        px(a, hx - rx + 2.4, cy + dy, CYAN)
    a.fill(a.line(hx - rx + 0.4, cy - 3.0, hx - rx - 0.4, cy - 5.4, 0.45), SEAM, 0.9)      # seam back over the skull
    return {'imp_cortex': (crisp(a, outline=False), 73)}


def optics(b):
    """Optic Suite: the near eye is a round lens in a graphite ring with a ranging line to the ear"""
    a = A()
    ne, fe, ey = _eyes(b)
    hx, cy, rx = b.centre(), b.head_cy, b.head[0]
    a.fill(a.rect(ne - 1, ey, 4, 4), GRAPH[2])
    a.fill(a.rect(ne - 1, ey, 4, 1), GRAPH[4])
    px(a, ne, ey + 1, '#0b1a22', w=2, h=2)
    px(a, ne + 1, ey + 1, CYAN)
    px(a, ne, ey + 2, CYAN_D)
    a.fill(a.line(ne - 1.0, ey + 1.5, hx - rx + 1.0, cy - 0.2, 0.5), GRAPH[3])            # rangefinder arm to the ear
    px(a, fe, ey + 1, CYAN_D, w=2)                                                     # the far eye picks up the overlay
    return {'imp_optics': (crisp(a, outline=False), 71)}


def thermal(b):
    """Thermal Vision: both eyes behind amber heat lenses, a thin graphite bridge between them"""
    a = A()
    ne, fe, ey = _eyes(b)
    px(a, ne - 1, ey + 1, GRAPH[1], w=fe - ne + 3, h=1)
    px(a, ne, ey + 1, AMBER, w=3)
    px(a, ne + 1, ey + 1, '#fff0c8')
    px(a, fe, ey + 1, AMBER_D, w=2)
    px(a, ne - 1, ey + 2, GRAPH[2], w=fe - ne + 3, h=1)
    return {'imp_thermal': (crisp(a, outline=False), 71)}


# ------------------------------------------------------------------------------------------------ arms and hands
def mantis(b):
    """Mantis Blades, folded: a graphite housing along the outside of each forearm with the blade's back edge showing"""
    a = A()
    for near in (True, False):
        E, H = (b.E_n, b.H_n) if near else (b.E_f, b.H_f)
        ux, uy = H[0] - E[0], H[1] - E[1]
        L = np.hypot(ux, uy)
        ux, uy = ux / L, uy / L
        nx, ny = -uy, ux
        if nx > 0:                                    # the outside of the arm is the side away from the body
            nx, ny = -nx, -ny
        if not near:
            nx, ny = -nx, -ny
        off = b.arm_w[1] * 0.38
        p0 = (E[0] + nx * off + ux * 0.4, E[1] + ny * off + uy * 0.4)
        p1 = (H[0] + nx * off - ux * 2.0, H[1] + ny * off - uy * 2.0)
        limb_paint(a, p0, p1, 2.2, 1.8, ramp=GRAPH, dim=0 if near else 0)
        a.fill(a.line(p0[0] + nx * 1.2 - ux * 1.2, p0[1] + ny * 1.2 - uy * 1.2, p1[0] + nx * 1.1 + ux * 0.6, p1[1] + ny * 1.1 + uy * 0.6, 0.8), CHROME[6 if near else 5])
        mx, my = (p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2
        px(a, mx, my, CYAN if near else CYAN_D)
    return {'imp_mantis': (crisp(a), 49)}


def smartlink(b):
    """Smartlink Palm: a chrome port on the back of the near hand, a lit trace running up the forearm under the skin"""
    t, h = A(), A()
    E, H = b.E_n, b.H_n
    for k in (0.15, 0.45, 0.75):
        x, y = E[0] + (H[0] - E[0]) * k, E[1] + (H[1] - E[1]) * k
        px(t, x, y, CYAN_D)
    t.fill(t.line(E[0] + (H[0] - E[0]) * 0.15, E[1] + (H[1] - E[1]) * 0.15, H[0] - 0.6, H[1] - 1.6, 0.4), CYAN_D, 0.85)
    px(h, H[0] - 1, H[1] - 1, CHROME[5], w=2, h=2)
    px(h, H[0], H[1] - 1, CYAN)
    return {'imp_smartlink': (crisp(t, outline=False), 41), 'imp_smartlink_hand': (crisp(h, outline=False), 61)}


def grip(b):
    """Gecko Grip: dark setae pads across the fingers of both hands, a chrome stud at the base of each"""
    a = A()
    for H, E in ((b.H_n, b.E_n), (b.H_f, b.E_f)):
        ux, uy = H[0] - E[0], H[1] - E[1]
        L = np.hypot(ux, uy)
        ux, uy = ux / L, uy / L
        cx, cy = H[0] + ux * 1.4, H[1] + uy * 1.4
        pad = a.line(cx - uy * 2.2, cy + ux * 2.2, cx + uy * 2.2, cy - ux * 2.2, 1.6)
        a.fill(pad, '#262c3a')
        a.fill(pad & (((a.xx + a.yy) * 2).astype(int) % 2 == 0), '#4a5468')          # the setae texture
        for d in (-1.3, 0.0, 1.3):
            px(a, cx - ux * 1.6 - uy * d, cy - uy * 1.6 + ux * d, CHROME[5])
    return {'imp_grip': (crisp(a, outline=False), 61)}


# ------------------------------------------------------------------------------------------------ torso
def dermal(b):
    """Dermal Plating: the skin over chest, stomach and shoulders split into plates by fine seams, with a cool sheen"""
    a = A()
    tor = b.torso(a)
    t = b.top
    sheen = tor & (((a.xx - b.mx) * 0.6 + (a.yy - t) * 0.4) % 3.4 < 0.5)
    a.fill(sheen, '#c8d4e0', 0.3)
    for y in (t + 4.0, t + 8.6, t + 13.0, t + 17.4):
        a.fill(a.line(b.X(-b.chest - 1), y, b.X(b.chest + 1), y + 0.4, 0.4) & tor, SEAM, 0.85)
    for x in (-5.4, -1.6, 2.2, 6.0):
        for y0, y1 in ((t + 4.0, t + 8.6), (t + 13.0, t + 17.4)):
            a.fill(a.line(b.X(x), y0, b.X(x + 0.4), y1, 0.4) & tor, SEAM, 0.85)
        a.fill(a.line(b.X(x + 1.8), t + 8.6, b.X(x + 2.2), t + 13.0, 0.4) & tor, SEAM, 0.85)     # staggered like scales
    return {'imp_dermal': (crisp(a, outline=False), 12)}


def heart(b):
    """Cardiac Booster: a chrome ring set in the chest left of the sternum, its core glowing through the skin"""
    a = A()
    t = b.top
    cx, cy = b.X(-2.6), t + 6.4 + (0.6 if b.fem else 0)
    ring = a.ellipse(cx, cy, 2.2, 2.2) & ~a.ellipse(cx, cy, 1.1, 1.1)
    ramp_paint(a, ring, CHROME, bevel=0.8)
    a.fill(a.ellipse(cx, cy, 1.1, 1.1), CYAN)
    px(a, cx - 0.6, cy - 0.6, '#d8fbff')
    a.glow(cx, cy, 3.6, CYAN_D, 0.35)
    for ang in (0.4, 2.2, 3.9):
        a.fill(a.line(cx + 2.2 * np.cos(ang), cy + 2.2 * np.sin(ang), cx + 3.8 * np.cos(ang), cy + 3.8 * np.sin(ang), 0.4), SEAM, 0.6)
    return {'imp_heart': (crisp(a, outline=False), 12)}


def jets(b):
    """Dorsal Jump Jets: two graphite nozzles mounted on the back, showing over the shoulders, with lit exhaust rings"""
    a = A()
    t = b.top
    for s, dim in ((-1, 0), (1, 1)):
        x = b.X(s * (b.sh - 2.0))
        limb_paint(a, (x + 0.8 * s, t - 6.4), (x, t + 1.4), 4.4, 3.8, ramp=GRAPH, dim=dim)
        a.fill(a.ellipse(x + 0.8 * s, t - 6.6, 2.2, 1.0), '#10141a')
        a.fill(a.ellipse(x + 0.8 * s, t - 6.6, 1.4, 0.55), CYAN if dim == 0 else CYAN_D)
        a.fill(a.line(x - 2.0 + 0.5 * s, t - 3.6, x + 2.0 + 0.5 * s, t - 3.6, 0.5), CHROME[5 - dim])
        a.fill(a.line(x - 1.8 + 0.4 * s, t - 1.2, x + 1.8 + 0.4 * s, t - 1.2, 0.5), CHROME[4 - dim])
    return {'imp_jets': (crisp(a), 2)}


# ------------------------------------------------------------------------------------------------ legs
def legs(b):
    """Leg Actuators, the visible kind: chrome knee discs and piston rods down the outside of each shin"""
    a = A()
    for near in (True, False):
        K_, A_ = (b.K_n, b.A_n) if near else (b.K_f, b.A_f)
        side = -1 if near else 1
        off = b.leg_w[1] * 0.45 * side
        dim = 0 if near else 1
        limb_paint(a, (K_[0] + off, K_[1] + 0.6), (A_[0] + off * 0.7, A_[1] - 2.2), 1.6, 1.2, ramp=CHROME, dim=dim)
        limb_paint(a, (K_[0] + off * 1.1, K_[1] - 3.0), (K_[0] + off, K_[1] + 1.0), 1.8, 1.8, ramp=GRAPH, dim=dim)
        knee = a.ellipse(K_[0] + off * 0.9, K_[1], 1.8, 1.8)
        ramp_paint(a, knee, CHROME, bevel=0.8, k=1.0 if near else 0.85)
        px(a, K_[0] + off * 0.9, K_[1], CYAN if near else CYAN_D)
    return {'imp_legs': (crisp(a), 33)}


def legs_seam(b):
    """Leg Actuators, the hidden kind: plating seams round each knee and down the shin, one port lit below the knee"""
    a = A()
    for near in (True, False):
        K_, A_ = (b.K_n, b.A_n) if near else (b.K_f, b.A_f)
        a.stroke(a.ellipse(K_[0], K_[1] - 0.2, 2.6, 2.2), SEAM, 0.45, 0.9)
        a.fill(a.ellipse(K_[0] - 0.4, K_[1] - 0.6, 1.0, 0.8), '#c8d4e0', 0.35)
        a.fill(a.line(K_[0] - 0.6, K_[1] + 2.6, A_[0] - 0.4, A_[1] - 3.0, 0.45), SEAM, 0.85)
        a.fill(a.line(K_[0] - 2.2, K_[1] + 5.6, K_[0] + 1.6, K_[1] + 5.8, 0.45), SEAM, 0.85)
        px(a, K_[0] + 1.0, K_[1] + 3.0, CYAN if near else CYAN_D)
    return {'imp_legs_seam': (crisp(a, outline=False), 12)}


REGIONS = {
    'head': [('Neural Link', cortex), ('Optic Suite', optics), ('Thermal Vision', thermal)],
    'arms': [('Mantis Blades', mantis), ('Smartlink Palm', smartlink), ('Gecko Grip', grip)],
    'torso': [('Dermal Plating', dermal), ('Cardiac Booster', heart), ('Dorsal Jump Jets', jets)],
    'legs': [('Leg Actuators: braces', legs), ('Leg Actuators: under the skin', legs_seam)],
}


def all_implants(b):
    out = {}
    for reg in REGIONS.values():
        for _, fn in reg:
            out.update(fn(b))
    return out
