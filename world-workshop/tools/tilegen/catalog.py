"""Every sprite id a theme draws, with its builder and how many variants it has.  The ids are the game's own
(gfx/Trilobit64): a theme set can stand in for the base set cell by cell.  New ids (the props) are listed too; the
game places them by district (see the game's citygen and view)."""
import terrain as T
import walls as W
import furniture as F
import props as P
import furniture2 as F2

# id -> (builder(theme, rng, variant), variants, kind)   kind: 'ground' (wraps, opaque) or 'object' (drawn over a floor)
CATALOG = {}


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
for pid, f in P.BUILDERS.items():
    _o(pid, (lambda ff: lambda th, r, v: ff(th, r))(f), 1)

# the business and home furniture and floors (furniture2.py): three variants each
for fid, f in F2.FLOORS.items():
    _g('t_trl_' + fid, f, F2.VARIANTS)
for fid, f in F2.FURN.items():
    _o('f_trl_' + fid, f, F2.VARIANTS)
for fid, f in F2.EXTRA.items():
    _o('f_trl_' + fid, f, 1)

NEW_IDS = sorted(set(P.BUILDERS) | set(P.GROUND) | {'t_door_closed', 't_door_closed.v', 't_window_broken'})

# extra names the game's base set also answers to: the plain id of a varied sprite (its first variant) and a few
# spellings the game asks for
ALIASES = {'t_floor_metal_gangway.0': 't_floor_metal_gangway'}
