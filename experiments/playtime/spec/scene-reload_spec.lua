-- Specs for the scene script's hot reload (src/scene-loader.lua maybeHotReload): a saved change
-- is picked up, also in the same second as the load (file times are whole seconds), a script
-- whose start errors isn't loaded again until it changes, and the script's path for lurker.

if not love then return end

local sceneLoader = require('src.scene-loader')
local state = require('src.state')

describe('scene script hot reload', function()
    local path = love.filesystem.getWorkingDirectory() .. '/scripts/zz-reload-spec.playtime.lua'
    local loads

    local function write(onStart)
        local f = io.open(path, 'w')
        f:write('local s = {} function s.onStart() ' .. onStart .. ' end return s')
        f:close()
    end
    local function check() return pcall(sceneLoader.maybeHotReload, 1.1) end
    local function wait() os.execute('sleep 1.1') end

    before_each(function()
        state.physicsWorld = love.physics.newWorld(0, 0, true)
        state.world.reloadSpec = nil
        loads = 0
    end)

    after_each(function()
        os.remove(path)
        state.scene.sceneScript, state.scene.scriptPath = nil, nil
        state.world.reloadSpec = nil
    end)

    it('loads a saved change again', function()
        write('worldState.reloadSpec = 1')
        sceneLoader.loadAndRunScript(path)
        wait()
        write('worldState.reloadSpec = 2')
        assert.is_true(check())
        assert.are.equal(2, state.world.reloadSpec)
    end)

    it('catches a change saved in the same second as the load', function()
        write('worldState.reloadSpec = 1')
        sceneLoader.loadAndRunScript(path)
        write('worldState.reloadSpec = 3')
        assert.is_true(check())
        assert.are.equal(3, state.world.reloadSpec)
    end)

    it('leaves an unchanged script alone', function()
        write('worldState.reloadSpec = (worldState.reloadSpec or 0) + 1')
        sceneLoader.loadAndRunScript(path)
        assert.is_true(check())
        assert.is_true(check())
        assert.are.equal(1, state.world.reloadSpec)
    end)

    it("doesn't load a script that errors on start again until it's fixed", function()
        write('worldState.reloadSpec = 1')
        sceneLoader.loadAndRunScript(path)
        wait()
        write('local broken = nil; broken.field = 1')
        local ok = check()
        assert.is_false(ok) -- the error goes up (to lurker's error screen in the game)
        assert.is_true(check()) -- not again: unchanged since
        wait()
        write('worldState.reloadSpec = 4')
        assert.is_true(check())
        assert.are.equal(4, state.world.reloadSpec)
    end)

    it("gives lurker the script as a path inside the game", function()
        write('worldState.reloadSpec = 1')
        sceneLoader.loadAndRunScript(path)
        assert.are.equal('scripts/zz-reload-spec.playtime.lua', sceneLoader.scriptFile())
    end)
end)
