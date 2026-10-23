"""Faces: eyes, brows and mouth as hand-designed pixel stamps.

At this size an eye is three pixels wide, so faces are drawn, not rendered: every shape and expression below is a
deliberate pixel pattern.  A face sprite is anchored on the near eye (the projected `eye_r` point of each frame), so
one face sprite serves every frame of a body.  Colours come from the doll's palette: lashes and pupils from DARK,
whites from SCLERA, iris from IRIS, brows from HAIR (they always match the hair), lips from LIP, lids from SKIN.

Stamp legend:
  L lash / upper lid line      l lower lid (skin shade 1)   K lid crease (skin shade 2)
  S white, lit                 s white, shaded              I iris              i iris, dark side
  P pupil                      G catch light                B brow              b brow, light end
  M lip line                   m lower lip light             D open mouth        T teeth
"""
import numpy as np

import materials as M

CODE = {
    'L': (M.DARK, 2), 'l': (M.SKIN, 1), 'K': (M.SKIN, 2), 'S': (M.SCLERA, 2), 's': (M.SCLERA, 1),
    'I': (M.IRIS, 3), 'i': (M.IRIS, 1), 'P': (M.DARK, 0), 'G': (M.SCLERA, 7), 'B': (M.HAIR, 1), 'b': (M.HAIR, 3),
    'M': (M.LIP, 1), 'm': (M.LIP, 4), 'D': (M.DARK, 1), 'T': (M.SCLERA, 4),
}

# eye shapes: (near eye rows, far eye rows); row 0 sits one pixel above the eye point; column 0 of the near eye sits
# one pixel left of the eye point, column 0 of the far eye on its point.
SHAPES = {
    'round':  (['LLLL', '.SGI', '.SIi'], ['LL', 'GI', 'Ii']),
    'almond': (['.LLL', 'LSGI', '..li'], ['LL', 'GI', 'l.']),
    'hooded': (['.KKK', 'LLLL', '.SIi'], ['KK', 'LL', 'Ii']),
    'wide':   (['LLLL', '.SGI', '.SIi', '..ss'], ['LL', 'GI', 'Ii', 's.']),
    'sharp':  (['L...', 'LLLL', '.sGi'], ['.L', 'LL', 'Gi']),
}
SHAPE_ORDER = ['round', 'almond', 'hooded', 'wide', 'sharp']
SHAPE_NAMES = {'round': 'Round', 'almond': 'Almond', 'hooded': 'Hooded', 'wide': 'Wide', 'sharp': 'Sharp'}

# brows: (near rows, far rows), placed two rows above the lash row; the nose side is to the right of the near eye
BROWS = {
    'neutral':   (['BBB'], ['BB']),
    'focused':   (['BBB'], ['BB']),
    'angry':     (['BB.', '..B'], ['.B', 'B.']),
    'pain':      (['..B', 'BB.'], ['B.', '.B']),
    'surprised': (['.BB', 'B..'], ['BB', '..']),
    'blink':     (['BBB'], ['BB']),
}
# mouths, centred one pixel right of the mouth point
MOUTHS = {
    'neutral':   ['MM', 'm.'],
    'focused':   ['MMM'],
    'angry':     ['MMM', 'M..'],
    'pain':      ['MMM', 'MDM'],
    'surprised': ['.M.', 'MDM'],
    'blink':     ['MM', 'm.'],
}
EXPRESSIONS = ['neutral', 'focused', 'angry', 'pain', 'surprised', 'blink']
EXPR_NAMES = {'neutral': 'Neutral', 'focused': 'Focused', 'angry': 'Angry', 'pain': 'Pain', 'surprised': 'Surprised', 'blink': 'Blink'}


def _eye_rows(shape, expr, near):
    rows = list(SHAPES[shape][0 if near else 1])
    w = len(rows[0])
    lash = next(i for i, r in enumerate(rows) if 'L' in r)
    if expr in ('blink', 'pain'):
        # closed: the lash line drops to the eye's middle row and the eye below it is skin (left empty)
        out = ['.' * w] * len(rows)
        line = ('.LLL' if expr == 'blink' else 'LLL.') if near else ('LL' if expr == 'blink' else 'L.')
        out[min(lash + 1, len(rows) - 1)] = line.ljust(w, '.')[:w]
        return out
    if expr in ('focused', 'angry'):
        # lid lowered one row over the top of the iris
        out = list(rows)
        if lash + 1 < len(rows):
            out[lash + 1] = rows[lash].replace('.', 'L') if near else rows[lash]
            out[lash] = '.' * w if shape != 'hooded' else rows[lash].replace('L', 'K')
            out = [r.replace('G', 'I') for r in out]
        return out
    if expr == 'surprised':
        # one more row of white under the iris
        return list(rows) + [('.s' + 's' * (w - 2)) if near else 's' * w]
    return rows


def stamp(img, rows, x0, y0):
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch == '.':
                continue
            m, sh = CODE[ch]
            y, x = y0 + j, x0 + i
            if 0 <= y < img.shape[0] and 0 <= x < img.shape[1]:
                img[y, x] = m * 8 + sh


def face_sprite(shape, expr, eye_sep, mouth_dx, mouth_dy):
    """the face of one shape and expression as a small indexed image and its offset from the near-eye anchor.
    eye_sep: far eye x minus near eye x (pixels); mouth_dx/dy: mouth point minus near eye point"""
    W, H = 12, 12
    ox, oy = 3, 5                          # the anchor's position inside the small image
    img = np.zeros((H, W), np.uint8)
    near = _eye_rows(shape, expr, True)
    far = _eye_rows(shape, expr, False)
    lash_n = next((i for i, r in enumerate(SHAPES[shape][0]) if 'L' in r), 0)
    # rows start one pixel above the eye point at the lash row
    y_top = oy - 1 - lash_n
    stamp(img, near, ox - 1, y_top)
    stamp(img, far, ox + eye_sep, y_top)
    bn, bf = BROWS[expr]
    by = oy - 1 - 2 - (len(bn) - 1) - (1 if expr == 'surprised' else 0)
    if shape == 'hooded':
        by -= 0
    stamp(img, bn, ox - 1, by)
    stamp(img, bf, ox + eye_sep, by)
    mo = MOUTHS[expr]
    stamp(img, mo, ox + mouth_dx, oy + mouth_dy)
    return img, (-ox, -oy)


# the 32 px world set: a face is two pixels, so shapes share one design and the expression shows in the eyes alone
FACE32 = {'neutral': ('I', 'I'), 'focused': ('I', 'I'), 'surprised': ('S', 'S'), 'angry': ('L', 'L'), 'pain': ('K', 'K'),
          'blink': ('K', 'K')}


def face_sprite32(shape, expr, eye_sep, mouth_dx, mouth_dy):
    W, H = 8, 8
    ox, oy = 2, 3
    img = np.zeros((H, W), np.uint8)
    n, f = FACE32[expr]
    stamp(img, [n], ox, oy)
    stamp(img, [f], ox + max(1, eye_sep), oy)
    if expr in ('pain', 'surprised'):
        stamp(img, ['D'], ox + mouth_dx, oy + mouth_dy)
    return img, (-ox, -oy)
