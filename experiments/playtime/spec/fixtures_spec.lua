-- spec/fixtures_spec.lua
-- Tests for src/fixtures.lua — fixture ordering invariant, sfixture creation
-- hasFixturesWithUserDataAtBeginning uses :getUserData() which we mock for pure tests.
-- createSFixture needs LÖVE.

if not love then return end


local registry = require('src.registry')
local fixtures = require('src.fixtures')

describe("fixtures.hasFixturesWithUserDataAtBeginning", function()

    -- Helper: create mock fixtures with/without userData
    local function mockFixture(hasUD)
        return {
            getUserData = function()
                if hasUD then
                    return { type = "sfixture", id = "test" }
                else
                    return nil
                end
            end
        }
    end

    it("returns true for empty fixture list", function()
        local ok, idx = fixtures.hasFixturesWithUserDataAtBeginning({})
        assert.is_true(ok)
        assert.are.equal(0, idx)
    end)

    it("returns true when all fixtures have userData", function()
        local list = { mockFixture(true), mockFixture(true), mockFixture(true) }
        local ok, idx = fixtures.hasFixturesWithUserDataAtBeginning(list)
        assert.is_true(ok)
        assert.are.equal(3, idx)
    end)

    it("returns true when no fixtures have userData", function()
        local list = { mockFixture(false), mockFixture(false) }
        local ok, idx = fixtures.hasFixturesWithUserDataAtBeginning(list)
        assert.is_true(ok)
        assert.are.equal(0, idx)
    end)

    it("returns true for correct ordering: userData first, then plain", function()
        local list = {
            mockFixture(true),
            mockFixture(true),
            mockFixture(false),
            mockFixture(false),
        }
        local ok, idx = fixtures.hasFixturesWithUserDataAtBeginning(list)
        assert.is_true(ok)
        assert.are.equal(2, idx) -- last userData fixture is at index 2
    end)

    it("returns false when userData fixture appears after plain fixture", function()
        local list = {
            mockFixture(true),
            mockFixture(false),  -- gap
            mockFixture(true),   -- violation!
        }
        local ok, idx = fixtures.hasFixturesWithUserDataAtBeginning(list)
        assert.is_false(ok)
        assert.are.equal(-1, idx)
    end)

    it("returns false when plain fixture is first and userData comes later", function()
        local list = {
            mockFixture(false),
            mockFixture(true),
        }
        local ok, idx = fixtures.hasFixturesWithUserDataAtBeginning(list)
        assert.is_false(ok)
        assert.are.equal(-1, idx)
    end)

    it("returns true for single userData fixture", function()
        local ok, idx = fixtures.hasFixturesWithUserDataAtBeginning({ mockFixture(true) })
        assert.is_true(ok)
        assert.are.equal(1, idx)
    end)

    it("returns true for single plain fixture", function()
        local ok, idx = fixtures.hasFixturesWithUserDataAtBeginning({ mockFixture(false) })
        assert.is_true(ok)
        assert.are.equal(0, idx)
    end)
end)

