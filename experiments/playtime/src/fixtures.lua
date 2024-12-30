--fixtures.lua


local mathutils = require 'src.math-utils'
local uuid = require 'src.uuid'

local registry = require 'src.registry'
local lib = {}


function lib.hasFixturesWithUserDataAtBeginning(fixtures)
    -- first we will start looking from beginning untill we no longer find userdata on fixtures
    -- then we will start looking fom that index on and expect not to found any more userdata
    local found = true
    local index = 0
    for i = 1, #fixtures do
        if found then
            if fixtures[i]:getUserData() then
                index = i
            else
                found = false
            end
        end
        if not found then
            if fixtures[i]:getUserData() then
                return false, -1
            else

            end
        end
    end
    return true, index
end

function lib.getCentroidOfFixture(body, fixture)
    return { mathutils.getCenterOfPoints({ fixture:getShape():getPoints() }) }
end

local function rect(w, h, x, y)
    return {
        x - w / 2, y - h / 2,
        x + w / 2, y - h / 2,
        x + w / 2, y + h / 2,
        x - w / 2, y + h / 2
    }
end
function lib.createSFixture(body, localX, localY, radius)
    local shape = love.physics.newPolygonShape(rect(radius, radius, localX, localY))
    local fixture = love.physics.newFixture(body, shape)
    fixture:setSensor(true) -- Sensor so it doesn't collide
    local setId = uuid.generateID()
    fixture:setUserData({ type = "sfixture", id = setId, extra = {} })

    registry.registerSFixture(setId, fixture)
    return fixture
end

return lib
