"""Standing paper dolls for the 64px tileset: people seen from the front or turned up to three-quarters, in a readied pose
(weapon or tool held diagonally across the body: grip hand low on the near side, support hand high on the far side).

Every doll is a stack of 64x64 layers that line up pixel for pixel, so worn and wielded things can be swapped:
    z1 body       legs, torso, neck, head, hair, far upper arm
    z2 under      underwear (always worn by the base doll)
    z3 armor      torso / leg armor
    z4 arms       near upper arm and both forearms (in front of the torso)
    z5 armor_arm  arm guards, pauldrons
    z6 held       weapon or tool
    z7 hands      both hands, closed over whatever is held
The figure faces the viewer's right when turned; the game mirrors it for the other way.
"""
import math
import numpy as np
from PIL import Image
from art64 import Art, col, lit, mix

SZ = 64
SKIN_PREVIEW = '#b98463'
LAYERS = ['shadow', 'body', 'under', 'armor', 'arms', 'armor_arm', 'held', 'hands']


def A():
    return Art(SZ, SZ, 4)


class Body:
    """proportions + pose.  dx values are front-view offsets from the midline; X() turns them for a three-quarter view."""

    def __init__(self, key, turn, sh, chest, waist, hip, head=(4.2, 5.1), head_cy=8.7, top=15.6, fem=False, cyber=False,
                 arm_w=(3.7, 3.1), leg_w=(5.6, 4.2), hair='crop', jaw=1.0):
        self.key, self.turn, self.sh, self.chest, self.waist, self.hip = key, turn, sh, chest, waist, hip
        self.head, self.head_cy, self.top, self.fem, self.cyber = head, head_cy, top, fem, cyber
        self.arm_w, self.leg_w, self.hair, self.jaw = arm_w, leg_w, hair, jaw
        self.mx = 32.0 + 1.3 * turn
        t = top
        self.S_n, self.S_f = (self.X(-sh + 1.6), t + 2.6), (self.X(sh - 1.6), t + 2.6)
        self.E_n, self.E_f = (self.X(-sh - 1.4), t + 10.8), (self.X(sh + 1.2), t + 10.2)
        self.H_n, self.H_f = (self.X(-4.4), t + 18.4), (self.X(7.0), t + 7.4)
        self.P_n, self.P_f = (self.X(-hip * 0.5), t + 21.4), (self.X(hip * 0.5), t + 21.4)
        self.K_n, self.K_f = (self.X(-hip * 0.6), 48.4), (self.X(hip * 0.56), 48.2)
        self.A_n, self.A_f = (self.X(-hip * 0.72), 58.4), (self.X(hip * 0.66), 58.2)

    def X(self, dx):
        k = (1.0 - 0.32 * self.turn) if dx > 0 else (1.0 + 0.03 * self.turn)
        return self.mx + dx * k

    def torso_pts(self):
        t, sh, c, w, h = self.top, self.sh, self.chest, self.waist, self.hip
        right = [(2.4, t - 1.8), (sh - 2.6, t + 0.2), (sh - 0.6, t + 2.0), (c + 0.4, t + 4.8), (c, t + 9.0), (w + 0.5, t + 13.2), (w, t + 15.8),
                 (h, t + 20.4), (h - 0.5, t + 23.6)]
        left = [(-x, y) for x, y in reversed(right)]
        if self.fem:            # the bust shows in profile on the side the figure turns toward; the near side keeps the plain line
            right = right[:4] + [(c + 1.4, t + 6.8), (c + 0.6, t + 8.6)] + right[5:]
        return [(self.X(x), y) for x, y in right + left]

    # masks -------------------------------------------------------------------------------------
    def torso(self, a):
        from scipy import ndimage as ndi
        m = a.poly(self.torso_pts())
        m = ndi.gaussian_filter(m.astype(np.float32), 0.9 * a.ss) > 0.5
        m |= a.ellipse(self.S_n[0] + 0.8, self.S_n[1] + 0.2, 2.4, 2.4) | a.ellipse(self.S_f[0] + 0.3, self.S_f[1] + 0.6, 3.1 * (1 - 0.2 * self.turn), 3.0)
        return m

    def centre(self):
        """x of the torso's visible centre line (the turned body is narrower on the far side)"""
        return (self.X(-self.chest) + self.X(self.chest)) / 2

    def neck(self, a):
        x = self.centre()
        w = 3.2 if self.fem else 3.8
        return a.rrect(x - w / 2, self.head_cy + 2.5, w, self.top - self.head_cy - 1.5, 1.0)

    def head_mask(self, a):
        rx, ry = self.head
        hx = self.centre()
        m = a.ellipse(hx, self.head_cy, rx * (1 - 0.03 * self.turn), ry)
        m |= a.ellipse(hx - 0.3 * self.turn, self.head_cy - 1.2, rx * 1.02, ry * 0.8)      # cranium
        # jaw: a slightly squarer lower face, turned toward the facing side
        m |= a.poly([(hx - rx * 0.86, self.head_cy + 0.6), (hx + rx * 0.86, self.head_cy + 0.6),
                     (hx + rx * 0.5 * self.jaw + 0.4 * self.turn, self.head_cy + ry - 0.4), (hx - rx * 0.4 * self.jaw + 0.4 * self.turn, self.head_cy + ry - 0.2)])
        return m, hx

    def leg(self, a, near):
        P, K, Aa = (self.P_n, self.K_n, self.A_n) if near else (self.P_f, self.K_f, self.A_f)
        w0, w1 = self.leg_w
        if not near:
            w0, w1 = w0 * (1 - 0.1 * self.turn), w1 * (1 - 0.1 * self.turn)
        thigh = a.line(P[0], P[1], K[0], K[1], w0)
        shin = a.line(K[0], K[1], Aa[0], Aa[1], w1)
        calf = a.ellipse((K[0] + Aa[0]) / 2 + (-0.4 if near else 0.4), K[1] + 3.2, w1 * 0.56, 3.0)
        foot = a.ellipse(Aa[0] + 1.0 + 0.8 * self.turn, 60.6, 3.6, 1.9)
        return thigh, shin | calf, foot

    def upper_arm(self, a, near):
        S, E = (self.S_n, self.E_n) if near else (self.S_f, self.E_f)
        w = self.arm_w[0] * (1 if near else 1 - 0.12 * self.turn)
        return a.line(S[0], S[1], E[0], E[1], w)

    def forearm(self, a, near):
        E, Hh = (self.E_n, self.H_n) if near else (self.E_f, self.H_f)
        return a.line(E[0], E[1], Hh[0], Hh[1], self.arm_w[1])

    def hand(self, a, near):
        Hh = self.H_n if near else self.H_f
        return a.ellipse(Hh[0], Hh[1], 2.5, 2.7)


