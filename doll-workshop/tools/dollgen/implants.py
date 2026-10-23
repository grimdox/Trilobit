"""Visible implants: hardware on every body part, built like garments (solids on the skeleton), coloured by the
palette's METAL (chrome), POLY (graphite plates), SYNTH (prosthetic shell), GLOW / GLOW2 (lights) and LENS.

Every implant names its slot of the body (head, eyes, torso, back, arm_r, arm_l, hand_r, hand_l, leg_r, leg_l) so the
creator and the random generator never fit two that fight for the same place, and whether it shows over clothes.
Full prosthetic limbs are shells over the limb's own solids, with joint rings, panel seams and a light at the joint.
Game ids (DollSpec.IMPLANT_LAYER): cortex, optics, thermal, jets, reflex, synapse, dermal, mantis, legs, smartlink,
heart, grip map onto entries here (GAME).
"""
import math

import numpy as np

from sdf import v, norm, INTERSECT, SUBTRACT, copy_shell
import materials as M
from anatomy import _bone_axes, SIDE, arm_layer, head_points
from garments import F, shell

IMPLANTS = {}


def imp(id, name, slots, builder, over=False, side=None):
    IMPLANTS[id] = dict(id=id, name=name, slots=list(slots), builder=builder, over=over, side=side)


def _seam_ring(sc, g, a, b, frac, r, lay, mat=M.DARK):
    """a thin dark ring around a limb at `frac` (a panel joint)"""
    c = a + (b - a) * frac
    ax = _bone_axes(a, b, v(1, 0, 0))
    sc.torus(c, r, 0.32, np.stack([ax[0], ax[1], ax[2]]), g, mat, lay, 'seam')


# ------------------------------------------------------------------------------------------------ limbs
def cyber_arm(s):
    def build(sc, sk):
        f = F(sk)
        b, J = f.b, f.J
        lay = arm_layer(s, sk.pose, 'arm')
        hlay = arm_layer(s, sk.pose, 'hand')
        S, E, Wr = J['sh_' + s], J['elbow_' + s], J['wrist_' + s]
        g = sc.group('carm_' + s, 0.5, parent=None)
        shell(sc, f, {'upper_arm', 'deltoid', 'biceps', 'triceps', 'forearm', 'forearm_m'}, g, M.SYNTH, 0.12, layer=lay, k=1.0,
              groups={'arm_' + s, 'fore_' + s})
        gh = sc.group('chand_' + s, 0.3, parent='carm_' + s)
        shell(sc, f, {'palm', 'knuckles', 'thumb', 'wrist'}, gh, M.POLY, 0.1, layer=hlay, k=0.4, groups={'hand_' + s})
        gj = sc.group('cjoint_' + s, 0.0)
        ax = _bone_axes(E, Wr, v(1, 0, 0))
        sc.ellipsoid(E, (b['fa'][0] * 0.85, b['fa'][0] * 0.85, b['fa'][0] * 0.85), ax, gj, M.METAL, lay, 'elbow')
        sc.ellipsoid(E + norm(np.cross(ax[1], v(0, 1, 0))) * 0.0 + ax[2] * (b['fa'][0] * 0.7), (0.55, 0.55, 0.4), ax, gj, M.GLOW, lay, 'light')
        gs = sc.group('cseam_' + s, 0.0)
        for (a0, a1, fr, r) in ((S, E, 0.55, b['ua'][1] + 0.1), (E, Wr, 0.45, b['fa'][0] * 0.82 + 0.05), (E, Wr, 0.92, b['fa'][1] + 0.1)):
            _seam_ring(sc, gs, a0, a1, fr, r, lay)
        return []
    return build


