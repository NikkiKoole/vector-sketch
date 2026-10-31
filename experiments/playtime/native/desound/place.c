// place.c — a spike (claudetools/drawcall-bench, case E): a Mipo's part vertices, kept in their
// body's frame, moved to where the bodies are now, in one call, into a ByteData for one
// Mesh:setVertices and one draw per Mipo (docs/MIPO-DRAWING.md L2 "laid in C").
#include <math.h>

#define PLACE_MAX_BODIES 64

// local: nVerts x { x, y, u, v } in their body's frame; bodyOf: each vertex's body (0-based);
// bodies: nBodies x { x, y, angle }; out: nVerts x { x, y, u, v } in the world.
// Returns nVerts, or 0 when there are too many bodies.
int place_vertices(const float *local, const unsigned short *bodyOf, int nVerts,
                   const float *bodies, int nBodies, float *out) {
    if (nBodies > PLACE_MAX_BODIES) return 0;
    float bx[PLACE_MAX_BODIES], by[PLACE_MAX_BODIES], bc[PLACE_MAX_BODIES], bs[PLACE_MAX_BODIES];
    for (int b = 0; b < nBodies; b++) {
        bx[b] = bodies[3 * b];
        by[b] = bodies[3 * b + 1];
        bc[b] = cosf(bodies[3 * b + 2]);
        bs[b] = sinf(bodies[3 * b + 2]);
    }
    for (int i = 0; i < nVerts; i++) {
        int b = bodyOf[i];
        const float *l = local + 4 * i;
        float *o = out + 4 * i;
        o[0] = bx[b] + l[0] * bc[b] - l[1] * bs[b];
        o[1] = by[b] + l[0] * bs[b] + l[1] * bc[b];
        o[2] = l[2];
        o[3] = l[3];
    }
    return nVerts;
}
