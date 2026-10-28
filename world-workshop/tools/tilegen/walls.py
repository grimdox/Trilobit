"""Walls, glass walls, doors and windows.

Walls join up: the game picks one of 16 shapes per cell from which neighbours are walls too (bits 1 north, 2 east,
4 south, 8 west), and draws it over the floor.  A wall is a raised band (24 px thick, 14 px high) through the middle
of the cell with an arm out to every joined side; where an arm meets the cell edge it carries on into the next cell,
so it has no outline there.  Solid walls (not glass) fill their cell to the edge, so a room's floor runs right up to
them: the top covers the cell and, where nothing joins to the south, the south face takes the bottom 9 px.  Each theme gives the band its own build: marble with a chrome edge and teal inlay
downtown, panelled concrete in mid-town, patched sheet metal in the slums, timber frame and plaster in the country,
riveted plate in the docks."""
import numpy as np

from canvas import Tile, N, XX, YY, Rng, blotches, cracks, speckle
from themes import style

A, B = 20, 43           # the band
H = 14.0                # wall height


def band(mask_bits, a=A, b=B):
    m = Tile.box_mask(a, a, b, b)
    if mask_bits & 1:
        m |= Tile.box_mask(a, 0, b, b)
    if mask_bits & 2:
        m |= Tile.box_mask(a, a, N - 1, b)
    if mask_bits & 4:
        m |= Tile.box_mask(a, a, b, N - 1)
    if mask_bits & 8:
        m |= Tile.box_mask(0, a, b, b)
    return m


FACE = 9               # the visible south face below the top of a wall


def _face(t, m, bits, theme, rng, mat='wall_side'):
    """the front (south) face of the wall: a darker vertical strip under every band edge that faces south"""
    face = np.zeros((N, N), bool)
    for k in range(1, FACE + 1):
        sh = np.zeros((N, N), bool)
        sh[k:, :] = m[:N - k, :]
        face |= sh & ~m
    face &= ~(YY > N - 1)
    t.m[face] = mat
    t.solid |= face
    t.obj |= face
    # a vertical surface: height falls away down the face, so it shades as one band and casts no shadow onto itself
    yy = np.zeros((N, N), np.float32)
    for k in range(1, FACE + 1):
        sh = np.zeros((N, N), bool)
        sh[k:, :] = m[:N - k, :]
        yy = np.where(sh & ~m & (yy == 0), k, yy)
    t.h = np.where(face, H - yy * 0.25, t.h).astype(np.float32)
    t.d[face] = -1
    # the line where the face meets the top, and texture on the face
    top_edge = face & np.roll(m, 1, 0)
    t.mark(top_edge, 1)
    if theme == 'slum':
        t.paint(face & blotches(rng.int(0, 1 << 20), 0.35, cells=4), 'rust')
        t.mark(face & ((XX % 6) == 0), -1)
    elif theme == 'rural':
        t.mark(face & ((XX % 16) < 3), -1)
    elif theme == 'industry':
        hz = face & (yy >= FACE - 2) & (((XX + yy.astype(int)) % 8) < 4)
        t.paint(hz, 'hazard_y')
    elif theme == 'rich':
        strip = face & (yy == 3)
        t.emit(strip, 'neon_cyan')
    elif theme == 'mid':
        t.mark(face & ((XX % 16) == 0), -1)
    if bits & 4:
        pass
    return face


def _open_edges(t, bits):
    """no outline where the wall runs on into the next cell"""
    if bits & 1:
        t.noline |= YY == 0
    if bits & 2:
        t.noline |= XX == N - 1
    if bits & 4:
        t.noline |= YY == N - 1
    if bits & 8:
        t.noline |= XX == 0


def _along(bits):
    """per pixel: 1 where the band runs east-west, 2 north-south (for patterns that follow the wall)"""
    ew = Tile.box_mask(0, A, N - 1, B) & ((bits & 2 > 0) | (bits & 8 > 0) | (XX >= A) & (XX <= B))
    return ew


def block(bits, d=0):
    """the wall's top when it fills its cell, shrunk by d on every side that does not join a neighbour"""
    bottom = N - 1 if bits & 4 else N - 1 - FACE
    return Tile.box_mask(0 if bits & 8 else d, 0 if bits & 1 else d, N - 1 if bits & 2 else N - 1 - d,
                         bottom if bits & 4 else bottom - d)


