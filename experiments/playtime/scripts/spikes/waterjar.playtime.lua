-- waterjar: a tank of particle water to tip and slosh, after dreamengine's waterjar cart (docs/WATERJAR.md)
-- Each point of water pushes its neighbours apart (Position-Based Fluids, src/fluid.lua, the step in
-- native/desound/fluid.c): swing the tank fast and the wave climbs the far wall and folds over.
-- Mipos and crates in it are pushed by the water and push it back.
--
-- play mode (tab): a/d or left/right tip the tank; drag in the water to stir it (drag a body to
-- move it); space pours water at the mouse; m a Mipo, b a crate at the mouse; r fill it again;
-- v the points / the water; h the panel

local s = {}

local GROUND_TOP = 0
local TANK_X, TANK_Y = 0, -520 -- the pivot: the middle of the tank's floor
local HALF_WIDTH, DEPTH, WALL = 760, 640, 46
local MAX_TILT = math.rad(35)
local TILT_SPEED = math.rad(3.5) * 60 -- per second (the cart: 3.5 degrees a frame)

local OUTLINE = { 0.16, 0.14, 0.2 }
local GROUND = { 0.55, 0.66, 0.42 }
local WOOD = { 0.62, 0.47, 0.34 }
local GLASS = { 0.85, 0.93, 0.96 }

local function scene()
    state.waterjarScene = state.waterjarScene or {
        settings = { gravity = 1, damping = 0.966, viscosity = 0.10, cohesion = 0.85, iterations = 6,
            push = 1, density = 1, opacity = 0.82 },
        tilt = 0, showPanel = false, points = false, mipos = {}, crates = {},
    }
    return state.waterjarScene
end

local function apply(sc)
    local f = sc.fluid
    if not f then return end
    for k, v in pairs(sc.settings) do f[k] = v end
end

local function box(body, x1, y1, x2, y2)
    local shape = love.physics.newPolygonShape(x1, y1, x2, y1, x2, y2, x1, y2)
    return love.physics.newFixture(body, shape)
end

local function fill(sc)
    local f = fluid.new({ tank = sc.tank, tankHalfWidth = HALF_WIDTH, tankDepth = DEPTH })
    sc.fluid = f
    apply(sc)
    local level = f.native and 0.55 or 0.25
    fluid.fill(f, TANK_X - HALF_WIDTH, TANK_Y - DEPTH * level, TANK_X + HALF_WIDTH, TANK_Y)
end

