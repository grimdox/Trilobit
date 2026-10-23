"""Hair styles as solids on the skull.

Each style is built in the head's own frame (x = the character's right, y = up, z = forward) from the skull's radii,
so it fits every body.  Most styles are a cap (an ellipsoid a little larger than the cranium, cut at the hairline and
the nape, with the face cut out) plus the forms that make the style: a fringe, side panels, a crest, a tail.
Hanging parts (ponytail, braid, long hair) follow `pose['sway']` so they swing in the walk.  Strand lines are surface
marks running from the crown along the flow of the style.  Brows are not here: they belong to the face (face.py).

Layers: 'hair' for every part; the frame renderer splits it into the front slot and, where the body is in front of
it, the back slot.
"""
import math

import numpy as np

from sdf import v, norm, INTERSECT, SUBTRACT, UNION
import materials as M

STYLES = ['bald', 'buzz', 'crop', 'pixie', 'undercut', 'slick', 'mohawk', 'bob', 'shag', 'long', 'ponytail', 'bun', 'braid', 'topknot']
STYLE_NAMES = {'bald': 'Bald', 'buzz': 'Buzz cut', 'crop': 'Crop', 'pixie': 'Pixie', 'undercut': 'Undercut', 'slick': 'Slicked back',
               'mohawk': 'Mohawk', 'bob': 'Bob', 'shag': 'Shag', 'long': 'Long', 'ponytail': 'Ponytail', 'bun': 'Bun', 'braid': 'Braid',
               'topknot': 'Topknot'}
# styles that leave the ears clear (helmets and head implants check this)
SHORT = {'bald', 'buzz', 'crop', 'pixie', 'undercut', 'slick', 'mohawk', 'topknot'}


class HeadFrame:
    def __init__(self, sk):
        b, J = sk.body, sk.J
        self.R = J['R_head']
        self.c = J['head']
        self.rx, self.ry, self.rz = b['head_r']
        self.sk = sk
        self.sway = np.asarray(sk.pose.p.get('sway', (0.0, 0.0, 0.0)), float)

    def P(self, x, y, z):
        return self.c + self.R @ v(x, y, z)

    def D(self, x, y, z):
        return self.R @ v(x, y, z)

    def axes(self):
        return np.stack([self.R @ v(1, 0, 0), self.R @ v(0, 1, 0), self.R @ v(0, 0, 1)])


def _cap(sc, h, g, t, hairline=1.6, nape=-2.2, ears=True, front_tilt=0.75, tag='cap'):
    """the cap: skull + t, kept above a hairline plane tilted back over the forehead and above a nape plane"""
    rx, ry, rz = h.rx, h.ry, h.rz
    sc.ellipsoid(h.P(0, 0.62, -0.42), (rx + t, ry * 0.92 + t, rz + t), h.axes(), g, M.HAIR, 'hair', tag)
    # hairline: at the forehead the cap stops at `hairline`; the plane tilts so the cap reaches far down at the back
    sc.plane(h.P(0, hairline, rz * 0.8), h.D(0, -1, front_tilt), g, op=INTERSECT, k=0.35)
    # nape: the lowest edge at the back of the head, sloping lower toward the back
    sc.plane(h.P(0, nape, 0), h.D(0, -1, 0.35), g, op=INTERSECT, k=0.35)
    if ears:
        # clear the ears: cut the sides above the ear top in front of the ear's back edge
        for sg in (1.0, -1.0):
            sc.ellipsoid(h.P(sg * rx * 1.02, -1.3, 0.6), (1.1, 1.7, 1.4), h.axes(), g, M.HAIR, 'hair', 'earcut', op=SUBTRACT, k=0.3)
    # never cover the face
    sc.ellipsoid(h.P(0, -2.0, rz * 0.95), (rx * 0.82, ry * 0.62, rz * 0.62), h.axes(), g, M.HAIR, 'hair', 'facecut', op=SUBTRACT, k=0.5)


