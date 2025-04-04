-- src/scene_manager.lua
local SceneManager = {}
SceneManager.__index = SceneManager

-- Modules REQUIRED by SceneManager itself
local state = require 'src.state'
local eio = require 'src.io'
local script = require 'src.script'
local logger = require 'src.logger' -- Assuming logger is created and accessible
local cam = require('src.camera').getInstance()
local registry = require 'src.registry'
local utils = require 'src.utils'
local inspect = require 'vendor.inspect' -- For debug logging if needed

-- Internal state for the manager
local currentSceneScript = nil
local currentScriptPath = nil
local lastModTime = nil
local hotReloadTimer = 0
local hotReloadInterval = 1 -- Default, maybe make configurable later

--[[----------------------------------------------------------------------------
Private Helper Methods (Internal to SceneManager module)
----------------------------------------------------------------------------]] --

local function _getFiledata(filename)
    local f = io.open(filename, 'r')
    if f then
        local content = f:read("*all")
        f:close()
        return love.filesystem.newFileData(content, filename) -- Use LÖVE's FileData
    else
        logger:error("SceneManager: Could not open file:", filename)
        return nil
    end
end

local function _getFileModificationTime(path)
    local cwd = love.filesystem.getWorkingDirectory()
    -- Use utils relative to the scene manager's context/needs if necessary
    local diff = utils.getPathDifference(cwd, path)
    if diff then
        local info = love.filesystem.getInfo(diff)
        return info and info.modtime or 0
    end
    return 0
end

local function _resetSelectionState()
    -- Helper to clear selection, accesses state module directly
    state.selection.selectedJoint = nil
    state.selection.selectedObj = nil
    state.selection.selectedSFixture = nil
    state.selection.selectedBodies = nil
end

--[[----------------------------------------------------------------------------
Public API Methods (Exported from the module)
----------------------------------------------------------------------------]] --

--- Loads ONLY a scene file (.json). Clears selection state.
-- @param name Full path to the scene file.
-- @param isReload Use eio.reload instead of eio.load (clears world differently).
function SceneManager.loadScene(name, isReload)
    local fileData = _getFiledata(name)
    if not fileData then return false end

    local dataString = fileData:getString()
    _resetSelectionState()

    -- eio.load/reload needs world and cam, which it can require from state/camera
    local loaderFunc = isReload and eio.reload or eio.load
    local success, err = pcall(loaderFunc, dataString, state.physicsWorld, cam) -- Pass dependencies directly

    if success then
        logger:info("SceneManager: Scene", (isReload and "reloaded" or "loaded"), name)
        if isReload then logger:info(inspect(registry.bodies)) end -- Log registry on reload
    else
        logger:error("SceneManager: Failed to load scene", name, "-", err)
    end
    return success
end

