"""Body frames and the skeleton.

A BodyDef holds proportions (joint heights, widths, bone lengths, limb radii, muscle and bust amounts).  A Pose holds
targets: pelvis offset and turn, spine lean and twist, head turn, hand targets with fist orientation, foot targets.
Skeleton.solve(body, pose) places every joint in character space (X = the character's right, Y = up, Z = forward),
using two-bone IK for arms and legs with pole hints so elbows and knees always bend the anatomical way.

The six frames share one skeleton layout, so every pose, garment, implant and held item works on all of them.
"""
import math

import numpy as np

from sdf import v, norm, rot_axis


class BodyDef:
    def __init__(self, key, sex, size, **p):
        self.key, self.sex, self.size = key, sex, size
        self.fem = sex == 'f'
        d = dict(
            # heights (standing, units = sprite pixels at LOD 64)
            ankle=3.0, knee=15.2, hipj=27.7, pelvis=29.1, waist=34.8, chest=40.6, shoulder=45.5, neck=47.4,
            head_c=53.8, head_r=(4.7, 5.0, 5.0), jaw=1.0,
            # half widths and depths
            sh_x=8.8, hip_x=3.5, rib=(6.8, 6.2, 4.5), abd=(5.4, 4.8, 3.8), pel=(6.0, 3.6, 4.1),
            waist_pinch=1.0,
            # limbs: radii at both ends, bone lengths
            ua=(2.45, 2.0), fa=(2.15, 1.4), th=(3.55, 2.45), cf=(2.6, 1.35), neck_r=(2.3, 2.1),
            ua_len=10.0, fa_len=9.0, hand=(1.55, 1.85, 1.3), foot=6.2,
            # anatomy
            muscle=1.0, bust=0.0, glute=1.0, trap=1.0, lean=0.0,
        )
        d.update(p)
        self.p = d
        self.th_len = d['hipj'] - d['knee']
        self.cf_len = d['knee'] - d['ankle']
        self.height = d['head_c'] + d['head_r'][1]

    def __getitem__(self, k):
        return self.p[k]


def _scaled(base, k, **over):
    """a body scaled uniformly by k from a base dict, with overrides"""
    out = {}
    for name, val in base.items():
        if isinstance(val, tuple):
            out[name] = tuple(x * k for x in val)
        elif isinstance(val, (int, float)) and name not in ('muscle', 'bust', 'glute', 'trap', 'jaw', 'waist_pinch', 'lean'):
            out[name] = val * k
        else:
            out[name] = val
    out.update(over)
    return out


_M = dict(BodyDef('m_m', 'm', 'm').p)
_M.update(dict(sh_x=9.6, hip_x=3.9, rib=(8.2, 6.6, 5.0), abd=(6.6, 5.0, 4.3), pel=(7.2, 3.9, 4.5),
               ua=(3.0, 2.45), fa=(2.65, 1.85), th=(4.0, 2.85), cf=(2.95, 1.65), neck_r=(2.7, 2.5),
               head_r=(5.1, 5.5, 5.3), hand=(1.75, 2.05, 1.45), foot=7.4, muscle=1.0))
_F = dict(_M)
_F.update(dict(sh_x=8.3, hip_x=3.9, rib=(6.8, 6.2, 4.4), abd=(5.4, 4.8, 3.8), pel=(7.5, 4.2, 4.8), waist_pinch=0.84,
               ua=(2.35, 2.0), fa=(2.1, 1.45), th=(3.95, 2.6), cf=(2.75, 1.45), neck_r=(2.1, 1.95), hand=(1.5, 1.8, 1.25),
               head_r=(4.85, 5.3, 5.05), jaw=0.8, muscle=0.45, bust=1.0, glute=1.25, trap=0.55, foot=6.6))

