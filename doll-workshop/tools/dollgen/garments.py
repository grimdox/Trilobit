"""Garments as data: every piece of clothing or armour is a list of parts, each part an inflated copy of the body's own
solids cut by planes.  So any garment fits all six bodies in every pose, folds where the body bends, and keeps the
muscles from showing through (cloth follows the big forms only, plus the bust).

Part types and their options (all lengths in sprite pixels at LOD 64):
  torso    mat, t (thickness), top: crew|v|scoop|high|none, bottom: chest|waist|hip|crotch|thigh, open (front gap width),
           loose (extra volume), arms: True (covers the shoulder) | False (sleeveless armholes)
  sleeves  mat, t, len: cap|short|elbow|long, cuff (material of a cuff band), loose
  legs     mat, t, len: short|knee|long, loose, top: waist|hip, cuff
  boots    mat, t, height: ankle|mid|knee, sole (material)
  gloves   mat, t
  skirt    mat, t, len: thigh|knee|calf, flare, open (front gap)      coat tails and skirts, split per leg so they walk
  collar   mat, h (height up the neck), t, open (bool)
  belt     mat, y: waist|hip, w (width), buckle (material)
  plate    mat, at: chest|back|abdomen|shoulders|forearms|thighs|shins|knees, t, size
  pocket   mat, at: chest_r|chest_l|thigh_r|thigh_l
  strap    mat, from, to (named points), w                           harness and sling straps
  hood     mat, t, up (bool)
  helmet   mat, t, visor (material or None), brim (bool)
  mask     mat, cover: lower|full
Layers: torso, legs, boots, skirt, collar, belt, plates, pockets, straps on the body; sleeves and arm plates on the
near / far arm; gloves on the hands.  `level` orders garments inside each layer group (0 underwear ... 6 harness).
"""
import math

import numpy as np

from sdf import v, norm, frame_from, INTERSECT, SUBTRACT, UNION, Scene, copy_shell
import materials as M
from anatomy import _bone_axes, SIDE, arm_layer

MAT = {'cloth1': M.CLOTH1, 'cloth2': M.CLOTH2, 'cloth3': M.CLOTH3, 'cloth4': M.CLOTH4, 'leather': M.LEATHER, 'leather2': M.LEATHER2,
       'metal': M.METAL, 'poly': M.POLY, 'synth': M.SYNTH, 'under': M.UNDER, 'glow': M.GLOW, 'glow2': M.GLOW2, 'dark': M.DARK,
       'lens': M.LENS}


class F:
    """frames of a skeleton: chest, pelvis and head points, bone axes"""

    def __init__(self, sk):
        self.sk, self.b, self.J = sk, sk.body, sk.J
        self.Rs, self.Rh, self.Rhd = self.J['R_chest'], self.J['R_pelvis'], self.J['R_head']
        self.W = self.J['waist']

    def CP(self, x, y, z):
        return self.W + self.Rs @ v(x, y - self.b['waist'], z)

    def PP(self, x, y, z):
        return self.J['pelvis'] + self.Rh @ v(x, y - self.b['pelvis'], z)

    def HP(self, x, y, z):
        return self.J['head'] + self.Rhd @ v(x, y, z)

    def chest_axes(self):
        return np.stack([self.Rs @ v(1, 0, 0), self.Rs @ v(0, 1, 0), self.Rs @ v(0, 0, 1)])

    def pel_axes(self):
        return np.stack([self.Rh @ v(1, 0, 0), self.Rh @ v(0, 1, 0), self.Rh @ v(0, 0, 1)])

    def head_axes(self):
        return np.stack([self.Rhd @ v(1, 0, 0), self.Rhd @ v(0, 1, 0), self.Rhd @ v(0, 0, 1)])

    def up(self):
        return self.Rs @ v(0, 1, 0)

    def anatomy(self, cam):
        """the body's own solids (built once per frame) for shells"""
        if getattr(self, '_an', None) is None:
            from anatomy import build_body
            self._an = Scene(cam)
            build_body(self._an, self.sk)
        return self._an


def shell(sc, f, tags, group, mat, t, layer=None, k=1.6, groups=None):
    """clothing as an inflated copy of the body solids with these tags (and in these anatomy groups)"""
    an = f.anatomy(sc.cam)
    sel = lambda m: m['tag'] in tags and (groups is None or m['group'] in groups)
    n = copy_shell(sc, an, sel, t + 0.08, group, mat, layer=layer, k=k)
    # join the shell to the rest of the garment at least as smoothly as the body joins those parts (plus a margin),
    # so the fillets where a limb meets the torso are covered too
    src = [an.gjoin[g] for g in an.groups if groups is None or g in groups]
    if src:
        sc.gjoin[group] = max(sc.gjoin.get(group, 0.0), max(src) + 0.25 * sc.cam.s)
    return n


