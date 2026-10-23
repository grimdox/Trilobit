"""The body as solids: an anatomical build on the skeleton, smooth-joined so shoulders, neck and hips grow out of the
torso.  Muscles are separate soft solids (pectorals, deltoids, biceps, triceps, forearm, quadriceps, calves, glutes,
trapezius, lats), scaled by the body's `muscle` amount; the female build adds bust and hip forms.

Layers (draw order is set by the runtime): 'far' (the far arm, and the far hand when it holds nothing), 'body'
(torso, legs, head), 'near' (the near arm), 'hands' (the near hand, and the far hand when it holds)."""
import math

import numpy as np

from sdf import v, norm, frame_from, UNION, SUBTRACT
import materials as M

SIDE = {'r': 1.0, 'l': -1.0}


def arm_layer(s, pose, part):
    if s == 'r':
        return 'hands' if part == 'hand' else 'near'
    if part == 'hand' and 'l' in pose['hands_front']:
        return 'hands'
    return 'far'


def _bone_axes(a, b, side_hint):
    """axes for an ellipsoid along bone a->b: y along the bone, x toward side_hint"""
    y = norm(b - a)
    x = np.asarray(side_hint, float)
    x = norm(x - y * np.dot(x, y))
    z = norm(np.cross(x, y))
    return np.stack([x, y, z])


