// fluid.c — Position-Based Fluid water for Playtime (src/fluid.lua, scene `waterjar`).
// A port of dreamengine's tools/carts/waterjar.c (Macklin & Müller's PBF, the Ten Minute Physics
// way): points fall, a density constraint pushes overpacked water apart until it reads as
// incompressible, a touch of XSPH viscosity smooths it, and cohesion only on fast water so a wave
// crest folds over instead of spraying. Differences from the cart:
//   - world px and a real tank: the tank is a body that turns (gravity stays down), its inside a
//     box the points are kept in (in the tank's frame, so a fast swing can't tunnel through a wall)
//   - Box2D shapes (Mipos, crates, the outside of the tank, the ground) push the points out and
//     get the push back as impulses, so the water carries and floats things
//   - neighbours from a hashed grid (the world has no screen-sized bounds)
// All arrays are 0-based and owned by the Lua side (FFI arrays), like cloth.c.
#include <math.h>
#include <stdint.h>
#include <stdlib.h>

typedef struct {
    int n, maxn, maxnbr, nhead;
    float *x, *y, *px, *py;
    float *lam, *dpx, *dpy, *vlx, *vly;
    int *nbr, *nbrN, *cnext, *head;
    uint8_t *inTank;
    float h, pr, rho0, eps;
    float gx, gy, damp, visc, vmax, maxdp, cmin, cohLo, cohHi;
    int iters;
    int hasTank;
    float tx, ty, tcos, tsin, thw, tdepth, trest, tfric;
    float mass;
    int hasFloor;
    float floorY;
} FluidSim;

#define SHAPE_STRIDE 24 // type, vx, vy, w, cx, cy, flags, nv | circle x, y, r | poly verts (8 max)
#define FLAG_DYNAMIC 1
#define FLAG_TANK 2

static float KP, KS, WDQ, H2;

static void kernels(FluidSim *f) {
    float h = f->h, h5 = h * h * h * h * h, h8 = h5 * h * h * h;
    KP = 4.0f / (3.14159265f * h8);
    KS = 30.0f / (3.14159265f * h5);
    H2 = h * h;
    float q = 0.2f * h;
    float d = H2 - q * q;
    WDQ = KP * d * d * d;
}

static inline float poly6(float r2) {
    if (r2 >= H2) return 0.0f;
    float d = H2 - r2;
    return KP * d * d * d;
}

static inline float spikyG(float r, float h) {
    if (r >= h || r < 0.0001f) return 0.0f;
    float d = h - r;
    return -KS * d * d / r;
}

static inline int cellOf(float v, float h) { return (int)floorf(v / h); }

static inline int bucket(int gx, int gy, int mask) {
    uint32_t k = (uint32_t)gx * 92837111u ^ (uint32_t)gy * 689287499u;
    return (int)(k & (uint32_t)mask);
}

static void neighbours(FluidSim *f) {
    int mask = f->nhead - 1, n = f->n, M = f->maxnbr;
    float h = f->h;
    for (int c = 0; c < f->nhead; c++) f->head[c] = -1;
    for (int i = 0; i < n; i++) {
        int b = bucket(cellOf(f->x[i], h), cellOf(f->y[i], h), mask);
        f->cnext[i] = f->head[b];
        f->head[b] = i;
    }
    for (int i = 0; i < n; i++) {
        int gx = cellOf(f->x[i], h), gy = cellOf(f->y[i], h);
        int seen[9], ns = 0, cnt = 0;
        float xi = f->x[i], yi = f->y[i];
        for (int oy = -1; oy <= 1; oy++)
            for (int ox = -1; ox <= 1; ox++) {
                int b = bucket(gx + ox, gy + oy, mask), dup = 0;
                for (int s = 0; s < ns; s++) if (seen[s] == b) { dup = 1; break; }
                if (dup) continue;
                seen[ns++] = b;
                for (int j = f->head[b]; j >= 0 && cnt < M; j = f->cnext[j]) {
                    if (j == i) continue;
                    float dx = xi - f->x[j], dy = yi - f->y[j];
                    if (dx * dx + dy * dy < H2) f->nbr[i * M + cnt++] = j;
                }
            }
        f->nbrN[i] = cnt;
    }
}