def _hem(sc, g, f, height, frame='pelvis', tilt=0.0):
    """keep above a horizontal plane at a standing height (in the pelvis or chest frame)"""
    if frame == 'pelvis':
        p, n = f.PP(0, height, 0), f.Rh @ v(0, -1, tilt)
    else:
        p, n = f.CP(0, height, 0), f.Rs @ v(0, -1, tilt)
    sc.plane(p, n, g, op=INTERSECT, k=0.3)


def _limb_cut(sc, g, a, b, frac, keep_root=True, k=0.25, r=4.0, reach=4.0):
    """cut a limb shell across the bone at `frac` from a toward b.  The cut is a slab of limited radius `r` around the
    bone that runs from the cut point past the bone's far end (by `reach`), not an endless plane: a bent limb (a wrist
    folded back to the shoulder) must not lose the part of the sleeve it doubles back next to."""
    p = a + (b - a) * frac
    n = norm(b - a) if keep_root else norm(a - b)
    length = float(np.linalg.norm(b - a)) * ((1.0 - frac) if keep_root else frac) + reach
    u = norm(np.cross(n, v(0, 0, 1) if abs(n[2]) < 0.9 else v(1, 0, 0)))
    w = np.cross(u, n)
    sc.box(p + n * (length * 0.5), (r, length * 0.5, r), np.stack([u, n, w]), 0.0, g, MAT['cloth1'], 'body', 'cut', op=SUBTRACT, k=k)


# ------------------------------------------------------------------------------------------------ parts
def part_torso(sc, f, gname, o, layer='body'):
    b, J = f.b, f.J
    mat = MAT[o.get('mat', 'cloth1')]
    t = o.get('t', 0.35)
    lo = o.get('loose', 0.0)
    rib, abd, pel = b['rib'], b['abd'], b['pel']
    g = sc.group(gname, 0.0)
    ca, pa = f.chest_axes(), f.pel_axes()
    tt = t + lo
    # an inflated copy of the torso solids, smoothed so the muscles do not print through
    shell(sc, f, {'rib', 'shelf', 'abd', 'pelvis', 'glute', 'hip', 'bust', 'pec', 'lat', 'trap', 'neck'}, g, mat, tt, layer=layer, k=2.2 + lo,
          groups={'torso'})
    if lo > 0:
        sc.ellipsoid(f.CP(0, b['waist'] + 0.4, 0.3), (abd[0] + tt + lo * 0.6, abd[1] + t, abd[2] + tt + lo * 0.5), ca, g, mat, layer, 'loose', k=2.6)
    # (the shoulder caps belong to the sleeves, which sit on the arm layers above the torso)
    # bottom hem
    bottom = o.get('bottom', 'hip')
    hy = {'chest': b['chest'] - 2.5, 'waist': b['waist'] - 0.5, 'hip': b['pelvis'] + 0.5, 'crotch': b['hipj'] - 2.2,
          'thigh': b['hipj'] - 5.0}[bottom]
    _hem(sc, g, f, hy, 'pelvis' if bottom in ('hip', 'crotch', 'thigh') else 'chest')
    # sleeveless: armholes
    if not o.get('arms', True):
        for s, sg in SIDE.items():
            S = J['sh_' + s]
            sc.ellipsoid(S + v(0, -1.2, 0) + norm(S - J['neck']) * 1.6, (2.8, 3.8, 3.2), f.chest_axes(), g, mat, layer, 'armhole', op=SUBTRACT, k=0.5)
    # neckline
    top = o.get('top', 'crew')
    nr = b['neck_r'][0]
    if top in ('crew', 'v', 'scoop', 'none'):
        sc.plane(f.CP(0, b['neck'] - 0.2, 0), f.Rs @ v(0, 1, 0), g, op=INTERSECT, k=0.4)
        sc.cone(f.CP(0, b['neck'] - 4.0, -0.5), f.CP(0, b['neck'] + 4.0, -0.5), nr + 0.35, nr + 0.35, g, mat, layer, 'neckhole', op=SUBTRACT, k=0.4)
    if top == 'v':
        sc.box(f.CP(0, b['chest'] + 2.6, rib[2] + 1.0), (1.9, 3.6, 2.5), np.stack([f.Rs @ v(1, 0, 0), f.Rs @ v(0, 1, 0), f.Rs @ v(0, 0, 1)]),
               0.3, g, mat, layer, 'vcut', op=SUBTRACT, k=0.3)
    if top == 'scoop':
        sc.ellipsoid(f.CP(0, b['chest'] + 3.2, rib[2] + 0.4), (rib[0] * 0.6, 2.6, 2.4), f.chest_axes(), g, mat, layer, 'scoop', op=SUBTRACT, k=0.5)
    if top == 'high':
        sc.cone(f.CP(0, b['neck'] - 1.4, -0.5), J['head'] + f.Rhd @ v(0, -3.6, -0.6), nr + t + 0.35, b['neck_r'][1] + t + 0.25, g, mat, layer,
                'turtle', k=0.8)
        sc.plane(J['head'] + f.Rhd @ v(0, -3.3, 0), f.Rhd @ v(0, 1, 0.2), g, op=INTERSECT, k=0.3)
    if o.get('open', 0) > 0:
        w = o['open']
        sc.box(f.CP(0.3, b['waist'], rib[2] + 2.2), (w * 0.5, 12.0, 2.6), f.chest_axes(), 0.2, g, mat, layer, 'opening', op=SUBTRACT, k=0.2)
    return g