def build_body(sc, sk, skin=M.SKIN, opts=None):
    """add the base body of skeleton `sk` to scene `sc`.  opts: {'cyber': set of limb names replaced by prosthetics}"""
    opts = opts or {}
    b, P, J = sk.body, sk.pose, sk.J
    mu = b['muscle']
    fem = b.fem
    Rs, Rh, Rhd = J['R_chest'], J['R_pelvis'], J['R_head']
    W = J['waist']
    X, Y, Z = (Rs @ v(1, 0, 0), Rs @ v(0, 1, 0), Rs @ v(0, 0, 1))
    Xh, Yh, Zh = (Rh @ v(1, 0, 0), Rh @ v(0, 1, 0), Rh @ v(0, 0, 1))
    chest_axes = np.stack([X, Y, Z])
    pel_axes = np.stack([Xh, Yh, Zh])

    def CP(x, y, z):                       # a point in the chest frame, heights measured as standing heights
        return W + Rs @ v(x, y - b['waist'], z)

    def PP(x, y, z):                       # a point in the pelvis frame
        return J['pelvis'] + Rh @ v(x, y - b['pelvis'], z)

    t = sc.group('torso', 0.0)
    rib, abd, pel = b['rib'], b['abd'], b['pel']
    br = P['breath']
    sc.ellipsoid(CP(0, b['chest'] + br * 0.5, 0.0), (rib[0] + br * 0.15, rib[1], rib[2] + br * 0.2), chest_axes, t, skin, 'body', 'rib', k=0.0)
    # the upper chest shelf carries the shoulders out to the deltoids
    sc.ellipsoid(CP(0, b['shoulder'] - 2.4 + br, -0.2), (b['sh_x'] - 0.9, 2.6, rib[2] * 0.86), chest_axes, t, skin, 'body', 'shelf', k=2.2)
    sc.ellipsoid(CP(0, b['waist'] + 0.4, 0.3), (abd[0] * b['waist_pinch'], abd[1], abd[2]), chest_axes, t, skin, 'body', 'abd', k=2.6)
    sc.ellipsoid(PP(0, b['pelvis'], -0.2), pel, pel_axes, t, skin, 'body', 'pelvis', k=2.4)
    # glutes and the hip flesh over the hip joints
    for s, sg in SIDE.items():
        sc.ellipsoid(PP(sg * pel[0] * 0.45, b['pelvis'] - 1.0, -pel[2] * 0.55), (3.0 * b['glute'], 3.4 * b['glute'], 2.6 * b['glute']),
                     pel_axes, t, skin, 'body', 'glute', k=1.6)
        if fem:
            sc.ellipsoid(PP(sg * (pel[0] - 0.6), b['pelvis'] - 1.6, 0.0), (2.4, 3.6, 3.4), pel_axes, t, skin, 'body', 'hip', k=2.0)
    # chest anatomy
    if fem and b['bust'] > 0:
        bu = b['bust']
        for s, sg in SIDE.items():
            sc.ellipsoid(CP(sg * rib[0] * 0.44, b['chest'] + 1.0 + br * 0.6, rib[2] * 0.62), (2.5 * bu + 0.4, 2.3 * bu + 0.3, 2.2 * bu),
                         chest_axes, t, skin, 'body', 'bust', k=1.1)
    if mu > 0.2:
        for s, sg in SIDE.items():
            # pectorals: a flattened slab on the upper rib cage, its lower edge creasing over the ribs
            sc.ellipsoid(CP(sg * rib[0] * 0.5, b['chest'] + 1.6 + br * 0.6, rib[2] * 0.55 + 0.25 * mu),
                         (rib[0] * 0.52, 2.3 + 0.35 * mu, 1.3 + 0.55 * mu), chest_axes, t, skin, 'body', 'pec', k=0.7)
            # lats under the arms
            sc.ellipsoid(CP(sg * (rib[0] - 0.8), b['chest'] - 1.2, -0.8), (1.6 + 0.6 * mu, 4.2, 2.6), chest_axes, t, skin, 'body', 'lat', k=1.4)
        if not fem:
            for row, y in enumerate((b['waist'] + 3.2, b['waist'] + 1.0, b['waist'] - 1.3)):
                for s, sg in SIDE.items():
                    sc.ellipsoid(CP(sg * 1.2, y, abd[2] * 0.82 + 0.15 * mu), (1.15, 0.95, 0.55 + 0.25 * mu), chest_axes, t, skin, 'body', 'abs', k=0.45)
    # trapezius and neck
    tr = b['trap']
    for s, sg in SIDE.items():
        sc.cone(CP(sg * 1.4, b['neck'] - 0.6, -1.3), CP(sg * (b['sh_x'] - 1.6), b['shoulder'] + 0.1 + br, -0.9),
                1.3 + 0.55 * tr, 1.0 + 0.3 * tr, t, skin, 'body', 'trap', k=1.4)
    nk0 = CP(0, b['neck'] - 1.4, -0.5)
    sc.cone(nk0, J['head'] + J['R_head'] @ v(0, -3.2, -0.6), b['neck_r'][0], b['neck_r'][1], t, skin, 'body', 'neck', k=1.2)

    # ---------------------------------------------------------------------------------- head
    build_head(sc, sk, skin)

    # ---------------------------------------------------------------------------------- arms
    for s, sg in SIDE.items():
        cyber = ('arm_' + s) in opts.get('cyber', ())
        mat = M.SYNTH if cyber else skin
        S, E, Wr = J['sh_' + s], J['elbow_' + s], J['wrist_' + s]
        g = sc.group('arm_' + s, 0.9, parent='torso')
        lay = arm_layer(s, P, 'arm')
        out = norm(S - J['neck'])
        sc.cone(S, E, b['ua'][0], b['ua'][1], g, mat, lay, 'upper_arm', k=0.0)
        ax = _bone_axes(S, E, out)
        # deltoid caps the shoulder; biceps in front, triceps behind
        sc.ellipsoid(S + (E - S) * 0.1 + out * 0.6, (b['ua'][0] * 1.05 + 0.25 * mu, 3.0 + 0.3 * mu, b['ua'][0] * 1.08 + 0.2 * mu), ax, g, mat, lay, 'deltoid', k=1.0)
        if mu > 0.2:
            fwd = ax[2]
            sc.ellipsoid(S + (E - S) * 0.52 + fwd * (b['ua'][1] * 0.45), (b['ua'][1] * 0.72, 2.6, 0.8 + 0.5 * mu), ax, g, mat, lay, 'biceps', k=0.8)
            sc.ellipsoid(S + (E - S) * 0.42 - fwd * (b['ua'][1] * 0.5), (b['ua'][1] * 0.75, 2.9, 0.8 + 0.45 * mu), ax, g, mat, lay, 'triceps', k=0.8)
        g2 = sc.group('fore_' + s, 0.7, parent='arm_' + s)
        sc.cone(E, Wr, b['fa'][0], b['fa'][1], g2, mat, lay, 'forearm', k=0.0)
        axf = _bone_axes(E, Wr, out)
        sc.ellipsoid(E + (Wr - E) * 0.26, (b['fa'][0] * 0.95 + 0.15 * mu, 2.4, b['fa'][0] * 0.9 + 0.1 * mu), axf, g2, mat, lay, 'forearm_m', k=0.9)
        build_fist(sc, sk, s, mat, arm_layer(s, P, 'hand'), cyber)

    # ---------------------------------------------------------------------------------- legs
    for s, sg in SIDE.items():
        cyber = ('leg_' + s) in opts.get('cyber', ())
        mat = M.SYNTH if cyber else skin
        Hj, K, A = J['hip_' + s], J['knee_' + s], J['ankle_' + s]
        g = sc.group('leg_' + s, 1.4, parent='torso')
        out = Rh @ v(sg, 0, 0)
        sc.cone(Hj + v(0, 0.8, 0), K, b['th'][0], b['th'][1], g, mat, 'body', 'thigh', k=0.0)
        axt = _bone_axes(Hj, K, out)
        sc.ellipsoid(Hj + (K - Hj) * 0.45 + axt[2] * (b['th'][0] * 0.32), (b['th'][0] * 0.86, 5.0, b['th'][0] * 0.62 + 0.15 * mu), axt, g, mat, 'body', 'quad', k=1.2)
        sc.ellipsoid(K + axt[2] * 0.9 + (Hj - K) * 0.04, (1.25, 1.1, 0.8), axt, g, mat, 'body', 'kneecap', k=0.7)
        g2 = sc.group('shin_' + s, 0.8, parent='leg_' + s)
        sc.cone(K, A, b['cf'][0], b['cf'][1], g2, mat, 'body', 'shin', k=0.0)
        axc = _bone_axes(K, A, out)
        sc.ellipsoid(K + (A - K) * 0.27 - axc[2] * (b['cf'][0] * 0.32), (b['cf'][0] * 0.88, 3.4, b['cf'][0] * 0.66 + 0.1 * mu), axc, g2, mat, 'body', 'calf', k=1.0)
        build_foot(sc, sk, s, mat)


