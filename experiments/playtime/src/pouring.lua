-- pouring.lua — water poured out of cups, in any scene (ENGINE-MERGE EM3, WATER W2; after the seaside spike's,
-- from WATERJAR WJ4). What spills over a container's rim (src/liquid.lua update, through state.liquidSpillHook)
-- leaves as points of particle water (src/fluid.lua) from the rim's low corner, at most FLOW a second; the rest
-- goes back in, so a pouring cup stays full to the brim. The points fall and run over the bodies (fluid
-- collides with the world's shapes); one landing in a cup or a bath joins its water, one lying still soaks away.
-- Drawn as one stream at the end of the water pass (src/water-look.lua drawEnd: lib.draw), bending what's
-- behind it. An engine system (src/systems.lua): update runs while the world does. A scene that catches spills
-- itself (seaside sets its own hook) is left alone. Without containers nothing runs.
local state = require('src.state')
local registry = require('src.registry')
local subtypes = require('src.subtypes')
local liquid = require('src.liquid')
local fluid = require('src.fluid')
local waterShader = require('src.render.water-shader')
local units = require('src.physics-units')

local lib = {}

local FLOW = 40000      -- area units a second through a rim at most
local POUR_H = 30       -- the points' spacing (fluid's h)
local POINT_AREA = (0.62 * POUR_H) ^ 2 -- the water one point carries (they sit 0.62 h apart)
local POINT_R = 21      -- a point drawn as a drop this big (overlapping its neighbours: one stream)
local SOAK = 2.5        -- s a still point lies on a floor before it soaks away
local MAX_AGE = 15      -- s at most (one fallen off the world)

local function data()
    state.pouring = state.pouring or { carry = setmetatable({}, { __mode = 'k' }) }
    return state.pouring
end

local function points(d)
    if not d.f then
        d.f = fluid.new({ h = POUR_H, dataNames = { 'from', 'age', 'still', 'wetted' } })
        fluid.calibrate(d.f)
    end
    return d.f
end

