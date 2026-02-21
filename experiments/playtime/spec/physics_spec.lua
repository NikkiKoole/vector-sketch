-- spec/physics_spec.lua
-- Integration tests that use real LÖVE physics (no mocks)
-- Run with: love . --specs
-- Skipped by standalone busted (no LÖVE available)

if not love then return end

describe("physics world (integration)", function()

    local world

    before_each(function()
        world = love.physics.newWorld(0, 9.81 * 100, true)
    end)

    after_each(function()
        if world and not world:isDestroyed() then
            world:destroy()
        end
    end)

    describe("world creation", function()
        it("can create a physics world", function()
            assert.is_not_nil(world)
            assert.are.equal(0, world:getBodyCount())
        end)

        it("has correct gravity", function()
            local gx, gy = world:getGravity()
            assert.are.equal(0, gx)
            assert.is_near(981, gy, 0.01)
        end)
    end)

    describe("bodies", function()
        it("can add a body to the world", function()
            local body = love.physics.newBody(world, 100, 100, "dynamic")

            assert.are.equal(1, world:getBodyCount())
            assert.are.equal(100, body:getX())
            assert.are.equal(100, body:getY())
        end)

        it("can create all body types", function()
            local dynamic = love.physics.newBody(world, 0, 0, "dynamic")
            local static = love.physics.newBody(world, 0, 0, "static")
            local kinematic = love.physics.newBody(world, 0, 0, "kinematic")

            assert.are.equal("dynamic", dynamic:getType())
            assert.are.equal("static", static:getType())
            assert.are.equal("kinematic", kinematic:getType())
            assert.are.equal(3, world:getBodyCount())
        end)

        it("can set and get user data", function()
            local body = love.physics.newBody(world, 0, 0, "dynamic")
            local thing = { id = "test123", label = "torso", shapeType = "rectangle" }
            body:setUserData({ thing = thing })

            local ud = body:getUserData()
            assert.are.equal("test123", ud.thing.id)
            assert.are.equal("torso", ud.thing.label)
        end)
    end)

    describe("fixtures", function()
        it("can add a fixture to a body", function()
            local body = love.physics.newBody(world, 100, 100, "dynamic")
            local shape = love.physics.newRectangleShape(50, 50)
            local fixture = love.physics.newFixture(body, shape)

            assert.is_not_nil(fixture)
            assert.are.equal(body, fixture:getBody())
        end)

        it("can set fixture as sensor", function()
            local body = love.physics.newBody(world, 0, 0, "dynamic")
            local shape = love.physics.newCircleShape(10)
            local fixture = love.physics.newFixture(body, shape)

            assert.is_false(fixture:isSensor())
            fixture:setSensor(true)
            assert.is_true(fixture:isSensor())
        end)

        it("can store fixture user data", function()
            local body = love.physics.newBody(world, 0, 0, "dynamic")
            local shape = love.physics.newCircleShape(10)
            local fixture = love.physics.newFixture(body, shape)

            local ud = { type = "sfixture", subtype = "texfixture", id = "sf1" }
            fixture:setUserData(ud)

            assert.are.equal("sfixture", fixture:getUserData().type)
            assert.are.equal("sf1", fixture:getUserData().id)
        end)

        it("multiple fixtures maintain order on body", function()
            local body = love.physics.newBody(world, 0, 0, "dynamic")

            -- Add sfixtures first (with userData), then collision shapes (without)
            local sf1 = love.physics.newFixture(body, love.physics.newCircleShape(10))
            sf1:setUserData({ type = "sfixture", id = "a" })
            sf1:setSensor(true)

            local sf2 = love.physics.newFixture(body, love.physics.newCircleShape(10))
            sf2:setUserData({ type = "sfixture", id = "b" })
            sf2:setSensor(true)

            local col = love.physics.newFixture(body, love.physics.newRectangleShape(20, 20))
            -- no userData on collision fixture

            local fixtures = body:getFixtures()
            assert.are.equal(3, #fixtures)
        end)
    end)

    describe("joints", function()
        it("can create a revolute joint", function()
            local bodyA = love.physics.newBody(world, 100, 100, "dynamic")
            local bodyB = love.physics.newBody(world, 150, 100, "dynamic")

            local joint = love.physics.newRevoluteJoint(bodyA, bodyB, 125, 100)

            assert.is_not_nil(joint)
            assert.are.equal("revolute", joint:getType())
            assert.are.equal(1, #world:getJoints())
        end)

        it("can create a distance joint", function()
            local bodyA = love.physics.newBody(world, 0, 0, "dynamic")
            local bodyB = love.physics.newBody(world, 100, 0, "dynamic")

            local joint = love.physics.newDistanceJoint(bodyA, bodyB, 0, 0, 100, 0)

            assert.are.equal("distance", joint:getType())
        end)

        it("can create a rope joint", function()
            local bodyA = love.physics.newBody(world, 0, 0, "dynamic")
            local bodyB = love.physics.newBody(world, 100, 0, "dynamic")

            local joint = love.physics.newRopeJoint(bodyA, bodyB, 0, 0, 100, 0, 120)

            assert.are.equal("rope", joint:getType())
            assert.is_near(120, joint:getMaxLength(), 0.01)
        end)

        it("can store joint user data", function()
            local bodyA = love.physics.newBody(world, 0, 0, "dynamic")
            local bodyB = love.physics.newBody(world, 100, 0, "dynamic")
            local joint = love.physics.newRevoluteJoint(bodyA, bodyB, 50, 0)

            joint:setUserData({ id = "j1", offsetA = { x = 0, y = 0 } })

            assert.are.equal("j1", joint:getUserData().id)
        end)

        it("destroying a joint removes it from the world", function()
            local bodyA = love.physics.newBody(world, 0, 0, "dynamic")
            local bodyB = love.physics.newBody(world, 100, 0, "dynamic")
            local joint = love.physics.newRevoluteJoint(bodyA, bodyB, 50, 0)

            assert.are.equal(1, #world:getJoints())
            joint:destroy()
            assert.are.equal(0, #world:getJoints())
        end)
    end)

    describe("simulation", function()
        it("body falls under gravity", function()
            local body = love.physics.newBody(world, 100, 0, "dynamic")
            love.physics.newFixture(body, love.physics.newCircleShape(10))

            local initialY = body:getY()
            world:update(1/60)

            assert.is_true(body:getY() > initialY)
        end)

        it("static bodies don't move", function()
            local body = love.physics.newBody(world, 100, 100, "static")
            love.physics.newFixture(body, love.physics.newRectangleShape(50, 50))

            world:update(1/60)

            assert.are.equal(100, body:getX())
            assert.are.equal(100, body:getY())
        end)

        it("bodies collide with ground", function()
            -- Ground
            local ground = love.physics.newBody(world, 400, 500, "static")
            love.physics.newFixture(ground, love.physics.newRectangleShape(800, 20))

            -- Falling ball
            local ball = love.physics.newBody(world, 400, 100, "dynamic")
            love.physics.newFixture(ball, love.physics.newCircleShape(10))

            -- Run 300 frames (~5 seconds)
            for i = 1, 300 do
                world:update(1/60)
            end

            -- Ball should have settled near the ground, not fallen through
            assert.is_true(ball:getY() < 500)
            assert.is_true(ball:getY() > 400) -- close to ground
        end)

        it("revolute joint constrains bodies", function()
            local bodyA = love.physics.newBody(world, 100, 100, "static")
            love.physics.newFixture(bodyA, love.physics.newRectangleShape(20, 20))

            local bodyB = love.physics.newBody(world, 150, 100, "dynamic")
            love.physics.newFixture(bodyB, love.physics.newRectangleShape(20, 20))

            love.physics.newRevoluteJoint(bodyA, bodyB, 125, 100)

            -- Run simulation
            for i = 1, 120 do
                world:update(1/60)
            end

            -- bodyB should stay connected — distance from anchor should be constant
            local dx = bodyB:getX() - 125
            local dy = bodyB:getY() - 100
            local dist = math.sqrt(dx * dx + dy * dy)
            assert.is_near(25, dist, 2) -- should be ~25 (initial offset)
        end)
    end)
end)
