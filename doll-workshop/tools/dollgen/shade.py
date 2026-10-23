"""From ray-marched samples to clean indexed pixel art.

  1 resolve  - each sprite pixel takes the primitive most of its samples hit (no blending: every pixel is one surface)
  2 light    - key light from the upper left front, wrap lighting, cavity darkening from the depth buffer
  3 bands    - the light value is cut into shades 1-5 at fixed thresholds; rim (6) on the shadow-side edge facing the
               cold back light, specular (7) on glossy materials
  4 clean    - orphan pixels take their neighbours' shade; lone bumps in a band edge are flattened (traceable: every
               repair is counted in the returned stats)
  5 lines    - inside one layer a surface that passes behind another gets a dark line (shade 0 of its own material);
               every layer gets a 1 px outline outside its silhouette, skipped where it joins a lower layer smoothly
               (the shoulder growing out of the torso), lighter on brightly lit edges (selective outline)
Output: {layer: uint8 image of material * 8 + shade (0 = empty)}.
"""
import numpy as np
from scipy import ndimage as ndi

import materials as M

LIGHT = np.array([-0.5, -0.55, 0.67])
LIGHT = LIGHT / np.linalg.norm(LIGHT)
BACK = np.array([0.82, -0.3, -0.48])
BACK = BACK / np.linalg.norm(BACK)
HALF = (LIGHT + np.array([0, 0, 1.0]))
HALF = HALF / np.linalg.norm(HALF)
THRESH = (0.12, 0.32, 0.58, 0.86)     # light value -> shades 1..5: wide mid tones, small highlights
N4 = [(0, 1), (0, -1), (1, 0), (-1, 0)]
WRAP = 0.1
AO_K, AO_FLOOR = 0.11, 0.35          # ambient occlusion strength, and the amount ignored (a limb's own curvature)


def shift(a, dy, dx, fill=0):
    out = np.full_like(a, fill)
    H, W = a.shape[:2]
    ys, yd = (slice(0, H - dy), slice(dy, H)) if dy >= 0 else (slice(-dy, H), slice(0, H + dy))
    xs, xd = (slice(0, W - dx), slice(dx, W)) if dx >= 0 else (slice(-dx, W), slice(0, W + dx))
    out[yd, xd] = a[ys, xs]
    return out


def resolve(r, cover=0.45):
    """sample arrays -> per-pixel prim, z, normal"""
    ss, H, W = r['ss'], r['H'], r['W']
    n = ss * ss
    hit = r['hit'].reshape(H, ss, W, ss).transpose(0, 2, 1, 3).reshape(H, W, n)
    prim = r['prim'].reshape(H, ss, W, ss).transpose(0, 2, 1, 3).reshape(H, W, n)
    z = r['z'].reshape(H, ss, W, ss).transpose(0, 2, 1, 3).reshape(H, W, n)
    nr = r['n'].reshape(H, ss, W, ss, 3).transpose(0, 2, 1, 3, 4).reshape(H, W, n, 3)
    cnt = hit.sum(axis=2)
    px_hit = cnt >= max(1, int(round(n * cover)))
    p = np.where(hit, prim, -1)
    # mode of the prim ids among hit samples
    ps = np.sort(p, axis=2)
    best = ps[..., -1].copy()
    bestn = np.zeros((H, W), np.int32)
    run = np.zeros((H, W), np.int32)
    for i in range(n):
        same = (ps[..., i] == ps[..., i - 1]) if i > 0 else np.zeros((H, W), bool)
        run = np.where(same, run + 1, 1)
        better = (run > bestn) & (ps[..., i] >= 0)
        bestn = np.where(better, run, bestn)
        best = np.where(better, ps[..., i], best)
    sel = (p == best[..., None]) & hit
    k = np.maximum(sel.sum(axis=2), 1)
    zz = (np.where(sel, z, 0).sum(axis=2)) / k
    ao = r['ao'].reshape(H, ss, W, ss).transpose(0, 2, 1, 3).reshape(H, W, n)
    aa = (np.where(sel, ao, 0).sum(axis=2)) / k
    nn = (np.where(sel[..., None], nr, 0).sum(axis=2)) / k[..., None]
    nn = nn / np.maximum(np.linalg.norm(nn, axis=2, keepdims=True), 1e-6)
    best = np.where(px_hit, best, -1)
    znear = np.where(sel, z, -1e9).max(axis=2)
    return {'prim': best, 'z': np.where(px_hit, zz, -1e9), 'n': nn, 'hit': px_hit, 'ao': np.where(px_hit, aa, 0.0),
            'znear': np.where(px_hit, znear, -1e9)}