# ------------------------------------------------------------------------------------------------ the three candidates
BODIES = {
    # approved direction: D1's build with D3's turn; hair is a character-creation option, so the base doll is bald
    'B': Body('B', turn=0.8, sh=11.2, chest=9.8, waist=7.8, hip=8.4, head=(5.2, 5.7), head_cy=9.3, top=16.4, hair='none', jaw=1.1,
              arm_w=(6.0, 5.0), leg_w=(7.5, 5.5)),
    'BX': Body('BX', turn=0.8, sh=11.2, chest=9.8, waist=7.8, hip=8.4, head=(5.2, 5.7), head_cy=9.3, top=16.4, hair='none', jaw=1.1,
               arm_w=(6.0, 5.0), leg_w=(7.5, 5.5), cyber=True),
    # the female body (in review): same pose, height and hand positions, so everything held still lines up; narrower
    # shoulders and waist, wider hips, slimmer limbs, a smaller head with a softer jaw
    'F': Body('F', turn=0.8, sh=9.4, chest=8.4, waist=6.2, hip=9.5, head=(4.9, 5.5), head_cy=9.5, top=16.8, hair='none', jaw=0.8,
              arm_w=(4.7, 3.9), leg_w=(7.1, 4.9), fem=True),
    'FX': Body('FX', turn=0.8, sh=9.4, chest=8.4, waist=6.2, hip=9.5, head=(4.9, 5.5), head_cy=9.5, top=16.8, hair='none', jaw=0.8,
               arm_w=(4.7, 3.9), leg_w=(7.1, 4.9), fem=True, cyber=True),
}


# Five skin tones, each a hand-picked 7-step ramp (deep shadow -> highlight).  Shadows lean warm red-violet, highlights
# lean warm yellow, so muscle and hand forms keep their contrast on every tone instead of being a darkened copy.
SKINS = {
    'skin_pale':  ['#5c3b3d', '#8c5c5a', '#b9857e', '#d8a79a', '#ebc3b2', '#f6dccc', '#fff1e6'],   # pale white
    'skin_fair':  ['#4f3329', '#7d5342', '#a9785e', '#c99b7b', '#deb795', '#eecfaf', '#f9e3c9'],   # tan white
    'skin_tan':   ['#3e2420', '#6a3e30', '#93593f', '#b47a58', '#cf9a74', '#e6bb95', '#f4d8b8'],   # moderately tanned
    'skin_brown': ['#26140f', '#45261b', '#64392a', '#83523a', '#a06a4a', '#ba845e', '#d1a07a'],   # darker
    'skin_deep':  ['#100808', '#1f120e', '#311d16', '#452a20', '#5a392b', '#72493a', '#8e6352'],   # near-black
}
SKIN_NAMES = {'skin_pale': 'Pale', 'skin_fair': 'Fair', 'skin_tan': 'Tan', 'skin_brown': 'Brown', 'skin_deep': 'Deep'}
SKIN_DEFAULT = 'skin_tan'
SKIN_RAMP = list(SKINS[SKIN_DEFAULT])


def use_skin(name):
    """select the skin ramp every skin layer is painted with (body, arms, hands); deterministic, call before building"""
    global SKIN_RAMP
    SKIN_RAMP = list(SKINS[name])
UNDER_RAMP = ['#121317', '#1d1f24', '#2a2c33', '#383b44', '#4b4f5a', '#606572']


def ramp_paint(a, m, ramp, bevel=2.6, strength=1.0, seed=1, k=1.0, grain=0.0):
    """light the mask like art64.shade, then posterise onto a hand-picked hue-shifted ramp (classic pixel-art shading).
    k < 1 darkens the whole part (far side)."""
    if not m.any():
        return
    a.shade(m, '#8c8c8c', bevel=bevel, strength=strength, grain=grain, seed=seed, rough=1.0, spec=0.0)
    L = a.rgb[m].mean(axis=1) * k
    t = np.clip((L - 0.28) / 0.62, 0, 0.999)
    R = np.array([col(c) for c in ramp])
    a.rgb[m] = R[(t * len(ramp)).astype(int)]


def skin_paint(a, m, skin, seed=1, bevel=2.6):
    k = float(np.mean(col(skin)) / np.mean(col(SKIN_PREVIEW)))
    ramp_paint(a, m, SKIN_RAMP, bevel=bevel, strength=1.0, seed=seed, k=min(1.0, k))


LIGHT2 = np.array([-0.55, -0.65, 0.52]) / np.linalg.norm([-0.55, -0.65, 0.52])


def limb_paint(a, p0, p1, w0, w1, ramp=None, k=1.0, bulge=(), cap0=True, cap1=True, dim=0, rim_dir=None, lift_inner=None):
    """a limb segment lit as a real cylinder: the side facing the top-left light gets the bright band, the far side the
    shadow band, then a dark rim; every band is a ramp colour, so the result posterises cleanly.
    bulge: (t, amount, spread) muscle swellings along the segment (t 0..1 from p0).  dim: ramp steps darker (far limbs)."""
    ramp = SKIN_RAMP if ramp is None else ramp
    x0, y0 = p0
    x1, y1 = p1
    dx, dy = x1 - x0, y1 - y0
    L = max(np.hypot(dx, dy), 1e-3)
    ux, uy = dx / L, dy / L
    px_, py_ = -uy, ux
    rx, ry = a.xx - x0, a.yy - y0
    t = (rx * ux + ry * uy) / L
    d = rx * px_ + ry * py_
    tc = np.clip(t, 0, 1)
    hw = (w0 + (w1 - w0) * tc) / 2
    for (bt, amt, sp) in bulge:
        hw = hw * (1 + amt * np.exp(-((tc - bt) / sp) ** 2))
    inside = (np.abs(d) <= hw) & (t >= 0) & (t <= 1)
    if cap0:
        inside |= np.hypot(rx, ry) <= w0 / 2
    if cap1:
        inside |= np.hypot(a.xx - x1, a.yy - y1) <= w1 / 2
    u = np.clip(d / np.maximum(hw, 1e-3), -1, 1)
    nz = np.sqrt(np.clip(1 - u * u, 0, 1))
    nx, ny = px_ * u, py_ * u
    lam = nx * LIGHT2[0] + ny * LIGHT2[1] + nz * LIGHT2[2]
    lam = lam - 0.10 * np.clip(t - 0.85, 0, 1)
    lv = np.clip((lam + 0.25) / 1.15, 0, 0.999)
    n = len(ramp)
    idx = np.clip((lv * (n - 1)).astype(int) + 1 - dim, 0, n - 1)
    rim = inside & (np.abs(u) > 0.86)
    if rim_dir is not None:                       # dark rim only on the side facing rim_dir (e.g. away from the torso)
        rim &= (u * (px_ * rim_dir[0] + py_ * rim_dir[1])) > 0
    idx = np.where(rim, np.maximum(idx - 2, 0), idx)
    if lift_inner is not None and rim_dir is not None:
        # where the limb meets the body: keep the inner side at the body's own tone so the join reads as one surface
        t_end, floor = lift_inner
        inner = (u * (px_ * rim_dir[0] + py_ * rim_dir[1])) < 0
        fade = np.clip(1 - t / t_end, 0, 1)
        idx = np.where(inner & (fade > 0), np.maximum(idx, np.round(floor - (1 - fade) * 1.0).astype(int)), idx)
    R_ = np.array([lit(c, k) for c in ramp])
    a.rgb[inside] = R_[idx[inside]]
    a.a[inside] = 1.0
    return inside