def _chain(sc, g, pts, r0, r1, tag, k=0.6):
    n = len(pts) - 1
    for i in range(n):
        ra = r0 + (r1 - r0) * i / n
        rb = r0 + (r1 - r0) * (i + 1) / n
        sc.cone(pts[i], pts[i + 1], ra, rb, g, M.HAIR, 'hair', tag, k=k)


def build_hair(sc, sk, style):
    """add the hair of `style` to the scene; returns strand marks"""
    if style == 'bald':
        return []
    h = HeadFrame(sk)
    rx, ry, rz = h.rx, h.ry, h.rz
    J = sk.J
    sw = h.sway
    marks_spec = dict(t=0.8, n=7, spread=1.0)
    if style == 'buzz':
        g = sc.group('hair', 0.0)
        _cap(sc, h, g, 0.32, hairline=2.0, nape=-1.6)
        marks_spec = None
    elif style == 'crop':
        g = sc.group('hair', 0.0)
        _cap(sc, h, g, 0.85, hairline=2.1, nape=-1.4)
        g2 = sc.group('hair_f', 0.6)
        sc.ellipsoid(h.P(0.6, 3.0, rz * 0.62), (rx * 0.62, 1.0, 1.6), h.axes(), g2, M.HAIR, 'hair', 'fringe')
        marks_spec = dict(t=0.85, n=6, spread=0.8)
    elif style == 'pixie':
        g = sc.group('hair', 0.0)
        _cap(sc, h, g, 0.9, hairline=2.0, nape=-2.0)
        g2 = sc.group('hair_f', 0.7)
        # a side-swept fringe falling across the forehead toward the far side
        sc.cone(h.P(rx * 0.55, 3.6, rz * 0.45), h.P(-rx * 0.45, 1.6, rz * 0.92), 1.5, 0.75, g2, M.HAIR, 'hair', 'fringe')
        sc.ellipsoid(h.P(rx * 0.9, 0.0, 0.2), (0.9, 2.0, 1.6), h.axes(), g2, M.HAIR, 'hair', 'sideburn')
        marks_spec = dict(t=0.9, n=7, spread=1.0)
    elif style == 'undercut':
        g = sc.group('hair', 0.0)
        _cap(sc, h, g, 0.3, hairline=2.0, nape=-1.6)
        g2 = sc.group('hair_top', 0.5)
        sc.ellipsoid(h.P(-0.2, 2.9, 0.3), (rx * 0.82, 2.3, rz * 0.98), h.axes(), g2, M.HAIR, 'hair', 'top')
        sc.plane(h.P(0, 1.6, 0), h.D(0, -1, 0.15), g2, op=INTERSECT, k=0.3)
        # the top swept forward and over to the near side
        sc.cone(h.P(-rx * 0.4, ry * 0.95, rz * 0.2), h.P(rx * 0.55, ry * 0.45, rz * 0.95), 1.9, 1.1, g2, M.HAIR, 'hair', 'sweep', k=0.8)
        marks_spec = dict(t=1.2, n=6, spread=0.7)
    elif style == 'slick':
        g = sc.group('hair', 0.0)
        _cap(sc, h, g, 0.75, hairline=2.6, nape=-2.6, front_tilt=0.55)
        g2 = sc.group('hair_b', 0.8)
        sc.ellipsoid(h.P(0, -0.8, -rz * 0.72), (rx * 0.82, 2.2, 1.6), h.axes(), g2, M.HAIR, 'hair', 'back')
        marks_spec = dict(t=0.75, n=8, spread=1.2, back=True)
    elif style == 'mohawk':
        g = sc.group('hair', 0.0)
        _cap(sc, h, g, 0.22, hairline=2.0, nape=-1.4)
        g2 = sc.group('hair_crest', 0.4)
        pts = [h.P(0, ry * 0.75 + 1.6, rz * 0.62), h.P(0, ry + 2.2, rz * 0.05), h.P(0, ry + 1.6, -rz * 0.55), h.P(0, ry * 0.3 + 0.8, -rz - 0.3)]
        _chain(sc, g2, pts, 1.0, 0.75, 'crest', k=0.5)
        for p in pts[1:3]:
            sc.ellipsoid(p + h.D(0, 0.6, 0), (0.7, 1.6, 1.2), h.axes(), g2, M.HAIR, 'hair', 'spike', k=0.4)
        marks_spec = dict(t=1.6, n=3, spread=0.3)
    elif style in ('bob', 'long', 'shag'):
        g = sc.group('hair', 0.0)
        _cap(sc, h, g, 0.95, hairline=2.3, nape=-ry * 1.2, ears=False)
        g2 = sc.group('hair_s', 0.8)
        drop = {'bob': ry * 0.78, 'long': ry * 0.9, 'shag': ry * 0.95}[style]
        # side panels falling to the jaw, kept off the face
        sc.ellipsoid(h.P(0, -0.6, -0.5), (rx + 1.25, ry + 0.3, rz + 0.9), h.axes(), g2, M.HAIR, 'hair', 'panel')
        sc.plane(h.P(0, -drop, 0), h.D(0, -1, 0.12), g2, op=INTERSECT, k=0.3)
        sc.ellipsoid(h.P(0, -1.6, rz * 1.05), (rx * 0.78, ry * 0.75, rz * 0.7), h.axes(), g2, M.HAIR, 'hair', 'facecut', op=SUBTRACT, k=0.4)
        g3 = sc.group('hair_f', 0.6)
        if style == 'bob':
            # straight-cut bangs
            sc.box(h.P(0.2, 2.6, rz * 0.7), (rx * 0.78, 1.15, 1.0), h.axes(), 0.5, g3, M.HAIR, 'hair', 'bangs')
        else:
            sc.cone(h.P(rx * 0.5, 3.4, rz * 0.5), h.P(-rx * 0.35, 1.8, rz * 0.95), 1.5, 0.8, g3, M.HAIR, 'hair', 'fringe')
        if style == 'long':
            g4 = sc.group('hair_l', 0.9)
            nape = J['neck'] + h.D(0, -0.5, -2.2)
            low = nape + v(0, -9.5, -1.6) + sw * 0.6
            sc.cone(h.P(0, -0.6, -rz * 0.75), nape, rx + 0.9, rx + 0.4, g4, M.HAIR, 'hair', 'mass')
            sc.cone(nape, low, rx + 0.4, rx * 0.65, g4, M.HAIR, 'hair', 'mass')
            # a lock in front of the near shoulder
            sc.cone(h.P(rx + 0.3, -1.6, 0.4), J['sh_r'] + v(-1.6, -3.0, 2.0) + sw * 0.4, 1.4, 0.9, g4, M.HAIR, 'hair', 'lock')
        if style == 'shag':
            g4 = sc.group('hair_l', 0.5)
            for i, (x, y, z) in enumerate([(rx + 0.6, -ry * 0.75, 0.2), (-rx - 0.6, -ry * 0.7, 0.0), (rx * 0.4, -ry * 0.9, -rz * 0.9),
                                            (-rx * 0.4, -ry * 0.85, -rz * 0.9), (0, -ry * 0.5, -rz - 0.6)]):
                sc.ellipsoid(h.P(x, y, z), (1.3, 1.9, 1.3), h.axes(), g4, M.HAIR, 'hair', 'lobe', k=0.5)
        marks_spec = dict(t=1.1, n=9, spread=1.3)
    elif style in ('ponytail', 'braid'):
        g = sc.group('hair', 0.0)
        _cap(sc, h, g, 0.8, hairline=2.3, nape=-1.8)
        g2 = sc.group('hair_t', 0.5)
        tie = h.P(0, 0.4 if style == 'ponytail' else -0.6, -rz - 0.5)
        if style == 'ponytail':
            p1 = tie + h.D(0, -1.2, -2.2) + sw * 0.3
            p2 = p1 + v(0, -4.6, -0.9) + sw * 0.7
            p3 = p2 + v(0, -3.4, 0.2) + sw * 1.0
            sc.ellipsoid(tie, (1.2, 1.2, 1.0), h.axes(), g2, M.DARK, 'hair', 'tie')
            _chain(sc, g2, [tie, p1, p2, p3], 1.7, 0.6, 'tail', k=0.7)
        else:
            p = tie
            for i in range(6):
                q = p + v(0, -1.7, -0.25) + sw * (0.2 * (i + 1))
                sc.ellipsoid((p + q) / 2, (1.15 - 0.06 * i, 1.0, 1.0 - 0.05 * i), h.axes(), g2, M.HAIR, 'hair', 'braid%d' % (i % 2), k=0.25)
                p = q
            sc.ellipsoid(p, (0.7, 0.6, 0.7), h.axes(), g2, M.DARK, 'hair', 'tie')
        marks_spec = dict(t=0.8, n=7, spread=1.0, back=True)
    elif style == 'bun':
        g = sc.group('hair', 0.0)
        _cap(sc, h, g, 0.8, hairline=2.3, nape=-1.8)
        g2 = sc.group('hair_b', 0.6)
        sc.ellipsoid(h.P(0, ry * 0.55, -rz - 0.6), (2.3, 2.1, 2.1), h.axes(), g2, M.HAIR, 'hair', 'bun')
        marks_spec = dict(t=0.8, n=7, spread=1.0, back=True)
    elif style == 'topknot':
        g = sc.group('hair', 0.0)
        _cap(sc, h, g, 0.28, hairline=2.0, nape=-1.4)
        g2 = sc.group('hair_k', 0.5)
        k0 = h.P(0, ry + 0.6, -rz * 0.25)
        sc.ellipsoid(k0, (1.6, 1.3, 1.6), h.axes(), g2, M.HAIR, 'hair', 'knot')
        sc.cone(k0, k0 + h.D(0, 0.8, -2.6) + sw * 0.3, 1.0, 0.55, g2, M.HAIR, 'hair', 'knot_tail', k=0.3)
        sc.ellipsoid(k0 + h.D(0, -0.9, 0), (1.3, 0.45, 1.3), h.axes(), g2, M.DARK, 'hair', 'tie')
        marks_spec = None
    return strand_marks(h, style, marks_spec) if marks_spec else []