def wall(theme, bits, rng, glass=False):
    t = Tile('', periodic=False)
    st = style(theme)
    m = block(bits)
    inner = block(bits, 3)
    edge = m & ~inner
    if glass:
        # a window is the district's own wall with glazing set into it, so it carries the wall's materials, wear and
        # face; only the glazing differs by district
        t = wall(theme, bits, rng, glass=False)
        _glaze(t, theme, bits, rng)
        return t
    if theme == 'rich':
        t.slab(m, 'wall', H, bevel=1.5)
        t.paint(edge, 'trim')
        core = band(bits, 30, 33)
        t.paint(core, 'inlay')
        t.mark(core, 1)
    elif theme == 'mid':
        t.slab(m, 'wall', H, bevel=1.2)
        joint = m & (((XX % 16) == 0) & ((bits & 10) > 0) | ((YY % 16) == 0) & ((bits & 5) > 0))
        t.carve(joint & inner, 0.8)
        t.mark(joint & inner, -1)
        t.paint(edge, 'wall_side')
    elif theme == 'slum':
        # sheet metal over block: ribs across the band, rust, a patched plate
        t.slab(m, 'wall', H, bevel=1.0)
        rib = inner & ((((XX % 6) < 2) & ((bits & 10) > 0)) | (((YY % 6) < 2) & ((bits & 5) > 0) & ~((bits & 10) > 0)))
        t.h[rib] += 0.8
        t.mark(rib, 1)
        t.paint(m & blotches(rng.int(0, 1 << 20), 0.12, cells=8), 'rust')
        t.paint(edge, 'wall_side')
        if rng.chance(0.5):
            pat = Tile.box_mask(rng.int(A, B - 10), rng.int(A, B - 10), 0, 0)
            x0, y0 = rng.int(A + 2, B - 12), rng.int(A + 2, B - 12)
            pat = Tile.box_mask(x0, y0, x0 + 9, y0 + 9) & m
            t.paint(pat, 'trim')
            t.mark(pat & ~Tile.box_mask(x0 + 1, y0 + 1, x0 + 8, y0 + 8), -1)
        c = cracks(rng.int(0, 1 << 20), 2, 10, region=inner) & inner
        t.mark(c, -1)
    elif theme == 'rural':
        # timber frame (dark beams along both faces, posts every 16 px) with plaster between
        t.slab(m, 'wall', H, bevel=1.0)
        t.paint(edge, 'trim')
        post = m & ((((XX % 16) < 3) & ((bits & 10) > 0)) | (((YY % 16) < 3) & ((bits & 5) > 0)))
        t.paint(post, 'trim')
        t.h[post] += 0.6
    else:
        # riveted steel plate, a hazard band at the base of each face
        t.slab(m, 'wall', H, bevel=1.0)
        joint = inner & ((((XX % 32) == 0) & ((bits & 10) > 0)) | (((YY % 32) == 0) & ((bits & 5) > 0)))
        t.mark(joint, -1)
        riv = inner & ~block(bits, 5) & ((((XX % 8) == 4) & ((bits & 10) > 0)) | (((YY % 8) == 4) & ((bits & 5) > 0)))
        t.h[riv] += 0.7
        t.mark(riv, 1)
        t.paint(edge, 'wall_side')
        t.paint(m & blotches(rng.int(0, 1 << 20), 0.07, cells=8), 'rust')
    face = _face(t, m, bits, theme, rng)
    _open_edges(t, bits)
    # contact shadow on the floor to the bottom right of the wall and its face
    t.drop_shadow(m | face, 4, 4, 0.4)
    return t


GLAZE = {'rich': ('glass_smoke', 'trim'), 'mid': ('glass_mid', 'wall_side'), 'slum': ('glass_grime', 'trim'),
         'rural': ('paper', 'trim'), 'industry': ('glass_block', 'dark_steel')}