def cyber_leg(s):
    def build(sc, sk):
        f = F(sk)
        b, J = f.b, f.J
        Hj, K, A = J['hip_' + s], J['knee_' + s], J['ankle_' + s]
        g = sc.group('cleg_' + s, 0.5, parent=None)
        shell(sc, f, {'thigh', 'quad', 'kneecap', 'shin', 'calf'}, g, M.SYNTH, 0.12, layer='body', k=1.2, groups={'leg_' + s, 'shin_' + s})
        gf = sc.group('cfoot_' + s, 0.3, parent='cleg_' + s)
        shell(sc, f, {'heel', 'foot', 'toes', 'ankle'}, gf, M.POLY, 0.1, layer='body', k=0.6, groups={'foot_' + s})
        gj = sc.group('cknee_' + s, 0.0)
        ax = _bone_axes(K, A, v(1, 0, 0))
        sc.ellipsoid(K + ax[2] * 0.6, (b['cf'][0] * 0.9, b['cf'][0] * 0.8, b['cf'][0] * 0.8), ax, gj, M.METAL, 'body', 'knee')
        sc.ellipsoid(K + ax[2] * (b['cf'][0] * 0.9 + 0.5), (0.55, 0.5, 0.4), ax, gj, M.GLOW, 'body', 'light')
        gs = sc.group('clseam_' + s, 0.0)
        _seam_ring(sc, gs, Hj, K, 0.35, b['th'][0] * 0.95 + 0.1, 'body')
        _seam_ring(sc, gs, K, A, 0.55, b['cf'][0] * 0.8 + 0.1, 'body')
        return []
    return build


def mantis(sc, sk):
    """forearm blade housings, folded: a graphite rail along the outside of each forearm, the blade's back edge showing"""
    f = F(sk)
    b, J = f.b, f.J
    for s, sg in SIDE.items():
        E, Wr = J['elbow_' + s], J['wrist_' + s]
        lay = arm_layer(s, sk.pose, 'arm')
        ax = _bone_axes(E, Wr, J['sh_' + s] - J['neck'])
        out = ax[0]
        g = sc.group('mantis_' + s, 0.4, parent=None)
        r = b['fa'][0]
        p0 = E + (Wr - E) * 0.08 + out * (r * 1.0)
        p1 = E + (Wr - E) * 0.86 + out * (b['fa'][1] * 1.05)
        sc.box((p0 + p1) / 2, (1.2, np.linalg.norm(p1 - p0) * 0.5, 1.5), ax, 0.5, g, M.POLY, lay, 'housing')
        # the folded blade lies along the housing and its tip juts back past the elbow
        sc.cone(p1 + out * 1.2, p0 + out * 1.4 - (Wr - E) * 0.32, 0.62, 0.25, g, M.METAL, lay, 'blade', k=0.15)
        sc.ellipsoid((p0 + p1) / 2 + out * 0.2 + ax[2] * 1.4, (0.6, 0.9, 0.45), ax, g, M.GLOW, lay, 'light')
    return []


def smartlink(sc, sk):
    """a chrome port on the back of the near hand, a lit trace up the forearm"""
    f = F(sk)
    b, J = f.b, f.J
    E, Wr = J['elbow_r'], J['wrist_r']
    fd, gd = J['fist_r'], J['grip_r']
    side = norm(np.cross(gd, fd))
    g = sc.group('smart', 0.0)
    c = Wr + fd * (b['hand'][1] * 0.8) + side * (b['hand'][2] + 0.15)
    sc.box(c, (1.1, 1.1, 0.45), np.stack([gd, fd, side]), 0.3, g, M.METAL, arm_layer('r', sk.pose, 'hand'), 'port')
    sc.ellipsoid(c + side * 0.4, (0.6, 0.6, 0.3), np.stack([gd, fd, side]), g, M.GLOW, arm_layer('r', sk.pose, 'hand'), 'light')
    ax = _bone_axes(E, Wr, J['sh_r'] - J['neck'])
    gt = sc.group('smart_t', 0.0)
    for fr in (0.3, 0.55, 0.8):
        p = E + (Wr - E) * fr + ax[2] * (b['fa'][0] * 0.95 - 0.3 * fr)
        sc.ellipsoid(p, (0.55, 0.9, 0.35), ax, gt, M.GLOW, arm_layer('r', sk.pose, 'arm'), 'trace')
    return []