def crisp(a, outline=True, oc=(0.06, 0.04, 0.05), no_outline=None, soft=None):
    """downsample by taking the most common colour of each pixel's sub-samples (not the average), so every pixel is a
    real palette colour and edges stay hard; then a 1px dark outline round the silhouette."""
    from scipy import ndimage as ndi
    s = a.ss
    H, W = a.h, a.w
    rgb = np.round(np.clip(a.rgb, 0, 1) * 255).astype(np.int64)
    key = (rgb[..., 0] << 16) | (rgb[..., 1] << 8) | rgb[..., 2]
    key = np.where(a.a > 0.5, key, -1)
    blk = key.reshape(H, s, W, s).transpose(0, 2, 1, 3).reshape(H, W, s * s)
    blk = np.sort(blk, axis=2)
    out = blk[..., 0].copy()
    best = np.ones((H, W), np.int32)
    run = np.ones((H, W), np.int32)
    for i in range(1, s * s):
        same = blk[..., i] == blk[..., i - 1]
        run = np.where(same, run + 1, 1)
        better = run > best
        best = np.where(better, run, best)
        out = np.where(better, blk[..., i], out)
    solid = out >= 0
    img = np.zeros((H, W, 4), np.uint8)
    o = np.maximum(out, 0)
    img[..., 0] = (o >> 16) & 255
    img[..., 1] = (o >> 8) & 255
    img[..., 2] = o & 255
    img[..., 3] = np.where(solid, 255, 0)
    if outline:
        ring = ndi.binary_dilation(solid) & ~solid
        if no_outline is not None:
            ring &= ~no_outline
        img[ring, :3] = (np.array(oc) * 255).astype(np.uint8)
        img[ring, 3] = 235
        if soft is not None:                      # a softer line in a chosen colour (e.g. a deep skin tone for a body gap)
            sm, sc = soft
            sr = ndi.binary_dilation(solid) & ~solid & sm
            img[sr, :3] = (np.array(sc) * 255).astype(np.uint8)
            img[sr, 3] = 255
    return Image.fromarray(img, 'RGBA')


def px_mask(a, m):
    """a supersampled mask brought down to sprite pixels"""
    return m.reshape(a.h, a.ss, a.w, a.ss).mean(axis=(1, 3)) > 0.5


def layer_shadow(b):
    """z0: a soft contact shadow under the feet"""
    from scipy import ndimage as ndi
    a = A()
    m = a.ellipse(b.mx + 0.5, 61.2, 10.5, 2.2)
    a.a[:] = ndi.gaussian_filter(m.astype(np.float32), 1.0 * a.ss) * 0.45
    a.rgb[:] = 0.02
    return a.image()


def layer_body(b, skin=SKIN_PREVIEW, hair_c='#2b2420'):
    a = A()
    far_leg, near_leg = b.leg(a, False), b.leg(a, True)
    # far side first
    k = min(1.0, float(np.mean(col(skin)) / np.mean(col(SKIN_PREVIEW))))
    aw0, aw1 = b.arm_w
    limb_paint(a, b.S_f, b.E_f, aw0 * 0.9, aw1 * 0.95, k=k, dim=1, bulge=[(0.35, 0.12, 0.25)])
    for near in (False, True):
        P, K, Aa = (b.P_n, b.K_n, b.A_n) if near else (b.P_f, b.K_f, b.A_f)
        w0, w1 = b.leg_w
        f = 1.0 if near else 1 - 0.1 * b.turn
        dim = 0 if near else 1
        limb_paint(a, P, K, w0 * f, w1 * 1.02 * f, k=k, dim=dim, bulge=[(0.3, 0.08, 0.3)])
        limb_paint(a, K, Aa, w1 * f, w1 * 0.66 * f, k=k, dim=dim, bulge=[(0.28, 0.16, 0.22)])
        R_ = [lit(c, k) for c in SKIN_RAMP]
        a.fill(a.ellipse(K[0] - 0.5, K[1] - 0.5, 1.2, 0.9), R_[5 - dim], 1.0)                                 # kneecap light
        a.fill(a.ellipse(K[0] + 0.3, K[1] + 1.0, 1.2, 0.45), R_[2 - dim], 1.0)                                # under the knee
        foot = a.ellipse(Aa[0] + 1.7 + 0.8 * b.turn, 60.6, 4.2, 1.7)
        a.fill(foot, R_[3 - dim])
        a.fill(foot & (a.yy < 60.1), R_[4 - dim])
        a.fill(foot & (a.yy > 61.3), R_[1])
        a.fill(foot & (a.xx > Aa[0] + 4.1 + 0.8 * b.turn) & (a.yy < 60.8), R_[5 - dim])          # toes catch the light
    tor = b.torso(a)
    skin_paint(a, tor, skin, 6, bevel=3.2)
    nk = b.neck(a)
    kn = min(1.0, float(np.mean(col(skin)) / np.mean(col(SKIN_PREVIEW))))
    TN = [lit(c, kn) for c in SKIN_RAMP]
    a.fill(nk, TN[3])                                                                    # neck in the head's shadow
    a.fill(nk & (a.xx < b.centre() - 0.6), TN[4])                                        # lit side of the neck
    a.fill(nk & (a.xx > b.centre() + 1.2), TN[2])                                        # far edge
    t = b.top
    # anatomy, kept quiet
    if b.fem:
        fem_torso(a, b, skin)
    else:
        muscles(a, b, skin)
    for s in (-1, 1):
        a.fill(a.line(b.X(s * 1.4), t + 1.2, b.X(s * (b.sh - 2.5)), t + 0.6, 0.55), SKIN_RAMP[5], 0.5)    # collarbones
    a.fill(a.ellipse(b.X(0), t + 15.6, 0.5, 0.5), SKIN_RAMP[2], 0.8)                                    # navel
    # head + face
    hm, hx = b.head_mask(a)
    # the face is painted in flat planes so it stays readable: lit front, a shadow plane on the far side, a light crown
    kk = min(1.0, float(np.mean(col(skin)) / np.mean(col(SKIN_PREVIEW))))
    T_ = [lit(c, kk) for c in SKIN_RAMP]
    rx_, ry_ = b.head
    a.fill(hm, T_[4])
    a.fill(hm & ~a.ellipse(hx - 0.9, b.head_cy - 0.3, rx_, ry_ + 0.4), T_[3])                 # far-side plane
    a.fill(hm & ~a.ellipse(hx - 0.3, b.head_cy + 0.4, rx_ - 0.2, ry_ - 0.2) & (a.yy < b.head_cy) & (a.xx < hx + 1), T_[5])   # crown light
    face(a, b, hx, skin)
    if b.hair != 'none':
        hair(a, b, hx, hair_c)
    if b.cyber:
        cyber_body(a, b, skin)
    return crisp(a)


