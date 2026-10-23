#!/usr/bin/env python3
"""Bake the doll set: every body x frame x layer into indexed atlas pages, held items into a colour atlas, and one
manifest that tells the runtime what to draw, where, and in which order.

Outputs (in OUT):
  doll_idx_<n>.png   8-bit greyscale pages; a pixel's value is material * 8 + shade (0 = empty), coloured by the
                     runtime palette shader
  doll_rgba_<n>.png  full-colour pages for held items
  dolls.json         the manifest (see docs/FORMAT.md)
Usage: bake.py ITEMS_JSON OUT [--bodies m_m,f_m] [--frames N] [--jobs 2] [--lod 64]
Deterministic: the same inputs give byte-identical outputs.
"""
import argparse
import json
import math
import os
import sys
import time
from multiprocessing import Pool

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import frame as FR          # noqa: E402
import poses as PO          # noqa: E402
import catalog as CA        # noqa: E402
import hair as HR           # noqa: E402
import face as FC           # noqa: E402
import implants as IM       # noqa: E402
import materials as M       # noqa: E402
from body import BODIES, BODY_ORDER, BODY_NAMES   # noqa: E402

PAGE = 2048
FORMAT_VERSION = 1


def trim(img):
    """(cropped array, (x, y)) of the non-empty part, or None"""
    if img.ndim == 2:
        m = img > 0
    else:
        m = img[..., 3] > 0
    if not m.any():
        return None
    ys, xs = np.nonzero(m)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    return img[y0:y1, x0:x1], (int(x0), int(y0))


def frame_id(grip, anim, i):
    return '%s/%s/%d' % (grip or 'any', anim, i)


def bake_body(args):
    """worker: every frame of one body.  Returns (body key, sprites, frames meta)"""
    body, frames, flags = args
    FR.set_lod(flags.get('lod', 64))
    out = []
    meta = {}
    t0 = time.time()
    styles = [s for s in HR.STYLES if s != 'bald']
    for (grip, anim, i) in frames:
        fid = frame_id(grip, anim, i)
        base = FR.render_body(body, grip, anim, i)
        rep_items = {}

        def tally(st):
            for k_, n_ in st.items():
                if isinstance(n_, (int, np.integer)):
                    rep_items[k_] = rep_items.get(k_, 0) + int(n_)
        sub_of = {'back': ('back', 9), 'far': ('far', 0), 'body': ('body', 0), 'near': ('near', 0), 'hands': ('hands', 0)}
        for name, img in base['layers'].items():
            grp, sub = sub_of[name]
            out.append(('b/%s/%s/%s' % (body, fid, name), grp, sub, img, (0, 0)))
        if flags.get('android', True):
            andro = FR.render_body(body, grip, anim, i, android=True)
            for name, img in andro['layers'].items():
                grp, sub = sub_of[name]
                out.append(('a/%s/%s/%s' % (body, fid, name), grp, sub, img, (0, 0)))
        for gid in sorted(CA.G):
            lay, st = FR.garment_layers(base, gid)
            tally(st)
            for (grp, sub), img in lay.items():
                out.append(('g/%s/%s/%s/%s' % (body, fid, gid, grp), grp, sub, img, (0, 0)))
        for style in styles:
            lay, st = FR.hair_layers(base, style)
            tally(st)
            for (grp, sub), img in lay.items():
                out.append(('h/%s/%s/%s/%s' % (body, fid, style, grp), grp, sub, img, (0, 0)))
        for iid in sorted(IM.IMPLANTS):
            spec = IM.IMPLANTS[iid]
            slots, backs = IM.slots_for(spec)
            lay, st = FR.render_item(base, spec['builder'], slots, backs, face_light=('eye_r' in spec['slots'] or 'temple' in spec['slots']))
            tally(st)
            for (grp, sub), img in lay.items():
                out.append(('i/%s/%s/%s/%s' % (body, fid, iid, grp), grp, sub, img, (0, 0)))
        a = base['anchors']
        m = {'eye': [int(round(a['eye_r'][0])), int(round(a['eye_r'][1]))],
             'head': [round(float(a['centre'][0]), 2), round(float(a['centre'][1]), 2)],
             'ground': [round(float(a['ground'][0]), 2), round(float(a['ground'][1]), 2)]}
        if 'grip' in a:
            from items import quant
            ang, fs, L = quant(math.radians(a['grip_angle']), a['grip_fs'], a['grip_L'])
            m['grip'] = [int(round(a['grip'][0])), int(round(a['grip'][1]))]
            m['hold'] = 'a%d_f%d_l%d' % (ang, int(round(fs * 100)), L)
            m['hold_q'] = [ang, fs, L]
        if anim == 'down':
            m['face'] = False
        # traceable repairs: how many pixels each cleanup step changed (shade.py), on the bare body and summed over every
        # garment, hair style and implant of the frame
        m['repairs'] = {'body': {k_: int(n_) for k_, n_ in base['stats'].items() if isinstance(n_, (int, np.integer))}, 'items': rep_items}
        meta[fid] = m
    # faces: anchored on the near eye, one per shape and expression
    base = FR.render_body(body, 'unarmed', 'idle', 0)
    er = base['anchors']['eye_r']
    ax, ay = int(round(er[0])), int(round(er[1]))
    for shape in FC.SHAPE_ORDER:
        for expr in FC.EXPRESSIONS:
            img, (x, y) = FR.face_layer(base, shape, expr)
            out.append(('f/%s/%s/%s' % (body, shape, expr), 'head', 0, img, (x - ax, y - ay)))
    print('  %s: %d frames, %d sprites, %.0fs' % (body, len(frames), len(out), time.time() - t0), flush=True)
    return body, out, meta


