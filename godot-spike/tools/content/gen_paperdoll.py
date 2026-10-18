#!/usr/bin/env python3
"""Draws every paper-doll sprite and packs them into gfx/paperdoll/pd_sheet.png + pd_index.json.
  icon:<item id>   32x32 icon of each weapon / armor / container (guns, melee x3 grades, armor)
  doll:<layer id>  32x36 layer drawn over the base person sprite (armor, outfits, implants)
Usage: gen_paperdoll.py ITEMS_JSON OUTDIR"""
import sys, os, json, hashlib
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image
from pd_weapons import gun_icon, melee_icon, DRAW
from pd_armor import ARMOR_ICONS, LAYERS
from pdlib import C

def main(items_path, out):
    items = json.load(open(items_path))
    cells = []     # (key, Image, w, h)
    seen = {}
    def add(key, c):
        im = c.image() if hasattr(c, 'image') else c
        h = hashlib.md5(im.tobytes()).hexdigest()
        if key.startswith('icon:') and h in seen:
            raise SystemExit('duplicate icon art: %s == %s' % (key, seen[h]))
        seen[h] = key
        cells.append((key, im))
    for it in items:
        t = it.get('tags', [])
        id_ = it['id']
        if 'gun' in t:
            add('icon:' + id_, gun_icon(it))
        elif 'melee' in t:
            base = id_[len('trl_mel_'):]
            grade = ''
            for g in ('_f', '_m'):
                if base.endswith(g):
                    grade = g
                    base = base[:-2]
            add('icon:' + id_, melee_icon(base, it, grade))
        elif id_ in ARMOR_ICONS:
            c = C()
            ARMOR_ICONS[id_](c, None)
            add('icon:' + id_, c)
    for k, f in LAYERS.items():
        add('doll:' + k, f())
    cols = 16
    rows = (len(cells) + cols - 1) // cols
    sheet = Image.new('RGBA', (cols * 32, rows * 36), (0, 0, 0, 0))
    index = {}
    for n, (key, im) in enumerate(cells):
        x, y = (n % cols) * 32, (n // cols) * 36
        sheet.paste(im, (x, y))
        index[key] = [x, y, im.width, im.height]
    os.makedirs(out, exist_ok=True)
    sheet.save(os.path.join(out, 'pd_sheet.png'))
    json.dump(index, open(os.path.join(out, 'pd_index.json'), 'w'), indent=0, sort_keys=True)
    print('paperdoll: %d sprites (%d icons, %d doll layers) in %dx%d' % (len(cells), sum(1 for k, _ in cells if k.startswith('icon:')), sum(1 for k, _ in cells if k.startswith('doll:')), sheet.width, sheet.height))

if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
