"""One frame of one doll: the body, then every item laid over it, as sprites with draw-order keys.

Draw order (runtime and previews alike): groups in GROUPS order, then `sub` inside a group:
  back   0 hair behind the body, 1 back-mounted garments, 2 back implants
  far    0 far-arm skin, 1 implants, 10 + level garments (sleeves, arm armour)
  body   0 skin, 1 implants, 10 + level garments (underwear 0 ... straps 6)
  head   0 face, 1 head implants, 2 hair, 3 headwear
  held   0 the held item
  near   0 near-arm skin, 1 implants, 10 + level garments
  hands  0 skin, 1 implants, 10 + level gloves
  over   0 items drawn over the fists (knuckle weapons)
"""
import math

import numpy as np

from sdf import Scene, Camera
from body import BODIES, Skeleton
from anatomy import build_body, body_marks, head_points
import shade as S
import materials as M
import face as FC
import hair as HR
import garments as GA
import catalog as CA
import poses as PO
import implants as IM

GROUPS = ['back', 'far', 'body', 'head', 'held', 'near', 'hands', 'over']
BODY_LAYERS = ['back', 'far', 'body', 'near', 'hands']
CELL = 96
SS = 3
LOD = 64
ORIGIN = (40.0, 88.0)
SCALE = 1.0


def set_lod(lod):
    """64: the main set (96 px cells).  32: the world set for small tiles - the same solids at half scale, its own faces"""
    global CELL, LOD, ORIGIN, SCALE
    LOD = lod
    CELL, ORIGIN, SCALE = (96, (40.0, 88.0), 1.0) if lod == 64 else (48, (20.0, 44.0), 0.5)
    import items as IT
    IT.set_lod(lod)


def camera():
    return Camera(origin=ORIGIN, scale=SCALE)


def item_slots(level, back=False, headwear=False):
    """prim layer tag -> (group, sub) for a garment of `level`"""
    sub = 10 + level
    body = ('head', 3) if headwear else ('body', sub)
    slots = {'body': body, 'far': ('far', sub), 'near': ('near', sub), 'hands': ('hands', sub)}
    backs = {'body': ('back', 1)} if back else {}
    return slots, backs


class FrameResult:
    def __init__(self):
        self.sprites = []          # (group, sub, key, uint8 index image or RGBA PIL image, (x, y) offset, kind)
        self.anchors = {}
        self.stats = {}
        self.held = None

    def add(self, group, sub, key, img, off=(0, 0), kind='index'):
        self.sprites.append((group, sub, key, img, off, kind))

    def ordered(self):
        return sorted(self.sprites, key=lambda s: (GROUPS.index(s[0]), s[1]))


def solve(body_key, grip, anim, i):
    b = BODIES[body_key]
    pose, held = PO.frame(b, grip, anim, i)
    return b, pose, held, Skeleton(b, pose)


def render_body(body_key, grip, anim, i, cyber=(), cam=None, android=False):
    """the bare body of a frame: layers, pixel info (for items), anchors"""
    cam = cam or camera()
    b, pose, held, sk = solve(body_key, grip, anim, i)
    sc = Scene(cam)
    build_body(sc, sk, opts={'cyber': set(cyber)})
    r = sc.render(CELL, CELL, ss=SS)
    layers, st, info = S.compose(sc, r, BODY_LAYERS, marks=body_marks(sk, android))
    hp = head_points(sk)
    anchors = {n: cam.screen(p) for n, p in hp.items()}
    anchors['ground'] = cam.screen((0.0, 0.0, 0.0))
    if held:
        g = cam.screen(held['grip'])
        d = cam.vec(held['axis'])
        anchors['grip'] = g
        anchors['grip_angle'] = math.degrees(math.atan2(d[1], d[0]))
        anchors['grip_fs'] = math.hypot(d[0], d[1])
        if 'support' in held:
            s2 = cam.screen(held['support'])
            anchors['support'] = s2
            anchors['grip_L'] = math.hypot(s2[0] - g[0], s2[1] - g[1])
        else:
            anchors['grip_L'] = 10.0
    return dict(layers=layers, info=info, sk=sk, pose=pose, held=held, cam=cam, anchors=anchors, stats=st)


def render_item(base, build, slots, backs, face_light=False, cover_skin=False):
    """build(scene, skeleton) -> marks; returns {(group, sub): image}"""
    sc = Scene(base['cam'])
    marks = build(sc, base['sk'])
    if not sc.recs:
        return {}, {}
    r = sc.render(CELL, CELL, ss=SS)
    out, st = S.compose_item(sc, r, base['info'], slots, backs, marks=marks, face_light=face_light, cover_skin=cover_skin)
    return out, st


