"""64x64 ground / inventory icons for every item (guns, melee, armour, containers, food, ammo, mods, engines, charms, misc)."""
import zlib
import numpy as np
from PIL import Image
from art64 import Art, col, mix, lit, hx
import t64_guns as GN
import t64_melee as ML

STEEL = '#aeb6c0'; STEEL_D = '#59626d'; BLACK = '#1b1d22'; CY = '#35d7ff'; MG = '#ff3fa4'; GOLD = '#e4b94a'


def A():
    return Art(64, 64, 4)


def done(a, **kw):
    return a.image(outline=0.85, fit=kw.pop('fit', None), zmax=kw.pop('zmax', 1.5)) if True else None


def sh(a, m, c, bevel=2.5, **kw):
    a.shadow(m, 1.6, 2.4, 2.0, 0.5)
    a.shade(m, c, bevel=bevel, **kw)
    return m


def rr(a, x, y, w, h, c, r=2.0, bevel=2.5, **kw):
    return sh(a, a.rrect(x, y, w, h, r), c, bevel, **kw)


def el(a, cx, cy, rx, ry, c, bevel=None, **kw):
    return sh(a, a.ellipse(cx, cy, rx, ry), c, bevel or min(rx, ry) * 0.7, **kw)


def label(a, x, y, w, h, c):
    a.shade(a.rect(x, y, w, h), c, bevel=0.8, strength=0.2)


def led(a, x, y, c=CY, r=1.0):
    a.shade(a.ellipse(x, y, r), c, bevel=0.5, strength=0.1, emit=1.0)
    a.glow(x, y, r * 4, c, 0.7)


def seed(s):
    return zlib.crc32(s.encode()) & 0xffff


# ------------------------------------------------------------------------------------------------ food
def bowl(a, c_in, c_bowl='#d8dde4', topping=None, steam=True, rim='#2a3a6a'):
    el(a, 32, 36, 22, 17, c_bowl, strength=0.7, spec=0.5)
    a.stroke(a.ellipse(32, 36, 22, 17), hx(rim), 1.2, 0.9)
    m = a.ellipse(32, 34, 18, 13)
    a.shade(m, c_in, bevel=3, strength=0.4, grain=0.35, seed=7)
    if topping:
        topping(a)


def dots(a, pts, c, r=2.0):
    for (x, y) in pts:
        el(a, x, y, r, r, c, bevel=r * 0.8, shadow=False) if False else a.shade(a.ellipse(x, y, r), c, bevel=r * 0.8, strength=0.6, spec=0.3)


def plate(a, c='#e8ebef'):
    el(a, 32, 34, 25, 19, c, bevel=4, strength=0.45, spec=0.5)
    a.stroke(a.ellipse(32, 34, 17, 12), hx('#b9c0c8'), 1.0, 0.7)


def f_cup_ramen(a, it):
    m = a.poly([(16, 20), (48, 20), (43, 52), (21, 52)])
    sh(a, m, '#f2f2f4', 3, strength=0.5)
    a.shade(a.poly([(17.5, 30), (46.5, 30), (45, 40), (19, 40)]), '#e3342f', bevel=1, strength=0.3)
    a.shade(a.poly([(24, 42), (40, 42), (39, 49), (25, 49)]), '#f6d34a', bevel=1, strength=0.3)
    el(a, 32, 20, 16.5, 4, '#e6e6ea', bevel=2)
    a.shade(a.ellipse(32, 20, 13, 2.6), '#e8c36a', bevel=1.2, grain=0.5, seed=3)
    a.shade(a.rect(10, 12, 30, 2), '#d8b070', bevel=0.5)


def f_noodle(a, it):
    n = it['id']
    bowl(a, '#e0b563' if 'chow' in n else '#c98d3a')
    for i in range(7):
        a.stroke(a.line(20 + i * 3, 28, 24 + i * 3, 40, 1.4), hx('#f1d083'), 1.0, 0.9)
    dots(a, [(26, 30), (38, 32)], '#7cc24c', 2.4)
    a.shade(a.rect(40, 14, 2, 26), '#6a4a2a', bevel=0.6)


def f_gyoza(a, it):
    plate(a)
    for i in range(5):
        x = 17 + i * 7.5
        a.shade(a.ellipse(x, 33 + (i % 2) * 2, 4.5, 8), '#f1d9a0', bevel=3, strength=0.7, spec=0.3)
        a.shade(a.ellipse(x, 36 + (i % 2) * 2, 3.5, 4), '#b9742e', bevel=2.5, strength=0.4, grain=0.3, seed=i)


def f_onigiri(a, it):
    m = a.poly([(32, 12), (50, 48), (14, 48)])
    sh(a, a.rrect(14, 12, 36, 38, 7) & m, '#f4f6f0', 6, strength=0.8, grain=0.1, seed=2)
    a.shade(a.rect(22, 38, 20, 12), '#14201c', bevel=1, strength=0.3, grain=0.3, seed=5)