static float densityAt(FluidSim *f, int i) {
    float rho = poly6(0.0f);
    int M = f->maxnbr;
    for (int k = 0; k < f->nbrN[i]; k++) {
        int j = f->nbr[i * M + k];
        float dx = f->x[i] - f->x[j], dy = f->y[i] - f->y[j];
        rho += poly6(dx * dx + dy * dy);
    }
    return rho;
}

static void clampSpeed(FluidSim *f, int i) {
    float vx = f->x[i] - f->px[i], vy = f->y[i] - f->py[i];
    float sp = sqrtf(vx * vx + vy * vy);
    if (sp > f->vmax) {
        float s = f->vmax / sp;
        f->px[i] = f->x[i] - vx * s;
        f->py[i] = f->y[i] - vy * s;
    }
}

// The tank's inside, in its own frame: origin on the floor's middle, x along it, y down; the inside
// is |x| < thw, -tdepth < y < 0, open at the top. A point that was inside (its previous position,
// in the tank's frame now) is kept inside: phys_bounds in the tank's frame.
static void tankLocal(FluidSim *f, float x, float y, float *lx, float *ly) {
    float dx = x - f->tx, dy = y - f->ty;
    *lx = dx * f->tcos + dy * f->tsin;
    *ly = -dx * f->tsin + dy * f->tcos;
}
static void tankWorld(FluidSim *f, float lx, float ly, float *x, float *y) {
    *x = f->tx + lx * f->tcos - ly * f->tsin;
    *y = f->ty + lx * f->tsin + ly * f->tcos;
}

static void markInTank(FluidSim *f) {
    for (int i = 0; i < f->n; i++) {
        f->inTank[i] = 0;
        if (!f->hasTank) continue;
        float lx, ly;
        tankLocal(f, f->px[i], f->py[i], &lx, &ly);
        f->inTank[i] = (fabsf(lx) < f->thw && ly > -f->tdepth) ? 1 : 0;
    }
}

// a flat floor (a beach): kept above it, rubbing off speed along it like the tank's floor
static void keepAboveFloor(FluidSim *f, int i) {
    if (!f->hasFloor) return;
    float y1 = f->floorY - f->pr;
    if (f->y[i] > y1) {
        float v = f->y[i] - f->py[i];
        f->y[i] = y1;
        f->py[i] = y1 + v * f->trest;
        float vx = f->x[i] - f->px[i];
        f->px[i] = f->x[i] - vx * f->tfric;
    }
}

static void keepInTank(FluidSim *f, int i) {
    if (!f->inTank[i]) return;
    float x, y, px, py, r = f->pr, v;
    tankLocal(f, f->x[i], f->y[i], &x, &y);
    tankLocal(f, f->px[i], f->py[i], &px, &py);
    int hit = 0;
    float x0 = -f->thw + r, x1 = f->thw - r, y1 = -r;
    if (x < x0) { v = x - px; x = x0; px = x + v * f->trest; hit = 1; }
    if (x > x1) { v = x - px; x = x1; px = x + v * f->trest; hit = 1; }
    if (y > y1) { v = y - py; y = y1; py = y + v * f->trest; float vx = x - px; px = x - vx * f->tfric; hit = 1; }
    if (!hit) return;
    tankWorld(f, x, y, &f->x[i], &f->y[i]);
    tankWorld(f, px, py, &f->px[i], &f->py[i]);
}

