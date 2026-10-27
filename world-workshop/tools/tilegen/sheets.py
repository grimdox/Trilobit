#!/usr/bin/env python3
"""Review sheets from a bake.  Usage: sheets.py SETS OUT

  compare.png        the same ids side by side in all five themes (one theme per row)
  sheet_<theme>.png  every sprite of a theme over its floor
  icons.png          every item icon over a floor
  rooms_sample.png   seeds 1-4 of a furnished room (kind, floor, fittings and pieces drawn by the seed) in every theme
  furniture_<theme>  the business and home furniture and floors, three variants each
  random_sample.png  seeds 1-3 of a small generated street block (road, kerb, building with door and windows,
                     furnished interior, park) in every theme, exactly as generated: nothing picked or retouched
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import themes as TH      # noqa: E402
import catalog as CA     # noqa: E402
from canvas import Rng   # noqa: E402
from qa import load      # noqa: E402

BG = (12, 14, 20, 255)


def over(*imgs):
    out = Image.new('RGBA', (64, 64), (0, 0, 0, 0))
    for im in imgs:
        if im is not None:
            out.alpha_composite(Image.fromarray(im))
    return out


COMPARE = [('t_sidewalk.0', None), ('t_pavement.1', None), ('t_concrete.0', None), ('t_floor.0', None), ('t_grass.1', None),
           ('t_water_dp.0', None), ('t_wall.10', 't_floor.0'), ('t_wall.6', 't_floor.0'), ('t_wall_glass.10', 't_floor.0'),
           ('t_door_closed', 't_floor.0'), ('t_door_metal_locked', 't_floor.0'), ('f_trl_shop_counter', 't_floor.0'),
           ('f_trl_shelf_clean', 't_floor.0'), ('f_trl_vending', 't_sidewalk.0'), ('t_tree.0', 't_grass.0'),
           ('f_trl_tree_street', 't_sidewalk.0'), ('f_trl_streetlight', 't_sidewalk.0'), ('f_trl_bench', 't_sidewalk.0'),
           ('f_trl_planter', 't_sidewalk.0'), ('f_trl_statue', 't_grass.0'), ('f_trl_fountain', 't_trl_plaza.0'),
           ('f_trl_dumpster.0', 't_pavement.0'), ('f_dumpster.0', 't_pavement.0'), ('t_manhole_cover', None)]


def compare(S, out):
    k = 2
    w = len(COMPARE)
    img = Image.new('RGBA', (w * 64 * k, len(TH.ORDER) * 64 * k), BG)
    for r, th in enumerate(TH.ORDER):
        spr = S[th][0]
        for c, (id_, under) in enumerate(COMPARE):
            if id_ not in spr:
                id_ = id_.split('.')[0]
            im = over(spr.get(under) if under else None, spr.get(id_))
            img.paste(im.resize((64 * k, 64 * k), Image.NEAREST), (c * 64 * k, r * 64 * k))
    img.save(os.path.join(out, 'compare.png'))


def theme_sheet(S, th, out):
    spr = S[th][0]
    names = sorted(spr)
    cols = 24
    rows = (len(names) + cols - 1) // cols
    img = Image.new('RGBA', (cols * 64, rows * 64), BG)
    fl = spr['t_floor.0']
    for i, n in enumerate(names):
        kind = CA.CATALOG.get(n.split('.')[0] if n.split('.')[0] in CA.CATALOG else n, (None, 1, 'object'))[2]
        im = over(fl if kind == 'object' else None, spr[n])
        img.paste(im, ((i % cols) * 64, (i // cols) * 64))
    img.save(os.path.join(out, 'sheet_%s.png' % th))


# ------------------------------------------------------------------------------------------------ the random sample
W, H = 12, 8


def block(spr, th, seed):
    """a street block from a seed: a road along the bottom, a kerb, a building with a door and windows, its interior
    furnished, a strip of park; the same rules the game uses for walls and street furniture"""
    rng = Rng('block', th, seed)
    g = [['grass'] * W for _ in range(H)]
    for x in range(W):
        g[H - 1][x] = 'road'
        g[H - 2][x] = 'road'
        g[H - 3][x] = 'walk'
    x0, x1 = rng.int(0, 2), rng.int(7, 10)
    y0, y1 = rng.int(0, 1), H - 4
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            edge = x in (x0, x1) or y in (y0, y1)
            g[y][x] = 'wall' if edge else 'floor'
    door = rng.int(x0 + 1, x1 - 1)
    g[y1][door] = 'door'
    for k in range(2):
        wx = rng.int(x0 + 1, x1 - 1)
        if wx != door:
            g[y0][wx] = 'glass'
    for x in range(x1 + 1, W):
        for y in range(0, H - 3):
            g[y][x] = 'grass'
    furn = [k for k, (f, n, kind) in CA.CATALOG.items() if k.startswith('f_trl_') and kind == 'object' and k not in
            ('f_trl_crane_beam', 'f_trl_crane_trolley', 'f_trl_crane_leg', 'f_trl_ev_nw', 'f_trl_ev_ne', 'f_trl_ev_sw', 'f_trl_ev_se',
             'f_trl_container', 'f_trl_spill_chem', 'f_trl_spill_oil', 'f_trl_puddle', 'f_trl_portal', 'f_trl_device')]
    img = Image.new('RGBA', (W * 64, H * 64), BG)

    def isw(x, y):
        return 0 <= x < W and 0 <= y < H and g[y][x] in ('wall', 'glass', 'door')
    for y in range(H):
        for x in range(W):
            c = g[y][x]
            v = (x * 7 + y * 13 + seed) % 4
            layers = []
            if c == 'road':
                layers = [spr['t_pavement.%d' % (v % 6)]]
            elif c == 'walk':
                layers = [spr['t_sidewalk.%d' % v]]
                h = (x * 2654435761 + seed * 97) & 0xffff
                road = True
                deco = None
                if h % 4 == 0:
                    deco = {'rich': 'f_trl_tree_street', 'mid': 'f_trl_streetlight', 'slum': 'f_trl_streetlight_broken',
                            'rural': 'f_trl_woodpile', 'industry': 'f_trl_barrels'}[th]
                elif h % 5 == 0:
                    deco = {'rich': 'f_trl_bench', 'mid': 'f_trl_neon_pink', 'slum': 'f_trl_spill_chem', 'rural': 'f_trl_fence',
                            'industry': 'f_trl_pallet'}[th]
                if deco:
                    layers.append(spr[deco])
            elif c == 'grass':
                layers = [spr['t_grass.%d' % (v % 6)]]
                h = (x * 40503 + y * 9973 + seed * 31) & 0xffff
                if h % 5 == 0:
                    layers.append(spr['t_tree.%d' % (h % 3)])
                elif h % 7 == 0:
                    layers.append(spr[{'rich': 'f_trl_fountain', 'mid': 'f_trl_statue', 'slum': 'f_trl_shrub_wild', 'rural': 'f_trl_haystack',
                                       'industry': 'f_trl_fuel_tank'}[th]])
            elif c in ('wall', 'glass'):
                bits = (1 if isw(x, y - 1) else 0) | (2 if isw(x + 1, y) else 0) | (4 if isw(x, y + 1) else 0) | (8 if isw(x - 1, y) else 0)
                layers = [spr['t_concrete.0'], spr[('t_wall_glass.%d' if c == 'glass' else 't_wall.%d') % bits]]
            elif c == 'door':
                layers = [spr['t_floor.0'], spr['t_door_closed']]
            else:
                layers = [spr['t_floor.%d' % (v % 3)]]
                if rng.chance(0.35):
                    layers.append(spr[rng.pick(furn)])
            img.alpha_composite(over(*layers), (x * 64, y * 64))
    return img


def random_sample(S, out, seeds=range(1, 4)):
    panels = []
    for th in TH.ORDER:
        row = [block(S[th][0], th, s) for s in seeds]
        panels.append(row)
    pw, ph = W * 64, H * 64
    img = Image.new('RGBA', (len(seeds) * (pw + 16), len(TH.ORDER) * (ph + 16)), BG)
    for r, row in enumerate(panels):
        for c, p in enumerate(row):
            img.paste(p, (c * (pw + 16), r * (ph + 16)))
    img.save(os.path.join(out, 'random_sample.png'))


# ------------------------------------------------------------------------------------------------ furnished rooms
# the new furniture as the game lays it: a row of fittings on the back wall, the room's pieces in rows, its floor
ROOM_KINDS = [
    ('cafe', ['t_trl_floor_parquet', 't_trl_floor_tile'], ['coffee_bar', 'bakery_case', 'bread_rack'],
     ['cafe_table', 'cafe_chair', 'cafe_chair', 'coffee_machine', 'armchair']),
    ('bar', ['t_trl_floor_dance', 't_trl_floor_concrete'], ['bar_counter', 'speaker_stack', 'dj_booth'],
     ['booth_seat', 'pool_table', 'card_table', 'jukebox', 'lounge_sofa', 'barrel', 'karaoke_booth']),
    ('shop', ['t_trl_floor_lino', 't_trl_floor_concrete', 't_trl_floor_carpet_grey'], ['shoe_wall', 'tv_wall', 'electronics_shelf', 'bookshelf', 'pharmacy_shelf'],
     ['clothing_rack', 'mannequin', 'display_case', 'mirror', 'office_shelf', 'hardware_rack']),
    ('garage', ['t_trl_floor_concrete'], ['tool_wall', 'tire_rack', 'gun_rack'], ['lift_hoist', 'tool_chest', 'workbench', 'car_plinth', 'lumber_stack']),
    ('service', ['t_trl_floor_tile', 't_trl_floor_carpet_grey'], ['teller_window', 'deposit_boxes', 'locker', 'salon_mirror', 'mail_sorter', 'key_rack'],
     ['waiting_bench', 'queue_rail', 'atm', 'barber_chair', 'washing_machine', 'dryer', 'arcade_cabinet', 'claw_machine', 'pachinko_machine']),
    ('gym', ['t_trl_floor_rubber', 't_trl_floor_mat'], ['locker', 'dumbbell_rack', 'weapon_rack', 'shoe_shelf'],
     ['treadmill', 'weight_bench', 'squat_rack', 'punching_bag', 'training_dummy']),
    ('works', ['t_trl_floor_concrete'], ['pallet_rack', 'parts_bin'], ['conveyor', 'lathe', 'mill', 'scrap_pile', 'baler', 'shredder', 'press_machine', 'pallet_stack']),
    ('home', ['t_trl_floor_lino', 't_trl_floor_parquet', 't_trl_floor_mat'], ['kitchen_counter', 'kitchen_sink', 'wardrobe', 'dresser', 'home_shrine', 'tv_stand'],
     ['bed_single', 'bed_double', 'bunk_bed', 'sofa', 'coffee_table', 'kotatsu', 'futon', 'toilet', 'bathtub', 'shower', 'shoe_rack']),
    ('office', ['t_trl_floor_carpet_grey'], ['server_rack', 'whiteboard', 'mailboxes', 'filing_cabinet', 'directory_board'],
     ['desk_workstation', 'office_chair', 'desk_executive', 'meeting_table', 'cubicle_divider', 'copier']),
]
RW, RH = 9, 6


def room(spr, th, seed):
    """one furnished room from a seed, exactly as generated: its kind, floor, wall fittings and pieces are drawn by
    the seed; one variant per room as in the game"""
    rng = Rng('room', th, seed)
    name, floors, wall, pieces = ROOM_KINDS[rng.int(0, len(ROOM_KINDS) - 1)]
    v = rng.int(0, 2)
    fl = rng.pick(floors)
    img = Image.new('RGBA', (RW * 64, RH * 64), BG)
    for y in range(RH):
        for x in range(RW):
            edge = x in (0, RW - 1) or y in (0, RH - 1)
            if edge:
                bits = (1 if y > 0 and x in (0, RW - 1) else 0) | (2 if x < RW - 1 and y in (0, RH - 1) else 0) | \
                       (4 if y < RH - 1 and x in (0, RW - 1) else 0) | (8 if x > 0 and y in (0, RH - 1) else 0)
                img.alpha_composite(over(spr['t_concrete.0'], spr['t_wall.%d' % bits]), (x * 64, y * 64))
                continue
            layers = [spr['%s.%d' % (fl, v)]]
            if y == 1:
                w = wall[(x // 3 + seed) % len(wall)] if rng.chance(0.85) else None
                if w:
                    layers.append(spr['f_trl_%s.%d' % (w, v)])
            elif y in (3, 4) and x not in (1, RW - 2) and rng.chance(0.55):
                layers.append(spr['f_trl_%s.%d' % (rng.pick(pieces), v)])
            img.alpha_composite(over(*layers), (x * 64, y * 64))
    return img


def rooms_sample(S, out, seeds=range(1, 5)):
    pw, ph = RW * 64, RH * 64
    img = Image.new('RGBA', (len(seeds) * (pw + 16), len(TH.ORDER) * (ph + 16)), BG)
    for r, th in enumerate(TH.ORDER):
        for c, s in enumerate(seeds):
            img.paste(room(S[th][0], th, s), (c * (pw + 16), r * (ph + 16)))
    img.save(os.path.join(out, 'rooms_sample.png'))


def furniture_sheet(S, th, out):
    """every new piece and floor of a theme, its three variants side by side"""
    import furniture2 as F2
    ids = ['t_trl_' + k for k in F2.FLOORS] + ['f_trl_' + k for k in F2.FURN]
    spr = S[th][0]
    per = 6
    cols = per * 3
    rows = (len(ids) + per - 1) // per
    img = Image.new('RGBA', (cols * 66, rows * 66), BG)
    for i, id_ in enumerate(ids):
        for v in range(3):
            under = None if id_.startswith('t_') else spr['t_floor.0']
            c = (i % per) * 3 + v
            img.paste(over(under, spr['%s.%d' % (id_, v)]), (c * 66 + (i % per) * 0, (i // per) * 66))
    img.save(os.path.join(out, 'furniture_%s.png' % th))


def main(sets, out):
    os.makedirs(out, exist_ok=True)
    S = {th: load(sets, th) for th in TH.ORDER}
    compare(S, out)
    for th in TH.ORDER:
        theme_sheet(S, th, out)
    random_sample(S, out)
    rooms_sample(S, out)
    for th in TH.ORDER:
        furniture_sheet(S, th, out)
    if os.path.exists(os.path.join(sets, 'items', 'tile_config.json')):
        icons, _ = load(sets, 'items')
        fl = S['mid'][0]['t_floor.0']
        names = list(icons)
        cols = 16
        img = Image.new('RGBA', (cols * 64, ((len(names) + cols - 1) // cols) * 64), BG)
        for i, n in enumerate(names):
            img.paste(over(fl, icons[n]), ((i % cols) * 64, (i // cols) * 64))
        img.save(os.path.join(out, 'icons.png'))
    print('sheets written to', out)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
