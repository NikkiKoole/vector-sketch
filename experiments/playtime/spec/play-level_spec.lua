-- spec/play-level_spec.lua
-- What the pointer does as play (src/play-level.lua): holding counts a little, dragging more the
-- faster it goes, letting go counts by how hard it was thrown; held still, the level settles under
-- the band's join.

local state = require('src.state')

-- a body moving at vx px/s (the specs run at the reference meter, 100 px/m, where speeds are as tuned)
local function movingBody(vx)
    return { getLinearVelocity = function() return vx, 0 end }
end

describe('play level', function()
    local playLevel, bumps, held, savedMusic, savedPointer, savedState, savedUnits

    before_each(function()
        savedMusic, savedPointer = package.loaded['src.music'], package.loaded['src.physics.box2d-pointerjoints']
        savedUnits, savedState = package.loaded['src.physics-units'], state.playLevel
        bumps, held = {}, {}
        package.loaded['src.music'] = { bump = function(amount) bumps[#bumps + 1] = amount end }
        package.loaded['src.physics.box2d-pointerjoints'] = { getInteractedWithPointer = function() return held end }
        package.loaded['src.physics-units'] = { toReferenceSpeed = function(v) return v end }
        package.loaded['src.play-level'], state.playLevel = nil, nil
        playLevel = require('src.play-level')
    end)

    after_each(function()
        package.loaded['src.music'], package.loaded['src.physics.box2d-pointerjoints'] = savedMusic, savedPointer
        package.loaded['src.physics-units'], state.playLevel = savedUnits, savedState
        package.loaded['src.play-level'] = nil
    end)

    local function total()
        local sum = 0
        for _, amount in ipairs(bumps) do sum = sum + amount end
        return sum
    end

    it('counts nothing while nothing is held', function()
        playLevel.update(1)
        assert.equals(0, total())
    end)

    it('counts holding still a little and dragging fast more', function()
        held = { movingBody(0) }
        playLevel.update(1)
        assert.near(playLevel.hold, total(), 1e-9)
        bumps = {}
        held = { movingBody(playLevel.dragSpeed * 3) }
        playLevel.update(1)
        assert.near(playLevel.hold + playLevel.drag, total(), 1e-9)
    end)

    it('counts letting go by how hard it was thrown', function()
        held = { movingBody(playLevel.throwSpeed / 2) }
        playLevel.update(0)
        held = {}
        playLevel.update(0)
        assert.near(playLevel.throw / 2, bumps[#bumps], 1e-9)
    end)

    it('settles under the band when something is only held still', function()
        -- the music halves the level every 8 s (music-styles' activityHalfLife), the band joins at 4
        local rate = playLevel.hold
        assert.is_true(rate / (math.log(2) / 8) < 4)
    end)
end)
