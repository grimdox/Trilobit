"""Scene building and ray marching (thin wrapper over libsdfcore.so).

Coordinates: character space is X = the character's right, Y = up, Z = forward, 1 unit = 1 sprite pixel at LOD 64.
Camera space (what the core sees) is x = screen right, y = screen down, z = toward the viewer.  The camera turns the
character three-quarters toward screen right and looks down a little (Camera.yaw, Camera.pitch)."""
import ctypes
import math
import os
import subprocess

import numpy as np

_HERE = os.path.dirname(os.path.abspath(__file__))
_LIB = os.path.join(_HERE, 'libsdfcore.so')


def _load():
    src = os.path.join(_HERE, 'sdfcore.c')
    if not os.path.exists(_LIB) or os.path.getmtime(_LIB) < os.path.getmtime(src):
        subprocess.check_call(['cc', '-O2', '-shared', '-fPIC', '-o', _LIB, src, '-lm'])
    lib = ctypes.CDLL(_LIB)
    f = ctypes.POINTER(ctypes.c_float)
    lib.render.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_float, ctypes.c_float, ctypes.c_float, ctypes.c_float, ctypes.c_float,
                           f, ctypes.c_int, f, f, ctypes.POINTER(ctypes.c_int), ctypes.c_int, ctypes.POINTER(ctypes.c_ubyte), f, f,
                           ctypes.POINTER(ctypes.c_int), ctypes.c_int, f]
    lib.render.restype = ctypes.c_int
    return lib


LIB = _load()
PSTRIDE = 32
UNION, SUBTRACT, INTERSECT = 0, 1, 2


# ------------------------------------------------------------------------------------------------ vectors
def v(*a):
    return np.array(a, dtype=np.float64)


def norm(a):
    a = np.asarray(a, dtype=np.float64)
    n = np.linalg.norm(a)
    return a / n if n > 1e-12 else a


def frame_from(fwd, up_hint=(0, 1, 0)):
    """an orthonormal basis (x, y, z) whose y runs along `fwd`; used to orient ellipsoids and boxes along a bone"""
    y = norm(fwd)
    h = np.asarray(up_hint, dtype=np.float64)
    if abs(np.dot(h, y)) > 0.95:
        h = np.array([1.0, 0, 0]) if abs(y[0]) < 0.9 else np.array([0, 0, 1.0])
    x = norm(np.cross(y, h))
    z = norm(np.cross(x, y))
    return np.stack([x, y, z])


def rot_axis(axis, ang):
    axis = norm(axis)
    c, s = math.cos(ang), math.sin(ang)
    x, y, z = axis
    return np.array([[c + x * x * (1 - c), x * y * (1 - c) - z * s, x * z * (1 - c) + y * s],
                     [y * x * (1 - c) + z * s, c + y * y * (1 - c), y * z * (1 - c) - x * s],
                     [z * x * (1 - c) - y * s, z * y * (1 - c) + x * s, c + z * z * (1 - c)]])


class Camera:
    def __init__(self, yaw_deg=22.0, pitch_deg=10.0, origin=(40.0, 88.0), mirror=False, scale=1.0):
        """scale: sprite pixels per unit (1 for the 64 px set, 0.5 for the 32 px world set)"""
        self.yaw, self.pitch = math.radians(yaw_deg), math.radians(pitch_deg)
        self.origin = origin
        self.s = scale
        sy, cy = math.sin(self.yaw), math.cos(self.yaw)
        right = np.array([-cy, 0.0, sy])          # the character's right, in camera space (screen left, toward viewer)
        up = np.array([0.0, 1.0, 0.0])
        fwd = np.array([sy, 0.0, cy])
        Ryaw = np.stack([right, up, fwd], axis=1)  # columns: where the character's X, Y, Z axes go
        sp, cp = math.sin(self.pitch), math.cos(self.pitch)
        Rp = np.array([[1, 0, 0], [0, cp, -sp], [0, sp, cp]])
        R = Rp @ Ryaw
        flip = np.diag([1.0, -1.0, 1.0])            # camera y points down the screen
        self.R = flip @ R

    def pt(self, p):
        q = (self.R @ np.asarray(p, dtype=np.float64)) * self.s
        return np.array([q[0] + self.origin[0], q[1] + self.origin[1], q[2]])

    def vec(self, d):
        return self.R @ np.asarray(d, dtype=np.float64)

    def screen(self, p):
        q = self.pt(p)
        return q[0], q[1]


