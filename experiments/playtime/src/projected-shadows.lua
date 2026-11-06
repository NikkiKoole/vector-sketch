-- projected-shadows.lua — hard shadows thrown in 3D: along a floor and up the wall behind
-- (docs/LIGHT-AND-SHADOW.md LS22). The wall shadow (src/backdrop-shadows.lua) shifts the silhouettes one
-- way; this one projects them from the light, as if the scene had depth:
--   the wall stands at depth 0, its foot at `floorY` (world y); the floor comes towards you from there;
--   everything stands at `depth` in front of the wall, on the line y = floorY + depth (its feet), so the band
--   floorY..floorY+depth is the floor behind the things, seen from a little above.
--   A point lamp (x, h above the floor, z in front of the wall) or a sun (the way to it) throws a thing's
--   shadow along that floor and up the wall. A low sun stretches it long over the floor; a lamp close to a
--   thing throws a big one on the wall, further back it shrinks to the thing's size (a torch, shadow puppets).
-- Each frame the textured world is drawn once more into a canvas, as it is (the things' own plane:
-- src/shadow-silhouettes.lua, shared with the soft wall shadows, drawn once for both); then,
-- per pixel of the wall and floor, a ray goes from that spot to the light, and where it crosses the
-- things' plane the canvas says whether something's there: in shadow. Hard edges; `softness` > 0 samples a
-- lamp that size (or a sun that wide), the penumbra wider the further a shadow lands from its thing.
-- Off unless state.projectedShadows is set: { area = function() (draws the wall and floor's shape, world
-- space: the shadows land only there), floorY, depth, strength = 0..1, softness (world units for a lamp,
-- about 0.05..0.3 for a sun), colour = { r, g, b } (black),
-- light = { kind = 'point', x, h, z } or { kind = 'sun', x, h, z } (the way towards it, z towards you) }.
-- Several lights: lights = { { light = ..., strength =, softness =, colour = }, ... } in place of light (each
-- falls back to the settings' own strength, softness and colour); each throws its own shadow, one pass each
-- over the same silhouettes, so where two shadows cross it's darker.
-- The lamp's z must be in front of the things (z > depth), else no shadow falls behind them.
-- Boards: boards = { { x0, x1, z, height }, ... } (up to 4): flat backdrops standing on the floor
-- z in front of the wall (0 < z < depth), from x0 to x1, height tall; on screen from y = floorY + z up.
-- A shadow landing on one is cut short there, so a board close behind the things catches a shadow near
-- their size and crisp, the wall far behind a bigger, softer one. The scene draws the boards (before the
-- shadows); they don't throw shadows themselves.
-- Costs a second pass of the textured drawing per frame (one for this and the wall shadow together), and a
-- per-pixel loop.
local lib = {}

local state = require('src.state')
local silhouettesOf = require('src.shadow-silhouettes')

local projector
local function projectorShader()
    projector = projector or love.graphics.newShader([[
        uniform vec2 origin;   // world point at the screen's top left
        uniform vec2 screen;   // the screen in world units
        uniform float floorY;
        uniform float depth;
        uniform vec3 light;    // a lamp: where it is (x, h, z); a sun: the way to it
        uniform float isSun;
        uniform float softness;
        uniform float strength;
        uniform vec3 colour;
        uniform vec4 boards[4]; // x0, x1, z, height
        uniform float boardCount;
        const int TAPS = 13;

        // how much of the light reaches a spot S (x, h, z) past the things' plane: 1 lit, 0 in shadow
        float shade(Image tex, vec3 S, vec3 L) {
            vec3 toL = isSun > 0.5 ? L : L - S;
            if (toL.z <= 0.0) return 1.0;           // the light behind the things: nothing falls back here
            float s = (depth - S.z) / toL.z;
            if (s <= 0.0) return 1.0;
            if (isSun < 0.5 && s >= 1.0) return 1.0; // the lamp between the spot and the things
            vec3 P = S + toL * s;                    // where the ray crosses the things' plane
            if (P.y < 0.0) return 1.0;
            vec2 world = vec2(P.x, floorY + depth - P.y);
            vec2 uv = (world - origin) / screen;
            if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) return 1.0;
            return 1.0 - Texel(tex, uv).a;
        }

        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
            vec2 w = origin + uv * screen;
            vec3 S;
            if (w.y <= floorY) S = vec3(w.x, floorY - w.y, 0.0);  // on the wall
            else {
                S = vec3(w.x, 0.0, w.y - floorY);                // on the floor behind the things
                if (S.z >= depth) return vec4(0.0);
            }
            // on a board: the one nearest you that covers this spot on screen
            float nearest = -1.0;
            for (int i = 0; i < 4; ++i) {
                if (float(i) < boardCount) {
                    vec4 b = boards[i];
                    float foot = floorY + b.z;
                    if (w.x >= b.x && w.x <= b.y && w.y <= foot && w.y >= foot - b.w && b.z > nearest) {
                        nearest = b.z;
                        S = vec3(w.x, foot - w.y, b.z);
                    }
                }
            }
            float dark;
            if (softness <= 0.0) {
                dark = 1.0 - shade(tex, S, light);
            } else {
                vec2 offs[TAPS];
                offs[0] = vec2(0.0, 0.0);
                offs[1] = vec2(0.5, 0.0);   offs[2] = vec2(0.25, 0.433);  offs[3] = vec2(-0.25, 0.433);
                offs[4] = vec2(-0.5, 0.0);  offs[5] = vec2(-0.25, -0.433); offs[6] = vec2(0.25, -0.433);
                offs[7] = vec2(0.866, 0.5); offs[8] = vec2(0.0, 1.0);    offs[9] = vec2(-0.866, 0.5);
                offs[10] = vec2(-0.866, -0.5); offs[11] = vec2(0.0, -1.0); offs[12] = vec2(0.866, -0.5);
                float lit = 0.0;
                for (int i = 0; i < TAPS; ++i) {
                    // a lamp that size, facing the wall (its x and height); a sun that wide
                    lit += shade(tex, S, light + vec3(offs[i] * softness, 0.0));
                }
                dark = 1.0 - lit / float(TAPS);
            }
            return vec4(colour, dark * strength);
        }
    ]])
    return projector