BODIES = {
    # male: the small frame is the wiry netrunner, the medium the approved athletic build, the large the heavy enforcer
    'm_s': BodyDef('m_s', 'm', 's', **_scaled(_M, 0.97, sh_x=8.6, rib=(7.0, 6.2, 4.4), abd=(5.6, 4.8, 3.8), pel=(6.4, 3.7, 4.1),
                                              ua=(2.45, 2.05), fa=(2.2, 1.55), th=(3.45, 2.45), cf=(2.55, 1.45), neck_r=(2.25, 2.1),
                                              hand=(1.6, 1.9, 1.35), muscle=0.6, trap=0.6, lean=0.05)),
    'm_m': BodyDef('m_m', 'm', 'm', **_M),
    'm_l': BodyDef('m_l', 'm', 'l', **_scaled(_M, 1.03, sh_x=11.0, rib=(9.6, 7.2, 6.0), abd=(7.8, 5.6, 5.4), pel=(7.8, 4.1, 5.0),
                                              ua=(3.6, 2.95), fa=(3.15, 2.2), th=(4.6, 3.3), cf=(3.4, 1.9), neck_r=(3.4, 3.2),
                                              hand=(2.05, 2.3, 1.7), muscle=1.4, trap=1.7, head_r=(5.25, 5.55, 5.4), jaw=1.25, foot=7.8)),
    # female: petite, athletic (the approved direction), tall and strong
    'f_s': BodyDef('f_s', 'f', 's', **_scaled(_F, 0.94, sh_x=7.8, rib=(6.2, 5.9, 4.1), pel=(7.0, 4.0, 4.5), ua=(2.1, 1.8), fa=(1.9, 1.3),
                                              th=(3.6, 2.4), cf=(2.5, 1.35), bust=0.8, muscle=0.25, head_r=(4.8, 5.25, 5.0))),
    'f_m': BodyDef('f_m', 'f', 'm', **_scaled(_F, 0.97)),
    'f_l': BodyDef('f_l', 'f', 'l', **_scaled(_F, 1.0, sh_x=9.2, rib=(7.6, 6.6, 5.0), abd=(6.2, 5.1, 4.3), pel=(7.9, 4.3, 5.1),
                                              ua=(2.8, 2.35), fa=(2.5, 1.7), th=(4.4, 2.95), cf=(3.1, 1.65), neck_r=(2.45, 2.3),
                                              hand=(1.65, 1.95, 1.4), muscle=0.9, bust=1.1, trap=0.95)),
}
BODY_ORDER = ['m_s', 'm_m', 'm_l', 'f_s', 'f_m', 'f_l']
BODY_NAMES = {'m_s': 'Male, small', 'm_m': 'Male, medium', 'm_l': 'Male, large',
              'f_s': 'Female, small', 'f_m': 'Female, medium', 'f_l': 'Female, large'}


# ------------------------------------------------------------------------------------------------ pose
class Pose:
    """targets in character space, relative to the standing rest skeleton of each body (scaled by body height)"""

    def __init__(self, **p):
        d = dict(
            root=(0.0, 0.0, 0.0),        # pelvis offset (x, y, z); y negative = crouch
            hip_turn=0.0, hip_tilt=0.0,  # radians: twist about Y, side tilt about Z
            lean=0.0, twist=0.0, side=0.0,   # spine: forward lean (about X), chest twist (about Y), side bend
            head=(0.0, 0.0, 0.0),        # head yaw, pitch (down +), roll
            breath=0.0,                  # chest rise in units
            # hands: target (relative to the shoulder of that side), fist axis (direction the knuckles point), elbow pole
            hand_r=(0.0, -16.0, 2.0), hand_l=(0.0, -16.0, 2.0),
            fist_r=(0.0, -1.0, 0.3), fist_l=(0.0, -1.0, 0.3),
            grip_r=(0.0, 0.0, 1.0), grip_l=(0.0, 0.0, 1.0),    # the axis a held haft runs through the fist
            elbow_r=(0.6, 0.0, -1.0), elbow_l=(-0.6, 0.0, -1.0),
            # feet: ground position (x, z), lift (y), heel raise (radians), toe yaw
            foot_r=(4.4, 0.0, 0.6), foot_l=(-4.4, 0.0, -0.4),
            heel_r=0.0, heel_l=0.0, toe_r=0.15, toe_l=-0.05,
            knee_r=(0.15, 0.0, 1.0), knee_l=(-0.15, 0.0, 1.0),
            hands_front=('r',),          # which hands are drawn over held items (the far hand only when it holds)
        )
        d.update(p)
        self.p = d

    def __getitem__(self, k):
        return self.p[k]

    def with_(self, **p):
        d = dict(self.p)
        d.update(p)
        return Pose(**d)


def two_bone(a, target, la, lb, pole):
    """joint position for a two-bone chain from a toward target, bending toward `pole` (character space)"""
    d = target - a
    dist = np.linalg.norm(d)
    dist_c = min(max(dist, abs(la - lb) + 1e-3), la + lb - 1e-3)
    dn = d / max(dist, 1e-6)
    cos_a = (la * la + dist_c * dist_c - lb * lb) / (2 * la * dist_c)
    cos_a = max(-1.0, min(1.0, cos_a))
    sin_a = math.sqrt(1 - cos_a * cos_a)
    p = np.asarray(pole, dtype=np.float64)
    p = p - dn * np.dot(p, dn)
    if np.linalg.norm(p) < 1e-6:
        p = np.array([0.0, 0.0, 1.0]) - dn * dn[2]
    p = norm(p)
    joint = a + dn * (cos_a * la) + p * (sin_a * la)
    end = a + dn * dist_c
    return joint, end


HEAD_TURN = 0.25


