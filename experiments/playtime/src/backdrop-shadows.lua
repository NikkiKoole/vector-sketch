-- backdrop-shadows.lua — what stands in front of a back wall throws a soft shadow onto it
-- (docs/LIGHT-AND-SHADOW.md LS7). The contact shadow (src/contact-shadows.lua) is about touching and fades
-- as a thing rises; this one stays, on the vertical plane behind, and moves with it.
-- Each frame the textured world is drawn once more into a canvas (src/shadow-silhouettes.lua, shared with
-- the 3D shadows); that canvas, shifted the way the light shines (how far the wall is behind sets how
-- far) and blurred, goes onto the wall as soft black, cut with a
-- stencil to the wall: no shadow over nothing (open sky behind: none). Drawn after the scene's backdrop
-- (its drawBelow), before the bodies.
-- Off unless state.backdropShadows is set: { wall = function() (draws the wall's shape, world space),
-- notOn = function() (optional: what stands in front of the wall and hides it, cut out),
-- offset = { x, y } (world units the shadow is shifted), blur = world units (8), strength = 0..1 (0.4) },
-- or { layers = { such tables } }: a pass each, for walls at other distances (a backdrop's own `behind`,
-- src/scene-light.lua: a wall further back, a longer and softer shadow; Nikki 2026-11-11).
-- A scene works out the offset from its light (the way its sun shines). One direction for the whole scene: a lamp
-- in the middle throwing shadows both ways would need a pass per thing (not yet).
-- Costs a second pass of the textured drawing per frame (shared with the 3D shadows: one pass for both).
local lib = {}

local state = require('src.state')
local silhouettesOf = require('src.shadow-silhouettes')

-- the silhouettes' alpha, blurred over a small disk, as black
local composite
local function compositeShader()
    composite = composite or love.graphics.newShader([[
        uniform vec2 texel;
        uniform float radius;
        uniform float strength;
        const int TAPS = 13;
        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 fc) {
            vec2 offs[TAPS];
            offs[0] = vec2(0.0, 0.0);
            offs[1] = vec2(0.5, 0.0);   offs[2] = vec2(0.25, 0.433);  offs[3] = vec2(-0.25, 0.433);
            offs[4] = vec2(-0.5, 0.0);  offs[5] = vec2(-0.25, -0.433); offs[6] = vec2(0.25, -0.433);
            offs[7] = vec2(0.866, 0.5); offs[8] = vec2(0.0, 1.0);    offs[9] = vec2(-0.866, 0.5);
            offs[10] = vec2(-0.866, -0.5); offs[11] = vec2(0.0, -1.0); offs[12] = vec2(0.866, -0.5);
            float a = 0.0;
            for (int i = 0; i < TAPS; ++i) a += Texel(tex, uv + offs[i] * radius * texel).a;
            return vec4(0.0, 0.0, 0.0, a / float(TAPS) * strength);
        }
    ]])
    return composite
end

-- world units to screen pixels under the current transform
local function pixelsPerUnit()
    local x0, y0 = love.graphics.transformPoint(0, 0)
    local x1, y1 = love.graphics.transformPoint(1, 0)
    return math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2)
end

local function drawOne(settings, shadowCanvas, w, h)
    if not settings.wall or not settings.offset then return end
    -- the silhouettes, as they are; shifted the way the light shines when laid down (screen pixels)
    local ox, oy = love.graphics.transformPoint(0, 0)
    local sx, sy = love.graphics.transformPoint(settings.offset[1], settings.offset[2])

    -- onto the wall only
    local scale = pixelsPerUnit()
    local compare, value = love.graphics.getStencilTest()
    love.graphics.stencil(settings.wall, 'replace', 1)
    if settings.notOn then love.graphics.stencil(settings.notOn, 'replace', 0, true) end
    love.graphics.setStencilTest('greater', 0)
    love.graphics.push()
    love.graphics.origin()
    local shader = compositeShader()
    love.graphics.setShader(shader)
    shader:send('texel', { 1 / w, 1 / h })
    shader:send('radius', (settings.blur or 8) * scale)
    shader:send('strength', settings.strength or 0.4)
    love.graphics.setColor(1, 1, 1, 1)
    local pad = silhouettesOf.pad() -- the canvas has a margin round the screen (shadow-silhouettes)
    love.graphics.draw(shadowCanvas, sx - ox - pad, sy - oy - pad)
    love.graphics.setShader()
    love.graphics.pop()
    if compare then love.graphics.setStencilTest(compare, value) else love.graphics.setStencilTest() end
end

function lib.draw(world)
    local settings = state.backdropShadows
    if not settings or not world then return end
    if not settings.layers and not (settings.wall and settings.offset) then return end
    local shadowCanvas, w, h = silhouettesOf.get(world) -- once, for every layer
    if settings.layers then
        for _, layer in ipairs(settings.layers) do drawOne(layer, shadowCanvas, w, h) end
    else
        drawOne(settings, shadowCanvas, w, h)
    end
end

return lib