def f_fish_plate(a, it):
    plate(a)
    cs = ['#ff8f7a', '#ffb09e', '#ff7060']
    for i in range(5):
        a.shade(a.rrect(15 + i * 6, 24 + (i % 2), 7, 18, 3), cs[i % 3], bevel=3, strength=0.6, spec=0.5)
    a.shade(a.ellipse(46, 40, 4, 3), '#8bd06a', bevel=1.5)


def f_skewer(a, it):
    a.shade(a.line(8, 50, 56, 14, 1.8), '#a8825a', bevel=0.8, strength=0.5)
    for i in range(4):
        x, y = 20 + i * 8, 41 - i * 6.2
        sh(a, a.ellipse(x, y, 5, 4), '#8a4b22', 3, strength=0.6, grain=0.3, seed=i)
        a.shade(a.ellipse(x - 1, y - 1, 2.5, 1.8), '#c47a3a', bevel=1, strength=0.2)


def f_bento(a, it):
    rr(a, 8, 14, 48, 36, '#2a2c33', 3, 3, strength=0.5)
    a.shade(a.rrect(11, 17, 20, 30, 2), '#f4f6f0', bevel=2, grain=0.2, seed=2)
    a.shade(a.rrect(33, 17, 20, 14, 2), '#d99a3a', bevel=2, grain=0.5, seed=4)
    a.shade(a.rrect(33, 33, 20, 14, 2), '#7cc24c', bevel=2, grain=0.4, seed=9)
    dots(a, [(43, 40)], '#e3342f', 2.5)


def f_donburi(a, it):
    bowl(a, '#f4f6f0', '#b8422f', rim='#101018')
    a.shade(a.rrect(18, 27, 28, 9, 4), '#4a2a14', bevel=3, strength=0.7, spec=0.5)
    a.shade(a.rrect(20, 34, 24, 4, 2), '#8a4b22', bevel=1.5)


def f_soup(a, it):
    n = it['id']
    c = {'miso': '#c9893a', 'borscht': '#a31c2a', 'solyanka': '#c75a1a'}.get(n.split('_')[-1], '#c9893a')
    bowl(a, c, '#e8ebef' if 'miso' not in n else '#7a1f1f')
    if 'borscht' in n:
        a.shade(a.ellipse(32, 33, 5, 3.2), '#f1efe8', bevel=1.5)
    else:
        dots(a, [(26, 30), (36, 36), (40, 29)], '#e9d66a', 2)


def f_pancake(a, it):
    n = it['id']
    plate(a)
    for k in range(3):
        a.shade(a.ellipse(32, 36 - k * 3, 15, 10), '#e9b45e', bevel=4, strength=0.6, grain=0.4, seed=k)
    if 'caviar' in n:
        dots(a, [(28, 28), (34, 27), (31, 31), (36, 31), (26, 32)], '#c4262e', 1.8)
    if 'okonomi' in n:
        a.shade(a.ellipse(32, 33, 11, 6), '#3a1a10', bevel=2, strength=0.5)
        a.stroke(a.line(20, 30, 44, 35, 1.2), hx('#f1efe0'), 1.0)


def f_balls(a, it):
    plate(a, '#6a4a2a' if 'tako' in it['id'] else '#e8ebef')
    pts = [(24, 30), (34, 28), (43, 32), (28, 39), (38, 39)]
    for x, y in pts:
        a.shade(a.ellipse(x, y, 5, 5), '#9a5a22', bevel=3.5, strength=0.7, grain=0.3, seed=int(x))
    a.shade(a.ellipse(34, 33, 8, 3), '#3a1a10', bevel=1, strength=0.2) if False else None


def f_dumpling(a, it):
    plate(a)
    for x, y in [(23, 31), (33, 28), (42, 33), (28, 39), (38, 40)]:
        a.shade(a.ellipse(x, y, 6, 4.5), '#f1e2b8', bevel=3, strength=0.7, spec=0.3)
    a.shade(a.rect(28, 29, 8, 4), '#fff', bevel=1) if False else None


def f_burger(a, it):
    el(a, 32, 22, 18, 9, '#d58f3f', 5, grain=0.3, seed=1)
    a.shade(a.rrect(13, 28, 38, 5, 2), '#7cc24c', bevel=1.5)
    a.shade(a.rrect(13, 32, 38, 6, 3), '#5a2a16', bevel=2.5, grain=0.4, seed=3)
    a.shade(a.rrect(13, 37, 38, 3, 1), '#f5c842', bevel=1)
    el(a, 32, 45, 18, 6, '#c27a30', 4, grain=0.3, seed=2)


def f_taco(a, it):
    m = a.ellipse(32, 40, 24, 22) & a.rect(0, 12, 64, 28)
    sh(a, m, '#e9b45e', 5, strength=0.6, grain=0.3, seed=3)
    for x in (22, 30, 38):
        a.shade(a.ellipse(x, 22, 4, 3), '#7cc24c', bevel=1.5)
    dots(a, [(27, 24), (36, 24)], '#e3342f', 2)