// Push point i out of the shapes; what that does to its speed goes back to the shape's body.
static void collideShapes(FluidSim *f, int i, const float *S, int ns, float *J) {
    float r = f->pr;
    for (int s = 0; s < ns; s++) {
        const float *o = S + s * SHAPE_STRIDE;
        int flags = (int)o[6];
        if ((flags & FLAG_TANK) && f->inTank[i]) continue;
        float x = f->x[i], y = f->y[i];
        float ox = 0, oy = 0;
        int hit = 0;
        if (o[0] < 0.5f) {
            float dx = x - o[7], dy = y - o[8], rr = o[9] + r, d2 = dx * dx + dy * dy;
            if (d2 < rr * rr && d2 > 1e-6f) {
                float d = sqrtf(d2), depth = rr - d;
                ox = dx / d * depth; oy = dy / d * depth; hit = 1;
            }
        } else {
            int nv = (int)o[7];
            float best = 1e30f, bnx = 0, bny = 0;
            int inside = 1;
            for (int k = 0; k < nv; k++) {
                int k2 = (k + 1) % nv;
                float ax = o[8 + k * 2], ay = o[9 + k * 2];
                float ex = o[8 + k2 * 2] - ax, ey = o[9 + k2 * 2] - ay;
                float el = sqrtf(ex * ex + ey * ey);
                if (el <= 0) continue;
                float nx = ey / el, ny = -ex / el;
                float depth = r - ((x - ax) * nx + (y - ay) * ny);
                if (depth <= 0) { inside = 0; break; }
                if (depth < best) { best = depth; bnx = nx; bny = ny; }
            }
            if (inside && best < 1e29f) { ox = bnx * best; oy = bny * best; hit = 1; }
        }
        if (!hit) continue;
        float len = sqrtf(ox * ox + oy * oy);
        if (len < 1e-6f) continue;
        float nx = ox / len, ny = oy / len;
        // the body's speed where the point is (px a frame)
        float bvx = o[1] - o[3] * (y - o[5]), bvy = o[2] + o[3] * (x - o[4]);
        float vx = x - f->px[i], vy = y - f->py[i];
        float rx = vx - bvx, ry = vy - bvy;
        float vn = rx * nx + ry * ny;
        if (vn < 0) { rx -= vn * nx; ry -= vn * ny; }
        rx *= 0.92f; ry *= 0.92f;
        float qx = x + ox, qy = y + oy;
        f->x[i] = qx; f->y[i] = qy;
        f->px[i] = qx - (bvx + rx);
        f->py[i] = qy - (bvy + ry);
        if (flags & FLAG_DYNAMIC) {
            // the point's change of speed, the other way, on the body
            float dvx = (bvx + rx) - vx, dvy = (bvy + ry) - vy;
            float jx = -dvx * f->mass, jy = -dvy * f->mass;
            J[s * 3] += jx;
            J[s * 3 + 1] += jy;
            J[s * 3 + 2] += (qx - o[4]) * jy - (qy - o[5]) * jx;
        }
    }
}