def part_sleeves(sc, f, gname, o, pose):
    b, J = f.b, f.J
    mat = MAT[o.get('mat', 'cloth1')]
    t = o.get('t', 0.3)
    lo = o.get('loose', 0.0)
    L = o.get('len', 'long')
    out = []
    for s, sg in SIDE.items():
        S, E, Wr = J['sh_' + s], J['elbow_' + s], J['wrist_' + s]
        lay = arm_layer(s, pose, 'arm')
        g = sc.group('%s_%s' % (gname, s), 0.6)
        # the upper sleeve and the forearm sleeve are separate groups (the forearm one joined into the upper one), so a
        # cut across the forearm never reaches the upper arm, even with the wrist folded back to the shoulder
        shell(sc, f, {'upper_arm', 'deltoid', 'biceps', 'triceps'}, g, mat, t + 0.12, layer=lay, k=1.4 + lo, groups={'arm_' + s})
        if lo > 0:
            sc.cone(S + (E - S) * 0.2, E, b['ua'][0] + t + lo * 0.6, b['ua'][1] + t + lo * 0.8, g, mat, lay, 'loose', k=1.2)
        if L in ('elbow', 'long'):
            g2 = sc.group('%s_fa_%s' % (gname, s), 0.7, parent=g)
            shell(sc, f, {'forearm', 'forearm_m'}, g2, mat, t + 0.12, layer=lay, k=1.4 + lo, groups={'fore_' + s})
            if lo > 0:
                sc.cone(E, Wr, b['fa'][0] + t + lo * 0.7, b['fa'][1] + t + lo, g2, mat, lay, 'loose', k=1.0)
        if L == 'cap':
            _limb_cut(sc, g, S, E, 0.28)
        elif L == 'short':
            _limb_cut(sc, g, S, E, 0.55)
        elif L == 'elbow':
            _limb_cut(sc, g2, E, Wr, 0.12, r=b['fa'][0] + t + lo + 1.6)
        else:
            _limb_cut(sc, g2, E, Wr, 0.94, r=b['fa'][1] + t + lo + 1.6)
        if o.get('cuff') and L in ('long', 'elbow', 'short'):
            gc = sc.group('%s_cuff_%s' % (gname, s), 0.0)
            cm = MAT[o['cuff']]
            if L == 'long':
                c0, c1 = E + (Wr - E) * 0.8, E + (Wr - E) * 0.95
                r = b['fa'][1] + t + lo + 0.35
            elif L == 'elbow':
                c0, c1 = E - (E - S) * 0.02, E + (Wr - E) * 0.12
                r = b['fa'][0] + t + 0.4
            else:
                c0, c1 = S + (E - S) * 0.45, S + (E - S) * 0.56
                r = b['ua'][1] + t + 0.55
            sc.cone(c0, c1, r, r, gc, cm, lay, 'cuff')
        out.append(g)
    return out


def part_legs(sc, f, gname, o):
    b, J = f.b, f.J
    mat = MAT[o.get('mat', 'cloth3')]
    t = o.get('t', 0.35)
    lo = o.get('loose', 0.0)
    L = o.get('len', 'long')
    g = sc.group(gname, 0.0)
    shell(sc, f, {'pelvis', 'glute', 'hip'}, g, mat, t, layer='body', k=1.6)
    for s, sg in SIDE.items():
        Hj, K, A = J['hip_' + s], J['knee_' + s], J['ankle_' + s]
        gs = sc.group('%s_%s' % (gname, s), 1.2, parent=gname)
        tags = {'thigh', 'quad'}
        if L in ('knee', 'long'):
            tags |= {'kneecap'}
        if L == 'long':
            tags |= {'shin', 'calf'}
        shell(sc, f, tags, gs, mat, t, layer='body', k=1.5 + lo, groups={'leg_' + s, 'shin_' + s})
        if lo > 0:
            sc.cone(Hj + v(0, 0.8, 0), K, b['th'][0] + t + lo * 0.3, b['th'][1] + t + lo * 0.6, gs, mat, 'body', 'loose', k=1.2)
            if L == 'long':
                sc.cone(K, A + (K - A) * 0.12, b['cf'][0] + t + lo * 0.6, b['cf'][1] + t + lo * 1.1, gs, mat, 'body', 'loose', k=1.0)
        if L == 'short':
            _limb_cut(sc, gs, Hj, K, 0.45)
        elif L == 'knee':
            sc.cone(K, A, b['cf'][0] + t + lo, b['cf'][0] + t + lo, gs, mat, 'body', 'knee', k=0.8)
            _limb_cut(sc, gs, K, A, 0.12)
        else:
            _limb_cut(sc, gs, K, A, 0.93)
    _hem_top = {'waist': b['waist'] - 0.2, 'hip': b['pelvis'] + 1.2}[o.get('top', 'waist')]
    sc.plane(f.PP(0, _hem_top, 0), f.Rh @ v(0, 1, 0), g, op=INTERSECT, k=0.3)
    return g