def muscles(a, b, skin):
    """pectorals, a six-pack and obliques drawn as clean pixel-art forms: a flat lit tone per muscle, a highlight on its
    upper-left edge and a dark crease below, instead of one rounded dome over the whole chest."""
    t = b.top
    tor = b.torso(a)
    k = float(np.mean(col(skin)) / np.mean(col(SKIN_PREVIEW)))
    tone = lambda i: lit(SKIN_RAMP[i], min(1.0, k))
    for s in (-1, 1):
        far = s > 0
        rx = 4.4 * (1 - 0.3 * b.turn if far else 1)
        cx, cy = b.X(s * 3.9), t + 5.2
        pec = a.ellipse(cx, cy, rx, 2.9) & tor
        a.fill(pec, tone(3 if far else 4))
        hi = pec & ~a.ellipse(cx + 0.7, cy + 0.7, rx, 2.9)
        a.fill(hi, tone(4 if far else 5))                                         # light on the upper edge
        crease = (a.ellipse(cx, cy + 0.8, rx, 2.9) & ~pec & (a.yy > cy)) & tor
        a.fill(crease, tone(1))                                                   # crease under the pec
    a.fill(a.line(b.X(0), t + 2.8, b.X(0), t + 7.6, 0.5), tone(2))                 # sternum groove
    for r, y in enumerate((t + 10.2, t + 12.6, t + 15.0)):
        for s in (-1, 1):
            far = s > 0
            w = 2.9 * (1 - 0.3 * b.turn if far else 1)
            x0 = b.X(0.5) if far else b.X(-0.5) - w
            blk = a.rect(x0, y - 1.0, w, 2.0) & tor
            a.fill(blk, tone(3 if far else 4))
            a.fill(blk & (a.yy < y - 0.5), tone(4 if far else 5))                 # top light
            a.fill(a.rect(x0, y + 1.0, w, 0.5) & tor, tone(2))                    # crease below
    a.fill(a.line(b.X(0), t + 9.0, b.X(0), t + 16.2, 0.5), tone(2))               # linea alba
    for s in (1,):                                                                # oblique on the far side (the near one hides under the arm)
        a.fill(a.line(b.X(s * (b.waist - 0.4)), t + 11.0, b.X(s * (b.waist - 1.8)), t + 17.0, 0.5), tone(2))


def fem_torso(a, b, skin):
    """the female chest and stomach in the same language as muscles(): flat lit forms with a highlight on the upper-left
    edge and a soft crease beneath, a cleavage shadow, a quiet toned stomach (no six-pack) and the waist-to-hip curve"""
    t = b.top
    tor = b.torso(a)
    k = float(np.mean(col(skin)) / np.mean(col(SKIN_PREVIEW)))
    tone = lambda i: lit(SKIN_RAMP[i], min(1.0, k))
    for s in (-1, 1):
        far = s > 0
        rx = 3.5 * (1 - 0.28 * b.turn if far else 1)
        cx, cy = b.X(s * 3.5), t + 6.6
        br = a.ellipse(cx, cy, rx, 2.9) & tor
        a.fill(br, tone(3 if far else 4))
        a.fill(br & ~a.ellipse(cx + 0.8, cy + 0.9, rx, 2.9), tone(4 if far else 5))      # light on the upper curve
        a.fill(br & a.ellipse(cx - 0.9, cy - 0.7, 1.1, 0.8), tone(5 if far else 6))       # one bright point near side
        under = a.ellipse(cx, cy + 0.9, rx, 2.9) & ~br & (a.yy > cy + 0.6) & tor
        a.fill(under, tone(2))                                                           # soft crease beneath
    a.fill(a.line(b.X(0), t + 4.8, b.X(0), t + 7.4, 0.55), tone(2))                     # cleavage shadow
    a.fill(a.line(b.X(0), t + 11.0, b.X(0), t + 15.0, 0.45), tone(3))                   # a quiet centre line on the stomach
    for s in (-1, 1):                                                                    # the waist curve catches a little shade
        a.fill(a.line(b.X(s * (b.waist + 0.2)), t + 12.0, b.X(s * (b.waist - 0.6)), t + 16.4, 0.5), tone(2 if s > 0 else 3), 0.8)


def px(a, x, y, c, alpha=1.0, w=1, h=1):
    """one crisp sprite pixel (or a w x h block) at integer position"""
    a.fill(a.rect(int(round(x)), int(round(y)), w, h), c, alpha)


def face(a, b, hx, skin):
    rx, ry = b.head
    cy = b.head_cy
    fx = hx + 1.2 * b.turn
    sep = 2.2 * (1 - 0.2 * b.turn)
    ey = cy + 0.2
    dark = '#1c1512'
    # eyes and brows are character-creation layers, not part of the base doll
    px(a, fx + 0.6 * b.turn, ey + 2.2, SKIN_RAMP[2], 1.0)                          # nose: one shadow pixel
    px(a, fx - 1.0 + 0.6 * b.turn, cy + ry - 2.4, mix(SKIN_RAMP[1], '#8a2a2a', 0.35 if not b.fem else 0.5), 1.0, w=2)   # small mouth
    px(a, fx - 1.0 + 0.6 * b.turn, cy + ry - 1.4, SKIN_RAMP[3], 0.6, w=2)          # lower lip shade
    if b.turn > 0.2:
        a.fill(a.ellipse(hx - rx + 1.0, cy + 0.8, 1.0, 1.7), SKIN_RAMP[3], 1.0)   # near ear
        px(a, hx - rx + 0.6, cy + 0.6, SKIN_RAMP[2], 0.9)
    else:
        for s_ in (-1, 1):
            a.fill(a.ellipse(hx + s_ * (rx - 0.1), cy + 0.8, 0.9, 1.6), SKIN_RAMP[3], 1.0)
    if b.hair == 'none':
        a.fill(a.ellipse(hx - 1.2, cy - ry + 2.0, 1.6, 0.9), SKIN_RAMP[5], 0.55)   # light on the bare scalp


def hair(a, b, hx, c):
    rx, ry = b.head
    cy = b.head_cy
    if b.hair == 'crop':
        cap = a.ellipse(hx + 0.2, cy - 1.2, rx + 0.5, ry - 0.4) & (a.yy < cy - 2.6 + 0.35 * np.abs(a.xx - hx - 1.2))
        cap |= a.rect(hx - rx - 0.3, cy - 2.2, 1.6, 3.6)
        a.shade(cap, c, bevel=1.3, strength=1.0, grain=0.5, rough=0.6, seed=11, spec=0.15)
    elif b.hair == 'bob':
        back = a.ellipse(hx, cy + 0.2, rx + 1.1, ry + 0.4) & (a.yy < cy + 3.8)
        a.shade(back & ~b.head_mask(a)[0], lit(c, 0.8), bevel=1.2, strength=1.0, grain=0.5, rough=0.6, seed=12)
        cap = a.ellipse(hx, cy - 1.2, rx + 0.8, ry - 0.4) & (a.yy < cy - 2.3 - 0.3 * (a.xx - hx + 1.5).clip(0, None))
        cap |= (a.ellipse(hx, cy + 0.2, rx + 1.1, ry + 0.4) & (a.yy < cy + 3.8) & ((a.xx < hx - rx + 0.9) | (a.xx > hx + rx - 0.9)))
        a.shade(cap, c, bevel=1.4, strength=1.0, grain=0.5, rough=0.6, seed=13, spec=0.2)
    elif b.hair == 'shaved':
        cap = a.ellipse(hx + 0.2, cy - 1.2, rx + 0.25, ry - 0.7) & (a.yy < cy - 2.8)
        a.shade(cap, mix(c, '#55504a', 0.45), bevel=1.0, strength=0.8, grain=0.9, rough=0.4, seed=14)


