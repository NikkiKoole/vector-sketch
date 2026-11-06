// cloth.c — the cloth step and its mesh in C (src/cloth.lua, docs/CLOTH.md). The same as the Lua
// path in src/cloth.lua.
//
// The points move in 3D (after Müller's Ten Minute Physics #14, "the secret of cloth simulation"):
// a curtain seen face-on folds toward and away from you; kept in the screen's plane it could only
// bunch up flat (it looked like sticky tape). Many small steps, sides that don't stretch, soft
// bending, almost no damping, real gravity. Box2D bodies are slabs `depth` thick in z (static ones
// endlessly deep), so a Mipo walking into a curtain pushes it out toward you, over itself. Wind
// pushes on the cloth's surface (how much air hits it, by its normal), which is what makes flags
// flap. Drawn flat with a touch of perspective, lit by its 3D normals.
//
// Every array is 1-based (index 0 unused), so Lua reads the same arrays with c.x[i].

#include <math.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    int n, cols, rows, nc;
    float *x, *y, *z, *px, *py, *pz, *inv, *pinx, *piny, *railY;
    float *sx, *sy;           // where each point is drawn (projected)
    uint8_t *rail;            // 1: this point slides on the rail
    int *ca, *cb;
    float *cr, *ck;
    uint8_t *alive, *structural;
    uint8_t *quad;            // the cell right-below this point is whole
    uint8_t *scratch;         // 2n+2 bytes for the outline walk
    float railMin, railMax;
    int grabbed;
    float grabX, grabY;
    float gravity, wind, gust, damping, thickness, time, tear;
    int iterations;
    float flutter;            // how fast the wind's gusts move over the cloth (1: brisk)
    float drag;               // how much the air holds the cloth (1/s)
    float lift;               // how much the wind pushes on the cloth's face (1/s)
    float perspective;        // drawn size per px of z toward you
    float cx, cy;             // the centre of the perspective
} Cloth;

// ------------------------------------------------------------------ wind noise (value noise, 0..1)

static float hash3(int x, int y, int z) {
    uint32_t h = (uint32_t)x * 374761393u + (uint32_t)y * 668265263u + (uint32_t)z * 2246822519u;
    h = (h ^ (h >> 13)) * 1274126177u;
    return (float)((h ^ (h >> 16)) & 0xffffff) / 16777215.0f;
}

static float smooth(float t) { return t * t * (3.0f - 2.0f * t); }

static float noise3(float x, float y, float z) {
    int ix = (int)floorf(x), iy = (int)floorf(y), iz = (int)floorf(z);
    float fx = smooth(x - ix), fy = smooth(y - iy), fz = smooth(z - iz);
    float v[2];
    for (int k = 0; k < 2; k++) {
        float a = hash3(ix, iy, iz + k), b = hash3(ix + 1, iy, iz + k);
        float c = hash3(ix, iy + 1, iz + k), d = hash3(ix + 1, iy + 1, iz + k);
        float ab = a + (b - a) * fx, cd = c + (d - c) * fx;
        v[k] = ab + (cd - ab) * fy;
    }
    return v[0] + (v[1] - v[0]) * fz;
}

// ------------------------------------------------------------------ normals

// a point's normal from its neighbours across and down
static void normalAt(const Cloth *c, int i, float *nx, float *ny, float *nz) {
    int cols = c->cols, col = (i - 1) % cols, r = (i - 1) / cols;
    int l = col > 0 ? i - 1 : i, rt = col < cols - 1 ? i + 1 : i;
    int u = r > 0 ? i - cols : i, d = r < c->rows - 1 ? i + cols : i;
    float ax = c->x[rt] - c->x[l], ay = c->y[rt] - c->y[l], az = c->z[rt] - c->z[l];
    float bx = c->x[d] - c->x[u], by = c->y[d] - c->y[u], bz = c->z[d] - c->z[u];
    float x = ay * bz - az * by, y = az * bx - ax * bz, z = ax * by - ay * bx;
    float len = sqrtf(x * x + y * y + z * z);
    if (len < 1e-6f) { *nx = 0; *ny = 0; *nz = 1; return; }
    *nx = x / len; *ny = y / len; *nz = z / len;
}

