-- spec/mipo-joint-guard_spec.lua

describe("src.mipo-joint-guard", function()
    package.loaded['src.mipo-joint-guard'] = nil
    local guard = require('src.mipo-joint-guard')
    local pi = math.pi

    describe("turnsToUnwind", function()
        it("leaves angles within half a turn of the limit middle alone", function()
            assert.are.equal(0, guard.turnsToUnwind(0, 0, pi))
            assert.are.equal(0, guard.turnsToUnwind(pi + 1, 0, pi))   -- past the limit, but not wound
            assert.are.equal(0, guard.turnsToUnwind(-1, 0, pi))
        end)

        it("takes off whole turns when wound up", function()
            -- the recorded case: shoulder limits [0, pi], angle -39.62 (6.5 turns from the middle)
            local turns = guard.turnsToUnwind(-39.62, 0, pi)
            assert.are.equal(-7, turns)
            local unwound = -39.62 - turns * 2 * pi
            assert.is_true(unwound > pi / 2 - pi and unwound < pi / 2 + pi)
        end)

        it("works for positive wind-up", function()
            assert.are.equal(1, guard.turnsToUnwind(2 * pi + 0.2, -0.4, 0.4))
            assert.are.equal(2, guard.turnsToUnwind(4 * pi, -0.4, 0.4))
        end)
    end)
end)
