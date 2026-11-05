-- Snapshot: a pixel hash of every scene in scripts/ drawn by box2d-draw's drawWorld (the editor's body
-- and joint view, src/physics/box2d-draw.lua), once per VARIANT of the world settings it reads: dark and
-- light, fixtures and outlines on and off, joints and debug ids, the tex/body view and play mode (bodies
-- under their pictures skipped), Mipo bodies, and zoomed in (bodies off the canvas culled).
-- claudetools/snapshot.sh. Runs only when $SNAPSHOT_OUT is set.
if not love then return end
local out = os.getenv('SNAPSHOT_OUT')
if not out or out == '' then return end

local state = require('src.state')
local registry = require('src.registry')
local sceneIO = require('src.io')
local camera = require('src.camera')
local box2dDraw = require('src.physics.box2d-draw')

-- name, the drawOutline argument, the world settings (over the defaults), the zoom over framing it all
-- (zoomed in, it centres on the scene's middle body: the middle of the bounds is often empty)
local VARIANTS = {
    { 'default', true, {}, 1 },
    { 'joints+ids', true, { debugDrawJoints = true, showDebugIds = true }, 1 },
    { 'light, no fill, no outline', false, { darkMode = false, drawFixtures = false }, 1 },
    { 'outline off in settings', true, { drawOutline = false, debugAlpha = 0.5 }, 1 },
    { 'tex/body', true, { textureOrBody = true, debugDrawJoints = true }, 1 },
    { 'tex/body + mipo bodies', true, { textureOrBody = true, mipoBodies = true }, 1 },
    { 'play mode', true, { playMode = true }, 1 },
    { 'joints only', true, { debugDrawBodies = false, debugDrawJoints = true }, 1 },
    { 'zoomed in', true, { debugDrawJoints = true }, 4 },
}
local WORLD_KEYS = { 'debugDrawJoints', 'showDebugIds', 'darkMode', 'drawFixtures', 'drawOutline', 'debugAlpha',
                     'textureOrBody', 'mipoBodies', 'debugDrawBodies', 'showTextures' }

love.mouse.getPosition = function() return 0, 0 end
local function scenes()
    local list = {}
    for _, scene in ipairs(require('src.scene-catalog').list()) do
        if scene.path then list[#list + 1] = scene.path end
    end
    table.sort(list)
    return list
end

local function bounds(world)
    local x1, y1, x2, y2 = math.huge, math.huge, -math.huge, -math.huge
    for _, body in ipairs(world:getBodies()) do
        local x, y = body:getPosition()
        x1, y1, x2, y2 = math.min(x1, x), math.min(y1, y), math.max(x2, x), math.max(y2, y)
    end
    return x1, y1, x2, y2
end

-- what no saved scene has but drawWorld still draws: an edge and a chain shape, a pulley joint, a
-- 'connector' fixture, a typed fixture (orange), a revolute joint with limits, a prismatic one with limits,
-- a wheel joint, an offset circle
local function syntheticWorld(world)
    local P = love.physics
    local ground = P.newBody(world, 0, 400, 'static')
    P.newFixture(ground, P.newEdgeShape(-400, 0, 400, 0))
    P.newFixture(ground, P.newChainShape(false, -300, -50, -200, -20, -100, -60, 0, -10))
    local a, b = P.newBody(world, -150, 0, 'dynamic'), P.newBody(world, 150, 0, 'dynamic')
    P.newFixture(a, P.newRectangleShape(60, 60))
    P.newFixture(b, P.newRectangleShape(60, 60))
    P.newPulleyJoint(a, b, -150, -200, 150, -200, -150, 0, 150, 0, 1)
    local c = P.newBody(world, 0, 150, 'dynamic')
    P.newFixture(c, P.newRectangleShape(80, 40)):setUserData({ bodyType = 'connector' })
    P.newFixture(c, P.newCircleShape(30, 10, 20))
    local d = P.newBody(world, 0, 250, 'dynamic')
    P.newFixture(d, P.newRectangleShape(40, 40)):setUserData({ type = 'sfixture', id = 'synthetic-d' })
    local r = P.newRevoluteJoint(c, d, 0, 200)
    r:setLimits(-0.5, 0.8)
    r:setLimitsEnabled(true)
    local e = P.newBody(world, 250, 250, 'dynamic')
    P.newFixture(e, P.newRectangleShape(30, 30))
    local pr = P.newPrismaticJoint(d, e, 250, 250, 1, 0)
    pr:setLimits(-40, 60)
    pr:setLimitsEnabled(true)
    local w = P.newBody(world, -250, 250, 'dynamic')
    P.newFixture(w, P.newCircleShape(25))
    P.newWheelJoint(d, w, -250, 250, 0, 1)
end

describe('outline snapshot', function()
    it('hashes every scene in every variant', function()
        local lines = {}
        local W, H = 800, 600
        local saved, savedPlay = {}, state.playMode
        for _, k in ipairs(WORLD_KEYS) do saved[k] = state.world[k] end
        local font = love.graphics.newFont(12) -- the debug ids: the same font every run
        local list = scenes()
        list[#list + 1] = 'synthetic'
        for _, path in ipairs(list) do
            local world = love.physics.newWorld(0, 0, true)
            state.physicsWorld = world
            registry.reset()
            state.backdrops = {}
            math.randomseed(1); love.math.setRandomSeed(1)
            local ok, err
            if path == 'synthetic' then ok, err = pcall(syntheticWorld, world)
            else ok, err = pcall(sceneIO.load, love.filesystem.read(path), world, camera.getInstance()) end
            if ok then
                local x1, y1, x2, y2 = bounds(world)
                local fit = math.min(W / math.max(x2 - x1 + 600, 1), H / math.max(y2 - y1 + 600, 1))
                local hashes = {}
                for _, variant in ipairs(VARIANTS) do
                    local _, drawOutline, settings, zoom = variant[1], variant[2], variant[3], variant[4]
                    for _, k in ipairs(WORLD_KEYS) do state.world[k] = saved[k] end
                    state.playMode = settings.playMode or false
                    for k, v in pairs(settings) do if k ~= 'playMode' then state.world[k] = v end end
                    local canvas = love.graphics.newCanvas(W, H)
                    love.graphics.setCanvas({ canvas, stencil = true })
                    love.graphics.clear(0, 0, 0, 1)
                    love.graphics.setFont(font)
                    -- a canvas pixel wide at any scale: drawWorld uses the width it's given, and a 1-wide
                    -- line drawn under a scale below 1 lights no pixel at all (the outlines and joints
                    -- were invisible in most scenes, so a change to them showed nothing)
                    love.graphics.setLineWidth(1 / (fit * zoom))
                    love.graphics.push()
                    love.graphics.translate(W / 2, H / 2)
                    love.graphics.scale(fit * zoom)
                    local bodies = world:getBodies()
                    if zoom > 1 and #bodies > 0 then
                        local cx, cy = bodies[math.ceil(#bodies / 2)]:getPosition()
                        love.graphics.translate(-cx, -cy)
                    else
                        love.graphics.translate(-(x1 + x2) / 2, -(y1 + y2) / 2)
                    end
                    local drew, derr = pcall(box2dDraw.drawWorld, world, drawOutline)
                    love.graphics.pop()
                    love.graphics.setCanvas()
                    love.graphics.setColor(1, 1, 1, 1)
                    hashes[#hashes + 1] = drew and love.data.encode('string', 'hex',
                        love.data.hash('md5', canvas:newImageData():getString())):sub(1, 12)
                        or ('ERR ' .. tostring(derr):sub(1, 60))
                    canvas:release()
                end
                lines[#lines + 1] = path .. ' ' .. #world:getBodies() .. ' ' .. table.concat(hashes, ' ')
            else
                lines[#lines + 1] = path .. ' LOADERR ' .. tostring(err):sub(1, 80)
            end
            for _, body in ipairs(world:getBodies()) do body:setUserData(nil) end
            world:setCallbacks()
            world:destroy()
            registry.reset()
        end
        for _, k in ipairs(WORLD_KEYS) do state.world[k] = saved[k] end
        state.playMode = savedPlay
        local header = {}
        for i, v in ipairs(VARIANTS) do header[i] = v[1] end
        local f = assert(io.open(out, 'w'))
        f:write('-- variants: ', table.concat(header, ' | '), '\n', table.concat(lines, '\n'), '\n')
        f:close()
    end)
end)