local function build(sc)
    for _, b in ipairs(sc.bodies or {}) do
        if not b:isDestroyed() then b:destroy() end
    end
    sc.bodies = {}
    local ground = love.physics.newBody(world, 0, 0, 'static')
    box(ground, -4000, GROUND_TOP, 4000, GROUND_TOP + 300)
    -- the stand: a wedge the tank rocks on
    box(ground, -60, TANK_Y + WALL + 10, 60, GROUND_TOP)
    sc.bodies[#sc.bodies + 1] = ground
    -- the tank: a kinematic body turning about the middle of its floor, open at the top
    local tank = love.physics.newBody(world, TANK_X, TANK_Y, 'kinematic')
    box(tank, -HALF_WIDTH - WALL, 0, HALF_WIDTH + WALL, WALL)
    box(tank, -HALF_WIDTH - WALL, -DEPTH, -HALF_WIDTH, 0)
    box(tank, HALF_WIDTH, -DEPTH, HALF_WIDTH + WALL, 0)
    sc.bodies[#sc.bodies + 1] = tank
    sc.tank = tank
    sc.tilt = 0
    fill(sc)
end

local function spawnMipo(sc, x, y)
    local inst = characterManager.createCharacter('humanoid', x, y, 0.3)
    if inst then characterManager.randomizeMipoConstrained(inst) end
    if inst then sc.mipos[#sc.mipos + 1] = inst end
end

local function spawnCrate(sc, x, y)
    local body = love.physics.newBody(world, x, y, 'dynamic')
    local size = 120 + love.math.random() * 80
    love.physics.newFixture(body, love.physics.newRectangleShape(size, size * 0.8), 0.6)
    body:setAngle((love.math.random() - 0.5) * 0.6)
    sc.crates[#sc.crates + 1] = { body = body, w = size, h = size * 0.8 }
end

---------------------------------------------------------------- hooks

function s.onStart()
    worldState.paused = false
    local sc = scene()
    local ok = sc.tank and not sc.tank:isDestroyed()
    if not ok then
        sc.mipos, sc.crates = {}, {}
        build(sc)
        spawnCrate(sc, TANK_X - 300, TANK_Y - DEPTH - 200)
    end
end

function s.onKeyPress(key)
    local sc = scene()
    local mx, my = mouseWorldPos()
    if key == 'r' then fill(sc)
    elseif key == 'm' then spawnMipo(sc, mx, my)
    elseif key == 'b' then spawnCrate(sc, mx, my)
    elseif key == 'v' then sc.points = not sc.points
    elseif key == 'h' then sc.showPanel = not sc.showPanel
    end
end

local function bodyAt(x, y)
    local hit = false
    world:queryBoundingBox(x - 1, y - 1, x + 1, y + 1, function(fx)
        if fx:getBody():getType() == 'dynamic' and fx:testPoint(x, y) then hit = true; return false end
        return true
    end)
    return hit
end

local function overPanel(sc)
    local p = sc.panelRect
    if not (p and sc.showPanel and state.playMode) then return false end
    local mx, my = love.mouse.getPosition()
    return mx >= p[1] and mx <= p[1] + p[3] and my >= p[2] and my <= p[2] + p[4]
end

-- the hand: a drag that starts where there's no body stirs the water
local function hand(sc, dt)
    local down = love.mouse.isDown(1)
    local mx, my = mouseWorldPos()
    if down and not sc.wasDown then
        sc.stirring = not overPanel(sc) and not bodyAt(mx, my)
    elseif not down then
        sc.stirring = false
    end
    if sc.stirring and sc.lastX then
        local dx, dy = mx - sc.lastX, my - sc.lastY
        if dx * dx + dy * dy > 0.25 then
            fluid.stir(sc.fluid, mx, my, dx * dt * 60, dy * dt * 60, sc.fluid.h * 3)
        end
    end
    sc.lastX, sc.lastY = mx, my
    sc.wasDown = down
end

function s.update(dt)
    local sc = state.waterjarScene
    if not (sc and sc.fluid and sc.tank) or sc.tank:isDestroyed() then return end
    -- tip the tank: a fast swing to a steep angle throws the wave; let go and it eases back level
    local t = 0
    if love.keyboard.isDown('a', 'left') then t = t - 1 end
    if love.keyboard.isDown('d', 'right') then t = t + 1 end
    if t ~= 0 then
        sc.tilt = math.max(-MAX_TILT, math.min(MAX_TILT, sc.tilt + t * TILT_SPEED * dt))
    else
        sc.tilt = sc.tilt * 0.9 ^ (dt * 60)
    end
    if dt > 0 then sc.tank:setAngularVelocity((sc.tilt - sc.tank:getAngle()) / dt) end

    hand(sc, dt)
    if love.keyboard.isDown('space') and not overPanel(sc) then
        local mx, my = mouseWorldPos()
        local sp = sc.fluid.h * 0.62
        for k = -3, 3 do fluid.add(sc.fluid, mx + k * sp, my, 0, 300) end
    end
    fluid.update(sc.fluid, dt)
    fluid.cull(sc.fluid, -6000, -6000, 6000, 1500)
end

---------------------------------------------------------------- drawing

local function outlined(mode, ...)
    love.graphics.polygon(mode, ...)
    love.graphics.setColor(OUTLINE)
    love.graphics.setLineWidth(4)
    love.graphics.polygon('line', ...)
end

local function drawTankPart(sc, x1, y1, x2, y2, color)
    love.graphics.setColor(color)
    outlined('fill', sc.tank:getWorldPoints(x1, y1, x2, y1, x2, y2, x1, y2))
end

function s.drawBelow()
    local sc = state.waterjarScene
    if not (sc and sc.tank) or sc.tank:isDestroyed() then return end
    sc.savedDrawBodies = state.world.debugDrawBodies
    state.world.debugDrawBodies = false
    love.graphics.setColor(0.94, 0.9, 0.82)
    love.graphics.rectangle('fill', -6000, -6000, 12000, 6000)
    love.graphics.setColor(GROUND)
    outlined('fill', -4000, GROUND_TOP, 4000, GROUND_TOP, 4000, GROUND_TOP + 300, -4000, GROUND_TOP + 300)
    love.graphics.setColor(WOOD)
    outlined('fill', -60, GROUND_TOP, 60, GROUND_TOP, 30, TANK_Y + WALL + 10, -30, TANK_Y + WALL + 10)
    -- the tank's back: pale glass
    love.graphics.setColor(GLASS[1], GLASS[2], GLASS[3], 0.6)
    love.graphics.polygon('fill', sc.tank:getWorldPoints(-HALF_WIDTH, -DEPTH, HALF_WIDTH, -DEPTH, HALF_WIDTH, 0,
        -HALF_WIDTH, 0))
    -- the crates (the debug bodies are off)
    for _, c in ipairs(sc.crates) do
        if not c.body:isDestroyed() then
            love.graphics.setColor(0.8, 0.6, 0.38)
            outlined('fill', c.body:getWorldPoints(c.body:getFixtures()[1]:getShape():getPoints()))
        end
    end
end

function s.draw()
    local sc = state.waterjarScene
    if not (sc and sc.tank) or sc.tank:isDestroyed() then return end
    if sc.savedDrawBodies ~= nil then
        state.world.debugDrawBodies = sc.savedDrawBodies
        sc.savedDrawBodies = nil
    end
    if sc.fluid then
        if sc.points then fluid.drawPoints(sc.fluid) else fluid.draw(sc.fluid) end
    end
    drawTankPart(sc, -HALF_WIDTH - WALL, 0, HALF_WIDTH + WALL, WALL, WOOD)
    drawTankPart(sc, -HALF_WIDTH - WALL, -DEPTH, -HALF_WIDTH, 0, WOOD)
    drawTankPart(sc, HALF_WIDTH, -DEPTH, HALF_WIDTH + WALL, 0, WOOD)
end

local SLIDERS = {
    { key = 'gravity', min = 0.2, max = 2 },
    { key = 'damping', min = 0.85, max = 0.995 },
    { key = 'viscosity', min = 0, max = 0.6 },
    { key = 'cohesion', min = 0, max = 1.5 },
    { key = 'iterations', min = 1, max = 10, step = 1 },
    { key = 'push', min = 0, max = 3 },
    { key = 'density', min = 0.1, max = 4 },
    { key = 'opacity', min = 0, max = 1 },
}

function s.drawUI()
    local sc = state.waterjarScene
    if not (sc and sc.fluid and state.playMode) then return end
    local f = sc.fluid
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.print(string.format('%d points   step %.1f ms (%s)   a/d tip  drag stir  space pour  m b r v h',
        f.n, f.stepMs or 0, f.native and 'C' or 'Lua'), 20, 20)
    if not sc.showPanel then return end
    ui.startFrame()
    local BH, pad, colW = 34, 8, 360
    local rows = math.ceil(#SLIDERS / 2)
    local w = colW * 2 + pad * 3
    local h = (BH + pad) * rows + pad + 20
    local _, sh = love.graphics.getDimensions()
    local x0, y0 = 20, sh - h - 20
    sc.panelRect = { x0, y0, w, h }
    ui.panel(x0, y0, w, h, '•• water ••', function()
        local st = sc.settings
        local top = y0 + pad + 20
        for k, sl in ipairs(SLIDERS) do
            local x = x0 + pad + ((k - 1) % 2) * (colW + pad)
            local y = top + math.floor((k - 1) / 2) * (BH + pad)
            local v = ui.sliderWithInput('water' .. sl.key, x, y, 150, sl.min, sl.max, st[sl.key], nil, sl.step)
            if v and v ~= st[sl.key] then
                if sl.step then v = math.floor(v + 0.5) end
                st[sl.key] = v
                apply(sc)
            end
            ui.label(x + 250, y, sl.key)
        end
    end)
end

return s
