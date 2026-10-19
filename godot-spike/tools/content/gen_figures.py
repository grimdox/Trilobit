#!/usr/bin/env python3
"""Bakes the standing-doll sprite set into gfx/figure/fig_sheet.png + fig_index.json.
Every cell is 64x64.  Index: key -> [x, y, w, h, z]; z is the draw order (lowest first).  Keys:
  base:<body>:<skin>:<part>      body B (natural) / BX (augmented); skin_pale..skin_deep; part body|arms|arms_sleeved|hands
  base:shadow, base:under
  <DollSpec layer id>            outfits (thug, nap, nasim, suit, jacket_0..5, ...) and worn gear (vest, coat, visor, ...);
                                 <id>_arm is the sleeve / arm-armor part, backpack_back the part behind the body
  wear:C1..C3, wear:A1..A3       the approved step-3 designs (body part, and :arm)
  <item id>                      held sprite for every gun, melee weapon and tool (trl_gun_*, trl_mel_*, trl_kit_repair, ...)
  hair_<style>_<colour>[_back], eyes_<shape>_<colour>
Usage: gen_figures.py ITEMS_JSON OUTDIR"""
import sys, os, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image
import t64_figure as F
import t64_wear as W
import t64_kit as K
import t64_held as HD
import t64_hair as HR

COLS = 32


def collect(items):
    cells = {}
    b = F.BODIES['B']
    cells['base:shadow'] = (F.layer_shadow(b), 0)
    cells['base:under'] = (F.layer_under(b), 15)
    for body in ('B', 'BX'):
        bb = F.BODIES[body]
        for skin in F.SKINS:
            F.use_skin(skin)
            cells['base:%s:%s:body' % (body, skin)] = (F.layer_body(bb), 10)
            cells['base:%s:%s:arms' % (body, skin)] = (F.layer_arms(bb), 40)
            cells['base:%s:%s:arms_sleeved' % (body, skin)] = (F.layer_arms(bb, gap=False), 40)
            cells['base:%s:%s:hands' % (body, skin)] = (F.layer_hands(bb), 60)
        F.use_skin(F.SKIN_DEFAULT)
    cells.update(K.all_layers(b))
    for k, (name, fn) in W.CLOTHES.items():
        c, ca = fn(b)
        cells['wear:' + k] = (c, 20)
        cells['wear:%s:arm' % k] = (ca, 45)
    for k, (name, fn) in W.ARMOR.items():
        c, ca = fn(b)
        cells['wear:' + k] = (c, 30)
        cells['wear:%s:arm' % k] = (ca, 48)
    cells.update(HD.all_held(b, items))
    cells.update(HR.all_hair_eyes(b))
    return {k: v for k, v in cells.items() if v[0] is not None}


def main(items_path, out):
    items = json.load(open(items_path))
    cells = collect(items)
    keys = sorted(cells)
    rows = (len(keys) + COLS - 1) // COLS
    sheet = Image.new('RGBA', (COLS * 64, rows * 64), (0, 0, 0, 0))
    index = {'_cell': 64, '_note': 'standing paper dolls; z = draw order, lowest first'}
    for n, k in enumerate(keys):
        im, z = cells[k]
        x, y = (n % COLS) * 64, (n // COLS) * 64
        sheet.paste(im, (x, y))
        index[k] = [x, y, 64, 64, z]
    os.makedirs(out, exist_ok=True)
    sheet.save(os.path.join(out, 'fig_sheet.png'), optimize=True)
    json.dump(index, open(os.path.join(out, 'fig_index.json'), 'w'), indent=0, sort_keys=True)
    print('figures: %d sprites in %dx%d' % (len(keys), sheet.width, sheet.height))


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
