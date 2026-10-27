#!/usr/bin/env python3
"""Bake the world tilesets: every id in catalog.py for every theme in themes.py, into one folder per theme in the
game's tileset format (tile_config.json + sheet_tiles.png, read by the game's src/tileset.gd).

Usage: bake.py OUT [--themes rich,mid] [--jobs N] [--no-cache]
Each sprite is cached (in .cache/) under a key of the sources that draw it, its theme's materials and its id and
variant, so a bake re-renders only what changed: a new prop renders that prop in five themes; a changed material
renders that theme; a changed renderer renders everything.  Output is byte-identical either way.
"""
import argparse
import gzip
import hashlib
import json
import os
import pickle
import sys
import time
from multiprocessing import Pool

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import themes as TH        # noqa: E402
import catalog as CA       # noqa: E402
from canvas import Rng     # noqa: E402
import render as R         # noqa: E402

COLS = 32
CACHE_VERSION = 1
SOURCES = ['canvas.py', 'render.py', 'color.py', 'terrain.py', 'walls.py', 'furniture.py', 'props.py', 'items.py', 'furniture2.py', 'goods.py']


def _src_key():
    h = hashlib.sha256()
    for n in SOURCES:
        h.update(open(os.path.join(HERE, n), 'rb').read())
    return h.hexdigest()


def _theme_key(theme):
    th = dict(TH.THEMES[theme])
    return hashlib.sha256(json.dumps([TH.COMMON, th], sort_keys=True, default=str).encode()).hexdigest()


def sprite_names(n, id_):
    return [id_] if n == 1 else ['%s.%d' % (id_, v) for v in range(n)]


def render_one(args):
    theme, id_, v = args
    f, n, kind = CA.CATALOG[id_]
    t = f(theme, Rng(theme, id_, v), v)
    return R.to_rgba(t, TH.Mats(theme))


def render_icon(item):
    import items as IT
    return R.to_rgba(IT.icon(item), TH.Mats('mid'))


