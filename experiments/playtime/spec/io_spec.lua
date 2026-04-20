-- spec/io_spec.lua
-- Tests for src/io.lua — save/load, clone, dimension gating
-- io.lua requires love (via uuid.lua), so all tests need LÖVE.
-- Run with: love . --specs

if not love then return end


package.loaded['src.io'] = nil
local sceneIO = require('src.io')
local t = sceneIO._test
local registry = require('src.registry')
local utils = require('src.utils')

-- ─── needsDimProperty (pure logic, but loaded via LÖVE) ───

describe("io._test.needsDimProperty", function()

    -- All shape types in the system
    local radiusShapes = { 'circle', 'triangle', 'pentagon', 'hexagon', 'heptagon', 'octagon' }
    local dimShapes = { 'rectangle', 'capsule', 'torso', 'trapezium', 'ribbon', 'itriangle', 'shape8' }

    describe("radius", function()
        for _, shape in ipairs(radiusShapes) do
            it("is needed for " .. shape, function()
                assert.is_truthy(t.needsDimProperty('radius', shape))
            end)
        end

        for _, shape in ipairs(dimShapes) do
            it("is NOT needed for " .. shape, function()
                assert.is_falsy(t.needsDimProperty('radius', shape))
            end)
        end
    end)

    describe("width and height", function()
        for _, shape in ipairs(radiusShapes) do
            it("width is NOT needed for " .. shape, function()
                assert.is_falsy(t.needsDimProperty('width', shape))
            end)
            it("height is NOT needed for " .. shape, function()
                assert.is_falsy(t.needsDimProperty('height', shape))
            end)
        end

        it("width is NOT needed for custom", function()
            assert.is_falsy(t.needsDimProperty('width', 'custom'))
        end)

        for _, shape in ipairs({ 'rectangle', 'capsule', 'torso', 'trapezium' }) do
            it("width is needed for " .. shape, function()
                assert.is_truthy(t.needsDimProperty('width', shape))
            end)
            it("height is needed for " .. shape, function()
                assert.is_truthy(t.needsDimProperty('height', shape))
            end)
        end
    end)

    describe("width2", function()
        it("is needed for torso", function()
            assert.is_truthy(t.needsDimProperty('width2', 'torso'))
        end)

        it("is needed for trapezium", function()
            assert.is_truthy(t.needsDimProperty('width2', 'trapezium'))
        end)

        it("is NOT needed for rectangle", function()
            assert.is_falsy(t.needsDimProperty('width2', 'rectangle'))
        end)

        it("is NOT needed for capsule", function()
            assert.is_falsy(t.needsDimProperty('width2', 'capsule'))
        end)
    end)

    describe("height2", function()
        it("is needed for torso", function()
            assert.is_truthy(t.needsDimProperty('height2', 'torso'))
        end)

        it("is needed for capsule", function()
            assert.is_truthy(t.needsDimProperty('height2', 'capsule'))
        end)

        it("is NOT needed for rectangle", function()
            assert.is_falsy(t.needsDimProperty('height2', 'rectangle'))
        end)
    end)

    describe("torso-only properties", function()
        local torsoOnly = { 'width3', 'height3', 'height4' }
        for _, prop in ipairs(torsoOnly) do
            it(prop .. " is needed for torso", function()
                assert.is_truthy(t.needsDimProperty(prop, 'torso'))
            end)

            it(prop .. " is NOT needed for rectangle", function()
                assert.is_falsy(t.needsDimProperty(prop, 'rectangle'))
            end)

            it(prop .. " is NOT needed for capsule", function()
                assert.is_falsy(t.needsDimProperty(prop, 'capsule'))
            end)
        end
    end)

    describe("edge cases", function()
        it("returns nil for unknown properties", function()
            assert.is_nil(t.needsDimProperty('nonexistent', 'rectangle'))
        end)

        it("returns false for unknown shapes on radius", function()
            assert.is_false(t.needsDimProperty('radius', 'unknownShape'))
        end)
    end)
end)

-- ─── remapAndRestoreInfluences (ID remapping portion) ───

describe("io._test.remapAndRestoreInfluences (ID remapping)", function()

    it("remaps nodeId through idMapping", function()
        local influences = {
            [1] = {
                { nodeId = "old1", nodeType = "anchor", side = nil },
                { nodeId = "old2", nodeType = "joint", side = "A" },
            },
            [2] = {
                { nodeId = "old1", nodeType = "anchor", side = nil },
            },
        }
        local idMapping = { old1 = "new1", old2 = "new2" }

        t.remapAndRestoreInfluences(influences, idMapping)

        assert.are.equal("new1", influences[1][1].nodeId)
        assert.are.equal("new2", influences[1][2].nodeId)
        assert.are.equal("new1", influences[2][1].nodeId)
    end)

    it("sets nodeId to nil when mapping is missing", function()
        local influences = {
            [1] = {
                { nodeId = "old1", nodeType = "anchor", side = nil },
            },
        }
        local idMapping = {}

        t.remapAndRestoreInfluences(influences, idMapping)

        assert.is_nil(influences[1][1].nodeId)
    end)

    it("handles nil influences gracefully", function()
        assert.has_no.errors(function()
            t.remapAndRestoreInfluences(nil, { a = "b" })
        end)
    end)

    it("handles empty influences", function()
        assert.has_no.errors(function()
            t.remapAndRestoreInfluences({}, { a = "b" })
        end)
    end)
end)

-- ─── gatherSaveData integration tests ───

