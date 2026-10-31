-- spec/meshusert-bind_spec.lua
-- Binding a skinned mesh to its bones (src/meshusert-bind.lua, out of the sfixture panel
-- since CL21), on the Knut 'hoop' scene: a MESHUSERT with its RESOURCE and nodes.
-- Run with: love . --specs spec/meshusert-bind_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local sceneIO = require('src.io')
local camera = require('src.camera')
local meshusertBind = require('src.meshusert-bind')

describe('meshusert-bind', function()
    local world, mesh

    before_each(function()
        registry.reset()
        world = love.physics.newWorld(0, 0, true)
        state.physicsWorld = world
        sceneIO.load(love.filesystem.read('scripts/tech/hoop.playtime.json'), world, camera.getInstance())
        for _, fixture in pairs(registry.sfixtures) do
            if fixture:getUserData().subtype == 'meshusert' then mesh = fixture end
        end
    end)

    after_each(function()
        world:destroy()
        state.physicsWorld = nil
        registry.reset()
    end)

    it('binds every vertex to at most 3 bones, weights adding up to 1', function()
        local ud = mesh:getUserData()
        meshusertBind.unbind(ud.extra)
        assert.is_true(meshusertBind.bindInfluences(ud, mesh:getBody()))
        local verts = meshusertBind.worldVerts(ud, mesh:getBody())
        assert.are.equal(#verts / 2, #ud.extra.influences)
        assert.are.equal(#verts / 2, #ud.extra.bindVerts)
        for _, list in ipairs(ud.extra.influences) do
            assert.is_true(#list >= 1 and #list <= 3)
            local sum = 0
            for _, infl in ipairs(list) do sum = sum + infl.w end
            assert.is_near(1, sum, 1e-6)
        end
        assert.is_nil(ud.extra.spineBind)
    end)

    it('one bind at a time: a spine bind clears the weights, unbind clears both', function()
        local ud = mesh:getUserData()
        meshusertBind.bindInfluences(ud, mesh:getBody())
        local bind = meshusertBind.bindSpine(ud, mesh:getBody(), false)
        assert.is_not_nil(bind)
        assert.are.equal(bind, ud.extra.spineBind)
        assert.is_nil(ud.extra.influences)
        assert.is_nil(ud.extra.rigidLookup)
        meshusertBind.unbind(ud.extra)
        assert.is_nil(ud.extra.spineBind)
    end)

    it('says why a spine bind cannot be made', function()
        local ud = mesh:getUserData()
        local nodes = ud.extra.nodes
        ud.extra.nodes = { nodes[1] }
        local bind, err = meshusertBind.bindSpine(ud, mesh:getBody(), false)
        ud.extra.nodes = nodes
        assert.is_nil(bind)
        assert.is_truthy(err:find('nodes'))
    end)
end)
