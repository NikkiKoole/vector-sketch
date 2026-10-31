// ribbon.c — a limb ribbon's vertices in one call (src/ribbon-native.lua), the same maths as
// src/physics/box2d-draw-textured.lua's shapeRibbon + src/render/ribbon.lua's texturedCurve:
// grow both ends, double the middle control points, sample the Bezier `segments` times,
// half-width clamped at sharp bends, written as a triangle strip of
// { x, y, u, v } floats (2 vertices a sample) for Mesh:setVertices(ByteData).
// Built into libdesound with the synth (build.sh, build-ios.sh): one native library.
#include <math.h>

#define RIBBON_MAX_POINTS 64

// Bezier point and derivative at t, de Casteljau (as love.math's BezierCurve evaluates).
static void bezier_at(const double *px, const double *py, int n, double t,
                      double *x, double *y, double *dx, double *dy) {
    double ax[RIBBON_MAX_POINTS], ay[RIBBON_MAX_POINTS];
    for (int i = 0; i < n; i++) { ax[i] = px[i]; ay[i] = py[i]; }
    // the derivative is the curve through n-1 points (n-1)(P[i+1]-P[i]); its value at t is
    // (n-1) times the difference of the last two de Casteljau points
    for (int k = n - 1; k > 0; k--) {
        if (k == 1) {
            *dx = (n - 1) * (ax[1] - ax[0]);
            *dy = (n - 1) * (ay[1] - ay[0]);
        }
        for (int i = 0; i < k; i++) {
            ax[i] = ax[i] + (ax[i + 1] - ax[i]) * t;
            ay[i] = ay[i] + (ay[i + 1] - ay[i]) * t;
        }
    }
    *x = ax[0];
    *y = ay[0];
    if (n == 1) { *dx = 0; *dy = 0; }
}

static void grow_line(double *x1, double *y1, double x2, double y2, double length) {
    double dx = *x1 - x2, dy = *y1 - y2;
    double inv = 1.0 / (sqrt(dx * dx + dy * dy) + 1e-12);
    *x1 += length * dx * inv;
    *y1 += length * dy * inv;
}

// nodes: nNodes (x, y) pairs, the anchors. Returns the number of vertices written to `out`
// (2 * segments), or 0 when there is no curve (fewer than 2 nodes, too many).
int ribbon_strip(const float *nodes, int nNodes, float grow, int bendiness, int segments,
                 float halfWidth, float shift, int miterClamp, float *out) {
    double px[RIBBON_MAX_POINTS], py[RIBBON_MAX_POINTS];
    int n = 0;
    if (nNodes == 2) { // a curve needs 3 points: the middle one added
        px[0] = nodes[0]; py[0] = nodes[1];
        px[1] = (nodes[0] + nodes[2]) / 2.0; py[1] = (nodes[1] + nodes[3]) / 2.0;
        px[2] = nodes[2]; py[2] = nodes[3];
        n = 3;
    } else {
        if (nNodes < 3) return 0;
        for (int i = 0; i < nNodes; i++) { px[i] = nodes[2 * i]; py[i] = nodes[2 * i + 1]; }
        n = nNodes;
    }
    // shapeRibbon grows the first point away from the second and the THIRD from the second
    // (points[5], points[6]): the last point only when there are three
    grow_line(&px[0], &py[0], px[1], py[1], grow);
    grow_line(&px[2], &py[2], px[1], py[1], grow);

    // doubleControlPoints: each middle point written `bendiness` more times
    double cx[RIBBON_MAX_POINTS], cy[RIBBON_MAX_POINTS];
    int m = 0;
    for (int i = 0; i < n; i++) {
        int copies = (i > 0 && i < n - 1 && n > 2 && bendiness > 0) ? 1 + bendiness : 1;
        for (int c = 0; c < copies; c++) {
            if (m >= RIBBON_MAX_POINTS) return 0;
            cx[m] = px[i]; cy[m] = py[i]; m++;
        }
    }

    if (segments < 2 || segments > 256) return 0;
    double sx[256], sy[256], tx[256], ty[256];
    const double eps = 1e-12;
    int segMinus1 = segments - 1;
    for (int p = 0; p < segments; p++) {
        double t = (double)p / segMinus1, x, y, dx, dy;
        bezier_at(cx, cy, m, t, &x, &y, &dx, &dy);
        double invlen = 1.0 / sqrt(dx * dx + dy * dy + eps);
        sx[p] = x; sy[p] = y; tx[p] = dx * invlen; ty[p] = dy * invlen;
    }

    double absHW = halfWidth < 0 ? -halfWidth : halfWidth;
    double signHW = halfWidth < 0 ? -1 : 1;
    for (int p = 0; p < segments; p++) {
        double x = sx[p], y = sy[p];
        double nx = -ty[p], ny = tx[p];
        double hw = absHW;
        if (miterClamp && p > 0 && p < segments - 1) {
            double ax = x - sx[p - 1], ay = y - sy[p - 1];
            double bx = sx[p + 1] - x, by = sy[p + 1] - y;
            double la = sqrt(ax * ax + ay * ay), lb = sqrt(bx * bx + by * by);
            if (la > eps && lb > eps) {
                double dot = (ax * bx + ay * by) / (la * lb);
                if (dot < 0.9999) {
                    if (dot < -1) dot = -1; else if (dot > 1) dot = 1;
                    double alpha = (M_PI - acos(dot)) * 0.5;
                    double maxHw = (la < lb ? la : lb) * tan(alpha);
                    if (maxHw < hw) hw = maxHw;
                }
            }
        }
        hw *= signHW;
        double v = segMinus1 > 0 ? (double)p / segMinus1 : 0;
        float *o = out + p * 8;
        o[0] = (float)(x + (hw + shift) * nx); o[1] = (float)(y + (hw + shift) * ny);
        o[2] = 0; o[3] = (float)v;
        o[4] = (float)(x - (hw - shift) * nx); o[5] = (float)(y - (hw - shift) * ny);
        o[6] = 1; o[7] = (float)v;
    }
    return segments * 2;
}