def grip(sc, sk):
    """gecko pads across the fingers of both fists"""
    f = F(sk)
    b, J = f.b, f.J
    for s in ('r', 'l'):
        Wr, fd, gd = J['wrist_' + s], J['fist_' + s], J['grip_' + s]
        side = norm(np.cross(gd, fd))
        g = sc.group('gecko_' + s, 0.0)
        hx, hy, hz = b['hand']
        c = Wr + fd * (hy * 1.45)
        lay = arm_layer(s, sk.pose, 'hand')
        sc.box(c, (hx * 1.08, 0.75, hz * 1.08), np.stack([gd, fd, side]), 0.35, g, M.POLY, lay, 'pad')
        sc.ellipsoid(c + side * (hz * 0.9), (hx * 0.7, 0.35, 0.3), np.stack([gd, fd, side]), g, M.GLOW, lay, 'light')
    return []


def shoulder_mount(sc, sk):
    """a chrome socket plate over the near shoulder (where a weapon mount or a prosthetic joins)"""
    f = F(sk)
    b, J = f.b, f.J
    S = J['sh_r']
    up = norm(S - J['neck'])
    ax = _bone_axes(S, J['elbow_r'], up)
    g = sc.group('smount', 0.4)
    sc.ellipsoid(S + up * 1.0 + v(0, 1.0, 0), (b['ua'][0] + 0.9, 1.6, b['ua'][0] + 0.9), ax, g, M.METAL, arm_layer('r', sk.pose, 'arm'), 'mount')
    sc.ellipsoid(S + up * 1.0 + v(0, 2.2, 0.6), (0.6, 0.5, 0.5), ax, g, M.GLOW, arm_layer('r', sk.pose, 'arm'), 'light')
    return []


def knee_actuator(sc, sk):
    f = F(sk)
    b, J = f.b, f.J
    for s, sg in SIDE.items():
        Hj, K, A = J['hip_' + s], J['knee_' + s], J['ankle_' + s]
        ax = _bone_axes(K, A, f.Rh @ v(sg, 0, 0))
        g = sc.group('kact_' + s, 0.3, parent=None)
        o = ax[0] * (b['cf'][0] * 0.95) * 1.0
        sc.ellipsoid(K + o, (1.7, 1.7, 1.5), ax, g, M.METAL, 'body', 'disc')
        sc.cone(K + o + (Hj - K) * 0.35, K + o + (A - K) * 0.5, 0.85, 0.7, g, M.POLY, 'body', 'rod', k=0.3)
        sc.ellipsoid(K + o + ax[0] * 1.2, (0.6, 0.6, 0.45), ax, g, M.GLOW, 'body', 'light')
    return []


def calf_pistons(sc, sk):
    f = F(sk)
    b, J = f.b, f.J
    for s, sg in SIDE.items():
        K, A = J['knee_' + s], J['ankle_' + s]
        ax = _bone_axes(K, A, f.Rh @ v(sg, 0, 0))
        g = sc.group('cpist_' + s, 0.2, parent=None)
        back = -ax[2] * (b['cf'][0] * 0.8)
        side = ax[0] * (b['cf'][0] * 0.7)
        sc.cone(K + (A - K) * 0.12 + back + side, A + (K - A) * 0.12 + back * 0.7 + side, 0.75, 0.6, g, M.METAL, 'body', 'piston', k=0.2)
        sc.cone(K + (A - K) * 0.12 + back * 1.2 + side, K + (A - K) * 0.55 + back * 1.15 + side, 1.0, 1.0, g, M.POLY, 'body', 'sleeve', k=0.2)
        sc.ellipsoid(K + (A - K) * 0.55 + back * 1.15 + side * 1.3, (0.5, 0.5, 0.5), ax, g, M.GLOW, 'body', 'light')
    return []


