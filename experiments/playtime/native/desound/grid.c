// grid.c — a bent picture's grid in one call (src/spine-skin.lua drawGrid): the same maths as
// spineSkin.deform (a spine torso: bands between the bones' middles) and earBend.deform (an
// ear: the base where the ear is at rest on the head, the top on the ear body). The picture's
// rectangle gets a cols x rows grid (bilinear between its corners), each point is bent, and the
// grid is written as { x, y, u, v } floats ((cols + 1) * (rows + 1) vertices, row by row) for
// Mesh:setVertices(ByteData). Body transforms come in as { x, y, angle }: read once in Lua,
// where Lua called getWorldPoint/getLocalPoint three times a point.
#include <math.h>

#define GRID_MAX_BONES 32

static double smoothstep(double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    return t * t * (3 - 2 * t);
}

// the rest point of grid vertex (c, r): bilinear over the corners (x1 y1 .. x4 y4: top edge
// 1 -> 2, bottom edge 4 -> 3)
static void rest_point(const float *k, int c, int r, int cols, int rows, double *x, double *y) {
    double u = (double)c / cols, v = (double)r / rows;
    double tx = k[0] + (k[2] - k[0]) * u, ty = k[1] + (k[3] - k[1]) * u;
    double bx = k[6] + (k[4] - k[6]) * u, by = k[7] + (k[5] - k[7]) * u;
    *x = tx + (bx - tx) * v;
    *y = ty + (by - ty) * v;
}

// a body's transform: { x, y, angle } -> x, y, cos, sin
typedef struct { double x, y, c, s; } xform;
static xform xform_of(const float *t) {
    xform f = { t[0], t[1], cos(t[2]), sin(t[2]) };
    return f;
}
static void world_point(xform f, double lx, double ly, double *wx, double *wy) {
    *wx = f.x + f.c * lx - f.s * ly;
    *wy = f.y + f.s * lx + f.c * ly;
}
static void local_point(xform f, double wx, double wy, double *lx, double *ly) {
    double dx = wx - f.x, dy = wy - f.y;
    *lx = f.c * dx + f.s * dy;
    *ly = -f.s * dx + f.c * dy;
}

static void write_vertex(float *out, int i, double x, double y, int c, int r, int cols, int rows) {
    float *o = out + 4 * i;
    o[0] = (float)x; o[1] = (float)y;
    o[2] = (float)c / cols; o[3] = (float)r / rows;
}

// A spine torso. bones: nBones x { x, y, angle } (the first is the root, torso1, whose local
// space the grid is in); middles: each bone's band middle (torso1-local y). Returns the number
// of vertices written.
// One point (torso1-local at rest) bent over a spine's bones (f: their transforms), back in
// torso1's local space: the two bands around it, blended near their cut (spineSkin.deform).
static void bend_spine(const xform *f, const float *middles, int nBones, float blend, double x, double y,
                       double *lx, double *ly) {
    int a = 0;
    double w = 0;
    for (int j = 0; j < nBones - 1; j++) {
        double s = (y - middles[j]) / (middles[j + 1] - middles[j]);
        if (s >= 0 || j == 0) {
            a = j;
            w = smoothstep((s - 0.5) / blend + 0.5);
        }
    }
    if (nBones == 1) w = 0;
    int b = a + 1 < nBones ? a + 1 : nBones - 1;
    double ax, ay, bx, by;
    world_point(f[a], x, y - middles[a], &ax, &ay);
    world_point(f[b], x, y - middles[b], &bx, &by);
    local_point(f[0], ax + (bx - ax) * w, ay + (by - ay) * w, lx, ly);
}