def part_boots(sc, f, gname, o):
    b, J = f.b, f.J
    mat = MAT[o.get('mat', 'leather')]
    t = o.get('t', 0.5)
    hgt = o.get('height', 'mid')
    sole = MAT[o.get('sole', 'dark')]
    for s, sg in SIDE.items():
        K, A = J['knee_' + s], J['ankle_' + s]
        fd = J['foot_dir_' + s]
        up = v(0, 1, 0) if abs(f.sk.pose.p.get('roll', 0.0)) < 1e-6 else f.Rh @ v(0, 1, 0)
        flat = norm(fd - up * np.dot(fd, up))
        side = norm(np.cross(up, flat))
        ax = np.stack([side, up, flat])
        g = sc.group('%s_%s' % (gname, s), 0.0)
        L = b['foot']
        heel = A - up * (b['ankle'] * 0.62) - flat * 0.9
        ball = heel + flat * (L * 0.72) - up * 0.15
        hu = J['heel_' + s]
        if hu > 0.01:
            heel = ball - flat * (L * 0.72) * math.cos(hu) + up * (L * 0.72 * math.sin(hu))
        toe = ball + flat * (L * 0.26)
        # the boot is the foot's own solids inflated (so no toe ever shows through), plus the shaft and a sole
        shell(sc, f, {'heel', 'foot', 'toes', 'ankle'}, g, mat, t, layer='body', k=0.8, groups={'foot_' + s})
        top = {'ankle': 0.18, 'mid': 0.42, 'knee': 0.9}[hgt]
        sc.cone(A + (K - A) * top, heel + up * 0.9, b['cf'][1] + t + (b['cf'][0] - b['cf'][1]) * top * 0.9, 1.25 + t, g, mat, 'body', 'shaft', k=0.8)
        gs = sc.group('%s_sole_%s' % (gname, s), 0.0)
        # the sole: a darker slab under the whole foot
        mid = (heel + toe) / 2 - up * 1.05
        sc.box(mid, (1.55 + t, 0.42, np.linalg.norm(toe - heel) * 0.5 + 1.4), ax, 0.35, gs, sole, 'body', 'sole')


def part_gloves(sc, f, gname, o, pose):
    from anatomy import build_fist
    mat = MAT[o.get('mat', 'leather2')]
    t = o.get('t', 0.3)
    b = f.b
    for s in ('r', 'l'):
        # a fist one shell larger: reuse the fist builder on an inflated hand
        hx, hy, hz = b['hand']
        J = f.J
        Wr = J['wrist_' + s]
        fd, gd = J['fist_' + s], J['grip_' + s]
        gd = norm(gd - fd * np.dot(gd, fd))
        side = norm(np.cross(gd, fd))
        lay = arm_layer(s, pose, 'hand')
        g = sc.group('%s_%s' % (gname, s), 0.3, parent=None)
        c = Wr + fd * (hy * 0.95)
        axes = np.stack([gd, fd, side])
        sc.box(c, (hx * 0.95 + t, hy + t, hz + t), axes, min(hx, hz) * 0.75 + t, g, mat, lay, 'palm')
        sc.ellipsoid(c + fd * (hy * 0.55) + side * (hz * 0.25), (hx * 1.02 + t, hy * 0.62 + t, hz * 1.05 + t), axes, g, mat, lay, 'knuckles', k=0.5)
        th0 = c - gd * (hx * 0.55) + side * (hz * 0.5)
        sc.cone(th0 - fd * (hy * 0.4), th0 + fd * (hy * 0.35) + side * 0.4, hz * 0.52 + t, hz * 0.45 + t, g, mat, lay, 'thumb', k=0.4)
        sc.cone(Wr - fd * 2.0, c - fd * (hy * 0.4), b['fa'][1] + t + 0.15, hx * 0.85 + t, g, mat, lay, 'cuff', k=0.5)


