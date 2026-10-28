-- claudetools/make-door-rooms.lua
-- Builds the test rooms for docs/WORLDS-AND-DOORS.md (W1) and writes them to
-- scripts/: a wide overworld with two doors and a Mipo, and two rooms behind
-- them (bakery, treehouse), each with a 'front' door back out.
-- Run with: love . --specs claudetools/make-door-rooms.lua
-- (a busted file so it runs headless in LÖVE; it overwrites the three scenes.)

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local objectManager = require('src.object-manager')
local sceneIO = require('src.io')
local camera = require('src.camera')
local props = require('src.props')
local json = require('vendor.dkjson')

local FLOOR_Y = 600

local function static(shape, x, y, w, h, label)
    return objectManager.addThing(shape, { x = x, y = y, width = w, height = h, bodyType = 'static', label = label })
end

-- A door: a static sensor box with a DOOR behavior, standing on the floor.
local function door(x, name, to, arrive)
    local w, h = 300, 600 -- a Mipo at scale 0.3 is about 600 tall
    local thing = static('rectangle', x, FLOOR_Y - 50 - h / 2, w, h, 'door ' .. name)
    for _, fixture in ipairs(thing.body:getFixtures()) do
        if not fixture:getUserData() then fixture:setSensor(true) end
    end
    thing.behaviors = { { name = 'DOOR', door = name, to = to, arrive = arrive } }
    return thing
end

local function mipo(x)
    local CM = require('src.character-manager')
    local instance = CM.createCharacter('humanoid', x, FLOOR_Y - 400, 0.3)
    CM.randomizeMipo(instance)
    CM.poseTpose(instance)
    return instance
end

-- A room: floor, two walls and a ceiling around [left, right].
local function box(left, right, height)
    local width = right - left
    local cx = (left + right) / 2
    static('rectangle', cx, FLOOR_Y, width + 200, 100, 'floor')
    static('rectangle', left - 50, FLOOR_Y - height / 2, 100, height + 100, 'wall')
    static('rectangle', right + 50, FLOOR_Y - height / 2, 100, height + 100, 'wall')
    static('rectangle', cx, FLOOR_Y - height - 50, width + 200, 100, 'ceiling')
end

local function save(name, camX, camY)
    local cam = camera.getInstance()
    cam:setTranslation(camX, camY)
    local data = sceneIO.gatherSaveData(state.physicsWorld, cam)
    local path = love.filesystem.getWorkingDirectory() .. '/scripts/' .. name .. '.playtime.json'
    local f = assert(io.open(path, 'w'))
    f:write(json.encode(data, { indent = true }))
    f:close()
    print('wrote ' .. path .. ' (' .. #data.bodies .. ' bodies, ' .. #(data.characters or {}) .. ' mipos)')
end

describe('door rooms', function()
    local world

    before_each(function()
        world = love.physics.newWorld(0, 9.81 * 100, true)
        state.physicsWorld = world
        registry.reset()
    end)

    after_each(function()
        world:destroy()
    end)

    it('overworld: a wide strip, two doors, a Mipo', function()
        -- the ground runs far both ways; hills are just boxes for now
        static('rectangle', 0, FLOOR_Y, 8000, 100, 'ground')
        static('rectangle', -1600, FLOOR_Y - 120, 600, 140, 'hill')
        static('rectangle', 1900, FLOOR_Y - 90, 500, 80, 'hill')
        -- houses: a wall behind each door (decoration, a sensor too)
        for _, x in ipairs({ -900, 1100 }) do
            local house = static('rectangle', x, FLOOR_Y - 50 - 400, 800, 800, 'house')
            for _, fixture in ipairs(house.body:getFixtures()) do fixture:setSensor(true) end
        end
        door(-900, 'bakery', 'bakery', 'front')
        door(1100, 'treehouse', 'treehouse', 'front')
        props.makeBall(200, FLOOR_Y - 200, 80, { squishy = true })
        mipo(-300)
        save('overworld', -300, FLOOR_Y - 400)
    end)

    it('bakery: a room with a door back out and some toys', function()
        box(-1100, 1100, 1100)
        door(-800, 'front', 'overworld', 'bakery')
        props.makeBall(0, FLOOR_Y - 300, 70, { squishy = true })
        props.makeSnapBlock(300, FLOOR_Y - 200, 1)
        props.makeSnapBlock(420, FLOOR_Y - 200, 1)
        static('rectangle', 500, FLOOR_Y - 150, 400, 40, 'counter')
        save('bakery', 0, FLOOR_Y - 500)
    end)

    it('treehouse: a tall room with a door back out', function()
        box(-700, 700, 1900)
        door(0, 'front', 'overworld', 'treehouse')
        static('rectangle', -400, FLOOR_Y - 700, 500, 40, 'branch')
        static('rectangle', 400, FLOOR_Y - 1200, 500, 40, 'branch')
        props.makeBall(-400, FLOOR_Y - 900, 60, { squishy = true })
        save('treehouse', 0, FLOOR_Y - 900)
    end)
end)