def garment_layers(base, gid):
    spec = CA.garment_parts(gid, base['sk'].body.fem)
    headwear = spec['level'] >= 7
    slots, backs = item_slots(spec['level'], spec.get('back', False), headwear)
    return render_item(base, lambda sc, sk: GA.build_garment(sc, sk, spec), slots, backs, face_light=headwear, cover_skin=not headwear)


def hair_layers(base, style):
    return render_item(base, lambda sc, sk: HR.build_hair(sc, sk, style), {'hair': ('head', 2)}, {'hair': ('back', 0)}, face_light=True)


def face_layer(base, shape, expr):
    a = base['anchors']
    er, el, mo = a['eye_r'], a['eye_l'], a['mouth']
    ax, ay = int(round(er[0])), int(round(er[1]))
    if LOD == 32:
        img, (dx, dy) = FC.face_sprite32(shape, expr, int(round(el[0])) - ax, int(round(mo[0])) - ax, int(round(mo[1])) - ay)
    else:
        img, (dx, dy) = FC.face_sprite(shape, expr, int(round(el[0])) - ax, int(round(mo[0])) - ax - 1, int(round(mo[1])) - ay)
    return img, (ax + dx, ay + dy)


def render_doll(d, cam=None):
    """a whole doll for previews: d = {body, grip, anim, i, hair, eyes, expr, garments: [ids], held: item dict or None,
    cyber: [limbs]}.  Returns FrameResult (sprites in draw order)"""
    import items as IT
    base = render_body(d['body'], d.get('grip', 'unarmed'), d.get('anim', 'idle'), d.get('i', 0), d.get('cyber', ()), cam, d.get('android', False))
    res = FrameResult()
    res.anchors = base['anchors']
    sub_of = {'back': ('back', 9), 'far': ('far', 0), 'body': ('body', 0), 'near': ('near', 0), 'hands': ('hands', 0)}
    for name, img in base['layers'].items():
        grp, sub = sub_of[name]
        res.add(grp, sub, 'body:' + name, img)
    hides_hair = hides_face = False
    for gid in d.get('garments', []):
        spec = CA.G[gid]
        hides_hair |= spec.get('hides_hair', False)
        hides_face |= spec.get('hides_face', False)
        out, st = garment_layers(base, gid)
        for (grp, sub), img in out.items():
            res.add(grp, sub, 'wear:%s:%s' % (gid, grp), img)
    for iid in d.get('implants', []):
        spec = IM.IMPLANTS[iid]
        slots, backs = IM.slots_for(spec)
        out, st = render_item(base, spec['builder'], slots, backs, face_light='eye_r' in spec['slots'] or 'temple' in spec['slots'])
        for (grp, sub), img in out.items():
            res.add(grp, sub, 'imp:%s:%s' % (iid, grp), img)
    if not hides_hair and d.get('hair', 'bald') != 'bald':
        out, st = hair_layers(base, d['hair'])
        for (grp, sub), img in out.items():
            res.add(grp, sub, 'hair:%s:%s' % (d['hair'], grp), img)
    if not hides_face and d.get('anim') != 'down':
        # the face sprite is drawn once per body (from the standing frame) and anchored on each frame's near eye,
        # exactly as the runtime places it
        ref = render_body(d['body'], 'unarmed', 'idle', 0, cam=cam) if (d.get('grip'), d.get('anim'), d.get('i')) != ('unarmed', 'idle', 0) else base
        img, off = face_layer(ref, d.get('eyes', 'round'), d.get('expr', 'neutral'))
        er0 = ref['anchors']['eye_r']
        er = base['anchors']['eye_r']
        off = (off[0] - int(round(er0[0])) + int(round(er[0])), off[1] - int(round(er0[1])) + int(round(er[1])))
        res.add('head', 0, 'face', img, off)
    it = d.get('held')
    if it is not None and base['held'] is not None:
        a = base['anchors']
        im, over = IT.draw(it, *IT.quant(math.radians(a['grip_angle']), a['grip_fs'], a['grip_L']))
        if im is not None:
            g = a['grip']
            res.add('over' if over else 'held', 0, 'held:' + it['id'], im,
                    (int(round(g[0] - IT.ORIGIN[0])), int(round(g[1] - IT.ORIGIN[1]))), kind='rgba')
    return res


def flatten(res, pal, bg=None, size=None):
    """composite a FrameResult into one RGBA PIL image"""
    from PIL import Image
    import preview as PV
    lut = PV.palette_array(pal)
    size = size or CELL
    out = Image.new('RGBA', (size, size), bg or (0, 0, 0, 0))
    for grp, sub, key, img, off, kind in res.ordered():
        im = img if kind == 'rgba' else Image.fromarray(lut[img], 'RGBA')
        layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        layer.paste(im, off, im)
        out.alpha_composite(layer)
    return out