def cyber_body(a, b, skin):
    """an augmented body that skips skin covering in places: a plasteel panel on the near shoulder and chest, a temple
    jack, seams on the thigh.  The prosthetic arm itself is drawn on the arms layer."""
    t = b.top
    panel = a.poly([(b.X(-b.sh + 0.2), t + 1.0), (b.X(-1.6), t + 2.2), (b.X(-1.8), t + 7.6), (b.X(-b.chest + 0.4), t + 8.6), (b.X(-b.sh - 0.6), t + 4.0)])
    a.shade(panel, '#8c96a3', bevel=1.2, strength=1.0, spec=0.5, grain=0.3, rough=0.5, seed=21)
    a.stroke(panel, '#2b3038', 0.35, 0.9)
    a.fill(a.line(b.X(-5.2), t + 4.0, b.X(-2.2), t + 4.6, 0.4), '#2b3038', 0.85)
    a.fill(a.ellipse(b.X(-3.4), t + 6.2, 0.55), '#35d7ff', 1.0)
    a.glow(b.X(-3.4), t + 6.2, 2.2, '#1f8fb0', 0.5)
    hx = b.centre()
    a.fill(a.rect(hx - b.head[0] + 1.1, b.head_cy - 1.8, 1.3, 1.3), '#20252c', 1.0)            # temple jack
    a.fill(a.rect(hx - b.head[0] + 1.4, b.head_cy - 1.5, 0.6, 0.6), '#35d7ff', 1.0)
    for y in (42.0, 45.5):
        a.fill(a.line(b.X(-6.4), y, b.X(-2.0), y + 0.5, 0.4), SKIN_RAMP[1], 0.8)            # plating seams on the thigh
    a.fill(a.line(b.X(-6.0), 42.0, b.X(-6.0), 45.6, 0.4), SKIN_RAMP[1], 0.8)


def layer_under(b):
    """plain underwear: boxer shorts to mid thigh; a sports top for D2.  Charcoal, washed out, a little worn."""
    a = A()
    t = b.top
    c = '#34373f'
    pelvis = a.poly([(b.X(-b.waist - 0.3), t + 16.4), (b.X(b.waist + 0.3), t + 16.4), (b.X(b.hip + 0.4), t + 20.2), (b.X(b.hip - 0.2), t + 24.2), (b.X(-b.hip + 0.2), t + 24.2), (b.X(-b.hip - 0.4), t + 20.2)])
    shorts = pelvis
    for near in (True, False):
        thigh = b.leg(a, near)[0] & (a.yy < (41.6 if b.fem else 44.2))          # women's shorts sit higher on the thigh
        shorts |= ndi_grow(a, thigh, 0.4)
    ramp_paint(a, shorts, UNDER_RAMP, bevel=3.0, strength=1.0, seed=31, grain=0.1)
    a.fill(a.poly([(b.X(-b.waist - 0.3), t + 16.4), (b.X(b.waist + 0.3), t + 16.4), (b.X(b.waist + 0.6), t + 17.8), (b.X(-b.waist - 0.6), t + 17.8)]), '#5b606b', 0.95)  # waistband
    a.fill(a.line(b.X(0.2), t + 18.2, b.X(0.2), t + 22.5, 0.45), '#1d1f24', 0.7)
    a.speckle(shorts, '#4a4d55', 0.04, 32, alpha=0.6)
    if b.fem:
        tor = b.torso(a)
        top = a.poly([(b.X(-b.chest + 0.2), t + 3.4), (b.X(b.chest + 2.0), t + 3.4), (b.X(b.chest + 2.0), t + 9.9), (b.X(-b.chest - 0.1), t + 9.9)]) & tor
        for s in (-1, 1):
            top |= a.line(b.X(s * 3.6), t + 4.0, b.X(s * (b.sh - 2.6)), t + 0.2, 1.3)
        a.fill(top, UNDER_RAMP[2])
        for s in (-1, 1):                         # the top follows the bust: a lit upper curve and a shadow under each side
            far = s > 0
            rx = 3.5 * (1 - 0.28 * b.turn if far else 1)
            cx, cy = b.X(s * 3.5), t + 6.6
            cup = a.ellipse(cx, cy, rx, 2.9) & top
            a.fill(cup, UNDER_RAMP[3 if far else 4])
            a.fill(cup & ~a.ellipse(cx + 0.8, cy + 0.9, rx, 2.9), UNDER_RAMP[4 if far else 5])
            a.fill(top & a.ellipse(cx, cy + 0.9, rx, 2.9) & ~cup & (a.yy > cy + 0.6), UNDER_RAMP[1])
        a.fill(a.line(b.X(0), t + 4.6, b.X(0), t + 7.6, 0.5) & top, UNDER_RAMP[0])
        a.fill(a.rect(b.X(-b.chest - 0.4), t + 8.9, b.X(b.chest + 2.0) - b.X(-b.chest - 0.4), 1.1) & tor, '#5b606b', 0.95)   # under-band
    return a.image(outline=0.7)


def ndi_grow(a, m, px):
    from scipy import ndimage as ndi
    return ndi.binary_dilation(m, iterations=max(1, int(px * a.ss)))


