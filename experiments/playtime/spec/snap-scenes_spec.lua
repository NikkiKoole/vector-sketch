-- spec/snap-scenes_spec.lua
-- The snap test scenes load on the new snap design: points found, old snap
-- joints get their points named, script-added points don't duplicate.
-- Run with: love . --specs spec/snap-scenes_spec.lua

if not love then return end

local state = require('src.state')
local sceneLoader = require('src.scene-loader')
local snap = require('src.physics.snap')
local script = require('src.script')

describe('snap test scenes', function()
    before_each(function()
        if not state.physicsWorld or state.physicsWorld:isDestroyed() then
            state.physicsWorld = love.physics.newWorld(0, 9.8 * love.physics.getMeter(), true)
        end
    end)

    local function summary()
        local named = 0
        for _, joint in ipairs(snap.joints()) do
            local meta = joint:getUserData().scriptmeta
            if meta.a and meta.b then named = named + 1 end
        end
        return #snap.points(), #snap.joints(), named
    end

    it('tech/snapstatic: its two old snap joints get their snap points named', function()
        sceneLoader.loadScriptAndScene('tech/snapstatic')
        local points, joints, named = summary()
        print(string.format('[snap scenes] tech/snapstatic: %d points, %d snap joints, %d named', points, joints, named))
        assert.are.equal(2, joints)
        assert.are.equal(joints, named)
    end)

    it('snap (havesnap labels): the script adds two points per body, once', function()
        sceneLoader.loadScriptAndScene('snap')
        script.call('onStart')
        local points1 = #snap.points()
        script.call('onStart')
        local points2 = #snap.points()
        print(string.format('[snap scenes] snap: %d points after onStart, %d after a second onStart', points1, points2))
        assert.is_true(points1 > 0)
        assert.are.equal(points1, points2)
    end)

    it('tech/snap2 loads', function()
        sceneLoader.loadScriptAndScene('tech/snap2')
        local points, joints = summary()
        print(string.format('[snap scenes] tech/snap2: %d points, %d snap joints', points, joints))
    end)

    it('dollhouse (Mipos = hand snap points without fixtures) loads', function()
        sceneLoader.loadScriptAndScene('dollhouse')
        local hands = 0
        for _, p in ipairs(snap.points()) do if p.hand then hands = hands + 1 end end
        print(string.format('[snap scenes] dollhouse: %d hand snap points', hands))
        assert.is_true(hands >= 2)
    end)
end)
