"""Poses and animations.

Six grips, each with the same animation set, plus a shared fall:
  grips       unarmed, melee1 (one-handed blade or club, held upright), melee2 (two-handed, both hands on the haft),
              pistol (low ready, one hand), rifle (long gun across the body, both hands), tool (carried in the near hand)
  animations  idle (4 frames, breathing and weight), walk (8), act (the grip's attack or use, 4), hit (2), down (4)

Every pose is a function of the body, so hand and foot targets scale with each frame.  A held item is placed by a grip
point and an axis in character space (`held`); the near fist closes on the grip and, for two-handed holds, the far
fist on the haft further along the axis.  Durations are in milliseconds; `event` marks the frame where a strike lands
or a shot fires.
"""
import math

import numpy as np

from body import Pose
from sdf import v, norm

GRIPS = ['unarmed', 'melee1', 'melee2', 'pistol', 'rifle', 'tool']
GRIP_NAMES = {'unarmed': 'Unarmed', 'melee1': 'One-handed melee', 'melee2': 'Two-handed melee', 'pistol': 'Pistol',
              'rifle': 'Rifle', 'tool': 'Tool'}
ANIMS = {'idle': 4, 'walk': 8, 'act': 4, 'hit': 2}
DOWN = 4
DUR = {'idle': [420, 380, 420, 380], 'walk': [110] * 8, 'act': [140, 90, 160, 180], 'hit': [90, 200], 'down': [120, 140, 180, 1000]}
EVENT = {'act': 1}
LOOP = {'idle': True, 'walk': True, 'act': False, 'hit': False, 'down': False}


# the direction the character aims, strikes and thrusts: 45 degrees to its left-forward, which the camera shows running
# toward screen right (straight ahead, +Z, would point mostly at the viewer and foreshorten to nothing)
AIM = norm(v(-0.7, 0.0, 0.72))
AIM_TWIST = -0.42                      # the torso turns into the aim


def _sh(b, s):
    return v(b['sh_x'] * (1 if s == 'r' else -1), b['shoulder'], -0.4)


def stance(b, wide=1.0, crouch=0.6):
    """the ready stance every grip starts from: feet apart, near foot a little forward, knees soft"""
    hx = b['hip_x']
    return dict(root=(0.0, -crouch, 0.0), foot_r=(hx + 0.9 * wide, 0.0, 1.4 * wide), foot_l=(-hx - 0.7 * wide, 0.0, -1.2 * wide),
                toe_r=0.22, toe_l=-0.12, lean=0.05)


def hold(b, grip, axis, knuckle_hint):
    """fist (centre, knuckle direction, haft axis) holding a haft at `grip` along `axis`"""
    ax = norm(axis)
    kh = np.asarray(knuckle_hint, float)
    kd = norm(kh - ax * np.dot(kh, ax))
    return (tuple(grip), tuple(kd), tuple(ax))