def layer_arms(b, skin=SKIN_PREVIEW, gap=True):
    """gap=False when a sleeve covers the arm: the sleeve draws its own gap line"""
    a = A()
    ua = b.upper_arm(a, True)
    fa_n, fa_f = b.forearm(a, True), b.forearm(a, False)
    if b.cyber:
        prosthetic_arm(a, b, ua, fa_n)
    else:
        k = min(1.0, float(np.mean(col(skin)) / np.mean(col(SKIN_PREVIEW))))
        aw0, aw1 = b.arm_w
        # deltoid + biceps on the upper arm, then the forearm: thick below the elbow, tapering to the wrist
        limb_paint(a, (b.S_n[0] + 1.4, b.S_n[1] - 0.9), b.E_n, aw0 * 1.0, aw1 * 0.95, k=k, rim_dir=(-1, 0),
                   bulge=[(0.5, 0.08, 0.25)], lift_inner=(0.9, 4))
        limb_paint(a, b.E_n, b.H_n, aw1 * 1.0, aw1 * 0.72, k=k, bulge=[(0.22, 0.14, 0.22)])
        R_ = [lit(c, k) for c in SKIN_RAMP]
        a.fill(a.ellipse(b.E_n[0] + 0.6, b.E_n[1] - 0.2, 0.9, 0.5), R_[2], 1.0)                              # elbow crease
    k = min(1.0, float(np.mean(col(skin)) / np.mean(col(SKIN_PREVIEW))))
    limb_paint(a, b.E_f, b.H_f, b.arm_w[1] * 0.98, b.arm_w[1] * 0.72, k=k, bulge=[(0.22, 0.12, 0.22)])
    # no outline where the shoulder overlaps the torso: the arm grows out of the body instead of sitting on it
    tor = px_mask(a, b.torso(a))
    yy_, xx_ = np.mgrid[0:SZ, 0:SZ]
    # the shoulder top grows out of the torso (no line); from the armpit down a 1px deep-skin gap separates arm and body
    shoulder = tor & (yy_ < b.S_n[1] + 2.5) & (xx_ < b.centre())
    gapm = tor & (yy_ >= b.S_n[1] + 2.5) & (yy_ < b.E_n[1] + 0.5) & (xx_ < b.centre())
    return crisp(a, no_outline=shoulder | gapm, soft=(gapm, tuple(col(SKIN_RAMP[1]) * k)) if gap else None)


def prosthetic_arm(a, b, ua, fa):
    """graphite plates over a chrome frame, cyan joint lights."""
    a.shadow(ua, 0.7, 0.9, 1.0, 0.35)
    a.shade(ua, '#3a3f48', bevel=1.6, strength=1.0, spec=0.6, grain=0.25, rough=0.5, seed=44)
    a.shade(fa, '#454b55', bevel=1.4, strength=1.0, spec=0.6, grain=0.25, rough=0.5, seed=45)
    # chrome frame visible between plates
    for (p, q) in ((b.S_n, b.E_n), (b.E_n, b.H_n)):
        mx_, my_ = (p[0] + q[0]) / 2, (p[1] + q[1]) / 2
        a.fill(a.line(mx_ - 1.2, my_ - 0.2, mx_ + 1.2, my_ + 0.4, 0.5), '#c9d2dc', 0.9)
    for (x, y) in (b.E_n, b.S_n):
        j = a.ellipse(x, y, 1.6)
        a.shade(j, '#b9c3cf', bevel=0.8, strength=1.0, spec=0.9)
        a.fill(a.ellipse(x, y, 0.55), '#35d7ff', 1.0)
        a.glow(x, y, 2.4, '#1f8fb0', 0.45)


def fist(a, Hh, E, T_, far=False):
    """a fist closed round a haft, drawn in the hand's own frame so every line follows the hand: the axis runs from
    the elbow E through the wrist, finger gaps run along it, the knuckle ridge crosses it, the thumb wraps over the haft"""
    d = 1 if far else 0
    ux, uy = Hh[0] - E[0], Hh[1] - E[1]
    L = max(np.hypot(ux, uy), 1e-3)
    ux, uy = ux / L, uy / L
    vx, vy = -uy, ux
    rx, ry = a.xx - Hh[0], a.yy - Hh[1]
    al = rx * ux + ry * uy                     # along the hand (toward the finger tips)
    pe = rx * vx + ry * vy                     # across the hand
    hand = (al / 2.9) ** 2 + (pe / 2.6) ** 2 <= 1
    lightside = np.sign(vx * -0.55 + vy * -0.65) or 1.0     # which side of the hand faces the top-left light
    tone = np.full(al.shape, 4 - d)
    tone = np.where(pe * lightside > 1.3, 5 - d, tone)
    tone = np.where(pe * lightside < -1.4, 2 - d, tone)
    tone = np.where((al > -1.0) & (al < -0.3) & (np.abs(pe) < 1.9), 5 - d, tone)            # knuckle ridge
    for g in (-1.25, 0.0, 1.25):                                                             # gaps between fingers
        tone = np.where((np.abs(pe - g) < 0.45) & (al > -0.3), 2 - d, tone)
    tone = np.where(al > 2.2, 2 - d, tone)                                                   # finger tips curl into shadow
    tone = np.clip(tone, 0, len(T_) - 1).astype(int)
    TT = np.array([col(c) for c in T_])
    a.rgb[hand] = TT[tone[hand]]
    a.a[hand] = 1.0
    th = ((al + 0.6) / 1.4) ** 2 + ((pe - 2.2 * lightside) / 1.1) ** 2 <= 1                # thumb on the lit side
    a.rgb[th & ~hand] = TT[4 - d]
    a.a[th & ~hand] = 1.0


def layer_hands(b, skin=SKIN_PREVIEW):
    a = A()
    k = min(1.0, float(np.mean(col(skin)) / np.mean(col(SKIN_PREVIEW))))
    T_ = [lit(c, k) for c in SKIN_RAMP]
    for near in (True, False):
        m = b.hand(a, near)
        if b.cyber and near:
            a.shade(m, '#4b525d', bevel=0.9, strength=1.0, spec=0.6, seed=46)
            a.fill(a.line(b.H_n[0] - 1.2, b.H_n[1] - 0.2, b.H_n[0] + 1.2, b.H_n[1] - 0.6, 0.35), '#c9d2dc', 0.8)
            for kk in (-1, 0, 1):
                px(a, b.H_n[0] + kk, b.H_n[1] + 0.5, '#2a2e35')                  # finger joints of the prosthetic
        else:
            fist(a, b.H_n if near else b.H_f, b.E_n if near else b.E_f, T_, far=False)
    # no outline where the fist meets its own forearm
    joins = px_mask(a, b.forearm(a, True) | b.forearm(a, False))
    return crisp(a, no_outline=joins, oc=tuple(col(T_[0])))


