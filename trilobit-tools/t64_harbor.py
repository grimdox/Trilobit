"""Harbor props: shipping containers (4 colours), crane legs, the gantry beam and trolley overlays, bollards."""
import numpy as np
from art64 import Art, col, lit

COLS = ['#b8412f', '#2f5f9a', '#3f8a52', '#d0a23a']


def A():
    return Art(64, 64, 4)


def container(k):
    a = Art(64, 64, 4)
    m = a.rect(1, 3, 62, 58)
    a.shadow(m, 1.5, 2.5, 2.5, 0.5)
    a.shade(m, COLS[k], bevel=2.0, strength=0.55, spec=0.25, grain=0.1, seed=k + 3)
    for i in range(9):                              # corrugation ribs along the roof
        a.shade(a.rect(4 + i * 6.6, 5, 2.4, 54), lit(COLS[k], 0.78), bevel=0.8, strength=0.5)
    a.shade(a.rect(1, 3, 62, 3.5), lit(COLS[k], 0.62), bevel=1.0, strength=0.3)       # top rail
    a.shade(a.rect(1, 57, 62, 4), lit(COLS[k], 0.62), bevel=1.0, strength=0.3)
    for (x, y) in ((1, 3), (59, 3), (1, 57), (59, 57)):                                 # corner castings
        a.shade(a.rect(x, y, 4, 4), '#2a2d33', bevel=1.0, strength=0.4)
    a.shade(a.rect(24 + k * 3, 24, 14, 6), '#e8e8ea', bevel=0.5, strength=0.1)          # stencilled code plate
    return a.image(outline=0.85)


def crane_leg():
    a = A()
    m = a.rect(14, 8, 36, 48)
    a.shadow(m, 2.0, 3.0, 3.0, 0.5)
    a.shade(m, '#d9a21b', bevel=3.0, strength=0.7, spec=0.35, grain=0.15, seed=4)
    for y in (14, 26, 38, 50):                                                           # lattice
        a.shade(a.line(16, y, 48, y + 10, 2.2), '#a87a0f', bevel=0.8, strength=0.4)
        a.shade(a.line(48, y, 16, y + 10, 2.2), '#a87a0f', bevel=0.8, strength=0.4)
    a.shade(a.rect(10, 4, 44, 8), '#3a3f47', bevel=1.5, strength=0.6)
    a.shade(a.rect(6, 52, 52, 8), '#3a3f47', bevel=1.5, strength=0.6)
    a.shade(a.ellipse(32, 8, 2), '#ff3b30', bevel=0.8, emit=0.9)
    a.glow(32, 8, 9, '#ff3b30', 0.6)
    return a.image(outline=0.85)


def beam():
    a = A()
    m = a.rect(0, 22, 64, 20)
    a.shadow(m, 2.0, 5.0, 3.5, 0.45)
    a.shade(m, '#e0aa22', bevel=2.2, strength=0.6, spec=0.3, grain=0.12, seed=2)
    for x in range(0, 64, 16):
        a.shade(a.line(x, 24, x + 8, 40, 2.0), '#a87a0f', bevel=0.8, strength=0.4)
        a.shade(a.line(x + 16, 24, x + 8, 40, 2.0), '#a87a0f', bevel=0.8, strength=0.4)
    a.shade(a.rect(0, 21, 64, 3), '#3a3f47', bevel=1.0)
    a.shade(a.rect(0, 40, 64, 3), '#3a3f47', bevel=1.0)
    return a.image(outline=0.0)


def trolley():
    a = A()
    m = a.rect(18, 16, 28, 32)
    a.shadow(m, 3.0, 6.0, 4.0, 0.45)
    a.shade(m, '#3a3f47', bevel=2.5, strength=0.7, spec=0.5)
    a.shade(a.rect(24, 22, 16, 20), '#d9a21b', bevel=1.5)
    a.shade(a.ellipse(32, 32, 3), '#101216', bevel=1.0)
    a.shade(a.ellipse(32, 18, 1.5), '#35d7ff', bevel=0.5, emit=1.0)
    return a.image(outline=0.85)


def bollard():
    a = A()
    m = a.ellipse(32, 36, 9)
    a.shadow(m, 2.0, 3.0, 2.5, 0.5)
    a.shade(m, '#2d3239', bevel=5.0, strength=0.8, spec=0.6)
    a.shade(a.ellipse(32, 36, 4), '#555c66', bevel=2.0)
    a.shade(a.rect(24, 30, 16, 2), '#e0b020', bevel=0.4, strength=0.1)
    return a.image(outline=0.85)


def sprites(items=None):
    out = []
    for k in range(4):
        out.append(('f_trl_container.%d' % k, container(k)))
    out.append(('f_trl_container', container(0)))
    out.append(('f_trl_crane_leg', crane_leg()))
    out.append(('f_trl_crane_beam', beam()))
    out.append(('f_trl_crane_trolley', trolley()))
    out.append(('f_trl_bollard', bollard()))
    return out, {'f_trl_container': 4}