# ------------------------------------------------------------------------------------------------ grip holds
def grip_pose(b, grip, phase='idle', t=0.0):
    """the arms and the held item for one grip at rest (t = breathing phase 0..1)"""
    breath = 0.35 * math.sin(t * 2 * math.pi)
    S_r, S_l = _sh(b, 'r'), _sh(b, 'l')
    arm = b['ua_len'] + b['fa_len']
    d = dict(breath=breath)
    held = None
    if grip == 'unarmed':
        d.update(hand_r=(2.0, -arm * 0.86, 3.2), hand_l=(-2.2, -arm * 0.86, 2.4), fist_r=(0.15, -1, 0.35), fist_l=(-0.15, -1, 0.3),
                 grip_r=(0, 0, 1), grip_l=(0, 0, 1), elbow_r=(0.7, 0, -1), elbow_l=(-0.7, 0, -1), hands_front=('r',))
    elif grip == 'melee1':
        G = S_r + v(-2.0, -arm * 0.66, 8.2)
        ax = norm(v(-0.05, 1.0, 0.18))
        d.update(abs_r=hold(b, G, ax, (0, 0, 1)), elbow_r=(0.9, -0.3, -1),
                 hand_l=(2.6, -arm * 0.48, 7.0), fist_l=(0.4, 0.2, 1), grip_l=(0, 1, 0), elbow_l=(-0.9, -0.4, -1), hands_front=('r',))
        held = dict(grip=G, axis=ax, hands=1)
    elif grip == 'melee2':
        G = v(b['sh_x'] * 0.25, b['waist'] + 0.6, 9.0)
        ax = norm(v(-0.62, 0.7, 0.36))
        G2 = G + ax * (b['hand'][1] * 2.3)
        d.update(abs_r=hold(b, G, ax, (0.3, 0, 1)), abs_l=hold(b, G2, ax, (-0.2, 0, 1)), elbow_r=(1, -0.4, -0.6), elbow_l=(-1, -0.6, -0.4),
                 hands_front=('r', 'l'), twist=0.12)
        held = dict(grip=G, axis=ax, hands=2, support=G2)
    elif grip == 'pistol':
        G = S_r + v(-1.4, -arm * 0.72, 7.4)
        ax = norm(v(0.12, -0.72, 0.68))
        d.update(abs_r=hold(b, G, ax, (0, 0.6, 1)), elbow_r=(0.8, 0, -1), hand_l=(-2.0, -arm * 0.85, 2.8), fist_l=(-0.15, -1, 0.3),
                 grip_l=(0, 0, 1), elbow_l=(-0.7, 0, -1), hands_front=('r',))
        held = dict(grip=G, axis=ax, hands=1)
    elif grip == 'rifle':
        G = S_r + v(-3.0, -arm * 0.64, 5.0)
        ax = norm(v(-0.5, 0.42, 0.76))
        G2 = G + ax * 10.5
        d.update(abs_r=hold(b, G, ax, (0.2, -0.3, 1)), abs_l=hold(b, G2, ax, (0, -1, 0.2)), elbow_r=(1, -0.2, -0.5), elbow_l=(-0.4, -1, 0.2),
                 hands_front=('r', 'l'), twist=0.1)
        held = dict(grip=G, axis=ax, hands=2, support=G2)
    elif grip == 'tool':
        G = S_r + v(-0.6, -arm * 0.82, 4.4)
        ax = norm(v(0.0, -0.3, 1.0))
        d.update(abs_r=hold(b, G, ax, (0, -1, 0)), elbow_r=(0.8, 0, -1), hand_l=(-2.2, -arm * 0.85, 2.6), fist_l=(-0.15, -1, 0.3),
                 grip_l=(0, 0, 1), elbow_l=(-0.7, 0, -1), hands_front=('r',))
        held = dict(grip=G, axis=ax, hands=1)
    return d, held


def _shift_hold(d, held, dv, b):
    """move the held item (and the hands on it) by dv"""
    dv = np.asarray(dv, float)
    out = dict(d)
    for s in ('r', 'l'):
        if out.get('abs_' + s) is not None:
            c, kd, ax = out['abs_' + s]
            out['abs_' + s] = (tuple(np.asarray(c) + dv), kd, ax)
    if held:
        held = dict(held)
        held['grip'] = held['grip'] + dv
        if 'support' in held:
            held['support'] = held['support'] + dv
    return out, held


def _place(b, d, held, G, ax, support_dist=None, knuckle_r=(0, 0, 1), knuckle_l=(0, -1, 0.2)):
    out = dict(d)
    ax = norm(ax)
    out['abs_r'] = hold(b, G, ax, knuckle_r)
    held = dict(held or {})
    held.update(grip=np.asarray(G, float), axis=ax)
    if support_dist is not None:
        G2 = np.asarray(G, float) + ax * support_dist
        out['abs_l'] = hold(b, G2, ax, knuckle_l)
        held['support'] = G2
    return out, held


# ------------------------------------------------------------------------------------------------ animations
def frame(b, grip, anim, i):
    """the Pose and held placement for frame i of an animation"""
    base = stance(b)
    if anim == 'idle':
        t = i / 4.0
        d, held = grip_pose(b, grip, t=t)
        p = dict(base)
        p.update(d)
        p['root'] = (0.0, -0.6 - 0.25 * math.sin(t * 2 * math.pi), 0.0)
        p['hip_tilt'] = 0.025 * math.sin(t * 2 * math.pi)
        p['head'] = (0.0, 0.02 * math.sin(t * 2 * math.pi + 1.0), 0.0)
        p['sway'] = (0.1 * math.sin(t * 2 * math.pi), 0.0, -0.4)
        if held:
            held = dict(held)
            bob = v(0, p['breath'] * 0.5 - 0.25 * math.sin(t * 2 * math.pi), 0)
            p, held = _shift_hold(p, held, bob, b)
        return Pose(**p), held
    if anim == 'walk':
        return walk(b, grip, i)
    if anim == 'act':
        return act(b, grip, i)
    if anim == 'hit':
        d, held = grip_pose(b, grip)
        p = dict(base)
        p.update(d)
        k = [1.0, 0.5][i]
        # the blow snaps the torso back and the head whips; the weapon is thrown up and back; the free hands flinch out
        p['lean'] = -0.34 * k
        p['twist'] = p.get('twist', 0.0) - 0.28 * k
        p['side'] = 0.1 * k
        p['head'] = (0.25 * k, -0.5 * k, 0.18 * k)
        p['root'] = (0.0, -0.6 - 1.2 * k, -2.6 * k)
        p['foot_l'] = (-b['hip_x'] - 0.9, 0.0, -3.4 * k - 1.0)
        p['sway'] = (1.4 * k, 0.6, 1.0)
        if held:
            p, held = _shift_hold(p, held, v(0.8 * k, 2.0 * k, -2.8 * k), b)
        if grip in ('unarmed', 'pistol', 'tool', 'melee1'):
            p['hand_l'] = (-3.5, -arm_len(b) * 0.45, 5.0 * k)
            p['fist_l'] = (-0.4, -0.2, 1)
        if grip == 'unarmed':
            p['hand_r'] = (3.5, -arm_len(b) * 0.45, 5.0 * k)
            p['fist_r'] = (0.4, -0.2, 1)
        return Pose(**p), held
    if anim == 'down':
        return down(b, i)
    raise KeyError(anim)