int grid_spine(const float *corners, int cols, int rows, const float *bones, const float *middles,
               int nBones, float blend, float *out) {
    if (nBones < 1 || nBones > GRID_MAX_BONES || cols < 1 || rows < 1) return 0;
    xform f[GRID_MAX_BONES];
    for (int i = 0; i < nBones; i++) f[i] = xform_of(bones + 3 * i);
    int i = 0;
    for (int r = 0; r <= rows; r++) {
        for (int c = 0; c <= cols; c++, i++) {
            double x, y, lx, ly;
            rest_point(corners, c, r, cols, rows, &x, &y);
            bend_spine(f, middles, nBones, blend, x, y, &lx, &ly);
            write_vertex(out, i, lx, ly, c, r, cols, rows);
        }
    }
    return i;
}

// Any vertices ({ x, y, u, v }, `count` of them, torso1-local at rest: bodyhair's fan) bent over a
// spine the same way, into `out` (the same layout, u and v copied). nBones 1 copies them as
// they are. Returns the count.
int points_spine(const float *in, int count, const float *bones, const float *middles, int nBones,
                 float blend, float *out) {
    if (nBones < 1 || nBones > GRID_MAX_BONES || count < 0) return 0;
    xform f[GRID_MAX_BONES];
    for (int i = 0; i < nBones; i++) f[i] = xform_of(bones + 3 * i);
    for (int i = 0; i < count; i++) {
        const float *p = in + 4 * i;
        float *o = out + 4 * i;
        if (nBones == 1) {
            o[0] = p[0]; o[1] = p[1];
        } else {
            double lx, ly;
            bend_spine(f, middles, nBones, blend, p[0], p[1], &lx, &ly);
            o[0] = (float)lx; o[1] = (float)ly;
        }
        o[2] = p[2]; o[3] = p[3];
    }
    return count;
}

// Soft points' pushes (lobes, the drawn jiggle: src/torso-lobes.lua pushBuffer) added to
// `count` vertices of `stride` floats, x and y first. weights: count x nSoft (a vertex's row,
// already divided by their sum when over 1); offsets: nSoft x { ox, oy }.
void grid_push(float *out, int count, int stride, const float *weights, int nSoft, const float *offsets) {
    for (int v = 0; v < count; v++) {
        const float *w = weights + v * nSoft;
        double ox = 0, oy = 0;
        for (int i = 0; i < nSoft; i++) {
            if (w[i] > 0) {
                ox += w[i] * offsets[2 * i];
                oy += w[i] * offsets[2 * i + 1];
            }
        }
        out[v * stride] += (float)ox;
        out[v * stride + 1] += (float)oy;
    }
}

// An ear. ear, parent: { x, y, angle }; restAngle: the ear's angle against its parent at rest;
// anchor: the joint on the parent (parent-local), root: on the ear (ear-local); axis: up the
// ear (unit), length: root to the farthest corner along it; bendLength: earBend.bendLength.
int grid_ear(const float *corners, int cols, int rows, const float *ear, const float *parent,
             float restAngle, float anchorX, float anchorY, float rootX, float rootY,
             float axisX, float axisY, float length, float bendLength, float *out) {
    if (cols < 1 || rows < 1 || length <= 0) return 0;
    xform fe = xform_of(ear), fp = xform_of(parent);
    double rc = cos(restAngle), rs = sin(restAngle);
    int i = 0;
    for (int r = 0; r <= rows; r++) {
        for (int c = 0; c <= cols; c++, i++) {
            double x, y;
            rest_point(corners, c, r, cols, rows, &x, &y);
            // where it is on the ear body, and where it would be with the ear at rest
            double ex, ey, hx, hy, lx = x - rootX, ly = y - rootY, ox, oy;
            world_point(fe, x, y, &ex, &ey);
            world_point(fp, anchorX + lx * rc - ly * rs, anchorY + lx * rs + ly * rc, &hx, &hy);
            // 1 at the root (and below it), 0 from bendLength up
            double t = (lx * axisX + ly * axisY) / length;
            double w = 1 - smoothstep(t / bendLength);
            local_point(fe, ex + (hx - ex) * w, ey + (hy - ey) * w, &ox, &oy);
            write_vertex(out, i, ox, oy, c, r, cols, rows);
        }
    }
    return i;
}