def bake_items(out, items_path, jobs):
    """the item icon set (sets/items): one icon per item the game has that is not a gun or melee weapon"""
    import items as IT
    its = [i for i in json.load(open(items_path)) if IT.is_drawn_here(i)]
    with Pool(jobs) as pool:
        imgs = pool.map(render_icon, its, chunksize=4)
    rows = (len(its) + COLS - 1) // COLS
    sheet = np.zeros((rows * 64, COLS * 64, 4), np.uint8)
    tiles = []
    for i, (it, img) in enumerate(zip(its, imgs)):
        r, c = divmod(i, COLS)
        sheet[r * 64:(r + 1) * 64, c * 64:(c + 1) * 64] = img
        tiles.append({'id': it['id'], 'fg': i + 1})
    od = os.path.join(out, 'items')
    os.makedirs(od, exist_ok=True)
    Image.fromarray(sheet, 'RGBA').save(os.path.join(od, 'sheet_tiles.png'), optimize=True)
    cfg = {'tile_info': [{'pixelscale': 1, 'width': 64, 'height': 64}], 'variants': {}, 'doll': {},
           'theme': {'id': 'items', 'name': 'Item icons', 'desc': 'every item that is not a gun or melee weapon'},
           'tiles-new': [{'file': 'sheet_tiles.png', 'sprite_width': 64, 'sprite_height': 64, 'sprite_offset_x': 0,
                          'sprite_offset_y': 0, 'tiles': tiles}]}
    json.dump(cfg, open(os.path.join(od, 'tile_config.json'), 'w'), separators=(',', ':'), sort_keys=True)
    print('  items: %d icons' % len(its), flush=True)
    return len(its)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('out')
    ap.add_argument('--themes', default=','.join(TH.ORDER))
    ap.add_argument('--jobs', type=int, default=os.cpu_count() or 2)
    ap.add_argument('--no-cache', action='store_true')
    ap.add_argument('--cache', default=os.path.join(HERE, '..', '..', '.cache', 'tiles'))
    ap.add_argument('--items', default=os.path.join(HERE, '..', '..', '..', 'godot-spike', 'data', 'items.json'),
                    help="the game's item list, for the item icon set ('' to skip it)")
    a = ap.parse_args()
    t0 = time.time()
    src = _src_key()
    os.makedirs(a.cache, exist_ok=True)
    total = rendered = 0
    for theme in a.themes.split(','):
        tk = _theme_key(theme)
        jobs, keys, cached = [], [], {}
        for id_, (f, n, kind) in CA.CATALOG.items():
            for v in range(n):
                k = hashlib.sha256(('%d|%s|%s|%s|%s|%d' % (CACHE_VERSION, src, tk, theme, id_, v)).encode()).hexdigest()[:32]
                p = os.path.join(a.cache, k + '.npy.gz')
                if not a.no_cache and os.path.exists(p):
                    with gzip.open(p, 'rb') as fh:
                        cached[(id_, v)] = np.load(fh)
                else:
                    jobs.append((theme, id_, v))
                    keys.append(p)
        if jobs:
            with Pool(a.jobs) as pool:
                for (th, id_, v), p, img in zip(jobs, keys, pool.map(render_one, jobs, chunksize=4)):
                    cached[(id_, v)] = img
                    if not a.no_cache:
                        with gzip.open(p + '.tmp', 'wb', compresslevel=1) as fh:
                            np.save(fh, img)
                        os.replace(p + '.tmp', p)
        rendered += len(jobs)
        # the sheet: ids in catalogue order, variants together
        # one sprite per image: the plain id of a varied sprite and the aliases name the first variant's sprite rather
        # than repeat it (a sheet costs memory in the game: tens of MB a theme)
        entries = []
        variants = {}
        first = {}
        for id_, (f, n, kind) in CA.CATALOG.items():
            names = sprite_names(n, id_)
            if n > 1:
                variants[id_] = n
            for v, name in enumerate(names):
                entries.append(([name], cached[(id_, v)]))
            first[id_] = len(entries) - n
            if n > 1:
                entries[first[id_]][0].append(id_)
        for alias, id_ in CA.ALIASES.items():
            entries[first[id_]][0].append(alias)
        rows = (len(entries) + COLS - 1) // COLS
        sheet = np.zeros((rows * 64, COLS * 64, 4), np.uint8)
        tiles = []
        for i, (names, img) in enumerate(entries):
            r, c = divmod(i, COLS)
            sheet[r * 64:(r + 1) * 64, c * 64:(c + 1) * 64] = img
            tiles.append({'id': names[0] if len(names) == 1 else names, 'fg': i + 1})
        od = os.path.join(a.out, theme)
        os.makedirs(od, exist_ok=True)
        Image.fromarray(sheet, 'RGBA').save(os.path.join(od, 'sheet_tiles.png'), optimize=True)
        cfg = {'tile_info': [{'pixelscale': 1, 'width': 64, 'height': 64}], 'variants': variants, 'doll': {},
               'theme': {'id': theme, 'name': TH.THEMES[theme]['name'], 'desc': TH.THEMES[theme]['desc']},
               'tiles-new': [{'file': 'sheet_tiles.png', 'sprite_width': 64, 'sprite_height': 64, 'sprite_offset_x': 0,
                              'sprite_offset_y': 0, 'tiles': tiles}]}
        json.dump(cfg, open(os.path.join(od, 'tile_config.json'), 'w'), indent=None, separators=(',', ':'), sort_keys=True)
        total += len(entries)
        print('  %s: %d sprites, %d names (%d rendered)' % (theme, len(entries), sum(len(e[0]) for e in entries), len(jobs)), flush=True)
    if a.items:
        total += bake_items(a.out, a.items, a.jobs)
    print('baked %d sprites, rendered %d, in %.0fs' % (total, rendered, time.time() - t0))


if __name__ == '__main__':
    main()
