#!/usr/bin/env python3
"""Preview sheets for the standing-doll candidates (t64_figure).  Writes PNGs to OUTDIR; nothing goes into gfx/ until a
design is approved.
Usage: preview_figures.py ITEMS_JSON TILE_SHEET OUTDIR"""
import sys, os, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from PIL import Image
import t64_figure as F

STATES = ['bare', 'armor', 'gun', 'tool']
BG = (16, 20, 28, 255)


def zoom(im, k):
    return im.resize((im.width * k, im.height * k), Image.NEAREST)


def on_bg(im, c=BG):
    bg = Image.new('RGBA', im.size, c)
    bg.alpha_composite(im)
    return bg


def three_ink(im, ink='#35d7ff'):
    """a quick black / white / one-neon print treatment of a sprite (preview of a 3-ink look):
    light areas paper-white, deep shadow black, mid tones a 50% hatch, saturated cyan/blue lights in the neon ink"""
    from scipy import ndimage as ndi
    arr = np.asarray(im).astype(np.float32) / 255
    a = arr[..., 3]
    rgb = arr[..., :3]
    lum = rgb @ np.array([0.3, 0.55, 0.15])
    sat = rgb.max(axis=2) - rgb.min(axis=2)
    yy, xx = np.mgrid[0:arr.shape[0], 0:arr.shape[1]]
    hatch = (xx + yy) % 2 == 0
    white = (lum > 0.36) | ((lum > 0.2) & hatch)
    out = np.zeros_like(arr)
    out[..., :3] = np.where(white[..., None], 0.94, 0.05)
    solid = a > 0.5
    edge = solid & ~ndi.binary_erosion(solid)
    out[edge, :3] = 0.05
    k = np.array([int(ink[i:i + 2], 16) for i in (1, 3, 5)]) / 255
    neon = (sat > 0.35) & (rgb[..., 2] > rgb[..., 0] + 0.25) & (lum > 0.35)
    out[neon, :3] = k
    out[..., 3] = a
    return Image.fromarray((out * 255).astype(np.uint8), 'RGBA')


def main(items_path, tiles_path, out):
    os.makedirs(out, exist_ok=True)
    items = json.load(open(items_path))
    res = {k: F.build(k, items) for k in F.BODIES}
    meta = {}
    for k, r in res.items():
        for s in STATES:
            r[s].save(os.path.join(out, '%s_%s.png' % (k, s)))
            on_bg(zoom(r[s], 6)).save(os.path.join(out, '%s_%s_x6.png' % (k, s)))
            on_bg(zoom(three_ink(r[s]), 6), (240, 240, 236, 255)).save(os.path.join(out, '%s_%s_ink_x6.png' % (k, s)))
        # exploded layer strip
        names = ['body', 'under', 'armor', 'arms', 'armor_arm', 'gun', 'hands']
        strip = Image.new('RGBA', (64 * len(names), 64), (0, 0, 0, 0))
        for n, nm in enumerate(names):
            if r['layers'].get(nm) is not None:
                strip.alpha_composite(r['layers'][nm], (64 * n, 0))
        on_bg(zoom(strip, 4)).save(os.path.join(out, '%s_layers_x4.png' % k))
        meta[k] = {'gun': r['gun_name'], 'armor': r['armor_name'], 'turn': F.BODIES[k].turn}
    # contact sheet for review
    sheet = Image.new('RGBA', (len(STATES) * 64 * 4 + 40, len(res) * 64 * 4 + 40), BG)
    for row, k in enumerate(res):
        for c, s in enumerate(STATES):
            sheet.alpha_composite(zoom(res[k][s], 4), (20 + c * 256, 20 + row * 256))
    sheet.save(os.path.join(out, 'review_x4.png'))
    # game-scale context: 1:1 and 2:1 on street tiles from the live tileset
    tiles = Image.open(tiles_path).convert('RGBA')
    road = tiles.crop((384, 0, 448, 64))
    pave = tiles.crop((0, 0, 64, 64))
    crate = tiles.crop((832, 128, 896, 192))
    ctx = Image.new('RGBA', (64 * 10, 64 * 3))
    for y in range(3):
        for x in range(10):
            ctx.alpha_composite(pave if y == 2 or x < 2 else road, (x * 64, y * 64))
    ctx.alpha_composite(crate, (64 * 1, 64 * 1))
    keys = list(res)
    picks = [(k, s) for s in STATES for k in keys]
    for n, (k, s) in enumerate(picks[:8]):
        ctx.alpha_composite(res[k][s], (64 * (2 + n % 4 * 2 + (1 if n >= 4 else 0)), 64 * (1 if n < 4 else 2)))
    ctx.save(os.path.join(out, 'context_x1.png'))
    zoom(ctx, 2).save(os.path.join(out, 'context_x2.png'))
    json.dump(meta, open(os.path.join(out, 'meta.json'), 'w'), indent=1)
    print('figures:', meta)


if __name__ == '__main__':
    main(*sys.argv[1:4])
