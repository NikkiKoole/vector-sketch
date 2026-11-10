// hair.c — a hair lock's strip in one call (src/hair-native.lua), the same maths as
// src/hair-locks.lua's lockPath + stripMesh: a Catmull-Rom curve through the lock's points
// (4 samples a segment, or ~10 a ringlet turn or wave), for ringlets a
// corkscrew around it seen a little from above (its back half darker), for curly hair a wave
// across it, then a strip the
// picture's width across, written as { x, y, u, v, r, g, b, a } floats (2 vertices a sample)
// for Mesh:setVertices(ByteData). Built into libdesound with the synth (build.sh, build-ios.sh).
#include <math.h>

#define HAIR_MAX_SAMPLES 400
#define HAIR_PLAIN_PER 4

static double sx[HAIR_MAX_SAMPLES], sy[HAIR_MAX_SAMPLES], ss[HAIR_MAX_SAMPLES];

// The lock's point i (1-based), its ends mirrored.
static void at(const float *p, int n, int i, double *x, double *y) {
    if (i < 1) { *x = 2.0 * p[0] - p[2]; *y = 2.0 * p[1] - p[3]; return; }
    if (i > n) { *x = 2.0 * p[2 * n - 2] - p[2 * n - 4]; *y = 2.0 * p[2 * n - 1] - p[2 * n - 3]; return; }
    *x = p[2 * i - 2];
    *y = p[2 * i - 1];
}

static void unit_tangent(int c, int count, double *tx, double *ty) {
    int a = c > 0 ? c - 1 : 0, b = c < count - 1 ? c + 1 : count - 1;
    double dx = sx[b] - sx[a], dy = sy[b] - sy[a];
    double l = sqrt(dx * dx + dy * dy);
    if (l > 1e-6) { *tx = dx / l; *ty = dy / l; } else { *tx = 0; *ty = 1; }
}