def bake_held(args):
    """worker: every item of a grip kind at every hold that grip uses"""
    import items as IT
    kind, holds, items, lod = args
    FR.set_lod(lod)
    out = []
    for hid, (ang, fs, L) in sorted(holds.items()):
        for it in items:
            im, over = IT.draw(it, ang, fs, L)
            if im is None:
                continue
            arr = np.array(im)
            out.append(('held/%s/%s' % (it['id'], hid), 'over' if over else 'held', 0, arr, (-int(IT.ORIGIN[0]), -int(IT.ORIGIN[1]))))
    return kind, out


class Packer:
    """shelf packing on fixed pages, sprites placed tallest first (deterministic order)"""

    def __init__(self, mode):
        self.mode = mode
        self.pages = []
        self.x = self.y = self.h = 0

    def _new(self):
        self.pages.append(np.zeros((PAGE, PAGE) if self.mode == 'L' else (PAGE, PAGE, 4), np.uint8))
        self.x = self.y = self.h = 0

    def place(self, arr):
        h, w = arr.shape[:2]
        if not self.pages:
            self._new()
        if self.x + w > PAGE:
            self.x, self.y, self.h = 0, self.y + self.h + 1, 0
        if self.y + h > PAGE:
            self._new()
        p = len(self.pages) - 1
        self.pages[p][self.y:self.y + h, self.x:self.x + w] = arr
        r = (p, self.x, self.y, w, h)
        self.x += w + 1
        self.h = max(self.h, h)
        return r


def palette_table():
    """everything the runtime needs to build palettes exactly as the previews do"""
    return {
        'rows': M.ROWS, 'shades': M.SHADES,
        'materials': {v: k for k, v in M.NAMES.items()},
        'default': M.default_palette(),
        'skins': {k: {'mid': v, 'contrast': M.SKIN_CONTRAST.get(k, 1.0)} for k, v in M.SKIN_PRESETS.items()},
        'hair': M.HAIR_PRESETS, 'eyes': M.EYE_PRESETS, 'cloth': M.CLOTH_PRESETS, 'metal': M.METAL_PRESETS, 'glow': M.GLOW_PRESETS,
        # sample ramps so the runtime's port of the ramp builder can be checked against this one
        'ramp_checks': {c: M.ramp(c) for c in ('#a87356', '#3c4450', '#26232d', '#8e98a4')},
        'ramp_checks_glow': {c: M.glow_ramp(c) for c in ('#3fd8f0',)},
        'rim': M.RIM,
        # whole palettes for a few colour choices: the runtime's palette_rows() must give exactly these
        'palette_checks': [[c, M.palette_for(c)] for c in PALETTE_CHECKS],
    }


