-- Specs for src/scene-catalog.lua: the scenes tab's list (names, lines, groups) and loading one
-- on the next update.

if not love then return end

local catalog = require('src.scene-catalog')
local state = require('src.state')

describe('scene catalog', function()
    local byId
    setup(function()
        byId = {}
        for _, scene in ipairs(catalog.list()) do byId[scene.id] = scene end
    end)

    it('finds scenes, one folder down too', function()
        assert.is_truthy(byId.dollhouse)
        assert.is_truthy(byId['tech/snap2'])
        assert.are.equal('tech', byId['tech/snap2'].group)
    end)

    it("takes a scene's line from its script's first comment, without the name", function()
        assert.are.equal('a spike for an underground Mipo home you dig yourself.', byId.burrow.note)
    end)

    it('groups by what the line says: rooms, spikes, tests', function()
        assert.are.equal('rooms', byId.dollhouse.group) -- 'the doll-play test room' is a room
        assert.are.equal('spikes', byId.burrow.group)
        assert.are.equal('tests', byId.snap.group)
    end)

    it('a script with no scene of its own runs on the open one', function()
        assert.is_true(byId.tufts.scriptOnly)
        assert.is_falsy(byId.dollhouse.scriptOnly)
    end)

    it('every scene has a line or is in a described folder', function()
        for id, scene in pairs(byId) do
            assert.is_true(scene.note ~= '' or catalog.folderNote(scene.group) ~= nil, id .. ' has no line')
        end
    end)

    it('loads a picked scene on the next update, not before', function()
        if not state.physicsWorld or state.physicsWorld:isDestroyed() then
            state.physicsWorld = love.physics.newWorld(0, 9.8 * love.physics.getMeter(), true)
        end
        state.scene.id = 'before'
        catalog.request(byId['spine-test'], false)
        assert.are.equal('before', state.scene.id)
        catalog.update()
        assert.are.equal('spine-test', state.scene.id)
    end)
end)
