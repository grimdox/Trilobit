#!/usr/bin/env python3
"""Three alternative looks for the Trilobit street tileset (Milestone 23): same ids, sizes, offsets and layout as Bouma.
usage: gen_variants.py <trilobit repo dir>      (run gen_bouma.py first)
  Neonoir  - night city: darker, teal shadows and magenta lights, saturated neon with a soft bloom, navy outline
  Pixel16  - a fixed 16-colour palette with ordered dithering and a black outline: a crisp retro look
  Smog     - hazy, desaturated concrete and rust, film grain; only neon signs and lights keep their colour
Every sheet, including the upgraded people and the new item icons, is re-inked sprite by sprite.  Pick one or combine."""
import json, os, sys, colorsys
import numpy as np
from PIL import Image, ImageFilter

P16 = np.array([(26, 28, 44), (93, 39, 93), (177, 62, 83), (239, 125, 87), (255, 205, 117), (167, 240, 112), (56, 183, 100), (37, 113, 121),
                (41, 54, 111), (59, 93, 201), (65, 166, 246), (115, 239, 247), (244, 244, 244), (148, 176, 194), (86, 108, 134), (51, 60, 87)], np.float32)
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], np.float32) / 16.0 - 0.5


def _hsv(rgb):
    mx, mn = rgb.max(-1), rgb.min(-1)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    lum = 0.3 * rgb[..., 0] + 0.59 * rgb[..., 1] + 0.11 * rgb[..., 2]
    return sat, lum


def _outline(out, solid, col):
    pad = np.pad(solid, 1, constant_values=False)
    edge = solid & ~(pad[:-2, 1:-1] & pad[2:, 1:-1] & pad[1:-1, :-2] & pad[1:-1, 2:])
    out[edge, :3] = col


def neonoir(im, seed):
    a = np.array(im.convert("RGBA")).astype(np.float32)
    rgb, alpha = a[..., :3] / 255.0, a[..., 3]
    sat, lum = _hsv(rgb)
    solid = alpha > 128
    k = np.clip(lum, 0, 1)[..., None]
    shadow, light = np.array([0.06, 0.20, 0.30]), np.array([1.0, 0.30, 0.80])
    toned = rgb * 0.82 + (shadow * (1 - k) + light * k * 0.55) * 0.18          # split toning: teal shadows, magenta lights
    g = (toned.max(-1, keepdims=True) + 1e-6)
    toned = np.clip(toned ** 1.25, 0, 1)                                         # darker mids
    m = toned.mean(-1, keepdims=True)
    toned = np.clip(m + (toned - m) * 1.5, 0, 1)                                 # saturate
    bright = (sat > 0.45) & (lum > 0.55) & solid
    glow = Image.fromarray((bright * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.6))
    bl = np.array(glow).astype(np.float32)[..., None] / 255.0
    out = np.zeros_like(a)
    out[..., :3] = np.clip(toned * 255 + np.where(bright[..., None], 40, 0) + bl * toned * 120, 0, 255)
    out[..., 3] = np.where(solid, 255, alpha * 0)
    # bloom spills a little outside the sprite as faint translucent colour
    halo = (bl[..., 0] > 0.18) & ~solid
    out[halo, :3] = np.clip(toned.mean((0, 1)) * 255, 0, 255) * 0 + (255, 70, 200)
    out[halo, 3] = (bl[..., 0][halo] * 150).astype(np.float32)
    _outline(out, solid, (8, 10, 28))
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def pixel16(im, seed):
    a = np.array(im.convert("RGBA")).astype(np.float32)
    h, w = a.shape[:2]
    solid = a[..., 3] > 128
    yy, xx = np.mgrid[0:h, 0:w]
    d = BAYER[yy % 4, xx % 4][..., None] * 46.0
    px = np.clip(a[..., :3] + d, 0, 255)
    dist = ((px[:, :, None, :] - P16[None, None, :, :]) ** 2).sum(-1)
    out = np.zeros_like(a)
    out[..., :3] = P16[dist.argmin(-1)]
    out[..., 3] = np.where(solid, 255, 0)
    _outline(out, solid, P16[0])
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def smog(im, seed):
    a = np.array(im.convert("RGBA")).astype(np.float32)
    h, w = a.shape[:2]
    rgb, alpha = a[..., :3] / 255.0, a[..., 3]
    sat, lum = _hsv(rgb)
    solid = alpha > 128
    keep = (sat > 0.55) & (lum > 0.6)                                            # signs, lights, neon stay vivid
    grey = lum[..., None] * np.array([1.0, 0.95, 0.86])                          # warm concrete tint
    mix_ = rgb * 0.25 + grey * 0.75
    haze = np.linspace(0.16, 0.0, h)[:, None, None] * np.array([0.8, 0.74, 0.62])   # smog thickest at the top of the sprite
    res = np.clip((mix_ - 0.5) * 1.15 + 0.5 + haze - 0.05, 0, 1)
    res = np.where(keep[..., None], np.clip(rgb * 1.1, 0, 1), res)
    rnd = np.random.RandomState(seed)
    res = np.clip(res + rnd.randint(-9, 10, (h, w, 1)) / 255.0, 0, 1)
    out = np.zeros_like(a)
    out[..., :3] = res * 255
    out[..., 3] = np.where(solid, 255, 0)
    _outline(out, solid, (38, 30, 28))
    return Image.fromarray(out.astype(np.uint8), "RGBA")


STYLES = {"Neonoir": ("noir", neonoir, "Neonoir"), "Pixel16": ("p16", pixel16, "Pixel16"), "Smog": ("smog", smog, "Smog")}


def build(repo, name, pre, fn, src="Bouma"):
    sd, dd = os.path.join(repo, "gfx", src), os.path.join(repo, "gfx", name)
    os.makedirs(dd, exist_ok=True)
    cfg = json.load(open(os.path.join(sd, "tile_config.json")))
    for s in cfg["tiles-new"]:
        f = s["file"]
        if f == "fallback.png":
            Image.open(os.path.join(sd, f)).save(os.path.join(dd, f))
            continue
        im = Image.open(os.path.join(sd, f)).convert("RGBA")
        sw, sh = s["sprite_width"], s["sprite_height"]
        out = Image.new("RGBA", im.size, (0, 0, 0, 0))
        n = 0
        for y in range(0, im.height, sh):
            for x in range(0, im.width, sw):
                tile = im.crop((x, y, x + sw, y + sh))
                if tile.getbbox() is None:
                    continue
                out.paste(fn(tile, n + 31), (x, y))
                n += 1
        nf = f.replace("bouma_", pre + "_")
        out.save(os.path.join(dd, nf))
        s["file"] = nf
    json.dump(cfg, open(os.path.join(dd, "tile_config.json"), "w"), indent=1)
    open(os.path.join(dd, "tileset.txt"), "w").write("NAME: %s\nVIEW: %s\nJSON: tile_config.json\nTILESET: tiles.png\n" % (name, name))
    print(name, "written")


if __name__ == "__main__":
    repo = sys.argv[1]
    for name, (pre, fn, _) in STYLES.items():
        build(repo, name, pre, fn)
