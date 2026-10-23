"""Read a baked set and compose dolls from it exactly as the runtime does (addons/trilobit_doll/doll_library.gd compose()).
Used by the QA pass and the review sheets; tests/render_check.gd proves the runtime draws the same pixels."""
import json
import os

import numpy as np
from PIL import Image

import materials as M
import preview as PV


class Baked:
    def __init__(self, path):
        self.path = path
        self.man = json.load(open(os.path.join(path, 'dolls.json')))
        self.sprites = self.man['sprites']
        self.idx = [np.array(Image.open(os.path.join(path, 'doll_idx_%d.png' % n))) for n in range(self.man['pages']['i'])]
        self.rgba = [np.array(Image.open(os.path.join(path, 'doll_rgba_%d.png' % n)).convert('RGBA')) for n in range(self.man['pages']['c'])]
        self.groups = self.man['groups']

    def sprite(self, key):
        s = self.sprites.get(key)
        if s is None:
            return None
        kind, p, x, y, w, h, ox, oy, g, sub = s
        page = self.idx[p] if kind == 'i' else self.rgba[p]
        return kind, page[y:y + h, x:x + w], (ox, oy), g, sub

    def frame_meta(self, body, fid):
        return self.man['frames'].get(body, {}).get(fid, {})

    def grip(self, spec):
        return self.man['items'].get(spec.get('item') or '', 'unarmed') if spec.get('item') else 'unarmed'

    def frames(self, anim, grip):
        if anim == 'down':
            return ['any/down/%d' % i for i in range(self.man['down']['frames'])]
        return ['%s/%s/%d' % (grip, anim, i) for i in range(self.man['anims'][anim]['frames'])]

    def compose(self, spec, fid):
        """[(key, kind, array, (x, y))] back to front, the runtime's order"""
        body = spec['body']
        fm = self.frame_meta(body, fid)
        out = []
        n = [0]
        hides_hair = False
        hides_face = not fm.get('face', True)
        for gid in spec.get('garments', []):
            g = self.man['garments'].get(gid, {})
            hides_hair |= g.get('hides_hair', False)
            hides_face |= g.get('hides_face', False)

        def add(key, at=(0, 0)):
            s = self.sprite(key)
            if s is None:
                return
            kind, arr, (ox, oy), g, sub = s
            out.append((g * 1000.0 + sub * 10.0 + n[0] * 0.001, key, kind, arr, (at[0] + ox, at[1] + oy)))
            n[0] += 1
        pre = 'a' if spec.get('android') else 'b'
        for layer in ('back', 'far', 'body', 'near', 'hands'):
            add('%s/%s/%s/%s' % (pre, body, fid, layer))
        for gid in spec.get('garments', []):
            for grp in self.groups:
                add('g/%s/%s/%s/%s' % (body, fid, gid, grp))
        for iid in spec.get('implants', []):
            for grp in self.groups:
                add('i/%s/%s/%s/%s' % (body, fid, iid, grp))
        if not hides_hair and spec.get('hair', 'bald') != 'bald':
            for grp in ('head', 'back'):
                add('h/%s/%s/%s/%s' % (body, fid, spec['hair'], grp))
        if not hides_face and 'eye' in fm:
            add('f/%s/%s/%s' % (body, spec.get('eyes', 'round'), spec.get('expr', 'neutral')), tuple(fm['eye']))
        if spec.get('item') and 'hold' in fm:
            add('held/%s/%s' % (spec['item'], fm['hold']), tuple(fm['grip']))
        out.sort(key=lambda e: e[0])
        return [e[1:] for e in out]

    def render(self, spec, fid, bg=None, size=None):
        """the doll as an RGBA PIL image (cell size)"""
        lut = PV.palette_array(M.palette_for(spec.get('colours', {})))
        size = size or self.man.get('cell', 96)
        canvas = np.zeros((size, size, 4), np.uint8)
        if bg is not None:
            canvas[:] = bg
        for key, kind, arr, (x, y) in self.compose(spec, fid):
            rgba = lut[arr] if kind == 'i' else arr
            h, w = rgba.shape[:2]
            x0, y0 = max(0, x), max(0, y)
            x1, y1 = min(size, x + w), min(size, y + h)
            if x1 <= x0 or y1 <= y0:
                continue
            sub = rgba[y0 - y:y1 - y, x0 - x:x1 - x]
            a = sub[..., 3:4] > 0
            canvas[y0:y1, x0:x1] = np.where(a, sub, canvas[y0:y1, x0:x1])
        return Image.fromarray(canvas, 'RGBA')