def f_fries(a, it):
    for i in range(9):
        x = 18 + i * 3.4
        a.shade(a.line(x, 36, x + (i - 4) * 0.9, 12 + (i % 3) * 3, 2.6), '#f1c64a', bevel=1, strength=0.5)
    m = a.poly([(16, 30), (48, 30), (44, 54), (20, 54)])
    sh(a, m, '#d62828', 3, strength=0.5)
    a.shade(a.ellipse(32, 42, 7, 5), '#ffd23a', bevel=2)


def f_crepe(a, it):
    m = a.poly([(12, 50), (32, 8), (52, 50)])
    sh(a, m, '#eebb66', 3, strength=0.55, grain=0.3, seed=2)
    a.shade(a.poly([(24, 20), (40, 20), (42, 26), (22, 26)]), '#8a3a1a', bevel=1.2)
    dots(a, [(32, 14)], '#e3342f', 2)


def f_cup(a, it):
    n = it['id']
    c = {'sencha': '#9ac24a', 'oolong': '#c47a2a', 'kompot': '#b02a4a', 'milk': '#f4f4f0', 'vodka': '#dfeaf2',
         'sake': '#f0f0e8'}.get(n.split('_')[-1], '#c47a2a')
    m = a.poly([(20, 22), (44, 22), (40, 52), (24, 52)])
    sh(a, m, '#cde6f2', 3, strength=0.4, spec=0.7)
    a.shade(a.poly([(21, 30), (43, 30), (40, 51), (24, 51)]), c, bevel=1.5, strength=0.3)


def f_can(a, it, c='#7a5a3a', c2='#e6b84a'):
    n = it['id']
    pal = {'kan_coffee': ('#5a3a24', '#e6b84a'), 'cola': ('#c0262e', '#f4f4f4'), 'tushonka': ('#4a5a3a', '#d8d8c0'),
           'hydrogel': ('#2aa6cc', '#e8f8ff'), 'kvass': ('#7a4a1a', '#e6c06a')}
    k = n[len('trl_food_'):]
    c, c2 = pal.get(k, (c, c2))
    a.shade(a.ellipse(32, 50, 12, 4), '#8a929c', bevel=2)
    sh(a, a.rrect(20, 14, 24, 36, 4), c, 5, strength=0.9, spec=0.7)
    a.shade(a.rect(20, 26, 24, 10), c2, bevel=0.8, strength=0.15)
    el(a, 32, 14, 12, 4, '#cfd6de', 2)
    led(a, 32, 31, '#d83a3a' if k != 'hydrogel' else CY, 1.2)


def f_beer(a, it):
    n = it['id']
    sh(a, a.rrect(20, 18, 22, 32, 3), '#f4f2e8', 3, strength=0.3, spec=0.8)
    a.shade(a.rrect(22, 28, 18, 21, 2), '#e29a1a', bevel=2, strength=0.4)
    a.shade(a.rrect(20, 14, 22, 7, 3), '#fff', bevel=2)
    a.shade(a.rrect(42, 24, 8, 16, 4), '#e6eef4', bevel=1.5, strength=0.3) if False else None


def f_bottle(a, it):
    n = it['id']
    c = '#c5e1ee' if 'sake' not in n else '#e8f0f0'
    sh(a, a.rrect(24, 22, 16, 32, 4), '#2aa86a' if 'vodka' in n else c, 3, strength=0.5, spec=0.8)
    sh(a, a.rrect(29, 8, 6, 16, 2), '#2aa86a' if 'vodka' in n else c, 2, strength=0.5)
    a.shade(a.rect(24, 34, 16, 10), '#f4f4ee', bevel=0.8, strength=0.15)


def f_bread(a, it):
    n = it['id']
    if 'mochi' in n:
        for x, y, c in [(24, 36, '#fff'), (38, 34, '#f7b6c8'), (32, 24, '#bfe2a8')]:
            a.shade(a.ellipse(x, y, 9, 8), c, bevel=5, strength=0.6, spec=0.3)
        return
    m = a.rrect(10, 20, 44, 26, 8)
    sh(a, m, '#4a2e1a' if 'black' in n else '#cf9a52', 6, strength=0.7, grain=0.5, seed=4)
    for x in (22, 32, 42):
        a.stroke(a.line(x, 24, x - 3, 36, 1.5), hx('#2a190e' if 'black' in n else '#e8c27c'), 1.0, 0.7)


def f_herring(a, it):
    n = it['id']
    m = a.poly([(8, 32), (22, 22), (44, 24), (56, 18), (56, 46), (44, 40), (22, 42)])
    sh(a, m, '#a8b4c0', 4, strength=0.8, spec=0.8, grain=0.25, seed=3)
    a.shade(a.ellipse(18, 31, 1.5), '#111', bevel=0.5)


def f_natto(a, it):
    rr(a, 12, 18, 40, 28, '#f1e6c8', 2, 2, strength=0.3)
    for x in (18, 26, 34, 42):
        a.shade(a.ellipse(x, 32, 3, 3), '#8a5a2a', bevel=1.5)
    a.shade(a.rect(12, 18, 40, 5), '#c0262e', bevel=0.8, strength=0.1)


