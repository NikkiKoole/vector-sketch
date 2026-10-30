-- Snapshot: 6 seeded Mipos through the character-manager API (new, randomized, part by part,
-- mutated, saved and loaded): every body, fixture and joint, the DNA and a pixel hash.
-- claudetools/snapshot.sh. Runs only when $SNAPSHOT_OUT is set.
if not love then return end
local out = os.getenv('SNAPSHOT_OUT')
if not out or out == '' then return end

local CM = require('src.character-manager')
local registry = require('src.registry')
local state = require('src.state')
local box2dDrawTextured = require('src.physics.box2d-draw-textured')

local function num(v) return string.format('%.4f', v) end

local function dump(v, seen, depth)
    local t = type(v)
    if t == 'number' then return num(v) end
    if t == 'string' then return string.format('%q', v) end
    if t == 'boolean' or t == 'nil' then return tostring(v) end
    if t ~= 'table' then return '<' .. t .. '>' end
    if seen[v] or depth > 8 then return '<seen>' end
    seen[v] = true
    local keys = {}
    for k in pairs(v) do
        if k ~= 'id' and k ~= 'mipoId' and k ~= 'resourceId' and k ~= 'nodeId' then keys[#keys + 1] = k end
    end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    for _, k in ipairs(keys) do parts[#parts + 1] = tostring(k) .. '=' .. dump(v[k], seen, depth + 1) end
    seen[v] = nil
    return '{' .. table.concat(parts, ',') .. '}'
end

local function bodyKey(body)
    local ud = body:getUserData()
    local thing = ud and ud.thing
    return (thing and (thing.mipoPartName or thing.label) or '?') .. string.format('@%.2f,%.2f', body:getPosition())
end

local function worldDump(world)
    local lines = {}
    for _, body in ipairs(world:getBodies()) do
        local fx = {}
        for _, f in ipairs(body:getFixtures()) do
            local ud = f:getUserData()
            local shape = f:getShape()
            local pts = shape.getPoints and { shape:getPoints() } or { shape:getRadius() }
            fx[#fx + 1] = dump({ ud = type(ud) == 'table' and ud or nil, pts = pts, sensor = f:isSensor(),
                density = f:getDensity(), friction = f:getFriction(), group = f:getGroupIndex() }, {}, 0)
        end
        table.sort(fx)
        local thing = body:getUserData() and body:getUserData().thing
        lines[#lines + 1] = bodyKey(body) .. ' a=' .. num(body:getAngle()) .. ' m=' .. num(body:getMass())
            .. ' thing=' .. dump(thing and { label = thing.label, shapeType = thing.shapeType, vertices = thing.vertices,
                behaviors = thing.behaviors, zOffset = thing.zOffset } or nil, {}, 0)
            .. ' fx=' .. table.concat(fx, ';')
    end
    for _, joint in ipairs(world:getJoints()) do
        local a, b = joint:getBodies()
        local x1, y1, x2, y2 = joint:getAnchors()
        lines[#lines + 1] = 'J ' .. joint:getType() .. ' ' .. bodyKey(a) .. ' ' .. bodyKey(b)
            .. ' ' .. num(x1) .. ',' .. num(y1) .. ',' .. num(x2) .. ',' .. num(y2)
    end
    table.sort(lines)
    return lines
end

local function pixels(world)
    local W, H = 600, 600
    local canvas = love.graphics.newCanvas(W, H)
    love.graphics.setCanvas({ canvas, stencil = true })
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.push()
    love.graphics.translate(W / 2, H / 2)
    love.graphics.scale(0.5)
    local ok, err = pcall(box2dDrawTextured.drawTexturedWorld, world)
    love.graphics.pop()
    love.graphics.setCanvas()
    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1, 1)
    local hash = ok and love.data.encode('string', 'hex', love.data.hash('md5', canvas:newImageData():getString()))
        or ('ERR ' .. tostring(err))
    canvas:release()
    return hash
end

describe('mipo snapshot', function()
    it('records seeded Mipos', function()
        local lines = {}
        local function record(tag, world)
            lines[#lines + 1] = '## ' .. tag .. ' pixels ' .. pixels(world)
            for _, l in ipairs(worldDump(world)) do lines[#lines + 1] = l end
            lines[#lines + 1] = 'DNA ' .. dump(CM.serializeCharacters(), {}, 0)
        end
        for seed = 1, 6 do
            local world = love.physics.newWorld(0, 0, true)
            state.physicsWorld = world
            registry.reset()
            require('src.mipo-registry').reset()
            math.randomseed(seed); love.math.setRandomSeed(seed)
            local mipo = CM.createCharacter('humanoid', 0, 0, 1)
            record(seed .. ' new', world)
            if seed % 2 == 0 then CM.randomizeMipo(mipo) else CM.randomizeMipoConstrained(mipo) end
            record(seed .. ' randomized', world)
            for _, part in ipairs({ 'head', 'torso1', 'lear', 'lfoot', 'lhand', 'luarm', 'luleg' }) do
                CM.randomizePart(mipo, part)
            end
            record(seed .. ' parts', world)
            CM.mutateSizes(mipo)
            CM.rebuildFromCreation(mipo, { isPotatoHead = not mipo.dna.creation.isPotatoHead })
            CM.updateFaceOfPart(mipo, mipo.dna.creation.isPotatoHead and 'torso1' or 'head', { eyeWidthMultiplier = 1.3 })
            CM.rebuildTextures(mipo)
            record(seed .. ' mutated', world)
            local json = require('vendor.dkjson')
            local sceneIO = require('src.io')
            local s0 = { x = 0, y = 0, scale = 1 }
            local cam = {}
            function cam:getTranslation() return s0.x, s0.y end
            function cam:getRotation() return 0 end
            function cam:getScale() return s0.scale end
            function cam:setTranslation(x, y) s0.x = x; s0.y = y end
            function cam:setScale(v) s0.scale = v end
            local saved = json.decode(json.encode(sceneIO.gatherSaveData(world, cam)))
            for _, body in ipairs(world:getBodies()) do body:setUserData(nil) end
            world:setCallbacks()
            world:destroy()
            world = love.physics.newWorld(0, 0, true)
            state.physicsWorld = world
            registry.reset()
            require('src.mipo-registry').reset()
            sceneIO.buildWorld(saved, world, cam)
            record(seed .. ' reloaded', world)
            for _, body in ipairs(world:getBodies()) do body:setUserData(nil) end
            world:setCallbacks()
            world:destroy()
            registry.reset()
            require('src.mipo-registry').reset()
        end
        local f = assert(io.open(out, 'w'))
        f:write(table.concat(lines, '\n'), '\n')
        f:close()
    end)
end)