def build_fist(sc, sk, s, mat, layer, cyber=False):
    """a closed fist: palm block, knuckle row, thumb over the grip axis.  `fist` = direction the knuckles point,
    `grip` = axis a held haft runs through"""
    b, J = sk.body, sk.J
    Wr = J['wrist_' + s]
    fd = J['fist_' + s]
    gd = J['grip_' + s]
    gd = norm(gd - fd * np.dot(gd, fd))
    if np.linalg.norm(gd) < 1e-3:
        gd = norm(np.cross(fd, v(0, 0, 1)))
    side = norm(np.cross(gd, fd))
    hx, hy, hz = b['hand']
    g = sc.group('hand_' + s, 0.35, parent='fore_' + s)
    c = Wr + fd * (hy * 0.95)
    axes = np.stack([gd, fd, side])
    sc.box(c, (hx * 0.95, hy, hz), axes, min(hx, hz) * 0.75, g, mat, layer, 'palm', k=0.0)
    sc.ellipsoid(c + fd * (hy * 0.55) + side * (hz * 0.25), (hx * 1.02, hy * 0.62, hz * 1.05), axes, g, mat, layer, 'knuckles', k=0.5)
    # thumb wraps over the front of the grip
    sg = SIDE[s]
    th0 = c - gd * (hx * 0.55) + side * (hz * 0.5)
    sc.cone(th0 - fd * (hy * 0.4), th0 + fd * (hy * 0.35) + side * 0.4, hz * 0.52, hz * 0.45, g, mat, layer, 'thumb', k=0.4)
    sc.cone(Wr - fd * 0.6, c - fd * (hy * 0.4), b['fa'][1] * 0.95, hx * 0.85, g, mat, layer, 'wrist', k=0.5)


def build_foot(sc, sk, s, mat, shoe=None):
    b, J = sk.body, sk.J
    A = J['ankle_' + s]
    fd = J['foot_dir_' + s]
    L = b['foot']
    up = J['R_pelvis'] @ v(0, 1, 0) if abs(sk.pose.p.get('roll', 0.0)) > 1e-6 else v(0, 1, 0)
    flat = norm(fd - up * np.dot(fd, up))
    heel_up = J['heel_' + s]
    g = sc.group('foot_' + s, 0.9, parent='shin_' + s)
    side = norm(np.cross(up, flat))
    ax = np.stack([side, up, flat])
    # heel under the ankle, the foot running forward to the toes; a raised heel rolls the foot onto the ball
    heel = A - up * (b['ankle'] * 0.62) - flat * 0.9
    ball = heel + flat * (L * 0.72) - up * 0.15
    if heel_up > 0.01:
        heel = ball - flat * (L * 0.72) * math.cos(heel_up) + up * (L * 0.72 * math.sin(heel_up))
    sc.ellipsoid(heel, (1.35, 1.3, 1.5), ax, g, mat, 'body', 'heel', k=0.0)
    sc.cone(heel + up * 0.3, ball, 1.4, 1.25, g, mat, 'body', 'foot', k=0.8)
    toe = ball + flat * (L * 0.24) - up * 0.05
    sc.cone(ball, toe, 1.25, 0.95, g, mat, 'body', 'toes', k=0.6)
    sc.cone(A, heel + up * 0.9 + flat * 0.3, b['cf'][1] * 0.95, 1.25, g, mat, 'body', 'ankle', k=0.8)