def f_fruit(a, it):
    n = it['id']
    if 'apple' in n:
        el(a, 32, 36, 16, 15, '#d62828', 10, strength=0.9, spec=0.7)
        a.shade(a.line(32, 22, 34, 14, 2), '#6a4a2a', bevel=0.6)
        a.shade(a.ellipse(40, 16, 5, 2.4), '#5ac24a', bevel=1.2)
    elif 'orange' in n:
        el(a, 32, 34, 17, 17, '#f08a1a', 11, strength=0.9, spec=0.5, grain=0.3, seed=5)
        a.shade(a.ellipse(32, 18, 3, 1.6), '#4a8a2a', bevel=0.8)
    else:
        m = a.poly([(10, 40), (20, 52), (44, 50), (54, 30), (50, 22), (44, 38), (24, 42), (14, 30)])
        sh(a, m, '#f4d03a', 3, strength=0.7, spec=0.4)
        a.shade(a.rect(48, 18, 5, 6), '#5a4a1a', bevel=0.8)


def f_bar(a, it):
    n = it['id']
    pal = {'ration': '#4a6a4a', 'protein': '#2a6aa8', 'chocolate': '#5a3018', 'glucose': '#eaf4ff', 'cheese': '#f2c24a'}
    k = n[len('trl_food_'):] if n.startswith('trl_food_') else 'ration'
    c = pal.get(k, '#4a6a4a')
    if k == 'cheese':
        sh(a, a.poly([(10, 44), (52, 36), (52, 24), (10, 28)]), c, 3, strength=0.7, grain=0.2, seed=2)
        dots(a, [(22, 36), (36, 31)], '#d9a02a', 2)
        return
    if k == 'glucose':
        sh(a, a.rrect(18, 20, 24, 24, 3), c, 4, strength=0.7, spec=0.8)
        return
    rr(a, 8, 20, 48, 26, c, 3, 3, strength=0.6, spec=0.3)
    a.shade(a.rect(8, 28, 48, 10), '#f4f4f0', bevel=0.8, strength=0.1)
    led(a, 14, 24, CY if k != 'chocolate' else MG, 0.9)


FOOD = {
    'cup_ramen': f_cup_ramen, 'gyoza': f_gyoza, 'onigiri': f_onigiri, 'sashimi': f_fish_plate, 'yakitori': f_skewer,
    'katsu': f_bento, 'unagi': f_donburi, 'miso': f_soup, 'okonomiyaki': f_pancake, 'takoyaki': f_balls,
    'pelmeni': f_dumpling, 'borscht': f_soup, 'blini': f_pancake, 'caviar_blini': f_pancake, 'solyanka': f_soup,
    'piroshki': f_bread, 'kotleta': f_bento, 'chow_mein': f_noodle, 'fried_rice': f_donburi, 'hamburger': f_burger,
    'taco': f_taco, 'fries': f_fries, 'crepe': f_crepe, 'sencha': f_cup, 'oolong': f_cup, 'kan_coffee': f_can,
    'kvass': f_can, 'kompot': f_cup, 'cola': f_can, 'beer': f_beer, 'vodka': f_bottle, 'sake': f_bottle,
    'black_bread': f_bread, 'tushonka': f_can, 'herring': f_herring, 'natto': f_natto, 'mochi': f_bread,
    'apple': f_fruit, 'orange': f_fruit, 'banana': f_fruit, 'milk': f_cup, 'protein': f_bar, 'glucose': f_bar,
    'hydrogel': f_can, 'chocolate': f_bar, 'cheese': f_bar,
}


# ------------------------------------------------------------------------------------------------ ammo
AMMO_BAND = {'fmj': '#c8a24a', 'ap': '#1d8bd6', 'hp': '#d6401d', 'shot': '#c0262e', 'slug': '#2a8a3a', 'he': '#e0d020', 'cell': CY}


def ammo_icon(a, it):
    n = it['id']
    kind = n.split('_')[-1]
    band = col(AMMO_BAND.get(kind, '#c8a24a'))
    rr(a, 10, 22, 44, 26, '#4c5560', 3, 3, strength=0.7, spec=0.3)
    a.shade(a.rect(10, 31, 44, 8), band, bevel=0.8, strength=0.15)
    for i in range(5):
        x = 16 + i * 8
        if kind == 'cell':
            break
        a.shade(a.rrect(x, 14, 5, 12, 2), '#d7a64a' if kind != 'ap' else '#7a7f88', bevel=1.6, strength=0.9, spec=0.8)
        a.shade(a.rrect(x, 14, 5, 5, 2), '#8a4a22' if kind == 'hp' else '#a8aeb8', bevel=1.4, strength=0.8, spec=0.6)
    if kind == 'cell':
        a.shade(a.rrect(14, 12, 36, 12, 3), '#1a1d24', bevel=2)
        led(a, 32, 18, CY, 2)
    a.shade(a.rect(14, 40, 18, 5), '#e8eaec', bevel=0.6, strength=0.1)


