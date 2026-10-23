#!/usr/bin/env python3
"""Quality checks on a baked doll set.  Every check has a threshold; the report lists each with its measured value.
Usage: qa.py DOLLS_DIR [REPORT_JSON]    exit code 0 only when every check passes.

  Q1 indices      every pixel of every index sprite decodes to a defined material and shade
  Q2 orphans      stray pixels in body sprites (a ramp shade none of its 8 neighbours share) under 1 %; the hand-drawn
                  face stamp is not counted
  Q3 islands      the bare body of every frame is one piece (8-connected; specks of 2 px or less count as islands)
  Q4 ground       in every standing frame the feet touch the ground line (lowest body pixel within 2 px of it)
  Q5 outline      the doll's outer edge is dark (ink or a material's line shade) on at least 97 % of edge pixels
  Q6 cover        a full suit with gloves and boots shows no skin below the chin, on every body and frame
  Q7 stability    idle frames move the head anchor by 1 px at most and change under 12 % of the body's pixels
  Q8 discipline   no body sprite uses more than 7 shades of one material (5 ramp + rim + glint)
  Q9 anchors      every frame has eye and ground anchors inside the cell; every armed frame a grip inside the cell
"""
import json
import os
import sys

import numpy as np
from scipy import ndimage as ndi

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import materials as M    # noqa: E402
from manifest import Baked   # noqa: E402

VALID_MATS = set(M.NAMES)