def part_skirt(sc, f, gname, o):
    """coat tails / skirt: a flared panel per leg from the hip, joined at the seat, so it opens as the legs stride"""
    b, J = f.b, f.J
    mat = MAT[o.get('mat', 'cloth2')]
    t = o.get('t', 0.45)
    fl = o.get('flare', 1.6)
    L = o.get('len', 'knee')
    end = {'thigh': 0.55, 'knee': 1.05, 'calf': 1.45}[L]
    g = sc.group(gname, 0.0)
    pel = b['pel']
    sc.ellipsoid(f.PP(0, b['pelvis'] - 0.4, -0.2), (pel[0] + t + 0.5, pel[1] + t + 0.8, pel[2] + t + 0.6), f.pel_axes(), g, mat, 'body', 'seat')
    for s, sg in SIDE.items():
        Hj, K, A = J['hip_' + s], J['knee_' + s], J['ankle_' + s]
        tip = K + (A - K) * (end - 1.0) if end > 1.0 else Hj + (K - Hj) * end
        outw = f.Rh @ v(sg * 0.6, 0, -0.35)
        sc.cone(Hj + v(0, 1.4, 0) + outw * 0.4, tip + outw * fl, b['th'][0] + t + 0.4, b['th'][1] + t + fl, g, mat, 'body', 'tail', k=1.6)
    # hem across both panels (level with the lower knee) and the front opening
    low = min(J['knee_r'][1], J['knee_l'][1])
    hy = {'thigh': (J['hip_r'][1] + low) / 2, 'knee': low - 1.0, 'calf': low - (b['knee'] - b['ankle']) * 0.45}[L]
    sc.plane(v(0, hy, 0), v(0, -1, 0), g, op=INTERSECT, k=0.4)
    sc.plane(f.PP(0, b['pelvis'] + 1.0, 0), f.Rh @ v(0, 1, 0), g, op=INTERSECT, k=0.3)
    if o.get('open', True):
        sc.box(f.PP(0.2, b['hipj'] - 8.0, pel[2] + 3.0), (o.get('gap', 1.6), 12.0, 3.6), f.pel_axes(), 0.3, g, mat, 'body', 'slit', op=SUBTRACT,
               k=0.4)


def part_collar(sc, f, gname, o):
    b, J = f.b, f.J
    mat = MAT[o.get('mat', 'cloth2')]
    t = o.get('t', 0.5)
    h = o.get('h', 2.2)
    g = sc.group(gname, 0.0)
    nr = b['neck_r'][0]
    base = f.CP(0, b['neck'] - 1.6, -0.6)
    topc = f.CP(0, b['neck'] - 1.6 + h + 0.8, -0.9)
    sc.cone(base, topc, nr + t + 1.4, nr + t + 1.0, g, mat, 'body', 'collar')
    sc.cone(base - f.up() * 2, topc + f.up() * 2, nr + 0.5, nr + 0.4, g, mat, 'body', 'inner', op=SUBTRACT, k=0.2)
    if o.get('open', True):
        sc.box(f.CP(0, b['neck'], b['rib'][2] + 0.6), (1.6, h + 2.0, 2.6), f.chest_axes(), 0.4, g, mat, 'body', 'gap', op=SUBTRACT, k=0.3)


def part_belt(sc, f, gname, o):
    b = f.b
    mat = MAT[o.get('mat', 'leather')]
    y = {'waist': b['waist'] - 0.8, 'hip': b['pelvis'] + 0.6}[o.get('y', 'waist')]
    w = o.get('w', 1.4)
    g = sc.group(gname, 0.0)
    abd, pel = b['abd'], b['pel']
    rx = (abd[0] * b['waist_pinch'] + pel[0]) * 0.5 + 0.9
    rz = (abd[2] + pel[2]) * 0.5 + 0.9
    sc.ellipsoid(f.PP(0, y, 0.0), (rx, w * 1.6, rz), f.pel_axes(), g, mat, 'body', 'belt')
    sc.plane(f.PP(0, y + w * 0.5, 0), f.Rh @ v(0, 1, 0), g, op=INTERSECT, k=0.2)
    sc.plane(f.PP(0, y - w * 0.5, 0), f.Rh @ v(0, -1, 0), g, op=INTERSECT, k=0.2)
    if o.get('buckle'):
        gb = sc.group(gname + '_b', 0.0)
        sc.box(f.PP(0.4, y, rz - 0.1), (1.0, w * 0.55, 0.45), f.pel_axes(), 0.2, gb, MAT[o['buckle']], 'body', 'buckle')


