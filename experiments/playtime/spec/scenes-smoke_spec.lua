-- Every scene in scripts/ (src/scene-catalog.lua, the editor's scenes tab) loads and runs: its
-- scene and script, then a second of frames the way main.lua runs them (physics, the script's
-- update, the bodies and the textured world drawn, the script's draw hooks and its UI panel in
-- play mode), then every key the script listens for (`key == 'p'`) pressed with a few frames after
-- each. A script-only spike runs on an empty world. A scene that errors fails here.

if not love then return end

local catalog = require('src.scene-catalog')
local sceneLoader = require('src.scene-loader')
local script = require('src.script')
local state = require('src.state')
local ui = require('src.ui.all')
local box2dDraw = require('src.physics.box2d-draw')
local box2dDrawTextured = require('src.physics.box2d-draw-textured')
local fabuland = require('src.fabuland')
local camera = require('src.camera')

describe('every scene', function()
    local canvas, previousPlay

    setup(function()
        canvas = love.graphics.newCanvas(1200, 768)
        local font = love.graphics.newFont(12)
        love.graphics.setFont(font)
        ui.init(font, font:getHeight())
        previousPlay = state.playMode
    end)

    teardown(function()
        state.playMode = previousPlay
        if state.scene.sceneScript then script.call('onUnload') end
        state.scene.sceneScript, state.scene.scriptPath = nil, nil
        canvas:release()
    end)

    local function frame(dt)
        if not state.world.paused then
            state.physicsWorld:update(dt)
            script.call('update', dt)
        end
        love.graphics.setCanvas({ canvas, stencil = true })
        love.graphics.clear()
        local cam = camera.getInstance()
        cam:push()
        script.call('drawBelow')
        box2dDraw.drawWorld(state.physicsWorld)
        fabuland.draw()
        box2dDrawTextured.drawTexturedWorld(state.physicsWorld)
        script.call('draw')
        cam:pop()
        ui.startFrame()
        script.call('drawUI')
        love.graphics.setCanvas()
    end

    -- the keys a scene script answers to
    local function keysOf(id)
        local contents = love.filesystem.read('scripts/' .. id .. '.playtime.lua') or ''
        local keys, seen = {}, {}
        for key in contents:gmatch("key%s*==%s*['\"]([^'\"]+)['\"]") do
            if not seen[key] then seen[key] = true; keys[#keys + 1] = key end
        end
        return keys
    end

    for _, scene in ipairs(catalog.list()) do
        it(scene.id .. (scene.scriptOnly and ' (on an empty world)' or ''), function()
            if not state.physicsWorld or state.physicsWorld:isDestroyed() then
                state.physicsWorld = love.physics.newWorld(0, 9.8 * love.physics.getMeter(), true)
            end
            state.playMode = true -- scripts draw their panels in play mode
            local ok, err = pcall(function()
                if scene.scriptOnly then
                    sceneLoader.loadSceneData('{"version":"1.0","bodies":[],"joints":[]}', 'empty')
                    sceneLoader.loadAndRunScript('/scripts/' .. scene.id .. '.playtime.lua')
                else
                    sceneLoader.loadScriptAndScene(scene.id)
                end
                for _ = 1, 60 do frame(1 / 60) end
                if scene.lua then
                    for _, key in ipairs(keysOf(scene.id)) do
                        script.call('onKeyPress', key)
                        for _ = 1, 10 do frame(1 / 60) end
                    end
                end
            end)
            love.graphics.setCanvas()
            if state.scene.sceneScript then pcall(script.call, 'onUnload') end
            state.scene.sceneScript, state.scene.scriptPath = nil, nil
            assert.is_true(ok, tostring(err))
        end)
    end
end)
