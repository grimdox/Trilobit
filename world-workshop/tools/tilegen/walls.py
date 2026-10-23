"""Walls, glass walls, doors and windows.

Walls join up: the game picks one of 16 shapes per cell from which neighbours are walls too (bits 1 north, 2 east,
4 south, 8 west), and draws it over the floor.  A wall is a raised band (24 px thick, 14 px high) through the middle
of the cell with an arm out to every joined side; where an arm meets the cell edge it carries on into the next cell,
so it has no outline there.  Each theme gives the band its own build: marble with a chrome edge and teal inlay
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


def wall(theme, bits, rng, glass=False):
    t = Tile('', periodic=False)
    m = band(bits)
    st = style(theme)
    inner = band(bits, A + 3, B - 3)
    edge = m & ~inner
    if glass:
        # frame round the edge, glass in the middle with diagonal glints
        t.slab(m, 'trim', H, bevel=1.0)
        pane = band(bits, A + 3, B - 3)
        t.slab(pane, 'glass', -1.5, bevel=0.5, on=H)
        t.m[pane] = 'glass'
        gl = pane & (((XX + YY) % 23) < 2)
        t.mark(gl, 2)
        mull = pane & ((((XX % 21) == 10) & ((bits & 10) > 0)) | (((YY % 21) == 10) & ((bits & 5) > 0)))
        t.paint(mull, 'trim')
        t.h[mull] = H
        if theme == 'rural':
            # paper screens (shoji) in a lattice
            t.m[pane] = 'paper'
            lat = pane & (((XX % 8) == 0) | ((YY % 8) == 0))
            t.paint(lat, 'trim')
        if theme in ('slum', 'industry'):
            wire = pane & ((((XX + YY) % 6) == 0) | (((XX - YY) % 6) == 0))
            t.mark(wire, -1)
            if theme == 'slum':
                t.paint(pane & blotches(rng.int(0, 1 << 20), 0.25, cells=4), 'grime')
        face = _face(t, m, bits, theme, rng, mat='trim')
        _open_edges(t, bits)
        t.drop_shadow(m | face, 4, 4, 0.35)
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
        if rng.chance(0.25):
            t.paint(m & blotches(rng.int(0, 1 << 20), 0.06, cells=4), 'grime')
    elif theme == 'slum':
        # sheet metal over block: ribs across the band, rust, a patched plate
        t.slab(m, 'wall', H, bevel=1.0)
        rib = inner & ((((XX % 6) < 2) & ((bits & 10) > 0)) | (((YY % 6) < 2) & ((bits & 5) > 0) & ~((bits & 10) > 0)))
        t.h[rib] += 0.8
        t.mark(rib, 1)
        t.paint(m & blotches(rng.int(0, 1 << 20), 0.3, cells=4), 'rust')
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
        post = m & ((((XX % 16) < 3) & ((bits & 10) > 0)) | (((YY % 16) < 3) & ((bits & 5) > 0)) | Tile.box_mask(A, A, B, B) & ~band(0, A + 4, B - 4))
        t.paint(post, 'trim')
        t.h[post] += 0.6
    else:
        # riveted steel plate, a hazard band at the base of each face
        t.slab(m, 'wall', H, bevel=1.0)
        joint = inner & ((((XX % 32) == 0) & ((bits & 10) > 0)) | (((YY % 32) == 0) & ((bits & 5) > 0)))
        t.mark(joint, -1)
        riv = inner & ~band(bits, A + 5, B - 5) & ((((XX % 8) == 4) & ((bits & 10) > 0)) | (((YY % 8) == 4) & ((bits & 5) > 0)))
        t.h[riv] += 0.7
        t.mark(riv, 1)
        t.paint(edge, 'wall_side')
        t.paint(m & blotches(rng.int(0, 1 << 20), 0.18, cells=4), 'rust')
    face = _face(t, m, bits, theme, rng)
    _open_edges(t, bits)
    # contact shadow on the floor to the bottom right of the wall and its face
    t.drop_shadow(m | face, 4, 4, 0.4)
    return t


# ------------------------------------------------------------------------------------------------ doors and windows
def door(theme, rng, vertical=False, state='open', locked=False):
    """a door in a wall line: frame posts at both ends; the leaf shut across the gap, or swung open against the frame"""
    t = Tile('', periodic=False)
    st = style(theme)

    def R(x0, y0, x1, y1, r=0.0):
        return Tile.box_mask(y0, x0, y1, x1, r) if vertical else Tile.box_mask(x0, y0, x1, y1, r)

    post = R(0, A, 7, B) | R(N - 8, A, N - 1, B)
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