def _glaze(t, theme, bits, rng):
    """set a window into a wall top: a frame proud of the wall, the glazing sunk below it, mullions along the run, and
    the glazing carried down the south face so the window reads from the street"""
    glaze, frame_m = GLAZE[theme]
    inner = block(bits, 3)
    pane = band(bits, 16, 47) & inner
    frame = band(bits, 13, 50) & inner & ~pane
    t.paint(frame, frame_m)
    t.h[frame] = H + 0.6
    t.m[pane] = glaze
    t.h[pane] = H - 2.6
    t.d[pane] = 0
    along_x = (bits & 10) > 0 or not (bits & 5)
    if along_x:
        mull = pane & ((XX % 16) == 8)
    else:
        mull = pane & ((YY % 16) == 8)
    if theme == 'rural':
        lat = pane & (((XX % 8) == 0) | ((YY % 8) == 0))
        t.paint(lat, 'trim')
        t.h[lat] = H - 1.8
    elif theme == 'industry':
        # glass block: a grid of thick lenses in mortar
        mortar = pane & (((XX % 6) == 0) | ((YY % 6) == 0))
        t.paint(mortar, 'concrete')
        t.h[mortar] = H - 1.8
        lens = pane & ~mortar
        t.mark(lens & (((XX % 6) == 1) | ((YY % 6) == 1)), 1)
        t.mark(lens & (((XX % 6) == 5) | ((YY % 6) == 5)), -1)
    else:
        t.paint(mull, frame_m)
        t.h[mull] = H - 1.0
        # reflections: broad diagonal sheen bands, the city light caught in the glass
        sheen = pane & ~mull & ((((XX + YY) % 29) < 3) | ((((XX + YY) % 29) == 5)))
        t.mark(sheen, 2 if theme == 'rich' else 1)
        if theme == 'rich':
            t.emit(pane & ~mull & (((XX - YY) % 64) == 40) & (((XX + YY) % 7) < 4), 'neon_cyan')
        if theme == 'slum':
            wire = pane & ~mull & ((((XX + YY) % 6) == 0) | (((XX - YY) % 6) == 0))
            t.mark(wire, -1)
            t.paint(pane & blotches(rng.int(0, 1 << 20), 0.22, cells=8), 'grime')
            if rng.chance(0.4):        # a broken pane boarded over
                bx0 = rng.pick([0, 16, 32, 48])
                board = pane & ((XX >= bx0) & (XX < bx0 + 16) if along_x else (YY >= bx0) & (YY < bx0 + 16))
                t.paint(board, 'wood')
                t.h[board] = H - 0.5
                t.mark(board & ((((YY if along_x else XX) % 5) == 0)), -1)
    # the glazing seen down the south face
    if not bits & 4:
        cols = np.any(pane, axis=0)
        face = (t.m == 'wall_side') & (YY > N - 1 - FACE) & cols[None, :] & (XX > 2) & (XX < N - 3)
        if theme != 'rural':
            t.paint(face & (YY > N - FACE + 1) & (YY < N - 2), glaze)
            t.mark(face & (YY == N - FACE + 2), 1)


