local lib = {}
local logger = require('src.logger')
local state = require('src.state')
local sceneIO = require('src.io')
local script = require('src.script')
local utils = require('src.utils')
local camera = require('src.camera')
local SE = require('src.script-events')
local FEXT = require('src.file-extensions')
local signals = require('src.signals')
local cam = camera.getInstance()

-- The scene script's hot reload (maybeHotReload): on state, so a hot swap of this file doesn't
-- forget what was loaded and reload for nothing.
state.sceneReload = state.sceneReload or { timer = 0, modTime = 0, contents = nil }
local reload = state.sceneReload
local hotReloadInterval = 1

local function getFiledata(filename)
    -- io.open works on native (LuaJIT), not available on web (PUC Lua 5.1 in love.js)
    if io then
        local f = io.open(filename, 'r')
        if f then
            local filedata = love.filesystem.newFileData(f:read("*all"), filename)
            f:close()
            return filedata
        end
    end
    -- Fallback for web/.love bundles: use love.filesystem
    local data = love.filesystem.read(filename)
    if data then
        return love.filesystem.newFileData(data, filename)
    end
    return nil
end

function lib.loadScene(name)
    local filedata = getFiledata(name)
    if not filedata then
        logger:error('Scene file not found: ' .. tostring(name))
        return
    end
    return lib.loadSceneData(filedata:getString(), name)
end

-- Load a scene from its JSON text (a file's contents, or a room kept in memory by
-- src/doors.lua). name is only for the log.
function lib.loadSceneData(data, name)
    state.selection.selectedJoint = nil
    state.selection.selectedObj = nil
    state.selection.selectedSFixture = nil
    state.selection.selectedBodies = nil
    -- Tear down any script still running from the previous scene before its
    -- bodies are destroyed below: fire its unload hook (so it can clean up
    -- while its bodies still exist), then drop the reference so its
    -- update/draw/contact callbacks stop firing. Without this, loading a
    -- script-less scene left the old script's update() running against freed
    -- Box2D bodies (e.g. maan.lua:22 "Attempt to use destroyed body"). A
    -- scene that brings its own script re-populates these immediately after,
    -- via loadAndRunScript.
    if state.scene.sceneScript then
        script.call(SE.ON_UNLOAD)
        state.scene.sceneScript = nil
        state.scene.scriptPath = nil
    end
    sceneIO.load(data, state.physicsWorld, cam)
    signals.applySavedStates() -- gates back to their saved open/closed
    logger:info("Scene loaded: " .. name)
    return data
end

function lib.loadScriptAndScene(id)
    state.scene.id = id -- the room you're in (src/doors.lua)
    local jsonPath = '/scripts/' .. id .. FEXT.SCENE_JSON
    local luaPath = '/scripts/' .. id .. FEXT.SCENE_LUA
    local jsoninfo = love.filesystem.getInfo(jsonPath)
    local luainfo = love.filesystem.getInfo(luaPath)
    if not jsoninfo then
        logger:error('Scene file not found: ' .. jsonPath)
        return
    end
    -- Try absolute path first (native), fall back to relative (web/.love bundle)
    local cwd = love.filesystem.getWorkingDirectory()
    local absJson = cwd .. jsonPath
    local absLua = cwd .. luaPath
    if getFiledata(absJson) then
        lib.loadScene(absJson)
    else
        lib.loadScene(jsonPath)
    end
    if luainfo then
        if getFiledata(absLua) then
            lib.loadAndRunScript(absLua)
        else
            lib.loadAndRunScript(luaPath)
        end
    else
        logger:info('No script file for scene: ' .. id)
    end
end

local function getFileModificationTime(path)
    -- a bit of lame thing, i'm getting the cwd and the fll path
    -- then im cutting the duplication, so i'm left with the local fileName
    -- load that using love filesystem so i can get the mod time....
    local cwd = love.filesystem.getWorkingDirectory()
    local diff = utils.getPathDifference(cwd, path)
    if diff then
        local info = love.filesystem.getInfo(diff)
        return info and info.modtime or 0
    end
    return 0
end

function lib.loadAndRunScript(name)
    local filedata = getFiledata(name)
    if not filedata then
        logger:error('Script file not found: ' .. tostring(name))
        return
    end
    local data = filedata:getString()
    -- Fire the outgoing script's unload hook before swapping in the new one,
    -- so a reload/replace tears the old one down first. (This previously ran
    -- after the new script was assigned, firing ON_UNLOAD on the wrong target.)
    if state.scene.sceneScript then
        script.call(SE.ON_UNLOAD)
    end
    -- remembered before the script runs: one whose onStart errors isn't loaded again every second
    reload.modTime, reload.contents = getFileModificationTime(name), data
    state.scene.sceneScript = script.loadScript(data, name)
    state.scene.scriptPath = name
    script.setEnv({ worldState = state.world, world = state.physicsWorld, state = state })
    script.call(SE.ON_START)
end

-- Has the scene script changed since it was loaded? Its time first; file times are whole seconds,
-- so a save in the same second as the load looked unchanged for good (missed until a later save):
-- while the time is that recent, the contents are compared too.
local function scriptChanged(path)
    local modTime = getFileModificationTime(path)
    if modTime == 0 then return false end -- gone (deleted, renamed): nothing to load
    if modTime ~= reload.modTime then return true end
    if os.time() - modTime > 2 then return false end
    local filedata = getFiledata(path)
    return filedata ~= nil and filedata:getString() ~= reload.contents
end

-- Load the scene script again if it changed (now, not at the next once-a-second check).
function lib.reloadIfChanged()
    if state.scene.scriptPath and scriptChanged(state.scene.scriptPath) then
        logger:info('scene script changed: loading it again')
        lib.loadAndRunScript(state.scene.scriptPath)
    end
end

function lib.maybeHotReload(dt)
    reload.timer = reload.timer + dt
    if reload.timer >= hotReloadInterval then
        reload.timer = reload.timer - hotReloadInterval
        lib.reloadIfChanged()
    end
end

-- The scene script as a path inside the game (scripts/x.playtime.lua), or nil: main.lua lets
-- lurker watch it, so saving a fix gets the game out of lurker's error screen.
function lib.scriptFile()
    local path = state.scene.scriptPath
    if not path then return nil end
    local diff = utils.getPathDifference(love.filesystem.getWorkingDirectory(), path)
    if diff then return (diff:gsub('^/', '')) end
    return (path:gsub('^/', ''))
end

return lib