PALETTE_CHECKS = [{}, {'skin': 'porcelain', 'hair': 'cyan dye', 'eyes': 'violet', 'cloth1': 'black', 'cloth2': 'red coat', 'cloth3': 'olive',
                       'cloth4': 'bone', 'metal': 'brass', 'glow': 'amber'},
                  {'skin': 'pearl', 'synth': 'graphite', 'hair': '#5a2a8a', 'cloth1': '#123456', 'leather': 'gunmetal', 'poly': 'slate',
                   'glow': 'violet', 'glow2': 'teal'},
                  {'skin': '#8a5a3a', 'eyes': '#20a060', 'under': 'white', 'metal': 'black chrome'}]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('items')
    ap.add_argument('out')
    ap.add_argument('--bodies', default=','.join(BODY_ORDER))
    ap.add_argument('--frames', type=int, default=0, help='limit frames per body (quick test bakes)')
    ap.add_argument('--jobs', type=int, default=2)
    ap.add_argument('--lod', type=int, default=64, choices=(64, 32))
    ap.add_argument('--palette-only', action='store_true',
                    help='rewrite only the palette tables in an existing set (new or changed colour presets); seconds, no rendering')
    a = ap.parse_args()
    if a.palette_only:
        # colours never touch the sprite pixels (they are material x 8 + shade), so a new skin, hair, cloth or light
        # preset needs only the manifest's palette tables
        path = os.path.join(a.out, 'dolls.json')
        man = json.load(open(path))
        man['palette'] = json.loads(json.dumps(palette_table()))
        json.dump(man, open(path, 'w'), separators=(',', ':'), sort_keys=True)
        print('palette tables rewritten in %s (%d skins)' % (path, len(man['palette']['skins'])))
        return
    FR.set_lod(a.lod)
    items = json.load(open(a.items))
    bodies = a.bodies.split(',')
    frames = PO.all_frames()
    if a.frames:
        frames = frames[:a.frames]
    os.makedirs(a.out, exist_ok=True)
    t0 = time.time()
    print('baking %d bodies x %d frames' % (len(bodies), len(frames)), flush=True)
    with Pool(a.jobs) as pool:
        results = pool.map(bake_body, [(b, frames, {'lod': a.lod}) for b in bodies])
    # held items: every hold the frames use, per grip kind
    import items as IT
    by_kind = {}
    for it in items:
        k = IT.kind_of(it)
        if k:
            by_kind.setdefault(k, []).append(it)
    holds = {}
    for body, sprites, meta in results:
        for fid, m in meta.items():
            if 'hold' in m:
                grip = fid.split('/')[0]
                holds.setdefault(grip, {})[m['hold']] = tuple(m['hold_q'])
    with Pool(a.jobs) as pool:
        held = pool.map(bake_held, [(k, holds.get(k, {}), sorted(by_kind.get(k, []), key=lambda x: x['id']), a.lod) for k in sorted(holds)])
    # pack
    pk_i, pk_c = Packer('L'), Packer('RGBA')
    table = {}
    allspr = []
    for body, sprites, meta in results:
        allspr += sprites
    for kind, sprites in held:
        allspr += sprites
    entries = []
    for key, grp, sub, img, off in allspr:
        t = trim(img)
        if t is None:
            continue
        arr, (x0, y0) = t
        entries.append((key, grp, sub, arr, (off[0] + x0, off[1] + y0)))
    # tallest first, then key: deterministic and tight
    entries.sort(key=lambda e: (-e[3].shape[0], e[0]))
    for key, grp, sub, arr, off in entries:
        rgba = arr.ndim == 3
        p, x, y, w, h = (pk_c if rgba else pk_i).place(arr)
        table[key] = [('c' if rgba else 'i'), p, x, y, w, h, off[0], off[1], FR.GROUPS.index(grp), sub]
    for n, pg in enumerate(pk_i.pages):
        Image.fromarray(pg, 'L').save(os.path.join(a.out, 'doll_idx_%d.png' % n), optimize=True)
    for n, pg in enumerate(pk_c.pages):
        Image.fromarray(pg, 'RGBA').save(os.path.join(a.out, 'doll_rgba_%d.png' % n), optimize=True)
    kinds = {}
    for it in items:
        k = IT.kind_of(it)
        if k:
            kinds[it['id']] = k
    man = {
        'format': FORMAT_VERSION, 'lod': a.lod, 'cell': FR.CELL, 'groups': FR.GROUPS, 'origin': [int(FR.ORIGIN[0]), int(FR.ORIGIN[1])],
        'pages': {'i': len(pk_i.pages), 'c': len(pk_c.pages)}, 'page_size': PAGE,
        'bodies': {b: {'name': BODY_NAMES[b], 'sex': BODIES[b].sex, 'size': BODIES[b].size} for b in bodies},
        'grips': PO.GRIPS, 'grip_names': PO.GRIP_NAMES,
        'anims': {an: {'frames': n, 'dur': PO.DUR[an], 'loop': PO.LOOP[an], 'event': PO.EVENT.get(an, -1)} for an, n in PO.ANIMS.items()},
        'down': {'frames': PO.DOWN, 'dur': PO.DUR['down'], 'loop': False},
        'frames': {b: m for b, s, m in results},
        'hair': {s: HR.STYLE_NAMES[s] for s in HR.STYLES}, 'eye_shapes': {s: FC.SHAPE_NAMES[s] for s in FC.SHAPE_ORDER},
        'expressions': {e: FC.EXPR_NAMES[e] for e in FC.EXPRESSIONS},
        'garments': {k: {'name': v['name'], 'level': v['level'], 'hides_hair': v['hides_hair'], 'hides_face': v['hides_face'], 'tags': v['tags'],
                         'mats': sorted({p.get('mat', '') for p in (v['parts'] + (v['fem'] or []) + (v['male'] or [])) if p.get('mat')} |
                                        {p.get(x) for p in v['parts'] for x in ('cuff', 'sole', 'buckle', 'visor') if p.get(x)})}
                     for k, v in sorted(CA.G.items())},
        'outfits': CA.O, 'worn': CA.WORN,
        'implants': {k: {'name': v['name'], 'slots': v['slots'], 'over': v['over']} for k, v in sorted(IM.IMPLANTS.items())},
        'implant_game': IM.GAME,
        'items': kinds,
        'palette': palette_table(),
        'sprites': table,
    }
    with open(os.path.join(a.out, 'dolls.json'), 'w') as f:
        json.dump(man, f, separators=(',', ':'), sort_keys=True)
    print('baked %d sprites into %d index + %d colour pages in %.0fs' % (len(table), len(pk_i.pages), len(pk_c.pages), time.time() - t0))


if __name__ == '__main__':
    main()
