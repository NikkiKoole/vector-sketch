-- spec/influences-missing-node_spec.lua
-- A skinned mesh (MESHUSERT) names its bones by the joints and anchors they hang on. When one of
-- those is gone from the file (deleted, or a clone of the mesh alone whose original rig was deleted
-- later), the scene didn't load at all: influences.restoreBodies indexed the missing joint / anchor
-- (influences.lua: attempt to index local 'anchor' (a nil value)). Now that bone gets no body, the
-- way skinning already treats a bone whose body was destroyed: it's left out of the blend.
-- Run with: love . --specs spec/influences-missing-node_spec.lua

if not love then return end

local json = require('vendor.dkjson')
local state = require('src.state')
local registry = require('src.registry')
local sceneIO = require('src.io')
local camera = require('src.camera')
local NT = require('src.node-types')
local SIDES = require('src.sides')

describe('a skinned mesh whose bone is gone', function()
    local world

    before_each(function()
        registry.reset()
        world = love.physics.newWorld(0, 0, true)
        state.physicsWorld = world
    end)

    after_each(function()
        world:destroy()
        state.physicsWorld = nil
        registry.reset()
    end)

    it('restores no body for a joint or an anchor that is not there', function()
        local list = { {
            { nodeType = NT.JOINT, nodeId = 'no-such-joint', side = SIDES.A, dx = 3, dy = 4, w = 0.5 },
            { nodeType = NT.ANCHOR, nodeId = 'no-such-anchor', dx = 0, dy = 0, w = 0.5 },
        } }
        sceneIO._test.restoreInfluenceBodies(list)
        assert.is_nil(list[1][1].body)
        assert.is_nil(list[1][2].body)
        assert.are.equal(5, list[1][1].dist)
    end)

    it('loads the scene, the mesh still on its body', function()
        local scene = json.decode((love.filesystem.read('scripts/tech/hoop.playtime.json')))
        scene.joints = {} -- every joint the mesh hangs on gone
        sceneIO.load(json.encode(scene), world, camera.getInstance())
        local mesh
        for _, fixture in pairs(registry.sfixtures) do
            if fixture:getUserData().subtype == 'meshusert' then mesh = fixture end
        end
        assert.is_truthy(mesh, 'the mesh loaded')
        assert.is_truthy(mesh:getUserData().extra.influences)
        -- and it draws, with the bones it has left
        local canvas = love.graphics.newCanvas(64, 64)
        love.graphics.setCanvas({ canvas, stencil = true })
        local ok, err = pcall(require('src.physics.box2d-draw-textured').drawTexturedWorld, world)
        love.graphics.setCanvas()
        assert.is_true(ok, tostring(err))
    end)
end)