# ------------------------------------------------------------------------------------------------ mods
def mod_icon(a, it):
    k = it['id'][len('trl_mod_'):]
    D = '#262a31'
    if k in ('redot', 'holo', 'smartlink', 'laser'):
        rr(a, 14, 38, 36, 8, D, 2, 2)
        rr(a, 20, 20, 24, 20, '#30353d', 3, 3, spec=0.6)
        a.shade(a.rect(24, 24, 16, 12), '#07222c', bevel=1.2, strength=0.3)
        led(a, 32, 30, '#ff3030' if k == 'redot' else (CY if k != 'laser' else '#ff3030'), 1.4)
    elif k.startswith('scope'):
        L = 52 if k == 'scope8' else 44
        x0 = 32 - L / 2
        rr(a, x0, 26, L, 12, '#252a31', 5, 4, spec=0.8)
        el(a, x0 + 2, 32, 5, 9, '#30353d', 4)
        el(a, x0 + L - 2, 32, 4, 7, '#1b2a3a', 3)
        a.shade(a.ellipse(x0 + L - 2, 32, 2.4, 4.4), '#4aa8d0', bevel=1.2, strength=0.3, emit=0.4)
        rr(a, 28, 38, 8, 6, D, 1, 1)
    elif k in ('suppressor', 'compensator', 'flashhider', 'longbarrel', 'shortbarrel', 'choke'):
        L = {'suppressor': 46, 'compensator': 22, 'flashhider': 24, 'longbarrel': 54, 'shortbarrel': 26, 'choke': 18}[k]
        x0 = 32 - L / 2
        h = 14 if k == 'suppressor' else 8
        rr(a, x0, 32 - h / 2, L, h, '#3a3f47', h / 2.2, 3, spec=0.9)
        if k == 'compensator' or k == 'flashhider':
            for i in range(3):
                a.shade(a.rect(x0 + 12 + i * 3, 27, 1.4, 10), '#101216', bevel=0.4, strength=0.1)
        if k == 'suppressor':
            for i in range(5):
                a.shade(a.rect(x0 + 8 + i * 7, 26, 1.2, 12), '#12141a', bevel=0.4, strength=0.1)
    elif k in ('extmag', 'drum', 'quickmag'):
        if k == 'drum':
            el(a, 32, 34, 17, 17, '#2b3038', 8, spec=0.6)
            el(a, 32, 34, 7, 7, '#5a626d', 3)
            led(a, 32, 34, CY, 1.2)
        else:
            m = a.poly([(24, 8), (40, 8), (44, 56), (28, 56)]) if k == 'extmag' else a.poly([(26, 14), (40, 14), (42, 52), (28, 52)])
            sh(a, m, '#2d323a', 3, strength=0.8, spec=0.5)
            a.shade(a.rect(26, 12, 14, 3), '#7a808a', bevel=0.5)
            if k == 'quickmag':
                a.shade(a.rect(27, 44, 13, 5), '#e0702a', bevel=0.8)
    elif k in ('foregrip', 'bipod'):
        if k == 'foregrip':
            sh(a, a.poly([(24, 12), (40, 12), (42, 52), (22, 52)]), '#2c3037', 4, strength=0.8, grain=0.3, seed=5)
            for y in (22, 30, 38):
                a.shade(a.rect(25, y, 14, 2), '#15171b', bevel=0.4, strength=0.1)
        else:
            rr(a, 22, 10, 20, 6, '#2c3037', 2, 2)
            a.shade(a.line(26, 16, 16, 54, 3), '#3a3f47', bevel=1, strength=0.7)
            a.shade(a.line(38, 16, 48, 54, 3), '#3a3f47', bevel=1, strength=0.7)
    else:   # stock, cheekrest
        sh(a, a.poly([(8, 22), (50, 18), (56, 48), (8, 44)]), '#30353d', 5, strength=0.8, grain=0.3, seed=4)
        a.shade(a.rrect(44, 20, 10, 26, 3), '#1c1f24', bevel=2, strength=0.7)
        if k == 'cheekrest':
            a.shade(a.rrect(12, 14, 26, 8, 4), '#6a4a2a', bevel=2.5, grain=0.4, seed=5)


# ------------------------------------------------------------------------------------------------ armour & containers
def helmet(a, it, visor=False, balaclava=False):
    n = it['id']
    if balaclava:
        sh(a, a.ellipse(32, 34, 17, 20), '#1d2026', 9, strength=0.6, grain=0.4, seed=5)
        a.shade(a.rrect(20, 26, 24, 7, 3), '#c9a68a', bevel=2, strength=0.5)
        return
    c = '#4c5a48' if 'tac' not in n else '#2b3036'
    el(a, 32, 34, 22, 19, c, 12, strength=0.9, spec=0.7, grain=0.2, seed=2)
    a.shade(a.rrect(12, 38, 40, 6, 2), '#1f2420', bevel=1.2)
    if visor:
        a.shade(a.rrect(15, 30, 34, 13, 5), '#0a2a3a', bevel=3, strength=0.5, spec=1.0, emit=0.25)
        a.shade(a.rect(20, 33, 14, 1.4), '#a4e8ff', bevel=0.4, emit=0.6)
    else:
        a.shade(a.rect(26, 18, 12, 3), '#1c211c', bevel=0.5)
        led(a, 32, 28, CY, 0.9)


