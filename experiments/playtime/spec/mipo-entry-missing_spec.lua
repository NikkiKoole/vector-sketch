-- spec/mipo-entry-missing_spec.lua
-- A scene file whose Mipo bodies are there but the Mipo's own entry (its DNA, in `characters`) is
-- not: a damaged file. It loaded, but the first frame died in spine-skin (attempt to index local
-- 'instance', found by claudetools/scene-damage_spec.lua). The bodies draw as plain parts now.
-- Run with: love . --specs spec/mipo-entry-missing_spec.lua

if not love then return end

local json = require('vendor.dkjson')
local state = require('src.state')
local registry = require('src.registry')
local mipoRegistry = require('src.mipo-registry')
local sceneIO = require('src.io')
local camera = require('src.camera')
local draw = require('src.physics.box2d-draw-textured')

describe('a scene with Mipo bodies but no Mipo entry', function()
    before_each(function()
        registry.reset()
        mipoRegistry.reset()
        state.physicsWorld = love.physics.newWorld(0, 0, true)
    end)

    after_each(function()
        state.physicsWorld:destroy()
        state.physicsWorld = nil
        registry.reset()
        mipoRegistry.reset()
    end)

    it('loads and draws', function()
        local scene = json.decode((love.filesystem.read('scripts/spikes/fabuland.playtime.json')))
        assert.is_true(#scene.characters > 0)
        scene.characters = {}
        sceneIO.load(json.encode(scene), state.physicsWorld, camera.getInstance())
        assert.is_true(state.physicsWorld:getBodyCount() > 0)
        local canvas = love.graphics.newCanvas(128, 128)
        love.graphics.setCanvas({ canvas, stencil = true })
        local ok, err = pcall(function()
            draw.makeCombinedImages()
            draw.drawTexturedWorld(state.physicsWorld)
        end)
        love.graphics.setCanvas()
        assert.is_true(ok, tostring(err))
    end)
end)
