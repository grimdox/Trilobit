#!/usr/bin/env python3
"""Preview sheets for the step-3 wearables (t64_wear): C1-C3, A1-A3, G1-G3 and pistols P1-P2 on the approved doll, three mixed
loadouts on different skins, the gun layers alone, and a game-scale strip.  Writes PNGs to OUTDIR only.
Usage: preview_wear.py TILE_SHEET OUTDIR"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image
import t64_figure as F
import t64_wear as W

BG = (16, 20, 28, 255)
MIXES = [('C3', 'A1', 'G1', 'skin_pale'), ('C2', 'A2', 'G2', 'skin_brown'), ('C1', 'A3', 'G3', 'skin_deep')]


def zoom(im, k):
    return im.resize((im.width * k, im.height * k), Image.NEAREST)


def row(ims, k=4):
    out = Image.new('RGBA', (len(ims) * 64 * k, 64 * k), BG)
    for i, im in enumerate(ims):
        out.alpha_composite(zoom(im, k), (i * 64 * k, 0))
    return out


def main(tiles_path, out):
    os.makedirs(out, exist_ok=True)
    b = F.BODIES['B']
    rows = {
        'clothes': [W.dress('B', cloth=c) for c in W.CLOTHES],
        'armor': [W.dress('B', armor=a) for a in W.ARMOR],
        'guns': [W.dress('B', cloth='C1', gun=g) for g in W.GUNS],
        'mixes': [W.dress('B', cloth=c, armor=a, gun=g, skin=s) for c, a, g, s in MIXES],
        'gun_layers': [W.GUNS[g][1](b) for g in W.GUNS],
        'pistols': [W.dress('B', cloth='C3', gun='P1'), W.dress('B', cloth='C2', gun='P2')] + [W.PISTOLS[p][1](b) for p in W.PISTOLS],
    }
    for name, ims in rows.items():
        row(ims).save(os.path.join(out, 'wear_%s_x4.png' % name))
    tiles = Image.open(tiles_path).convert('RGBA')
    road, pave, crate = tiles.crop((384, 0, 448, 64)), tiles.crop((0, 0, 64, 64)), tiles.crop((832, 128, 896, 192))
    ctx = Image.new('RGBA', (64 * 10, 64 * 2))
    for y in range(2):
        for x in range(10):
            ctx.alpha_composite(road if y == 0 else pave, (x * 64, y * 64))
    ctx.alpha_composite(crate, (0, 64))
    for i, im in enumerate(rows['clothes'] + rows['armor'] + rows['guns'][:1]):
        ctx.alpha_composite(im, (64 * (i + 1) if i < 7 else 64 * 8, 0))
    for i, im in enumerate(rows['mixes'] + rows['guns'][1:]):
        ctx.alpha_composite(im, (64 * (i * 2 + 1), 64))
    zoom(ctx, 2).save(os.path.join(out, 'wear_context_x2.png'))
    print('wearables:', ', '.join(list(W.CLOTHES) + list(W.ARMOR) + list(W.GUNS)))


if __name__ == '__main__':
    main(*sys.argv[1:3])