# ------------------------------------------------------------------------------------------------ scene
class Scene:
    """primitives in character space; `group` strings keep smooth unions local; tags and layers ride along"""

    def __init__(self, cam):
        self.cam = cam
        self.recs = []          # float records
        self.meta = []          # dict per primitive: material, layer, tag, group name
        self.groups = []        # group names in order of first use
        self.gjoin = {}
        self.gparent = {}       # group -> the group it smooth-joins into (None: a hard union with everything)

    def group(self, name, join=0.0, parent='auto'):
        """parent: the group this one smooth-joins into.  'auto' (the default): the scene's first group when join > 0
        (an item's parts into its base part), none when join == 0"""
        if name not in self.gjoin:
            self.groups.append(name)
        self.gjoin[name] = join * self.cam.s
        if parent == 'auto':
            parent = self.groups[0] if (join > 0 and self.groups[0] != name) else None
        if name not in self.gparent or parent is not None:
            self.gparent[name] = parent
        return name

    def _rec(self, typ, group, op, k, material, layer, tag):
        if group not in self.gjoin:
            self.group(group)
        r = np.zeros(PSTRIDE, np.float32)
        r[0], r[2], r[3] = typ, op, k
        self.meta.append({'material': material, 'layer': layer, 'tag': tag, 'group': group, 'op': op})
        return r

    def _push(self, r, bounds):
        self.recs.append((r, bounds))
        return len(self.recs) - 1

    def cone(self, a, b, ra, rb, group, material, layer, tag='', op=UNION, k=0.0):
        A, B = self.cam.pt(a), self.cam.pt(b)
        S = self.cam.s
        ra, rb, k = ra * S, rb * S, k * S
        r = self._rec(0, group, op, k, material, layer, tag)
        r[8:11], r[11:14], r[14], r[15] = A, B, ra, rb
        m = max(ra, rb) + k + 1.0
        bb = (min(A[0], B[0]) - m, min(A[1], B[1]) - m, max(A[0], B[0]) + m, max(A[1], B[1]) + m)
        return self._push(r, bb if op == UNION else None)

    def ellipsoid(self, c, radii, axes, group, material, layer, tag='', op=UNION, k=0.0):
        """axes: 3x3 rows = the ellipsoid's local x, y, z directions in character space"""
        C = self.cam.pt(c)
        S = self.cam.s
        radii, k = tuple(float(x) * S for x in radii), k * S
        Ax = np.stack([self.cam.vec(a) for a in axes])
        r = self._rec(1, group, op, k, material, layer, tag)
        r[8:11], r[11:14], r[14:23] = C, radii, Ax.reshape(-1)
        m = max(radii) + k + 1.0
        return self._push(r, (C[0] - m, C[1] - m, C[0] + m, C[1] + m) if op == UNION else None)

    def box(self, c, half, axes, rounding, group, material, layer, tag='', op=UNION, k=0.0):
        C = self.cam.pt(c)
        S = self.cam.s
        half, rounding, k = tuple(float(x) * S for x in half), rounding * S, k * S
        Ax = np.stack([self.cam.vec(a) for a in axes])
        r = self._rec(2, group, op, k, material, layer, tag)
        r[8:11], r[11:14], r[14:23], r[23] = C, half, Ax.reshape(-1), rounding
        m = float(np.linalg.norm(half)) + k + 1.0
        return self._push(r, (C[0] - m, C[1] - m, C[0] + m, C[1] + m) if op == UNION else None)

    def plane(self, point, normal, group, layer='', op=INTERSECT, k=0.0):
        """keep the side the normal points away from (distance = dot(p - point, n))"""
        P = self.cam.pt(point)
        n = norm(self.cam.vec(normal))
        k = k * self.cam.s
        r = self._rec(3, group, op, k, 0, layer, 'plane')
        r[8:11], r[11] = n, float(np.dot(P, n))
        return self._push(r, None)

    def torus(self, c, R, rr, axes, group, material, layer, tag='', op=UNION, k=0.0):
        C = self.cam.pt(c)
        S = self.cam.s
        R, rr, k = R * S, rr * S, k * S
        Ax = np.stack([self.cam.vec(a) for a in axes])
        r = self._rec(4, group, op, k, material, layer, tag)
        r[8:11], r[11], r[12], r[14:23] = C, R, rr, Ax.reshape(-1)
        m = R + rr + k + 1.0
        return self._push(r, (C[0] - m, C[1] - m, C[0] + m, C[1] + m) if op == UNION else None)

    # -------------------------------------------------------------------------------------------- render
    def render(self, W, H, ss=3, zrange=(80.0, -80.0), maxsteps=96, keep=None):
        """W x H sprite pixels, ss samples per pixel each way.  keep: optional predicate on meta to restrict the scene.
        returns dict of sample arrays (H*ss, W*ss): hit, z, n (..., 3), prim"""
        order = []
        for gi, g in enumerate(self.groups):
            for i, (r, bb) in enumerate(self.recs):
                if self.meta[i]['group'] == g and (keep is None or keep(self.meta[i])):
                    order.append(i)
        n = len(order)
        prims = np.zeros((max(n, 1), PSTRIDE), np.float32)
        bounds = np.zeros((max(n, 1), 4), np.float32)
        gidx = {g: i for i, g in enumerate(self.groups)}
        for j, i in enumerate(order):
            r, bb = self.recs[i]
            prims[j] = r
            prims[j, 1] = gidx[self.meta[i]['group']]
            bounds[j] = bb if bb is not None else (-1e9, -1e9, 1e9, 1e9)
        gjoin = np.array([self.gjoin[g] for g in self.groups] or [0.0], np.float32)
        gpar = np.array([gidx[self.gparent[g]] if self.gparent.get(g) in gidx else -1 for g in self.groups] or [-1], np.int32)
        Ws, Hs = W * ss, H * ss
        hit = np.zeros(Ws * Hs, np.uint8)
        z = np.zeros(Ws * Hs, np.float32)
        nrm = np.zeros(Ws * Hs * 3, np.float32)
        pid = np.zeros(Ws * Hs, np.int32)
        occ = np.zeros(Ws * Hs, np.float32)
        fp = ctypes.POINTER(ctypes.c_float)
        LIB.render(Ws, Hs, float(ss), 0.0, 0.0, float(zrange[0]), float(zrange[1]),
                   prims.ctypes.data_as(fp), n, bounds.ctypes.data_as(fp), gjoin.ctypes.data_as(fp),
                   gpar.ctypes.data_as(ctypes.POINTER(ctypes.c_int)), len(self.groups),
                   hit.ctypes.data_as(ctypes.POINTER(ctypes.c_ubyte)), z.ctypes.data_as(fp), nrm.ctypes.data_as(fp),
                   pid.ctypes.data_as(ctypes.POINTER(ctypes.c_int)), maxsteps, occ.ctypes.data_as(fp))
        pid = pid.reshape(Hs, Ws)
        # map back from the ordered index to the scene's primitive index
        lut = np.array(order + [-1], np.int64)
        pid = np.where(pid >= 0, lut[np.clip(pid, 0, max(n - 1, 0))], -1)
        return {'hit': hit.reshape(Hs, Ws).astype(bool), 'z': z.reshape(Hs, Ws), 'n': nrm.reshape(Hs, Ws, 3), 'prim': pid,
                'ao': occ.reshape(Hs, Ws),
                'ss': ss, 'W': W, 'H': H}


def copy_shell(dst, src, select, inflate, group, material, layer=None, k=None, tag=None):
    """copy primitives of `src` chosen by select(meta) into `dst`, grown by `inflate` (a shell around them: clothing,
    prosthetic casings).  Union primitives only; their own blend radius is kept unless k is given."""
    n = 0
    for i, (rec, bb) in enumerate(src.recs):
        m = src.meta[i]
        if m['op'] != UNION or not select(m):
            continue
        r = rec.copy()
        typ = int(r[0])
        t = (inflate(m) if callable(inflate) else inflate) * dst.cam.s
        if typ == 0:
            r[14] += t
            r[15] += t
        elif typ == 1:
            r[11:14] += t
        elif typ == 2:
            r[11:14] += t
            r[23] += t
        elif typ == 4:
            r[12] += t
        if k is not None:
            r[3] = k * dst.cam.s
        if group not in dst.gjoin:
            dst.group(group)
        dst.meta.append({'material': material, 'layer': layer or m['layer'], 'tag': tag or m['tag'], 'group': group, 'op': UNION})
        g = t + (k or 0) + 0.5
        dst.recs.append((r, (bb[0] - g, bb[1] - g, bb[2] + g, bb[3] + g)))
        n += 1
    return n