end

-- world units to screen pixels under the current transform (no rotation)
local function pixelsPerUnit()
    local x0, y0 = love.graphics.transformPoint(0, 0)
    local x1, y1 = love.graphics.transformPoint(1, 0)
    return math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2)
end

function lib.draw(world)
    local settings = state.projectedShadows
    if not settings or not settings.area or not (settings.light or settings.lights) or not world then return end
    -- the things as they are (the current transform: world space)
    local silhouettes, w, h = silhouettesOf.get(world)

    local ox, oy = love.graphics.inverseTransformPoint(0, 0)
    local scale = pixelsPerUnit()
    local compare, value = love.graphics.getStencilTest()
    love.graphics.stencil(settings.area, 'replace', 1)
    love.graphics.setStencilTest('greater', 0)
    love.graphics.push()
    love.graphics.origin()
    local shader = projectorShader()
    love.graphics.setShader(shader)
    shader:send('origin', { ox, oy })
    shader:send('screen', { w / scale, h / scale })
    shader:send('floorY', settings.floorY)
    shader:send('depth', settings.depth)
    local boards = settings.boards or {}
    local packed = {}
    for i = 1, 4 do
        local b = boards[i]
        packed[i] = b and { b[1], b[2], b[3], b[4] } or { 0, 0, 0, 0 }
    end
    shader:send('boards', unpack(packed))
    shader:send('boardCount', math.min(4, #boards))
    love.graphics.setColor(1, 1, 1, 1)
    for _, one in ipairs(settings.lights or { { light = settings.light } }) do
        local light = one.light
        shader:send('light', { light.x, light.h, light.z })
        shader:send('isSun', light.kind == 'sun' and 1 or 0)
        shader:send('softness', one.softness or settings.softness or 0)
        shader:send('strength', one.strength or settings.strength or 0.5)
        shader:send('colour', one.colour or settings.colour or { 0, 0, 0 })
        love.graphics.draw(silhouettes, 0, 0)
    end
    love.graphics.setShader()
    love.graphics.pop()
    if compare then love.graphics.setStencilTest(compare, value) else love.graphics.setStencilTest() end
end

return lib
