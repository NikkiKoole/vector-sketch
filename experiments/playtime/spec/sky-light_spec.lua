-- spec/sky-light_spec.lua
-- The light at the sky's hour (src/sky-light.lua, docs/SKY.md SK2): the sun up by day and the moon by
-- night, the shadows thrown away from whichever leads (long when it's low), and a scene with a sky gets
-- its light level's lights from the clock without touching the noon defaults other scenes use.
-- Run with: love . --specs spec/sky-light_spec.lua

if not love then return end

local state = require('src.state')
local skyLight = require('src.sky-light')
local sceneLight = require('src.scene-light')
local sceneSky = require('src.scene-sky')

describe('the light at the hour', function()
    it('the sun by day, the moon by night', function()
        local noon = skyLight.at(12)
        assert.is_true(noon.sun[4] > 1, 'the sun strong at noon')
        assert.are.equal(0, noon.moon[4])
        assert.is_true(noon.sun[2] < -0.9, 'from high up')
        local midnight = skyLight.at(0)
        assert.are.equal(0, midnight.sun[4])
        assert.is_true(midnight.moon[4] > 0.2, 'the moon at midnight')
    end)

    it('casts away from a low evening sun, and fades the shadows through the handover', function()
        local evening = skyLight.at(17.5)
        assert.is_true(evening.cast[1] > 0.5, 'the sun low on the right')
        local x, y = evening.cast[1], evening.cast[2]
        assert.is_true(math.abs(x) > math.abs(y), 'low: more across than down')
        assert.is_true(skyLight.at(12).fade > skyLight.at(18.6).fade, 'darker shadows by day')
    end)

    it('changes smoothly: no jump between two minutes anywhere in the day', function()
        local prev = skyLight.at(0)
        for minute = 1, 24 * 60 do
            local now = skyLight.at(minute / 60)
            assert.is_true(math.abs(now.sun[4] - prev.sun[4]) < 0.05, 'sun at minute ' .. minute)
            assert.is_true(math.abs(now.moon[4] - prev.moon[4]) < 0.05, 'moon at minute ' .. minute)
            assert.is_true(math.abs(now.fade - prev.fade) < 0.05, 'shadows at minute ' .. minute)
            prev = now
        end
    end)
end)

describe('a scene with a sky', function()
    before_each(function()
        sceneSky.load(nil)
        sceneLight.load(nil)
        state.contactShadows, state.sceneDefaultLights, state.backdropShadows = nil, nil, nil
    end)

    after_each(function()
        sceneSky.load(nil)
        sceneLight.load(nil)
        state.contactShadows, state.sceneDefaultLights, state.backdropShadows = nil, nil, nil
    end)

    it("gets its lights from the clock, and leaves the noon defaults as they were", function()
        sceneLight.load({ level = 'shadows' })
        sceneLight.apply()
        local noonDefault = state.sceneDefaultLights
        assert.are.equal(1.2, noonDefault[1].intensity)

        sceneSky.load({ hour = 19.5 })
        sceneLight.apply()
        local lights = state.sceneDefaultLights
        assert.are_not.equal(noonDefault, lights, 'its own tables')
        assert.are.equal(4, #lights, 'sun, moon, sky light, back light')
        local dusk = lights[1].intensity
        sceneSky.settings().hour = 12
        sceneLight.apply()
        assert.is_true(lights[1].intensity > dusk, 'the sun stronger at noon than at 19:30')
        assert.is_truthy(state.backdropShadows.behind, 'the wall shadow knows how far behind')

        sceneSky.load(nil)
        sceneLight.apply()
        assert.are.equal(noonDefault, state.sceneDefaultLights, 'no sky: the noon defaults again')
        assert.are.equal(1.2, noonDefault[1].intensity, 'untouched')
    end)
end)