describe("io.gatherSaveData (LÖVE integration)", function()

    local world
    local cam = {
        getTranslation = function() return 0, 0 end,
        getScale = function() return 1 end,
        getRotation = function() return 0 end
    }

    before_each(function()
        world = love.physics.newWorld(0, 9.81 * 100, true)
        registry.reset()
    end)

    after_each(function()
        if world and not world:isDestroyed() then
            world:destroy()
        end
    end)

    it("returns valid structure for empty world", function()
        local data = sceneIO.gatherSaveData(world, cam)
        assert.is_not_nil(data)
        assert.is_not_nil(data.bodies)
        assert.is_not_nil(data.joints)
        assert.is_not_nil(data.camera)
        assert.are.equal(0, #data.bodies)
    end)

    it("captures body with thing userData", function()
        local body = love.physics.newBody(world, 100, 200, "dynamic")
        love.physics.newFixture(body, love.physics.newRectangleShape(50, 50))
        body:setUserData({
            thing = {
                id = "test1", label = "torso", shapeType = "rectangle",
                width = 50, height = 50, radius = 25, mirrorX = 1, mirrorY = 1,
            }
        })
        registry.registerBody("test1", body)

        local data = sceneIO.gatherSaveData(world, cam)

        assert.are.equal(1, #data.bodies)
        assert.are.equal("test1", data.bodies[1].id)
        assert.are.equal("torso", data.bodies[1].label)
        assert.are.equal("rectangle", data.bodies[1].shapeType)
        assert.is_near(100, data.bodies[1].position[1], 0.01)
        assert.is_near(200, data.bodies[1].position[2], 0.01)
    end)

    it("gates dims by shape type", function()
        local body = love.physics.newBody(world, 0, 0, "dynamic")
        love.physics.newFixture(body, love.physics.newCircleShape(30))
        body:setUserData({
            thing = {
                id = "circ1", label = "ball", shapeType = "circle",
                radius = 30, width = 999, height = 999,
            }
        })
        registry.registerBody("circ1", body)

        local data = sceneIO.gatherSaveData(world, cam)

        assert.are.equal(30, data.bodies[1].dims.radius)
        assert.is_nil(data.bodies[1].dims.width)
        assert.is_nil(data.bodies[1].dims.height)
    end)

    it("saves shared fixture data from non-userData fixture", function()
        local body = love.physics.newBody(world, 0, 0, "dynamic")
        local fixture = love.physics.newFixture(body, love.physics.newRectangleShape(50, 50))
        fixture:setDensity(2.5)
        fixture:setFriction(0.7)
        fixture:setRestitution(0.3)
        body:setUserData({
            thing = {
                id = "box1", label = "box", shapeType = "rectangle",
                width = 50, height = 50, radius = 1,
            }
        })
        registry.registerBody("box1", body)

        local data = sceneIO.gatherSaveData(world, cam)

        assert.is_near(2.5, data.bodies[1].sharedFixtureData.density, 0.01)
        assert.is_near(0.7, data.bodies[1].sharedFixtureData.friction, 0.01)
        assert.is_near(0.3, data.bodies[1].sharedFixtureData.restitution, 0.01)
    end)

    it("skips bodies without thing userData", function()
        -- Body without userData
        local body1 = love.physics.newBody(world, 0, 0, "dynamic")
        love.physics.newFixture(body1, love.physics.newCircleShape(10))

        -- Body with userData
        local body2 = love.physics.newBody(world, 0, 0, "dynamic")
        love.physics.newFixture(body2, love.physics.newCircleShape(10))
        body2:setUserData({
            thing = { id = "b2", label = "kept", shapeType = "circle", radius = 10 }
        })
        registry.registerBody("b2", body2)

        local data = sceneIO.gatherSaveData(world, cam)

        assert.are.equal(1, #data.bodies)
        assert.are.equal("b2", data.bodies[1].id)
    end)

    it("preserves body type", function()
        for _, bodyType in ipairs({ "dynamic", "static", "kinematic" }) do
            local body = love.physics.newBody(world, 0, 0, bodyType)
            love.physics.newFixture(body, love.physics.newCircleShape(10))
            local id = "bt_" .. bodyType
            body:setUserData({
                thing = { id = id, label = bodyType, shapeType = "circle", radius = 10 }
            })
            registry.registerBody(id, body)
        end

        local data = sceneIO.gatherSaveData(world, cam)
        assert.are.equal(3, #data.bodies)

        local types = {}
        for _, b in ipairs(data.bodies) do types[b.label] = b.bodyType end
        assert.are.equal("dynamic", types["dynamic"])
        assert.are.equal("static", types["static"])
        assert.are.equal("kinematic", types["kinematic"])
    end)

    it("saves camera state", function()
        local myCam = {
            getTranslation = function() return 500, 300 end,
            getScale = function() return 2.5 end,
            getRotation = function() return 0 end
        }

        local data = sceneIO.gatherSaveData(world, myCam)

        assert.are.equal(500, data.camera.x)
        assert.are.equal(300, data.camera.y)
        assert.are.equal(2.5, data.camera.scale)
    end)
end)

-- ─── Save/Load Round-Trip Tests (all scene files) ───

describe("save/load round-trip", function()
    local json = require('vendor.dkjson')

    -- Cam mock with getters and setters for the load path
    local camState = { x = 0, y = 0, scale = 1 }
    local cam = {
        getTranslation = function() return camState.x, camState.y end,
        getScale = function() return camState.scale end,
        getRotation = function() return 0 end,
        setTranslation = function(self, x, y) camState.x = x; camState.y = y end,
        setScale = function(self, s) camState.scale = s end,
    }

    -- Find all scene files
    local sceneFiles = {}
    local items = love.filesystem.getDirectoryItems("scripts")
    for _, item in ipairs(items) do
        if item:match("%.playtime%.json$") then
            table.insert(sceneFiles, "scripts/" .. item)
        end
    end

    -- Helper: index bodies/joints by ID for comparison
    local function indexById(list)
        local map = {}
        for _, item in ipairs(list) do
            if item.id then map[item.id] = item end
        end
        return map
    end

    -- Helper: compare body data (positions, types, dims, fixtures count)
    local function compareBodies(original, restored, file)
        local origMap = indexById(original)
        local restMap = indexById(restored)

        -- Same number of bodies
        assert.are.equal(#original, #restored,
            file .. ": body count mismatch (original=" .. #original .. ", restored=" .. #restored .. ")")

        for id, orig in pairs(origMap) do
            local rest = restMap[id]
            assert.is_not_nil(rest, file .. ": body " .. id .. " missing after round-trip")

            -- Body type must match
            assert.are.equal(orig.bodyType, rest.bodyType,
                file .. ": body " .. id .. " type mismatch")

            -- Shape type must match
            assert.are.equal(orig.shapeType, rest.shapeType,
                file .. ": body " .. id .. " shapeType mismatch")

            -- Position (within rounding tolerance)
            -- Box2D uses float32 internally; precision degrades at large coordinates
            -- (0.25 at ~4M, 0.5 at ~8M), so scale tolerance accordingly
            local posTolX = math.max(0.1, math.abs(orig.position[1]) * 1e-6)
            local posTolY = math.max(0.1, math.abs(orig.position[2]) * 1e-6)
            assert.is_near(orig.position[1], rest.position[1], posTolX,
                file .. ": body " .. id .. " X position drift")
            assert.is_near(orig.position[2], rest.position[2], posTolY,
                file .. ": body " .. id .. " Y position drift")

            -- Angle
            assert.is_near(orig.angle, rest.angle, 0.001,
                file .. ": body " .. id .. " angle drift")

            -- Dims should survive
            if orig.dims then
                for prop, val in pairs(orig.dims) do
                    assert.is_not_nil(rest.dims[prop],
                        file .. ": body " .. id .. " lost dim." .. prop)
                    assert.is_near(val, rest.dims[prop], 0.01,
                        file .. ": body " .. id .. " dim." .. prop .. " changed")
                end
            end

            -- Fixture count must match
            assert.are.equal(#orig.fixtures, #rest.fixtures,
                file .. ": body " .. id .. " fixture count mismatch (orig=" .. #orig.fixtures .. ", rest=" .. #rest.fixtures .. ")")
        end
    end

    -- Helper: compare joint data (types, body references, key properties)
    local function compareJoints(original, restored, file)
        local origMap = indexById(original)
        local restMap = indexById(restored)

        assert.are.equal(#original, #restored,
            file .. ": joint count mismatch (original=" .. #original .. ", restored=" .. #restored .. ")")

        for id, orig in pairs(origMap) do
            local rest = restMap[id]
            assert.is_not_nil(rest, file .. ": joint " .. id .. " missing after round-trip")

            assert.are.equal(orig.jointType, rest.jointType,
                file .. ": joint " .. id .. " type mismatch")

            assert.are.equal(orig.bodyA, rest.bodyA,
                file .. ": joint " .. id .. " bodyA mismatch")
            assert.are.equal(orig.bodyB, rest.bodyB,
                file .. ": joint " .. id .. " bodyB mismatch")
        end
    end

    for _, sceneFile in ipairs(sceneFiles) do
        it("round-trips " .. sceneFile, function()
            -- 1. Read the raw JSON
            local rawJson = love.filesystem.read(sceneFile)
            assert.is_not_nil(rawJson, "Could not read " .. sceneFile)

            local originalData = json.decode(rawJson)
            assert.is_not_nil(originalData, "Could not parse " .. sceneFile)
            if originalData.version ~= "1.0" then
                pending("skipping " .. sceneFile .. " (version " .. tostring(originalData.version) .. ")")
                return
            end

            -- 2. Load into a fresh world
            local world = love.physics.newWorld(0, 9.81 * 100, true)
            registry.reset()
            camState = { x = 0, y = 0, scale = 1 }

            -- Build the world from original data
            sceneIO.buildWorld(originalData, world, cam)

            -- 3. Gather save data from the live world
            local restoredData = sceneIO.gatherSaveData(world, cam)

            -- 4. Compare
            compareBodies(originalData.bodies or {}, restoredData.bodies or {}, sceneFile)
            compareJoints(originalData.joints or {}, restoredData.joints or {}, sceneFile)

            -- Camera should survive
            if originalData.camera then
                assert.is_near(originalData.camera.x, restoredData.camera.x, 0.1,
                    sceneFile .. ": camera X drift")
                assert.is_near(originalData.camera.y, restoredData.camera.y, 0.1,
                    sceneFile .. ": camera Y drift")
                assert.is_near(originalData.camera.scale, restoredData.camera.scale, 0.01,
                    sceneFile .. ": camera scale drift")
            end

            -- Cleanup
            world:destroy()
        end)
    end
end)

-- ─── Double Round-Trip: load → save → load → save → compare ───
-- If the pipeline is idempotent, save1 and save2 should be identical.
-- Catches data that drifts or leaks on each save/load cycle.

describe("double round-trip (all scene files)", function()
    local json = require('vendor.dkjson')

    local function makeCam()
        local cs = { x = 0, y = 0, scale = 1 }
        return {
            getTranslation = function() return cs.x, cs.y end,
            getScale = function() return cs.scale end,
            getRotation = function() return 0 end,
            setTranslation = function(_, x, y) cs.x = x; cs.y = y end,
            setScale = function(_, s) cs.scale = s end,
        }, cs
    end

    local function indexById(list)
        local map = {}
        for _, item in ipairs(list) do
            if item.id then map[item.id] = item end
        end
        return map
    end

    -- Deep-compare two save data blobs, reporting all differences
    local function compareSaveData(save1, save2, file)
        local diffs = {}
        local function diff(msg) table.insert(diffs, file .. ": " .. msg) end

        -- Body count
        local b1, b2 = save1.bodies or {}, save2.bodies or {}
        if #b1 ~= #b2 then
            diff("body count changed: " .. #b1 .. " → " .. #b2)
        end

        local map1 = indexById(b1)
        local map2 = indexById(b2)

        -- Check every body from save1 appears in save2
        for id, orig in pairs(map1) do
            local rest = map2[id]
            if not rest then
                diff("body " .. id .. " disappeared on second save")
            else
                -- Core identity
                if orig.shapeType ~= rest.shapeType then
                    diff("body " .. id .. " shapeType: " .. tostring(orig.shapeType) .. " → " .. tostring(rest.shapeType))
                end
                if orig.bodyType ~= rest.bodyType then
                    diff("body " .. id .. " bodyType: " .. tostring(orig.bodyType) .. " → " .. tostring(rest.bodyType))
                end
                if orig.label ~= rest.label then
                    diff("body " .. id .. " label: " .. tostring(orig.label) .. " → " .. tostring(rest.label))
                end

                -- Position drift
                if math.abs(orig.position[1] - rest.position[1]) > 0.01 then
                    diff("body " .. id .. " X drifted: " .. orig.position[1] .. " → " .. rest.position[1])
                end
                if math.abs(orig.position[2] - rest.position[2]) > 0.01 then
                    diff("body " .. id .. " Y drifted: " .. orig.position[2] .. " → " .. rest.position[2])
                end

                -- Angle drift
                if math.abs(orig.angle - rest.angle) > 0.001 then
                    diff("body " .. id .. " angle drifted: " .. orig.angle .. " → " .. rest.angle)
                end

                -- Dims
                if orig.dims and rest.dims then
                    for prop, val in pairs(orig.dims) do
                        if not rest.dims[prop] then
                            diff("body " .. id .. " lost dim." .. prop)
                        elseif math.abs(val - rest.dims[prop]) > 0.01 then
                            diff("body " .. id .. " dim." .. prop .. " drifted: " .. val .. " → " .. rest.dims[prop])
                        end
                    end
                    for prop, _ in pairs(rest.dims) do
                        if not orig.dims[prop] then
                            diff("body " .. id .. " gained unexpected dim." .. prop)
                        end
                    end
                end

                -- Fixture count
                if #orig.fixtures ~= #rest.fixtures then
                    diff("body " .. id .. " fixture count: " .. #orig.fixtures .. " → " .. #rest.fixtures)
                end

                -- Shared fixture data
                local sfd1 = orig.sharedFixtureData or {}
                local sfd2 = rest.sharedFixtureData or {}
                for _, prop in ipairs({ 'density', 'friction', 'restitution', 'groupIndex', 'sensor' }) do
                    local v1, v2 = sfd1[prop], sfd2[prop]
                    if type(v1) == 'number' and type(v2) == 'number' then
                        if math.abs(v1 - v2) > 0.001 then
                            diff("body " .. id .. " sharedFixtureData." .. prop .. ": " .. v1 .. " → " .. v2)
                        end
                    elseif v1 ~= v2 then
                        diff("body " .. id .. " sharedFixtureData." .. prop .. ": " .. tostring(v1) .. " → " .. tostring(v2))
                    end
                end

                -- SFixture userData survival
                for fi, fdata in ipairs(orig.fixtures) do
                    local rfix = rest.fixtures[fi]
                    if rfix then
                        local hasUD1 = fdata.userData ~= nil
                        local hasUD2 = rfix.userData ~= nil
                        if hasUD1 ~= hasUD2 then
                            diff("body " .. id .. " fixture[" .. fi .. "] userData presence changed")
                        elseif hasUD1 and hasUD2 then
                            if fdata.userData.subtype ~= rfix.userData.subtype then
                                diff("body " .. id .. " fixture[" .. fi .. "] subtype: "
                                    .. tostring(fdata.userData.subtype) .. " → " .. tostring(rfix.userData.subtype))
                            end
                            if fdata.userData.id ~= rfix.userData.id then
                                diff("body " .. id .. " fixture[" .. fi .. "] sfixture id changed")
                            end
                        end
                    end
                end

                -- Behaviors
                local beh1 = orig.behaviors or {}
                local beh2 = rest.behaviors or {}
                for k, v in pairs(beh1) do
                    if beh2[k] ~= v then
                        diff("body " .. id .. " behavior " .. k .. ": " .. tostring(v) .. " → " .. tostring(beh2[k]))
                    end
                end

                -- Mirror flags
                if orig.mirrorX ~= rest.mirrorX then
                    diff("body " .. id .. " mirrorX: " .. tostring(orig.mirrorX) .. " → " .. tostring(rest.mirrorX))
                end
                if orig.mirrorY ~= rest.mirrorY then
                    diff("body " .. id .. " mirrorY: " .. tostring(orig.mirrorY) .. " → " .. tostring(rest.mirrorY))
                end

                -- Vertices (polygon shapes)
                if orig.vertices and rest.vertices then
                    if #orig.vertices ~= #rest.vertices then
                        diff("body " .. id .. " vertex count: " .. #orig.vertices .. " → " .. #rest.vertices)
                    else
                        for vi = 1, #orig.vertices do
                            if math.abs(orig.vertices[vi] - rest.vertices[vi]) > 0.01 then
                                diff("body " .. id .. " vertex[" .. vi .. "] drifted: "
                                    .. orig.vertices[vi] .. " → " .. rest.vertices[vi])
                                break
                            end
                        end
                    end
                elseif (orig.vertices ~= nil) ~= (rest.vertices ~= nil) then
                    diff("body " .. id .. " vertices presence changed")
                end

                -- Damping
                if math.abs((orig.linearDamping or 0) - (rest.linearDamping or 0)) > 0.001 then
                    diff("body " .. id .. " linearDamping drifted")
                end
                if math.abs((orig.angularDamping or 0) - (rest.angularDamping or 0)) > 0.001 then
                    diff("body " .. id .. " angularDamping drifted")
                end

                -- Fixed rotation
                if orig.fixedRotation ~= rest.fixedRotation then
                    diff("body " .. id .. " fixedRotation changed")
                end
            end
        end

        -- Bodies that appeared in save2 but not save1
        for id, _ in pairs(map2) do
            if not map1[id] then
                diff("body " .. id .. " appeared out of nowhere on second save")
            end
        end

        -- Joint count
        local j1, j2 = save1.joints or {}, save2.joints or {}
        if #j1 ~= #j2 then
            diff("joint count changed: " .. #j1 .. " → " .. #j2)
        end

        local jmap1 = indexById(j1)
        local jmap2 = indexById(j2)

        for id, orig in pairs(jmap1) do
            local rest = jmap2[id]
            if not rest then
                diff("joint " .. id .. " disappeared on second save")
            else
                if orig.type ~= rest.type then
                    diff("joint " .. id .. " type: " .. tostring(orig.type) .. " → " .. tostring(rest.type))
                end
                if orig.bodyA ~= rest.bodyA then
                    diff("joint " .. id .. " bodyA changed")
                end
                if orig.bodyB ~= rest.bodyB then
                    diff("joint " .. id .. " bodyB changed")
                end
                -- Anchor drift
                if orig.anchorA and rest.anchorA then
                    if math.abs(orig.anchorA[1] - rest.anchorA[1]) > 0.1
                        or math.abs(orig.anchorA[2] - rest.anchorA[2]) > 0.1 then
                        diff("joint " .. id .. " anchorA drifted")
                    end
                end
                if orig.anchorB and rest.anchorB then
                    if math.abs(orig.anchorB[1] - rest.anchorB[1]) > 0.1
                        or math.abs(orig.anchorB[2] - rest.anchorB[2]) > 0.1 then
                        diff("joint " .. id .. " anchorB drifted")
                    end
                end
                -- Joint properties
                if orig.properties and rest.properties then
                    for k, v in pairs(orig.properties) do
                        local rv = rest.properties[k]
                        if type(v) == 'number' and type(rv) == 'number' then
                            if math.abs(v - rv) > 0.01 then
                                diff("joint " .. id .. " property " .. k .. ": " .. v .. " → " .. rv)
                            end
                        elseif type(v) ~= 'table' and v ~= rv then
                            diff("joint " .. id .. " property " .. k .. " changed")
                        end
                    end
                end
            end
        end

        -- Camera
        if save1.camera and save2.camera then
            if math.abs(save1.camera.x - save2.camera.x) > 0.1 then
                diff("camera X drifted")
            end
            if math.abs(save1.camera.y - save2.camera.y) > 0.1 then
                diff("camera Y drifted")
            end
            if math.abs(save1.camera.scale - save2.camera.scale) > 0.01 then
                diff("camera scale drifted")
            end
        end

        return diffs
    end

    -- Find all scene files
    local sceneFiles = {}
    local items = love.filesystem.getDirectoryItems("scripts")
    for _, item in ipairs(items) do
        if item:match("%.playtime%.json$") then
            table.insert(sceneFiles, "scripts/" .. item)
        end
    end

    for _, sceneFile in ipairs(sceneFiles) do
        it("is idempotent for " .. sceneFile, function()
            local rawJson = love.filesystem.read(sceneFile)
            assert.is_not_nil(rawJson, "Could not read " .. sceneFile)

            local originalData = json.decode(rawJson)
            assert.is_not_nil(originalData, "Could not parse " .. sceneFile)
            if originalData.version ~= "1.0" then
                pending("skipping " .. sceneFile .. " (version " .. tostring(originalData.version) .. ")")
                return
            end

            -- Pass 1: load original → save
            local world1 = love.physics.newWorld(0, 9.81 * 100, true)
            registry.reset()
            local cam1 = makeCam()
            sceneIO.buildWorld(originalData, world1, cam1)
            local save1 = sceneIO.gatherSaveData(world1, cam1)
            world1:destroy()

            -- Pass 2: load save1 → save again
            local world2 = love.physics.newWorld(0, 9.81 * 100, true)
            registry.reset()
            local cam2 = makeCam()
            sceneIO.buildWorld(save1, world2, cam2)
            local save2 = sceneIO.gatherSaveData(world2, cam2)
            world2:destroy()

            -- Compare: save1 and save2 should be identical
            local diffs = compareSaveData(save1, save2, sceneFile)
            if #diffs > 0 then
                local msg = "Double round-trip found " .. #diffs .. " difference(s):\n"
                for i, d in ipairs(diffs) do
                    msg = msg .. "  " .. i .. ". " .. d .. "\n"
                end
                assert.is_true(false, msg)
            end
        end)
    end
end)

-- ─── roundFloats (save-time precision clamp) ───

describe("io._test.roundFloats", function()
    it("rounds positive floats to n decimals", function()
        local result = t.roundFloats({ x = 1734.8215684197 }, 4)
        assert.are.equal(1734.8216, result.x)
    end)

    it("rounds negative floats symmetrically", function()
        local result = t.roundFloats({ x = -86.81404209137 }, 4)
        assert.are.equal(-86.8140, result.x)
    end)

    it("leaves integers as integers", function()
        local result = t.roundFloats({ x = 42 }, 4)
        assert.are.equal(42, result.x)
    end)

    it("leaves strings and booleans untouched", function()
        local result = t.roundFloats({ s = "hello", b = true, n = false }, 4)
        assert.are.equal("hello", result.s)
        assert.are.equal(true, result.b)
        assert.are.equal(false, result.n)
    end)

    it("recurses into nested tables and lists", function()
        local input = {
            a = { 1.12345, 2.99999 },
            b = { inner = { c = 3.33333 } },
        }
        local result = t.roundFloats(input, 2)
        assert.are.equal(1.12, result.a[1])
        assert.are.equal(3.00, result.a[2])
        assert.are.equal(3.33, result.b.inner.c)
    end)

    it("handles zero and very small values without -0.0", function()
        local result = t.roundFloats({ a = 0, b = -0.00001, c = 0.00001 }, 4)
        assert.are.equal(0, result.a)
        assert.are.equal(0, result.b)
        assert.are.equal(0, result.c)
    end)

    it("does not mutate the input table", function()
        local input = { x = 1.23456789 }
        t.roundFloats(input, 2)
        assert.are.equal(1.23456789, input.x)
    end)

    it("produces JSON with no floats beyond n decimal places", function()
        local json = require('vendor.dkjson')
        local data = {
            vertices = { 1734.8215684197, 836.78543898645, -86.81404209137 },
            nested = { { x = 0.123456789 }, { x = 987.654321 } },
        }
        local rounded = t.roundFloats(data, 4)
        local encoded = json.encode(rounded)
        local over = encoded:match('%-?%d+%.%d%d%d%d%d+')
        assert.is_nil(over, "Found a number exceeding 4 decimals: " .. tostring(over))
    end)
end)

-- ─── influence `dist` field (redundant with dx/dy) ───

describe("io._test.stripInfluenceDist", function()
    it("removes dist from every influence entry", function()
        local influences = {
            [1] = { { dx = 3, dy = 4, dist = 5, other = 1 } },
            [2] = { { dx = 6, dy = 8, dist = 10 }, { dx = 1, dy = 0, dist = 1 } },
        }
        t.stripInfluenceDist(influences)
        assert.is_nil(influences[1][1].dist)
        assert.is_nil(influences[2][1].dist)
        assert.is_nil(influences[2][2].dist)
    end)

    it("preserves other fields on each entry", function()
        local influences = { [1] = { { dx = 3, dy = 4, dist = 5, w = 0.5, nodeId = 'abc' } } }
        t.stripInfluenceDist(influences)
        assert.are.equal(3, influences[1][1].dx)
        assert.are.equal(0.5, influences[1][1].w)
        assert.are.equal('abc', influences[1][1].nodeId)
    end)

    it("is a no-op when given nil", function()
        assert.has_no.errors(function() t.stripInfluenceDist(nil) end)
    end)

    it("tolerates entries that already lack dist", function()
        local influences = { [1] = { { dx = 3, dy = 4 } } }
        assert.has_no.errors(function() t.stripInfluenceDist(influences) end)
        assert.is_nil(influences[1][1].dist)
    end)
end)

describe("io._test.restoreInfluenceDist", function()
    it("computes dist = sqrt(dx^2 + dy^2) per entry when missing", function()
        local influences = {
            [1] = { { dx = 3, dy = 4 } },
            [2] = { { dx = 6, dy = 8 }, { dx = 1, dy = 0 } },
        }
        t.restoreInfluenceDist(influences)
        assert.are.equal(5, influences[1][1].dist)
        assert.are.equal(10, influences[2][1].dist)
        assert.are.equal(1, influences[2][2].dist)
    end)

    it("does not overwrite an existing dist value", function()
        -- Old saves still ship dist — trust what's there.
        local influences = { [1] = { { dx = 3, dy = 4, dist = 99 } } }
        t.restoreInfluenceDist(influences)
        assert.are.equal(99, influences[1][1].dist)
    end)

    it("leaves dist nil if dx or dy missing", function()
        local influences = { [1] = { { dx = 3 } } }
        t.restoreInfluenceDist(influences)
        assert.is_nil(influences[1][1].dist)
    end)

    it("is a no-op when given nil", function()
        assert.has_no.errors(function() t.restoreInfluenceDist(nil) end)
    end)

    it("round-trips with stripInfluenceDist", function()
        local influences = {
            [1] = { { dx = 3, dy = 4, dist = 5, w = 0.5 } },
            [2] = { { dx = -6, dy = 8, dist = 10 }, { dx = 0, dy = 0, dist = 0 } },
        }
        t.stripInfluenceDist(influences)
        t.restoreInfluenceDist(influences)
        assert.are.equal(5, influences[1][1].dist)
        assert.are.equal(10, influences[2][1].dist)
        assert.are.equal(0, influences[2][2].dist)
        assert.are.equal(0.5, influences[1][1].w)
    end)
end)

-- ─── zero-weight influence pruning ───

describe("io._test.pruneZeroWeightInfluences", function()
    it("removes entries with w == 0", function()
        local influences = {
            [1] = { { w = 0.5, nodeId = 'a' }, { w = 0, nodeId = 'b' } },
        }
        t.pruneZeroWeightInfluences(influences)
        assert.are.equal(1, #influences[1])
        assert.are.equal('a', influences[1][1].nodeId)
    end)

    it("removes entries with missing w (nil treated as zero)", function()
        local influences = { [1] = { { w = 0.5 }, { nodeId = 'x' } } }
        t.pruneZeroWeightInfluences(influences)
        assert.are.equal(1, #influences[1])
        assert.are.equal(0.5, influences[1][1].w)
    end)

    it("keeps small-but-nonzero weights", function()
        local influences = { [1] = { { w = 0.0001 }, { w = 0 } } }
        t.pruneZeroWeightInfluences(influences)
        assert.are.equal(1, #influences[1])
        assert.are.equal(0.0001, influences[1][1].w)
    end)

    it("preserves per-vertex slot as empty when all entries zero-weight", function()
        -- Don't leave holes in the outer array: vertex slot stays, just empty.
        local influences = {
            [1] = { { w = 0.5 } },
            [2] = { { w = 0 }, { w = 0 } },
            [3] = { { w = 0.3 } },
        }
        t.pruneZeroWeightInfluences(influences)
        assert.are.equal(3, #influences)
        assert.are.equal(0, #influences[2])
        assert.are.equal(0.3, influences[3][1].w)
    end)

    it("is a no-op when given nil", function()
        assert.has_no.errors(function() t.pruneZeroWeightInfluences(nil) end)
    end)

    it("handles all-zero entries across multiple verts", function()
        local influences = {
            [1] = { { w = 0, a = 1 }, { w = 0, a = 2 } },
            [2] = { { w = 0, a = 3 } },
        }
        t.pruneZeroWeightInfluences(influences)
        assert.are.equal(2, #influences)
        assert.are.equal(0, #influences[1])
        assert.are.equal(0, #influences[2])
    end)
end)

-- ─── bone metadata normalization (shared bones table) ───

-- The fields nodeType, nodeId, offx, offy, bindAngle (and side for joints)
-- are identical for every influence entry with the same (nodeIndex, side).
-- Pull them out into a shared `bones` table keyed by "nodeIndex:side" and
-- expand them back on load.

describe("io._test.normalizeBones / restoreBones", function()
    it("normalize extracts per-bone metadata into a table keyed by nodeIndex:side", function()
        local influences = {
            [1] = {
                { nodeIndex = 3, nodeType = 'anchor', nodeId = 'a1',
                  offx = 1, offy = 2, bindAngle = 0.5,
                  w = 0.5, dx = 10, dy = 20 },
            },
        }
        local bones = t.normalizeBones(influences)
        assert.is_truthy(bones['3:'])
        assert.are.equal('anchor', bones['3:'].nodeType)
        assert.are.equal('a1', bones['3:'].nodeId)
        assert.are.equal(1, bones['3:'].offx)
        assert.are.equal(2, bones['3:'].offy)
        assert.are.equal(0.5, bones['3:'].bindAngle)
    end)

    it("normalize strips per-bone metadata from each entry", function()
        local influences = {
            [1] = { { nodeIndex = 3, nodeType = 'anchor', nodeId = 'a1',
                      offx = 1, offy = 2, bindAngle = 0.5,
                      w = 0.5, dx = 10, dy = 20 } },
        }
        t.normalizeBones(influences)
        local e = influences[1][1]
        assert.is_nil(e.nodeType)
        assert.is_nil(e.nodeId)
        assert.is_nil(e.offx)
        assert.is_nil(e.offy)
        assert.is_nil(e.bindAngle)
        -- Retained: nodeIndex + per-vertex data
        assert.are.equal(3, e.nodeIndex)
        assert.are.equal(0.5, e.w)
        assert.are.equal(10, e.dx)
        assert.are.equal(20, e.dy)
    end)

    it("keeps side on joint entries (part of the lookup key)", function()
        local influences = {
            [1] = {
                { nodeIndex = 2, side = 'A', nodeType = 'joint', nodeId = 'j1',
                  offx = 5, offy = 6, bindAngle = 0.1,
                  w = 0.4, dx = 1, dy = 2 },
                { nodeIndex = 2, side = 'B', nodeType = 'joint', nodeId = 'j1',
                  offx = 7, offy = 8, bindAngle = 0.2,
                  w = 0.6, dx = 3, dy = 4 },
            },
        }
        local bones = t.normalizeBones(influences)
        assert.is_truthy(bones['2:A'])
        assert.is_truthy(bones['2:B'])
        assert.are.equal(5, bones['2:A'].offx)
        assert.are.equal(7, bones['2:B'].offx)
        -- Influence entries still carry side (it's the key)
        assert.are.equal('A', influences[1][1].side)
        assert.are.equal('B', influences[1][2].side)
    end)

    it("dedupes identical (nodeIndex, side) across multiple verts", function()
        local common = { nodeType = 'anchor', nodeId = 'a1',
                         offx = 1, offy = 2, bindAngle = 0.5 }
        local influences = {
            [1] = { {
                nodeIndex = 3, nodeType = common.nodeType, nodeId = common.nodeId,
                offx = common.offx, offy = common.offy, bindAngle = common.bindAngle,
                w = 0.5, dx = 10, dy = 20,
            } },
            [2] = { {
                nodeIndex = 3, nodeType = common.nodeType, nodeId = common.nodeId,
                offx = common.offx, offy = common.offy, bindAngle = common.bindAngle,
                w = 0.3, dx = 11, dy = 21,
            } },
        }
        local bones = t.normalizeBones(influences)
        -- Only one bone entry; both vertex entries reference it.
        local count = 0
        for _ in pairs(bones) do count = count + 1 end
        assert.are.equal(1, count)
    end)

    it("restore expands bone metadata back onto each influence entry", function()
        local influences = {
            [1] = { { nodeIndex = 3, w = 0.5, dx = 10, dy = 20 } },
        }
        local bones = { ['3:'] = { nodeType = 'anchor', nodeId = 'a1',
                                   offx = 1, offy = 2, bindAngle = 0.5 } }
        t.restoreBones(influences, bones)
        local e = influences[1][1]
        assert.are.equal('anchor', e.nodeType)
        assert.are.equal('a1', e.nodeId)
        assert.are.equal(1, e.offx)
        assert.are.equal(2, e.offy)
        assert.are.equal(0.5, e.bindAngle)
    end)

    it("normalize+restore roundtrip preserves every field", function()
        local function freshInfluences()
            return {
                [1] = {
                    { nodeIndex = 3, nodeType = 'anchor', nodeId = 'a1',
                      offx = 1, offy = 2, bindAngle = 0.5,
                      w = 0.5, dx = 10, dy = 20 },
                },
                [2] = {
                    { nodeIndex = 2, side = 'A', nodeType = 'joint', nodeId = 'j1',
                      offx = 5, offy = 6, bindAngle = 0.1,
                      w = 0.4, dx = 1, dy = 2 },
                    { nodeIndex = 2, side = 'B', nodeType = 'joint', nodeId = 'j1',
                      offx = 7, offy = 8, bindAngle = 0.2,
                      w = 0.6, dx = 3, dy = 4 },
                },
            }
        end
        local original = freshInfluences()
        local roundtripped = freshInfluences()
        local bones = t.normalizeBones(roundtripped)
        t.restoreBones(roundtripped, bones)
        assert.are.same(original, roundtripped)
    end)

    it("restoreBones is a no-op when bones is nil (old saves)", function()
        local influences = {
            [1] = { { nodeIndex = 1, nodeType = 'anchor', w = 0.5, dx = 1, dy = 2 } },
        }
        t.restoreBones(influences, nil)
        -- Pre-existing metadata untouched; old saves pass through.
        assert.are.equal('anchor', influences[1][1].nodeType)
    end)

    it("normalize and restore are both no-ops on nil influences", function()
        assert.has_no.errors(function() t.normalizeBones(nil) end)
        assert.has_no.errors(function() t.restoreBones(nil, {}) end)
    end)
end)

-- ─── migrateExtraSteinerToBody ───
--
-- Path B refactor (STEINER-OWNERSHIP-PLAN.md Phase 1): Steiner-point
-- ownership moves from ud.extra.extraSteiner on RESOURCE sfixtures
-- (authoring-world coords) to body.extraSteiner at the body level
-- (body-local coords). This migration runs on load.

describe("io._test.migrateExtraSteinerToBody", function()
    local function makeBodyData(verts)
        return {
            id = 'bodyA',
            vertices = verts,
            shapeType = 'custom',
            position = { 0, 0 },
            fixtures = {},
        }
    end

    local function addResource(body, extraSteiner)
        body.fixtures[#body.fixtures + 1] = {
            userData = { subtype = 'resource', extra = { extraSteiner = extraSteiner } },
        }
        return body.fixtures[#body.fixtures]
    end

    it("moves authoring-world extraSteiner to body-local on the body", function()
        -- Unit square centered at (50, 50) → centroid = (50, 50)
        local b = makeBodyData({ 0, 0, 100, 0, 100, 100, 0, 100 })
        addResource(b, { 50, 50, 60, 40 })
        local data = { bodies = { b } }
        t.migrateExtraSteinerToBody(data)
        assert.are.same({ 0, 0, 10, -10 }, b.extraSteiner)
    end)

    it("clears the old location on the RESOURCE after migrating", function()
        local b = makeBodyData({ 0, 0, 100, 0, 100, 100, 0, 100 })
        local res = addResource(b, { 50, 50 })
        t.migrateExtraSteinerToBody({ bodies = { b } })
        assert.is_nil(res.userData.extra.extraSteiner)
    end)

    it("concatenates lists across multiple RESOURCEs on the same body", function()
        local b = makeBodyData({ 0, 0, 100, 0, 100, 100, 0, 100 })
        addResource(b, { 50, 50 })
        addResource(b, { 60, 40 })
        t.migrateExtraSteinerToBody({ bodies = { b } })
        assert.are.same({ 0, 0, 10, -10 }, b.extraSteiner)
    end)

    it("is idempotent — running twice is the same as once", function()
        local b = makeBodyData({ 0, 0, 100, 0, 100, 100, 0, 100 })
        addResource(b, { 50, 50 })
        local data = { bodies = { b } }
        t.migrateExtraSteinerToBody(data)
        local after1 = { unpack(b.extraSteiner) }
        t.migrateExtraSteinerToBody(data)
        assert.are.same(after1, b.extraSteiner)
    end)

    it("leaves existing body.extraSteiner alone when no RESOURCE has the old data", function()
        local b = makeBodyData({ 0, 0, 100, 0, 100, 100, 0, 100 })
        b.extraSteiner = { 1, 2, 3, 4 }
        addResource(b, nil)
        t.migrateExtraSteinerToBody({ bodies = { b } })
        assert.are.same({ 1, 2, 3, 4 }, b.extraSteiner)
    end)

    it("is a no-op when given nil / empty", function()
        assert.has_no.errors(function() t.migrateExtraSteinerToBody(nil) end)
        assert.has_no.errors(function() t.migrateExtraSteinerToBody({}) end)
        assert.has_no.errors(function() t.migrateExtraSteinerToBody({ bodies = {} }) end)
    end)

    it("skips bodies without vertices (can't compute centroid)", function()
        local b = { id = 'x', fixtures = {} }
        addResource(b, { 1, 2 })
        assert.has_no.errors(function() t.migrateExtraSteinerToBody({ bodies = { b } }) end)
        assert.is_nil(b.extraSteiner)
    end)
end)
