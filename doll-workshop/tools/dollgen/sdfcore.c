/* sdfcore.c - the doll generator's ray-marching core.
 *
 * A scene is a list of primitives in camera space (x right, y down, z toward the viewer; 1 unit = 1 sprite pixel at
 * scale 1).  Primitives are combined group by group: inside a group each primitive is applied to the running distance
 * with its own operation (smooth union, smooth subtraction, intersection); the groups are then joined with a smooth
 * union whose radius is the group's join radius.  Rays are orthographic, cast from the viewer toward -z.
 *
 * For every sample the core reports: hit flag, depth z, the surface normal, the primitive whose own surface is
 * nearest (it decides material and layer) and the group.  Everything is deterministic: no randomness, no threads.
 * Build: cc -O2 -shared -fPIC -o libsdfcore.so sdfcore.c -lm
 */
#include <math.h>
#include <string.h>

#define PSTRIDE 32
/* primitive record (floats):
 *  0 type   1 group   2 op   3 k (blend radius)   4 material   5 layer   6 tag
 *  type 0 round cone : 8..10 a  11..13 b  14 ra  15 rb
 *  type 1 ellipsoid  : 8..10 c  11..13 radii  14..22 rotation rows (world->local)
 *  type 2 round box  : 8..10 c  11..13 half extents  14..22 rotation rows  23 rounding
 *  type 3 plane      : 8..10 n  11 d     (distance = dot(p, n) - d; inside is negative)
 *  type 4 torus      : 8..10 c  11 R  12 r  14..22 rotation rows (torus in the local xz plane)
 *  op 0 smooth union, 1 smooth subtraction, 2 smooth intersection
 */

static inline float clampf(float x, float a, float b) { return x < a ? a : (x > b ? b : x); }
static inline float smin(float a, float b, float k) {
    if (k <= 0.0f) return a < b ? a : b;
    float h = clampf(0.5f + 0.5f * (b - a) / k, 0.0f, 1.0f);
    /* mixed form: exact at h = 0 and h = 1, so a far-away group (1e9) never swamps the float precision */
    return a * h + b * (1.0f - h) - k * h * (1.0f - h);
}
static inline float smax(float a, float b, float k) { return -smin(-a, -b, k); }

static float sd_roundcone(const float *q, const float *P) {
    /* iq's round cone between two points with two radii */
    float ax = P[8], ay = P[9], az = P[10], bx = P[11], by = P[12], bz = P[13], r1 = P[14], r2 = P[15];
    float bax = bx - ax, bay = by - ay, baz = bz - az;
    float l2 = bax * bax + bay * bay + baz * baz;
    float rr = r1 - r2;
    float a2 = l2 - rr * rr;
    float il2 = 1.0f / (l2 > 1e-6f ? l2 : 1e-6f);
    float pax = q[0] - ax, pay = q[1] - ay, paz = q[2] - az;
    float y = pax * bax + pay * bay + paz * baz;
    float z = y - l2;
    float xx = pax * l2 - bax * y, xy = pay * l2 - bay * y, xz = paz * l2 - baz * y;
    float x2 = xx * xx + xy * xy + xz * xz;
    float y2 = y * y * l2;
    float z2 = z * z * l2;
    float k = (rr > 0 ? 1.0f : -1.0f) * rr * rr * x2;
    if ((z > 0 ? 1.0f : -1.0f) * a2 * z2 > k) return sqrtf(x2 + z2) * il2 - r2;
    if ((y > 0 ? 1.0f : -1.0f) * a2 * y2 < k) return sqrtf(x2 + y2) * il2 - r1;
    return (sqrtf(x2 * a2 * il2) + y * rr) * il2 - r1;
}

static inline void to_local(const float *q, const float *c, const float *R, float *o) {
    float dx = q[0] - c[0], dy = q[1] - c[1], dz = q[2] - c[2];
    o[0] = R[0] * dx + R[1] * dy + R[2] * dz;
    o[1] = R[3] * dx + R[4] * dy + R[5] * dz;
    o[2] = R[6] * dx + R[7] * dy + R[8] * dz;
}