def smooth_normals(px, groups, sigma=0.7):
    """blur normals inside each solid group so the bands follow big forms, not sample noise"""
    n = px['n'].copy()
    hit = px['hit']
    for g in np.unique(groups[hit]):
        m = (groups == g) & hit
        w = ndi.gaussian_filter(m.astype(np.float32), sigma)
        for c in range(3):
            n[..., c] = np.where(m, ndi.gaussian_filter(np.where(m, px['n'][..., c], 0.0), sigma) / np.maximum(w, 1e-6), n[..., c])
    n /= np.maximum(np.linalg.norm(n, axis=2, keepdims=True), 1e-6)
    return n


FACE_LIGHT = np.array([-0.45, -0.45, 0.77])
FACE_LIGHT = FACE_LIGHT / np.linalg.norm(FACE_LIGHT)


def light_value(px, mats, cav_k=0.16, cav_min=0.7, face=None, scale=1.0):
    """face: mask of pixels lit by the frontal face light instead of the side key (the head)"""
    n, z, hit = px['n'], px['z'], px['hit']
    d = n @ LIGHT
    if face is not None:
        d = np.where(face, n @ FACE_LIGHT, d)
    w = WRAP
    lam = np.clip((d + w) / (1 + w), 0, 1)
    # cavity: the pixel sits below the average of its hit neighbours -> it is in a crease
    zf = np.where(hit, z, 0.0)
    hk = hit.astype(np.float32)
    k = np.ones((5, 5), np.float32)
    s = ndi.convolve(zf, k, mode='constant')
    c = ndi.convolve(hk, k, mode='constant')
    mean = s / np.maximum(c, 1)
    cav = np.clip((mean - z) / scale - cav_min, 0, 3.0)    # only real creases, not the curvature of a limb (in body units)
    ao = np.zeros_like(lam)
    for m, prop in M.LIGHT.items():
        ao = np.where(mats == m, prop['ao'], ao)
    occ = np.clip(px['ao'] / scale - AO_FLOOR, 0, None) * AO_K
    val = lam - cav * cav_k * ao - occ * ao
    return np.where(hit, val, 0.0)


def bands(val, px, mats, layer_mask_edge):
    shade = 1 + np.digitize(val, THRESH)
    shade = np.where(val < 0.04, 0, shade)
    n = px['n']
    rim = n @ BACK
    spec = np.clip(n @ HALF, 0, 1)
    rim_amt = np.zeros_like(val)
    gloss = np.zeros_like(val)
    for m, prop in M.LIGHT.items():
        rim_amt = np.where(mats == m, prop['rim'], rim_amt)
        gloss = np.where(mats == m, prop['gloss'], gloss)
    rim_on = (rim * rim_amt > 0.34) & layer_mask_edge & (shade <= 3) & (n[..., 0] > 0.25)
    shade = np.where(rim_on, 6, shade)
    p = 6 + 50 * gloss
    spec_on = (gloss > 0) & (spec ** p > 0.6) & (shade >= 3)
    shade = np.where(spec_on, 7, shade)
    return shade


