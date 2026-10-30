-- spec/draw-cache_spec.lua
-- docs/MIPO-DRAWING.md L0 + L1: the renderer keeps its draw list, fans and strips between frames
-- and skips Mipos that are off screen. Whatever it keeps, a frame must look exactly like the same
-- frame drawn with every cache cleared, and culling must not change a pixel.
if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local sceneIO = require('src.io')
local camera = require('src.camera')
local CM = require('src.character-manager')
local utils = require('src.utils')
local draw = require('src.physics.box2d-draw-textured')

local W, H = 800, 600

local function render(world, cx, cy, scale)
    local canvas = love.graphics.newCanvas(W, H)
    love.graphics.setCanvas({ canvas, stencil = true })
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.push()
    love.graphics.translate(W / 2, H / 2)
    love.graphics.scale(scale)
    love.graphics.translate(-cx, -cy)
    local ok, err = pcall(draw.drawTexturedWorld, world)
    love.graphics.pop()
    love.graphics.setCanvas()
    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1, 1)
    assert(ok, tostring(err))
    local hash = love.data.encode('string', 'hex', love.data.hash('md5', canvas:newImageData():getString()))
    canvas:release()
    return hash
end

describe('drawing with caches (L1) and culling (L0)', function()
    local world, cx, cy, scale

    before_each(function()
        world = love.physics.newWorld(0, 0, true)
        state.physicsWorld = world
        registry.reset()
        require('src.mipo-registry').reset()
        state.backdrops = {}
        math.randomseed(3); love.math.setRandomSeed(3)
        sceneIO.load(love.filesystem.read('scripts/crowd.playtime.json'), world, camera.getInstance())
        local x1, y1, x2, y2 = math.huge, math.huge, -math.huge, -math.huge
        for _, body in ipairs(world:getBodies()) do
            local x, y = body:getPosition()
            x1, y1, x2, y2 = math.min(x1, x), math.min(y1, y), math.max(x2, x), math.max(y2, y)
        end
        cx, cy = (x1 + x2) / 2, (y1 + y2) / 2
        scale = math.min(W / (x2 - x1 + 800), H / (y2 - y1 + 800))
        draw.cull = true
        draw._test.clearCaches()
    end)

    after_each(function()
        draw.cull = true
        for _, body in ipairs(world:getBodies()) do body:setUserData(nil) end
        world:setCallbacks()
        world:destroy()
        registry.reset()
        require('src.mipo-registry').reset()
    end)

    -- a frame drawn with what the caches kept, and the same frame drawn from scratch
    local function keptAndFresh()
        local kept = render(world, cx, cy, scale)
        local keptOrder = draw._test.order()
        draw._test.clearCaches()
        local fresh = render(world, cx, cy, scale)
        assert.are.equal(draw._test.order(), keptOrder)
        assert.are.equal(fresh, kept)
    end

    it('follows bodies that moved and brows that bent', function()
        render(world, cx, cy, scale) -- fills the caches
        for i, body in ipairs(world:getBodies()) do
            local x, y = body:getPosition()
            body:setPosition(x + (i % 7) * 3, y - (i % 5) * 2)
            body:setAngle(body:getAngle() + (i % 3) * 0.05)
            local thing = utils.thingOf(body)
            if thing and (thing.mipoPartName == 'head' or thing.mipoPartName == 'torso1') then
                thing.lbrowVec, thing.rbrowVec = { 0.4, -0.3, 0.5 }, { -0.2, 0.3, 0.1 }
            end
        end
        keptAndFresh()
    end)

    it('follows a part moved to another z', function()
        render(world, cx, cy, scale)
        for _, fixture in pairs(registry.sfixtures) do
            local ud = fixture:getUserData()
            if ud.subtype == 'texfixture' and ud.extra.zOffset then ud.extra.zOffset = -ud.extra.zOffset end
        end
        keptAndFresh()
    end)

    it('follows a Mipo added and one taken away', function()
        render(world, cx, cy, scale)
        CM.createCharacter('humanoid', cx, cy, 1)
        local gone
        for _, instance in pairs(require('src.mipo-registry').getAll()) do gone = gone or instance end
        for _, part in pairs(gone.parts) do
            for _, fixture in ipairs(part.body:getFixtures()) do
                local ud = fixture:getUserData()
                if type(ud) == 'table' and ud.id then registry.unregisterSFixture(ud.id) end
            end
            part.body:destroy()
        end
        require('src.mipo-registry').unregister(gone.id)
        keptAndFresh()
    end)

    -- culled and not culled, the same picture, with the view at (x, y) and `zoom`
    local function sameCulled(x, y, zoom, what)
        draw.cull = true
        local culled = render(world, x, y, zoom)
        local skipped = draw._test.culled()
        draw.cull = false
        local all = render(world, x, y, zoom)
        assert.are.equal(all, culled, what)
        return skipped
    end

    it('culling off-screen Mipos changes no pixel, across the crowd', function()
        local zoom = scale * 4 -- a quarter of the crowd's width: most Mipos are off screen
        local skipped = 0
        for step = -4, 4 do
            skipped = skipped + sameCulled(cx + step * 400, cy + (step % 3 - 1) * 300, zoom, 'view ' .. step)
        end
        assert.is_true(skipped > 0, 'nothing was culled')
    end)

    it('culling keeps a Mipo whose body centres are just off screen but its picture is not', function()
        local zoom = 0.5
        local halfW, halfH = W / 2 / zoom, H / 2 / zoom
        local tried = 0
        for _, instance in pairs(require('src.mipo-registry').getAll()) do
            local x1, y1, x2, y2 = math.huge, math.huge, -math.huge, -math.huge
            for _, part in pairs(instance.parts) do
                local x, y = part.body:getPosition()
                x1, y1, x2, y2 = math.min(x1, x), math.min(y1, y), math.max(x2, x), math.max(y2, y)
            end
            local my, mx = (y1 + y2) / 2, (x1 + x2) / 2
            for _, d in ipairs({ 20, 100, 200, 350, 500 }) do
                sameCulled(x2 + d + halfW, my, zoom, 'left of view by ' .. d)  -- view starts right of it
                sameCulled(x1 - d - halfW, my, zoom, 'right of view by ' .. d) -- view ends left of it
                sameCulled(mx, y2 + d + halfH, zoom, 'above view by ' .. d)
                sameCulled(mx, y1 - d - halfH, zoom, 'below view by ' .. d)
            end
            tried = tried + 1
            if tried == 4 then break end
        end
    end)
end)