class Skeleton:
    """joints in character space for one body in one pose"""

    def __init__(self, body, pose):
        self.body, self.pose = body, pose
        b, P = body, pose
        J = {}
        root = v(*P['root'])
        # pelvis frame: twist about Y, tilt about Z
        Rh = rot_axis((0, 1, 0), P['hip_turn']) @ rot_axis((0, 0, 1), P['hip_tilt'])
        pelvis = v(0, b['pelvis'], 0) + root
        J['pelvis'] = pelvis
        J['R_pelvis'] = Rh
        J['hip_r'] = pelvis + Rh @ v(b['hip_x'], b['hipj'] - b['pelvis'], 0.2)
        J['hip_l'] = pelvis + Rh @ v(-b['hip_x'], b['hipj'] - b['pelvis'], 0.2)
        # spine: lean forward about X (positive bends the chest forward), then twist and side bend
        Rs = Rh @ rot_axis((0, 1, 0), P['twist']) @ rot_axis((1, 0, 0), P['lean'] + b['lean']) @ rot_axis((0, 0, 1), P['side'])
        J['R_chest'] = Rs
        waist = pelvis + Rh @ v(0, b['waist'] - b['pelvis'], 0)
        J['waist'] = waist
        J['chest'] = waist + Rs @ v(0, b['chest'] - b['waist'] + P['breath'] * 0.5, 0.0)
        J['sh_r'] = waist + Rs @ v(b['sh_x'], b['shoulder'] - b['waist'] + P['breath'], -0.4)
        J['sh_l'] = waist + Rs @ v(-b['sh_x'], b['shoulder'] - b['waist'] + P['breath'], -0.4)
        J['neck'] = waist + Rs @ v(0, b['neck'] - b['waist'] + P['breath'], -0.6)
        hy, hp, hr = P['head']
        # the head turns a little further toward the viewer than the body (the face reads better; a pixel-art cheat)
        Rhd = Rs @ rot_axis((0, 1, 0), hy + HEAD_TURN) @ rot_axis((1, 0, 0), hp) @ rot_axis((0, 0, 1), hr)
        J['R_head'] = Rhd
        J['head'] = J['neck'] + Rhd @ v(0, b['head_c'] - b['neck'], 0.3)
        # arms (hand targets are given relative to each shoulder, in the chest frame)
        for s in ('r', 'l'):
            S = J['sh_' + s]
            pole = Rs @ v(*P['elbow_' + s])
            if P.p.get('abs_' + s) is not None:
                # absolute: the fist centre, knuckle direction and haft axis in character space (weapon holds)
                fc, fd, gd = (v(*x) for x in P['abs_' + s])
                fd = norm(fd)
                gd = norm(gd - fd * np.dot(gd, fd))
                T = fc - fd * (b['hand'][1] * 0.95)
                J['fist_' + s], J['grip_' + s] = fd, gd
            else:
                T = S + Rs @ v(*P['hand_' + s])
                J['fist_' + s] = norm(Rs @ v(*P['fist_' + s]))
                J['grip_' + s] = norm(Rs @ v(*P['grip_' + s]))
            E, W = two_bone(S, T, b['ua_len'], b['fa_len'], pole)
            J['elbow_' + s], J['wrist_' + s] = E, W
            J['reach_' + s] = float(np.linalg.norm(T - S) - (b['ua_len'] + b['fa_len']))
        # legs: feet on the ground (x, z), y lift
        for s in ('r', 'l'):
            fx, fy, fz = P['foot_' + s]
            heel = P['heel_' + s]
            ank = v(fx, b['ankle'] + fy, fz)
            Hj = J['hip_' + s]
            pole = Rh @ v(*P['knee_' + s])
            K, A = two_bone(Hj, ank, b.th_len, b.cf_len, pole)
            J['knee_' + s], J['ankle_' + s] = K, A
            yaw = P['toe_' + s] + P['hip_turn'] * 0.5
            J['foot_dir_' + s] = norm(v(math.sin(yaw), -math.sin(heel), math.cos(yaw)))
            J['heel_' + s] = heel
        # whole-body roll about the character's forward axis through a pivot on the ground (falling, lying)
        roll = P.p.get('roll', 0.0)
        if abs(roll) > 1e-6:
            piv = v(*P.p.get('roll_pivot', (0.0, 0.0, 0.0)))
            Rr = rot_axis((0, 0, 1), roll)
            for k, val in list(J.items()):
                if k.startswith('R_'):
                    J[k] = Rr @ val
                elif isinstance(val, np.ndarray) and val.shape == (3,):
                    if k.startswith(('fist_', 'grip_', 'foot_dir_')):
                        J[k] = Rr @ val
                    else:
                        J[k] = piv + Rr @ (val - piv)
        self.J = J

    def __getitem__(self, k):
        return self.J[k]