def vest(a, it, heavy=False, jacket=False, corp=False):
    c = '#2f3640' if not corp else '#4a5a72'
    if jacket:
        c = '#2a2d36'
    m = a.poly([(10, 14), (24, 10), (28, 18), (36, 18), (40, 10), (54, 14), (52, 54), (12, 54)])
    sh(a, m, c, 5, strength=0.8, grain=0.35, seed=7)
    a.shade(a.poly([(24, 10), (28, 18), (36, 18), (40, 10), (36, 12), (28, 12)]), '#15181d', bevel=0.8, strength=0.3)
    if heavy or not corp:
        a.shade(a.rrect(18, 24, 28, 24, 3), '#586270' if not heavy else '#6a7480', bevel=3, strength=0.7, spec=0.5)
        for y in (30, 37, 44):
            a.shade(a.rect(21, y, 22, 1.4), '#262b33', bevel=0.4)
    if jacket:
        a.shade(a.rect(31.2, 18, 1.6, 36), '#101216', bevel=0.4)
    led(a, 15, 20, CY, 0.9)
    if corp:
        a.shade(a.rect(14, 30, 36, 3), '#e8f0f8', bevel=0.5, emit=0.3)


def limb_guard(a, it, leg=False, heavy=False, knee=False):
    c = '#3b4450' if not heavy else '#5a6470'
    if knee:
        for x in (18, 36):
            el(a, x + 5, 34, 9, 12, c, 6, spec=0.6)
            a.shade(a.rrect(x, 28, 10, 5, 2), '#1c1f24', bevel=1)
        return
    for x in (12, 36):
        sh(a, a.poly([(x + 4, 8), (x + 16, 8), (x + 15, 54), (x + 6, 54)]) if leg else a.poly([(x, 20), (x + 16, 14), (x + 16, 48), (x + 2, 46)]), c, 4, strength=0.8, spec=0.5)
        a.shade(a.rect(x + 4, 30, 10, 2), '#171a1f', bevel=0.4)
        led(a, x + 9, 22, CY, 0.8)


def pack(a, it, kind):
    if kind == 'backpack':
        rr(a, 14, 8, 36, 46, '#2f4a52', 8, 5, strength=0.8, grain=0.3, seed=2)
        rr(a, 20, 32, 24, 18, '#26383e', 3, 3)
        a.shade(a.rect(20, 40, 24, 1.5), '#e0702a', bevel=0.4)
        a.shade(a.rect(24, 14, 16, 3), '#15191c', bevel=0.6)
        led(a, 32, 24, MG, 1.0)
    elif kind == 'duffel':
        rr(a, 6, 20, 52, 26, '#4a4f3a', 11, 6, strength=0.8, grain=0.4, seed=3)
        a.shade(a.rrect(16, 12, 32, 6, 3), '#15171a', bevel=1.5)
        a.shade(a.rect(10, 31, 44, 1.6), '#1c1f24', bevel=0.4)
    elif kind == 'pouch':
        rr(a, 14, 18, 36, 28, '#4a3a2c', 4, 4, grain=0.4, seed=3)
        a.shade(a.rrect(14, 18, 36, 11, 4), '#5c4938', bevel=3)
        a.shade(a.ellipse(32, 29, 2.4), GOLD, bevel=1.2, spec=0.8)
    elif kind == 'holster':
        sh(a, a.poly([(22, 10), (42, 10), (44, 34), (36, 52), (24, 52), (20, 34)]), '#2a2420', 4, strength=0.8, grain=0.4, seed=3)
        a.shade(a.rect(20, 20, 24, 5), '#15110e', bevel=1)
        a.shade(a.ellipse(40, 22, 2), STEEL, bevel=1, spec=0.9)
    elif kind == 'coat':
        sh(a, a.poly([(8, 12), (22, 8), (28, 16), (36, 16), (42, 8), (56, 12), (60, 56), (4, 56)]), '#2a2c36', 5, strength=0.8, grain=0.4, seed=7)
        a.shade(a.poly([(28, 16), (36, 16), (34, 56), (30, 56)]), '#15161c', bevel=0.8)
        for y in (26, 36, 46):
            a.shade(a.ellipse(36, y, 1.3), GOLD, bevel=0.6, spec=0.8)
    else:   # water bottle
        sh(a, a.rrect(22, 18, 20, 36, 6), '#9fd8ec', 4, strength=0.4, spec=0.9)
        a.shade(a.rrect(24, 32, 16, 20, 4), '#2a9ac8', bevel=2, strength=0.3)
        sh(a, a.rrect(27, 8, 10, 12, 2), '#2a2d33', 2)


