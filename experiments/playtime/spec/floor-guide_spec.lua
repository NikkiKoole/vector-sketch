-- spec/floor-guide_spec.lua
-- The light floor on the stage (src/floor-guide.lua): shown only while the settings panel's light
-- section is open; dragging the stand line moves the floor, dragging the wall's foot changes the depth.
-- Run with: love . --specs spec/floor-guide_spec.lua

if not love then return end

local state = require('src.state')
local camera = require('src.camera')
local sceneLight = require('src.scene-light')
local floorGuide = require('src.floor-guide')

describe('the floor guide', function()
    local cam, pv, folds

    before_each(function()
        cam = camera.getInstance()
        cam:setScale(1)
        cam:setTranslation(0, 0)
        sceneLight.load({ level = 'full', floor = { standY = 100, depth = 300 } })
        pv = state.panelVisibility.worldSettingsOpened
        folds = state.settingsFolds
        state.panelVisibility.worldSettingsOpened = true
        state.settingsFolds = { light = true }
        state.floorGuideOn = true
        state.interaction.floorDrag = nil
    end)

    after_each(function()
        state.panelVisibility.worldSettingsOpened = pv
        state.settingsFolds = folds
        state.floorGuideOn = nil
        state.interaction.floorDrag = nil
        sceneLight.load(nil)
    end)

    local function screenY(wy)
        local _, sy = cam:getScreenCoordinates(0, wy)
        return sy
    end

    it("is off unless 'floor on stage' is ticked", function()
        state.floorGuideOn = nil
        assert.is_nil(floorGuide.floor())
        assert.is_false(floorGuide.pressed(400, screenY(100)))
    end)

    it('is there only while the light section is open', function()
        assert.is_truthy(floorGuide.floor())
        state.settingsFolds.light = false
        assert.is_nil(floorGuide.floor())
        assert.is_false(floorGuide.pressed(400, screenY(100)))
    end)

    it('the stand line moves the floor', function()
        assert.is_true(floorGuide.pressed(400, screenY(100) + 3))
        floorGuide.moved(400, screenY(100) + 3 + 50)
        assert.is_true(floorGuide.released())
        assert.are.equal(150, sceneLight.settings().floor.standY)
        assert.are.equal(300, sceneLight.settings().floor.depth)
    end)

    it("the wall's foot changes the depth (up: deeper)", function()
        assert.is_true(floorGuide.pressed(400, screenY(-200)))
        floorGuide.moved(400, screenY(-200) - 40)
        floorGuide.released()
        assert.are.equal(340, sceneLight.settings().floor.depth)
        assert.are.equal(100, sceneLight.settings().floor.standY)
    end)

    it('a press away from the lines is not taken', function()
        assert.is_false(floorGuide.pressed(400, screenY(0)))
    end)
end)