def arm_len(b):
    return b['ua_len'] + b['fa_len']


def walk(b, grip, i):
    ph = i / 8.0 * 2 * math.pi
    c, s = math.cos(ph), math.sin(ph)
    hx = b['hip_x']
    S = 5.2                      # half stride
    lift = 2.2
    zr, zl = S * c, -S * c
    yr = lift * max(0.0, -s) ** 1.2
    yl = lift * max(0.0, s) ** 1.2
    # the trailing foot rolls onto its toes before it swings
    hr = 0.55 * max(0.0, -c) * (1 if s > -0.2 else 0.4)
    hl = 0.55 * max(0.0, c) * (1 if s < 0.2 else 0.4)
    d, held = grip_pose(b, grip, t=i / 8.0)
    p = dict(stance(b, wide=0.75, crouch=0.4))
    p.update(d)
    p.update(foot_r=(hx + 0.5, yr, zr + 0.6), foot_l=(-hx - 0.5, yl, zl - 0.2), heel_r=hr, heel_l=hl, toe_r=0.12, toe_l=-0.06,
             root=(0.0, -0.4 - 0.75 * abs(c), 0.3 * c), hip_turn=0.14 * c, twist=d.get('twist', 0.0) - 0.16 * c, lean=0.08,
             hip_tilt=0.03 * s, breath=0.0, sway=(0.25 * s, 0.4 * abs(c), -1.2 - 0.4 * abs(s)))
    # arms swing opposite the legs when they are free
    A = 5.6
    if grip in ('unarmed', 'pistol', 'tool', 'melee1'):
        a = arm_len(b)
        p['hand_l'] = (-2.2, -a * 0.84 + 0.6 * abs(c), 2.4 + A * c)
        p['fist_l'] = (-0.1, -1, 0.3 + 0.4 * c)
        if grip == 'unarmed':
            p['hand_r'] = (2.0, -a * 0.84 + 0.6 * abs(c), 3.0 - A * c)
            p['fist_r'] = (0.1, -1, 0.3 - 0.4 * c)
    if held:
        bob = v(0, -0.6 * abs(c) + 0.2, 0.25 * c)
        if grip in ('pistol', 'tool'):
            bob = bob + v(0, 0, -1.4 * c)          # the carrying arm swings a little
        p, held = _shift_hold(p, held, bob, b)
    return Pose(**p), held