def head_points(sk):
    """named points on the face in character space: eyes, brows, mouth, nose tip, ears, crown"""
    b, J = sk.body, sk.J
    R = J['R_head']
    hc = J['head']
    rx, ry, rz = b['head_r']

    def H(x, y, z):
        return hc + R @ v(x, y, z)

    return {
        'eye_r': H(rx * 0.37, 0.45, rz * 0.84), 'eye_l': H(-rx * 0.37, 0.45, rz * 0.84),
        'brow_r': H(rx * 0.38, 1.7, rz * 0.86), 'brow_l': H(-rx * 0.38, 1.7, rz * 0.86),
        'mouth': H(0, -ry * 0.5, rz * 0.84), 'nose': H(0, -ry * 0.12, rz * 1.02),
        'ear_r': H(rx * 0.96, -0.6, -0.2), 'ear_l': H(-rx * 0.96, -0.6, -0.2),
        'crown': H(0, ry, -0.2), 'chin': H(0, -ry * 0.98, rz * 0.5), 'temple_r': H(rx * 0.86, 0.6, rz * 0.4),
        'temple_l': H(-rx * 0.86, 0.6, rz * 0.4), 'centre': hc,
    }


def build_head(sc, sk, skin):
    b, J = sk.body, sk.J
    R = J['R_head']
    hc = J['head']
    rx, ry, rz = b['head_r']
    jaw = b['jaw']
    ax = np.stack([R @ v(1, 0, 0), R @ v(0, 1, 0), R @ v(0, 0, 1)])

    def H(x, y, z):
        return hc + R @ v(x, y, z)

    g = sc.group('head', 0.9, parent='torso')
    # cranium, then the face mass forward and down; the jaw and chin close it, cheekbones and brow give the planes
    sc.ellipsoid(H(0, 0.55, -0.35), (rx, ry * 0.92, rz), ax, g, skin, 'body', 'cranium', k=0.0)
    sc.ellipsoid(H(0, -1.7, 1.0), (rx * 0.84, ry * 0.72, rz * 0.8), ax, g, skin, 'body', 'face', k=1.6)
    sc.ellipsoid(H(0, -ry * 0.72, 1.4), (rx * 0.62 * (0.85 + 0.15 * jaw), ry * 0.34, rz * 0.62), ax, g, skin, 'body', 'jaw', k=1.2)
    sc.ellipsoid(H(0, -ry * 0.86, rz * 0.48), (1.45 * jaw + 0.1, 0.95, 1.15), ax, g, skin, 'body', 'chin', k=0.8)
    sc.ellipsoid(H(0, 1.5, rz * 0.7), (rx * 0.74, 0.85, 1.25), ax, g, skin, 'body', 'brow', k=0.9)
    for sg in (1.0, -1.0):
        sc.ellipsoid(H(sg * rx * 0.55, -0.4, rz * 0.62), (1.25, 1.0, 1.0), ax, g, skin, 'body', 'cheek', k=0.8)
        sc.ellipsoid(H(sg * rx * 0.95, -0.5, -0.2), (0.6, 1.35, 1.0), ax, g, skin, 'body', 'ear', k=0.5)
    sc.cone(H(0, 0.6, rz * 0.86), H(0, -0.9, rz * 1.08), 0.55, 0.62, g, skin, 'body', 'nose', k=0.5)
    # eye sockets: a shallow cut under the brow so the eyes sit in shade
    for sg in (1.0, -1.0):
        sc.ellipsoid(H(sg * rx * 0.37, 0.5, rz * 1.0), (1.05, 0.62, 0.55), ax, g, skin, 'body', 'socket', op=SUBTRACT, k=0.5)


def _curve(pts, n=6):
    """a smooth polyline through control points (quadratic B-spline style corner cutting)"""
    P = [np.asarray(p, float) for p in pts]
    for _ in range(2):
        Q = [P[0]]
        for a, b in zip(P[:-1], P[1:]):
            Q += [a * 0.75 + b * 0.25, a * 0.25 + b * 0.75]
        Q.append(P[-1])
        P = Q
    return P


