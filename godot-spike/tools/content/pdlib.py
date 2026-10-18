"""Tiny pixel-art canvas used by gen_paperdoll.py: dict-of-pixels, auto outline and edge shading."""
from PIL import Image
OUT = (18, 18, 26, 255)

def hx(s, a=255):
    s = s.lstrip('#')
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), a)

def lit(c, k):
    return (min(255, int(c[0] + (255 - c[0]) * k)), min(255, int(c[1] + (255 - c[1]) * k)), min(255, int(c[2] + (255 - c[2]) * k)), c[3])

def dark(c, k):
    return (int(c[0] * (1 - k)), int(c[1] * (1 - k)), int(c[2] * (1 - k)), c[3])

class C:
    def __init__(s, w=32, h=32):
        s.w, s.h = w, h
        s.p = {}
        s.top = {}          # glow pixels drawn after the outline, unshaded
    def px(s, x, y, c):
        if 0 <= x < s.w and 0 <= y < s.h:
            s.p[(int(x), int(y))] = c
    def glow(s, x, y, c):
        if 0 <= x < s.w and 0 <= y < s.h:
            s.top[(int(x), int(y))] = c
    def rect(s, x0, y0, x1, y1, c):
        for y in range(int(min(y0, y1)), int(max(y0, y1)) + 1):
            for x in range(int(min(x0, x1)), int(max(x0, x1)) + 1):
                s.px(x, y, c)
    def line(s, x0, y0, x1, y1, c, w=1):
        x0, y0, x1, y1 = int(x0), int(y0), int(x1), int(y1)
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx + dy
        while True:
            for k in range(w):
                s.px(x0, y0 + k, c)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy
    def disc(s, cx, cy, r, c):
        for y in range(int(cy - r - 1), int(cy + r + 2)):
            for x in range(int(cx - r - 1), int(cx + r + 2)):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r + 0.3:
                    s.px(x, y, c)
    def erase(s, x, y):
        s.p.pop((int(x), int(y)), None)
    def image(s, outline=True, shade=True):
        p = dict(s.p)
        if shade:
            q = {}
            for (x, y), c in p.items():
                if (x, y - 1) not in p:
                    c = lit(c, 0.22)
                elif (x, y + 1) not in p:
                    c = dark(c, 0.28)
                q[(x, y)] = c
            p = q
        im = Image.new('RGBA', (s.w, s.h), (0, 0, 0, 0))
        if outline:
            for (x, y) in list(p):
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    n = (x + dx, y + dy)
                    if n not in p and 0 <= n[0] < s.w and 0 <= n[1] < s.h:
                        im.putpixel(n, OUT)
        for (x, y), c in p.items():
            im.putpixel((x, y), c)
        for (x, y), c in s.top.items():
            im.putpixel((x, y), c)
        return im
