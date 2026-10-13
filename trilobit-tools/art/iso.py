"""Isometric drawing primitives for the Bouma tileset (48x24 diamond tiles).  Original art, drawn from code with Pillow.
Every sprite is drawn at S times size and reduced, so edges are smooth.  Coordinates passed to helpers are 1x pixels.
"""
import random
from PIL import Image, ImageDraw

S = 4
W = 48
DH = 24  # diamond height


def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c[:3]) + ((c[3],) if len(c) > 3 else ())


def mix(a, b, t):
    return tuple(int(a[i] * (1 - t) + b[i] * t) for i in range(3))


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.im = Image.new("RGBA", (w * S, h * S), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    def poly(self, pts, fill, outline=None):
        self.d.polygon([(x * S, y * S) for x, y in pts], fill=fill + (255,) if len(fill) == 3 else fill)
        if outline:
            self.line(pts + [pts[0]], outline, 1)

    def line(self, pts, col, width=1):
        self.d.line([(x * S, y * S) for x, y in pts], fill=col + (255,) if len(col) == 3 else col, width=int(width * S))

    def ellipse(self, box, fill):
        x0, y0, x1, y1 = box
        self.d.ellipse([x0 * S, y0 * S, x1 * S, y1 * S], fill=fill + (255,) if len(fill) == 3 else fill)

    def rect(self, box, fill):
        x0, y0, x1, y1 = box
        self.d.rectangle([x0 * S, y0 * S, x1 * S, y1 * S], fill=fill + (255,) if len(fill) == 3 else fill)

    def done(self, seed=None, grain=0):
        out = self.im.resize((self.w, self.h), Image.LANCZOS)
        if grain and seed is not None:
            rnd = random.Random(seed)
            px = out.load()
            for y in range(self.h):
                for x in range(self.w):
                    r, g, b, a = px[x, y]
                    if a > 200:
                        k = rnd.randint(-grain, grain)
                        px[x, y] = (max(0, min(255, r + k)), max(0, min(255, g + k)), max(0, min(255, b + k)), a)
        return out


def diamond(H, f=1.0, lift=0):
    """Vertices of the footprint diamond in a sprite of height H, scaled by f about its centre, lifted by lift pixels."""
    cx, cy = W / 2, H - DH / 2 - lift
    return [(cx - W / 2 * f, cy), (cx, cy - DH / 2 * f), (cx + W / 2 * f, cy), (cx, cy + DH / 2 * f)]


def box(cv, H, h, f=1.0, top=(120, 120, 130), left=None, right=None, edge=True, base=0):
    """Draw an isometric box of footprint scale f and height h standing on the tile floor (raised by base)."""
    left = left or shade(top, 0.62)
    right = right or shade(top, 0.80)
    b = diamond(H, f, base)
    t = diamond(H, f, base + h)
    L, T, R, B = 0, 1, 2, 3
    cv.poly([b[L], b[B], t[B], t[L]], left)
    cv.poly([b[B], b[R], t[R], t[B]], right)
    cv.poly(t, top)
    if edge:
        light = shade(top, 1.25)
        cv.line([t[L], t[T], t[R]], light, 0.8)
        cv.line([t[L], t[B], t[R]], shade(top, 1.12), 0.8)
    return b, t


def face(cv, p, u0, u1, v0, v1, fill, outline=None):
    """Fill a rectangle on a box side.  p = (bottom-left, bottom-right, top-right, top-left); u runs left to right, v bottom to top."""
    bl, br, tr, tl = p

    def pt(u, v):
        bx = bl[0] + (br[0] - bl[0]) * u
        by = bl[1] + (br[1] - bl[1]) * u
        tx = tl[0] + (tr[0] - tl[0]) * u
        ty = tl[1] + (tr[1] - tl[1]) * u
        return (bx + (tx - bx) * v, by + (ty - by) * v)
    pts = [pt(u0, v0), pt(u1, v0), pt(u1, v1), pt(u0, v1)]
    cv.poly(pts, fill, outline)


def sides(H, h, f=1.0, base=0):
    b = diamond(H, f, base)
    t = diamond(H, f, base + h)
    left = (b[0], b[3], t[3], t[0])
    right = (b[3], b[2], t[2], t[3])
    return left, right
