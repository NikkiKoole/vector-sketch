--fixtures.lua


local mathutils = require 'src.math-utils'
local uuid = require 'src.uuid'

local registry = require 'src.registry'
local utils = require 'src.utils' -- Needed for shallowCopy

local lib = {}


-- Updates the position of an sfixture based on a new WORLD coordinate click
function lib.updateSFixturePosition(sfixture, worldX, worldY)
    if not sfixture or sfixture:isDestroyed() then
        logger:error("WARN: updateSFixturePosition called on invalid sfixture"); return nil
    end

    local body = sfixture:getBody()
    if not body or body:isDestroyed() then
        logger:error("WARN: updateSFixturePosition called on sfixture with invalid body"); return nil
    end

    -- Convert world click to body's local coordinates for the new shape center
    local localX, localY = body:getLocalPoint(worldX, worldY)

    local points = { sfixture:getShape():getPoints() }                                     -- Existing local points
    local centerX, centerY = mathutils.getCenterOfPoints(points)                           -- Center of existing shape
    local relativePoints = mathutils.makePolygonRelativeToCenter(points, centerX, centerY) -- Points relative to old center

    -- Create new absolute points centered at the *new* local click position
    local newShapePoints = mathutils.makePolygonAbsolute(relativePoints, localX, localY)

    local oldUD = utils.deepCopy(sfixture:getUserData()) -- Use deepCopy if 'extra' might contain tables
    local fixtureID = oldUD.id                           -- Keep the ID
    local fixtureDensity = sfixture:getDensity()         -- Keep properties
    local fixtureFriction = sfixture:getFriction()
    local fixtureRestitution = sfixture:getRestitution()
    local fixtureGroupIndex = sfixture:getGroupIndex()

    logger:info(string.format("Updating SFixture %s Position to World(%.2f, %.2f) -> Local(%.2f, %.2f)", fixtureID,
        worldX,
        worldY, localX, localY))

    -- Destroy old fixture and unregister
    sfixture:destroy()
    registry.unregisterSFixture(fixtureID)

    -- Create the new shape and fixture
    local shape = love.physics.newPolygonShape(newShapePoints)
    local newfixture = love.physics.newFixture(body, shape, fixtureDensity)
    newfixture:setSensor(true) -- Ensure it remains a sensor
    newfixture:setFriction(fixtureFriction)
    newfixture:setRestitution(fixtureRestitution)
    newfixture:setGroupIndex(fixtureGroupIndex)
    newfixture:setUserData(oldUD)                    -- Reuse the userdata (including the ID)

    registry.registerSFixture(fixtureID, newfixture) -- Register the new fixture with the *same* ID

    return newfixture
end

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


function lib.destroyFixture(fixture)
    registry.unregisterSFixture(fixture:getUserData().id)
    fixture:destroy()
end

function lib.createSFixture(body, localX, localY, cfg)
    if (cfg.label == 'snap') then
        local shape = love.physics.newPolygonShape(rect(cfg.radius, cfg.radius, localX, localY))
        local fixture = love.physics.newFixture(body, shape)
        fixture:setSensor(true) -- Sensor so it doesn't collide
        local setId = uuid.generateID()
        fixture:setUserData({ type = "sfixture", id = setId, label = cfg.label, extra = {} })
        registry.registerSFixture(setId, fixture)
        return fixture
    end
    if (cfg.label == 'texfixture') then
        local shape = love.physics.newPolygonShape(rect(cfg.width, cfg.height, localX, localY))
        local fixture = love.physics.newFixture(body, shape, 0)
        fixture:setSensor(true) -- Sensor so it doesn't collide
        local setId = uuid.generateID()
        fixture:setUserData({ type = "sfixture", id = setId, label = '', extra = { type = 'texfixture' } })
        registry.registerSFixture(setId, fixture)
        return fixture
    end
    logger:info('I NEED A BETTER CONFIG FOR THIS FIXTURE OF YOURS!')
end

return lib
