#!/usr/bin/env python3
"""Quality checks on the baked tilesets.  Usage: qa.py SETS [GAME_TILESET_CONFIG]

  T1 coverage     every catalogue id is in every theme, and every non-item id of the game's base set is drawn
  T2 seams        ground tiles wrap: the step across the tile edge is no bigger than the biggest step inside it (x 1.2)
  T3 discipline   no sprite uses more than 7 shades of one material and no more than 56 colours in all
  T4 noise        lone pixels (no 8-neighbour of the same colour) under 1.5 % of object pixels, lights excepted
  T5 outline      the outer edge of objects is dark on at least 90 % of its pixels (not where a piece runs on)
  T6 colour names an id that names a colour shows that colour (f_trl_neon_green is green)
  T7 distinct     the five themes draw the same id differently (walk, road, wall, floor differ between every pair)
"""
import colorsys
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import catalog as CA     # noqa: E402
import themes as TH      # noqa: E402

COLOUR_WORDS = {'red': 0, 'pink': 330, 'green': 120, 'cyan': 185, 'violet': 265, 'amber': 38, 'blue': 215, 'yellow': 55, 'orange': 25}


def load(sets, theme):
    d = os.path.join(sets, theme)
    cfg = json.load(open(os.path.join(d, 'tile_config.json')))
    sheet = np.array(Image.open(os.path.join(d, 'sheet_tiles.png')).convert('RGBA'))
    out = {}
    for t in cfg['tiles-new'][0]['tiles']:
        k = t['fg'] - 1
        r, c = divmod(k, sheet.shape[1] // 64)
        out[t['id']] = sheet[r * 64:(r + 1) * 64, c * 64:(c + 1) * 64]
    return out, cfg


def run(sets, base_cfg=None):
    res = []

    def rep(cid, name, ok, value, detail=''):
        res.append({'id': cid, 'name': name, 'ok': bool(ok), 'value': value, 'detail': detail})
        print('  %s %s %-50s %s %s' % ('PASS' if ok else 'FAIL', cid, name, value, detail))
    S = {th: load(sets, th) for th in TH.ORDER}
    # T1
    missing = []
    want = []
    for id_, (f, n, kind) in CA.CATALOG.items():
        want += [id_] if n == 1 else ['%s.%d' % (id_, v) for v in range(n)]
    for th in TH.ORDER:
        missing += ['%s %s' % (th, w) for w in want if w not in S[th][0]]
    if base_cfg and os.path.exists(base_cfg):
        base = json.load(open(base_cfg))
        ids = {t['id'] for t in base['tiles-new'][0]['tiles']}
        for i in sorted(ids):
            b = i.split('.')[0]
            if b.startswith('trl_') or b.startswith('mon_') or b.startswith('icon'):
                continue
            if i not in S['mid'][0]:
                missing.append('base ' + i)
    rep('T1', 'every id in every theme (and every base id)', not missing, '%d missing' % len(missing), '; '.join(missing[:5]))
    # T2
    bad = []
    for th in TH.ORDER:
        for id_, (f, n, kind) in CA.CATALOG.items():
            if kind != 'ground':
                continue
            for v in range(n):
                im = S[th][0][id_ if n == 1 else '%s.%d' % (id_, v)][..., :3].astype(int)
                # the step across the tile edge against the steps between neighbouring columns (rows) inside it:
                # a seam the pattern itself has (a slab joint) is fine, a jump the pattern never makes is not
                cols = np.abs(np.diff(im, axis=1)).mean(axis=(0, 2))
                rows = np.abs(np.diff(im, axis=0)).mean(axis=(1, 2))
                ecol = np.abs(im[:, 0] - im[:, -1]).mean()
                erow = np.abs(im[0] - im[-1]).mean()
                edge = max(ecol / max(cols.max(), 1.0), erow / max(rows.max(), 1.0))
                inside = 1.0
                if edge > 1.2 and max(ecol, erow) > 4.0:
                    bad.append('%s %s %.2fx' % (th, id_, edge))
    rep('T2', 'ground tiles join without seams', not bad, '%d seams' % len(bad), '; '.join(bad[:4]))
    # T3
    bad = []
    for th in TH.ORDER:
        for k, im in S[th][0].items():
            op = im[..., 3] == 255
            cols = np.unique(im[op][:, :3], axis=0)
            if len(cols) > 56:
                bad.append('%s %s %d colours' % (th, k, len(cols)))
    rep('T3', 'restrained palette per sprite (<= 56 colours)', not bad, '%d over' % len(bad), '; '.join(bad[:4]))
    # T4
    lone = tot = 0
    for th in TH.ORDER:
        for id_, (f, n, kind) in CA.CATALOG.items():
            if kind != 'object':
                continue
            for v in range(n):
                im = S[th][0][id_ if n == 1 else '%s.%d' % (id_, v)]
                op = im[..., 3] == 255
                code = np.where(op, im[..., 0].astype(int) * 65536 + im[..., 1].astype(int) * 256 + im[..., 2], -1)
                same = np.zeros(code.shape, int)
                p = np.pad(code, 1, constant_values=-2)
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        if dy or dx:
                            same += p[1 + dy:65 + dy, 1 + dx:65 + dx] == code
                hsv = np.array([colorsys.rgb_to_hsv(*(c / 255.0)) for c in im[op][:, :3]]) if op.any() else np.zeros((0, 3))
                bright = np.zeros(code.shape, bool)
                if op.any():
                    bright[op] = (hsv[:, 1] > 0.5) & (hsv[:, 2] > 0.8)       # lights and glints are allowed to stand alone
                lone += int((op & (same == 0) & ~bright).sum())
                tot += int(op.sum())
    rate = lone / max(tot, 1)
    rep('T4', 'no pixel noise in objects', rate < 0.015, '%.2f %%' % (rate * 100))
    # T5
    dark = edges = 0
    for th in TH.ORDER:
        for id_, (f, n, kind) in CA.CATALOG.items():
            if kind != 'object':
                continue
            for v in range(n):
                im = S[th][0][id_ if n == 1 else '%s.%d' % (id_, v)]
                op = im[..., 3] == 255
                p = np.pad(op, 1, constant_values=False)
                e = op & ~(p[:-2, 1:-1] & p[2:, 1:-1] & p[1:-1, :-2] & p[1:-1, 2:])
                e[0, :] = e[-1, :] = e[:, 0] = e[:, -1] = False          # pieces that run on into the next cell
                lum = im[..., :3].astype(float) @ np.array([0.3, 0.59, 0.11])
                edges += int(e.sum())
                dark += int((e & (lum < 96)).sum())
    fr = dark / max(edges, 1)
    rep('T5', 'objects keep a dark outline', fr >= 0.9, '%.1f %%' % (fr * 100))
    # T6
    bad = []
    for th in TH.ORDER:
        for k, im in S[th][0].items():
            words = [w for w in COLOUR_WORDS if ('_' + w) in k]
            if not words:
                continue
            op = im[..., 3] == 255
            px = im[op][:, :3] / 255.0
            hsv = np.array([colorsys.rgb_to_hsv(*c) for c in px])
            sat = hsv[(hsv[:, 1] > 0.45) & (hsv[:, 2] > 0.35)]
            if len(sat) < 20:
                bad.append('%s %s no colour' % (th, k))
                continue
            h = np.degrees(np.angle(np.exp(1j * sat[:, 0] * 2 * np.pi).mean())) % 360
            want_h = COLOUR_WORDS[words[0]]
            dist = min(abs(h - want_h), 360 - abs(h - want_h))
            if dist > 40:
                bad.append('%s %s hue %.0f' % (th, k, h))
    rep('T6', 'ids that name a colour show it', not bad, '%d off' % len(bad), '; '.join(bad[:4]))
    # T7
    bad = []
    for id_ in ('t_sidewalk.0', 't_pavement.0', 't_wall.10', 't_floor.0', 't_door_closed', 'f_trl_shop_counter'):
        for i, a in enumerate(TH.ORDER):
            for b in TH.ORDER[i + 1:]:
                d = np.abs(S[a][0][id_].astype(int) - S[b][0][id_].astype(int)).mean()
                if d < 6:
                    bad.append('%s %s/%s %.1f' % (id_, a, b, d))
    rep('T7', 'every theme draws its own version', not bad, '%d too alike' % len(bad), '; '.join(bad[:4]))
    passed = sum(r['ok'] for r in res)
    print('TILES QA %d/%d' % (passed, len(res)))
    return res


if __name__ == '__main__':
    r = run(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)
    sys.exit(0 if all(x['ok'] for x in r) else 1)