// ------------------------------------------------------------------ collision

// A shape Lua hands over, SHAPE_STRIDE floats:
//   0 type (0 circle, 1 polygon)   1 vx  2 vy  3 w  4 cx  5 cy (the body's motion, about its centre)
//   circle: 6 x  7 y  8 r          polygon: 6 nv, 7..22 the points in the world, counter-clockwise
//   23: its half thickness in z (0: endless, the ground)
#define SHAPE_STRIDE 24
#define COLLIDE_MAX_PUSH 3.0f    // px a substep a point is moved out of a shape
#define COLLIDE_FRICTION 0.3f    // of the speed along a surface, lost a 1/60 (spread over the substeps)

static void collide(Cloth *c, float H, const float *shapes, int nshapes, float *impulses) {
    float th = c->thickness;
    float keep = powf(1 - COLLIDE_FRICTION, H * 60);
    float *acc = calloc((size_t)(c->n + 1) * 6, sizeof(float)); // push x, y, z, surface dx, dy, count
    if (!acc) return;
    for (int s = 0; s < nshapes; s++) {
        const float *sh = shapes + s * SHAPE_STRIDE;
        int poly = sh[0] > 0.5f;
        float half = sh[23];
        float minx, miny, maxx, maxy;
        int nv = 0;
        if (poly) {
            nv = (int)sh[6];
            minx = maxx = sh[7]; miny = maxy = sh[8];
            for (int k = 1; k < nv; k++) {
                float vx = sh[7 + k * 2], vy = sh[8 + k * 2];
                if (vx < minx) minx = vx;
                if (vx > maxx) maxx = vx;
                if (vy < miny) miny = vy;
                if (vy > maxy) maxy = vy;
            }
        } else {
            minx = sh[6] - sh[8]; maxx = sh[6] + sh[8];
            miny = sh[7] - sh[8]; maxy = sh[7] + sh[8];
        }
        minx -= th; miny -= th; maxx += th; maxy += th;
        float jx = 0, jy = 0;
        for (int i = 1; i <= c->n; i++) {
            float x = c->x[i], y = c->y[i], z = c->z[i];
            if (c->inv[i] <= 0 || x < minx || x > maxx || y < miny || y > maxy) continue;
            float zdepth = 1e30f;
            if (half > 0) {
                zdepth = half + th - fabsf(z);
                if (zdepth <= 0) continue; // in front of it or behind it
            }
            float ox = 0, oy = 0, dxy = 0;
            int hit = 0;
            if (!poly) {
                float r = sh[8] + th, dx = x - sh[6], dy = y - sh[7];
                float d2 = dx * dx + dy * dy;
                if (d2 < r * r && d2 > 1e-6f) {
                    float d = sqrtf(d2);
                    dxy = r - d;
                    ox = dx / d * dxy; oy = dy / d * dxy;
                    hit = 1;
                }
            } else {
                // inside every edge (pushed out by th): out through the one it's least deep behind
                float best = 1e30f, bnx = 0, bny = 0;
                int inside = 1;
                for (int k = 0; k < nv; k++) {
                    int k2 = (k + 1) % nv;
                    float ax = sh[7 + k * 2], ay = sh[8 + k * 2];
                    float ex = sh[7 + k2 * 2] - ax, ey = sh[8 + k2 * 2] - ay;
                    float el = sqrtf(ex * ex + ey * ey);
                    if (el <= 0) continue;
                    float nx = ey / el, ny = -ex / el;
                    float depth = th - ((x - ax) * nx + (y - ay) * ny);
                    if (depth <= 0) { inside = 0; break; }
                    if (depth < best) { best = depth; bnx = nx; bny = ny; }
                }
                if (inside) { dxy = best; ox = bnx * best; oy = bny * best; hit = 1; }
            }
            if (!hit) continue;
            float oz = 0;
            if (zdepth < dxy) {
                // out the front or the back of the slab (the side it's on; the front when level)
                ox = 0; oy = 0;
                oz = (z >= 0 ? 1.0f : -1.0f) * zdepth;
            } else {
                jx -= ox; jy -= oy; // a sideways push is what holds the body back (Lua: drag)
            }
            // gathered, applied below as one: a point in several shapes at once (a Mipo's hand
            // over its leg) ping-ponged between them when each pushed it in turn
            float *a = acc + i * 6;
            a[0] += ox; a[1] += oy; a[2] += oz;
            a[3] += (sh[1] - sh[3] * (y - sh[5])) * H; // the surface's motion this step
            a[4] += (sh[2] + sh[3] * (x - sh[4])) * H;
            a[5] += 1;
        }
        impulses[s * 2] += jx;
        impulses[s * 2 + 1] += jy;
    }
    for (int i = 1; i <= c->n; i++) {
        float *a = acc + i * 6;
        float k = a[5];
        if (k <= 0) continue;
        float ox = a[0] / k, oy = a[1] / k, oz = a[2] / k;
        float bvx = a[3] / k, bvy = a[4] / k;
        // out a few px a step, not all at once: a point deep in a shape that came at it eases out
        float depth = sqrtf(ox * ox + oy * oy + oz * oz);
        if (depth <= 1e-6f) continue;
        float nx = ox / depth, ny = oy / depth, nz = oz / depth;
        if (depth > COLLIDE_MAX_PUSH) {
            ox = nx * COLLIDE_MAX_PUSH; oy = ny * COLLIDE_MAX_PUSH; oz = nz * COLLIDE_MAX_PUSH;
        }
        float x = c->x[i], y = c->y[i], z = c->z[i];
        // its speed against the surface's: what goes into it stops (no bounce), along it some is
        // lost (friction), so a hem lying on the floor comes to rest
        float rx = (x - c->px[i]) - bvx, ry = (y - c->py[i]) - bvy, rz = z - c->pz[i];
        float vn = rx * nx + ry * ny + rz * nz;
        if (vn < 0) { rx -= vn * nx; ry -= vn * ny; rz -= vn * nz; }
        rx *= keep; ry *= keep; rz *= keep;
        float qx = x + ox, qy = y + oy, qz = z + oz;
        c->x[i] = qx; c->y[i] = qy; c->z[i] = qz;
        c->px[i] = qx - (bvx + rx); c->py[i] = qy - (bvy + ry); c->pz[i] = qz - rz;
    }
    free(acc);
}