def body_marks(sk, android=False):
    """deliberate anatomical marks (see shade.apply_marks): a pixel artist's few lines instead of noisy shading"""
    b, J = sk.body, sk.J
    Rs, Rh = J['R_chest'], J['R_pelvis']
    W = J['waist']
    mu = b['muscle']
    rib, abd = b['rib'], b['abd']
    br = sk.pose['breath']

    def CP(x, y, z):
        return W + Rs @ v(x, y - b['waist'], z)

    T = {'torso'}
    marks = []
    zf = rib[2] + 0.4
    # collarbones catch the light
    for sg in (1.0, -1.0):
        marks.append(dict(pts=_curve([CP(sg * 1.1, b['neck'] - 0.9 + br, zf - 1.6), CP(sg * (b['sh_x'] * 0.5), b['shoulder'] - 0.2 + br, zf - 1.5),
                                      CP(sg * (b['sh_x'] - 2.2), b['shoulder'] + 0.3 + br, zf - 2.6)]), d=+1, groups=T, tol=4.0, cap=5))
    if not b.fem and mu > 0.2:
        zp = rib[2] * 0.55 + 0.25 * mu + 1.2 + 0.5 * mu
        for sg in (1.0, -1.0):
            # the lower edge of the pectoral, sweeping up into the armpit
            marks.append(dict(pts=_curve([CP(sg * 0.5, b['chest'] + 0.2 + br, zp), CP(sg * rib[0] * 0.42, b['chest'] - 0.5 + br * 0.6, zp - 0.2),
                                          CP(sg * rib[0] * 0.86, b['chest'] + 0.9 + br * 0.6, zp - 1.8)]), d=-1, groups=T, tol=4.5, floor=1))
        marks.append(dict(pts=[CP(0, b['chest'] + 3.4 + br, zp), CP(0, b['chest'] + 0.9 + br, zp)], d=-1, groups=T, tol=4.5))
        za = abd[2] * 0.82 + 0.6 + 0.25 * mu
        marks.append(dict(pts=[CP(0, b['waist'] + 4.4, za), CP(0, b['waist'] - 2.6, za - 0.2)], d=-1, groups=T, tol=4.0))
        for y in (b['waist'] + 2.1, b['waist'] - 0.2):
            marks.append(dict(pts=[CP(-2.2, y, za - 0.5), CP(-0.6, y - 0.1, za), CP(0.6, y - 0.1, za), CP(2.2, y, za - 0.5)], d=-1, groups=T, tol=4.0))
        for sg in (1.0, -1.0):
            # the iliac line from the flank down toward the groin
            marks.append(dict(pts=_curve([CP(sg * abd[0] * 0.92, b['waist'] - 0.6, za - 1.8), CP(sg * abd[0] * 0.6, b['waist'] - 3.2, za - 0.6),
                                          CP(sg * 1.6, b['pelvis'] - 1.2, za - 0.4)]), d=-1, groups=T, tol=4.5))
    if b.fem and b['bust'] > 0:
        zb = rib[2] * 0.62 + 2.0 * b['bust']
        for sg in (1.0, -1.0):
            marks.append(dict(pts=_curve([CP(sg * 0.5, b['chest'] - 0.6 + br * 0.6, zb - 0.6), CP(sg * rib[0] * 0.44, b['chest'] - 1.4 + br * 0.6, zb - 0.4),
                                          CP(sg * rib[0] * 0.82, b['chest'] - 0.3 + br * 0.6, zb - 1.8)]), d=-1, groups=T, tol=4.5))
        marks.append(dict(pts=[CP(0, b['chest'] + 1.6 + br, zb - 1.0), CP(0, b['chest'] - 0.2 + br, zb - 1.0)], d=-1, groups=T, tol=4.5))
    # navel
    zn = abd[2] + 0.2
    marks.append(dict(pts=[CP(0, b['waist'] - 1.2, zn), CP(0, b['waist'] - 1.9, zn)], d=-1, groups=T, tol=4.0))
    # deltoid split on the front of each upper arm, knee and shin lines
    for s, sg in (('r', 1.0), ('l', -1.0)):
        S, E = J['sh_' + s], J['elbow_' + s]
        out = norm(S - J['neck'])
        ax = _bone_axes(S, E, out)
        r0 = b['ua'][0] + 0.2
        if mu > 0.3:
            marks.append(dict(pts=_curve([S + (E - S) * 0.12 + ax[2] * r0, S + (E - S) * 0.34 + ax[2] * r0 * 0.9 + ax[0] * 0.4,
                                          S + (E - S) * 0.5 + ax[0] * r0 * 0.9]), d=-1, groups={'arm_' + s}, tol=4.0))
        K, A = J['knee_' + s], J['ankle_' + s]
        Hj = J['hip_' + s]
        axk = _bone_axes(K, A, Rh @ v(sg, 0, 0))
        marks.append(dict(pts=[K + axk[2] * (b['cf'][0] + 0.2) + (A - K) * 0.08 - axk[0] * 0.9, K + axk[2] * (b['cf'][0] + 0.2) + (A - K) * 0.08 + axk[0] * 0.9],
                          d=-1, groups={'shin_' + s}, tol=4.0))
        axt = _bone_axes(Hj, K, Rh @ v(sg, 0, 0))
        if mu > 0.3:
            # the line between the outer quad and the hamstring, a light catch on the front of the thigh
            marks.append(dict(pts=_curve([Hj + (K - Hj) * 0.3 + axt[0] * b['th'][0] * 0.9, Hj + (K - Hj) * 0.7 + axt[0] * b['th'][0] * 0.75 - axt[2] * 0.3]),
                              d=-1, groups={'leg_' + s}, tol=4.0))
    if android:
        marks += android_seams(sk)
    return marks