def part_plate(sc, f, gname, o, pose):
    """armour plates on named places"""
    b, J = f.b, f.J
    mat = MAT[o.get('mat', 'poly')]
    t = o.get('t', 0.9)
    sz = o.get('size', 1.0)
    at = o['at']
    g = sc.group(gname + '_' + at, 0.4)
    ca = f.chest_axes()
    rib = b['rib']
    if at == 'chest':
        sc.box(f.CP(0, b['chest'] + 0.6, rib[2] + t * 0.3 + (1.4 * b['bust'] if b.fem else 0)), (rib[0] * 0.86 * sz, 4.8 * sz, 1.6 + t),
               ca, 1.4, g, mat, 'body', 'chest_plate')
        sc.ellipsoid(f.CP(0, b['chest'], 0), (rib[0] + t + 0.7, rib[1] + 0.6, rib[2] + t + 0.6), ca, g, mat, 'body', 'wrap', k=0.8)
        sc.plane(f.CP(0, b['chest'] - 5.2 * sz, 0), f.Rs @ v(0, -1, 0), g, op=INTERSECT, k=0.3)
        sc.plane(f.CP(0, b['shoulder'] - 0.2, 0), f.Rs @ v(0, 1, 0), g, op=INTERSECT, k=0.3)
        for sg in (1.0, -1.0):
            sc.ellipsoid(f.CP(sg * (rib[0] + 0.2), b['chest'] + 2.6, 0.2), (2.2, 3.0, 3.0), ca, g, mat, 'body', 'armhole', op=SUBTRACT, k=0.5)
    elif at == 'abdomen':
        for i, y in enumerate((b['waist'] + 2.0, b['waist'] - 0.4)):
            sc.box(f.CP(0, y, b['abd'][2] + 0.6), (b['abd'][0] * 0.8, 1.05, 0.9 + t * 0.5), ca, 0.5, g, mat, 'body', 'ab%d' % i, k=0.2)
    elif at == 'back':
        sc.box(f.CP(0, b['chest'] + 1.0, -rib[2] - 0.8), (rib[0] * 0.8, 5.0, 1.4), ca, 1.0, g, mat, 'body', 'back_plate')
    elif at == 'shoulders':
        for s, sg in SIDE.items():
            S = J['sh_' + s]
            up = norm(S - J['neck'])
            lay = arm_layer(s, pose, 'arm')
            gs = sc.group('%s_%s_%s' % (gname, at, s), 0.0)
            ax = _bone_axes(S, J['elbow_' + s], up)
            sc.ellipsoid(S + up * 0.9 + v(0, 0.6, 0), (b['ua'][0] + 1.4 * sz + t * 0.4, 2.2 * sz + 0.6, b['ua'][0] + 1.5 * sz + t * 0.4), ax, gs, mat,
                         lay, 'pauldron')
            sc.plane(S + (J['elbow_' + s] - S) * 0.3, norm(J['elbow_' + s] - S), gs, op=INTERSECT, k=0.3)
    elif at in ('forearms', 'shins', 'thighs', 'knees'):
        for s, sg in SIDE.items():
            if at == 'forearms':
                a0, a1, r = J['elbow_' + s], J['wrist_' + s], b['fa'][0]
                lay, f0, f1 = arm_layer(s, pose, 'arm'), 0.2, 0.85
            elif at == 'shins':
                a0, a1, r = J['knee_' + s], J['ankle_' + s], b['cf'][0]
                lay, f0, f1 = 'body', 0.05, 0.72
            elif at == 'thighs':
                a0, a1, r = J['hip_' + s], J['knee_' + s], b['th'][0]
                lay, f0, f1 = 'body', 0.3, 0.8
            else:
                a0, a1, r = J['hip_' + s], J['knee_' + s], b['th'][1]
                lay, f0, f1 = 'body', 0.86, 1.08
            gs = sc.group('%s_%s_%s' % (gname, at, s), 0.0)
            ax = _bone_axes(a0, a1, v(sg, 0, 0))
            p0, p1 = a0 + (a1 - a0) * f0, a0 + (a1 - a0) * f1
            front = ax[2]
            if at == 'forearms':
                front = norm(np.cross(ax[1], v(0, 0, 1)) * -sg + ax[2] * 0.3)
            c = (p0 + p1) / 2 + front * (r * 0.55)
            sc.ellipsoid(c, (r * 0.95 + t * 0.6, np.linalg.norm(p1 - p0) * 0.5 + 0.4, r * 0.72 + t * 0.6), ax, gs, mat, lay, at[:-1])
            sc.plane(c - front * 0.2, -front, gs, op=INTERSECT, k=0.6)


def part_pocket(sc, f, gname, o):
    b, J = f.b, f.J
    mat = MAT[o.get('mat', 'cloth3')]
    at = o['at']
    g = sc.group(gname + '_' + at, 0.3)
    if at.startswith('thigh'):
        s = at[-1]
        sg = SIDE[s]
        Hj, K = J['hip_' + s], J['knee_' + s]
        ax = _bone_axes(Hj, K, f.Rh @ v(sg, 0, 0))
        c = Hj + (K - Hj) * 0.55 + ax[0] * (b['th'][0] + 0.25) * 0.85 + ax[2] * 0.6
        sc.box(c, (0.9, 2.3, 1.7), ax, 0.4, g, mat, 'body', 'pocket')
    else:
        sg = 1.0 if at.endswith('r') else -1.0
        sc.box(f.CP(sg * b['rib'][0] * 0.5, b['chest'] + 1.2, b['rib'][2] + 0.5 + (1.6 * b['bust'] if b.fem else 0)), (1.6, 1.5, 0.7),
               f.chest_axes(), 0.35, g, mat, 'body', 'pocket')