def clean(mat, shade, hit, stats):
    """orphans and lone notches inside one material take the neighbours' shade"""
    for it in range(2):
        changed = 0
        for s in range(1, 6):
            me = hit & (shade == s)
            same = np.zeros(shade.shape, np.int32)
            for dy, dx in N4:
                same += (shift(shade, dy, dx, -1) == s) & (shift(mat, dy, dx, -1) == mat)
            lone = me & (same == 0)
            if not lone.any():
                continue
            # most common shade among same-material 8-neighbours
            votes = np.zeros(shade.shape + (8,), np.int32)
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if dy == 0 and dx == 0:
                        continue
                    sh = shift(shade, dy, dx, -1)
                    ok = (shift(mat, dy, dx, -1) == mat) & (sh >= 0) & (sh < 8)
                    for t in range(8):
                        votes[..., t] += ok & (sh == t)
            votes[..., 6] = 0
            votes[..., 7] = 0
            new = votes.argmax(axis=2)
            has = votes.max(axis=2) > 0
            fix = lone & has
            shade = np.where(fix, new, shade)
            changed += int(fix.sum())
        stats['orphans'] = stats.get('orphans', 0) + changed
        if changed == 0:
            break
    # flatten lone bumps: a pixel whose 8-neighbourhood is at least 6/8 one other shade of the same material
    votes = np.zeros(shade.shape + (8,), np.int32)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dy == 0 and dx == 0:
                continue
            sh = shift(shade, dy, dx, -1)
            ok = (shift(mat, dy, dx, -1) == mat)
            for t in range(6):
                votes[..., t] += ok & (sh == t)
    top = votes.argmax(axis=2)
    fix = hit & (shade < 6) & (votes.max(axis=2) >= 6) & (top != shade) & (np.abs(top - shade) == 1)
    shade = np.where(fix, top, shade)
    stats['notches'] = stats.get('notches', 0) + int(fix.sum())
    return shade


def mode_filter(mat, shade, hit, stats, need=5):
    """a pixel whose 3x3 neighbourhood (same material) holds `need`+ of one other ramp shade takes it: bigger, calmer clusters"""
    votes = np.zeros(shade.shape + (6,), np.int32)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dy == 0 and dx == 0:
                continue
            sh = shift(shade, dy, dx, -1)
            ok = shift(mat, dy, dx, -1) == mat
            for t in range(6):
                votes[..., t] += ok & (sh == t)
    top = votes.argmax(axis=2)
    fix = hit & (shade < 6) & (shade > 0) & (votes.max(axis=2) >= need) & (top != shade) & (top > 0)
    stats['mode'] = stats.get('mode', 0) + int(fix.sum())
    return np.where(fix, top, shade)


def _raster_line(x0, y0, x1, y1):
    """integer pixels of a line, one per step along the longer axis (clean pixel-art lines, no doubles)"""
    dx, dy = x1 - x0, y1 - y0
    n = int(max(abs(round(x1) - round(x0)), abs(round(y1) - round(y0)))) + 1
    out = []
    for i in range(n):
        t = i / max(n - 1, 1)
        p = (int(round(x0 + dx * t)), int(round(y0 + dy * t)))
        if not out or out[-1] != p:
            out.append(p)
    return out


def strays(mat, shade, hit, keep, stats):
    """the last repair: a ramp pixel with no neighbour of its own material and shade in any of the 8 directions takes
    the most common shade of its material around it (lights are left alone; a painted mark survives where its pixels
    touch, as a line, and only its lone dots are cleaned)"""
    idx = np.where(hit, mat * 8 + shade, -1)
    same = np.zeros(idx.shape, np.int32)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dy or dx:
                same += shift(idx, dy, dx, -2) == idx
    lone = hit & (same == 0) & (shade >= 1) & (shade <= 5) & ~keep
    if not lone.any():
        return shade
    votes = np.zeros(shade.shape + (6,), np.int32)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dy or dx:
                sh = shift(shade, dy, dx, -1)
                ok = shift(mat, dy, dx, -1) == mat
                for t in range(1, 6):
                    votes[..., t] += ok & (sh == t)
    has = votes.max(axis=2) > 0
    fix = lone & has
    shade = np.where(fix, votes.argmax(axis=2), shade)
    stats['strays'] = stats.get('strays', 0) + int(fix.sum())
    return shade


