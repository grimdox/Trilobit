"""Every sprite id a theme draws, with its builder and how many variants it has.  The ids are the game's own
(gfx/Trilobit64): a theme set can stand in for the base set cell by cell.  New ids (the props) are listed too; the
game places them by district (see the game's citygen and view)."""
import terrain as T
import walls as W
import furniture as F
import props as P
import furniture2 as F2
from canvas import Rng

# id -> (builder(theme, rng, variant), variants, kind)   kind: 'ground' (wraps, opaque) or 'object' (drawn over a floor)
CATALOG = {}
# ids drawn only in some themes (the underground set lives in the industry set, which the game uses below ground)
ONLY = {}


def drawn(id_, theme):
    return theme in ONLY.get(id_, (theme,))


def _g(id_, f, n=1):
    CATALOG[id_] = (f, n, 'ground')


def _o(id_, f, n=1):
    CATALOG[id_] = (f, n, 'object')


_g('t_sidewalk', T.sidewalk, 4)
_g('t_pavement', T.pavement, 6)
_g('t_concrete', T.concrete, 2)
_g('t_floor', T.floor, 3)
_g('t_grass', lambda th, r, v: T.grass(th, r, v), 6)
_g('t_grass_grazed', lambda th, r, v: T.grass(th, r, v, grazed=True), 3)
_g('t_water_dp', lambda th, r, v: T.water(th, r, v), 4)
_g('t_water_sh_murky_underground', lambda th, r, v: T.water(th, r, v, murky=True), 3)
_g('t_sand', lambda th, r, v: T.natural('sand', th, r, v), 3)
_g('t_trl_gravel', lambda th, r, v: T.natural('gravel', th, r, v), 3)
_g('t_rock_floor', lambda th, r, v: T.natural('rock_floor', th, r, v), 3)
_g('t_rock', lambda th, r, v: T.natural('rock', th, r, v), 3)
_g('t_rock_red', lambda th, r, v: T.natural('rock_red', th, r, v), 3)
_g('t_metal_floor', T.metal_floor, 2)
_g('t_metal_flat_roof', T.roof, 2)
_g('t_floor_metal_gangway', T.gangway, 1)
_g('t_railroad_tie', lambda th, r, v: T.rail(th, r, v), 1)
_g('t_railroad_tie.v', lambda th, r, v: T.rail(th, r, v, vertical=True), 1)
_g('t_manhole_cover', T.manhole, 1)
_o('t_stairs_up', T.stairs_up, 1)
_o('t_elevator', T.elevator, 1)
_o('t_ladder_up_down', T.ladder, 1)
_o('t_glass_railing', T.glass_railing, 1)
for k, kind in (('t_trl_checker', 'checker'), ('t_trl_floor_church', 'church'), ('t_trl_floor_hinoki', 'hinoki'),
                ('t_trl_floor_clean', 'clean'), ('t_trl_marble', 'marble'), ('t_trl_floor_steel', 'steel'),
                ('t_trl_floor_wood', 'wood'), ('t_trl_tatami', 'tatami'), ('t_trl_carpet_red', 'carpet_red')):
    _g(k, (lambda kk: lambda th, r, v: T.special_floor(kk, th, r, v))(kind), 1)
for gid, f in P.GROUND.items():
    _g(gid, f, 3)
# walls: 't_wall' is the lone pillar; 't_wall.<mask>' the 16 joined shapes
_o('t_wall', lambda th, r, v: W.wall(th, 0, r), 1)
_o('t_wall_glass', lambda th, r, v: W.wall(th, 0, r, glass=True), 1)
for m in range(16):
    _o('t_wall.%d' % m, (lambda mm: lambda th, r, v: W.wall(th, mm, r))(m), 1)
    _o('t_wall_glass.%d' % m, (lambda mm: lambda th, r, v: W.wall(th, mm, r, glass=True))(m), 1)
_o('t_door_c', lambda th, r, v: W.door(th, r, state='open'), 1)
_o('t_door_c.v', lambda th, r, v: W.door(th, r, vertical=True, state='open'), 1)
_o('t_door_closed', lambda th, r, v: W.door(th, r, state='closed'), 1)
_o('t_door_closed.v', lambda th, r, v: W.door(th, r, vertical=True, state='closed'), 1)
_o('t_door_metal_locked', lambda th, r, v: W.door(th, r, locked=True), 1)
_o('t_door_metal_locked.v', lambda th, r, v: W.door(th, r, vertical=True, locked=True), 1)
_o('t_window_broken', lambda th, r, v: W.window_broken(th, r), 1)
_o('t_tree', lambda th, r, v: F.tree(th, r, v), 3)
_o('f_trl_container', lambda th, r, v: F.container(th, r, v), 4)
for fid, f in F.BUILDERS.items():
    _o(fid, (lambda ff: lambda th, r, v: ff(th, r))(f), 2 if fid in ('f_crate_c', 'f_dumpster') else 1)