# ------------------------------------------------------------------------------------------------ torso and back
def heart(sc, sk):
    f = F(sk)
    b = f.b
    g = sc.group('heart', 0.0)
    ca = f.chest_axes()
    c = f.CP(-b['rib'][0] * 0.3, b['chest'] + 0.8, b['rib'][2] + 0.25 + (1.4 * b['bust'] if b.fem else 0.0))
    sc.torus(c, 1.35, 0.55, np.stack([ca[0], ca[2], ca[1]]), g, M.METAL, 'body', 'ring')
    sc.ellipsoid(c, (0.95, 0.95, 0.5), ca, g, M.GLOW, 'body', 'core')
    return []


def dermal(sc, sk):
    """subdermal plates: a thin graphite shell over chest and stomach split by seams"""
    f = F(sk)
    b = f.b
    g = sc.group('dermal', 0.0)
    shell(sc, f, {'rib', 'abd', 'pec', 'shelf', 'bust'}, g, M.POLY, 0.08, layer='body', k=1.2, groups={'torso'})
    sc.plane(f.CP(0, b['waist'] - 2.4, 0), f.Rs @ v(0, -1, 0), g, op=INTERSECT, k=0.3)
    sc.plane(f.CP(0, b['shoulder'] - 1.2, 0), f.Rs @ v(0, 1, 0), g, op=INTERSECT, k=0.3)
    marks = []
    for y in (b['chest'] + 2.4, b['chest'] - 1.4, b['waist'] + 1.0):
        marks.append(dict(pts=[f.CP(-b['rib'][0], y, b['rib'][2] - 1.0), f.CP(0, y - 0.3, b['rib'][2] + 0.8), f.CP(b['rib'][0], y, b['rib'][2] - 1.0)],
                          d=-2, groups={'dermal'}, mats=(M.POLY,), tol=4.0, floor=0))
    marks.append(dict(pts=[f.CP(0, b['shoulder'] - 1.4, b['rib'][2] + 0.6), f.CP(0, b['waist'] - 2.2, b['abd'][2] + 0.5)], d=-2, groups={'dermal'},
                      mats=(M.POLY,), tol=4.0, floor=0))
    return marks


def spine(sc, sk):
    """reflex wiring: a row of chrome ports down the back of the neck"""
    f = F(sk)
    b, J = f.b, f.J
    g = sc.group('spine', 0.0)
    for i in range(3):
        p = f.CP(b['neck_r'][0] * 0.75, b['neck'] + 1.4 - i * 1.6, -b['neck_r'][0] * 0.5 - i * 0.4)
        sc.box(p, (0.6, 0.6, 0.8), f.chest_axes(), 0.25, g, M.METAL, 'body', 'port')
        sc.ellipsoid(p + f.Rs @ v(0.55, 0, 0), (0.35, 0.35, 0.4), f.chest_axes(), g, M.GLOW, 'body', 'light')
    return []


def jets(sc, sk):
    """dorsal jump jets: two nozzles on the back, over the shoulders"""
    f = F(sk)
    b = f.b
    for s, sg in SIDE.items():
        g = sc.group('jet_' + s, 0.4, parent=None)
        base = f.CP(sg * (b['sh_x'] - 3.2), b['shoulder'] - 3.0, -b['rib'][2] - 1.2)
        top = f.CP(sg * (b['sh_x'] - 1.4), b['shoulder'] + 6.5, -b['rib'][2] - 2.2)
        sc.cone(base, top, 2.4, 1.9, g, M.POLY, 'body', 'pod')
        sc.ellipsoid(top + f.up() * 0.5, (1.7, 0.8, 1.7), f.chest_axes(), g, M.METAL, 'body', 'nozzle', k=0.3)
        sc.ellipsoid(top + f.up() * 1.0, (1.1, 0.45, 1.1), f.chest_axes(), g, M.GLOW, 'body', 'flame')
    return []


