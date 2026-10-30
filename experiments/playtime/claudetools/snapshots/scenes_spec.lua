-- Snapshot: a pixel hash of every scene in scripts/ (and knut/, tech/) drawn by drawTexturedWorld,
-- framed on all its bodies. Take one before a refactor and one after: claudetools/snapshot.sh.
-- Only the textured draw (not the editor overlay). Runs only when $SNAPSHOT_OUT is set.
if not love then return end
local out = os.getenv('SNAPSHOT_OUT')
if not out or out == '' then return end

local state = require('src.state')
local registry = require('src.registry')
local sceneIO = require('src.io')
local camera = require('src.camera')
local box2dDrawTextured = require('src.physics.box2d-draw-textured')

-- Mipo eyes without a gaze target follow the mouse (lookAtMouse): pin it, or where the mouse
-- happens to be changes the pupils between runs
love.mouse.getPosition = function() return 0, 0 end
local function scenes()
    local list = {}
    for _, dir in ipairs({ 'scripts', 'scripts/knut', 'scripts/tech' }) do
        for _, name in ipairs(love.filesystem.getDirectoryItems(dir)) do
            if name:match('%.playtime%.json$') then list[#list + 1] = dir .. '/' .. name end
        end
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

describe('render snapshot', function()
    it('hashes every scene', function()
        local lines = {}
        local W, H = 800, 600
        for _, path in ipairs(scenes()) do
            local world = love.physics.newWorld(0, 0, true)
            state.physicsWorld = world
            registry.reset()
            state.backdrops = {}
            math.randomseed(1); love.math.setRandomSeed(1)
            local ok, err = pcall(sceneIO.load, love.filesystem.read(path), world, camera.getInstance())
            if ok then
                local x1, y1, x2, y2 = bounds(world)
                local s = math.min(W / math.max(x2 - x1 + 600, 1), H / math.max(y2 - y1 + 600, 1))
                -- bake the OMP pictures first, as love.draw does (else most parts aren't drawn), before
                -- our canvas is set: the bake leaves no canvas set
                box2dDrawTextured.makeCombinedImages()
                local canvas = love.graphics.newCanvas(W, H)
                love.graphics.setCanvas({ canvas, stencil = true })
                love.graphics.clear(0, 0, 0, 1)
                love.graphics.push()
                love.graphics.translate(W / 2, H / 2)
                love.graphics.scale(s)
                love.graphics.translate(-(x1 + x2) / 2, -(y1 + y2) / 2)
                local drew, derr = pcall(box2dDrawTextured.drawTexturedWorld, world)
                love.graphics.pop()
                love.graphics.setCanvas()
                love.graphics.setShader()
                love.graphics.setColor(1, 1, 1, 1)
                local hash = drew and love.data.encode('string', 'hex',
                    love.data.hash('md5', canvas:newImageData():getString())) or ('ERR ' .. tostring(derr))
                canvas:release()
                lines[#lines + 1] = path .. ' ' .. #world:getBodies() .. ' ' .. hash
            else
                lines[#lines + 1] = path .. ' LOADERR ' .. tostring(err):sub(1, 80)
            end
            for _, body in ipairs(world:getBodies()) do body:setUserData(nil) end
            world:setCallbacks()
            world:destroy()
            registry.reset()
        end
        local f = assert(io.open(out, 'w'))
        f:write(table.concat(lines, '\n'), '\n')
        f:close()
    end)
end)