# the older fittings that stand against a wall or face a room turn too
OLD_TURN = ['f_chair', 'f_trl_shop_counter', 'f_trl_counter_noodle', 'f_trl_kitchen_range', 'f_trl_kitchen_fridge', 'f_trl_sushi_case',
            'f_trl_pizza_oven', 'f_trl_menu_board', 'f_trl_liquor_shelf', 'f_trl_hot_plate', 'f_trl_shelf_clean', 'f_trl_freezer_case',
            'f_trl_checkout', 'f_trl_vending', 'f_trl_med_cabinet', 'f_trl_reception', 'f_trl_church_bench', 'f_trl_iconostasis',
            'f_trl_charm_counter', 'f_trl_cabinet_lacquer', 'f_trl_gunsmith_table', 'f_trl_hospital_bed', 'f_trl_exam_couch',
            'f_trl_implant_chair', 'f_trl_terminal']
for fid in OLD_TURN:
    f0, n0, _ = CATALOG[fid]
    for suf, k in F2.FACINGS:
        _o(fid + suf, (lambda ff, fi, kk: lambda th, r, v: F2.turned(ff(th, Rng(th, fi, v), v), kk))(f0, fid, k), n0)
for pid, f in P.BUILDERS.items():
    _o(pid, (lambda ff: lambda th, r, v: ff(th, r))(f), 1)

# the business and home furniture and floors (furniture2.py): three variants each
for fid, f in F2.FLOORS.items():
    _g('t_trl_' + fid, f, F2.VARIANTS)
for fid, f in F2.FURN.items():
    _o('f_trl_' + fid, f, F2.VARIANTS)
    if fid in F2.NO_TURN:
        continue
    for suf, k in F2.FACINGS:
        # the same piece (same seed) turned: a shelf facing east holds the same stock as the one facing south
        _o('f_trl_' + fid + suf, (lambda ff, fi, kk: lambda th, r, v: F2.turned(ff(th, Rng(th, 'f_trl_' + fi, v), v), kk))(f, fid, k),
           F2.VARIANTS)
for fid, f in F2.EXTRA.items():
    _o('f_trl_' + fid, f, 1)
    for suf, k in F2.FACINGS:
        _o('f_trl_' + fid + suf, (lambda ff, fi, kk: lambda th, r, v: F2.turned(ff(th, Rng(th, 'f_trl_' + fi, v), v), kk))(f, fid, k), 1)

# rock: mountains and red cliffs everywhere, the rock round the tunnels in the industry set; rough rocky ground
import rock as RK
for bits in range(16):
    # sixteen cut positions each (the game picks the one for the cell's place in the 4 x 4 repeat of the rock field),
    # one shape per set of open sides and inside corners: mountains and cliffs in the country set, which the game draws
    # all rock from; the deep rock below ground in the industry set (it only ever shows whole)
    for cn in RK.corner_sets(bits):
        for kind, name in (('grey', 't_mtn'), ('red', 't_cliff')):
            id_ = '%s.%d_%d' % (name, bits, cn)
            _o(id_, (lambda kd, b, cc: lambda th, r, v: RK.massif(kd, th, r, v, b, cc))(kind, bits, cn), RK.CELLS)
            ONLY[id_] = ('rural',)
_o('t_ugrock.0_0', lambda th, r, v: RK.massif('under', th, r, v, 0, 0), RK.CELLS)
ONLY['t_ugrock.0_0'] = ('industry',)
_g('t_rocky', RK.rocky_ground, 4)

# the underground (industry set only: the game draws everything below ground with it)
import underground as UG
for opn in range(16):
    _o('t_ugwall.%d' % opn, (lambda o: lambda th, r, v: UG.lining(th, r, v, o))(opn), 3)
    _o('t_ugbrick.%d' % opn, (lambda o: lambda th, r, v: UG.lining(th, r, v, o, brick=True))(opn), 3)
    ONLY['t_ugwall.%d' % opn] = ONLY['t_ugbrick.%d' % opn] = ('industry',)
for gid, f in (('t_ug_tunnel', UG.tunnel_floor), ('t_ug_platform', UG.platform), ('t_ug_walk', UG.sewer_walk),
               ('t_ug_sludge', UG.sludge), ('t_ug_track', UG.track),
               ('t_ug_track.v', lambda th, r, v: UG.track(th, r, v, vertical=True))):
    _g(gid, f, 3)
    ONLY[gid] = ('industry',)
for fid, f in list(UG.WALL_FITTINGS.items()) + [('edge', UG.edge_strip)]:
    _o('f_ug_' + fid, f, 3)
    ONLY['f_ug_' + fid] = ('industry',)
    for suf, k in F2.FACINGS:
        _o('f_ug_' + fid + suf, (lambda ff, fi, kk: lambda th, r, v: F2.turned(ff(th, Rng(th, 'f_ug_' + fi, v), v), kk))(f, fid, k), 3)
        ONLY['f_ug_' + fid + suf] = ('industry',)
for fid, f in UG.FLOOR_FITTINGS.items():
    _o('f_ug_' + fid, f, 3)
    ONLY['f_ug_' + fid] = ('industry',)

NEW_IDS = sorted(set(P.BUILDERS) | set(P.GROUND) | {'t_door_closed', 't_door_closed.v', 't_window_broken'})

# extra names the game's base set also answers to: the plain id of a varied sprite (its first variant) and a few
# spellings the game asks for
ALIASES = {'t_floor_metal_gangway.0': 't_floor_metal_gangway'}
