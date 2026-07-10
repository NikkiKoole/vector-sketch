-- Specs for src/script.lua — scene-script loading, sandboxing, env injection.
-- Guards the two load-pipeline bugs found in the July 2026 audit:
-- top-level code executing twice per load, and globals leaking from one
-- scene's sandbox into the next.

if not love then return end

local script = require('src.script')

describe('script.loadScript', function()
    it('executes top-level code exactly once', function()
        -- __hits lives in the sandbox env; a second execution would bump it.
        local s = script.loadScript(
            '__hits = (__hits or 0) + 1\nreturn { hits = __hits }',
            'spec-exec-once')
        assert.is_table(s)
        assert.equal(1, s.hits)
    end)

    it('returns the chunk result, so scripts can expose hooks', function()
        local s = script.loadScript(
            'local n = 0\nreturn { onStart = function() n = n + 1 end, count = function() return n end }',
            'spec-hooks')
        s.onStart()
        s.onStart()
        assert.equal(2, s.count())
    end)

    it('gives every load a fresh sandbox (no global leaks between scenes)', function()
        local first = script.loadScript(
            'leaked = 42\nreturn { probe = function() return leaked end }',
            'spec-leaker')
        local second = script.loadScript(
            'return { probe = function() return leaked end }',
            'spec-victim')
        assert.equal(42, first.probe())
        assert.is_nil(second.probe())
    end)

    it('does not pollute the real global environment', function()
        script.loadScript('reallyLeaked = true\nreturn {}', 'spec-globals')
        assert.is_nil(_G.reallyLeaked)
    end)

    it('exposes the base API (math, statemachine, generateID, ...)', function()
        local s = script.loadScript([[
            return {
                hasMath = math ~= nil,
                hasSM = statemachine ~= nil,
                id = generateID(),
            }
        ]], 'spec-api')
        assert.is_true(s.hasMath)
        assert.is_true(s.hasSM)
        assert.is_string(s.id)
    end)

    it('returns a fallback table with foundError on a compile error', function()
        local s = script.loadScript('this is not lua at all (', 'spec-bad-syntax')
        assert.is_table(s)
        assert.is_not_nil(s.foundError)
        -- onStart is the error-surfacing hook; it must not throw.
        assert.has_no.errors(function() s.onStart() end)
    end)

    it('raises on a runtime error in top-level code', function()
        assert.has_error(function()
            script.loadScript('error("boom at load")\nreturn {}', 'spec-runtime-error')
        end)
    end)
end)

describe('script.setEnv', function()
    it('injects values into the most recently loaded script env', function()
        local s = script.loadScript(
            'return { probe = function() return injectedValue end }',
            'spec-inject')
        assert.is_nil(s.probe())
        script.setEnv({ injectedValue = 'hello' })
        assert.equal('hello', s.probe())
    end)

    it('injections do not carry over into the next load', function()
        script.loadScript('return {}', 'spec-inject-a')
        script.setEnv({ injectedValue = 'stale' })
        local s = script.loadScript(
            'return { probe = function() return injectedValue end }',
            'spec-inject-b')
        assert.is_nil(s.probe())
    end)
end)

describe('script.call', function()
    local state = require('src.state')
    local prevScript

    setup(function() prevScript = state.scene.sceneScript end)
    teardown(function() state.scene.sceneScript = prevScript end)

    it('is a no-op with no scene script or missing hook', function()
        state.scene.sceneScript = nil
        assert.has_no.errors(function() script.call('onStart') end)
        state.scene.sceneScript = {}
        assert.has_no.errors(function() script.call('onStart') end)
    end)

    it('forwards arguments to the hook', function()
        local got
        state.scene.sceneScript = { onThing = function(a, b) got = { a, b } end }
        script.call('onThing', 1, 'two')
        assert.same({ 1, 'two' }, got)
    end)
end)