int fluid_step(FluidSim *f, const float *shapes, int nshapes, float *impulses) {
    int n = f->n, M = f->maxnbr;
    if (n == 0) return 0;
    kernels(f);
    for (int s = 0; s < nshapes * 3; s++) impulses[s] = 0;
    markInTank(f);

    // 1) predict
    for (int i = 0; i < n; i++) {
        float vx = (f->x[i] - f->px[i]) * f->damp, vy = (f->y[i] - f->py[i]) * f->damp;
        f->px[i] = f->x[i]; f->py[i] = f->y[i];
        f->x[i] += vx + f->gx; f->y[i] += vy + f->gy;
        clampSpeed(f, i);
    }
    // 2) neighbours, once a step
    neighbours(f);
    // 3) the density solve
    float rho0 = f->rho0, h = f->h;
    for (int it = 0; it < f->iters; it++) {
        for (int i = 0; i < n; i++) {
            float C = densityAt(f, i) / rho0 - 1.0f;
            float vx = f->x[i] - f->px[i], vy = f->y[i] - f->py[i];
            float sp = sqrtf(vx * vx + vy * vy);
            float t = (sp - f->cohLo) / (f->cohHi - f->cohLo);
            t = t < 0 ? 0 : (t > 1 ? 1 : t);
            float coh = f->cmin * t;
            if (C < coh) C = coh;
            float gxi = 0, gyi = 0, sumk = 0;
            for (int k = 0; k < f->nbrN[i]; k++) {
                int j = f->nbr[i * M + k];
                float dx = f->x[i] - f->x[j], dy = f->y[i] - f->y[j], r = sqrtf(dx * dx + dy * dy);
                float gc = spikyG(r, h);
                float gjx = gc * dx / rho0, gjy = gc * dy / rho0;
                gxi += gjx; gyi += gjy;
                sumk += gjx * gjx + gjy * gjy;
            }
            f->lam[i] = -C / (gxi * gxi + gyi * gyi + sumk + f->eps);
        }
        for (int i = 0; i < n; i++) {
            float cx = 0, cy = 0;
            for (int k = 0; k < f->nbrN[i]; k++) {
                int j = f->nbr[i * M + k];
                float dx = f->x[i] - f->x[j], dy = f->y[i] - f->y[j], r = sqrtf(dx * dx + dy * dy);
                float coef = (f->lam[i] + f->lam[j]) / rho0 * spikyG(r, h);
                cx += coef * dx; cy += coef * dy;
            }
            float m = sqrtf(cx * cx + cy * cy);
            if (m > f->maxdp) { float s = f->maxdp / m; cx *= s; cy *= s; }
            f->dpx[i] = cx; f->dpy[i] = cy;
        }
        for (int i = 0; i < n; i++) {
            f->x[i] += f->dpx[i]; f->y[i] += f->dpy[i];
            collideShapes(f, i, shapes, nshapes, impulses);
            keepInTank(f, i);
            keepAboveFloor(f, i);
        }
    }
    // 4) XSPH viscosity
    for (int i = 0; i < n; i++) { f->vlx[i] = f->x[i] - f->px[i]; f->vly[i] = f->y[i] - f->py[i]; }
    for (int i = 0; i < n; i++) {
        float ax = 0, ay = 0;
        for (int k = 0; k < f->nbrN[i]; k++) {
            int j = f->nbr[i * M + k];
            float dx = f->x[i] - f->x[j], dy = f->y[i] - f->y[j];
            float w = poly6(dx * dx + dy * dy) / rho0;
            ax += (f->vlx[j] - f->vlx[i]) * w; ay += (f->vly[j] - f->vly[i]) * w;
        }
        f->px[i] -= f->visc * ax; f->py[i] -= f->visc * ay;
    }
    // 5) speed limit
    for (int i = 0; i < n; i++) clampSpeed(f, i);
    return n;
}

static int cmpFloat(const void *a, const void *b) {
    float x = *(const float *)a, y = *(const float *)b;
    return (x > y) - (x < y);
}

// the rest density: the densest point now (mode 0) or the median (mode 1, of a settled pack)
float fluid_rest_density(FluidSim *f, int mode) {
    if (f->n == 0) return 1;
    kernels(f);
    neighbours(f);
    for (int i = 0; i < f->n; i++) f->lam[i] = densityAt(f, i);
    if (mode == 0) {
        float m = 0;
        for (int i = 0; i < f->n; i++) if (f->lam[i] > m) m = f->lam[i];
        return m > 0 ? m : poly6(0);
    }
    qsort(f->lam, f->n, sizeof(float), cmpFloat);
    return f->lam[f->n / 2];
}

// drop the points outside the box (fallen off the world); returns how many are left
int fluid_cull(FluidSim *f, float minx, float miny, float maxx, float maxy) {
    int n = f->n;
    for (int i = n - 1; i >= 0; i--) {
        if (f->x[i] < minx || f->x[i] > maxx || f->y[i] < miny || f->y[i] > maxy) {
            n--;
            f->x[i] = f->x[n]; f->y[i] = f->y[n]; f->px[i] = f->px[n]; f->py[i] = f->py[n];
        }
    }
    f->n = n;
    return n;
}
