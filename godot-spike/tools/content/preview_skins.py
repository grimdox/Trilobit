#!/usr/bin/env python3
"""Preview of the five skin tones on the approved base doll (t64_figure 'B').  Writes PNGs to OUTDIR only.
Usage: preview_skins.py ITEMS_JSON TILE_SHEET OUTDIR"""
import sys, os, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image
import t64_figure as F

BG = (16, 20, 28, 255)


def zoom(im, k):
    return im.resize((im.width * k, im.height * k), Image.NEAREST)


def main(items_path, tiles_path, out):
    os.makedirs(out, exist_ok=True)
    items = json.load(open(items_path))
    names = list(F.SKINS)
    res = {}
    for n in names:
        F.use_skin(n)
        res[n] = {'B': F.build('B', items), 'BX': F.build('BX', items)}
        for k in ('B', 'BX'):
            for st in ('bare', 'gun'):
                res[n][k][st].save(os.path.join(out, '%s_%s_%s.png' % (n, k, st)))
    F.use_skin(F.SKIN_DEFAULT)
    # 4x review: row 1 bare, row 2 augmented bare, row 3 armor + gun
    rows = [('B', 'bare'), ('BX', 'bare'), ('B', 'gun')]
    sheet = Image.new('RGBA', (len(names) * 256, len(rows) * 256), BG)
    for c, n in enumerate(names):
        for r, (k, st) in enumerate(rows):
            sheet.alpha_composite(zoom(res[n][k][st], 4), (c * 256, r * 256))
    sheet.save(os.path.join(out, 'skins_x4.png'))
    # ramps, 7 swatches per tone at 24px
    sw = Image.new('RGBA', (len(names) * 256, 32), BG)
    for c, n in enumerate(names):
        for i, h in enumerate(F.SKINS[n]):
            sw.paste(Image.new('RGBA', (28, 24), h), (c * 256 + 30 + i * 28, 4))
    sw.save(os.path.join(out, 'skin_ramps.png'))
    # game scale on pavement, 1:1 then 2x
    tiles = Image.open(tiles_path).convert('RGBA')
    pave = tiles.crop((0, 0, 64, 64))
    road = tiles.crop((384, 0, 448, 64))
    ctx = Image.new('RGBA', (64 * 10, 64 * 2))
    for y in range(2):
        for x in range(10):
            ctx.alpha_composite(road if y == 0 else pave, (x * 64, y * 64))
    for c, n in enumerate(names):
        ctx.alpha_composite(res[n]['B']['bare'], (64 * c * 2, 0))
        ctx.alpha_composite(res[n]['B']['gun'], (64 * (c * 2 + 1), 0))
        ctx.alpha_composite(res[n]['BX']['bare'], (64 * c * 2 + 32, 64))
    zoom(ctx, 2).save(os.path.join(out, 'skins_context_x2.png'))
    print('skins:', ', '.join(F.SKIN_NAMES[n] for n in names))


if __name__ == '__main__':
    main(*sys.argv[1:4])