// ------------------------------------------------------------------ the step

static int step(Cloth *c, float H, float damp, const float *shapes, int nshapes, float *impulses) {
    int n = c->n, tears = 0;
    float *X = c->x, *Y = c->y, *Z = c->z, *PX = c->px, *PY = c->py, *PZ = c->pz, *inv = c->inv;
    c->time += H;
    float ft = c->time * c->flutter;
    float wind = c->wind, gust = c->gust;
    float swell = 1 - gust * 0.5f + gust * 0.5f * sinf(ft * 0.9f) * sinf(ft * 0.37f + 1.3f);
    float hh = H * H;
    for (int i = 1; i <= n; i++) {
        if (inv[i] <= 0) continue;
        float x = X[i], y = Y[i], z = Z[i];
        float vx = (x - PX[i]) * damp, vy = (y - PY[i]) * damp, vz = (z - PZ[i]) * damp;
        float ax = 0, ay = c->gravity, az = 0;
        // the air: the wind (gusty, uneven over the cloth, a little up/down and in/out) against
        // the point's own speed; along the cloth a little drag, on its face much more
        float wx = 0, wy = 0, wz = 0;
        if (wind != 0) {
            float w = noise3(x * 0.006f - ft * 1.7f, y * 0.006f, ft * 0.25f);
            wx = wind * swell * (1 - gust + gust * 2 * w);
            wy = fabsf(wind) * gust * 0.3f * (noise3(x * 0.01f, y * 0.01f - ft * 2.1f, 7.5f) - 0.5f);
            wz = fabsf(wind) * (0.15f + gust * 0.4f) * (noise3(x * 0.008f - ft * 1.3f, y * 0.008f, 3.1f) - 0.5f);
        }
        float rx = wx - vx / H, ry = wy - vy / H, rz = wz - vz / H; // the air past the point, px/s
        float nx, ny, nz;
        normalAt(c, i, &nx, &ny, &nz);
        float face = rx * nx + ry * ny + rz * nz;
        ax += c->drag * rx + c->lift * face * nx;
        ay += c->drag * ry + c->lift * face * ny;
        az += c->drag * rz + c->lift * face * nz;
        PX[i] = x; PY[i] = y; PZ[i] = z;
        X[i] = x + vx + ax * hh; Y[i] = y + vy + ay * hh; Z[i] = z + vz + az * hh;
    }
    for (int i = 1; i <= n; i++) {
        if (inv[i] == 0 && i != c->grabbed) { X[i] = c->pinx[i]; Y[i] = c->piny[i]; Z[i] = 0; }
    }
    for (int it = 0; it < c->iterations; it++) {
        for (int e = 1; e <= c->nc; e++) {
            if (!c->alive[e]) continue;
            int a = c->ca[e], b = c->cb[e];
            float wa = inv[a], wb = inv[b], w = wa + wb;
            if (w <= 0) continue;
            float dx = X[b] - X[a], dy = Y[b] - Y[a], dz = Z[b] - Z[a];
            float d = sqrtf(dx * dx + dy * dy + dz * dz);
            if (d <= 1e-6f) continue;
            float rest = c->cr[e];
            if (c->tear > 0 && d > rest * c->tear && c->structural[e]) {
                c->alive[e] = 0;
                tears++;
                continue;
            }
            float f = (d - rest) / d * c->ck[e] / w;
            X[a] += dx * f * wa; Y[a] += dy * f * wa; Z[a] += dz * f * wa;
            X[b] -= dx * f * wb; Y[b] -= dy * f * wb; Z[b] -= dz * f * wb;
        }
        for (int i = 1; i <= n; i++) {
            if (!c->rail[i]) continue;
            Y[i] = c->railY[i];
            Z[i] = 0;
            if (X[i] < c->railMin) X[i] = c->railMin; else if (X[i] > c->railMax) X[i] = c->railMax;
        }
        if (c->grabbed > 0) { X[c->grabbed] = c->grabX; Y[c->grabbed] = c->grabY; Z[c->grabbed] = 0; }
    }
    if (nshapes > 0) collide(c, H, shapes, nshapes, impulses);
    return tears;
}