def _ring(c, ax, r, n=14):
    return [c + (math.cos(t) * ax[0] + math.sin(t) * ax[2]) * r for t in np.linspace(0, 2 * math.pi, n)]


def android_seams(sk):
    """panel lines of a synthetic body: rings at the neck, shoulders, elbows, wrists, waist, thighs, knees, ankles, and
    the face plate's edge under the cheekbones"""
    b, J = sk.body, sk.J
    Rs, Rh = J['R_chest'], J['R_pelvis']
    W = J['waist']
    out = []
    S = dict(d=-2, floor=0, tol=3.0)

    def add(pts, groups):
        out.append(dict(pts=pts, groups=groups, **S))
    ca = np.stack([Rs @ v(1, 0, 0), Rs @ v(0, 1, 0), Rs @ v(0, 0, 1)])
    pa = np.stack([Rh @ v(1, 0, 0), Rh @ v(0, 1, 0), Rh @ v(0, 0, 1)])
    add(_ring(W + Rs @ v(0, b['neck'] - 0.4 - b['waist'], -0.5), ca, b['neck_r'][0] + 0.1), {'torso'})
    add([p for p in _ring(W + Rs @ v(0, b['waist'] - 1.6 - b['waist'], 0.2), ca, 1.0)], {'torso'})
    ab = b['abd']
    add([W + Rs @ v(math.cos(t) * (ab[0] * b['waist_pinch'] + 0.2), -1.4, math.sin(t) * (ab[2] + 0.2)) for t in np.linspace(0, 2 * math.pi, 18)], {'torso'})
    for s, sg in SIDE.items():
        Sh, E, Wr = J['sh_' + s], J['elbow_' + s], J['wrist_' + s]
        ax = _bone_axes(Sh, E, v(sg, 0, 0))
        add(_ring(Sh + (E - Sh) * 0.22, ax, b['ua'][0] + 0.15), {'arm_' + s})
        axf = _bone_axes(E, Wr, v(sg, 0, 0))
        add(_ring(E + (Wr - E) * 0.06, axf, b['fa'][0] + 0.1), {'fore_' + s})
        add(_ring(E + (Wr - E) * 0.9, axf, b['fa'][1] + 0.12), {'fore_' + s})
        Hj, K, A = J['hip_' + s], J['knee_' + s], J['ankle_' + s]
        axt = _bone_axes(Hj, K, Rh @ v(sg, 0, 0))
        add(_ring(Hj + (K - Hj) * 0.5, axt, b['th'][0] * 0.95 + 0.15), {'leg_' + s})
        axc = _bone_axes(K, A, Rh @ v(sg, 0, 0))
        add(_ring(K + (A - K) * 0.08, axc, b['cf'][0] + 0.1), {'shin_' + s})
        add(_ring(K + (A - K) * 0.88, axc, b['cf'][1] + 0.15), {'shin_' + s})
    # face plate: from the near ear under the cheekbone to the chin
    R, hc = J['R_head'], J['head']
    rx, ry, rz = b['head_r']
    add([hc + R @ v(rx * 0.92, -0.3, 0.6), hc + R @ v(rx * 0.6, -1.6, rz * 0.7), hc + R @ v(0.0, -ry * 0.78, rz * 0.82)], {'head'})
    return out
