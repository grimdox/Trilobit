#!/usr/bin/env python3
"""Bake the doll set: every body x frame x layer into indexed atlas pages, held items into a colour atlas, and one
manifest that tells the runtime what to draw, where, and in which order.

Outputs (in OUT):
  doll_idx_<n>.png   8-bit greyscale pages; a pixel's value is material * 8 + shade (0 = empty), coloured by the
                     runtime palette shader
  doll_rgba_<n>.png  full-colour pages for held items
  dolls.json         the manifest (see docs/FORMAT.md)
Usage: bake.py ITEMS_JSON OUT [--lod 64|32] [--jobs N] [--cache DIR | --no-cache] [--palette-only] [--bodies m_m,f_m] [--frames N]
Deterministic: the same inputs give byte-identical outputs, from the cache or not.  Only parts whose inputs changed
are rendered again (see the cache section); --palette-only rewrites colour presets alone.
"""
import argparse
import gzip
import hashlib
import json
import math
import os
import pickle
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


# ------------------------------------------------------------------------------------------------ the cache
# Every body's sprites are baked in parts: the bare body (with the frame anchors), the android body, each garment,
# each hair style, each implant and the faces; held items per grip kind.  A part is cached on disk under a key made
# from everything that decides its pixels (the generator sources it runs through and its own definition), so a bake
# re-renders only parts whose key changed: a new garment renders that garment alone, a changed shader everything.
# A colour preset is no part's input (pixels are material x 8 + shade): --palette-only handles those in seconds.
HERE = os.path.dirname(os.path.abspath(__file__))
CONTENT = os.path.join(HERE, '..', '..', '..', 'godot-spike', 'tools', 'content')
CACHE_VERSION = 1


def _src(*names, folder=HERE):
    h = hashlib.sha256()
    for n in names:
        with open(os.path.join(folder, n), 'rb') as f:
            h.update(n.encode() + b'\0' + f.read())
    return h.hexdigest()


def _canon(x):
    return json.dumps(x, sort_keys=True, default=lambda o: getattr(o, '__name__', repr(o)))


def part_keys(lod, frames):
    """{part name: key} for every part of a body (the body key is added per body)"""
    mats = _canon({k: v for k, v in vars(M).items() if k.isupper() and isinstance(v, int)})
    core = _src('sdf.py', 'sdfcore.c', 'shade.py', 'anatomy.py', 'body.py', 'poses.py', 'frame.py', 'items.py')
    core = hashlib.sha256(('%d|%d|%s|%s|%s' % (CACHE_VERSION, lod, core, mats, _canon(frames))).encode()).hexdigest()
    k = lambda *parts: hashlib.sha256('|'.join([core] + [str(p) for p in parts]).encode()).hexdigest()[:24]
    gsrc, hsrc, isrc, fsrc = _src('garments.py'), _src('hair.py'), _src('implants.py', 'garments.py'), _src('face.py')
    keys = {'body': k('body'), 'android': k('android'), 'faces': k('faces', fsrc)}
    for gid, spec in CA.G.items():
        keys['g:' + gid] = k('g', gid, gsrc, _canon(spec))
    for st in HR.STYLES:
        if st != 'bald':
            keys['h:' + st] = k('h', st, hsrc)
    for iid, spec in IM.IMPLANTS.items():
        keys['i:' + iid] = k('i', iid, isrc, _canon({x: y for x, y in spec.items() if x != 'builder'}), getattr(spec['builder'], '__name__', ''))
    return keys


def held_key(lod, kind, holds, items):
    srcs = sorted(n for n in os.listdir(CONTENT) if n.endswith('.py') and (n.startswith('t64_') or n.startswith('art')))
    return hashlib.sha256(('%d|%d|%s|%s|%s|%s|%s' % (CACHE_VERSION, lod, _src('items.py'), _src(*srcs, folder=CONTENT), kind,
                                                    _canon(sorted(holds.items())), _canon(items))).encode()).hexdigest()[:24]