// points: flat x, y (n of them); segment: rest length between them; radius 0 = no ringlets;
// wave 0 = no curly wave (its height, px, and wavePitch its length). Returns the number of
// vertices written (2 a sample), 0 when there's no lock.
int hair_strip(const float *points, int n, float segment, float radius, float pitch, float wave,
               float wavePitch, float phase, float tilt, float halfWidth, float *out) {
    if (n < 2) return 0;
    double L = segment, R = radius, P = pitch < 4 ? 4 : pitch, W = wave, WP = wavePitch;
    int maxPer = (HAIR_MAX_SAMPLES - 1) / (n - 1);
    if (maxPer < 1) maxPer = 1;
    int ringPer = 0;
    if (R > 0) {
        ringPer = (int)ceil(L / P * 10);
        if (ringPer < 3) ringPer = 3;
    }
    if (W > 0 && ringPer < 2) ringPer = 2; // ceil(10 / WAVE_SEGMENTS) in hair-locks.lua
    if (ringPer > maxPer) ringPer = maxPer;
    int count = 0;
    for (int j = 1; j <= n - 1; j++) {
        double x0, y0, x1, y1, x2, y2, x3, y3;
        at(points, n, j - 1, &x0, &y0);
        at(points, n, j, &x1, &y1);
        at(points, n, j + 1, &x2, &y2);
        at(points, n, j + 2, &x3, &y3);
        // a fixed count a segment (hair-locks.lua PLAIN_PER): counted by the bend, the samples
        // changed as the lock moved and its picture slid along it
        int per = ringPer ? ringPer : (HAIR_PLAIN_PER < maxPer ? HAIR_PLAIN_PER : maxPer);
        int last = (j == n - 1) ? per : per - 1;
        for (int s = 0; s <= last && count < HAIR_MAX_SAMPLES; s++) {
            double t = (double)s / per, t2 = t * t, t3 = t2 * t;
            sx[count] = 0.5 * (2 * x1 + (x2 - x0) * t + (2 * x0 - 5 * x1 + 4 * x2 - x3) * t2
                + (3 * x1 - x0 - 3 * x2 + x3) * t3);
            sy[count] = 0.5 * (2 * y1 + (y2 - y0) * t + (2 * y0 - 5 * y1 + 4 * y2 - y3) * t2
                + (3 * y1 - y0 - 3 * y2 + y3) * t3);
            ss[count] = (j - 1 + t) * L;
            count++;
        }
    }
    // the corkscrew and the wave, around the axis (tangents from the axis), growing in over the
    // first turn / wave
    double shade[HAIR_MAX_SAMPLES];
    if (R > 0 || W > 0) {
        double ox[HAIR_MAX_SAMPLES], oy[HAIR_MAX_SAMPLES];
        for (int c = 0; c < count; c++) {
            double tx, ty;
            unit_tangent(c, count, &tx, &ty);
            double side = 0, along = 0;
            shade[c] = 1;
            if (R > 0) {
                double r = R * (ss[c] / P < 1 ? ss[c] / P : 1);
                double th = ss[c] / P * 2 * M_PI + phase;
                double cs = cos(th);
                side = r * sin(th);
                along = r * tilt * cs;
                shade[c] = 0.72 + 0.28 * (0.5 + 0.5 * cs);
            }
            if (W > 0) {
                double grow = ss[c] / WP < 1 ? ss[c] / WP : 1;
                side += W * grow * sin(ss[c] / WP * 2 * M_PI + phase + 1);
            }
            ox[c] = sx[c] - ty * side + tx * along;
            oy[c] = sy[c] + tx * side + ty * along;
        }
        for (int c = 0; c < count; c++) { sx[c] = ox[c]; sy[c] = oy[c]; }
    } else {
        for (int c = 0; c < count; c++) shade[c] = 1;
    }
    // the strip: v by the rest length along the lock (so the picture can't slide), the width
    // clamped in tight bends (about twice the bend's radius, as the limb ribbons do)
    double total = (n - 1) * L > 1e-6 ? (n - 1) * L : 1e-6;
    for (int c = 0; c < count; c++) {
        double tx, ty;
        unit_tangent(c, count, &tx, &ty);
        double v = ss[c] / total;
        double hw = halfWidth;
        if (c > 0 && c < count - 1) {
            double ax = sx[c] - sx[c - 1], ay = sy[c] - sy[c - 1];
            double bx = sx[c + 1] - sx[c], by = sy[c + 1] - sy[c];
            double la = sqrt(ax * ax + ay * ay), lb = sqrt(bx * bx + by * by);
            if (la >= 1e-9 && lb >= 1e-9) {
                double dot = (ax * bx + ay * by) / (la * lb);
                if (dot < 0.9999) {
                    if (dot < -1) dot = -1;
                    if (dot > 1) dot = 1;
                    double lim = (la < lb ? la : lb) * tan((M_PI - acos(dot)) * 0.5);
                    if (lim < hw) hw = lim;
                }
            }
        }
        float *l = out + 16 * c, *r = l + 8;
        l[0] = (float)(sx[c] - ty * hw); l[1] = (float)(sy[c] + tx * hw); l[2] = 0; l[3] = (float)v;
        r[0] = (float)(sx[c] + ty * hw); r[1] = (float)(sy[c] - tx * hw); r[2] = 1; r[3] = (float)v;
        l[4] = l[5] = l[6] = r[4] = r[5] = r[6] = (float)shade[c];
        l[7] = r[7] = 1;
    }
    return 2 * count;
}

// hair_strip's version: 2 = with the curly wave (wave, wavePitch). src/hair-native.lua only uses
// hair_strip when this is there, so a library from before can't be called with the new arguments.
int hair_strip_v2(void) { return 2; }

