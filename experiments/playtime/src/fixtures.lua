--fixtures.lua

local logger = require 'src.logger'
local inspect = require 'vendor.inspect'
local mathutils = require 'src.math-utils'
local shapes = require 'src.shapes'
local uuid = require 'src.uuid'

local registry = require 'src.registry'
local utils = require 'src.utils' -- Needed for shallowCopy
local fixtureTypes = require('src.fixture-types')
local subtypes = require('src.subtypes')
local lib = {}

-- The userData of every sfixture of this subtype on the body (those with an `extra`).
function lib.sfixtureData(body, subtype)
    local found = {}
    for _, fixture in ipairs(body:getFixtures()) do
        local ud = fixture:getUserData()
        if type(ud) == 'table' and subtypes.is(ud, subtype) and ud.extra then
            found[#found + 1] = ud
        end
    end
    return found
end

-- A new shape (body-local polygon `points`) for an sfixture. A Box2D fixture can't change
-- shape, so a new one takes its place: same userData (or `ud`) and id in the registry,
-- still a sensor, same density, friction, restitution and group. Returns the new fixture.
function lib.replaceShape(fixture, points, ud)
    ud = ud or fixture:getUserData()
    local body = fixture:getBody()
    local density, friction = fixture:getDensity(), fixture:getFriction()
    local restitution, groupIndex = fixture:getRestitution(), fixture:getGroupIndex()
    fixture:destroy()
    local newFixture = love.physics.newFixture(body, love.physics.newPolygonShape(points), density)
    newFixture:setSensor(true)
    newFixture:setFriction(friction)
    newFixture:setRestitution(restitution)
    newFixture:setGroupIndex(groupIndex)
    newFixture:setUserData(ud)
    registry.registerSFixture(ud.id, newFixture)
    return newFixture
end

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
    local points = oldUD.extra.vertices or
        { sfixture:getShape():getPoints() } -- Existing local points
    local centerX, centerY = mathutils.getCenterOfPoints(points)

    -- Points relative to old center
    local relativePoints = mathutils.makePolygonRelativeToCenter(points, centerX, centerY)

    -- Create new absolute points centered at the *new* local click position
    local newShapePoints = mathutils.makePolygonAbsolute(relativePoints, localX, localY)

    local dx, dy = centerX - localX, centerY - localY

    -- Use deepCopy if 'extra' might contain tables

    if oldUD.extra and oldUD.extra.vertices then
        for i = 1, #oldUD.extra.vertices, 2 do
            oldUD.extra.vertices[i + 0] = oldUD.extra.vertices[i + 0] - dx
            oldUD.extra.vertices[i + 1] = oldUD.extra.vertices[i + 1] - dy
        end
    end
    return lib.replaceShape(sfixture, newShapePoints, oldUD)
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
        if not found and fixtures[i]:getUserData() then
            return false, -1
        end
    end
    return true, index
end

function lib.getCentroidOfFixture(_body, fixture)
    return { mathutils.getCenterOfPoints({ fixture:getShape():getPoints() }) }
end

local rect = shapes.rect
local rect8 = fixtureTypes.rect8

function lib.destroyFixture(fixture)
    registry.unregisterSFixture(fixture:getUserData().id)
    fixture:destroy()
end

-- A w x h rectangle (8 corners if extra.vertexCount says so) where the sfixture is now.
function lib.updateSFixtureDimensions(fixture, w, h)
    local centerX, centerY = mathutils.getCenterOfPoints({ fixture:getShape():getPoints() })
    local ud = utils.shallowCopy(fixture:getUserData())
    local vertices = ud.extra.vertexCount == 8 and rect8(w, h, centerX, centerY) or rect(w, h, centerX, centerY)
    ud.extra.vertices = vertices
    return lib.replaceShape(fixture, vertices, ud)
end

function lib.createSFixture(body, localX, localY, subtype, cfg)
    local ft = fixtureTypes[subtype]
    if not ft then
        logger:info('Unknown fixture subtype:', subtype, inspect(cfg))
        return
    end

    local w, h = ft.getSize(cfg)
    local shape = love.physics.newPolygonShape(rect(w, h, localX, localY))
    local fixture = love.physics.newFixture(body, shape, ft.density or 0) -- sensors weigh nothing
    fixture:setSensor(true)
    local setId = uuid.generateID()
    local extra = ft.getExtra(cfg, localX, localY)
    fixture:setUserData({ type = "sfixture", subtype = subtype, id = setId, label = '', extra = extra })
    registry.registerSFixture(setId, fixture)
    return fixture
end

-- Build a vertIndex -> world (x, y) mapper for a MESHUSERT mesh preview:
-- centered mesh verts transformed by the sfixture's meshX/Y, scaleX/Y and
-- meshRot, then into the owning body's world space. Shared by the triangle
-- editor's hit-testing (input-manager) and its overlay (editor-render).
function lib.makeMeshVertexMapper(extra, centeredVerts, body)
    local mx = extra.meshX or 0
    local my = extra.meshY or 0
    local sx = extra.scaleX or 1
    local sy = extra.scaleY or 1
    local mr = extra.meshRot or 0
    local cosR, sinR = math.cos(mr), math.sin(mr)
    return function(vertIndex)
        local lx = centeredVerts[(vertIndex - 1) * 2 + 1]
        local ly = centeredVerts[(vertIndex - 1) * 2 + 2]
        lx = (lx + mx) * sx
        ly = (ly + my) * sy
        if mr ~= 0 then
            lx, ly = lx * cosR - ly * sinR, lx * sinR + ly * cosR
        end
        return body:getWorldPoint(lx, ly)
    end
end

return lib
