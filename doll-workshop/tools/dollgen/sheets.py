#!/usr/bin/env python3
"""Curated review sheets from a baked set (composed exactly as the runtime composes; see manifest.py).
Usage: sheets.py DOLLS_DIR OUT_DIR"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from manifest import Baked     # noqa: E402

BG = (27, 34, 43, 255)
INK = (143, 166, 191, 255)


def cell(B, spec, fid, crop=(14, 18, 82, 94)):
    return B.render(spec, fid, bg=BG).crop(crop)


def grid(cells, cols, k=2, labels=None, pad=2):
    w, h = cells[0].size
    rows = (len(cells) + cols - 1) // cols
    lab_h = 12 if labels else 0
    out = Image.new('RGBA', (cols * (w * k + pad) + pad, rows * (h * k + pad + lab_h) + pad), (13, 17, 23, 255))
    d = ImageDraw.Draw(out)
    for n, c in enumerate(cells):
        x = pad + (n % cols) * (w * k + pad)
        y = pad + (n // cols) * (h * k + pad + lab_h)
        out.paste(c.resize((w * k, h * k), Image.NEAREST), (x, y))
        if labels:
            d.text((x + 2, y + h * k), labels[n], fill=INK)
    return out


CAST = [
    ('Tactical operative', dict(body='f_m', garments=['under', 'bodysuit', 'boots_high', 'gloves', 'holster'], hair='bob', eyes='round', expr='focused',
                             implants=['cortex'], item='trl_gun_sp45', colours={'skin': 'porcelain', 'hair': 'violet black', 'eyes': 'violet', 'cloth1': 'gunmetal',
                                                                               'leather': 'black', 'leather2': 'black'}), 'pistol/idle/0'),
    ('Ranger', dict(body='m_l', garments=['under', 'tee', 'cargo', 'boots', 'vest_heavy', 'sling'], hair='buzz', eyes='hooded', expr='neutral',
                    implants=['optic_twin', 'cyberarm_r'], item='trl_gun_vk74', colours={'skin': 'tan', 'hair': 'platinum', 'cloth1': 'olive', 'cloth3': 'drab',
                                                                                         'cloth4': 'olive', 'poly': 'gunmetal'}), 'rifle/idle/0'),
    ('Detective', dict(body='m_m', garments=['under', 'shirt', 'slacks', 'boots', 'trench'], hair='slick', eyes='almond', expr='neutral',
                       implants=['smartlink'], item='trl_gun_vr38', colours={'skin': 'fair', 'hair': 'dark brown', 'cloth1': 'bone', 'cloth2': 'khaki',
                                                                             'cloth3': 'gunmetal'}), 'pistol/idle/0'),
    ('Netrunner', dict(body='f_s', garments=['under', 'tank', 'leggings', 'sneakers', 'hoodie'], hair='undercut', eyes='sharp', expr='neutral',
                       implants=['neural_plate', 'antenna'], item='trl_kit_repair', colours={'skin': 'olive', 'hair': 'cyan dye', 'cloth1': 'black',
                                                                                           'cloth2': 'gunmetal', 'cloth3': 'black', 'cloth4': 'teal',
                                                                                           'glow': 'cyan'}), 'tool/idle/0'),
    ('Prosthetic body', dict(body='f_m', android=True, garments=['under'], hair='bald', eyes='wide', expr='neutral', implants=['optic_twin'],
                             item='', colours={'skin': 'pearl', 'synth': 'pearl', 'glow': 'violet'}), 'unarmed/idle/0'),
    ('Graphite android', dict(body='m_m', android=True, garments=['under', 'trench'], hair='bald', eyes='round', expr='focused', implants=['jaw'],
                              item='trl_mel_katana', colours={'skin': 'graphite', 'synth': 'graphite', 'cloth2': 'black', 'glow': 'amber'}), 'melee2/idle/0'),
    ('Bratva', dict(body='m_m', garments=['under', 'tee', 'cargo', 'boots', 'bomber'], hair='undercut', eyes='hooded', expr='angry',
                    implants=['mantis'], item='trl_mel_finka', colours={'skin': 'fair', 'hair': 'ash blond', 'cloth1': 'black', 'cloth2': 'red coat',
                                                                         'cloth3': 'black', 'cloth4': 'black'}), 'melee1/idle/0'),
    ('Enforcer', dict(body='f_l', garments=['under', 'tee', 'cargo', 'boots', 'riot', 'kneepads'], hair='mohawk', eyes='sharp', expr='angry',
                      implants=['jaw', 'knee_actuator'], item='trl_mel_ono', colours={'skin': 'deep', 'hair': 'teal dye', 'cloth1': 'black',
                                                                                       'cloth3': 'olive', 'poly': 'black'}), 'melee2/idle/0'),
    ('NAP officer', dict(body='m_s', garments=['under', 'shirt', 'slacks', 'boots', 'gloves', 'visor'], hair='crop', eyes='round', expr='neutral',
                         implants=[], item='trl_gun_hx9', colours={'skin': 'brown', 'cloth1': 'police blue', 'cloth3': 'ink navy', 'poly': 'police blue'}),
     'rifle/idle/0'),
    ('Corporate', dict(body='f_l', garments=['under', 'shirt', 'skirt', 'boots', 'suit_jacket'], hair='bun', eyes='almond', expr='neutral',
                       implants=['cortex'], item='', colours={'skin': 'tan', 'hair': 'black', 'cloth1': 'white', 'cloth2': 'gunmetal', 'cloth3': 'gunmetal'}),
     'unarmed/idle/0'),
    ('Dock worker', dict(body='m_l', garments=['under', 'tee', 'boots', 'overalls', 'helmet_ball'], hair='crop', eyes='hooded', expr='neutral',
                         implants=['cyberleg_r'], item='trl_kit_repair', colours={'skin': 'brown', 'cloth1': 'slate', 'cloth2': 'rust', 'poly': 'khaki'}),
     'tool/idle/0'),
    ('Courier', dict(body='f_m', garments=['under', 'tee', 'shorts', 'sneakers', 'hoodie', 'backpack'], hair='ponytail', eyes='round', expr='neutral',
                     implants=['optic_l'], item='', colours={'skin': 'fair', 'hair': 'chestnut', 'cloth1': 'bone', 'cloth2': 'teal', 'cloth3': 'black',
                                                             'cloth4': 'drab'}), 'unarmed/idle/0'),
]


def main(dolls, out):
    B = Baked(dolls)
    os.makedirs(out, exist_ok=True)
    bodies = list(B.man['bodies'])
    # the cast at 3x
    cells = [cell(B, s, f) for n, s, f in CAST]
    grid(cells, 6, 3, [n for n, s, f in CAST]).save(os.path.join(out, 'cast.png'))
    # hair: every style on a male and a female, four colours
    cols = ['black', 'chestnut', 'platinum', 'cyan dye']
    styles = [s for s in B.man['hair']]
    cells, labels = [], []
    for st in styles:
        for n, (b, c) in enumerate((('m_m', cols[0]), ('f_m', cols[1]), ('m_s', cols[3]), ('f_l', cols[2]))):
            sp = dict(body=b, garments=['under', 'turtleneck'], hair=st, eyes='round', colours={'hair': c, 'cloth1': 'black', 'skin': ['tan', 'porcelain', 'olive', 'brown'][n]})
            cells.append(cell(B, sp, 'unarmed/idle/0', crop=(24, 22, 58, 56)))
            labels.append(st if n == 0 else '')
    grid(cells, 8, 3, labels).save(os.path.join(out, 'hair.png'))
    # faces: shapes x expressions, female and male
    cells, labels = [], []
    for b in ('f_m', 'm_m'):
        for sh in B.man['eye_shapes']:
            for ex in B.man['expressions']:
                sp = dict(body=b, garments=['under', 'turtleneck'], hair='crop' if b == 'm_m' else 'bob', eyes=sh, expr=ex,
                          colours={'eyes': 'blue', 'hair': 'black', 'cloth1': 'black', 'skin': 'fair'})
                fm = B.frame_meta(b, 'unarmed/idle/0')
                ex_, ey = fm['eye']
                cells.append(cell(B, sp, 'unarmed/idle/0', crop=(ex_ - 8, ey - 9, ex_ + 10, ey + 9)))
                labels.append('%s %s' % (sh, ex) if b == 'f_m' else '')
    grid(cells, 6, 5, labels).save(os.path.join(out, 'faces.png'))
    # implants on the bare bodies
    cells, labels = [], []
    for n, iid in enumerate(B.man['implants']):
        b = bodies[n % len(bodies)]
        sp = dict(body=b, garments=['under'], hair='crop', implants=[iid], colours={'skin': 'tan', 'glow': 'cyan'})
        cells.append(cell(B, sp, 'unarmed/idle/0'))
        labels.append(iid)
    grid(cells, 8, 2, labels).save(os.path.join(out, 'implants.png'))
    # garments one by one on a medium body (with underwear)
    cells, labels = [], []
    for n, gid in enumerate(B.man['garments']):
        b = 'm_m' if n % 2 == 0 else 'f_m'
        sp = dict(body=b, garments=['under', gid], hair='crop', colours={'cloth1': 'slate', 'cloth2': 'olive', 'cloth3': 'black', 'cloth4': 'teal'})
        cells.append(cell(B, sp, 'unarmed/idle/0'))
        labels.append(gid)
    grid(cells, 9, 2, labels).save(os.path.join(out, 'garments.png'))
    # skins across all six bodies
    cells, labels = [], []
    for sk in B.man['palette']['skins']:
        for b in bodies:
            android = sk in ('pearl', 'graphite', 'bone')
            sp = dict(body=b, android=android, garments=['under'], hair='bald' if android else 'crop', colours={'skin': sk, 'synth': sk})
            cells.append(cell(B, sp, 'unarmed/idle/0'))
            labels.append(sk if b == bodies[0] else '')
    grid(cells, 6, 2, labels).save(os.path.join(out, 'skins.png'))
    print('sheets written to', out)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