def act(b, grip, i):
    """the grip's action: punch, slash, overhead cut, aimed shot, shouldered shot, tool use"""
    base = stance(b, wide=1.15, crouch=1.0)
    d, held = grip_pose(b, grip)
    p = dict(base)
    p.update(d)
    S_r = _sh(b, 'r')
    a = arm_len(b)
    if grip == 'unarmed':
        # guard, wind, cross, recover
        guard_r, guard_l = (-3.2, -a * 0.5, 8.0), (3.0, -a * 0.45, 9.0)
        ext = tuple(AIM * (a * 0.95) + v(-1.0, -a * 0.25, 0))
        R = [guard_r, (-1.0, -a * 0.5, 4.0), ext, guard_r][i]
        p.update(hand_r=R, hand_l=guard_l, fist_r=(-0.2, 0.0, 1), fist_l=(0.2, 0.1, 1), grip_r=(0, 1, 0), grip_l=(0, 1, 0),
                 elbow_r=(1, -0.6, -0.6), elbow_l=(-1, -0.6, -0.6), hands_front=('r', 'l'))
        p['twist'] = [0.0, 0.15, AIM_TWIST * 1.2, 0.0][i]
        p['lean'] = [0.06, 0.02, 0.16, 0.08][i]
        p['root'] = (0.0, -1.0, [0.0, -0.4, 1.2, 0.4][i])
    elif grip == 'melee1':
        poses = [
            (S_r + v(-0.5, 2.0, -1.0), v(0.15, 0.45, -0.88)),          # wound back over the shoulder
            (S_r + AIM * (a * 0.85) + v(0, -a * 0.35, 0), norm(AIM + v(0, -0.15, 0))),      # the cut lands forward
            (S_r + AIM * (a * 0.55) + v(-4.0, -a * 0.75, 0), v(-0.75, -0.6, 0.25)),       # follow through low across
            (S_r + v(-2.0, -a * 0.6, 8.0), v(-0.05, 1.0, 0.25)),          # back to guard
        ]
        G, ax = poses[i]
        p, held = _place(b, p, held, G, ax, knuckle_r=(0, 0.3, 1) if i != 0 else (0, 1, 0.3))
        p['twist'] = [0.25, AIM_TWIST, AIM_TWIST * 1.2, 0.05][i]
        p['lean'] = [0.0, 0.18, 0.22, 0.06][i]
        p['elbow_r'] = (1, -0.3, -0.8)
        p['root'] = (0.0, -1.0, [-0.4, 1.4, 1.8, 0.4][i])
    elif grip == 'melee2':
        top = v(b['sh_x'] * 0.3, b['shoulder'] + 3.0, 1.5)
        poses = [
            (top, v(-0.1, 0.45, -0.88)),                                       # raised over the head, blade back
            (v(0, b['chest'] - 1.5, 0) + AIM * 11.0, norm(AIM + v(0, 0.2, 0))),       # the downward cut, arms extended
            (v(0, b['waist'] - 3.0, 0) + AIM * 9.0, norm(AIM + v(0, -0.8, 0))),       # follow through low
            (v(b['sh_x'] * 0.25, b['waist'] + 0.6, 9.0), v(-0.62, 0.7, 0.36)),  # guard
        ]
        G, ax = poses[i]
        p, held = _place(b, p, held, G, ax, support_dist=b['hand'][1] * 2.3, knuckle_r=(0.3, 0, 1) if i != 0 else (0, 1, 0.4),
                         knuckle_l=(-0.2, 0, 1) if i != 0 else (0, 1, 0.4))
        p['lean'] = [-0.04, 0.22, 0.3, 0.06][i]
        p['twist'] = [0.1, AIM_TWIST * 0.8, AIM_TWIST, 0.12][i]
        p['root'] = (0.0, [-0.6, -1.6, -2.0, -1.0][i], [-0.6, 1.4, 1.8, 0.4][i])
        p['elbow_r'] = (1, -0.5, -0.4)
        p['elbow_l'] = (-1, -0.6, -0.3)
    elif grip == 'pistol':
        aim = S_r + AIM * (a * 0.88) + v(-1.5, -1.8, 0)
        up = v(0, 1, 0)
        poses = [(aim, AIM), (aim - AIM * 0.9 + up * 0.7, norm(AIM + up * 0.22)), (aim - AIM * 0.3 + up * 0.2, norm(AIM + up * 0.06)),
                 (S_r + v(-1.4, -a * 0.72, 7.4), v(0.12, -0.72, 0.68))]
        G, ax = poses[i]
        p, held = _place(b, p, held, G, ax, knuckle_r=(0, 1, 0))
        if i < 3:
            # the far hand cups the near one
            p['abs_l'] = hold(b, G + v(-1.6, -1.2, -0.2), ax, (0, 1, 0.2))
            p['hands_front'] = ('r', 'l')
            p['elbow_l'] = (-0.6, -1, -0.2)
        p['twist'] = [AIM_TWIST, AIM_TWIST * 0.9, AIM_TWIST, 0.0][i]
        p['head'] = (-0.12, 0.04, 0.0) if i < 3 else (0.0, 0.0, 0.0)
    elif grip == 'rifle':
        sho = S_r + AIM * 4.2 + v(-2.0, -2.8, 0)
        up = v(0, 1, 0)
        poses = [(sho, AIM), (sho - AIM * 1.0 + up * 0.6, norm(AIM + up * 0.2)), (sho - AIM * 0.3 + up * 0.2, norm(AIM + up * 0.07)),
                 (S_r + v(-3.0, -a * 0.64, 5.0), v(-0.5, 0.42, 0.76))]
        G, ax = poses[i]
        p, held = _place(b, p, held, G, ax, support_dist=10.0 if i < 3 else 10.5, knuckle_r=(0, 0.2, 1) if i < 3 else (0.2, -0.3, 1),
                         knuckle_l=(0, -1, 0.1))
        p['hands_front'] = ('r', 'l')
        p['twist'] = [AIM_TWIST, AIM_TWIST * 0.9, AIM_TWIST, 0.1][i]
        p['head'] = (-0.15, 0.08, 0.0) if i < 3 else (0.0, 0.0, 0.0)
        p['elbow_r'] = (1, -0.4, -0.2)
        p['elbow_l'] = (-0.3, -1, 0.1)
    elif grip == 'tool':
        poses = [(S_r + AIM * (a * 0.5) + v(0, -a * 0.45, 0), norm(AIM + v(0, 0.2, 0))), (S_r + AIM * (a * 0.82) + v(0, -a * 0.6, 0), norm(AIM + v(0, -0.5, 0))),
                 (S_r + AIM * (a * 0.75) + v(0, -a * 0.55, 0), AIM), (S_r + v(-0.6, -a * 0.82, 4.4), v(0.0, -0.3, 1.0))]
        G, ax = poses[i]
        p, held = _place(b, p, held, G, ax, knuckle_r=(0, -1, 0.1))
        p['lean'] = [0.08, 0.2, 0.16, 0.05][i]
        p['twist'] = [AIM_TWIST * 0.5, AIM_TWIST, AIM_TWIST, 0.0][i]
        p['hand_l'] = (-2.0, -a * 0.6, 6.5) if i in (1, 2) else p['hand_l']
    return Pose(**p), held


