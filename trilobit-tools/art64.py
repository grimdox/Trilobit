"""art64: a small supersampled, lit pixel-art renderer for the 64x64 Trilobit tileset.

Shapes are rasterised at SS times the sprite size, shaded with a bevel/normal model lit from the top left, textured with
noise, then box-filtered down.  The result keeps hard silhouettes (a 1px selective outline is added) but has real material
shading: brushed metal, rubber, glass, concrete, cloth.   Everything is deterministic from the seeds passed in.
"""
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

SS = 4
LIGHT = np.array([-0.55, -0.65, 0.52])
LIGHT = LIGHT / np.linalg.norm(LIGHT)


def hx(s):
    s = s.lstrip('#')
    if len(s) == 3:
        s = ''.join(ch * 2 for ch in s)
    return np.array([int(s[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32) / 255.0


def col(c):
    if isinstance(c, str):
        return hx(c)
    return np.asarray(c, dtype=np.float32)


def mix(a, b, t):
    return col(a) * (1 - t) + col(b) * t


def lit(c, k):
    c = col(c)
    return np.clip(c * k, 0, 1)


def tint(c, t, k):
    return np.clip(col(c) * (1 - k) + col(t) * k, 0, 1)


# ---------------------------------------------------------------- noise
def vnoise(h, w, scale, seed, wrap=False):
    """smooth value noise in 0..1 at feature size `scale` pixels"""
    rng = np.random.default_rng(seed)
    n = rng.random((h, w)).astype(np.float32)
    s = max(scale / 2.0, 0.5)
    n = ndi.gaussian_filter(n, s, mode='wrap' if wrap else 'reflect')
    lo, hi = n.min(), n.max()
    return (n - lo) / (hi - lo + 1e-9)


def fbm(h, w, scale, seed, octaves=4, wrap=False):
    tot = np.zeros((h, w), np.float32)
    amp = 1.0
    norm = 0.0
    for o in range(octaves):
        tot += amp * vnoise(h, w, max(scale / (2 ** o), 1.0), seed * 31 + o, wrap)
        norm += amp
        amp *= 0.5
    tot /= norm
    lo, hi = tot.min(), tot.max()
    return (tot - lo) / (hi - lo + 1e-9)


class Art:
    def __init__(self, w=64, h=64, ss=SS, wrap=False):
        self.w, self.h, self.ss = w, h, ss
        self.wrap = wrap
        self.W, self.H = w * ss, h * ss
        self.rgb = np.zeros((self.H, self.W, 3), np.float32)
        self.a = np.zeros((self.H, self.W), np.float32)
        yy, xx = np.mgrid[0:self.H, 0:self.W]
        self.xx = xx.astype(np.float32) / ss
        self.yy = yy.astype(np.float32) / ss
        self._noise = {}

    # ---------------------------------------------------------- masks (coordinates in sprite pixels, float)
    def _img(self):
        im = Image.new('L', (self.W, self.H), 0)
        return im, ImageDraw.Draw(im)

    def poly(self, pts):
        im, d = self._img()
        d.polygon([(x * self.ss, y * self.ss) for x, y in pts], fill=255)
        return np.asarray(im) > 127

    def rect(self, x, y, w, h):
        return self.poly([(x, y), (x + w, y), (x + w, y + h), (x, y + h)])

    def rrect(self, x, y, w, h, r):
        im, d = self._img()
        s = self.ss
        d.rounded_rectangle([x * s, y * s, (x + w) * s - 1, (y + h) * s - 1], radius=r * s, fill=255)
        return np.asarray(im) > 127

    def ellipse(self, cx, cy, rx, ry=None):
        ry = rx if ry is None else ry
        im, d = self._img()
        s = self.ss
        d.ellipse([(cx - rx) * s, (cy - ry) * s, (cx + rx) * s - 1, (cy + ry) * s - 1], fill=255)
        return np.asarray(im) > 127

    def line(self, x0, y0, x1, y1, width=1.0):
        im, d = self._img()
        s = self.ss
        d.line([(x0 * s, y0 * s), (x1 * s, y1 * s)], fill=255, width=max(1, int(width * s)))
        r = width * s / 2.0
        for (x, y) in ((x0, y0), (x1, y1)):
            d.ellipse([x * s - r, y * s - r, x * s + r, y * s + r], fill=255)
        return np.asarray(im) > 127

    def capsule(self, x0, y0, x1, y1, width):
        return self.line(x0, y0, x1, y1, width)

    def tri(self, a, b, c):
        return self.poly([a, b, c])

    # ---------------------------------------------------------- texture fields
    def noise(self, scale, seed, octaves=3):
        k = (scale, seed, octaves)
        if k not in self._noise:
            self._noise[k] = fbm(self.H, self.W, scale * self.ss, seed, octaves, self.wrap)
        return self._noise[k]

    # ---------------------------------------------------------- painting
    def fill(self, mask, c, alpha=1.0):
        c = col(c)
        m = mask & (np.ones_like(mask))
        if alpha >= 1.0:
            self.rgb[m] = c
            self.a[m] = 1.0
        else:
            self.rgb[m] = self.rgb[m] * (1 - alpha) + c * alpha
            self.a[m] = np.maximum(self.a[m], alpha)

    def shade(self, mask, base, bevel=3.0, strength=0.55, relief=None, grain=0.0, seed=1, spec=0.0, rough=2.0,
              grad=None, base2=None, emit=0.0, flat=False):
        """paint `mask` with a bevel-lit surface.
        bevel: width (sprite px) of the rounded edge;  strength: how strong the light/dark side contrast is.
        relief: optional extra height field (H,W) added before lighting (surface texture).
        grad: 'v'/'h' blends base->base2 across the mask's bounding box."""
        if not mask.any():
            return
        c = col(base)
        ys, xs = np.nonzero(mask)
        y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        sub = mask[y0:y1, x0:x1]
        pad = int(bevel * self.ss) + 4
        subp = np.pad(sub, pad)
        d = ndi.distance_transform_edt(subp).astype(np.float32) / self.ss
        hgt = np.minimum(d / max(bevel, 0.3), 1.0)
        hgt = np.sin(hgt * np.pi / 2)  # rounded profile
        if relief is not None:
            r = np.pad(relief[y0:y1, x0:x1], pad, mode='edge')
            hgt = hgt + r
        if flat:
            hgt = hgt * 0
        hs = ndi.gaussian_filter(hgt, 0.5 * self.ss / 2)
        gy, gx = np.gradient(hs)
        k = 7.0 * self.ss
        nx, ny = -gx * k, -gy * k
        nz = np.ones_like(nx)
        nl = np.sqrt(nx * nx + ny * ny + nz * nz)
        nx, ny, nz = nx / nl, ny / nl, nz / nl
        lam = nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2]
        lam0 = LIGHT[2]
        shade_ = 1.0 + (lam - lam0) * strength * 2.0
        shade_ = shade_[pad:-pad, pad:-pad]
        out = np.empty((y1 - y0, x1 - x0, 3), np.float32)
        if grad is not None and base2 is not None:
            t = np.linspace(0, 1, (y1 - y0) if grad == 'v' else (x1 - x0), dtype=np.float32)
            t = t[:, None] if grad == 'v' else t[None, :]
            t = np.broadcast_to(t, (y1 - y0, x1 - x0))
            out[:] = col(base)[None, None, :] * (1 - t[..., None]) + col(base2)[None, None, :] * t[..., None]
        else:
            out[:] = c
        if grain > 0:
            g = self.noise(rough, seed + 7, 2)[y0:y1, x0:x1] - 0.5
            shade_ = shade_ * (1.0 + g * grain * 2.0)
        res = out * shade_[..., None]
        if spec > 0:
            sp = np.clip((lam - 0.85) / 0.15, 0, 1)[pad:-pad, pad:-pad] ** 2
            res = res + sp[..., None] * spec
        if emit > 0:
            res = res + col(base)[None, None, :] * emit
        res = np.clip(res, 0, 1)
        reg = self.rgb[y0:y1, x0:x1]
        reg[sub] = res[sub]
        self.a[y0:y1, x0:x1][sub] = 1.0

    def shadow(self, mask, dx=2.0, dy=3.0, blur=2.0, alpha=0.45, under=True):
        """soft drop shadow, composited beneath what is already painted (only where nothing is painted yet)"""
        sh = np.roll(np.roll(mask.astype(np.float32), int(dy * self.ss), 0), int(dx * self.ss), 1)
        sh = ndi.gaussian_filter(sh, blur * self.ss / 2) * alpha
        free = (self.a < 0.5)
        k = sh * free
        self.rgb = self.rgb * (1 - k[..., None]) + 0.0 * k[..., None]
        self.a = np.maximum(self.a, k)

    def stroke(self, mask, c, width=1.0, alpha=1.0):
        """darker rim just inside the mask"""
        er = ndi.binary_erosion(mask, iterations=max(1, int(width * self.ss)))
        ring = mask & ~er
        self.fill(ring, c, alpha)

    def glow(self, cx, cy, r, c, strength=0.8):
        d = np.sqrt((self.xx - cx) ** 2 + (self.yy - cy) ** 2)
        k = np.clip(1 - d / r, 0, 1) ** 2 * strength
        c = col(c)
        self.rgb = np.clip(self.rgb + k[..., None] * c[None, None, :], 0, 1)
        self.a = np.maximum(self.a, k * 0.0 + self.a)

    def speckle(self, mask, c, density, seed, size=1.0, alpha=1.0):
        rng = np.random.default_rng(seed)
        n = rng.random((self.H, self.W)) < density / (self.ss * self.ss)
        if size > 1:
            n = ndi.binary_dilation(n, iterations=int(size * self.ss / 2))
        self.fill(n & mask, c, alpha)

    # ---------------------------------------------------------- output
    def image(self, outline=0.0, outline_col=(0.05, 0.05, 0.08), ys=1.0, yc=None, fit=None, zmax=1.9, fit_cy=32.0):
        """box-filtered down to sprite size.  ys squashes vertically first; fit=N enlarges a small drawing so its longest side is N px."""
        s = self.ss
        A_, R_ = self.a, self.rgb * self.a[..., None]
        if ys != 1.0:
            yc = self.h / 2 if yc is None else yc
            H = self.H
            src = (np.arange(H) - yc * s) / ys + yc * s
            src = np.clip(src, 0, H - 1)
            i0 = np.floor(src).astype(int)
            i1 = np.minimum(i0 + 1, H - 1)
            f = (src - i0)[:, None]
            A_ = A_[i0] * (1 - f) + A_[i1] * f
            R_ = R_[i0] * (1 - f[..., None]) + R_[i1] * f[..., None]
        if fit:
            import cv2
            ys_, xs_ = np.nonzero(A_ > 0.08)
            if len(ys_):
                bw, bh = (xs_.max() - xs_.min() + 1) / s, (ys_.max() - ys_.min() + 1) / s
                z = min(zmax, fit / max(bw, bh, 1.0))
                cx, cy = (xs_.max() + xs_.min()) / 2.0, (ys_.max() + ys_.min()) / 2.0
                if z < 1.0:
                    z = 1.0
                ws = self.W / z
                x0, y0 = cx - ws / 2, cy - ws / 2
                M = np.float32([[1 / (ws / self.w), 0, -x0 / (ws / self.w)], [0, 1 / (ws / self.w), -y0 / (ws / self.w)]])
                pa = np.dstack([R_, A_[..., None]]).astype(np.float32)
                out = cv2.warpAffine(pa, M, (self.w * 1, self.h * 1), flags=cv2.INTER_AREA, borderValue=(0, 0, 0, 0)) if False else None
                # resample by cropping and area-resizing
                xi0, yi0 = int(round(x0)), int(round(y0))
                wi = int(round(ws))
                pad = wi
                pp = np.pad(pa, ((pad, pad), (pad, pad), (0, 0)))
                crop = pp[yi0 + pad:yi0 + pad + wi, xi0 + pad:xi0 + pad + wi]
                out = cv2.resize(crop, (self.w, self.h), interpolation=cv2.INTER_AREA)
                # recentre vertically on fit_cy when asked
                a = out[..., 3]
                rgb = out[..., :3]
                A_ = None
        if fit and A_ is None:
            pass
        else:
            a = A_.reshape(self.h, s, self.w, s).mean(axis=(1, 3))
            rgb = R_.reshape(self.h, s, self.w, s, 3).mean(axis=(1, 3))
        rgb = rgb / np.maximum(a, 1e-4)[..., None]
        if outline > 0:
            solid = a > 0.5
            edge = solid & ~ndi.binary_erosion(solid)
            oc = np.array(outline_col, np.float32)
            rgb[edge] = rgb[edge] * (1 - outline) + (rgb[edge] * 0.35 + oc * 0.3) * outline
            # soft outer line
            ring = ndi.binary_dilation(solid) & ~solid
            rgb[ring] = oc
            a = np.where(ring, np.maximum(a, outline * 0.9), a)
        out = np.dstack([np.clip(rgb, 0, 1), np.clip(a, 0, 1)])
        return Image.fromarray((out * 255 + 0.5).astype(np.uint8), 'RGBA')


def tile_img(fn, w=64, h=64, ss=2):
    a = Art(w, h, ss)
    fn(a)
    return a.image()
