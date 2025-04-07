--fixtures.lua


local mathutils = require 'src.math-utils'
local uuid = require 'src.uuid'

local registry = require 'src.registry'
local utils = require 'src.utils' -- Needed for shallowCopy
local state= require 'src.state'
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
      local oldUD = utils.deepCopy(sfixture:getUserData())
    --  logger:info(oldUD.extra.vertices ,  { sfixture:getShape():getPoints() })
    local points = oldUD.extra.vertices or  { sfixture:getShape():getPoints() }                                     -- Existing local points
    local centerX, centerY = mathutils.getCenterOfPoints(points)

    local relativePoints = mathutils.makePolygonRelativeToCenter(points, centerX, centerY) -- Points relative to old center

    -- Create new absolute points centered at the *new* local click position
    local newShapePoints = mathutils.makePolygonAbsolute(relativePoints, localX, localY)

    local dx,dy = centerX-localX, centerY-localY

  -- Use deepCopy if 'extra' might contain tables

    if oldUD.extra and oldUD.extra.vertices then
       -- logger:info('vertices found, need to adjust all of them:',#oldUD.extra.vertices,dx,dy)
       -- logger:info(inspect(oldUD.extra.vertices))
        for i =  1, #oldUD.extra.vertices,2 do
            oldUD.extra.vertices[i+0] = oldUD.extra.vertices[i+0]-dx
            oldUD.extra.vertices[i+1] = oldUD.extra.vertices[i+1]-dy
        end
      --  logger:info(inspect(oldUD.extra.vertices))
    end
    local fixtureID = oldUD.id                           -- Keep the ID
    local fixtureDensity = sfixture:getDensity()         -- Keep properties
    local fixtureFriction = sfixture:getFriction()
    local fixtureRestitution = sfixture:getRestitution()
    local fixtureGroupIndex = sfixture:getGroupIndex()

    -- logger:info(string.format("Updating SFixture %s Position to World(%.2f, %.2f) -> Local(%.2f, %.2f)", fixtureID,
    --     worldX,
    --     worldY, localX, localY))

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

local function rect8(w, h, x, y)
    return {
        x - w / 2, y - h / 2,
        x , y - h / 2,
        x + w / 2, y - h / 2,
        x + w / 2, y ,
        x + w / 2, y + h / 2,
        x , y + h / 2,
        x - w / 2, y + h / 2,
        x - w/2, y ,
    }
end



function lib.destroyFixture(fixture)
    registry.unregisterSFixture(fixture:getUserData().id)
    fixture:destroy()
end

function lib.updateSFixtureDimensionsFunc(w, h)
    local points = { state.selection.selectedSFixture:getShape():getPoints() }
    local oldUD = utils.shallowCopy(state.selection.selectedSFixture:getUserData())
    local body = state.selection.selectedSFixture:getBody()
    state.selection.selectedSFixture:destroy()

    local centerX, centerY = mathutils.getCenterOfPoints(points)
    local vv = oldUD.extra.vertexCount == 8 and rect8(w, h, centerX, centerY) or rect(w, h, centerX, centerY)
    local shape = love.physics.newPolygonShape(vv)
    local newfixture = love.physics.newFixture(body, shape)
    oldUD.extra.vertices = vv
    newfixture:setSensor(true) -- Sensor so it doesn't collide
    newfixture:setUserData(oldUD)

    state.selection.selectedSFixture = newfixture
    --snap.updateFixture(newfixture)
    registry.registerSFixture(oldUD.id, newfixture)

    return newfixture
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
        local vertexCount = 4
        --
        local vv =vertexCount == 4 and rect(cfg.width, cfg.height, localX, localY) or  rect8(cfg.width, cfg.height, localX, localY)
        local shape = love.physics.newPolygonShape(vv)

        local fixture = love.physics.newFixture(body, shape, 0)
        fixture:setSensor(true) -- Sensor so it doesn't collide
        local setId = uuid.generateID()
        fixture:setUserData({ type = "sfixture", id = setId, label = '', extra = { vertexCount=vertexCount, vertices=vv, type = 'texfixture' } })
        registry.registerSFixture(setId, fixture)
        return fixture
    end
    logger:info('I NEED A BETTER CONFIG FOR THIS FIXTURE OF YOURS!')
end

--function lib.createTexFixtureShape(vertexCount)

return lib