def _named(f, name):
    b, J = f.b, f.J
    rib = b['rib']
    pts = {'sh_r': J['sh_r'] + f.Rs @ v(-1.2, 0.8, 0.6), 'sh_l': J['sh_l'] + f.Rs @ v(1.2, 0.8, 0.6),
           'hip_r': f.PP(b['pel'][0] * 0.8, b['pelvis'] + 1.0, b['pel'][2] * 0.6), 'hip_l': f.PP(-b['pel'][0] * 0.8, b['pelvis'] + 1.0, b['pel'][2] * 0.6),
           'chest': f.CP(0, b['chest'], rib[2] + 0.4), 'waist_r': f.CP(rib[0] * 0.6, b['waist'], b['abd'][2]),
           'waist_l': f.CP(-rib[0] * 0.6, b['waist'], b['abd'][2])}
    return pts[name]


def part_strap(sc, f, gname, o):
    mat = MAT[o.get('mat', 'leather')]
    a, c = _named(f, o['from']), _named(f, o['to'])
    g = sc.group(gname + '_' + o['from'] + o['to'], 0.3)
    # sag the strap over the chest: a mid point pushed forward so it lies on the torso
    m = (a + c) / 2 + f.Rs @ v(0, 0, 1.6 + (1.4 * f.b['bust'] if f.b.fem else 0))
    w = o.get('w', 0.6)
    sc.cone(a, m, w, w, g, mat, 'body', 'strap', k=0.3)
    sc.cone(m, c, w, w, g, mat, 'body', 'strap', k=0.3)


def part_hood(sc, f, gname, o):
    b = f.b
    mat = MAT[o.get('mat', 'cloth2')]
    t = o.get('t', 0.8)
    rx, ry, rz = b['head_r']
    g = sc.group(gname, 0.0)
    ha = f.head_axes()
    if o.get('up', True):
        sc.ellipsoid(f.HP(0, 0.6, -0.8), (rx + t + 0.6, ry + t + 0.3, rz + t + 0.8), ha, g, mat, 'body', 'hood')
        sc.ellipsoid(f.HP(0, -0.8, rz * 0.9 + 1.0), (rx * 0.78, ry * 0.85, rz * 0.9), ha, g, mat, 'body', 'face_open', op=SUBTRACT, k=0.6)
        sc.cone(f.HP(0, -3.0, -1.5), f.CP(0, b['neck'] - 1.0, -1.6), rx + t * 0.5, b['neck_r'][0] + t + 1.2, g, mat, 'body', 'drape', k=1.2)
    else:
        sc.ellipsoid(f.CP(0, b['neck'] - 0.4, -b['rib'][2] - 0.6), (b['sh_x'] * 0.6, 2.6, 2.0), f.chest_axes(), g, mat, 'body', 'hood_down')


def part_helmet(sc, f, gname, o):
    b = f.b
    mat = MAT[o.get('mat', 'poly')]
    t = o.get('t', 1.1)
    rx, ry, rz = b['head_r']
    g = sc.group(gname, 0.0)
    ha = f.head_axes()
    sc.ellipsoid(f.HP(0, 0.9, -0.4), (rx + t, ry * 0.92 + t, rz + t), ha, g, mat, 'body', 'shell')
    sc.plane(f.HP(0, o.get('rim', 0.9), 0), f.Rhd @ v(0, -1, 0.12), g, op=INTERSECT, k=0.3)
    if o.get('brim'):
        sc.ellipsoid(f.HP(0, o.get('rim', 0.9) + 0.3, rz * 0.5), (rx + t + 0.6, 0.45, rz + t + 1.2), ha, g, mat, 'body', 'brim', k=0.3)
    if o.get('visor'):
        gv = sc.group(gname + '_v', 0.0)
        sc.ellipsoid(f.HP(0, 0.3, rz * 0.55), (rx * 0.95 + t * 0.6, 1.9, rz * 0.62 + t), ha, gv, MAT[o['visor']], 'body', 'visor')
        sc.plane(f.HP(0, 0.0, 0.6), f.Rhd @ v(0, 0, -1), gv, op=INTERSECT, k=0.3)