class Cache:
    """one file per (body, part): {'key', 'frames': {fid: [(sprite key, group, sub, trimmed array, offset)]}, 'stats', 'meta'}"""

    def __init__(self, root, lod):
        self.dir = os.path.join(root, 'lod%d' % lod) if root else None
        if self.dir:
            os.makedirs(self.dir, exist_ok=True)

    def _path(self, body, part):
        return os.path.join(self.dir, '%s__%s.pkl.gz' % (body, part.replace(':', '_').replace(' ', '_')))

    def get(self, body, part, key):
        if not self.dir:
            return None
        try:
            with gzip.open(self._path(body, part), 'rb') as f:
                d = pickle.load(f)
            return d if d.get('key') == key else None
        except (OSError, EOFError, pickle.PickleError):
            return None

    def put(self, body, part, d):
        if not self.dir:
            return
        tmp = self._path(body, part) + '.tmp'
        with gzip.open(tmp, 'wb', compresslevel=1) as f:
            pickle.dump(d, f, protocol=pickle.HIGHEST_PROTOCOL)
        os.replace(tmp, self._path(body, part))


def _trimmed(sprites):
    out = []
    for key, grp, sub, img, off in sprites:
        t = trim(img)
        if t is not None:
            arr, (x0, y0) = t
            out.append((key, grp, sub, np.ascontiguousarray(arr), (off[0] + x0, off[1] + y0)))
    return out


def _frame_meta(base, anim):
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
    return m


def _ints(st):
    return {k_: int(n_) for k_, n_ in st.items() if isinstance(n_, (int, np.integer))}


SUB_OF = {'back': ('back', 9), 'far': ('far', 0), 'body': ('body', 0), 'near': ('near', 0), 'hands': ('hands', 0)}