ARMOR = {
    'helmet': lambda a, it: helmet(a, it), 'visor': lambda a, it: helmet(a, it, visor=True),
    'balaclava': lambda a, it: helmet(a, it, balaclava=True), 'helm_tac': lambda a, it: helmet(a, it),
    'vest': lambda a, it: vest(a, it), 'vest_heavy': lambda a, it: vest(a, it, heavy=True),
    'vest_corp': lambda a, it: vest(a, it, corp=True), 'jacket': lambda a, it: vest(a, it, jacket=True),
    'bracers': lambda a, it: limb_guard(a, it), 'bracers_heavy': lambda a, it: limb_guard(a, it, heavy=True),
    'greaves': lambda a, it: limb_guard(a, it, leg=True), 'greaves_heavy': lambda a, it: limb_guard(a, it, leg=True, heavy=True),
    'kneepads': lambda a, it: limb_guard(a, it, knee=True),
    'backpack': lambda a, it: pack(a, it, 'backpack'), 'holster': lambda a, it: pack(a, it, 'holster'),
    'coat': lambda a, it: pack(a, it, 'coat'), 'pouch': lambda a, it: pack(a, it, 'pouch'),
    'duffel': lambda a, it: pack(a, it, 'duffel'), 'water_bottle': lambda a, it: pack(a, it, 'bottle'),
}


# ------------------------------------------------------------------------------------------------ engines, charms, misc
def engine(a, it):
    k = it['id'].split('_')[-1]
    big = k in ('haul', 'reactor', 'rotor')
    if k == 'reactor':
        el(a, 32, 32, 22, 22, '#2d323a', 10, spec=0.6)
        el(a, 32, 32, 12, 12, '#0a2a38', 5, emit=0.5)
        a.glow(32, 32, 18, CY, 0.9)
        for ang in range(0, 360, 60):
            x, y = 32 + 18 * np.cos(np.radians(ang)), 32 + 18 * np.sin(np.radians(ang))
            led(a, x, y, CY, 1.2)
        return
    if k == 'rotor':
        rr(a, 8, 22, 40, 20, '#3a4048', 8, 5, spec=0.7)
        el(a, 52, 32, 6, 11, '#1d2026', 4)
        for x in (16, 24, 32):
            a.shade(a.rect(x, 20, 2, 24), '#20242a', bevel=0.4)
        return
    w = 46 if big else 36
    x0 = 32 - w / 2
    rr(a, x0, 14, w, 36, '#454c56', 5, 4, strength=0.8, spec=0.6, grain=0.2, seed=3)
    for i in range(4 if big else 3):
        a.shade(a.rect(x0 + 6 + i * 9, 14, 3, 36), '#2a2f36', bevel=0.5, strength=0.2)
    rr(a, x0 - 4, 26, 6, 12, '#2a2f36', 2, 2)
    a.shade(a.rrect(x0 + w - 4, 24, 10, 16, 2), '#8a929c', bevel=2, spec=0.8)
    led(a, 32, 44, '#6aff7a' if k != 'sport' else MG, 1.2)


def charm(a, it):
    k = it['id'].split('_')[-1]
    if k == 'candle':
        rr(a, 24, 20, 16, 32, '#f6f1dc', 5, 4)
        a.shade(a.line(32, 20, 32, 14, 1.2), '#222', bevel=0.4)
        a.glow(32, 12, 10, '#ffb03a', 1.0)
        a.shade(a.ellipse(32, 11, 2.2, 4), '#ffd25a', bevel=1, emit=1.0)
    elif k == 'icon':
        rr(a, 14, 8, 36, 48, '#6a4a2a', 3, 3, grain=0.4, seed=2)
        a.shade(a.rect(18, 12, 28, 40), '#d7a64a', bevel=1.5, spec=0.9)
        a.shade(a.ellipse(32, 26, 8, 9), '#e8c9a0', bevel=3)
        a.shade(a.rrect(22, 36, 20, 12, 3), '#8a2a2a', bevel=2)
    elif k == 'gospel':
        rr(a, 12, 12, 40, 40, '#2a2a3a', 3, 3, grain=0.4, seed=2)
        a.shade(a.rect(30, 18, 4, 28), GOLD, bevel=1, spec=0.9)
        a.shade(a.rect(24, 24, 16, 4), GOLD, bevel=1, spec=0.9)
        a.shade(a.rect(10, 12, 3, 40), '#d9d5c4', bevel=0.5)
    elif k == 'omamori':
        rr(a, 18, 14, 28, 38, '#c0262e', 4, 4, grain=0.3, seed=2)
        a.shade(a.rect(22, 22, 20, 4), GOLD, bevel=0.8, spec=0.9)
        a.shade(a.rect(22, 34, 20, 8), '#f1e6c8', bevel=0.8, strength=0.1)
        a.shade(a.line(32, 14, 32, 6, 1.4), '#d9b24a', bevel=0.5)
    elif k == 'ofuda':
        rr(a, 20, 8, 24, 48, '#f1ead2', 1, 1.5, grain=0.4, seed=2)
        for y in (14, 24, 34, 44):
            a.shade(a.rect(26, y, 12, 3), '#1a1a22', bevel=0.4, strength=0.1)
        a.shade(a.rect(40, 10, 2, 44), '#c0262e', bevel=0.4)
    else:   # ema
        sh(a, a.poly([(32, 8), (54, 22), (50, 54), (14, 54), (10, 22)]), '#b98a52', 3, strength=0.7, grain=0.5, seed=2)
        a.shade(a.ellipse(32, 36, 9, 9), '#c0262e', bevel=2)


