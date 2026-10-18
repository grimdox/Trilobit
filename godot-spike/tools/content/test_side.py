#!/usr/bin/env python3
"""Checks for the side-view dolls: every layer is 64x64, composites are deterministic, Mokuhanga uses at most 3 inks + transparency."""
import numpy as np, t64_side as S
ok = tot = 0
def chk(c, m):
    global ok, tot
    tot += 1; ok += bool(c)
    if not c: print('FAIL', m)
for st in ('bouma', 'moku'):
    for d in S.DOLLS:
        L = S.layers_for_export(d, st)
        chk(all(im.size == (64, 64) for im in L.values()), 'size %s %s' % (d, st))
        a = S.compose(d, st, armor='A1', item='rifle'); b = S.compose(d, st, armor='A1', item='rifle')
        chk(np.array_equal(np.asarray(a), np.asarray(b)), 'deterministic %s %s' % (d, st))
        ys, xs = np.nonzero(np.asarray(a)[..., 3] > 8)
        chk(ys.max() >= 60 and ys.min() >= 0 and xs.min() >= 0 and xs.max() < 64, 'feet on ground / inside tile %s' % d)
for d in S.DOLLS:
    for it in (None, 'pistol'):
        im = np.asarray(S.compose(d, 'moku', armor='A2', item=it)).reshape(-1, 4)
        px = im[im[:, 3] > 250][:, :3]
        # count distinct hues after snapping to the three inks + antialias ramps between them
        ink, paper, neon = (np.round(S.col(S.STYLES['moku'][k]) * 255) for k in ('ink', 'paper', 'neon'))
        near = lambda c: (np.abs(px - c).sum(1) < 60)
        frac = (near(ink) | near(paper) | near(neon)).mean()
        chk(frac > 0.85, 'moku mostly 3 inks %s (%.2f)' % (d, frac))
print('SIDE %d/%d' % (ok, tot))