// One lock's simulation for `steps` fixed steps of dt (src/hair-locks.lua's stepLock, the same
// maths): verlet with damping and gravity, then root outward each point pulled toward the rest
// shape (fixed in the head's frame, fading to nothing at the tip), back to its length (springy:
// part of the way), out of the head's oval, DFTL (the parent gives back the pull), on the floor.
// p, q: the points and their previous positions, flat x, y (n each), updated in place; bends:
// n + 1 values, bends[i] for point i (1-based, used from 3); the root (rootLX, rootLY) in the head's
// frame, the head at (bx, by) turned by `angle`. hasOval / hasGround: 0 = none.
int hair_step(double *p, double *q, int n, double segment, double restAngle, const double *bends,
              double rootLX, double rootLY, int drape, double bx, double by, double angle,
              double gx, double gy, double dt, double damping, double stand, double stiffness,
              double springy, int hasOval, double ovalX, double ovalY, int hasGround, double groundY,
              int steps) {
    const double DFTL = 0.5, GROUND_GAP = 2.0;
    if (n < 2) return 0;
    double c = cos(angle), s = sin(angle);
    double rootX = bx + c * rootLX - s * rootLY, rootY = by + s * rootLX + c * rootLY;
    double ddx = gx * dt * dt, ddy = gy * dt * dt, L = segment;
    double kBase = (stiffness > stand ? stiffness : stand) * 0.1;
    int nm1 = n - 1 > 1 ? n - 1 : 1;
    for (int step = 0; step < steps; step++) {
        p[0] = rootX; p[1] = rootY; q[0] = rootX; q[1] = rootY;
        for (int i = 1; i < n; i++) { // point i + 1 (1-based)
            double x = p[2 * i], y = p[2 * i + 1];
            p[2 * i] = x + (x - q[2 * i]) * damping + ddx;
            p[2 * i + 1] = y + (y - q[2 * i + 1]) * damping + ddy;
            q[2 * i] = x; q[2 * i + 1] = y;
        }
        double dirX = cos(restAngle + angle), dirY = sin(restAngle + angle);
        for (int i = 2; i <= n; i++) { // 1-based, as in the Lua
            int ix = 2 * i - 2, iy = 2 * i - 1;
            double px = p[ix - 2], py = p[iy - 2];
            if (i > 2) {
                double bc = cos(bends[i]), bs = sin(bends[i]);
                double nx = dirX * bc - dirY * bs, ny = dirX * bs + dirY * bc;
                dirX = nx; dirY = ny;
            }
            double fade = 1.0 - (1.0 - stand) * (double)(i - 2) / (double)nm1;
            double k = kBase * fade * fade;
            double tx = px + dirX * L, ty = py + dirY * L;
            double x = p[ix] + (tx - p[ix]) * k, y = p[iy] + (ty - p[iy]) * k;
            double ex = x - px, ey = y - py;
            double len = sqrt(ex * ex + ey * ey);
            if (len > 1e-6) {
                double want = L;
                if (springy > 0 && drape) {
                    want = len + (L - len) * (1.0 - springy * 0.85);
                    if (want > L * 1.8) want = L * 1.8;
                    if (want < L * 0.9) want = L * 0.9;
                }
                x = px + ex / len * want;
                y = py + ey / len * want;
            }
            if (i > 2 && hasOval && drape) { // out of the head
                double dx = x - bx, dy = y - by;
                double lx = c * dx + s * dy, ly = -s * dx + c * dy;
                double d = (lx / ovalX) * (lx / ovalX) + (ly / ovalY) * (ly / ovalY);
                if (d < 1.0) {
                    double f = 1.0 / sqrt(d > 1e-6 ? d : 1e-6);
                    lx *= f; ly *= f;
                    x = bx + c * lx - s * ly;
                    y = by + s * lx + c * ly;
                }
            }
            if (i > 2) {
                q[ix - 2] += (x - p[ix]) * DFTL;
                q[iy - 2] += (y - p[iy]) * DFTL;
            }
            if (hasGround && y > groundY - GROUND_GAP) {
                y = groundY - GROUND_GAP;
                q[ix] = x - (x - q[ix]) * 0.5;
                q[iy] = y;
            }
            p[ix] = x; p[iy] = y;
        }
    }
    return 1;
}
