"""Preview helpers: apply a palette to indexed layers, stack layers, scale, lay out contact sheets."""
import numpy as np
from PIL import Image

import materials as M

BG = (34, 40, 46, 255)


def palette_array(pal):
    arr = np.zeros((M.ROWS * M.SHADES, 4), np.uint8)
    for r in range(M.ROWS):
        for s in range(M.SHADES):
            c = M.hex_rgb(pal[r][s])
            arr[r * M.SHADES + s] = [int(round(x * 255)) for x in c] + [255]
    arr[0] = [0, 0, 0, 0]
    return arr


def colorize(idx, pal):
    lut = palette_array(pal)
    return lut[idx]


def stack(images, pal, size=None, bg=None):
    """images: list of (uint8 index image, (dx, dy)) in draw order"""
    H, W = images[0][0].shape if size is None else size
    out = np.zeros((H, W, 4), np.uint8)
    if bg is not None:
        out[:] = bg
    lut = palette_array(pal)
    for idx, (dx, dy) in images:
        h, w = idx.shape
        rgba = lut[idx]
        ys, xs = max(0, dy), max(0, dx)
        ye, xe = min(H, dy + h), min(W, dx + w)
        if ye <= ys or xe <= xs:
            continue
        sub = rgba[ys - dy:ye - dy, xs - dx:xe - dx]
        a = sub[..., 3:4] > 0
        out[ys:ye, xs:xe] = np.where(a, sub, out[ys:ye, xs:xe])
    return out


def img(arr, k=1):
    im = Image.fromarray(arr, 'RGBA')
    if k != 1:
        im = im.resize((im.width * k, im.height * k), Image.NEAREST)
    return im


def sheet(images, cols, pad=0, bg=BG):
    w = max(i.width for i in images)
    h = max(i.height for i in images)
    rows = (len(images) + cols - 1) // cols
    out = Image.new('RGBA', (cols * (w + pad) + pad, rows * (h + pad) + pad), bg)
    for n, im in enumerate(images):
        out.alpha_composite(im, (pad + (n % cols) * (w + pad), pad + (n // cols) * (h + pad)))
    return out