def strand_marks(h, style, spec):
    """darker strands running from the crown (or parting) down the cap; slicked and tied styles run straight back"""
    t, n, spread = spec['t'], spec['n'], spec['spread']
    rx, ry, rz = h.rx + t, h.ry * 0.92 + t, h.rz + t
    c0 = v(0, 0.62, -0.42)
    marks = []
    crown = (0.0, 1.0, -0.2)
    for i in range(n):
        a = -math.pi * 0.85 + (math.pi * 1.7) * i / max(n - 1, 1) * spread + (0 if spread >= 1 else (1 - spread) * 0.5)
        pts = []
        for k in range(6):
            u = 0.25 + 0.13 * k                             # from near the crown outward
            # direction on the ellipsoid: azimuth a around Y, polar angle from the top
            th = u * 1.25
            if spec.get('back'):
                d = v(math.sin(a) * 0.55 * math.sin(th), math.cos(th), -abs(math.cos(a)) * math.sin(th) - 0.1)
            else:
                d = v(math.sin(a) * math.sin(th), math.cos(th), math.cos(a) * math.sin(th) * 0.8)
            d = d / np.linalg.norm(d / np.array([rx, ry, rz]))
            pts.append(h.c + h.R @ (c0 + d))
        marks.append(dict(pts=pts, d=-1, groups={'hair', 'hair_f', 'hair_s', 'hair_top', 'hair_b', 'hair_l', 'hair_t'},
                          mats=(M.HAIR,), tol=3.5, floor=1))
    return marks