--- Loads and executes ONLY a script file (.lua).
-- Also handles setting up the script environment and calling lifecycle methods.
-- @param name Full path to the script file.
function SceneManager.loadScript(name)
    local fileData = _getFiledata(name)
    if not fileData then return false end
    local dataString = fileData:getString()

    -- Define the environment for the script
    -- Accessing modules directly via require
    local scriptEnv = {
        worldState = state.world,
        world = state.physicsWorld,
        state = state, -- Pass the whole state module
        registry = require 'src.registry',
        objectManager = require 'src.object-manager',
        ui = require 'src.ui-all',
        cam = require('src.camera').getInstance(),
        mathutils = require 'src.math-utils',
        utils = require 'src.utils',
        shapes = require 'src.shapes',
        uuid = require 'src.uuid',
        joints = require 'src.joints',
        box2dPointerJoints = require 'src.box2d-pointerjoints',
        script = require 'src.script',                               -- Let script call its own methods
        logger = logger,                                             -- Use the logger instance
        love = love,
        getObjectsByLabel = require('src.script').getObjectsByLabel, -- Expose helpers
        mouseWorldPos = require('src.script').mouseWorldPos,
        print = function(...) logger:info("SCRIPT:", ...) end,       -- Route script prints
        pairs = pairs,
        ipairs = ipairs,
        table = table,
        string = string,
        math = math,
        inspect = require 'vendor.inspect',
        unpack = unpack,
        getmetatable = getmetatable
        -- Add other necessary functions/modules
    }
    script.setEnv(scriptEnv) -- Configure the script module's environment

    -- Unload previous script if any
    if currentSceneScript then
        logger:debug("SceneManager: Calling onUnload for previous script.")
        pcall(script.call, 'onUnload') -- Use script.call which uses the (now old) global sceneScript
    end

    -- Load and run the new script
    -- script.loadScript now returns the loaded function/chunk
    local loadedScriptFunc, err = pcall(script.loadScript, dataString, name)
    if not loadedScriptFunc or err then
        logger:error("SceneManager: Failed to load script", name, "-", tostring(err))
        currentSceneScript = nil -- Ensure it's cleared on error
        currentScriptPath = nil
        lastModTime = nil
        -- Potentially set a dummy script to show the error in UI?
        -- currentSceneScript = { foundError = tostring(err) }
        return false
    end

    -- Execute the loaded chunk to get the script object
    local success, scriptObject = pcall(loadedScriptFunc)
    if not success or type(scriptObject) ~= 'table' then
        logger:error("SceneManager: Failed to execute script chunk", name, "-", tostring(scriptObject))
        currentSceneScript = nil
        currentScriptPath = nil
        lastModTime = nil
        return false
    end

    currentSceneScript = scriptObject -- Store the actual script table
    currentScriptPath = name

    logger:debug("SceneManager: Calling onStart for new script.")
    pcall(script.call, 'onStart') -- Use script.call which now implicitly uses the new global sceneScript

    lastModTime = _getFileModificationTime(name)
    logger:info("SceneManager: Script loaded:", name)
    return true
end

--- Loads a scene (.json) and its corresponding script (.lua) based on an ID.
-- @param id The base name identifier (e.g., 'lekker').
function SceneManager.loadScriptAndScene(id)
    local jsonPath = '/scripts/' .. id .. '.playtime.json'
    local luaPath = '/scripts/' .. id .. '.playtime.lua'
    local jsoninfo = love.filesystem.getInfo(jsonPath)
    local luainfo = love.filesystem.getInfo(luaPath)

    if (jsoninfo and jsoninfo.type == 'file' and luainfo and luainfo.type == 'file') then
        local cwd = love.filesystem.getWorkingDirectory()
        -- Use SceneManager's own methods
        local sceneSuccess = SceneManager.loadScene(cwd .. jsonPath, true) -- Use reload=true
        if sceneSuccess then
            local scriptSuccess = SceneManager.loadScript(cwd .. luaPath)
            return scriptSuccess
        else
            logger:error("SceneManager: Failed to load scene part for", id)
            return false
        end
    else
        logger:error("SceneManager: Cannot find both .json and .lua files for id:", id)
        if not jsoninfo then logger:error("Missing:", jsonPath) end
        if not luainfo then logger:error("Missing:", luaPath) end
        return false
    end
end

--- Call this in the main update loop to handle hot reloading.
-- @param dt Delta time.
function SceneManager.update(dt)
    hotReloadTimer = hotReloadTimer + dt
    if hotReloadTimer >= hotReloadInterval then
        hotReloadTimer = hotReloadTimer - hotReloadInterval -- Reset timer correctly

        if currentScriptPath then
            local newModTime = _getFileModificationTime(currentScriptPath)
            if newModTime > (lastModTime or 0) then        -- Compare modification times
                logger:info('SceneManager: Hot reloading script:', currentScriptPath)
                SceneManager.loadScript(currentScriptPath) -- Reload the script
            end
            -- Update lastModTime *after* the check/reload attempt
            lastModTime = newModTime
        end
    end
end

--- Returns the currently loaded script object (might be nil).
function SceneManager.getCurrentScript()
    return currentSceneScript
end

--- Returns the path of the currently loaded script (might be nil).
function SceneManager.getCurrentScriptPath()
    return currentScriptPath
end

return SceneManager
