local lib = {}
local state = require 'src.state'
local eio = require 'src.io'
local script = require 'src.script'
local utils = require 'src.utils'
local camera = require 'src.camera'
local cam = camera.getInstance()

local hotReloadTimer = 0
local hotReloadInterval = 1
local lastModTime = 0

function lib.loadScene(name)
    local data = getFiledata(name):getString()
    state.selection.selectedJoint = nil
    state.selection.selectedObj = nil
    eio.load(data, state.physicsWorld, cam)
    logger:info("Scene loaded: " .. name)
    return data
end

function lib.loadScriptAndScene(id)
    local jsonPath = '/scripts/' .. id .. '.playtime.json'
    local luaPath = '/scripts/' .. id .. '.playtime.lua'
    jsoninfo = love.filesystem.getInfo(jsonPath)
    luainfo = love.filesystem.getInfo(luaPath)
    if (jsoninfo and luainfo) then
        local cwd = love.filesystem.getWorkingDirectory()
        lib.loadScene(cwd .. jsonPath)
        lib.loadAndRunScript(cwd .. luaPath)
    else
        logger:error('issue loading both files.')
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

function getFiledata(filename)
    local f = io.open(filename, 'r')
    if f then
        local filedata = love.filesystem.newFileData(f:read("*all"), filename)
        f:close()
        return filedata
    end
end

function lib.loadAndRunScript(name)
    local data = getFiledata(name):getString()
    state.scene.sceneScript = script.loadScript(data, name)()
    state.scene.scriptPath = name
    script.setEnv({ worldState = state.world, world = state.physicsWorld, state = state })
    script.call('onUnload')
    script.call('onStart')

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
