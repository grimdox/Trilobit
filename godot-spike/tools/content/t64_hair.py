"""Hair and eyes for the standing dolls, chosen at character creation (creation.gd: STYLES, DollSpec.HAIRS, EYES).

Hair: the seven game styles in the seven game colours, each colour its own hue-shifted ramp; brows come with the
hair so they always match.  Styles with hair behind the head (long, ponytail, bun) also have a back layer drawn
behind the body.  Eyes: four shapes in the six natural eye colours (no glow: a glowing eye is an implant, pillar 3).
Keys:  hair_<style>_<colour index>  (z 72), hair_<style>_<colour index>_back (z 5), eyes_<shape>_<colour index> (z 70)"""
import numpy as np
import t64_figure as F
import t64_kit as K
from t64_figure import A, col, mix, px, crisp, ramp_paint

STYLES = ['short', 'buzz', 'mohawk', 'long', 'bob', 'ponytail', 'bun']            # creation.gd STYLES order
HAIR_COLOURS = [(0.1, 0.09, 0.1), (0.22, 0.14, 0.09), (0.45, 0.3, 0.15), (0.72, 0.58, 0.3), (0.6, 0.62, 0.66),
                (0.8, 0.2, 0.3), (0.2, 0.75, 0.9)]                                    # DollSpec.HAIRS order
HAIR_NAMES = ['Black', 'Dark brown', 'Chestnut', 'Blond', 'Grey', 'Crimson dye', 'Cyan dye']
EYE_COLOURS = [(0.34, 0.2, 0.1), (0.5, 0.36, 0.14), (0.3, 0.5, 0.22), (0.25, 0.45, 0.72), (0.52, 0.58, 0.62), (0.62, 0.45, 0.12),
               (0.62, 0.2, 0.2), (0.5, 0.32, 0.62), (0.78, 0.66, 0.2), (0.8, 0.45, 0.15), (0.2, 0.55, 0.55)]     # DollSpec EYE order: six natural, then red, violet, gold, orange, teal
EYE_NAMES = ['Brown', 'Hazel', 'Green', 'Blue', 'Grey', 'Amber', 'Red', 'Violet', 'Gold', 'Orange', 'Teal']
EYE_SHAPES = ['round', 'almond', 'hooded', 'wide']


def hexs(c):
    return '#%02x%02x%02x' % tuple(int(round(v * 255)) for v in c)


def hair_ramp(i):
    c = HAIR_COLOURS[i]
    r = K.ramp_from(hexs(c))
    if i == 0:                                              # black hair keeps a cool blue sheen in its lights
        r[5], r[6] = '#2c2e3a', '#4a4e60'
    return r


def _head(b):
    return b.centre(), b.head_cy, b.head[0], b.head[1]


def strands(a, m, ramp, hx, cy, seed, slope=0.45):
    """paint hair: lit like a dome, then darker strand lines running back from the face, a highlight band top-left"""
    if not m.any():
        return
    ramp_paint(a, m, ramp, bevel=2.2, strength=1.0)
    rng = np.random.default_rng(seed)
    phase = rng.random() * 3
    lines = m & (np.abs(((a.yy - (a.xx - hx) * slope + phase) / 1.6) % 1 - 0.5) < 0.14)
    a.rgb[lines] = col(ramp[1]) * 0.6 + a.rgb[lines] * 0.4
    hi = m & (np.abs(((a.xx - hx) + (a.yy - cy) * 1.2 + 4.0)) < 0.7) & (a.yy < cy - 1)
    a.rgb[hi] = col(ramp[6])


def brows(a, b, ramp):
    hx, cy, rx, ry = _head(b)
    fx = hx + 1.2 * b.turn
    sep = 2.2 * (1 - 0.2 * b.turn)
    ey0 = int(round(cy + 0.2 - 1.4))
    for s in (-1, 1):
        far = s > 0
        ex = int(round(fx + s * (sep + 0.4) - (1.0 if not far else 0.5)))
        px(a, ex, ey0 - 2, ramp[1], w=2 if far else 3)


