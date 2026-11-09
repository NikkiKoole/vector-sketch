// hair.c — a hair lock's strip in one call (src/hair-native.lua), the same maths as
// src/hair-locks.lua's lockPath + stripMesh: a Catmull-Rom curve through the lock's points
// (samples per segment by how sharply it turns, or ~10 a ringlet turn or wave), for ringlets a
// corkscrew around it seen a little from above (its back half darker), for curly hair a wave
// across it, then a strip the
// picture's width across, written as { x, y, u, v, r, g, b, a } floats (2 vertices a sample)
// for Mesh:setVertices(ByteData). Built into libdesound with the synth (build.sh, build-ios.sh).
#include <math.h>

#define HAIR_MAX_SAMPLES 400

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
        int per = ringPer;
        if (!per) {
            double ax = x1 - x0, ay = y1 - y0, bx = x2 - x1, by = y2 - y1, cx = x3 - x2, cy = y3 - y2;
            double la = ax * ax + ay * ay, lb = bx * bx + by * by, lc = cx * cx + cy * cy;
            double turn = 0;
            if (la > 1e-9 && lb > 1e-9) {
                double t = 1 - (ax * bx + ay * by) / sqrt(la * lb);
                if (t > turn) turn = t;
            }
            if (lb > 1e-9 && lc > 1e-9) {
                double t = 1 - (bx * cx + by * cy) / sqrt(lb * lc);
                if (t > turn) turn = t;
            }
            per = 1 + (int)floor(sqrt(2 * turn) / 0.15);
            if (per > maxPer) per = maxPer;
            if (per > 5) per = 5;
        }
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
    // the strip
    double hw = halfWidth;
    for (int c = 0; c < count; c++) {
        double tx, ty;
        unit_tangent(c, count, &tx, &ty);
        double v = count > 1 ? (double)c / (count - 1) : 0;
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