// A frame (1/60) in `substeps` small steps. `impulses` (2 per shape) gets the sum of the pushes
// the shapes took; returns how many edges tore.
int cloth_frame(Cloth *c, float frame, int substeps, const float *shapes, int nshapes, float *impulses) {
    if (substeps < 1) substeps = 1;
    float H = frame / substeps;
    float damp = powf(c->damping, H / (1.0f / 60.0f));
    for (int s = 0; s < nshapes * 2; s++) impulses[s] = 0;
    int tears = 0;
    for (int k = 0; k < substeps; k++) tears += step(c, H, damp, shapes, nshapes, impulses);
    return tears;
}

// ------------------------------------------------------------------ the mesh

// the cells whose four sides are whole, into `quad` and as triangles (0-based vertex indices) in
// `map`; returns how many indices
int cloth_map(Cloth *c, const int *hEdge, const int *vEdge, uint32_t *map) {
    int cols = c->cols, rows = c->rows, k = 0;
    memset(c->quad, 0, (size_t)(c->n + 1));
    for (int r = 0; r < rows - 1; r++) {
        for (int col = 0; col < cols - 1; col++) {
            int i = r * cols + col + 1;
            if (!(c->alive[hEdge[i]] && c->alive[vEdge[i]] && c->alive[hEdge[i + cols]] && c->alive[vEdge[i + 1]]))
                continue;
            c->quad[i] = 1;
            uint32_t a = i - 1, b = i, d = i - 1 + cols, e = i + cols;
            map[k++] = a; map[k++] = b; map[k++] = e;
            map[k++] = a; map[k++] = e; map[k++] = d;
        }
    }
    return k;
}

typedef struct { float x, y, u, v; uint8_t r, g, b, a; } ClothVertex;