# ------------------------------------------------------------------------------------------------ armor sets (one per candidate)
def armor_plate_carrier(b):
    """military plate carrier: olive drab, scuffed front plate, three mag pouches; knee and shin guards."""
    a = A()
    t = b.top
    base = '#5c7050'
    body = a.poly([(b.X(-b.chest - 0.6), t + 3.4), (b.X(b.chest + 0.6), t + 3.4), (b.X(b.chest + 0.4), t + 14.6), (b.X(-b.chest - 0.4), t + 14.6)])
    a.shadow(body, 0.6, 1.0, 1.2, 0.4)
    a.shade(body, base, bevel=1.8, strength=1.0, grain=0.45, rough=0.7, seed=51)
    for s in (-1, 1):
        a.shade(a.line(b.X(s * (b.sh - 3.0)), t - 0.2, b.X(s * (b.chest - 1.2)), t + 3.8, 2.2), lit(base, 0.9), bevel=0.9, strength=1.0, grain=0.3)
    plate = a.rrect(b.X(-4.6), t + 4.4, b.X(4.6) - b.X(-4.6), 6.4, 1.4)
    a.shade(plate, lit(base, 1.2), bevel=1.2, strength=1.0, grain=0.4, spec=0.1, seed=52)
    for k, x in enumerate((-3.6, 0.0, 3.6)):
        p = a.rrect(b.X(x) - 1.5, t + 11.0, 3.0 * (1 - (0.25 * b.turn if x > 0 else 0)), 3.4, 0.6)
        a.shade(p, lit(base, 0.86), bevel=0.8, strength=1.0, grain=0.3, seed=53 + k)
        a.fill(a.rect(b.X(x) - 1.3, t + 11.0, 2.6 * (1 - (0.25 * b.turn if x > 0 else 0)), 0.6), lit(base, 0.62), 0.9)
    a.speckle(body, '#2e3326', 0.12, 54, alpha=0.7)
    a.speckle(plate, '#8d9a80', 0.06, 55, alpha=0.8)
    for near in (True, False):
        K = b.K_n if near else b.K_f
        Aa = b.A_n if near else b.A_f
        kp = a.ellipse(K[0], K[1] - 0.3, 2.6, 2.2)
        a.shade(kp, '#2f3329', bevel=1.0, strength=1.0, spec=0.25, seed=56)
        sh_ = a.line(K[0], K[1] + 2.6, (K[0] + Aa[0]) / 2, (K[1] + Aa[1]) / 2 + 2, 3.6)
        a.shade(sh_, lit(base, 0.95 if near else 0.82), bevel=1.1, strength=1.0, grain=0.4, seed=57)
        a.fill(a.line(K[0] - 1.8, K[1] + 5.2, K[0] + 1.8, K[1] + 5.2, 0.5), '#1e2119', 0.8)
    return a.image(outline=0.8), None


def armor_duty_vest(b):
    """police-corporate light vest: navy-black shell, cyan stripe, white shoulder flash; forearm guards."""
    a = A()
    t = b.top
    base = '#262a33'
    body = a.poly([(b.X(-b.chest - 0.4), t + 2.6), (b.X(b.chest + 0.4), t + 2.6), (b.X(b.waist + 1.2), t + 16.0), (b.X(-b.waist - 1.2), t + 16.0)])
    body |= a.poly([(b.X(-b.sh + 1.8), t - 0.3), (b.X(-1.8), t + 2.8), (b.X(-b.chest - 0.4), t + 2.8)]) | a.poly([(b.X(b.sh - 1.8), t - 0.3), (b.X(1.8), t + 2.8), (b.X(b.chest + 0.4), t + 2.8)])
    a.shadow(body, 0.6, 1.0, 1.2, 0.4)
    a.shade(body, base, bevel=1.9, strength=1.0, grain=0.25, spec=0.25, rough=0.8, seed=61)
    a.fill(a.line(b.X(-b.chest + 0.6), t + 5.2, b.X(b.chest - 0.6), t + 5.2, 0.8), '#35d7ff', 0.95)
    a.glow(b.X(0), t + 5.2, 4.0, '#0f6f8a', 0.25)
    a.fill(a.rect(b.X(-1.0), t + 7.2, 2.0, 2.6), '#c9d0d8', 0.9)                       # id plate (no text)
    a.fill(a.rect(b.X(-b.waist - 1.2), t + 14.4, b.X(b.waist + 1.2) - b.X(-b.waist - 1.2), 1.6), '#0b1422', 0.95)   # duty belt
    for x in (-4.4, 2.6):
        a.shade(a.rrect(b.X(x), t + 13.6, 2.2, 2.6, 0.5), '#2a2e35', bevel=0.6, strength=1.0)
    a.speckle(body, '#3b404b', 0.06, 62, alpha=0.6)
    arm = A()
    for near in (True, False):
        E, Hh = (b.E_n, b.H_n) if near else (b.E_f, b.H_f)
        g = arm.line(E[0] + (Hh[0] - E[0]) * 0.2, E[1] + (Hh[1] - E[1]) * 0.2, E[0] + (Hh[0] - E[0]) * 0.78, E[1] + (Hh[1] - E[1]) * 0.78, b.arm_w[1] + 1.0)
        arm.shade(g, base, bevel=1.0, strength=1.0, spec=0.3, grain=0.2, seed=63)
        arm.fill(arm.line(E[0] + (Hh[0] - E[0]) * 0.3, E[1] + (Hh[1] - E[1]) * 0.3, E[0] + (Hh[0] - E[0]) * 0.7, E[1] + (Hh[1] - E[1]) * 0.7, 0.45), '#35d7ff', 0.8)
    # white shoulder flash on the near shoulder
    arm.fill(arm.ellipse(b.S_n[0] - 0.6, b.S_n[1] + 0.6, 1.6, 1.1), '#d8dde2', 0.9)
    return a.image(outline=0.8), arm.image(outline=0.75)


def armor_plasteel(b):
    """segmented plasteel: off-white plates over a dark harness, scuffed and chipped; one pauldron on the flesh shoulder."""
    a = A()
    t = b.top
    pal = '#aeb2aa'
    harness = a.poly([(b.X(-b.chest), t + 3.0), (b.X(b.chest), t + 3.0), (b.X(b.waist + 0.6), t + 15.4), (b.X(-b.waist - 0.6), t + 15.4)])
    a.shadow(harness, 0.6, 1.0, 1.2, 0.4)
    a.shade(harness, '#24262b', bevel=1.4, strength=1.0, grain=0.3, seed=71)
    rows = [(t + 3.4, 4.0, b.chest - 0.6), (t + 7.8, 3.2, b.chest - 1.2), (t + 11.4, 3.2, b.waist + 0.2)]
    for k, (y, hgt, w) in enumerate(rows):
        for s in (-1, 1):
            x0, x1 = (b.X(-w), b.X(-0.4)) if s < 0 else (b.X(0.4), b.X(w))
            p = a.rrect(x0, y, x1 - x0, hgt, 0.9)
            a.shade(p, lit(pal, 1.0 - 0.06 * k), bevel=1.1, strength=1.0, spec=0.35, grain=0.25, rough=0.6, seed=72 + k)
    pl = a.a > 0.5
    a.speckle(pl & (a.rgb.mean(axis=2) > 0.5), '#6d6a5e', 0.10, 75, alpha=0.8)           # grime and chips
    a.speckle(pl & (a.rgb.mean(axis=2) > 0.5), '#3a3833', 0.03, 76, size=1.5, alpha=0.8)
    a.fill(a.line(b.X(-b.chest + 1), t + 9.6, b.X(-1.6), t + 10.4, 0.4), '#8a3a2a', 0.6)     # an old rust streak
    arm = A()
    # pauldron on the far (flesh) shoulder - the near shoulder is the prosthetic
    pd = arm.ellipse(b.S_f[0] + 0.6, b.S_f[1] + 0.2, 2.9, 2.6)
    arm.shade(pd, pal, bevel=1.2, strength=1.0, spec=0.35, grain=0.3, seed=77)
    arm.fill(arm.line(b.S_f[0] - 1.6, b.S_f[1] + 1.2, b.S_f[0] + 2.8, b.S_f[1] + 1.6, 0.4), '#56544c', 0.8)
    # shin plates
    for near in (True, False):
        K = b.K_n if near else b.K_f
        Aa = b.A_n if near else b.A_f
        s_ = a.line(K[0], K[1] + 1.0, (K[0] + Aa[0]) / 2, (K[1] + Aa[1]) / 2 + 2.5, 3.6)
        a.shade(s_, lit(pal, 0.96 if near else 0.84), bevel=1.1, strength=1.0, spec=0.3, grain=0.3, seed=78)
    return a.image(outline=0.8), arm.image(outline=0.75)


