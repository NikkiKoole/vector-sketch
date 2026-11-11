-- part-shadows.lua — parts shadowing each other (docs/LIGHT-AND-SHADOW.md LS20): a Mipo's arm darkens its
-- torso where it lies over it, the head its neck, one Mipo the one standing behind it. Screen space, by
-- draw order: the textured world is drawn once more into a depth picture, each part writing its place in
-- the order (which part is in front where); then one pass over the screen darkens each pixel where a part
-- further forward lies a few world units toward the light (soft: several taps along the way, so a part
-- just behind gets more than one far behind, and the edge fades).
-- Off unless state.partShadows = { strength = 0..1, reach = world units (12) } (src/scene-light.lua, the
-- light section's 'part shadows'). The way to the light: the scene's wall shadows' (they fall away from
-- it; with a sky they follow the hour), else its first default light, else high on the left.
-- Costs a pass of the textured drawing (like src/shadow-silhouettes.lua) and one screen pass.
local lib = {}

local state = require('src.state')

local NO_SHADOW -- what doesn't throw one (the silhouettes' list): looked up when used (hot swaps)
local function castsShadow(drawable)
    NO_SHADOW = NO_SHADOW or require('src.shadow-silhouettes').NO_SHADOW
    return not (drawable and NO_SHADOW and NO_SHADOW[drawable.type])
end

-- writes a part's place in the order where its picture is (alpha over a half), as two bytes (r, g)
local writer
local function writerShader()
    writer = writer or love.graphics.newShader([[
        uniform vec2 order;
        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
            if (Texel(tex, uv).a * color.a < 0.5) discard;
            return vec4(order.x, order.y, 0.0, 1.0);
        }
    ]])
    return writer
end

-- darkens where a part further forward lies toward the light; drawn over the screen with the depth picture
local darkener
local function darkenerShader()
    darkener = darkener or love.graphics.newShader([[
        uniform vec2 toLight;   // uv per step toward the light (the whole reach)
        uniform float strength;
        const int TAPS = 8;
        float orderAt(vec4 p) { return p.r * 255.0 * 256.0 + p.g * 255.0; }
        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
            vec4 here = Texel(tex, uv);
            if (here.a < 0.5) discard;
            float mine = orderAt(here);
            vec2 side = vec2(-toLight.y, toLight.x) * 0.25;
            // each pixel's taps shifted by a little noise: the steps between taps blend into a soft, grainy edge
            float jitter = fract(sin(dot(sc, vec2(12.9898, 78.233))) * 43758.5453);
            float hit = 0.0;
            for (int i = 1; i <= TAPS; i++) {
                float t = (float(i) - jitter) / float(TAPS);
                // a little to either side as well, every other tap: a softer edge
                vec2 at = uv + toLight * t + side * (mod(float(i), 2.0) - 0.5) * t;
                vec4 there = Texel(tex, at);
                if (there.a > 0.5 && orderAt(there) > mine + 0.5) hit += 1.0 - 0.5 * t;
            }
            float amount = clamp(hit / (float(TAPS) * 0.6), 0.0, 1.0);
            if (amount <= 0.0) discard;
            return vec4(0.0, 0.0, 0.0, amount * strength);
        }
    ]])
    return darkener
end

local canvas
local function canvasFor(w, h)
    if not canvas or canvas:getWidth() ~= w or canvas:getHeight() ~= h then
        if canvas then canvas:release() end
        canvas = love.graphics.newCanvas(w, h)
        canvas:setFilter('nearest', 'nearest')
    end
    return canvas
end

-- world units to screen points under the current transform
local function pointsPerUnit()
    local x0, y0 = love.graphics.transformPoint(0, 0)
    local x1, y1 = love.graphics.transformPoint(1, 0)
    return math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2)
end

-- the way to the light (world, normalised)
local function toLight()
    local walls = state.backdropShadows
    local one = walls and (walls.layers and walls.layers[1] or walls)
    if one and one.offset and (one.offset[1] ~= 0 or one.offset[2] ~= 0) then
        local x, y = -one.offset[1], -one.offset[2]
        local len = math.sqrt(x * x + y * y)
        return x / len, y / len
    end
    local lights = state.sceneDefaultLights
    local first = lights and lights[1]
    if first and first.toLight and (first.intensity or 1) > 0 then
        local x, y = first.toLight[1], first.toLight[2]
        local len = math.sqrt(x * x + y * y)
        if len > 0 then return x / len, y / len end
    end
    return -0.5, -0.85
end

-- the depth picture: the textured world, each part its place in the order (parts at the same z share one)
local function drawOrder(world)
    local textured = require('src.physics.box2d-draw-textured')
    local shader = writerShader()
    local rank, lastZ = 0, nil
    local function only(_, drawable)
        if not castsShadow(drawable) then return false end
        local z = drawable and drawable.z or 0
        if z ~= lastZ then
            rank, lastZ = math.min(rank + 1, 65535), z
            shader:send('order', { math.floor(rank / 256) / 255, (rank % 256) / 255 })
        end
        return true
    end
    -- the drawers set shaders of their own (light, clay, cuts): kept to the writer for this pass
    local gfx = love.graphics
    local setShader, wasOutlines = gfx.setShader, state.drawingOutlines
    gfx.setShader(shader)
    rawset(gfx, 'setShader', function() end)
    state.drawingOutlines = true
    local ok, err = pcall(textured.drawTexturedWorld, world, only)
    rawset(gfx, 'setShader', setShader)
    state.drawingOutlines = wasOutlines
    love.graphics.setShader()
    if not ok then error(err, 0) end
end

-- after the textured world (main.lua): the parts' shadows on the parts behind them
function lib.draw(world)
    local settings = state.partShadows
    if not settings or not world or (settings.strength or 0) <= 0 then return end
    local target = love.graphics.getCanvas()
    local w, h
    if target then w, h = target:getDimensions() else w, h = love.graphics.getDimensions() end
    local picture = canvasFor(w, h)
    local scale = pointsPerUnit()
    love.graphics.push('all')
    love.graphics.setCanvas({ picture, stencil = true })
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setBlendMode('replace')
    drawOrder(world)
    love.graphics.pop()

    local lx, ly = toLight()
    local reach = (settings.reach or 12) * scale
    local shader = darkenerShader()
    love.graphics.push('all')
    love.graphics.origin()
    love.graphics.setShader(shader)
    shader:send('toLight', { lx * reach / w, ly * reach / h })
    shader:send('strength', settings.strength)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(picture, 0, 0)
    love.graphics.pop()
end

return lib
