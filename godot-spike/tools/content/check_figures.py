#!/usr/bin/env python3
"""Checks for the standing paper dolls (t64_figure): every layer is 64x64 RGBA, the stack is deterministic, the five
skins differ from each other only in skin pixels, and the hands sit on the hold axis.  Prints FIGURES n/n like the
Godot suites.  Usage: check_figures.py ITEMS_JSON"""
import sys, os, json, hashlib
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
import t64_figure as F


def h(im):
    return hashlib.md5(im.tobytes()).hexdigest()


def main(items_path):
    items = json.load(open(items_path))
    ok, n = 0, 0

    def check(cond, what):
        nonlocal ok, n
        n += 1
        if cond:
            ok += 1
        else:
            print('  FAIL', what)

    F.use_skin(F.SKIN_DEFAULT)
    a = F.build('B', items)
    b = F.build('B', items)
    for k, im in a['layers'].items():
        if im is None:
            continue
        check(im.size == (64, 64) and im.mode == 'RGBA', 'layer %s is 64x64 RGBA' % k)
    check(all(h(a[s]) == h(b[s]) for s in ('bare', 'armor', 'gun', 'tool')), 'build is deterministic')
    check(set(F.SKINS) == {'skin_pale', 'skin_fair', 'skin_tan', 'skin_brown', 'skin_deep', 'skin_blue', 'skin_red', 'skin_yellow', 'skin_green', 'skin_orange', 'skin_purple'}, 'eleven skin ids')
    check(all(len(r) == 7 for r in F.SKINS.values()), 'each skin ramp has 7 tones')
    seen = set()
    silhouettes = set()
    for name in F.SKINS:
        F.use_skin(name)
        r = F.build('B', items)
        seen.add(h(r['bare']))
        silhouettes.add(hashlib.md5((np.asarray(r['bare'])[..., 3] > 0).tobytes()).hexdigest())
        lum = [np.mean(F.col(c)) for c in F.SKINS[name]]
        check(all(x < y for x, y in zip(lum, lum[1:])), '%s ramp runs dark to light' % name)
    F.use_skin(F.SKIN_DEFAULT)
    check(len(seen) == 11, 'eleven skins give eleven different dolls')
    check(len(silhouettes) == 1, 'skins never change the silhouette')
    hands = np.asarray(a['layers']['hands'])[..., 3] > 0
    for H in (F.BODIES['B'].H_n, F.BODIES['B'].H_f):
        check(hands[int(round(H[1])), int(round(H[0]))], 'a hand covers the hold point %s' % (H,))
    body = np.asarray(a['layers']['body'])[..., 3] > 200
    check(body[59:63].any(), 'feet reach the bottom of the tile (rows 59-62)')
    check(not body[:2].any(), 'head clears the top of the tile')
    # the baked atlas covers everything the game can put on a person
    import re
    here = os.path.dirname(os.path.abspath(__file__))
    root = os.path.normpath(os.path.join(here, '..', '..'))
    idx_path = os.path.join(root, 'gfx', 'figure', 'fig_index.json')
    check(os.path.exists(idx_path), 'gfx/figure/fig_index.json exists')
    if os.path.exists(idx_path):
        idx = json.load(open(idx_path))
        spec = open(os.path.join(root, 'src', 'dollspec.gd')).read()
        worn = set(re.findall(r'"trl_[a-z_]+": "([a-z_]+)"', spec.split('const ARMOR_LAYER')[1].split('}')[0]))
        outfits = {'thug', 'nap', 'nasim', 'suit', 'overalls', 'coat', 'labcoat', 'chef', 'priest', 'kannushi', 'courier'} | {'jacket_%d' % i for i in range(6)}
        miss = sorted(k for k in worn | outfits if k not in idx)
        check(not miss, 'every DollSpec outfit and worn layer has a sprite %s' % miss)
        usable = [i['id'] for i in items if 'gun' in i.get('tags', []) or i.get('tags', [''])[0] == 'melee' or i['id'] in ('trl_kit_repair', 'trl_medkit')]
        miss = [i for i in usable if i not in idx]
        check(len(usable) >= 127 and not miss, 'every gun, melee weapon and tool has a held sprite (%d) %s' % (len(usable), miss[:5]))
        import t64_hair as HR
        hair = ['hair_%s_%d' % (st, c) for st in HR.STYLES for c in range(len(HR.HAIR_COLOURS))]
        eyes = ['eyes_%s_%d' % (sh, c) for sh in HR.EYE_SHAPES for c in range(len(HR.EYE_COLOURS))]
        check(all(k in idx for k in hair) and len(hair) == 49, '7 hair styles x 7 colours')
        check(all(k in idx for k in eyes) and len(eyes) == 44, '4 eye shapes x 11 colours')
        check(all(v[2] == 64 and v[3] == 64 for k, v in idx.items() if not k.startswith('_')), 'every cell is 64x64')
        check(all(('base:%s:%s:hands' % (bd, sk)) in idx for bd in ('B', 'BX') for sk in F.SKINS), 'base layers for both bodies in all eleven skins')
    print('FIGURES %d/%d' % (ok, n))
    return 0 if ok == n else 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1]))
