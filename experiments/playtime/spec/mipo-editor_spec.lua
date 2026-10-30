-- spec/mipo-editor_spec.lua
-- BUG14 (docs/CODE-BUGS-2026-10.md): with a skin panel open, its patch sliders
-- rebuilt the Mipo's textures every frame. ui.sliderWithInput returns nil when
-- nothing changed and `nil ~= 0` is true. It also returned a string when dragged.
-- Run with: love . --specs spec/mipo-editor_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local ui = require('src.ui.all')
local CM = require('src.character-manager')
local mipoEditor = require('src.ui.mipo-editor')

describe('mipo editor', function()
    local world, instance

    setup(function()
        local font = love.graphics.newFont(12)
        love.graphics.setFont(font)
        ui.init(font, font:getHeight())
    end)

    before_each(function()
        world = love.physics.newWorld(0, 0, true)
        state.physicsWorld = world
        registry.reset()
        instance = CM.createCharacter('humanoid', 0, 0, 0.3)
        ui.startFrame()
    end)

    after_each(function()
        mipoEditor._test.accordionStates['torso1 skin'] = nil
        mipoEditor._test.accordionStates['torso1_skin_patch1'] = nil
        require('src.mipo-registry').reset()
        if world and not world:isDestroyed() then world:destroy() end
        state.physicsWorld = nil
        registry.reset()
    end)

    it("an open skin panel doesn't rebuild textures when nothing is touched", function()
        mipoEditor._test.accordionStates['torso1 skin'] = true
        mipoEditor._test.accordionStates['torso1_skin_patch1'] = true -- its x/y/sx/sy/rot sliders
        local rebuilds = 0
        local original = CM.addTexturesFromInstance2
        CM.addTexturesFromInstance2 = function(...)
            rebuilds = rebuilds + 1
            return original(...)
        end
        local canvas = love.graphics.newCanvas(1200, 768)
        love.graphics.setCanvas(canvas)
        local ok, err = pcall(mipoEditor.drawMipoEditor, instance, 'torso1', 800, 0, 380, 768)
        love.graphics.setCanvas()
        canvas:release()
        CM.addTexturesFromInstance2 = original
        assert.is_true(ok, tostring(err))
        assert.are.equal(0, rebuilds)
    end)
end)
