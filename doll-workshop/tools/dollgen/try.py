#!/usr/bin/env python3
"""Try a part before baking it: render it on every body in a handful of telling frames (or every frame), save a sheet
and run the part's own checks.  Seconds, not a bake; nothing is written into the sets.

Usage: try.py PART [PART ...] [--on OUTFIT] [--bodies m_m,f_l] [--frames quick|all] [--lod 64|32] [--out FILE]
  PART  g:<garment> | i:<implant> | h:<hair style> | o:<outfit preset>, several to see them together
  --on  what the doll wears under the part (an outfit preset id; default: underwear only)

Checks (per part, every frame tried):
  drawn     the part draws something in every frame (a missing sleeve in one pose shows up here)
  strays    noise in the part as drawn on the doll (a shade none of its 8 neighbours share beside its own material), under 1 %
  outline   where the part makes the doll's outer edge, the edge is dark on at least 95 % of it
  cover     with --on full (a full suit, gloves and boots) the doll shows no skin below the chin
Exit code 0 when every check passes.
"""
import argparse
import os
import sys
import time

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import frame as FR          # noqa: E402
import poses as PO          # noqa: E402
import catalog as CA        # noqa: E402
import materials as M       # noqa: E402
from body import BODY_ORDER  # noqa: E402

# poses that catch most fitting problems: standing, both walk extremes, raised and folded arms, a two-hand swing,
# aiming, a tool held low, a hit and the fall
QUICK = [('unarmed', 'idle', 0), ('unarmed', 'walk', 2), ('unarmed', 'walk', 6), ('melee1', 'act', 0), ('melee2', 'act', 2),
         ('rifle', 'act', 0), ('pistol', 'idle', 0), ('tool', 'act', 1), ('unarmed', 'hit', 1), ('any', 'down', 2)]
FULL = ['under', 'bodysuit', 'boots', 'gloves']
BG = (22, 26, 36, 255)


def doll(body, f, garments, implants, hair):
    grip, anim, i = f
    return FR.render_doll(dict(body=body, grip='unarmed' if grip == 'any' else grip, anim=anim, i=i, garments=garments,
                               implants=implants, hair=hair))