def apply_marks(sc, marks, shade, info, stats):
    """surface marks: 3D polylines on the body, projected, depth-tested and painted as relative shade changes.
    mark = dict(pts=[3D points], d=-1 or +1 (darker / lighter), groups=set of group names, tol=depth tolerance,
                floor=lowest shade a darkening may reach, cap=highest a lightening may reach)"""
    z, hit, mats = info['z'], info['hit'], info['mats']
    grp = info['grp']
    gid = {g: i for i, g in enumerate(sc.groups)}
    H, W = shade.shape
    cnt = 0
    for mk in marks:
        pts = [sc.cam.pt(p) for p in mk['pts']]
        allowed = [gid[g] for g in mk['groups'] if g in gid]
        done = set()
        for a, b in zip(pts[:-1], pts[1:]):
            for (x, y) in _raster_line(a[0] - 0.5, a[1] - 0.5, b[0] - 0.5, b[1] - 0.5):
                if (x, y) in done or not (0 <= x < W and 0 <= y < H) or not hit[y, x]:
                    continue
                done.add((x, y))
                if grp[y, x] not in allowed or mats[y, x] not in mk.get('mats', (M.SKIN, M.SYNTH)):
                    continue
                seg = np.array([b[0] - a[0], b[1] - a[1]])
                L2 = max(float(seg @ seg), 1e-6)
                t = float(np.clip(((x + 0.5 - a[0]) * seg[0] + (y + 0.5 - a[1]) * seg[1]) / L2, 0, 1))
                pz = a[2] + (b[2] - a[2]) * t
                if abs(z[y, x] - pz) > mk.get('tol', 2.5) * sc.cam.s:
                    continue
                s0 = shade[y, x]
                if s0 == 0 or s0 >= 6:
                    continue
                if mk['d'] < 0:
                    shade[y, x] = max(mk.get('floor', 1), s0 + mk['d'])
                else:
                    shade[y, x] = min(mk.get('cap', 5), s0 + mk['d'])
                if 'painted' in info:
                    info['painted'][y, x] = True
                cnt += 1
    stats['marks'] = cnt
    return shade


