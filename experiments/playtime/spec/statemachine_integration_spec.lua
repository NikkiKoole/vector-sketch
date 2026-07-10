-- Integration test: load sm-demo via sceneLoader, drive its state machine,
-- verify transitions / data threading / push-pop work end-to-end through a
-- real .playtime.lua script (not the in-process mocks of the unit spec).

if not love then return end

local sceneLoader = require('src.scene-loader')
local state = require('src.state')

describe('statemachine integration (via sm-demo)', function()
    local prevScript
    local ownWorld = false

    setup(function()
        prevScript = state.scene.scriptPath
        -- In a fresh `love . --specs` run there is no live app world (and
        -- earlier specs destroy theirs); loadScriptAndScene needs one.
        if not state.physicsWorld or state.physicsWorld:isDestroyed() then
            state.physicsWorld = love.physics.newWorld(0, 9.81 * 100, true)
            ownWorld = true
        end
    end)

    teardown(function()
        if ownWorld then
            -- Fresh spec run: nothing to restore, just tear down what we made.
            state.scene.sceneScript = nil
            state.scene.scriptPath = nil
            if state.physicsWorld and not state.physicsWorld:isDestroyed() then
                state.physicsWorld:destroy()
            end
            state.physicsWorld = nil
            return
        end
        -- Live app (via bridge): restore the scene we displaced.
        local sl = require('src.scene-loader')
        if prevScript then
            local id = prevScript:match('([^/]+)%.playtime%.lua$')
            if id then sl.loadScriptAndScene(id); return end
        end
        sl.loadScriptAndScene('miposhader')
    end)

    it('drives splash → bath → reveal → bath, with data flowing through', function()
        sceneLoader.loadScriptAndScene('sm-demo')
        local s = state.scene.sceneScript
        assert.is_not_nil(s, 'sm-demo script should be loaded')
        assert.is_not_nil(s.app, 'sm-demo should expose its state machine as s.app')

        -- onStart kicked us into splash
        assert.equal('splash', s.app:current())
        assert.same({}, s.discovered)

        -- splash → bath
        s.app:transition('bath')
        assert.equal('bath', s.app:current())

        -- bath → reveal with mipo data; reveal records it into discovered
        s.app:transition('reveal', { mipo = 'pemberton' })
        assert.equal('reveal', s.app:current())
        assert.same({ 'pemberton' }, s.discovered)

        -- reveal → bath (next blob), bath → reveal again with a different mipo
        s.app:transition('bath')
        s.app:transition('reveal', { mipo = 'flora' })
        assert.same({ 'pemberton', 'flora' }, s.discovered)

        -- history tracks each transition's from-state (not the to-state)
        assert.same({ 'splash', 'bath', 'reveal', 'bath' }, s.app:getHistory())
    end)

    it('push/pop overlay: pause leaves the underlying state alive and resumes it', function()
        sceneLoader.loadScriptAndScene('sm-demo')
        local s = state.scene.sceneScript

        s.app:transition('bath')
        local discoveredBefore = #s.discovered

        s.app:push('paused')
        assert.equal('paused', s.app:current())
        assert.equal(2, s.app:depth())
        -- discovered list untouched by overlay
        assert.equal(discoveredBefore, #s.discovered)

        s.app:pop({ resumeReason = 'continue' })
        assert.equal('bath', s.app:current())
        assert.equal(1, s.app:depth())
    end)

    it('update/draw forward to the active top state without erroring', function()
        sceneLoader.loadScriptAndScene('sm-demo')
        local s = state.scene.sceneScript

        s.app:transition('bath')
        assert.has_no.errors(function()
            for i = 1, 5 do s.app:update(1/60) end
            s.app:draw()
        end)
    end)
end)
