"""Animals, the top-down paper-doll layers (sheet 'dolls', 96x96 centred on the cell) and held-weapon layers."""
import json, os
from PIL import Image
from art64 import Art
import t64_doll as D
import t64_guns as GN
import t64_melee as ML
import t64_items as IT

ITEMS_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'godot-spike', 'data', 'items.json')


def dog():
    a = Art(64, 64, 4)
    sh = a.ellipse(32, 34, 11, 20)
    a.shadow(sh, 1.5, 2.5, 2.5, 0.5)
    a.shade(a.poly([(30, 50), (34, 50), (40, 60), (26, 60)]) & a.ellipse(32, 56, 4, 8), '#8a5a2c', bevel=2, grain=0.3, seed=1)
    for x, y in ((22, 22), (42, 22), (23, 42), (41, 42)):
        a.shade(a.ellipse(x, y, 3.2, 5.5), '#6a4220', bevel=2)
    a.shade(sh, '#a86e34', bevel=6, strength=0.7, grain=0.45, seed=2)
    a.shade(a.ellipse(32, 38, 6, 8), '#c9944e', bevel=3, grain=0.3, seed=3)
    a.shade(a.ellipse(32, 14, 8, 9), '#b27a3a', bevel=4, grain=0.3, seed=4)
    a.shade(a.ellipse(32, 8, 4, 4.5), '#d6b080', bevel=2)
    a.shade(a.ellipse(32, 5, 1.8, 1.4), '#15100c', bevel=0.8)
    a.shade(a.ellipse(24.5, 16, 2.6, 4.5), '#4a2c14', bevel=1.5)
    a.shade(a.ellipse(39.5, 16, 2.6, 4.5), '#4a2c14', bevel=1.5)
    return a.image(outline=0.85)


def cat():
    a = Art(64, 64, 4)
    sh = a.ellipse(32, 36, 8, 14)
    a.shadow(sh, 1.5, 2.5, 2.5, 0.5)
    a.shade(a.line(32, 46, 40, 58, 3.4) | a.line(40, 58, 46, 52, 3.4), '#3a3a42', bevel=1.4)
    a.shade(sh, '#4a4a54', bevel=5, strength=0.7, grain=0.35, seed=5)
    for x in (30, 34):
        a.shade(a.line(x, 28, x, 44, 1.2), '#252530', bevel=0.5, strength=0.2)
    a.shade(a.ellipse(32, 22, 7, 6.5), '#555560', bevel=3.5, grain=0.3, seed=6)
    a.shade(a.tri((26, 19), (27.5, 12), (31, 17)), '#3a3a44', bevel=1)
    a.shade(a.tri((38, 19), (36.5, 12), (33, 17)), '#3a3a44', bevel=1)
    for x in (29.5, 34.5):
        a.shade(a.ellipse(x, 21.5, 1.3, 1.6), '#9affc0', bevel=0.6, emit=0.9)
    return a.image(outline=0.85)


DOLL_META = {}


def holds(items):
    out = []
    for it in items:
        t = it['tags']
        if 'gun' in t:
            ic = GN.gun_icon(it)
            hl = GN.hold_from_icon(ic, (ic.getbbox()[0] + 0.28 * (ic.getbbox()[2] - ic.getbbox()[0]), 0.5 * (ic.getbbox()[1] + ic.getbbox()[3])))
        elif t[0] == 'melee':
            ic = IT.make(it)
            bb = ic.getbbox()
            hl = GN.hold_from_icon(ic, (bb[0] + 0.2 * (bb[2] - bb[0]), 0.5 * (bb[1] + bb[3])))
        else:
            continue
        out.append(('dl:hold:' + it['id'], hl, 'dolls'))
    return out


def sprites(items):
    out = [('mon_dog', dog()), ('mon_cat', cat())]
    meta = {}
    for key, img, z, tk in D.layers():
        out.append(('dl:' + key, img, 'dolls'))
        meta[key] = [z, tk]
    out += holds(items)
    DOLL_META.update(meta)
    return out, {}
