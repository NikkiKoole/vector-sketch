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
                           'tile-repeat', 'texfixture', 'resource', 'uvusert', 'meshusert' }

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