def bake_chunk(args):
    """worker: the given parts of one body over a run of frames.  Returns (body, {part: {fid: sprites}}, {part: {fid:
    stats}}, {fid: frame meta} if the body part is asked for)"""
    body, frames, parts, lod = args
    FR.set_lod(lod)
    spr, stats, meta = {p: {} for p in parts}, {p: {} for p in parts}, {}
    if parts == ['faces']:
        base = FR.render_body(body, 'unarmed', 'idle', 0)
        er = base['anchors']['eye_r']
        ax, ay = int(round(er[0])), int(round(er[1]))
        out = []
        for shape in FC.SHAPE_ORDER:
            for expr in FC.EXPRESSIONS:
                img, (x, y) = FR.face_layer(base, shape, expr)
                out.append(('f/%s/%s/%s' % (body, shape, expr), 'head', 0, img, (x - ax, y - ay)))
        spr['faces']['*'] = _trimmed(out)
        return body, spr, stats, meta
    for (grip, anim, i) in frames:
        fid = frame_id(grip, anim, i)
        base = FR.render_body(body, grip, anim, i)
        for p in parts:
            out = []
            st = {}
            if p == 'body':
                for name, img in base['layers'].items():
                    grp, sub = SUB_OF[name]
                    out.append(('b/%s/%s/%s' % (body, fid, name), grp, sub, img, (0, 0)))
                st = base['stats']
                meta[fid] = _frame_meta(base, anim)
            elif p == 'android':
                andro = FR.render_body(body, grip, anim, i, android=True)
                for name, img in andro['layers'].items():
                    grp, sub = SUB_OF[name]
                    out.append(('a/%s/%s/%s' % (body, fid, name), grp, sub, img, (0, 0)))
            elif p.startswith('g:'):
                lay, st = FR.garment_layers(base, p[2:])
                out = [('g/%s/%s/%s/%s' % (body, fid, p[2:], grp), grp, sub, img, (0, 0)) for (grp, sub), img in lay.items()]
            elif p.startswith('h:'):
                lay, st = FR.hair_layers(base, p[2:])
                out = [('h/%s/%s/%s/%s' % (body, fid, p[2:], grp), grp, sub, img, (0, 0)) for (grp, sub), img in lay.items()]
            elif p.startswith('i:'):
                spec = IM.IMPLANTS[p[2:]]
                slots, backs = IM.slots_for(spec)
                lay, st = FR.render_item(base, spec['builder'], slots, backs, face_light=('eye_r' in spec['slots'] or 'temple' in spec['slots']))
                out = [('i/%s/%s/%s/%s' % (body, fid, p[2:], grp), grp, sub, img, (0, 0)) for (grp, sub), img in lay.items()]
            spr[p][fid] = _trimmed(out)
            stats[p][fid] = _ints(st)
    return body, spr, stats, meta


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
    return kind, _trimmed(out)


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
    ap.add_argument('--jobs', type=int, default=os.cpu_count() or 2, help='worker processes (default: every core)')
    ap.add_argument('--cache', default=os.path.join(HERE, '..', '..', '.cache', 'bake'), help='part cache folder')
    ap.add_argument('--no-cache', action='store_true', help='render everything, read and write no cache')
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
    cache = Cache(None if a.no_cache else a.cache, a.lod)
    keys = part_keys(a.lod, frames)
    parts_all = list(keys)
    # what each body has cached, and what it needs rendered
    have = {}
    need = {}
    for b in bodies:
        have[b] = {}
        for p in parts_all:
            d = cache.get(b, p, keys[p])
            if d is None:
                need.setdefault(b, []).append(p)
            else:
                have[b][p] = d
    n_need = sum(len(v) for v in need.values())
    print('baking %d bodies x %d frames: %d of %d parts cached, %d to render (%d jobs)' % (
        len(bodies), len(frames), len(bodies) * len(parts_all) - n_need, len(bodies) * len(parts_all), n_need, a.jobs), flush=True)
    # work units: (body, a run of frames, the parts it still needs); spread over every core (a body's frames are split
    # into runs so even one new garment on one body keeps every worker busy)
    tasks = []
    cost = {b: len([p for p in ps if p != 'faces']) + 2 for b, ps in need.items()}      # + the base render per frame
    total = sum(cost.values()) or 1
    for b, ps in need.items():
        if 'faces' in ps:
            tasks.append((b, [], ['faces'], a.lod))
        ps = [p for p in ps if p != 'faces']
        if not ps:
            continue
        runs = max(1, min(len(frames), round(a.jobs * 4 * cost[b] / total)))
        size = -(-len(frames) // runs)
        for c in range(0, len(frames), size):
            tasks.append((b, frames[c:c + size], ps, a.lod))
    if tasks:
        with Pool(a.jobs) as pool:
            done = 0
            for b, spr, stats, meta in pool.imap_unordered(bake_chunk, tasks):
                for p in spr:
                    d = have[b].setdefault(p, {'key': keys[p], 'frames': {}, 'stats': {}, 'meta': {}, '_new': True})
                    d['frames'].update(spr[p])
                    d['stats'].update(stats[p])
                    if p == 'body':
                        d['meta'].update(meta)
                done += 1
                if done % max(1, len(tasks) // 10) == 0 or done == len(tasks):
                    print('  %d/%d work units, %.0fs' % (done, len(tasks), time.time() - t0), flush=True)
        for b in bodies:
            for p, d in have[b].items():
                if d.pop('_new', False):
                    cache.put(b, p, d)
    # assemble per body: sprites, frame meta with repair counts
    results = []
    for b in bodies:
        sprites = []
        for p in parts_all:
            for fid, lst in have[b][p]['frames'].items():
                sprites += lst
        meta = {}
        for fid in have[b]['body']['meta']:
            m = dict(have[b]['body']['meta'][fid])
            items_rep = {}
            for p in parts_all:
                if p in ('body', 'android', 'faces'):
                    continue
                for k_, n_ in have[b][p]['stats'].get(fid, {}).items():
                    items_rep[k_] = items_rep.get(k_, 0) + n_
            # traceable repairs: how many pixels each cleanup step changed (shade.py), on the bare body and summed over
            # every garment, hair style and implant of the frame
            m['repairs'] = {'body': have[b]['body']['stats'].get(fid, {}), 'items': items_rep}
            meta[fid] = m
        results.append((b, sprites, meta))
    t_render = time.time() - t0
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
    held, todo = [], []
    for k in sorted(holds):
        its = sorted(by_kind.get(k, []), key=lambda x: x['id'])
        hk = held_key(a.lod, k, holds.get(k, {}), its)
        d = cache.get('held', k, hk)
        if d is None:
            todo.append(((k, holds.get(k, {}), its, a.lod), hk))
        else:
            held.append((k, d['frames']['*']))
    if todo:
        with Pool(a.jobs) as pool:
            for (kind, spr), (_, hk) in zip(pool.map(bake_held, [t for t, _ in todo]), todo):
                held.append((kind, spr))
                cache.put('held', kind, {'key': hk, 'frames': {'*': spr}, 'stats': {}, 'meta': {}})
    # pack (every sprite is already trimmed)
    pk_i, pk_c = Packer('L'), Packer('RGBA')
    table = {}
    entries = []
    for body, sprites, meta in results:
        entries += sprites
    for kind, sprites in held:
        entries += sprites
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
    print('baked %d sprites into %d index + %d colour pages in %.0fs (rendering %.0fs)' % (len(table), len(pk_i.pages), len(pk_c.pages),
                                                                                       time.time() - t0, t_render))


if __name__ == '__main__':
    main()
