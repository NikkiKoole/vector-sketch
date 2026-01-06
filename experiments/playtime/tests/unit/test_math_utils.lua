--[[
    Unit tests for src/math-utils.lua

    Run with: lua tests/run.lua
    (These tests don't require LÖVE)
]]

local T = require 'tests.mini-test'
local mathUtils = require 'src.math-utils'

T.describe("math-utils", function()

    T.describe("lerp", function()
        T.it("interpolates between two values at t=0", function()
            T.expect(mathUtils.lerp(0, 100, 0)).toBe(0)
        end)

        T.it("interpolates between two values at t=1", function()
            T.expect(mathUtils.lerp(0, 100, 1)).toBe(100)
        end)

        T.it("interpolates between two values at t=0.5", function()
            T.expect(mathUtils.lerp(0, 100, 0.5)).toBe(50)
        end)

        T.it("works with negative values", function()
            T.expect(mathUtils.lerp(-100, 100, 0.5)).toBe(0)
        end)
    end)

    T.describe("calculateDistance", function()
        T.it("returns 0 for same point", function()
            T.expect(mathUtils.calculateDistance(5, 5, 5, 5)).toBe(0)
        end)

        T.it("calculates horizontal distance", function()
            T.expect(mathUtils.calculateDistance(0, 0, 10, 0)).toBe(10)
        end)

        T.it("calculates vertical distance", function()
            T.expect(mathUtils.calculateDistance(0, 0, 0, 10)).toBe(10)
        end)

        T.it("calculates diagonal distance (3-4-5 triangle)", function()
            T.expect(mathUtils.calculateDistance(0, 0, 3, 4)).toBe(5)
        end)
    end)

    T.describe("getCenterOfPoints", function()
        T.it("finds center of a square", function()
            -- Square from (0,0) to (10,10)
            local points = {0, 0, 10, 0, 10, 10, 0, 10}
            local cx, cy, w, h = mathUtils.getCenterOfPoints(points)
            T.expect(cx).toBe(5)
            T.expect(cy).toBe(5)
        end)

        T.it("finds center of a rectangle", function()
            -- Rectangle from (0,0) to (20,10)
            local points = {0, 0, 20, 0, 20, 10, 0, 10}
            local cx, cy, w, h = mathUtils.getCenterOfPoints(points)
            T.expect(cx).toBe(10)
            T.expect(cy).toBe(5)
        end)
    end)

    T.describe("getLengthOfPath", function()
        T.it("returns 0 for single point", function()
            local path = {{0, 0}}
            T.expect(mathUtils.getLengthOfPath(path)).toBe(0)
        end)

        T.it("calculates length of straight horizontal line", function()
            local path = {{0, 0}, {10, 0}}
            T.expect(mathUtils.getLengthOfPath(path)).toBe(10)
        end)

        T.it("calculates length of path with multiple segments", function()
            -- Right 10, then up 10 = total 20
            local path = {{0, 0}, {10, 0}, {10, 10}}
            T.expect(mathUtils.getLengthOfPath(path)).toBe(20)
        end)
    end)

    T.describe("pointInRect", function()
        T.it("returns true for point inside rect", function()
            local rect = {x = 0, y = 0, width = 10, height = 10}
            T.expect(mathUtils.pointInRect(5, 5, rect)).toBeTruthy()
        end)

        T.it("returns false for point outside rect", function()
            local rect = {x = 0, y = 0, width = 10, height = 10}
            T.expect(mathUtils.pointInRect(15, 5, rect)).toBeFalsy()
        end)

        T.it("returns true for point on edge", function()
            local rect = {x = 0, y = 0, width = 10, height = 10}
            T.expect(mathUtils.pointInRect(0, 5, rect)).toBeTruthy()
        end)
    end)

    T.describe("computeCentroid", function()
        T.it("computes center of bounding box for triangle", function()
            -- Triangle at (0,0), (6,0), (3,6)
            -- Bounding box: x=0..6, y=0..6, so center is (3, 3)
            -- Note: computeCentroid uses getCenterOfPoints which returns bbox center
            local polygon = {0, 0, 6, 0, 3, 6}
            local cx, cy = mathUtils.computeCentroid(polygon)
            T.expect(cx).toBe(3)
            T.expect(cy).toBe(3)
        end)
    end)

end)