ARMOR = {'B': ('plate carrier + knee / shin guards', armor_plate_carrier),
         'BX': ('plasteel plates + pauldron + shin plates', armor_plasteel)}


# ------------------------------------------------------------------------------------------------ held things
def _harden(im, outline=True):
    """crisp up a resampled sprite: binary alpha and a 1px dark outline, like art64's own output"""
    from scipy import ndimage as ndi
    arr = np.asarray(im).astype(np.float32) / 255.0
    a = arr[..., 3]
    solid = a > 0.45
    rgb = arr[..., :3] / np.maximum(a, 1e-4)[..., None]
    rgb = np.clip(rgb, 0, 1)
    out = np.zeros_like(arr)
    out[..., :3] = rgb
    out[..., 3] = solid
    if outline:
        ring = ndi.binary_dilation(solid) & ~solid
        out[ring, :3] = (0.05, 0.05, 0.08)
        out[ring, 3] = 0.9
    return Image.fromarray((out * 255 + 0.5).astype(np.uint8), 'RGBA')


def held_from_icon(b, icon, length, grip=(0.3, 0.62)):
    """place a side-view icon (pointing right) along the hold axis, its grip on the near hand.
    grip = (fraction along the length from the rear, fraction down the height)."""
    bb = icon.getbbox()
    ic = icon.crop(bb)
    U = 4
    big = ic.resize((ic.width * U, ic.height * U), Image.NEAREST)
    s = length / ic.width
    big = big.resize((max(1, int(big.width * s)), max(1, int(big.height * s))), Image.BOX)       # still at U x
    gx, gy = grip[0] * big.width, grip[1] * big.height
    dx, dy = b.H_f[0] - b.H_n[0], b.H_f[1] - b.H_n[1]
    ang = math.degrees(math.atan2(-dy, dx))
    rot = big.rotate(ang, resample=Image.BICUBIC, expand=True)
    # where the grip went
    cx, cy = big.width / 2, big.height / 2
    r = math.radians(ang)
    vx, vy = gx - cx, gy - cy
    rx, ry = vx * math.cos(r) + vy * math.sin(r), -vx * math.sin(r) + vy * math.cos(r)
    gpx, gpy = rot.width / 2 + rx, rot.height / 2 + ry
    canvas = Image.new('RGBA', (SZ * U, SZ * U), (0, 0, 0, 0))
    canvas.alpha_composite(rot, (int(round(b.H_n[0] * U - gpx)), int(round(b.H_n[1] * U - gpy))))
    small = canvas.resize((SZ, SZ), Image.BOX)
    return _harden(small)


def gun_held(b, item, length):
    from t64_guns import gun_icon
    return held_from_icon(b, gun_icon(item), length, grip=(0.32, 0.62))


def pickaxe_held(b):
    """a work pickaxe on the same hold axis: ash haft, forged head with a rusted spike."""
    a = A()
    ux, uy = b.H_f[0] - b.H_n[0], b.H_f[1] - b.H_n[1]
    L = math.hypot(ux, uy)
    ux, uy = ux / L, uy / L
    p0 = (b.H_n[0] - ux * 6.0, b.H_n[1] - uy * 6.0)
    p1 = (b.H_n[0] + ux * 23.0, b.H_n[1] + uy * 23.0)
    haft = a.line(p0[0], p0[1], p1[0], p1[1], 1.7)
    a.shadow(haft, 0.6, 0.8, 0.8, 0.35)
    a.shade(haft, '#8a6a48', bevel=0.8, strength=1.0, grain=0.5, rough=0.4, seed=81)
    nx, ny = -uy, ux                           # across the haft
    hx_, hy_ = p1
    blade = a.poly([(hx_ + nx * 7.5 - ux * 0.5, hy_ + ny * 7.5 - uy * 0.5), (hx_ + nx * 1.5 + ux * 1.4, hy_ + ny * 1.5 + uy * 1.4),
                    (hx_ - nx * 1.5 + ux * 1.4, hy_ - ny * 1.5 + uy * 1.4), (hx_ - nx * 7.0 - ux * 1.2, hy_ - ny * 7.0 - uy * 1.2),
                    (hx_ - nx * 1.4 - ux * 1.4, hy_ - ny * 1.4 - uy * 1.4), (hx_ + nx * 1.4 - ux * 1.4, hy_ + ny * 1.4 - uy * 1.4)])
    a.shade(blade, '#6c737c', bevel=0.9, strength=1.0, spec=0.5, grain=0.3, seed=82)
    a.speckle(blade, '#7a4a2a', 0.18, 83, alpha=0.8)
    a.fill(a.line(p0[0], p0[1], p0[0] + ux * 3, p0[1] + uy * 3, 1.9), '#2a2a2a', 0.9)        # grip tape
    return a.image(outline=0.8)


GUNS = {'B': 'trl_gun_vk74', 'BX': 'trl_gun_hs10'}
GUN_LEN = {'rifle': 31, 'smg': 22, 'shotgun': 32, 'pistol': 13, 'sniper': 36}


# ------------------------------------------------------------------------------------------------ build
def stack(layers):
    out = Image.new('RGBA', (SZ, SZ), (0, 0, 0, 0))
    for im in layers:
        if im is not None:
            out.alpha_composite(im)
    return out


def build(key, items):
    b = BODIES[key]
    L = {'shadow': layer_shadow(b), 'body': layer_body(b), 'under': layer_under(b), 'arms': layer_arms(b), 'hands': layer_hands(b)}
    arm_name, fn = ARMOR[key]
    L['armor'], L['armor_arm'] = fn(b)
    it = next(i for i in items if i['id'] == GUNS[key])
    L['gun'] = gun_held(b, it, GUN_LEN[it['tags'][1]])
    L['pick'] = pickaxe_held(b)
    bare = stack([L['shadow'], L['body'], L['under'], L['arms'], L['hands']])
    armored = stack([L['shadow'], L['body'], L['under'], L['armor'], L['arms'], L['armor_arm'], L['hands']])
    gunned = stack([L['shadow'], L['body'], L['under'], L['armor'], L['arms'], L['armor_arm'], L['gun'], L['hands']])
    tool = stack([L['shadow'], L['body'], L['under'], L['arms'], L['pick'], L['hands']])
    return {'bare': bare, 'armor': armored, 'gun': gunned, 'tool': tool, 'layers': L, 'gun_name': it['name'], 'armor_name': arm_name}
