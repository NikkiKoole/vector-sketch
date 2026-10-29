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
package.loaded['src.physics.box2d-pointerjoints'] = nil
local pointerJoints = require('src.physics.box2d-pointerjoints')
local subtypes = require('src.subtypes')

local function makeWorld()
    return love.physics.newWorld(0, 9.81 * love.physics.getMeter(), true)
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

local function insideRim(rt, x, y)
    local inside, n = false, #rt.nodes
    local j = n
    for k = 1, n do
        local xi, yi = rt.nodes[k]:getPosition()
        local xj, yj = rt.nodes[j]:getPosition()
        if ((yi > y) ~= (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi) then inside = not inside end
        j = k
    end
    return inside
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

    it("keeps its handle inside the rim when dragged hard by it", function()
        local floor = love.physics.newBody(state.physicsWorld, 0, 400, 'static')
        love.physics.newFixture(floor, love.physics.newRectangleShape(4000, 40))
        local thing = props.makeBlob(0, 200)
        blobs.beforeStep(true)
        local rt = onlyRuntime()
        local restArea = rimArea(rt)
        step(1)
        -- a pointer grabbing the handle (as the play-mode grab does), yanked around
        local mj = love.physics.newMouseJoint(thing.body, thing.body:getPosition())
        mj:setMaxForce(1000000) -- the drag slider's maximum (state.world.mouseForce is 500000)
        mj:setDampingRatio(0.5)
        local outside, frames = 0, 0
        for _, target in ipairs({ { 700, 100 }, { -600, -200 }, { 300, 300 }, { -200, -500 } }) do
            mj:setTarget(target[1], target[2])
            for _ = 1, 40 do
                blobs.beforeStep(false)
                state.physicsWorld:update(1 / 60)
                blobs.afterStep()
                frames = frames + 1
                if not insideRim(rt, thing.body:getPosition()) then outside = outside + 1 end
            end
        end
        mj:destroy()
        step(2)
        assert.are.equal(0, outside, outside .. ' of ' .. frames .. ' frames outside while dragged')
        assert.is_true(insideRim(rt, thing.body:getPosition()), 'outside after letting go')
        -- and the rim came along: its middle is near the handle
        local cx, cy = 0, 0
        for _, node in ipairs(rt.nodes) do
            local x, y = node:getPosition()
            cx, cy = cx + x / #rt.nodes, cy + y / #rt.nodes
        end
        local bx, by = thing.body:getPosition()
        local dist = math.sqrt((cx - bx) ^ 2 + (cy - by) ^ 2)
        assert.is_true(dist < 40, string.format('rim middle %.0f from the handle (handle %.0f,%.0f rim %.0f,%.0f area %.2f)',
            dist, bx, by, cx, cy, rimArea(rt) / restArea))
    end)

    it("can be grabbed anywhere inside, not only on its edge or its handle", function()
        local thing = props.makeBlob(0, 0)
        blobs.beforeStep(true)
        local rt = onlyRuntime()
        local params = { pointerForceFunc = function() return 500000 end, damp = 0.5 }
        -- halfway between the middle and each rim point: inside the blob, off the handle circle
        local misses = 0
        for i = 1, #rt.nodes, 4 do
            local nx, ny = rt.nodes[i]:getPosition()
            local hit, hitted = pointerJoints.handlePointerPressed(nx * 0.55, ny * 0.55, 'mouse', params, true)
            local grabbed = hit and hitted[1] and (hitted[1]:getBody() == thing.body or blobs.ownerOf(hitted[1]:getBody()))
            if not grabbed then misses = misses + 1 end
            pointerJoints.killMouseJointIfPossible('mouse')
        end
        assert.are.equal(0, misses)
        -- outside the blob: nothing
        local hit = pointerJoints.handlePointerPressed(1000, 1000, 'mouse', params, true)
        assert.is_false(hit)
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
