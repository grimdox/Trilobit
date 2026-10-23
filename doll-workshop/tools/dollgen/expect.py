#!/usr/bin/env python3
"""Reference images for the runtime fidelity test: a few specs rendered by the generator itself (frame.render_doll +
the canonical palette), saved with their specs to tests/expected/.  tests/render_check.gd renders the same specs with
the real rig and palette shader and requires every pixel to match.
Usage: expect.py ITEMS_JSON OUT_DIR [LOD]"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import frame as FR          # noqa: E402
import materials as M       # noqa: E402

CASES = [
    ('operative_rifle', dict(body='m_m', garments=['under', 'bodysuit', 'boots', 'vest_heavy', 'harness'], hair='crop', eyes='sharp', expr='focused',
                             implants=['optic_r', 'shoulder_mount'], item='trl_gun_vk74', colours={'cloth1': 'gunmetal', 'cloth4': 'olive', 'skin': 'olive'}),
     ('rifle', 'idle', 0)),
    ('major_pistol', dict(body='f_m', garments=['under', 'bodysuit', 'boots_high', 'trench'], hair='bob', eyes='round', expr='neutral',
                          implants=['cortex'], item='trl_gun_sp45', colours={'skin': 'porcelain', 'hair': 'violet black', 'cloth2': 'drab'}),
     ('pistol', 'act', 0)),
    ('android_blade', dict(body='f_s', android=True, garments=['under'], hair='bald', eyes='wide', expr='neutral', implants=['optic_twin'],
                           item='trl_mel_wakizashi', colours={'skin': 'pearl', 'synth': 'pearl', 'glow': 'violet'}),
     ('melee1', 'walk', 3)),
    ('enforcer_axe', dict(body='m_l', garments=['under', 'tee', 'cargo', 'boots', 'riot', 'kneepads'], hair='mohawk', eyes='hooded', expr='angry',
                          implants=['cyberarm_r', 'jaw'], item='trl_mel_ono', colours={'skin': 'deep', 'hair': 'teal dye', 'cloth3': 'olive'}),
     ('melee2', 'act', 1)),
    ('runner_down', dict(body='f_l', garments=['under', 'tank', 'leggings', 'sneakers', 'hoodie'], hair='ponytail', eyes='almond', expr='pain',
                         implants=['neural_plate'], item='', colours={'skin': 'brown', 'hair': 'cyan dye', 'cloth2': 'teal'}),
     (None, 'down', 2)),
    ('detective_walk', dict(body='m_m', garments=['under', 'shirt', 'slacks', 'boots', 'trench'], hair='slick', eyes='almond', expr='blink',
                            implants=['smartlink'], item='trl_mel_finka', colours={'skin': 'fair', 'hair': 'dark brown', 'cloth2': 'khaki'}),
     ('melee1', 'walk', 2)),
]


def main(items_path, out, lod=64):
    FR.set_lod(lod)
    items = {i['id']: i for i in json.load(open(items_path))}
    os.makedirs(out, exist_ok=True)
    index = []
    for name, spec, (grip, anim, i) in CASES:
        d = dict(spec)
        d.update(body=spec['body'], grip=grip if grip else 'unarmed', anim=anim, i=i, held=items.get(spec.get('item') or '', None))
        if anim == 'down':
            d['grip'] = None
            d['held'] = None
        res = FR.render_doll(d)
        im = FR.flatten(res, M.palette_for(spec.get('colours', {})))
        im.save(os.path.join(out, name + '.png'))
        index.append({'name': name, 'spec': spec, 'frame': '%s/%s/%d' % (grip or 'any', anim, i), 'anim': anim, 'i': i})
    json.dump(index, open(os.path.join(out, 'cases.json'), 'w'), indent=1)
    print('wrote %d reference images' % len(index))


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 64)