-- what spills over a rim: out as points at most FLOW a second, the rest back in
function lib.onSpill(extra, body, spilled)
    local d = data()
    local c = liquid.container(extra, body)
    local full = liquid.volume(c.hull, c.holes)
    if full <= 0 then return end
    local dt = math.min(love.timer.getDelta(), 1 / 30)
    local out = math.min(spilled, FLOW * dt)
    extra.fill = extra.fill + (spilled - out) / full
    d.carry[extra] = (d.carry[extra] or 0) + out
    local mx, my = liquid.mouthPoint(extra, body)
    if not mx then return end
    local cx, cy = body:getWorldCenter()
    local ox, oy = mx - cx, my - cy
    local len = math.max(math.sqrt(ox * ox + oy * oy), 1)
    local vx, vy = body:getLinearVelocityFromWorldPoint(mx, my)
    -- (seaside's 90 + 260 px/s, tuned at 200 px a metre: written as at 100, src/physics-units.lua)
    local push = units.speed(45 + 130 * math.min(out / (FLOW * dt), 1))
    local f = points(d)
    local sp = 0.62 * POUR_H
    while d.carry[extra] >= POINT_AREA do
        d.carry[extra] = d.carry[extra] - POINT_AREA
        local j = love.math.random() - 0.5
        local i = fluid.add(f, mx + ox / len * sp + j * sp, my + j * sp * 0.5,
            vx + ox / len * push + j * 30, vy + oy / len * push * 0.3)
        if not i then -- no room for more points: it stays in the cup
            extra.fill = extra.fill + (d.carry[extra] + POINT_AREA) / full
            d.carry[extra] = 0
            break
        end
        f.data.from[i], f.data.age[i], f.data.still[i], f.data.wetted[i] = body, 0, 0, false
    end
end

local function insideConvex(poly, x, y)
    local n, sign = #poly, 0
    for i = 1, n, 2 do
        local j = (i + 2 > n) and 1 or i + 2
        local cross = (poly[j] - poly[i]) * (y - poly[i + 1]) - (poly[j + 1] - poly[i + 1]) * (x - poly[i])
        if cross ~= 0 then
            local sg = cross > 0 and 1 or -1
            if sign == 0 then sign = sg elseif sg ~= sign then return false end
        end
    end
    return true
end

-- the containers' water this frame: world hull, level, how much a full one holds
local function vessels()
    local out = {}
    for _, fixture in ipairs(registry.sfixturesOf(subtypes.LIQUID)) do
        if not fixture:isDestroyed() then
            local extra, body = fixture:getUserData().extra, fixture:getBody()
            local level, _, hull = liquid.water(extra, body)
            local c = liquid.container(extra, body)
            out[#out + 1] = { extra = extra, body = body, level = level, hull = hull,
                full = liquid.volume(c.hull, c.holes) }
        end
    end
    return out
end

-- while the world runs: catch the spills (unless a scene does), move the points, let them land
function lib.update(dt)
    local d = data()
    d.hook = d.hook or function(...) return require('src.pouring').onSpill(...) end
    if state.liquidSpillHook == nil and #registry.sfixturesOf(subtypes.LIQUID) > 0 then
        state.liquidSpillHook = d.hook
    end
    if state.liquidSpillHook ~= d.hook then return end -- a scene pours its own (seaside)
    local f = d.f
    if not f or f.n == 0 then return end
    fluid.update(f, dt)
    local from, age, still = f.data.from, f.data.age, f.data.still
    local list = vessels()
    for i = f.n - 1, 0, -1 do repeat
        local x, y = f.x[i], f.y[i]
        local vx, vy = x - f.px[i], y - f.py[i]
        age[i] = (age[i] or 0) + dt
        local gone = false
        if vy >= 0 then -- falling: into a cup or a bath (not straight back into its own)
            for _, v in ipairs(list) do
                if v.full > 0 and v.hull and (v.body ~= from[i] or age[i] > 0.4) and insideConvex(v.hull, x, y)
                    and (not v.level or y > v.level - POINT_R) then
                    v.extra.fill = math.min(1, (v.extra.fill or 0) + POINT_AREA / v.full)
                    gone = true
                    break
                end
            end
        end
        -- the first moving body it lands on (a Mipo under the stream) gets a wet spot there (src/wet.lua)
        if not gone and not f.data.wetted[i] and age[i] > 0.1 then
            local world = state.physicsWorld
            world:queryBoundingBox(x - POINT_R, y - POINT_R, x + POINT_R, y + POINT_R, function(fixture)
                local body = fixture:getBody()
                if body ~= from[i] and body:getType() == 'dynamic' and not fixture:isSensor() then
                    require('src.wet').splash(x, y + POINT_R * 0.5, 45, 0.8)
                    f.data.wetted[i] = true
                    return false
                end
                return true
            end)
        end
        if not gone and vx * vx + vy * vy < 1 then -- lying still: soaks away
            still[i] = (still[i] or 0) + dt
            gone = still[i] > SOAK + (i % 7) * 0.3
        elseif not gone then
            still[i] = 0
        end
        if gone or age[i] > MAX_AGE then fluid.remove(f, i) end
    until true end
end

-- the stream: the points as soft blobs added up in a field, then shown as water bending `scene` (the frame so
-- far, src/water-look.lua). Called under the camera, onto the frame's target.
local field
function lib.draw(scene)
    local d = state.pouring
    local f = d and d.f
    if not f or f.n == 0 or state.liquidSpillHook ~= d.hook then return end
    local w, h = scene:getDimensions()
    if not field or field:getWidth() ~= w or field:getHeight() ~= h then
        if field then field:release() end
        field = love.graphics.newCanvas(w, h)
    end
    local target = love.graphics.getCanvas()
    love.graphics.push('all')
    love.graphics.setCanvas(field)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setBlendMode('add')
    love.graphics.setColor(1, 1, 1, 1)
    local blob = waterShader.blobImage()
    local half = blob:getWidth() / 2
    local sc = POINT_R * waterShader.BLOB / half
    for i = 0, f.n - 1 do
        local vx, vy = (f.x[i] - f.px[i]) * 60, (f.y[i] - f.py[i]) * 60 -- (px a frame)
        local stretch = 1 + math.min(math.sqrt(vx * vx + vy * vy) / 1400, 1.2)
        love.graphics.draw(blob, f.x[i], f.y[i], math.atan2(vy, vx), sc * stretch, sc / math.sqrt(stretch), half, half)
    end
    love.graphics.pop()
    love.graphics.push('all')
    if target then love.graphics.setCanvas({ target, stencil = true }) else love.graphics.setCanvas() end
    love.graphics.origin()
    local shader = waterShader.streamShader()
    love.graphics.setShader(shader)
    shader:send('scene', scene)
    shader:send('field', field)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle('fill', 0, 0, w, h)
    love.graphics.pop()
end

-- a scene's data loads: no points left over from the last one
function lib.unload()
    local d = state.pouring
    if d and d.f then
        for i = d.f.n - 1, 0, -1 do fluid.remove(d.f, i) end
    end
    if d and state.liquidSpillHook == d.hook then state.liquidSpillHook = nil end
end

return lib