static float sd_ellipsoid(const float *q, const float *P) {
    float p[3];
    to_local(q, P + 8, P + 14, p);
    float rx = P[11], ry = P[12], rz = P[13];
    float k0 = sqrtf((p[0] / rx) * (p[0] / rx) + (p[1] / ry) * (p[1] / ry) + (p[2] / rz) * (p[2] / rz));
    float k1 = sqrtf((p[0] / (rx * rx)) * (p[0] / (rx * rx)) + (p[1] / (ry * ry)) * (p[1] / (ry * ry)) + (p[2] / (rz * rz)) * (p[2] / (rz * rz)));
    if (k1 < 1e-6f) return -fminf(rx, fminf(ry, rz));
    return k0 * (k0 - 1.0f) / k1;
}

static float sd_roundbox(const float *q, const float *P) {
    float p[3];
    to_local(q, P + 8, P + 14, p);
    float r = P[23];
    float dx = fabsf(p[0]) - P[11] + r, dy = fabsf(p[1]) - P[12] + r, dz = fabsf(p[2]) - P[13] + r;
    float ox = dx > 0 ? dx : 0, oy = dy > 0 ? dy : 0, oz = dz > 0 ? dz : 0;
    float m = fmaxf(dx, fmaxf(dy, dz));
    return sqrtf(ox * ox + oy * oy + oz * oz) + (m < 0 ? m : 0) - r;
}

static float sd_torus(const float *q, const float *P) {
    float p[3];
    to_local(q, P + 8, P + 14, p);
    float qx = sqrtf(p[0] * p[0] + p[2] * p[2]) - P[11];
    return sqrtf(qx * qx + p[1] * p[1]) - P[12];
}

static inline float sd_prim(const float *q, const float *P) {
    switch ((int)P[0]) {
        case 0: return sd_roundcone(q, P);
        case 1: return sd_ellipsoid(q, P);
        case 2: return sd_roundbox(q, P);
        case 3: return q[0] * P[8] + q[1] * P[9] + q[2] * P[10] - P[11];
        case 4: return sd_torus(q, P);
    }
    return 1e9f;
}

/* evaluate the scene restricted to `idx` (n entries, ordered); groups are contiguous in that order.
 * Groups form a tree: a group with a parent (gparent >= 0) is smooth-joined into its parent with its join radius
 * (an arm into the torso, a hand into the forearm); groups without one meet the rest with a hard union.  So a limb never
 * webs to a part it is not attached to (a raised arm to the jaw, a hanging hand to the thigh).
 * returns the distance; *best gets the union primitive whose own surface is nearest. */
#define MAXG 256
static float scene(const float *q, const float *prims, const int *idx, int n, const float *gjoin, const int *gparent, int ngroups,
                   int *best) {
    float gd[MAXG];
    for (int g = 0; g < ngroups && g < MAXG; g++) gd[g] = 1e9f;
    float bestd = 1e9f;
    *best = -1;
    for (int i = 0; i < n; i++) {
        const float *P = prims + idx[i] * PSTRIDE;
        int g = (int)P[1];
        float d = sd_prim(q, P);
        int op = (int)P[2];
        float k = P[3];
        if (op == 0) {
            gd[g] = smin(gd[g], d, k);
            if (d < bestd) { bestd = d; *best = idx[i]; }
        } else if (op == 1) {
            gd[g] = smax(gd[g], -d, k);
        } else {
            gd[g] = smax(gd[g], d, k);
        }
    }
    /* children into parents, last group first (a grandchild reaches its parent before that one reaches its own) */
    for (int g = ngroups - 1; g >= 0; g--) {
        int p = gparent[g];
        if (p >= 0 && p < g) {
            gd[p] = smin(gd[p], gd[g], gjoin[g]);
            gd[g] = 1e9f;
        }
    }
    float total = 1e9f;
    for (int g = 0; g < ngroups; g++) if (gd[g] < total) total = gd[g];
    return total;
}

