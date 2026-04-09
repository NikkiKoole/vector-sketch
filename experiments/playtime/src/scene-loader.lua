local lib = {}
local logger = require 'src.logger'
local state = require 'src.state'
local sceneIO = require 'src.io'
local script = require 'src.script'
local utils = require 'src.utils'
local camera = require 'src.camera'
local SE = require('src.script-events')
local FEXT = require('src.file-extensions')
local cam = camera.getInstance()

local hotReloadTimer = 0
local hotReloadInterval = 1
local lastModTime = 0

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
    local data = getFiledata(name):getString()
    state.selection.selectedJoint = nil
    state.selection.selectedObj = nil
    sceneIO.load(data, state.physicsWorld, cam)
    logger:info("Scene loaded: " .. name)
    return data
end

function lib.loadScriptAndScene(id)
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
    local data = getFiledata(name):getString()
    state.scene.sceneScript = script.loadScript(data, name)()
    state.scene.scriptPath = name
    script.setEnv({ worldState = state.world, world = state.physicsWorld, state = state })
    script.call(SE.ON_UNLOAD)
    script.call(SE.ON_START)

    lastModTime = getFileModificationTime(name)
end

function lib.maybeHotReload(dt)
    -- Accumulate time
    hotReloadTimer = hotReloadTimer + dt
    --state.scene.hotReloadTimer = state.scene.hotReloadTimer + dt
    -- Check if the accumulated time exceeds the interval
    --if state.scene.hotReloadTimer >= state.scene.hotReloadInterval then
    if hotReloadTimer >= hotReloadInterval then
        -- state.scene.hotReloadTimer = state.scene.hotReloadTimer - state.scene.hotReloadInterval -- Reset timer
        hotReloadTimer = hotReloadTimer - hotReloadInterval
        if state.scene.scriptPath then
            local newModeTime = (getFileModificationTime(state.scene.scriptPath))
            if (newModeTime ~= lastModTime) then
                logger:info('trying to load file because timestamp differs.')
                lib.loadAndRunScript(state.scene.scriptPath)
            end
            lastModTime = newModeTime
        end
    end
end

return lib
