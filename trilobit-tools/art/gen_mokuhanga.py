#!/usr/bin/env python3
"""Mokuhanga: the black, white and neon woodblock-print restyle of Bouma (Milestone 20).
usage: gen_mokuhanga.py <trilobit repo dir>     (run gen_bouma.py first)
Same ids, sizes, offsets and layout as Bouma; every sprite is re-inked: flat black, white and one neon per sprite,
stepped bands instead of gradients (hatching), a black outline on the silhouette and a faint paper grain on the whites.
"""
import json, os, sys, shutil, colorsys, random
import numpy as np
from PIL import Image

INK = (14, 14, 18)
PAPER = (240, 238, 228)
NEON = {"cyan": (0, 238, 255), "magenta": (255, 40, 190), "amber": (255, 176, 0), "green": (60, 255, 120)}


def neon_of(h):
    h *= 360
    if h < 40 or h >= 330: return "magenta" if h >= 300 else "amber"
    if h < 75: return "amber"
    if h < 170: return "green"
    if h < 260: return "cyan"
    return "magenta"


def restyle(im, seed):
    from PIL import ImageFilter
    im = im.convert("RGBA")
    a = np.array(im.filter(ImageFilter.MedianFilter(3))).astype(np.float32)
    h_, w_ = a.shape[:2]
    out = np.zeros_like(a)
    rgb = a[..., :3] / 255.0
    alpha = a[..., 3]
    mx, mn = rgb.max(-1), rgb.min(-1)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    lum = 0.3 * rgb[..., 0] + 0.59 * rgb[..., 1] + 0.11 * rgb[..., 2]
    # the sprite's neon: the hue of its most vivid bright pixels
    vivid = (sat > 0.45) & (mx > 0.7) & (alpha > 128)
    ink = None
    if vivid.sum() >= 2:
        hs = [colorsys.rgb_to_hsv(*rgb[y, x])[0] for y, x in zip(*np.nonzero(vivid))]
        ink = NEON[neon_of(float(np.median(hs)))]
    sel = alpha > 128
    if sel.sum() > 20:
        lo, hi = np.percentile(lum[sel], [5, 95])
        if hi - lo > 0.05:
            lum = np.clip((lum - lo) / (hi - lo), 0, 1)
    yy, xx = np.mgrid[0:h_, 0:w_]
    d4 = (xx + yy) % 4
    white = lum > 0.66
    mid = (lum > 0.45) & ~white
    low = (lum > 0.25) & ~white & ~mid
    band = np.zeros((h_, w_, 3), np.float32)
    band[:] = INK
    band[white] = PAPER
    band[mid & (d4 < 2)] = PAPER
    band[low & (d4 == 0)] = PAPER
    if ink:
        glow = vivid | ((sat > 0.5) & (lum > 0.5) & (alpha > 128))
        band[glow] = ink
    rnd = np.random.RandomState(seed)
    grain = rnd.randint(-5, 6, (h_, w_, 1)).astype(np.float32)
    isp = (band[..., 0] > 200) & (band[..., 1] > 200) & (band[..., 2] > 190)
    band = np.where(isp[..., None], np.clip(band + grain, 0, 255), band)
    out[..., :3] = band
    solid = alpha > 128
    out[..., 3] = np.where(solid, 255, 0)
    # outline: opaque pixels touching transparency
    pad = np.pad(solid, 1, constant_values=False)
    edge = solid & ~(pad[:-2, 1:-1] & pad[2:, 1:-1] & pad[1:-1, :-2] & pad[1:-1, 2:])
    out[edge, :3] = INK
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def main(repo, sname="Bouma", dname="Mokuhanga"):
    src = os.path.join(repo, "gfx/" + sname)
    dst = os.path.join(repo, "gfx/" + dname)
    os.makedirs(dst, exist_ok=True)
    cfg = json.load(open(os.path.join(src, "tile_config.json")))
    for s in cfg["tiles-new"]:
        f = s["file"]
        if f == "fallback.png":
            im = Image.open(os.path.join(src, f)).convert("RGBA")
            a = np.array(im); m = a[..., 3] > 0
            a[m, :3] = np.maximum(a[m, :3], 60)
            Image.fromarray(a).save(os.path.join(dst, f))
            continue
        im = Image.open(os.path.join(src, f))
        sw, sh = s["sprite_width"], s["sprite_height"]
        out = Image.new("RGBA", im.size, (0, 0, 0, 0))
        n = 0
        for y in range(0, im.height, sh):
            for x in range(0, im.width, sw):
                tile = im.crop((x, y, x + sw, y + sh))
                if tile.getbbox() is None:
                    continue
                out.paste(restyle(tile, n + 17), (x, y))
                n += 1
        out.save(os.path.join(dst, f.replace("bouma_", "moku_")))
        s["file"] = f.replace("bouma_", "moku_")
    json.dump(cfg, open(os.path.join(dst, "tile_config.json"), "w"), indent=1)
    open(os.path.join(dst, "tileset.txt"), "w").write("NAME: %s\nVIEW: %s\nJSON: tile_config.json\nTILESET: tiles.png\n" % (dname.replace("_", " "), dname.replace("_", " ")))
    print("Mokuhanga written")


if __name__ == "__main__":
    main(*sys.argv[1:])
