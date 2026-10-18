#!/usr/bin/env python3
"""Proposal sheet for the three-quarter dolls.  Usage: tq_preview.py OUTDIR  (deterministic)"""
import sys, os
from PIL import Image
import t64_tq as T

def main(o):
    os.makedirs(o, exist_ok=True)
    bg = (74, 76, 88, 255)
    Z = 4
    im = Image.new('RGBA', (3 * 128 * Z, 128 * Z + 64 * 4 + 20), bg)
    for i, p in enumerate(T.POSES):
        m = T.compose(p)
        im.alpha_composite(m.resize((128 * Z, 128 * Z), Image.NEAREST), (i * 128 * Z, 0))
        g = T.down(m)
        im.alpha_composite(g.resize((64 * 3, 64 * 3), Image.NEAREST), (i * 128 * Z + 40, 128 * Z + 10))
        im.alpha_composite(g, (i * 128 * Z + 300, 128 * Z + 10))
        m.save(os.path.join(o, 'doll_%s_128.png' % p))
        g.save(os.path.join(o, 'doll_%s_64.png' % p))
    im.convert('RGB').save(os.path.join(o, 'dolls_tq.png'))

if __name__ == '__main__':
    main(sys.argv[1])