# ------------------------------------------------------------------------------------------------ head
def _hp(sk):
    return head_points(sk)


def optic(which='r', mat=M.LENS, glow=M.GLOW, twin=False):
    def build(sc, sk):
        f = F(sk)
        hp = _hp(sk)
        ha = f.head_axes()
        rx = f.b['head_r'][0]
        g = sc.group('optic', 0.0)
        for s in (('r', 'l') if twin else (which,)):
            c = hp['eye_' + s] + f.Rhd @ v(0, 0, 0.35)
            sc.torus(c, 0.95, 0.42, np.stack([ha[0], ha[2], ha[1]]), g, M.POLY if twin else M.METAL, 'head', 'rim')
            sc.ellipsoid(c + f.Rhd @ v(0, 0, 0.1), (0.75, 0.75, 0.3), ha, g, glow, 'head', 'lens')
        if not twin:
            # the ranging arm runs back to the ear
            sc.cone(hp['eye_' + which] + f.Rhd @ v(0.9 if which == 'r' else -0.9, 0, 0), hp['ear_' + which] + f.Rhd @ v(0, 0.3, 0.2),
                    0.32, 0.3, g, M.METAL, 'head', 'arm', k=0.2)
        return []
    return build


def cortex(sc, sk):
    """temple jacks: two ports on the near temple"""
    f = F(sk)
    hp = _hp(sk)
    ha = f.head_axes()
    g = sc.group('cortex', 0.0)
    for dy in (0.6, -1.0):
        c = hp['temple_r'] + f.Rhd @ v(0.5, dy, -1.0)
        sc.box(c, (0.7, 0.65, 0.8), ha, 0.2, g, M.METAL, 'head', 'jack')
        sc.ellipsoid(c + f.Rhd @ v(0.55, 0, 0.1), (0.35, 0.4, 0.4), ha, g, M.GLOW, 'head', 'light')
    return []


def neural_plate(sc, sk):
    f = F(sk)
    rx, ry, rz = f.b['head_r']
    ha = f.head_axes()
    g = sc.group('nplate', 0.0)
    sc.ellipsoid(f.HP(0.2, 0.9, -0.5), (rx + 0.25, ry * 0.92 + 0.25, rz + 0.25), ha, g, M.METAL, 'head', 'plate')
    sc.plane(f.HP(rx * 0.25, 0, 0), f.Rhd @ v(-1, 0, 0.2), g, op=INTERSECT, k=0.2)
    sc.plane(f.HP(0, 0.2, 0), f.Rhd @ v(0, -1, 0), g, op=INTERSECT, k=0.2)
    sc.plane(f.HP(0, 0, rz * 0.3), f.Rhd @ v(0, 0, 1), g, op=INTERSECT, k=0.2)
    return []


def jaw(sc, sk):
    f = F(sk)
    rx, ry, rz = f.b['head_r']
    ha = f.head_axes()
    g = sc.group('jawp', 0.0)
    sc.ellipsoid(f.HP(0, -ry * 0.72, 1.4), (rx * 0.62 * 0.95 + 0.35, ry * 0.36 + 0.3, rz * 0.62 + 0.35), ha, g, M.METAL, 'head', 'jaw')
    sc.plane(f.HP(0, -ry * 0.58, 0), f.Rhd @ v(0, 1, 0), g, op=INTERSECT, k=0.2)
    gl = sc.group('jawl', 0.0)
    sc.ellipsoid(f.HP(rx * 0.55, -ry * 0.68, rz * 0.6), (0.35, 0.3, 0.3), ha, gl, M.GLOW, 'head', 'light')
    return []


