-- spec/ear-bend_spec.lua
-- A Mipo ear's picture: its root stays where the ear is at rest, its tip follows the ear.
local earBend = require('src.ear-bend')

-- a body at (x, y) turned by angle, as far as deform needs one
local function fakeBody(x, y, angle)
    local cos, sin = math.cos(angle), math.sin(angle)
    return {
        getWorldPoint = function(_, px, py) return x + px * cos - py * sin, y + px * sin + py * cos end,
        getLocalPoint = function(_, wx, wy)
            local dx, dy = wx - x, wy - y
            return dx * cos + dy * sin, -dx * sin + dy * cos
        end,
    }
end

local function near(a, b) return math.abs(a - b) < 1e-9 end

describe("ear-bend", function()
    -- head at the origin; the ear's root (0, 50 on the ear) sits on the head at (100, 0),
    -- the ear upright at rest (reference angle 0); here it has turned 30 degrees round its root
    local turn = math.rad(30)
    local head = fakeBody(0, 0, 0)
    local ear = fakeBody(100 + 50 * math.sin(turn), -50 * math.cos(turn), turn)
    local bones = {
        ear = ear, parent = head, restAngle = 0,
        anchorX = 100, anchorY = 0, rootX = 0, rootY = 50,
        axisX = 0, axisY = -1, length = 100,
    }

    it("keeps the root, and what is below it, where the ear is at rest", function()
        local out = earBend.deform({ -20, 50, 20, 60 }, bones)
        -- back in the ear's space: where the rest pose has those points
        local wx, wy = ear:getWorldPoint(out[1], out[2])
        assert.is_true(near(wx, 80) and near(wy, 0))
        wx, wy = ear:getWorldPoint(out[3], out[4])
        assert.is_true(near(wx, 120) and near(wy, 10))
    end)

    it("leaves the top of the ear on the ear", function()
        local out = earBend.deform({ 10, -50 }, bones)
        assert.is_true(near(out[1], 10) and near(out[2], -50))
    end)

    it("blends in between", function()
        local y = 50 - earBend.bendLength * 100 / 2 -- halfway up the bend
        local out = earBend.deform({ 0, y }, bones)
        local wx = ear:getWorldPoint(out[1], out[2])
        local restX = 100
        local earX = ear:getWorldPoint(0, y)
        assert.is_true(wx > math.min(restX, earX) and wx < math.max(restX, earX))
    end)
end)
