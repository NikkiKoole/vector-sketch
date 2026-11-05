-- spec/skinning-boneless-vertex_spec.lua
-- A skinned mesh's vertex whose bones are all gone (their joint / anchor deleted, their body
-- destroyed) has nothing to follow. DQS left it where it was in the world when bound, so it stayed
-- behind while its body moved on; the linear blend put it at the world's origin. Either way that
-- part of the mesh stretched off. It stays at its rest place on its own body now, moving with it.
-- Run with: love . --specs spec/skinning-boneless-vertex_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local sceneIO = require('src.io')
local camera = require('src.camera')
local meshusertBind = require('src.meshusert-bind')
local resourceLink = require('src.resource-link')
local skinning = require('src.render.skinning')

describe('a skinned vertex with no bone left', function()
    local world, ud, body, data, verts

    before_each(function()
        registry.reset()
        world = love.physics.newWorld(0, 0, true)
        state.physicsWorld = world
        sceneIO.load((love.filesystem.read('scripts/tech/hoop.playtime.json')), world, camera.getInstance())
        local mesh
        for _, fixture in pairs(registry.sfixtures) do
            if fixture:getUserData().subtype == 'meshusert' then mesh = fixture end
        end
        ud, body = mesh:getUserData(), mesh:getBody()
        local mappert = resourceLink.find(ud)
        data = mappert:getUserData().extra
        verts = data.meshVertices or mappert:getBody():getUserData().thing.vertices
    end)

    after_each(function()
        skinning.useDQS = true
        world:destroy()
        state.physicsWorld = nil
        registry.reset()
    end)

    -- the placed polygon at rest, body-local
    local function rest()
        local extra = { meshX = ud.extra.meshX, meshY = ud.extra.meshY, scaleX = ud.extra.scaleX,
            scaleY = ud.extra.scaleY, meshRot = ud.extra.meshRot }
        local _, _, out = skinning.meshusertVertices(extra, body, data, verts, false)
        return out
    end

    -- bind, lose every bone of the first vertex, move the mesh's body; that vertex's place
    local function firstVertexAfter()
        meshusertBind.bindInfluences(ud, body)
        for _, infl in ipairs(ud.extra.influences[1]) do infl.body = nil end
        body:setPosition(body:getX() + 300, body:getY() - 200)
        body:setAngle(body:getAngle() + 0.7)
        local _, _, out = skinning.meshusertVertices(ud.extra, body, data, verts, false)
        return out[1], out[2]
    end

    for _, dqs in ipairs({ true, false }) do
        it('stays at its rest place on its body (' .. (dqs and 'DQS' or 'linear blend') .. ')', function()
            skinning.useDQS = dqs
            local r = rest()
            local x, y = firstVertexAfter()
            assert.is_near(r[1], x, 1e-6)
            assert.is_near(r[2], y, 1e-6)
        end)
    end
end)
