-- backdrop-shadows.lua — what stands in front of a back wall throws a soft shadow onto it
-- (docs/LIGHT-AND-SHADOW.md LS7). The contact shadow (src/contact-shadows.lua) is about touching and fades
-- as a thing rises; this one stays, on the vertical plane behind, and moves with it.
-- Each frame the textured world is drawn once more into a canvas, shifted the way the light shines (how far
-- the wall is behind sets how far); that canvas, blurred, goes onto the wall as soft black, cut with a
-- stencil to the wall: no shadow over nothing (open sky behind: none). Drawn after the scene's backdrop
-- (its drawBelow), before the bodies.
-- Off unless state.backdropShadows is set: { wall = function() (draws the wall's shape, world space),
-- offset = { x, y } (world units the shadow is shifted), blur = world units (8), strength = 0..1 (0.4) }.
-- A scene works out the offset from its light (the way its sun shines). One direction for the whole scene: a lamp
-- in the middle throwing shadows both ways would need a pass per thing (not yet).
-- Costs a second pass of the textured drawing per frame.
local lib = {}

local state = require('src.state')

local canvas
local function canvasFor(w, h)
    if not canvas or canvas:getWidth() ~= w or canvas:getHeight() ~= h then
        if canvas then canvas:release() end
        canvas = love.graphics.newCanvas(w, h)
    end
    return canvas
end

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

function lib.draw(world)
    local settings = state.backdropShadows
    if not settings or not settings.wall or not settings.offset or not world then return end
    local textured = require('src.physics.box2d-draw-textured')
    local target = love.graphics.getCanvas()
    local w, h
    if target then w, h = target:getDimensions() else w, h = love.graphics.getDimensions() end
    local shadowCanvas = canvasFor(w, h)

    -- the silhouettes, shifted the way the light shines (the current transform: world space)
    love.graphics.setCanvas({ shadowCanvas, stencil = true })
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.push()
    love.graphics.translate(settings.offset[1], settings.offset[2])
    textured.drawTexturedWorld(world)
    love.graphics.pop()
    if target then love.graphics.setCanvas({ target, stencil = true }) else love.graphics.setCanvas() end

    -- onto the wall only
    local scale = pixelsPerUnit()
    local compare, value = love.graphics.getStencilTest()
    love.graphics.stencil(settings.wall, 'replace', 1)
    love.graphics.setStencilTest('greater', 0)
    love.graphics.push()
    love.graphics.origin()
    local shader = compositeShader()
    love.graphics.setShader(shader)
    shader:send('texel', { 1 / w, 1 / h })
    shader:send('radius', (settings.blur or 8) * scale)
    shader:send('strength', settings.strength or 0.4)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(shadowCanvas, 0, 0)
    love.graphics.setShader()
    love.graphics.pop()
    if compare then love.graphics.setStencilTest(compare, value) else love.graphics.setStencilTest() end
end

return lib