# ------------------------------------------------------------------------------------------------ doors and windows
def door(theme, rng, vertical=False, state='open', locked=False):
    """a door in a wall line: frame posts at both ends; the leaf shut across the gap, or swung open against the frame"""
    t = Tile('', periodic=False)
    st = style(theme)

    def R(x0, y0, x1, y1, r=0.0):
        return Tile.box_mask(y0, x0, y1, x1, r) if vertical else Tile.box_mask(x0, y0, x1, y1, r)

    post = R(0, 0, 7, N - 1) | R(N - 8, 0, N - 1, N - 1)           # the posts are as thick as the walls they sit in
    t.slab(post, 'trim' if theme != 'rural' else 'trim', H + 1, bevel=1.0)
    if vertical:
        t.noline |= (YY == 0) | (YY == N - 1)
    else:
        t.noline |= (XX == 0) | (XX == N - 1)
    sill = R(8, A + 2, N - 9, B - 2)
    t.slab(sill, 'concrete' if theme != 'rich' else 'kerb', 0.5, bevel=0, obj=False)
    if locked:
        if theme in ('slum', 'industry'):
            # a gate of bars
            for k in range(10, N - 9, 6):
                bar = R(k, A + 8, k + 2, B - 8)
                t.slab(bar, 'dark_steel' if theme == 'industry' else 'rust', H - 2, bevel=0.6)
            rail_ = R(8, A + 10, N - 9, A + 12) | R(8, B - 12, N - 9, B - 10)
            t.slab(rail_, 'dark_steel', H - 1, bevel=0.6)
            lock = R(28, A + 6, 36, A + 9)
            t.slab(lock, 'brass', H, bevel=0.5)
        else:
            leaf = R(8, A + 4, N - 9, B - 4)
            t.slab(leaf, 'steel' if theme != 'rural' else 'wood_dark', H - 3, bevel=1.0)
            t.mark(leaf & R(8, 31, N - 9, 32), -1)
            pad = R(40, A + 6, 46, A + 9)
            t.emit(pad, 'neon_red' if theme != 'rural' else 'lamp_dead')
            if theme == 'rural':
                t.m[pad] = 'dark_steel'
                t.glow[pad] = False
        t.drop_shadow(post, 3, 3, 0.35)
        return t
    leaf_mat = {'rich': 'door', 'mid': 'door', 'slum': 'door', 'rural': 'door', 'industry': 'door'}[theme]
    if state == 'closed':
        if theme == 'rich':
            # double door, gold pulls, a glass light in each leaf
            for x0, x1 in ((8, 31), (32, N - 9)):
                leaf = R(x0, A + 3, x1, B - 3)
                t.slab(leaf, leaf_mat, H - 4, bevel=1.2)
                t.slab(R(x0 + 4, A + 7, x1 - 4, B - 7), 'glass', 0.5, bevel=0.4, on=H - 4)
            t.slab(R(29, A + 8, 30, B - 8) | R(33, A + 8, 34, B - 8), 'door_trim', H - 2, bevel=0.3)
        elif theme == 'rural':
            leaf = R(8, A + 4, N - 9, B - 4)
            t.slab(leaf, 'door', H - 4, bevel=1.0)
            lat = leaf & (((XX if not vertical else YY) % 8 == 0) | ((YY if not vertical else XX) % 6 == 0))
            t.paint(lat, 'door_trim')
        else:
            leaf = R(8, A + 4, N - 9, B - 4)
            t.slab(leaf, leaf_mat, H - 4, bevel=1.0)
            win = R(22, A + 7, 40, A + 10)
            if theme == 'mid':
                t.slab(win, 'glass', 0.3, bevel=0.3, on=H - 4)
            knob = R(46, 30, 49, 33)
            t.slab(knob, 'door_trim', H - 2, bevel=0.4)
            if theme == 'industry':
                wheel = Tile.disk_mask(32, 32, 6) & ~Tile.disk_mask(32, 32, 4)
                t.slab(wheel & leaf, 'dark_steel', H - 2, bevel=0.4)
                hz = leaf & (((XX + YY) % 8) < 4) & ~R(10, A + 6, N - 11, B - 6)
                t.paint(hz, 'hazard_y')
            if theme == 'slum':
                t.paint(leaf & blotches(rng.int(0, 1 << 20), 0.35, cells=4), 'rust')
                dent = Tile.disk_mask(rng.range(16, 48), 32, 3)
                t.carve(dent & leaf, 1.0)
    else:
        # open: the leaf folded back against the left post, the doorway clear
        leaf = R(8, A - 14, 11, A + 3) if theme != 'rich' else R(8, A - 12, 11, A + 3) | R(N - 12, A - 12, N - 9, A + 3)
        t.slab(leaf, leaf_mat, H - 4, bevel=0.6)
    t.drop_shadow(post, 3, 3, 0.35)
    return t


def window_broken(theme, rng):
    t = Tile('', periodic=False)
    frame = Tile.box_mask(0, A, N - 1, A + 2) | Tile.box_mask(0, B - 2, N - 1, B)
    t.slab(frame, 'trim', 6, bevel=0.5)
    t.noline |= (XX == 0) | (XX == N - 1)
    for k in range(5):
        x = rng.range(4, 58)
        y = rng.pick([A + 3, B - 3])
        tri = Tile.poly_mask([(x, y), (x + rng.range(3, 7), y), (x + rng.range(0, 5), y + (rng.range(4, 9) if y < 32 else -rng.range(4, 9)))])
        t.slab(tri, 'glass', 2, bevel=0.3)
    for k in range(6):
        sh = Tile.disk_mask(rng.range(4, 60), rng.range(6, 58), rng.range(0.8, 1.6))
        t.slab(sh, 'glass', 0.5, bevel=0, obj=False)
    return t
