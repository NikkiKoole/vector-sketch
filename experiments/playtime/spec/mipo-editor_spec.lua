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
        local original = CM.rebuildTextures
        CM.rebuildTextures = function(...)
            rebuilds = rebuilds + 1
            return original(...)
        end
        local canvas = love.graphics.newCanvas(1200, 768)
        love.graphics.setCanvas(canvas)
        local ok, err = pcall(mipoEditor.drawMipoEditor, instance, 'torso1', 800, 0, 380, 768)
        love.graphics.setCanvas()
        canvas:release()
        CM.rebuildTextures = original
        assert.is_true(ok, tostring(err))
        assert.are.equal(0, rebuilds)
    end)

    it('draws every panel open, for every part', function()
        local states = mipoEditor._test.accordionStates
        local opened = {}
        for name in pairs(instance.dna.parts) do
            for _, suffix in ipairs({ ' shape', ' dims', ' skin', ' bodyhair', ' face', ' connected skin',
                ' connected hair', '_skin_patch1', '_skin_patch2', '_skin_patch3' }) do
                states[name .. suffix] = true
                opened[#opened + 1] = name .. suffix
            end
        end
        for _, key in ipairs({ 'creation', 'positioners', 'actions', 'torso shape' }) do
            states[key] = true
            opened[#opened + 1] = key
        end
        local canvas = love.graphics.newCanvas(1200, 768)
        love.graphics.setCanvas(canvas)
        local failed
        for name in pairs(instance.dna.parts) do
            local ok, err = pcall(mipoEditor.drawMipoEditor, instance, name, 800, 0, 380, 768)
            if not ok then failed = name .. ': ' .. tostring(err) break end
        end
        love.graphics.setCanvas()
        canvas:release()
        for _, key in ipairs(opened) do states[key] = nil end
        assert.is_nil(failed)
    end)

    -- CL15: 'this part, its mirror if symmetric, then rebuild once' in one place
    describe('editing a part and its mirror', function()
        local t = mipoEditor._test
        after_each(function() t.accordionStates.symmetricEditing = true end)

        it('takes the mirror only with symmetric editing on', function()
            t.accordionStates.symmetricEditing = true
            assert.are.same({ 'lear', 'rear' }, t.partAndMirror(instance, 'lear'))
            assert.are.same({ 'head' }, t.partAndMirror(instance, 'head'))
            t.accordionStates.symmetricEditing = false
            assert.are.same({ 'luarm' }, t.partAndMirror(instance, 'luarm'))
        end)

        it('edits both and rebuilds the textures once', function()
            local edited, rebuilds = {}, 0
            local original = CM.rebuildTextures
            CM.rebuildTextures = function() rebuilds = rebuilds + 1 end
            t.editPartAndMirror(instance, 'lfoot', function(name) edited[#edited + 1] = name end)
            CM.rebuildTextures = original
            assert.are.same({ 'lfoot', 'rfoot' }, edited)
            assert.are.equal(1, rebuilds)
        end)

        it('edits bodyhair on every torso segment', function()
            CM.rebuildFromCreation(instance, { torsoSegments = 3 })
            assert.are.same({ 'torso1', 'torso2', 'torso3' }, t.bodyhairParts(instance, 'torso2'))
        end)
    end)
end)
