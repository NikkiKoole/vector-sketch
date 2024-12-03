--script.lua
local script = {}
local inspect = require 'vendor.inspect'
local cam = require('lib.cameraBase').getInstance()
function getObjectsByLabel(label)
    local objects = {}
    for _, body in pairs(world:getBodies()) do
        local userData = body:getUserData()
        if (userData and userData.thing and userData.thing.label == label) then
            table.insert(objects, userData.thing)
        end
    end
    return objects
end

function mouseWorldPos()
    local mx, my = love.mouse:getPosition()
    local cx, cy = cam:getWorldCoordinates(mx, my)
    return cx, cy
end

local scriptEnv = {
    ipairs            = ipairs,
    table             = table,
    inspect           = inspect,
    print             = print,
    math              = math,
    love              = love,
    random            = love.math.random,
    getObjectsByLabel = getObjectsByLabel,
    world             = world,
    string            = string,
    mouseWorldPos     = mouseWorldPos
    -- Add global utilities like NeedManager, etc.
    --broadcastEvent = function(eventName, data)
    -- Implementation for event broadcasting
    --end,
}

function script.setEnv(newEnv)
    for key, value in pairs(newEnv) do
        scriptEnv[key] = value
    end
end

function script.call(method, ...)
    if sceneScript and sceneScript[method] then
        sceneScript[method](...)
    end
end

function script.loadScript(data, filePath)
    --print('>>>>> script environment api')
    --printTableKeys(scriptEnv)
    --print('>>>>>')
    local scriptContent = data
    if not scriptContent then
        error("Script not found: " .. filePath)
    end

    local chunk, err = load(scriptContent, "@" .. filePath, "t", scriptEnv)
    if not chunk then
        error("Error loading script: " .. err)
    end

    local success, err = pcall(chunk)
    if not success then
        error("Error executing script: " .. err)
    end

    print("Script loaded: " .. filePath)
    if success then
        return chunk
    end
end

return script