def part_mask(sc, f, gname, o):
    b = f.b
    mat = MAT[o.get('mat', 'cloth1')]
    rx, ry, rz = b['head_r']
    g = sc.group(gname, 0.0)
    ha = f.head_axes()
    if o.get('cover', 'lower') == 'lower':
        sc.ellipsoid(f.HP(0, -1.9, 0.9), (rx * 0.92 + 0.4, ry * 0.62, rz * 0.86 + 0.5), ha, g, mat, 'body', 'mask')
        sc.plane(f.HP(0, -0.35, 0), f.Rhd @ v(0, 1, -0.1), g, op=INTERSECT, k=0.3)
        sc.cone(f.HP(0, -3.2, -0.6), f.CP(0, b['neck'] - 1.0, -0.4), rx * 0.7, b['neck_r'][0] + 0.6, g, mat, 'body', 'neck', k=0.8)
    else:
        sc.ellipsoid(f.HP(0, 0.4, -0.3), (rx + 0.45, ry * 0.94 + 0.45, rz + 0.45), ha, g, mat, 'body', 'balaclava')
        sc.cone(f.HP(0, -3.2, -0.6), f.CP(0, b['neck'] - 1.0, -0.4), rx * 0.72, b['neck_r'][0] + 0.6, g, mat, 'body', 'neck', k=0.8)
        sc.box(f.HP(0, 0.45, rz * 0.9), (rx * 0.78, 0.85, 1.6), ha, 0.4, g, mat, 'body', 'eyeslot', op=SUBTRACT, k=0.2)


BUILDERS = {'torso': part_torso, 'sleeves': part_sleeves, 'legs': part_legs, 'boots': part_boots, 'gloves': part_gloves,
            'skirt': part_skirt, 'collar': part_collar, 'belt': part_belt, 'plate': part_plate, 'pocket': part_pocket, 'strap': part_strap,
            'hood': part_hood, 'helmet': part_helmet, 'mask': part_mask}
NEEDS_POSE = {'sleeves', 'gloves', 'plate'}


def build_garment(sc, sk, spec):
    """add every part of a garment; returns its marks (seams, folds, zips)"""
    f = F(sk)
    for i, part in enumerate(spec['parts']):
        typ = part['type']
        name = '%s_%d_%s' % (spec['id'], i, typ)
        if typ in NEEDS_POSE:
            BUILDERS[typ](sc, f, name, part, sk.pose)
        else:
            BUILDERS[typ](sc, f, name, part)
    return garment_marks(sk, spec, sc)


def garment_marks(sk, spec, sc):
    """seams, closures and folds: elbows and knees that bend fold the cloth; jackets show their front edge; coats a back vent"""
    f = F(sk)
    b, J = f.b, f.J
    marks = []
    groups = set(sc.groups)
    for i, part in enumerate(spec['parts']):
        typ = part['type']
        base = '%s_%d_%s' % (spec['id'], i, typ)
        if typ == 'sleeves' and part.get('len', 'long') in ('long', 'elbow'):
            for s in ('r', 'l'):
                S, E, Wr = J['sh_' + s], J['elbow_' + s], J['wrist_' + s]
                bend = math.acos(max(-1, min(1, np.dot(norm(E - S), norm(Wr - E)))))
                if bend > 0.45:
                    inner = norm((S - E) + (Wr - E))
                    for k in (-0.9, 0.9):
                        p = E + inner * (b['ua'][1] * 0.5)
                        q = E + norm(Wr - E) * (1.6 + 0.6 * k) + inner * (b['fa'][0] + 0.4)
                        marks.append(dict(pts=[p, q], d=-1, groups={'%s_%s' % (base, s), '%s_fa_%s' % (base, s)},
                                          mats=(MAT[part.get('mat', 'cloth1')],), tol=4.0))
        if typ == 'legs':
            for s, sg in SIDE.items():
                Hj, K, A = J['hip_' + s], J['knee_' + s], J['ankle_' + s]
                bend = math.acos(max(-1, min(1, np.dot(norm(K - Hj), norm(A - K)))))
                ax = _bone_axes(K, A, f.Rh @ v(sg, 0, 0))
                if part.get('len', 'long') == 'long':
                    # knee folds, stronger when bent; a side seam
                    n = 2 if bend > 0.35 else 1
                    for j in range(n):
                        y = 0.4 + 1.3 * j
                        marks.append(dict(pts=[K + ax[2] * (b['cf'][0] + 0.5) + (A - K) * (0.04 * y) - ax[0] * 1.4,
                                               K + ax[2] * (b['cf'][0] + 0.5) + (A - K) * (0.04 * y + 0.06) + ax[0] * 1.0],
                                          d=-1, groups={'%s_%s' % (base, s)}, mats=(MAT[part.get('mat', 'cloth3')],), tol=4.0))
        if typ == 'torso' and part.get('open', 0) > 0:
            pass
        if typ == 'torso' and part.get('seam', False):
            marks.append(dict(pts=[f.CP(0.2, b['neck'] - 1.4, b['rib'][2] + 0.6), f.CP(0.2, b['waist'] - 1.0, b['abd'][2] + 0.6)], d=-1,
                              groups={base}, mats=(MAT[part.get('mat', 'cloth1')],), tol=4.0))
    return marks
