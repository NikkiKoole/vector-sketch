--[[
    Integration tests for physics world creation

    These tests require LÖVE to run.
    Run with: love . --test
]]

local T = require 'tests.mini-test'

T.describe("physics world (integration)", function()

    T.describe("world creation", function()
        T.it("can create a physics world", function()
            local world = love.physics.newWorld(0, 9.81 * 100, true)
            T.expect(world).toNotBeNil()
            T.expect(world:getBodyCount()).toBe(0)
            world:destroy()
        end)

        T.it("can add a body to the world", function()
            local world = love.physics.newWorld(0, 9.81 * 100, true)
            local body = love.physics.newBody(world, 100, 100, "dynamic")

            T.expect(world:getBodyCount()).toBe(1)
            T.expect(body:getX()).toBe(100)
            T.expect(body:getY()).toBe(100)

            world:destroy()
        end)

        T.it("can add a fixture to a body", function()
            local world = love.physics.newWorld(0, 9.81 * 100, true)
            local body = love.physics.newBody(world, 100, 100, "dynamic")
            local shape = love.physics.newRectangleShape(50, 50)
            local fixture = love.physics.newFixture(body, shape)

            T.expect(fixture).toNotBeNil()
            T.expect(fixture:getBody()).toBe(body)

            world:destroy()
        end)
    end)

    T.describe("joints", function()
        T.it("can create a revolute joint between two bodies", function()
            local world = love.physics.newWorld(0, 9.81 * 100, true)
            local bodyA = love.physics.newBody(world, 100, 100, "dynamic")
            local bodyB = love.physics.newBody(world, 150, 100, "dynamic")

            local joint = love.physics.newRevoluteJoint(bodyA, bodyB, 125, 100)

            T.expect(joint).toNotBeNil()
            T.expect(joint:getType()).toBe("revolute")
            T.expect(#world:getJoints()).toBe(1)

            world:destroy()
        end)
    end)

    T.describe("simulation", function()
        T.it("updates body position after world step", function()
            local world = love.physics.newWorld(0, 100, true)  -- gravity down
            local body = love.physics.newBody(world, 100, 0, "dynamic")
            local shape = love.physics.newCircleShape(10)
            love.physics.newFixture(body, shape)

            local initialY = body:getY()

            -- Step the simulation
            world:update(1/60)

            -- Body should have fallen
            T.expect(body:getY()).toBeGreaterThan(initialY)

            world:destroy()
        end)
    end)

end)
