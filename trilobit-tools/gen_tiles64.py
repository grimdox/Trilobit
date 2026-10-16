#!/usr/bin/env python3
"""Draws the 64x64 Trilobit tileset into gfx/Trilobit64/ (CDDA tile_config format, read by src/tileset.gd).
Usage: gen_tiles64.py OUTDIR ITEMS_JSON"""
import sys, os, json, importlib
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image

MODULES = ['t64_terrain', 't64_furn', 't64_things', 't64_items']      # each: sprites() -> (list of (id, image[, sheet]), variants dict)


def main(out, items_path):
    items = json.load(open(items_path))
    sheets = {'tiles': (64, 64, 0, 0, []), 'dolls': (96, 96, -16, -16, [])}
    variants = {}
    seen = set()
    for name in MODULES:
        try:
            mod = importlib.import_module(name)
        except ModuleNotFoundError as e:
            if e.name != name:
                raise
            continue
        res = mod.sprites(items) if hasattr(mod, 'sprites') else mod.terrain_sprites()
        sp, var = res
        variants.update(var)
        for ent in sp:
            id_, im = ent[0], ent[1]
            sh = ent[2] if len(ent) > 2 else 'tiles'
            if id_ in seen:
                raise SystemExit('duplicate sprite id ' + id_)
            seen.add(id_)
            w, h = sheets[sh][0], sheets[sh][1]
            if im.size != (w, h):
                raise SystemExit('%s is %s, sheet %s wants %dx%d' % (id_, im.size, sh, w, h))
            sheets[sh][4].append((id_, im))
    os.makedirs(out, exist_ok=True)
    doll_meta = getattr(importlib.import_module('t64_things'), 'DOLL_META', {})
    cfg = {'doll': doll_meta, 'tile_info': [{'pixelscale': 1, 'width': 64, 'height': 64}], 'tiles-new': [], 'variants': variants}
    fg = 1
    for sh, (w, h, ox, oy, lst) in sheets.items():
        if not lst:
            continue
        cols = 32
        rows = (len(lst) + cols - 1) // cols
        im = Image.new('RGBA', (cols * w, rows * h), (0, 0, 0, 0))
        tiles = []
        for n, (id_, spr) in enumerate(lst):
            im.paste(spr, ((n % cols) * w, (n // cols) * h))
            tiles.append({'id': id_, 'fg': fg + n})
        fn = 'sheet_%s.png' % sh
        im.save(os.path.join(out, fn))
        cfg['tiles-new'].append({'file': fn, 'sprite_width': w, 'sprite_height': h, 'sprite_offset_x': ox, 'sprite_offset_y': oy, 'tiles': tiles})
        fg += cols * rows
        print('%s: %d sprites, %dx%d' % (fn, len(lst), im.width, im.height))
    json.dump(cfg, open(os.path.join(out, 'tile_config.json'), 'w'))
    open(os.path.join(out, 'tileset.txt'), 'w').write('NAME: Trilobit 64\nVIEW: Trilobit 64\nJSON: tile_config.json\nTILESET: sheet_tiles.png\n')


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