def compose(sc, r, layer_order, cover=0.45, depth_line=2.2, out_gap=2.0, lines=True, marks=None):
    """full pipeline for one render of a scene: returns ({layer: uint8 image}, stats, pixel info)"""
    S = sc.cam.s                       # depth thresholds are in scene units: scale them with the level of detail
    depth_line, out_gap = depth_line * S, out_gap * S
    px = resolve(r, cover)
    H, W = px['hit'].shape
    prim = px['prim']
    hit = px['hit']
    meta = sc.meta
    mats = np.zeros((H, W), np.int32)
    lay = np.full((H, W), -1, np.int32)
    grp = np.full((H, W), -1, np.int32)
    order = {name: i for i, name in enumerate(layer_order)}
    gid = {g: i for i, g in enumerate(sc.groups)}
    for pid in np.unique(prim[hit]):
        m = meta[pid]
        sel = prim == pid
        mats[sel] = m['material']
        lay[sel] = order.get(m['layer'], 0)
        grp[sel] = gid[m['group']]
    stats = {}
    px['n'] = smooth_normals(px, grp)
    face = grp == gid['head'] if 'head' in gid else None
    val = light_value(px, mats, face=face, scale=sc.cam.s)
    # edge pixels of each layer (for the rim light): a hit pixel next to a pixel not in its layer
    edge = np.zeros((H, W), bool)
    for dy, dx in N4 + [(1, 1), (-1, -1), (1, -1), (-1, 1)]:
        edge |= hit & (shift(lay, dy, dx, -1) != lay)
    shade = bands(val, px, mats, edge)
    shade = np.where(hit, shade, 0)
    # glow materials are flat emissive: shade from distance to their own edge (core bright)
    for gm in (M.GLOW, M.GLOW2):
        g = hit & (mats == gm)
        if g.any():
            # emissive: bright core, dimmer rim; small lights are bright all through
            dist = ndi.distance_transform_edt(g)
            lab, nl = ndi.label(g)
            size = ndi.sum(g, lab, range(1, nl + 1))
            small = np.isin(lab, 1 + np.nonzero(size <= 4)[0])
            shade = np.where(g, np.clip(3 + dist.astype(int), 3, 5), shade)
            shade = np.where(small, 5, shade)
    shade = clean(mats, shade, hit, stats)
    shade = mode_filter(mats, shade, hit, stats)
    z = px['z']
    painted = np.zeros((H, W), bool)
    if marks:
        shade = apply_marks(sc, marks, shade, {'z': z, 'hit': hit, 'mats': mats, 'grp': grp, 'painted': painted}, stats)
    # contour lines inside a layer: the pixel behind gets shade 0 of its own material
    if lines:
        line = np.zeros((H, W), bool)
        for dy, dx in N4:
            zq = shift(z, dy, dx, -1e9)
            lq = shift(lay, dy, dx, -1)
            gq = shift(grp, dy, dx, -1)
            line |= hit & (lq == lay) & (zq - z > depth_line) & ((gq != grp) | (zq - z > depth_line * 2.2))
        keep_glow = (mats == M.GLOW) | (mats == M.GLOW2)
        shade = np.where(line & ~keep_glow, 0, shade)
        stats['contour'] = int(line.sum())
    shade = strays(mats, shade, hit, (mats == M.GLOW) | (mats == M.GLOW2), stats)
    # per-layer images with outlines
    layers = {}
    for name, li in order.items():
        mask = hit & (lay == li)
        if not mask.any():
            continue
        img = np.where(mask, mats * 8 + shade, 0).astype(np.uint8)
        ring = np.zeros((H, W), bool)
        for dy, dx in N4:
            ring |= shift(mask, dy, dx, False)
        ring &= ~mask
        # the inside neighbour with the nearest depth decides join or outline
        zin = np.full((H, W), -1e9)
        inner_shade = np.zeros((H, W), np.int32)
        inner_mat = np.zeros((H, W), np.int32)
        for dy, dx in N4:
            ms = shift(mask, dy, dx, False)
            zs = shift(z, dy, dx, -1e9)
            better = ms & (zs > zin)
            zin = np.where(better, zs, zin)
            inner_shade = np.where(better, shift(shade, dy, dx, 0), inner_shade)
            inner_mat = np.where(better, shift(mats, dy, dx, 0), inner_mat)
        below = hit & (lay < li)
        above = hit & (lay > li)
        join = below & (zin - z < out_gap)
        draw = ring & ~above & ~join
        oc = np.full((H, W), M.INK * 8)
        img = np.where(draw, oc, img).astype(np.uint8)
        layers[name] = img
    info = {'mats': mats, 'shade': shade, 'lay': lay, 'z': z, 'hit': hit, 'prim': prim}
    return layers, stats, info


