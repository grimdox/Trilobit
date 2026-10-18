#!/usr/bin/env python3
"""Proposal sheets for the side-view dolls.  Usage: side_preview.py OUTDIR   (deterministic; writes PNGs only)"""
import sys, os
from PIL import Image
import t64_side as S

def sheet(style, out):
    states = [('bare', None, None), ('armor', True, None), ('pistol', None, 'pistol'), ('rifle + armor', True, 'rifle'), ('pickaxe', None, 'pick')]
    Z = 4
    bg = (74, 76, 88, 255) if style == 'bouma' else (236, 233, 222, 255)
    im = Image.new('RGBA', (len(states) * 64 * Z, 3 * 64 * Z), bg)
    for r, d in enumerate(('D1', 'D2', 'D3')):
        for c, (nm, ar, it) in enumerate(states):
            a = None if ar is None else ('A1', 'A2', 'A3')[r]
            spr = S.compose(d, style, armor=a, item=it)
            im.alpha_composite(spr.resize((64 * Z, 64 * Z), Image.NEAREST), (c * 64 * Z, r * 64 * Z))
    im.convert('RGB').save(out)

def one_to_one(style, out):
    """game scale (1x, then 2x) beside 64px ground tiles"""
    bg = (40, 40, 48, 255) if style == 'bouma' else (236, 233, 222, 255)
    im = Image.new('RGBA', (64 * 10, 64), bg)
    for i, d in enumerate(('D1', 'D2', 'D3')):
        im.alpha_composite(S.compose(d, style, armor=('A1', 'A2', 'A3')[i], item='rifle'), (i * 64 * 3 + 64, 0))
    im.convert('RGB').save(out)

def tile_img(tid):
    import json
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'gfx', 'Trilobit64')
    cfg = json.load(open(os.path.join(root, 'tile_config.json')))
    ids = [x['id'] for x in cfg['tiles-new'][0]['tiles']]
    n = ids.index(tid)
    sh = Image.open(os.path.join(root, 'sheet_tiles.png')).convert('RGBA')
    return sh.crop(((n % 32) * 64, (n // 32) * 64, (n % 32) * 64 + 64, (n // 32) * 64 + 64))

def context(out, scale=2):
    """the three designs standing on existing floor tiles, at 1:1 pixel scale (x2 for viewing)"""
    ids = ['t_trl_floor_steel', 't_trl_gravel', 't_trl_floor_clean', 't_trl_floor_steel', 't_trl_gravel', 't_trl_floor_clean', 't_trl_floor_steel', 't_trl_gravel']
    im = Image.new('RGBA', (64 * len(ids), 128), (0, 0, 0, 255))
    for r in range(2):
        for c, t in enumerate(ids):
            im.alpha_composite(tile_img(t), (c * 64, r * 64))
    d = ['D1', 'D2', 'D3']
    items = ['pistol', 'rifle', 'pick']
    for i in range(3):
        im.alpha_composite(S.compose(d[i], 'bouma', armor=('A1', 'A2', 'A3')[i], item=items[i]), (32 + i * 96, 64))
        im.alpha_composite(S.compose(d[i], 'bouma', armor=None, item=None), (32 + i * 96, 0))
    im = im.convert('RGB')
    im = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
    im.save(out)

if __name__ == '__main__':
    o = sys.argv[1]
    os.makedirs(o, exist_ok=True)
    for st in ('bouma', 'moku'):
        sheet(st, os.path.join(o, 'dolls_%s.png' % st))
    context(os.path.join(o, 'context_bouma_2x.png'))
