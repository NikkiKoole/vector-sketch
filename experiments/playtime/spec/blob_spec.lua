-- spec/blob_spec.lua — the SOFTBODY sfixture (src/blob.lua): the rim is built from the
-- saved settings, never saved itself, and survives a save/load round trip, a body
-- removal and an editor move.
-- Run with: love . --specs spec/blob_spec.lua

if not love then return end

package.loaded['src.registry'] = nil
package.loaded['src.object-manager'] = nil
package.loaded['src.fixtures'] = nil
package.loaded['src.io'] = nil
package.loaded['src.state'] = nil
package.loaded['src.physics.snap'] = nil
package.loaded['src.blob'] = nil
package.loaded['src.props'] = nil

local registry = require('src.registry')
local objectManager = require('src.object-manager')
local sceneIO = require('src.io')
local state = require('src.state')
local blobs = require('src.blob')
local props = require('src.props')
local subtypes = require('src.subtypes')

local function makeWorld()
    return love.physics.newWorld(0, 9.81 * 100, true)
end

local function makeCam()
    local camState = { x = 0, y = 0, scale = 1 }
    return {
        getTranslation = function() return camState.x, camState.y end,
        getScale = function() return camState.scale end,
        getRotation = function() return 0 end,
        setTranslation = function(_, x, y) camState.x = x; camState.y = y end,
        setScale = function(_, s) camState.scale = s end,
    }
end

local function step(seconds)
    for _ = 1, math.floor(seconds * 60) do
        blobs.beforeStep(false)
        state.physicsWorld:update(1 / 60)
        blobs.afterStep()
    end
end

local function onlyRuntime()
    local found
    for _, rt in pairs(state.blobs) do
        assert.is_nil(found) -- exactly one
        found = rt
    end
    return found
end

local function rimArea(rt)
    local a, n = 0, #rt.nodes
    for i = 1, n do
        local x1, y1 = rt.nodes[i]:getPosition()
        local x2, y2 = rt.nodes[i % n + 1]:getPosition()
        a = a + x1 * y2 - x2 * y1
    end
    return a / 2
end

describe("blob (SOFTBODY sfixture)", function()
    before_each(function()
        state.physicsWorld = makeWorld()
        registry.reset()
        for id in pairs(state.blobs) do state.blobs[id] = nil end
    end)

    it("builds its rim from the settings, around an ordinary body", function()
        local thing = props.makeBlob(0, 0)
        assert.is_not_nil(thing)
        blobs.beforeStep(true)
        local rt = onlyRuntime()
        assert.are.equal(28, #rt.nodes)
        assert.are.equal(1 + 28, state.physicsWorld:getBodyCount())
        assert.are.equal(thing.body, rt.body)
        assert.are.equal(thing.body, blobs.ownerOf(rt.nodes[1]))
        assert.is_nil(blobs.ownerOf(thing.body))
    end)

    it("saves the body and its settings, not the rim", function()
        props.makeBlob(0, 0)
        blobs.beforeStep(true)
        local data = sceneIO.gatherSaveData(state.physicsWorld, makeCam())
        assert.are.equal(1, #data.bodies)
        assert.are.equal(0, #(data.joints or {}))
        local extra
        for _, f in ipairs(data.bodies[1].fixtures) do
            if f.userData and f.userData.subtype == subtypes.SOFTBODY then extra = f.userData.extra end
        end
        assert.is_not_nil(extra)
        assert.are.equal(28, extra.rimPoints)
        assert.is_nil(extra.nodes) -- io.lua reads extra.nodes as a ribbon's joints
        assert.is_true(extra.OMP)
        assert.is_not_nil(extra.main.bgURL)
    end)

    it("comes back after a save/load round trip", function()
        props.makeBlob(120, 340)
        blobs.beforeStep(true)
        local cam = makeCam()
        local data = sceneIO.gatherSaveData(state.physicsWorld, cam)

        local world2 = makeWorld()
        state.physicsWorld = world2
        registry.reset()
        sceneIO.buildWorld(data, world2, cam)
        blobs.beforeStep(true)

        local rt = onlyRuntime()
        assert.are.equal(28, #rt.nodes)
        assert.are.equal(1 + 28, world2:getBodyCount())
        local x, y = rt.body:getPosition()
        assert.is_near(120, x, 0.1)
        assert.is_near(340, y, 0.1)
    end)

    it("drops its rim when the body goes", function()
        local thing = props.makeBlob(0, 0)
        blobs.beforeStep(true)
        objectManager.destroyBody(thing.body)
        blobs.beforeStep(true)
        assert.are.equal(0, state.physicsWorld:getBodyCount())
        assert.is_nil(next(state.blobs))
    end)

    it("takes the rim along when the editor moves the body", function()
        local thing = props.makeBlob(0, 0)
        blobs.beforeStep(true)
        blobs.afterStep()
        local rt = onlyRuntime()
        local nx, ny = rt.nodes[1]:getPosition()
        thing.body:setPosition(500, 200)
        blobs.beforeStep(true)
        local mx, my = rt.nodes[1]:getPosition()
        assert.is_near(nx + 500, mx, 0.01)
        assert.is_near(ny + 200, my, 0.01)
    end)

    it("rebuilds the rim when the size changes", function()
        local thing = props.makeBlob(0, 0)
        blobs.beforeStep(true)
        local before = onlyRuntime()
        local beforeArea = math.abs(rimArea(before))
        for _, f in ipairs(thing.body:getFixtures()) do
            local ud = f:getUserData()
            if ud and ud.subtype == subtypes.SOFTBODY then ud.extra.height = 600 end
        end
        blobs.beforeStep(true)
        local after = onlyRuntime()
        assert.are_not.equal(before, after)
        assert.is_true(before.nodes[1]:isDestroyed())
        assert.is_true(math.abs(rimArea(after)) > 3 * beforeArea) -- twice the height: ~4x the area
    end)

    it("lands on a floor and keeps its shape (pressure)", function()
        local floor = love.physics.newBody(state.physicsWorld, 0, 400, 'static')
        love.physics.newFixture(floor, love.physics.newRectangleShape(4000, 40))
        props.makeBlob(0, -200)
        blobs.beforeStep(true)
        local rt = onlyRuntime()
        local rest = rimArea(rt)
        step(3)
        local ratio = rimArea(rt) / rest
        assert.is_true(ratio > 0.85 and ratio < 1.1, 'area ratio ' .. ratio)
        local _, y = rt.body:getPosition()
        assert.is_true(y < 400, 'fell through the floor')
    end)
end)
