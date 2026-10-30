-- spec/omp-bake_spec.lua
-- M9 (docs/MEASURING.md): a picture that isn't there is looked up once, not every frame.
if not love then return end

local ompBake = require('src.render.omp-bake')

describe('omp-bake getLoveImage', function()
    it('asks the filesystem once for a missing picture', function()
        local getInfo, asked = love.filesystem.getInfo, 0
        love.filesystem.getInfo = function(path, ...)
            if path == 'textures/no-such-picture-m9.png' then asked = asked + 1 end
            return getInfo(path, ...)
        end
        for _ = 1, 5 do assert.is_nil(ompBake.getLoveImage('textures/no-such-picture-m9.png')) end
        love.filesystem.getInfo = getInfo
        assert.are.equal(1, asked)
    end)

    it('still loads pictures that are there', function()
        local img, w, h = ompBake.getLoveImage('textures/shapes6.png')
        assert.is_not_nil(img)
        assert.is_true(w > 0 and h > 0)
    end)
end)