def run(path):
    B = Baked(path)
    man = B.man
    res = []
    K = man.get('lod', 64) / 64.0          # pixel thresholds scale with the level of detail
    C = man.get('cell', 96)

    def rep(cid, name, ok, value, detail=''):
        res.append(dict(id=cid, name=name, ok=bool(ok), value=value, detail=detail))
        print('  %s %s %-60s %s %s' % ('PASS' if ok else 'FAIL', cid, name, value, detail))

    # Q1
    bad = 0
    for n, pg in enumerate(B.idx):
        v = pg[pg > 0]
        mats = np.unique(v // 8)
        bad += int(sum(1 for m in mats if int(m) not in VALID_MATS))
    rep('Q1', 'every index decodes to a defined material', bad == 0, '%d undefined materials' % bad)
    bodies = list(man['bodies'])
    # Q2, Q3, Q4, Q8 on bare bodies
    orphan = total = 0
    islands = []
    ground_bad = []
    shade_bad = []
    for b in bodies:
        for fid, fm in man['frames'][b].items():
            spec = {'body': b, 'garments': []}
            img = None
            parts = []
            for key, kind, arr, (x, y) in B.compose(spec, fid):
                # the body sprites only: the face is a hand-drawn stamp whose 1 px iris and catch lights are designed
                if key.startswith('b/'):
                    parts.append((arr, x, y))
            canvas = np.zeros((C, C), np.int32)
            for arr, x, y in parts:
                h, w = arr.shape
                sub = canvas[y:y + h, x:x + w]
                sub[:] = np.where(arr > 0, arr, sub)
            m = canvas > 0
            mat, sh = canvas // 8, canvas % 8
            ramp = m & (sh >= 1) & (sh <= 5) & (mat != M.INK)
            # a stray pixel has no neighbour of its own colour in any of the 8 directions (a 1 px diagonal line is not stray)
            same = np.zeros_like(canvas)
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if dy or dx:
                        same += (np.roll(np.roll(canvas, dy, 0), dx, 1) == canvas)
            orphan += int((ramp & (same == 0)).sum())
            total += int(ramp.sum())
            lab, nl = ndi.label(m, structure=np.ones((3, 3)))
            if nl > 1:
                islands.append('%s %s (%d)' % (b, fid, nl))
            anim = fid.split('/')[1]
            if anim != 'down':
                low = np.nonzero(m.any(axis=1))[0].max()
                g = fm['ground'][1]
                if abs(low - g) > max(1.5, 2.5 * K):
                    ground_bad.append('%s %s low %d ground %.1f' % (b, fid, low, g))
            for mt in np.unique(mat[m]):
                k = len(np.unique(sh[m & (mat == mt)]))
                if k > 7:
                    shade_bad.append('%s %s mat %d: %d shades' % (b, fid, mt, k))
    rate = orphan / max(total, 1)
    rep('Q2', 'stray pixels in the bare bodies', rate < 0.01, '%.2f %%' % (rate * 100))
    rep('Q3', 'the bare body is one piece in every frame', not islands, '%d frames split' % len(islands), '; '.join(islands[:4]))
    rep('Q4', 'feet on the ground line in every standing frame', not ground_bad, '%d frames off' % len(ground_bad), '; '.join(ground_bad[:3]))
    rep('Q8', 'at most 7 shades of one material per body', not shade_bad, '%d over' % len(shade_bad), '; '.join(shade_bad[:3]))
    # Q5 outline, on dressed dolls
    edge_dark = edge_all = 0
    looks = [['under', 'bodysuit', 'boots', 'trench'], ['under', 'tee', 'cargo', 'boots', 'riot'], ['under', 'tank', 'leggings', 'sneakers']]
    for b in bodies:
        for li, g in enumerate(looks):
            for fid in list(man['frames'][b])[::7]:
                spec = {'body': b, 'garments': g, 'hair': 'bob', 'item': ''}
                canvas = np.zeros((C, C), np.int32)
                for key, kind, arr, (x, y) in B.compose(spec, fid):
                    if kind != 'i':
                        continue
                    h, w = arr.shape
                    sub = canvas[y:y + h, x:x + w]
                    sub[:] = np.where(arr > 0, arr, sub)
                m = canvas > 0
                edge = m & ~ndi.binary_erosion(m, structure=np.array([[0, 1, 0], [1, 1, 1], [0, 1, 0]]))
                sh, mt = canvas % 8, canvas // 8
                dark = edge & ((mt == M.INK) | (sh == 0) | (mt == M.DARK))
                edge_dark += int(dark.sum())
                edge_all += int(edge.sum())
    fr = edge_dark / max(edge_all, 1)
    rep('Q5', 'the outer edge is dark (ink outline)', fr >= 0.97, '%.1f %%' % (fr * 100))
    # Q6 cover
    leaks = []
    for b in bodies:
        for fid, fm in man['frames'][b].items():
            spec = {'body': b, 'garments': ['under', 'bodysuit', 'boots', 'gloves'], 'hair': 'bald'}
            canvas = np.zeros((C, C), np.int32)
            for key, kind, arr, (x, y) in B.compose(spec, fid):
                if kind != 'i':
                    continue
                h, w = arr.shape
                sub = canvas[y:y + h, x:x + w]
                sub[:] = np.where(arr > 0, arr, sub)
            skin = (canvas // 8 == M.SKIN) & (canvas % 8 >= 1)
            chin = fm['eye'][1] + int(round(7 * K))
            if fid.split('/')[1] == 'down':
                continue
            leak = int(skin[chin:].sum())
            if leak > 0:
                leaks.append('%s %s %d px' % (b, fid, leak))
    rep('Q6', 'a full suit shows no skin below the chin', not leaks, '%d frames leak' % len(leaks), '; '.join(leaks[:4]))
    # Q7 stability
    unstable = []
    for b in bodies:
        for grip in man['grips']:
            fids = ['%s/idle/%d' % (grip, i) for i in range(man['anims']['idle']['frames'])]
            prev = None
            for fid in fids:
                fm = B.frame_meta(b, fid)
                s = B.sprite('b/%s/%s/body' % (b, fid))
                if s is None:
                    continue
                canvas = np.zeros((C, C), np.int32)
                arr, (x, y) = s[1], s[2]
                canvas[y:y + arr.shape[0], x:x + arr.shape[1]] = arr
                if prev is not None:
                    pm, pf = prev
                    moved = max(abs(fm['eye'][0] - pf['eye'][0]), abs(fm['eye'][1] - pf['eye'][1]))
                    changed = ((canvas > 0) != (pm > 0)).sum() / max((canvas > 0).sum(), 1)
                    if moved > 1 or changed > 0.12:
                        unstable.append('%s %s moved %d changed %.0f%%' % (b, fid, moved, changed * 100))
                prev = (canvas, fm)
    rep('Q7', 'idle animation is stable (no popping)', not unstable, '%d steps unstable' % len(unstable), '; '.join(unstable[:3]))
    # Q9 anchors
    bad_a = []
    for b in bodies:
        for fid, fm in man['frames'][b].items():
            ok = 0 <= fm['eye'][0] < C and 0 <= fm['eye'][1] < C and 0 <= fm['ground'][1] < C
            if fid.split('/')[0] not in ('unarmed', 'any') and fid.split('/')[1] != 'down':
                ok = ok and 'grip' in fm and 0 <= fm['grip'][0] < C and 0 <= fm['grip'][1] < C
            if not ok:
                bad_a.append('%s %s' % (b, fid))
    rep('Q9', 'anchors present and inside the cell', not bad_a, '%d bad' % len(bad_a), '; '.join(bad_a[:3]))
    # traceable repairs (recorded per frame by the bake): reported, not judged
    tot = {}
    nf = 0
    for b in bodies:
        for fid, fm in man['frames'][b].items():
            nf += 1
            for part in ('body', 'items'):
                for k, n in fm.get('repairs', {}).get(part, {}).items():
                    tot[(part, k)] = tot.get((part, k), 0) + n
    if tot:
        print('  repairs over %d frames: bare bodies %s; garments, hair and implants %s' % (
            nf, ', '.join('%s %d' % (k, n) for (p, k), n in sorted(tot.items()) if p == 'body'),
            ', '.join('%s %d' % (k, n) for (p, k), n in sorted(tot.items()) if p == 'items')))
    passed = sum(r['ok'] for r in res)
    print('QA %d/%d' % (passed, len(res)))
    return res


if __name__ == '__main__':
    r = run(sys.argv[1])
    if len(sys.argv) > 2:
        json.dump(r, open(sys.argv[2], 'w'), indent=1)
    sys.exit(0 if all(x['ok'] for x in r) else 1)