def compose_item(sc, r, base, slots, back_slots=None, cover=0.45, out_gap=1.2, marks=None, behind_tol=0.35, face_light=False,
                 depth_line=2.2, cover_skin=False):
    """an item (hair, garment, implant) rendered on its own, then laid over the body.
    base: the body's pixel info (z, hit, lay as slot ranks, rank of each body slot in `base['ranks']`).
    slots: {prim layer tag: slot name}; back_slots: {prim layer tag: slot name for pixels behind the body}.
    returns ({slot: image}, stats)"""
    back_slots = back_slots or {}
    S = sc.cam.s
    depth_line, out_gap, behind_tol = depth_line * S, out_gap * S, behind_tol * S
    px = resolve(r, cover)
    if cover_skin and 'mats' in base:
        # clothing covers the skin it lies over: over a skin pixel one sample of cloth is enough (otherwise, where the
        # cloth only grazes a pixel, single skin pixels show through between a sleeve, a glove and the suit)
        p1 = resolve(r, 1e-6)
        take = p1['hit'] & ~px['hit'] & base['hit'] & (base['mats'] == M.SKIN)
        for key_ in px:
            px[key_] = np.where(take[..., None], p1[key_], px[key_]) if px[key_].ndim == 3 else np.where(take, p1[key_], px[key_])
        # and a skin pixel the cloth surrounds on three sides or more (a pinhole between a glove's thumb and palm) is cloth
        h0 = px['hit']
        nb = sum(shift(h0, dy, dx, False).astype(np.int32) for dy, dx in N4)
        pin = ~h0 & base['hit'] & (base['mats'] == M.SKIN) & (nb >= 3)
        if pin.any():
            for dy, dx in N4:
                src_ = pin & shift(h0, dy, dx, False)
                for key_ in px:
                    sv = shift(px[key_], dy, dx, 0) if px[key_].ndim == 2 else np.stack([shift(px[key_][..., c], dy, dx, 0) for c in range(px[key_].shape[2])], -1)
                    px[key_] = np.where(src_[..., None], sv, px[key_]) if px[key_].ndim == 3 else np.where(src_, sv, px[key_])
                pin &= ~src_
    H, W = px['hit'].shape
    prim, hit = px['prim'], px['hit']
    meta = sc.meta
    mats = np.zeros((H, W), np.int32)
    tag = np.full((H, W), -1, np.int32)
    grp = np.full((H, W), -1, np.int32)
    gid = {g: i for i, g in enumerate(sc.groups)}
    tags = sorted(set(m['layer'] for m in meta))
    tid = {t: i for i, t in enumerate(tags)}
    extra_tags = {}
    for pid in np.unique(prim[hit]):
        m = meta[pid]
        sel = prim == pid
        mats[sel] = m['material']
        tag[sel] = tid[m['layer']]
        grp[sel] = gid[m['group']]
    stats = {}
    px['n'] = smooth_normals(px, grp)
    val = light_value(px, mats, face=(np.ones_like(hit) if face_light else None), scale=sc.cam.s)
    edge = np.zeros((H, W), bool)
    for dy, dx in N4 + [(1, 1), (-1, -1), (1, -1), (-1, 1)]:
        edge |= hit & ~shift(hit, dy, dx, False)
    edge |= hit & (base['hit'] == False)
    shade = np.where(hit, bands(val, px, mats, edge), 0)
    for gm in (M.GLOW, M.GLOW2):
        g = hit & (mats == gm)
        if g.any():
            # emissive: bright core, dimmer rim; small lights are bright all through
            dist = ndi.distance_transform_edt(g)
            lab, nl = ndi.label(g)
            size = ndi.sum(g, lab, range(1, nl + 1))
            small = np.isin(lab, 1 + np.nonzero(size <= 4)[0])
            shade = np.where(g, np.clip(3 + dist.astype(int), 3, 5), shade)
            shade = np.where(small, 5, shade)
    shade = clean(mats, shade, hit, stats)
    shade = mode_filter(mats, shade, hit, stats)
    z = px['z']
    painted = np.zeros((H, W), bool)
    if marks:
        shade = apply_marks(sc, marks, shade, {'z': z, 'hit': hit, 'mats': mats, 'grp': grp, 'painted': painted}, stats)
    # contour lines inside the item where one part passes over another
    line = np.zeros((H, W), bool)
    for dy, dx in N4:
        zq = shift(z, dy, dx, -1e9)
        gq = shift(grp, dy, dx, -1)
        line |= hit & shift(hit, dy, dx, False) & (zq - z > depth_line) & (gq != grp)
    glowy = (mats == M.GLOW) | (mats == M.GLOW2)
    shade = np.where(line & ~glowy, 0, shade)
    shade = strays(mats, shade, hit, glowy, stats)
    bz = np.where(base['hit'], base['z'], -1e9)
    # behind the body only if even the item's nearest sample in the pixel is behind it: at a silhouette edge the samples
    # average to a depth that is too far back, and a garment would lose its edge pixel to the skin it covers
    tol = np.full(hit.shape, behind_tol)
    if cover_skin and 'mats' in base:
        # cloth lying on skin wins a near tie (a glove's palm against the fist it is modelled over)
        tol = np.where(base['mats'] == M.SKIN, max(behind_tol, 0.7 * S), behind_tol)
    behind = hit & base['hit'] & (bz > px['znear'] + tol)
    if cover_skin and 'mats' in base:
        # a skin pixel the cloth surrounds on three sides or more is cloth too, even where the cloth dips behind it
        fr0 = hit & ~behind
        nbf = sum(shift(fr0, dy, dx, False).astype(np.int32) for dy, dx in N4)
        behind &= ~((base['mats'] == M.SKIN) & (nbf >= 3))
    front = hit & ~behind
    # every pixel's output slot.  Behind the body a pixel goes to the item's back slot (if any); in front it goes to its
    # own slot, promoted to the later group of the body pixel it covers: cloth always covers the skin it lies over (the
    # fillet where an arm joins the torso belongs to the arm in the body but to the torso in a garment)
    order = ['back', 'far', 'body', 'head', 'held', 'near', 'hands', 'over']
    base_layers = ['back', 'far', 'body', 'near', 'hands']
    slot_list = []

    def sid(key):
        if key not in slot_list:
            slot_list.append(key)
        return slot_list.index(key)
    slot_of = np.full((H, W), -1, np.int32)
    for t, i in tid.items():
        if t in slots:
            slot_of = np.where(front & (tag == i), sid(('F',) + tuple(slots[t])), slot_of)
        if t in back_slots:
            slot_of = np.where(behind & (tag == i), sid(('B',) + tuple(back_slots[t])), slot_of)
    if 'lay' in base:
        for li, name in enumerate(base_layers):
            if name not in slots:
                continue
            target = ('F',) + tuple(slots[name])
            tord = order.index(target[1])
            over = front & base['hit'] & (base['lay'] == li)
            for k, sl in enumerate(list(slot_list)):
                if sl[0] == 'F' and order.index(sl[1]) < tord:
                    m = over & (slot_of == k)
                    if m.any():
                        slot_of = np.where(m, sid(target), slot_of)
                        stats['promoted'] = stats.get('promoted', 0) + int(m.sum())
    out = {}
    for k, sl in enumerate(slot_list):
        mask = slot_of == k
        if not mask.any():
            continue
        which = sl[0] == 'B'
        img = np.where(mask, mats * 8 + shade, 0).astype(np.uint8)
        ring = np.zeros((H, W), bool)
        for dy, dx in N4:
            ring |= shift(mask, dy, dx, False)
        ring &= ~mask
        zin = np.full((H, W), -1e9)
        for dy, dx in N4:
            zs = np.where(shift(mask, dy, dx, False), shift(z, dy, dx, -1e9), -1e9)
            zin = np.maximum(zin, zs)
        if which:
            # behind the body: the outline only shows where the body does not cover it anyway
            draw = ring & ~base['hit'] & ~hit
        else:
            same_item = hit & (slot_of >= 0) & ~mask        # the item itself continues there (in another slot, or behind)
            join = base['hit'] & (zin - bz < out_gap) & (bz <= zin + 0.6 * S)
            draw = ring & ~join & ~(same_item & (np.abs(z - zin) < 2.5 * S))
        img = np.where(draw, M.INK * 8, img).astype(np.uint8)
        name = sl[1:]
        if name in out:
            out[name] = np.where(img > 0, img, out[name])
        else:
            out[name] = img
    return out, stats
