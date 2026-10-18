#!/usr/bin/env python3
"""Proposal sheets for the side-view dolls.  Usage: side_preview.py OUTDIR   (deterministic; writes PNGs only)"""
import sys, os, json
from PIL import Image
import t64_side as S

ST = ('ready', 'guard', 'crouch')
HELD = {'ready': 'rifle', 'guard': 'blade', 'crouch': 'rifle'}

def sheet(style, out, Z=5):
    cols = [('bare', None, None), ('armor', 'A1', None), ('armed', None, 'HELD'), ('armor + armed', 'A1', 'HELD')]
    bg = (74, 76, 88, 255) if style == 'bouma' else (236, 233, 222, 255)
    im = Image.new('RGBA', (len(cols) * 64 * Z, 3 * 64 * Z), bg)
    for r, st in enumerate(ST):
        for c, (nm, ar, it) in enumerate(cols):
            spr = S.compose(st, style, armor=ar, item=HELD[st] if it else None)
            im.alpha_composite(spr.resize((64 * Z, 64 * Z), Image.NEAREST), (c * 64 * Z, r * 64 * Z))
    im.convert('RGB').save(out)

def tile_img(tid):
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'gfx', 'Trilobit64')
    cfg = json.load(open(os.path.join(root, 'tile_config.json')))
    ids = [x['id'] for x in cfg['tiles-new'][0]['tiles']]
    n = ids.index(tid)
    sh = Image.open(os.path.join(root, 'sheet_tiles.png')).convert('RGBA')
    return sh.crop(((n % 32) * 64, (n // 32) * 64, (n % 32) * 64 + 64, (n // 32) * 64 + 64))

def context(out, scale=3):
    """the stances at true game scale on existing floor tiles (shown x3)"""
    ids = ['t_trl_floor_steel', 't_trl_gravel', 't_trl_floor_clean'] * 2
    im = Image.new('RGBA', (64 * len(ids), 64), (0, 0, 0, 255))
    for c, t in enumerate(ids):
        im.alpha_composite(tile_img(t), (c * 64, 0))
    for i, st in enumerate(ST):
        im.alpha_composite(S.compose(st, 'bouma', armor='A1', item=HELD[st]), (i * 64, 0))
        im.alpha_composite(S.compose(st, 'bouma'), (192 + i * 64, 0))
    im = im.convert('RGB').resize((im.width * scale, 64 * scale), Image.NEAREST)
    im.save(out)

if __name__ == '__main__':
    o = sys.argv[1]
    os.makedirs(o, exist_ok=True)
    for st in ('bouma', 'moku'):
        sheet(st, os.path.join(o, 'stances_%s.png' % st))
    context(os.path.join(o, 'context_bouma.png'))