/* bounds[i*4..]: screen-space bbox (x0, y0, x1, y1) of primitive i, already grown by its blend radius; a plane or a
 * subtractive primitive should be given a huge box so it always takes part.
 * W, H in samples; scale = samples per unit; ox, oy = unit coordinates of sample (0, 0).
 * zmax/zmin: the ray's range. */
int render(int W, int H, float scale, float ox, float oy, float zmax, float zmin,
           const float *prims, int nprims, const float *bounds, const float *gjoin, const int *gparent, int ngroups,
           unsigned char *hit, float *depth, float *normal, int *primid, int maxsteps, float *occl) {
    int idx[512];
    if (nprims > 512 || ngroups > MAXG) return -1;
    for (int j = 0; j < H; j++) {
        float y = oy + (j + 0.5f) / scale;
        for (int i = 0; i < W; i++) {
            float x = ox + (i + 0.5f) / scale;
            int n = 0;
            for (int p = 0; p < nprims; p++) {
                const float *b = bounds + p * 4;
                if (x >= b[0] && x <= b[2] && y >= b[1] && y <= b[3]) idx[n++] = p;
            }
            int o = j * W + i;
            hit[o] = 0;
            depth[o] = zmin;
            primid[o] = -1;
            occl[o] = 0.0f;
            if (n == 0) continue;
            /* keep only groups that contain at least one union primitive in this pixel */
            int any = 0;
            for (int t = 0; t < n; t++) if ((int)prims[idx[t] * PSTRIDE + 2] == 0) { any = 1; break; }
            if (!any) continue;
            float q[3] = {x, y, zmax};
            int best = -1;
            int ok = 0;
            for (int s = 0; s < maxsteps; s++) {
                float d = scene(q, prims, idx, n, gjoin, gparent, ngroups, &best);
                if (d < 0.004f) { ok = 1; break; }
                q[2] -= (d > 0.02f ? d * 0.9f : 0.02f);
                if (q[2] < zmin) break;
            }
            if (!ok) continue;
            /* refine: step back and forth to land on the surface */
            for (int r = 0; r < 4; r++) {
                int bb;
                float d = scene(q, prims, idx, n, gjoin, gparent, ngroups, &bb);
                q[2] += d;
            }
            float e = 0.05f, qa[3], dx, dy, dz;
            int bb;
            qa[0] = q[0] + e; qa[1] = q[1]; qa[2] = q[2]; dx = scene(qa, prims, idx, n, gjoin, gparent, ngroups, &bb);
            qa[0] = q[0] - e; dx -= scene(qa, prims, idx, n, gjoin, gparent, ngroups, &bb);
            qa[0] = q[0]; qa[1] = q[1] + e; dy = scene(qa, prims, idx, n, gjoin, gparent, ngroups, &bb);
            qa[1] = q[1] - e; dy -= scene(qa, prims, idx, n, gjoin, gparent, ngroups, &bb);
            qa[1] = q[1]; qa[2] = q[2] + e; dz = scene(qa, prims, idx, n, gjoin, gparent, ngroups, &bb);
            qa[2] = q[2] - e; dz -= scene(qa, prims, idx, n, gjoin, gparent, ngroups, &bb);
            float L = sqrtf(dx * dx + dy * dy + dz * dz);
            if (L < 1e-9f) L = 1e-9f;
            scene(q, prims, idx, n, gjoin, gparent, ngroups, &best);
            hit[o] = 1;
            depth[o] = q[2];
            normal[o * 3] = dx / L;
            normal[o * 3 + 1] = dy / L;
            normal[o * 3 + 2] = dz / L;
            primid[o] = best;
            /* ambient occlusion along the normal (iq): how much the scene closes in within ~4 units */
            float ao = 0.0f, w = 1.0f;
            for (int k = 1; k <= 5; k++) {
                float h = 0.75f * k;
                float qq[3] = {q[0] + normal[o * 3] * h, q[1] + normal[o * 3 + 1] * h, q[2] + normal[o * 3 + 2] * h};
                float dd = scene(qq, prims, idx, n, gjoin, gparent, ngroups, &bb);
                ao += (h - dd) * w;
                w *= 0.62f;
            }
            occl[o] = ao;
        }
    }
    return 0;
}