def hair(b, style, ci):
    """returns {key: (image, z)}"""
    ramp = hair_ramp(ci)
    hx, cy, rx, ry = _head(b)
    near = hx - rx                                          # back of the head is on the viewer's left (figure faces right)
    front, back = A(), A()
    skull = F.Body.head_mask(b, front)[0]
    seed = STYLES.index(style) * 10 + ci
    if style == 'short':
        m = front.ellipse(hx - 0.3, cy - 1.0, rx + 0.6, ry + 0.3) & (front.yy < cy - 1.6 + 0.5 * np.clip(hx - front.xx, 0, None))
        m &= ~(front.ellipse(near + 1.0, cy + 0.8, 1.4, 1.9))                                  # leave the ear
        m |= front.poly([(hx + 0.2, cy - 3.6), (hx + 3.6, cy - 3.4), (hx + 1.6, cy - 1.8)])     # fringe toward the face
        strands(front, m, ramp, hx, cy, seed)
    elif style == 'buzz':
        m = skull & (front.yy < cy - 1.4 + 0.45 * np.clip(hx - front.xx, 0, None)) & ~front.ellipse(near + 1.0, cy + 0.8, 1.4, 1.9)
        ramp_paint(front, m, ramp, bevel=2.0, strength=1.0)
        stip = m & (((front.xx * 2).astype(int) + (front.yy * 2).astype(int)) % 3 == 0)
        front.a[stip] = 0.0                                                                     # scalp shows through
    elif style == 'mohawk':
        side = skull & (front.yy < cy - 1.0) & ~front.ellipse(near + 1.0, cy + 0.8, 1.4, 1.9)
        ramp_paint(front, side, ramp, bevel=1.4, strength=1.0)
        front.a[side & (((front.xx * 2).astype(int) + (front.yy * 2).astype(int)) % 2 == 0)] = 0.0   # shaved sides
        crest = front.poly([(hx - 3.8, cy - ry + 1.4), (hx - 2.4, cy - ry - 2.6), (hx + 0.4, cy - ry - 3.2), (hx + 2.6, cy - ry - 1.4),
                            (hx + 1.6, cy - ry + 1.2), (hx - 1.4, cy - ry + 0.8)])
        strands(front, crest, ramp, hx, cy, seed, slope=-0.8)
    elif style in ('long', 'bob', 'ponytail', 'bun'):
        cap = front.ellipse(hx - 0.3, cy - 1.2, rx + 0.7, ry + 0.2) & (front.yy < cy - 1.4 + 0.3 * np.clip(hx - front.xx, 0, None))
        if style == 'bob':
            side = front.ellipse(hx - 0.6, cy + 0.2, rx + 1.2, ry + 0.6) & (front.yy < cy + 3.6) & (front.xx < near + 3.2)
            cap |= side
            cap |= front.ellipse(hx + rx - 0.2, cy + 0.4, 1.2, 2.8) & (front.yy < cy + 3.2) & ~skull     # far-side fall
            cap |= front.poly([(hx - 0.6, cy - 4.2), (hx + 4.0, cy - 3.6), (hx + 2.2, cy - 1.6)])    # fringe
        if style == 'long':
            cap |= front.ellipse(near + 0.6, cy + 1.8, 1.8, 3.6) & ~front.ellipse(near + 1.4, cy + 0.6, 1.0, 1.4)
            cap |= front.poly([(hx - 0.6, cy - 4.2), (hx + 4.0, cy - 3.6), (hx + 2.0, cy - 1.8)])
        strands(front, cap, ramp, hx, cy, seed)
        if style == 'long':                                                                  # falls behind the neck and shoulders
            m = back.poly([(near - 0.4, cy - 2.0), (hx + rx - 0.4, cy - 2.0), (hx + rx + 0.6, b.top + 7.0),
                           (hx + 1.0, b.top + 9.0), (near - 2.6, b.top + 8.0), (near - 2.4, cy + 2.0)])
            strands(back, m, ramp, hx, cy, seed + 1, slope=-2.5)
        elif style == 'ponytail':
            tie = (near + 0.4, cy - 1.2)
            m = back.poly([(tie[0] + 1.0, tie[1] - 1.2), (tie[0] - 1.6, tie[1] + 1.0), (tie[0] - 2.6, b.top + 7.0),
                           (tie[0] - 0.6, b.top + 8.4), (tie[0] + 1.2, tie[1] + 1.4)])
            strands(back, m, ramp, hx, cy, seed + 1, slope=-2.5)
            px(front, tie[0] - 0.6, tie[1] - 0.4, '#1a1c22', w=2, h=2)                         # hair tie
        elif style == 'bun':
            c = (near + 1.6, cy - ry + 1.8)
            bun = front.ellipse(c[0], c[1], 2.4, 2.2)
            strands(front, bun, ramp, hx, cy, seed + 1, slope=1.5)
            px(front, c[0] + 1.2, c[1] + 1.6, '#1a1c22', w=1, h=1)
    brows(front, b, ramp)
    out = {'hair_%s_%d' % (style, ci): (crisp(front), 72)}
    if back.a.max() > 0:
        out['hair_%s_%d_back' % (style, ci)] = (crisp(back), 5)
    return out