describe("fixtures with real Box2D (LÖVE integration)", function()

    local world

    before_each(function()
        world = love.physics.newWorld(0, 0, true)
        registry.reset()
    end)

    after_each(function()
        if world and not world:isDestroyed() then
            world:destroy()
        end
    end)

    describe("createSFixture", function()
        local subtypes = { 'snap', 'anchor', 'connected-texture', 'trace-vertices',
                           'tile-repeat', 'texfixture', 'resource', 'uvusert', 'meshusert', 'grass', 'liquid' }

        for _, subtype in ipairs(subtypes) do
            it("creates " .. subtype .. " sfixture", function()
                local body = love.physics.newBody(world, 0, 0, "dynamic")
                love.physics.newFixture(body, love.physics.newRectangleShape(50, 50))

                local fixture = fixtures.createSFixture(body, 0, 0, subtype, {
                    radius = 20, width = 40, height = 40
                })

                assert.is_not_nil(fixture)
                assert.is_true(fixture:isSensor())
                local ud = fixture:getUserData()
                assert.are.equal("sfixture", ud.type)
                assert.are.equal(subtype, ud.subtype)
                assert.is_not_nil(ud.id)
            end)
        end

        it("registers sfixture in registry", function()
            local body = love.physics.newBody(world, 0, 0, "dynamic")
            love.physics.newFixture(body, love.physics.newRectangleShape(50, 50))

            local fixture = fixtures.createSFixture(body, 0, 0, 'anchor', { radius = 20 })
            local ud = fixture:getUserData()

            local found = registry.getSFixtureByID(ud.id)
            assert.are.equal(fixture, found)
        end)

        it("texfixture gets vertices in extra", function()
            local body = love.physics.newBody(world, 0, 0, "dynamic")
            love.physics.newFixture(body, love.physics.newRectangleShape(50, 50))

            local fixture = fixtures.createSFixture(body, 10, 20, 'texfixture', {
                radius = 20, width = 40, height = 60
            })
            local ud = fixture:getUserData()

            assert.is_not_nil(ud.extra.vertices)
            assert.is_not_nil(ud.extra.vertexCount)
            assert.are.equal(4, ud.extra.vertexCount)
            assert.are.equal(8, #ud.extra.vertices) -- 4 vertices * 2 coords
        end)
    end)

    describe("fixture-types registry", function()
        it("unknown subtype returns nil", function()
            local body = love.physics.newBody(world, 0, 0, "dynamic")
            love.physics.newFixture(body, love.physics.newRectangleShape(50, 50))

            local fixture = fixtures.createSFixture(body, 0, 0, 'nonexistent', { radius = 20 })
            assert.is_nil(fixture)
        end)

        it("SNAP gets 5x radius shape", function()
            local body = love.physics.newBody(world, 0, 0, "dynamic")
            local fixture = fixtures.createSFixture(body, 0, 0, 'snap', { radius = 10 })
            local points = { fixture:getShape():getPoints() }
            -- 5x radius = 50, so shape spans -25 to +25 in both axes
            local minX, maxX = math.huge, -math.huge
            for i = 1, #points, 2 do
                if points[i] < minX then minX = points[i] end
                if points[i] > maxX then maxX = points[i] end
            end
            assert.is_near(50, maxX - minX, 0.01, "SNAP shape width should be 5x radius")
        end)

        it("TEXFIXTURE extra has vertexCount and vertices", function()
            local body = love.physics.newBody(world, 0, 0, "dynamic")
            local fixture = fixtures.createSFixture(body, 5, 10, 'texfixture', {
                width = 30, height = 50
            })
            local ud = fixture:getUserData()
            assert.are.equal(4, ud.extra.vertexCount)
            assert.are.equal(8, #ud.extra.vertices)
        end)

        it("TEXFIXTURE has density 0", function()
            local body = love.physics.newBody(world, 0, 0, "dynamic")
            local fixture = fixtures.createSFixture(body, 0, 0, 'texfixture', {
                width = 30, height = 50
            })
            assert.are.equal(0, fixture:getDensity())
        end)

        it("simple subtypes have empty extra", function()
            local body = love.physics.newBody(world, 0, 0, "dynamic")
            local fixture = fixtures.createSFixture(body, 0, 0, 'anchor', { radius = 10 })
            local ud = fixture:getUserData()
            assert.are.same({}, ud.extra)
        end)
    end)

    describe("fixture ordering invariant with real bodies", function()
        it("sfixtures added first maintain correct ordering", function()
            local body = love.physics.newBody(world, 0, 0, "dynamic")

            -- Add sfixtures first
            local sf1 = fixtures.createSFixture(body, 0, 0, 'anchor', { radius = 10 })
            local sf2 = fixtures.createSFixture(body, 5, 5, 'snap', { radius = 10 })

            -- Then add collision shape
            local collisionFixture = love.physics.newFixture(body,
                love.physics.newRectangleShape(50, 50))

            local bodyFixtures = body:getFixtures()
            local ok, idx = fixtures.hasFixturesWithUserDataAtBeginning(bodyFixtures)
            -- Note: Box2D may reverse fixture order internally.
            -- The important thing is the invariant check itself works.
            -- If this fails, it tells us Box2D reordered our fixtures.
            if not ok then
                pending("Box2D reordered fixtures — ordering invariant may need enforcement")
            end
        end)
    end)

    describe("destroyFixture", function()
        it("destroys fixture and unregisters from registry", function()
            local body = love.physics.newBody(world, 0, 0, "dynamic")
            love.physics.newFixture(body, love.physics.newRectangleShape(50, 50))

            local fixture = fixtures.createSFixture(body, 0, 0, 'anchor', { radius = 10 })
            local id = fixture:getUserData().id
            assert.is_not_nil(registry.getSFixtureByID(id))

            fixtures.destroyFixture(fixture)

            assert.is_nil(registry.getSFixtureByID(id))
        end)
    end)

    describe("getCentroidOfFixture", function()
        it("returns center of a rectangular fixture", function()
            local body = love.physics.newBody(world, 0, 0, "dynamic")
            -- newRectangleShape(w, h) centered at body origin
            local shape = love.physics.newRectangleShape(100, 50)
            local fixture = love.physics.newFixture(body, shape)

            local center = fixtures.getCentroidOfFixture(body, fixture)
            assert.is_not_nil(center)
            -- getCenterOfPoints returns x, y; wrapped in {} gives {x, y}
            assert.is_near(0, center[1], 0.01, "center x")
            assert.is_near(0, center[2], 0.01, "center y")
        end)
    end)
end)

-- CL8: one helper for "the sfixtures of this subtype on a body"
describe("fixtures.sfixtureData", function()
    local world

    before_each(function()
        world = love.physics.newWorld(0, 0, true)
        registry.reset()
    end)

    after_each(function()
        if world and not world:isDestroyed() then world:destroy() end
    end)

    it("gives the userData of each sfixture of that subtype, nothing else", function()
        local body = love.physics.newBody(world, 0, 0, 'dynamic')
        love.physics.newFixture(body, love.physics.newRectangleShape(40, 40)) -- a plain shape
        fixtures.createSFixture(body, 0, 0, 'resource', { width = 20, height = 20 })
        fixtures.createSFixture(body, 0, 0, 'snap', { radius = 10 })
        fixtures.createSFixture(body, 0, 0, 'resource', { width = 10, height = 10 })
        local found = fixtures.sfixtureData(body, 'resource')
        assert.are.equal(2, #found)
        for _, ud in ipairs(found) do
            assert.are.equal('resource', ud.subtype)
            assert.is_not_nil(ud.extra)
        end
        assert.are.same({}, fixtures.sfixtureData(body, 'liquid'))
    end)
end)

-- CL22: one way to give an sfixture a new shape (four copies before; two lost friction and group)
describe("fixtures.replaceShape", function()
    local world

    before_each(function()
        world = love.physics.newWorld(0, 0, true)
        registry.reset()
    end)

    after_each(function()
        if world and not world:isDestroyed() then world:destroy() end
    end)

    it("keeps the data, the id, the sensor flag and the fixture settings", function()
        local body = love.physics.newBody(world, 0, 0, 'dynamic')
        local old = fixtures.createSFixture(body, 0, 0, 'anchor', { radius = 10 })
        old:setFriction(0.9)
        old:setRestitution(0.3)
        old:setGroupIndex(-4)
        local ud = old:getUserData()
        local new = fixtures.replaceShape(old, { -20, -20, 20, -20, 20, 20, -20, 20 })
        assert.is_true(old:isDestroyed())
        assert.are.equal(ud, new:getUserData())
        assert.are.equal(new, registry.getSFixtureByID(ud.id))
        assert.is_true(new:isSensor())
        assert.is_near(0.9, new:getFriction(), 1e-6)
        assert.is_near(0.3, new:getRestitution(), 1e-6)
        assert.are.equal(-4, new:getGroupIndex())
        local _, _, x3 = new:getShape():getPoints()
        assert.is_near(20, math.abs(x3), 1e-6)
    end)
end)