def antenna(sc, sk):
    f = F(sk)
    hp = _hp(sk)
    g = sc.group('ant', 0.0)
    e = hp['ear_r'] + f.Rhd @ v(0.4, 0.4, -0.3)
    sc.box(e, (0.6, 1.1, 0.9), f.head_axes(), 0.3, g, M.POLY, 'head', 'base')
    sc.cone(e, e + f.Rhd @ v(0.4, 6.0, -1.6), 0.55, 0.3, g, M.METAL, 'head', 'mast', k=0.2)
    sc.ellipsoid(e + f.Rhd @ v(0.4, 6.2, -1.65), (0.55, 0.55, 0.55), f.head_axes(), g, M.GLOW2, 'head', 'tip')
    return []


imp('cyberarm_r', 'Prosthetic arm (near)', ['arm_r', 'hand_r'], cyber_arm('r'))
imp('cyberarm_l', 'Prosthetic arm (far)', ['arm_l', 'hand_l'], cyber_arm('l'))
imp('cyberleg_r', 'Prosthetic leg (near)', ['leg_r'], cyber_leg('r'))
imp('cyberleg_l', 'Prosthetic leg (far)', ['leg_l'], cyber_leg('l'))
imp('mantis', 'Mantis blades', ['forearms'], mantis, over=True)
imp('smartlink', 'Smartlink palm', ['hand_r'], smartlink, over=True)
imp('grip', 'Gecko grip', ['hand_r', 'hand_l'], grip, over=True)
imp('shoulder_mount', 'Shoulder mount', ['shoulder_r'], shoulder_mount, over=True)
imp('knee_actuator', 'Knee actuators', ['knees'], knee_actuator, over=True)
imp('calf_pistons', 'Calf pistons', ['calves'], calf_pistons)
imp('heart', 'Cardiac booster', ['chest'], heart)
imp('dermal', 'Dermal plating', ['chest'], dermal)
imp('spine', 'Reflex wiring', ['neck'], spine, over=True)
imp('jets', 'Dorsal jump jets', ['back'], jets, over=True)
imp('optic_r', 'Optic (near eye)', ['eye_r'], optic('r'), over=True)
imp('optic_l', 'Optic (far eye)', ['eye_l'], optic('l'), over=True)
imp('optic_twin', 'Twin optics', ['eye_r', 'eye_l'], optic(twin=True), over=True)
imp('thermal', 'Thermal lenses', ['eye_r', 'eye_l'], optic(twin=True, glow=M.GLOW2), over=True)
imp('cortex', 'Temple jacks', ['temple'], cortex, over=True)
imp('neural_plate', 'Skull plate', ['skull'], neural_plate, over=True)
imp('jaw', 'Jaw plate', ['jaw'], jaw, over=True)
imp('antenna', 'Antenna', ['ear'], antenna, over=True)

GAME = {'cortex': ['cortex'], 'optics': ['optic_r'], 'thermal': ['thermal'], 'jets': ['jets'], 'reflex': ['spine'], 'synapse': ['spine', 'neural_plate'],
        'dermal': ['dermal'], 'mantis': ['mantis'], 'legs': ['cyberleg_r', 'cyberleg_l'], 'smartlink': ['smartlink'], 'heart': ['heart'],
        'grip': ['grip']}


OVER_HAIR = {'temple', 'skull', 'ear'}


def slots_for(spec, prim_layer_map=None):
    """(group, sub) per prim layer for an implant: on the skin (sub 1) or over the clothes (sub 18); skull hardware sits
    over the hair (head 2.5), eye hardware over the face (head 1)"""
    sub = 18 if spec['over'] else 1
    head = ('head', 2.5) if OVER_HAIR & set(spec['slots']) else ('head', 1)
    return ({'body': ('body', sub), 'far': ('far', sub), 'near': ('near', sub), 'hands': ('hands', sub), 'head': head},
            {'body': ('back', 2)} if 'back' in spec['slots'] or 'neck' in spec['slots'] else {})