def eyes(b, shape, ci):
    """an eye pair in one shape and one natural colour; whites, iris, pupil, catch-light, lash line (no brows)"""
    a = A()
    hx, cy, rx, ry = _head(b)
    fx = hx + 1.2 * b.turn
    sep = 2.2 * (1 - 0.2 * b.turn)
    ey = cy + 0.2
    iris = hexs(EYE_COLOURS[ci])
    iris_d = hexs(tuple(v * 0.6 for v in EYE_COLOURS[ci]))
    lash, white, glint = '#140e0c', '#e4dcd2', '#f6f2ea'
    for s in (-1, 1):
        far = s > 0
        ex = int(round(fx + s * (sep + 0.4) - (1.0 if not far else 0.5)))
        ey0 = int(round(ey - 1.4))
        w = 2 if far else 3
        if shape == 'round':                       # the approved anime eye: 2x2 iris, catch-light, heavy upper lash
            if not far:
                px(a, ex, ey0 + 1, white, h=2)
                px(a, ex + 1, ey0 + 1, iris, w=2, h=2)
                px(a, ex + 2, ey0 + 2, iris_d)
                px(a, ex + 1, ey0 + 1, glint)
            else:
                px(a, ex, ey0 + 1, iris, w=2, h=2)
                px(a, ex + 1, ey0 + 2, iris_d)
                px(a, ex, ey0 + 1, glint)
            px(a, ex - (0 if far else 1), ey0, lash, w=w + (0 if far else 1))
        elif shape == 'almond':                    # narrower: one row of iris between lash lines, tail at the outer corner
            if not far:
                px(a, ex, ey0 + 1, white)
                px(a, ex + 1, ey0 + 1, iris, w=2)
                px(a, ex + 2, ey0 + 1, iris_d)
            else:
                px(a, ex, ey0 + 1, iris, w=2)
            px(a, ex - (0 if far else 1), ey0, lash, w=w + (0 if far else 1))
            px(a, ex + (0 if far else 1), ey0 + 2, mix(lash, '#b47a58', 0.5), w=2)
        elif shape == 'hooded':                    # heavy lid: lash line low over a half-covered iris
            px(a, ex - (0 if far else 1), ey0, mix(lash, '#93593f', 0.4), w=w + (0 if far else 1))   # lid crease
            px(a, ex - (0 if far else 1), ey0 + 1, lash, w=w + (0 if far else 1))
            if not far:
                px(a, ex, ey0 + 2, white)
                px(a, ex + 1, ey0 + 2, iris, w=2)
            else:
                px(a, ex, ey0 + 2, iris, w=2)
        elif shape == 'wide':                      # large and bright: 2x3 iris, two catch-lights
            if not far:
                px(a, ex, ey0 + 1, white, h=3)
                px(a, ex + 1, ey0 + 1, iris, w=2, h=3)
                px(a, ex + 2, ey0 + 2, iris_d, h=2)
                px(a, ex + 1, ey0 + 1, glint)
                px(a, ex + 2, ey0 + 3, glint)
            else:
                px(a, ex, ey0 + 1, iris, w=2, h=3)
                px(a, ex + 1, ey0 + 2, iris_d, h=2)
                px(a, ex, ey0 + 1, glint)
            px(a, ex - (0 if far else 1), ey0, lash, w=w + (0 if far else 1))
    return {'eyes_%s_%d' % (shape, ci): (crisp(a, outline=False), 70)}


def all_hair_eyes(b):
    out = {}
    for st in STYLES:
        for ci in range(len(HAIR_COLOURS)):
            out.update(hair(b, st, ci))
    for sh in EYE_SHAPES:
        for ci in range(len(EYE_COLOURS)):
            out.update(eyes(b, sh, ci))
    return out
