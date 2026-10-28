-- spec/texture-or-body_spec.lua
-- The 'tex/body' view (src/physics/box2d-draw.lua): a body with a texture
-- sfixture shows only its texture, other bodies still draw as bodies; with
-- 'mipo body' on, Mipo parts keep their body shapes too.
-- Run with: love . --specs spec/texture-or-body_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local objectManager = require('src.object-manager')
local fixtures = require('src.fixtures')
local box2dDraw = require('src.physics.box2d-draw')

describe('tex/body view', function()
    local world

    before_each(function()
        world = love.physics.newWorld(0, 0, true)
        state.physicsWorld = world
        registry.reset()
    end)

    after_each(function()
        state.world.textureOrBody = nil
        if world and not world:isDestroyed() then world:destroy() end
    end)

    it('counts texture kinds, not snaps, anchors or ribbons', function()
        local plain = objectManager.addThing('rectangle', { x = 0, y = 0, width = 40, height = 40 })
        local snapped = objectManager.addThing('rectangle', { x = 100, y = 0, width = 40, height = 40 })
        local textured = objectManager.addThing('rectangle', { x = 200, y = 0, width = 40, height = 40 })
        fixtures.createSFixture(snapped.body, 0, 0, 'snap', { radius = 10 })
        fixtures.createSFixture(textured.body, 0, 0, 'texfixture', { width = 40, height = 40 })
        assert.is_false(box2dDraw.hasTexture(plain.body))
        assert.is_false(box2dDraw.hasTexture(snapped.body))
        assert.is_true(box2dDraw.hasTexture(textured.body))
    end)

    it("'mipo body' keeps Mipo parts drawn as bodies, other textured bodies not", function()
        local textured = objectManager.addThing('rectangle', { x = 200, y = 0, width = 40, height = 40 })
        fixtures.createSFixture(textured.body, 0, 0, 'texfixture', { width = 40, height = 40 })
        local part = objectManager.addThing('rectangle', { x = 300, y = 0, width = 40, height = 40 })
        fixtures.createSFixture(part.body, 0, 0, 'texfixture', { width = 40, height = 40 })
        part.mipoId = 'mipo1'
        state.world.mipoBodies = false
        assert.is_false(box2dDraw.showsBody(part.body))
        state.world.mipoBodies = true
        assert.is_true(box2dDraw.showsBody(part.body))
        assert.is_false(box2dDraw.showsBody(textured.body))
        state.world.mipoBodies = nil
    end)

    it('draws with the view on', function()
        local textured = objectManager.addThing('rectangle', { x = 200, y = 0, width = 40, height = 40 })
        fixtures.createSFixture(textured.body, 0, 0, 'texfixture', { width = 40, height = 40 })
        objectManager.addThing('rectangle', { x = 0, y = 0, width = 40, height = 40 })
        state.world.textureOrBody = true
        local canvas = love.graphics.newCanvas(200, 200)
        love.graphics.setCanvas(canvas)
        local ok, err = pcall(box2dDraw.drawWorld, world, true)
        love.graphics.setCanvas()
        canvas:release()
        assert.is_true(ok, tostring(err))
    end)

    it('the selection box draws for a plain body and for nothing selected', function()
        local editorRender = require('src.editor-render')
        local thing = objectManager.addThing('rectangle', { x = 0, y = 0, width = 40, height = 40 })
        local canvas = love.graphics.newCanvas(200, 200)
        love.graphics.setCanvas(canvas)
        state.selection.selectedObj = nil
        local ok1, err1 = pcall(editorRender.renderSelectionBox)
        state.selection.selectedObj = thing
        local ok2, err2 = pcall(editorRender.renderSelectionBox)
        state.selection.selectedObj = nil
        love.graphics.setCanvas()
        canvas:release()
        assert.is_true(ok1, tostring(err1))
        assert.is_true(ok2, tostring(err2))
    end)
end)