// Where each point is drawn (c->sx, c->sy: a touch bigger the nearer it is) and the vertices for
// Mesh:setVertices: `uv` (2 a point, 1-based), the tint lit by the point's normal (light from the
// top left, in front). `shade` 0: flat, 1: fully lit; a face turned to you is the fabric as drawn.
void cloth_vertices(Cloth *c, ClothVertex *out, const float *uv, float tr, float tg, float tb,
                    float shade, float spacing) {
    (void)spacing;
    const float lx = -0.35f, ly = -0.55f, lz = 0.76f; // normalised
    for (int i = 1; i <= c->n; i++) {
        float s = 1 + c->z[i] * c->perspective;
        if (s < 0.2f) s = 0.2f;
        c->sx[i] = c->cx + (c->x[i] - c->cx) * s;
        c->sy[i] = c->cy + (c->y[i] - c->cy) * s;
    }
    for (int i = 1; i <= c->n; i++) {
        float l = 1;
        if (shade > 0) {
            float nx, ny, nz;
            normalAt(c, i, &nx, &ny, &nz);
            if (nz < 0) { nx = -nx; ny = -ny; nz = -nz; } // the side you see
            float lam = nx * lx + ny * ly + nz * lz;
            if (lam < 0) lam = 0;
            l = 1 - shade + shade * (0.45f + 0.55f * lam / lz);
            if (l > 1.2f) l = 1.2f;
        }
        ClothVertex *v = &out[i - 1];
        v->x = c->sx[i]; v->y = c->sy[i];
        v->u = uv[i * 2]; v->v = uv[i * 2 + 1];
        float r = tr * l * 255, g = tg * l * 255, bl = tb * l * 255;
        v->r = (uint8_t)(r > 255 ? 255 : r); v->g = (uint8_t)(g > 255 ? 255 : g);
        v->b = (uint8_t)(bl > 255 ? 255 : bl); v->a = 255;
    }
}

// ------------------------------------------------------------------ the outline

// an edge of the cloth has a whole cell on one side only. Edge ids: 2i the one to the right of i,
// 2i+1 the one below it.
static int boundaryH(const Cloth *c, int i) {
    int col = (i - 1) % c->cols, r = (i - 1) / c->cols;
    if (col >= c->cols - 1) return 0;
    int above = r > 0 && c->quad[i - c->cols], below = r < c->rows - 1 && c->quad[i];
    return above != below;
}

static int boundaryV(const Cloth *c, int i) {
    int col = (i - 1) % c->cols, r = (i - 1) / c->cols;
    if (r >= c->rows - 1) return 0;
    int left = col > 0 && c->quad[i - 1], right = col < c->cols - 1 && c->quad[i];
    return left != right;
}

// an unused boundary edge at point i: returns the point at its other end (0: none), marks it used
static int nextEdge(Cloth *c, int i) {
    int cols = c->cols, col = (i - 1) % cols, r = (i - 1) / cols;
    uint8_t *used = c->scratch;
    if (col < cols - 1 && !used[2 * i] && boundaryH(c, i)) { used[2 * i] = 1; return i + 1; }
    if (col > 0 && !used[2 * (i - 1)] && boundaryH(c, i - 1)) { used[2 * (i - 1)] = 1; return i - 1; }
    if (r < c->rows - 1 && !used[2 * i + 1] && boundaryV(c, i)) { used[2 * i + 1] = 1; return i + cols; }
    if (r > 0 && !used[2 * (i - cols) + 1] && boundaryV(c, i - cols)) { used[2 * (i - cols) + 1] = 1; return i - cols; }
    return 0;
}

// The outline (drawn positions, after cloth_vertices) as polylines: [count, x1, y1, x2, y2, ...]
// one after another, at most maxFloats; returns how many floats were written.
int cloth_outline(Cloth *c, float *out, int maxFloats) {
    memset(c->scratch, 0, (size_t)(2 * c->n + 2));
    int k = 0;
    for (int start = 1; start <= c->n; start++) {
        int next = nextEdge(c, start);
        if (!next) continue;
        if (k + 5 > maxFloats) break;
        int head = k++;
        int count = 1;
        out[k++] = c->sx[start]; out[k++] = c->sy[start];
        int at = next;
        while (at && k + 2 <= maxFloats) {
            out[k++] = c->sx[at]; out[k++] = c->sy[at];
            count++;
            at = nextEdge(c, at);
        }
        out[head] = (float)count;
        start--; // more edges may leave this point (a pinch, or the far side of the walk)
    }
    return k;
}