def down(b, i):
    """buckle, kneel, topple, lie still (unarmed: the item falls away)"""
    a = arm_len(b)
    hx = b['hip_x']
    if i == 0:
        p = dict(stance(b, crouch=3.0), lean=0.35, head=(0.1, 0.35, 0.05), hand_r=(1.0, -a * 0.6, 7.0), hand_l=(-1.0, -a * 0.6, 6.0),
                 fist_r=(0, -0.6, 1), fist_l=(0, -0.6, 1), sway=(0.4, -0.5, 1.0), hands_front=('r',))
    elif i == 1:
        p = dict(root=(0.0, -9.0, 1.0), foot_r=(hx + 0.8, 0.0, 4.5), foot_l=(-hx - 0.6, 0.6, -7.0), heel_l=0.9, lean=0.45,
                 head=(0.05, 0.45, 0.1), hand_r=(0.5, -a * 0.75, 8.0), hand_l=(-0.5, -a * 0.8, 7.0), fist_r=(0, -1, 0.5),
                 fist_l=(0, -1, 0.5), knee_l=(0, -0.3, 1), sway=(0.3, -0.6, 1.4), hands_front=('r',))
    elif i == 2:
        p = dict(root=(0.0, -9.5, 2.0), foot_r=(hx + 0.8, 0.0, 4.5), foot_l=(-hx - 0.6, 0.6, -7.0), heel_l=0.9, lean=0.55,
                 head=(0.1, 0.3, 0.3), hand_r=(1.5, -a * 0.7, 9.0), hand_l=(-1.5, -a * 0.6, 9.5), fist_r=(0, -1, 0.5),
                 fist_l=(0, -1, 0.5), roll=0.55, roll_pivot=(b['sh_x'], 0.0, 0.0), sway=(1.0, -0.8, 1.0), hands_front=('r',))
    else:
        p = dict(root=(0.0, -1.0, 0.0), foot_r=(hx + 0.4, 0.0, 1.2), foot_l=(-hx - 0.4, 0.0, -1.0), lean=0.12,
                 head=(0.25, 0.1, 0.2), hand_r=(2.4, -a * 0.9, 2.0), hand_l=(-1.0, -a * 0.6, 7.0), fist_r=(0, -1, 0.2),
                 fist_l=(0, -0.5, 1), roll=1.5, roll_pivot=(b['sh_x'] + 2.5, 0.0, 0.0), sway=(2.0, 0.0, 0.0), hands_front=('r',))
    return Pose(**p), None


def all_frames():
    """[(grip, anim, i)] in bake order; 'down' is shared and listed once with grip None"""
    out = []
    for g in GRIPS:
        for an, n in ANIMS.items():
            for i in range(n):
                out.append((g, an, i))
    for i in range(DOWN):
        out.append((None, 'down', i))
    return out