def part_sprites(res, prefix):
    return [(img, off) for grp, sub, key, img, off, kind in res.sprites if key.startswith(prefix) and kind == 'index']


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('parts', nargs='+')
    ap.add_argument('--on', default='')
    ap.add_argument('--bodies', default=','.join(BODY_ORDER))
    ap.add_argument('--frames', default='quick', choices=('quick', 'all'))
    ap.add_argument('--lod', type=int, default=64, choices=(64, 32))
    ap.add_argument('--out', default='try.png')
    a = ap.parse_args()
    FR.set_lod(a.lod)
    t0 = time.time()
    garments, implants, hair = [], [], 'bald'
    if a.on == 'full':
        garments = list(FULL)
    elif a.on:
        garments = list(CA.O[a.on]['garments'])
    if 'under' not in garments:
        garments.insert(0, 'under')
    tried = []
    for p in a.parts:
        kind, _, name = p.partition(':')
        if kind == 'g':
            if name not in CA.G:
                sys.exit('no garment %r' % name)
            garments.append(name)
            tried.append(('wear:%s:' % name, p))
        elif kind == 'i':
            implants.append(name)
            tried.append(('imp:%s:' % name, p))
        elif kind == 'h':
            hair = name
            tried.append(('hair:%s:' % name, p))
        elif kind == 'o':
            for gid in CA.O[name]['garments']:
                if gid not in garments:
                    garments.append(gid)
                    tried.append(('wear:%s:' % gid, 'g:' + gid))
        else:
            sys.exit('a part is g:<garment>, i:<implant>, h:<hair> or o:<outfit>, not %r' % p)
    bodies = a.bodies.split(',')
    frames = QUICK if a.frames == 'quick' else [('any' if g is None else g, an, i) for (g, an, i) in PO.all_frames()]
    pal = M.palette_for({'cloth1': 'gunmetal', 'cloth2': 'olive', 'cloth3': 'black'})
    C = FR.CELL
    sheet = Image.new('RGBA', (C * len(frames), C * len(bodies)), BG)
    empty, stray, total, edge_dark, edge_all, leaks = {}, 0, 0, 0, 0, []
    for bi, b in enumerate(bodies):
        for fi, f in enumerate(frames):
            res = doll(b, f, garments, implants, hair)
            sheet.paste(FR.flatten(res, pal, bg=BG), (fi * C, bi * C))
            for prefix, name in tried:
                spr = part_sprites(res, prefix)
                if not any((img > 0).any() for img, off in spr):
                    empty.setdefault(name, []).append('%s %s/%s/%d' % (b, *f))
            # the whole doll, and which part drew each pixel
            can = np.zeros((C, C), np.int32)
            src = np.zeros((C, C), np.int32)
            for grp, sub, key, img, off, kind in res.ordered():
                if kind != 'index' or key == 'face':
                    continue
                h, w = img.shape
                x, y = off
                hit = img > 0
                can[y:y + h, x:x + w] = np.where(hit, img, can[y:y + h, x:x + w])
                mine = any(key.startswith(pf) for pf, _ in tried)
                src[y:y + h, x:x + w] = np.where(hit, 1 if mine else 0, src[y:y + h, x:x + w])
            # noise in the part as it shows on the doll: a shade none of its 8 neighbours share although its own
            # material is beside it (a lone pixel of another material, a rivet or a light, is detail, not noise)
            sh, mat = can % 8, can // 8
            ramp = (src == 1) & (sh >= 1) & (sh <= 5) & (mat != M.INK) & (mat != M.GLOW) & (mat != M.GLOW2)
            same = np.zeros(can.shape, np.int32)
            kin = np.zeros(can.shape, np.int32)
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if dy or dx:
                        q = np.roll(np.roll(can, dy, 0), dx, 1)
                        same += q == can
                        kin += (q // 8 == mat) & (q > 0)
            stray += int((ramp & (same == 0) & (kin > 0)).sum())
            total += int(ramp.sum())
            # the part's share of the doll's outer edge
            m = can > 0
            pad = np.pad(m, 1)
            edge = m & ~(pad[:-2, 1:-1] & pad[2:, 1:-1] & pad[1:-1, :-2] & pad[1:-1, 2:]) & (src == 1)
            edge_all += int(edge.sum())
            edge_dark += int((edge & ((can % 8 == 0) | (can // 8 == M.INK))).sum())
            if a.on == 'full' and f[1] != 'down':
                skin = (can // 8 == M.SKIN) & (can % 8 >= 1)
                chin = int(round(res.anchors['eye_r'][1])) + int(round(7 * a.lod / 64))
                n = int(skin[chin:].sum())
                if n:
                    leaks.append('%s %s/%s/%d %d px' % (b, *f, n))
    k = 3 if a.lod == 64 else 5
    sheet.resize((sheet.width * k, sheet.height * k), Image.NEAREST).save(a.out)
    ok = True

    def rep(name, good, detail):
        nonlocal ok
        ok &= good
        print('  %s %-8s %s' % ('PASS' if good else 'FAIL', name, detail))
    print('%s on %d bodies x %d frames (LOD %d) in %.0fs -> %s' % (' '.join(a.parts), len(bodies), len(frames), a.lod, time.time() - t0, a.out))
    rep('drawn', not empty, 'every frame' if not empty else '; '.join('%s missing in %s' % (n, ', '.join(v[:4])) for n, v in empty.items()))
    rate = stray / max(total, 1)
    rep('strays', rate < 0.01, '%.2f %%' % (rate * 100))
    fr = edge_dark / max(edge_all, 1)
    rep('outline', fr >= 0.95, '%.1f %% dark' % (fr * 100))
    if a.on == 'full':
        rep('cover', not leaks, 'no skin below the chin' if not leaks else '; '.join(leaks[:4]))
    sys.exit(0 if ok else 1)


if __name__ == '__main__':
    main()