def misc(a, it):
    n = it['id']
    if n == 'trl_yen':
        for i, (x, y, r) in enumerate([(22, 40, 0), (30, 32, 1), (38, 24, 2)]):
            sh(a, a.rrect(x - 14, y - 8, 36, 18, 2), ['#5a8a5a', '#6aa06a', '#7ab87a'][i], 2, strength=0.5, grain=0.2, seed=i)
            a.shade(a.ellipse(x + 4, y + 1, 5), '#cfe8c8', bevel=1.2, strength=0.2)
    elif n == 'trl_water':
        el(a, 32, 38, 18, 12, '#3aa8e0', 6, strength=0.5, spec=0.9)
        a.shade(a.ellipse(26, 33, 6, 3), '#bfeaff', bevel=1)
    elif n == 'trl_medkit':
        rr(a, 8, 16, 48, 32, '#f2f2f2', 4, 4, spec=0.5)
        a.shade(a.rect(28, 22, 8, 20), '#d62828', bevel=0.8, strength=0.15)
        a.shade(a.rect(22, 28, 20, 8), '#d62828', bevel=0.8, strength=0.15)
        a.shade(a.rrect(24, 11, 16, 6, 2), '#b8bec6', bevel=1.5)
    elif n == 'trl_kit_repair':
        rr(a, 8, 20, 48, 28, '#c05a1a', 4, 4, spec=0.4, grain=0.2, seed=3)
        a.shade(a.rrect(22, 12, 20, 9, 3), '#1c1f24', bevel=2)
        a.shade(a.rect(14, 30, 36, 3), '#2a2f36', bevel=0.5)
        a.shade(a.ellipse(48, 40, 2.4), STEEL, bevel=1, spec=0.9)
    elif n == 'trl_credstick':
        sh(a, a.poly([(10, 44), (14, 38), (50, 22), (54, 26), (50, 36), (14, 50)]), '#2a2f3c', 2, strength=0.7, spec=0.8)
        led(a, 44, 28, CY, 1.4)
        a.shade(a.line(16, 44, 36, 36, 1.4), GOLD, bevel=0.5, spec=0.8)
    elif n == 'trl_parcel':
        rr(a, 10, 16, 44, 32, '#b98a52', 2, 2, grain=0.5, seed=2)
        a.shade(a.rect(28, 16, 8, 32), '#d9c08a', bevel=0.8, strength=0.2)
        a.shade(a.rect(38, 28, 12, 9), '#f4f4f0', bevel=0.6, strength=0.1)
    elif n == 'trl_datacase':
        rr(a, 10, 18, 44, 30, '#2a2d34', 4, 4, spec=0.8, grain=0.2, seed=2)
        a.shade(a.rrect(24, 12, 16, 7, 3), '#1c1f24', bevel=1.5)
        a.shade(a.rect(10, 31, 44, 1.5), '#12141a', bevel=0.4)
        led(a, 16, 40, MG, 1.0)
        led(a, 22, 40, CY, 1.0)
    else:
        rr(a, 14, 18, 36, 28, '#6a7480', 3, 3)


def make(it):
    n = it['id']
    tags = it['tags']
    if 'gun' in tags:
        return GN.gun_icon(it)
    if tags[0] == 'melee':
        base = n[len('trl_mel_'):]
        grade = ''
        for g in ('_f', '_m'):
            if base.endswith(g):
                grade, base = g, base[:-2]
        return ML.melee_icon(base, it, grade)
    a = A()
    k = n[len('trl_food_'):] if n.startswith('trl_food_') else None
    kk = n[4:]
    if k in FOOD:
        FOOD[k](a, it)
    elif n == 'trl_ration':
        f_bar(a, it)
    elif tags[0] == 'ammo':
        ammo_icon(a, it)
    elif tags[0] == 'mod':
        mod_icon(a, it)
    elif kk in ARMOR:
        ARMOR[kk](a, it)
    elif tags[0] == 'engine':
        engine(a, it)
    elif tags[0] == 'charm':
        charm(a, it)
    else:
        misc(a, it)
    return a.image(outline=0.85, fit=54, zmax=1.4)


def sprites(items):
    out = []
    for it in items:
        out.append((it['id'], make(it)))
    return out, {}
