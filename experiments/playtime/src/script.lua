--script.lua
local script = {}
local logger = require('src.logger')
local inspect = require('vendor.inspect')
local camera = require('src.camera')
local cam = camera.getInstance()
local mathutils = require('src.math-utils')
local ui = require('src.ui.all')
local box2dPointerJoints = require('src.physics.box2d-pointerjoints')
local uuid = require('src.uuid')
local registry = require('src.registry')
local utils = require('src.utils')
local objectManager = require('src.object-manager')
local state = require('src.state')
local statemachine = require('src.statemachine')
local characterManager = require('src.character-manager')
local mipoVoice = require('src.mipo-voice')
local mipoActions = require('src.mipo-actions')
local props = require('src.props')
local signals = require('src.signals')
local snap = require('src.physics.snap')
local cameraFollow = require('src.camera-follow')
local hairLocks = require('src.hair-locks')
local hairTufts = require('src.hair-tufts')
local fabuland = require('src.fabuland')
local shape8Dict = require('src.shape8-dict')
local shapeCatalogs = require('src.shape-catalogs')
local dnaDefaults = require('src.dna-defaults')
local fixtures = require('src.fixtures')
local scriptPanel = require('src.ui.script-panel')
--- here a tiny collection of helper function will grow, function i am sure that will be reused in various scripts.
local function getObjectsByLabel(label)
    local objects = {}
    for _, body in pairs(state.physicsWorld:getBodies()) do
        local thing = utils.thingOf(body)
        if thing and thing.label == label then
            table.insert(objects, thing)
        end
    end
    return objects
end

local function mouseWorldPos()
    local mx, my = love.mouse:getPosition()
    local cx, cy = cam:getWorldCoordinates(mx, my)
    return cx, cy
end

-- A scene script's ui: the real one, except that its panel can be folded away
-- (src/ui/script-panel.lua); ui.isPanelFolded(label) tells a script its panel is folded.
local scriptUi = setmetatable({ panel = scriptPanel.panel, isPanelFolded = scriptPanel.isFolded }, { __index = ui })

-- end collection

local baseEnv = {
    generateID               = uuid.generateID,
    objectManager            = objectManager,
    ui                       = scriptUi,
    cam                      = cam,
    camera                   = cameraFollow.script, -- follow, setBounds, shake, zoomTo
    mathutils                = mathutils,
    getPJAttachedTo          = box2dPointerJoints.getPointerJointAttachedTo,
    getInteractedWithPointer = box2dPointerJoints.getInteractedWithPointer,
    pointerGrab              = box2dPointerJoints.grab, -- (id, body, wx, wy): the pointer carries a body a script made
    polygonClip              = mathutils.polygonClip,
    pairs                    = pairs,
    ipairs                   = ipairs,
    table                    = table,
    inspect                  = inspect,
    print                    = print,
    math                     = math,
    love                     = love,
    random                   = love.math.random,
    getObjectsByLabel        = getObjectsByLabel,
    world                    = state.physicsWorld,
    string                   = string,
    mouseWorldPos            = mouseWorldPos,
    worldState               = state.world,
    unpack                   = unpack,
    getmetatable             = getmetatable,
    registry                 = registry,
    statemachine             = statemachine,
    characterManager         = characterManager,
    mipoVoice                = mipoVoice,
    mipoActions              = mipoActions,
    mipoRaspberry            = require('src.mipo-raspberry'), -- blow(instance) (raspberry spike)
    mipoTextures             = require('src.mipo-textures'), -- addFaceDecals: a Mipo face on a script's body (garden)
    mipoRegistry             = require('src.mipo-registry'),
    mipoFacing               = require('src.mipo-facing'), -- facing left / front / right (facing spike)
    props                    = props,
    signals                  = signals,
    snap                     = snap,
    hairLocks                = hairLocks,
    hairTufts                = hairTufts,
    fabuland                 = fabuland,
    shape8Dict               = shape8Dict,
    shapeCatalogs            = shapeCatalogs,
    dnaDefaults              = dnaDefaults,
    tostring                 = tostring,
    tonumber                 = tonumber,
    pcall                    = pcall,
    ompBake                  = require('src.render.omp-bake'), -- the outline + mask + pattern bake (scan-test)
    formBake                 = require('src.render.form-bake'), -- a picture's roundness from its mask (material-check)
    shaderCost               = require('src.render.shader-cost'), -- a shader's GPU cost per MP (material-check)
    projectedShadows         = require('src.projected-shadows'), -- drawFront: 3D shadows on a ground drawn late
    materials                = require('src.render.materials'), -- material presets for parts (mipo-materials)
    wet                      = require('src.wet'), -- wet spots and a waterline that dry (mipo-materials)
    fixtures                 = fixtures, -- sfixtures on a script's own bodies (burrow's OMP rocks)
    liquid                   = require('src.liquid'), -- water in cups: spill, water, mouthPoint (seaside)
    cloth                    = require('src.cloth'), -- curtains, flags, sheets: a verlet grid drawn as a mesh (cloth)
    wearables                = require('src.wearables'), -- glasses, pants: on at a spot, off by a jolt (wearables)
    -- the textured world pass with `only` (a scene drawing some Mipos itself, in its own transform:
    -- tracks); looked up at the call (box2d-draw-textured loads after this file)
    drawTexturedWorld        = function(...)
        return require('src.physics.box2d-draw-textured').drawTexturedWorld(...)
    end,
    fluid                    = require('src.fluid'), -- particle water: tip a tank, a wave folds over (waterjar)
    -- Add global utilities like NeedManager, etc.
    --broadcastEvent = function(eventName, data)
    -- Implementation for event broadcasting
    --end,
}

-- Sandbox env of the most recently loaded script. Built fresh per load so
-- an un-`local` assignment in one scene script can't leak into the next.
local scriptEnv = nil

local function freshEnv()
    local env = {}
    for key, value in pairs(baseEnv) do
        env[key] = value
    end
    return env
end

function script.setEnv(newEnv)
    if not scriptEnv then return end
    for key, value in pairs(newEnv) do
        scriptEnv[key] = value
    end
end

function script.call(method, ...)
    if state.scene.sceneScript and state.scene.sceneScript[method] then
        state.scene.sceneScript[method](...)
    end
end

function script.loadScript(data, filePath)
    local scriptContent = data
    if not scriptContent then
        error("Script not found: " .. filePath)
    end

    scriptEnv = freshEnv()

    -- load() with 4 args is Lua 5.2+/LuaJIT; Lua 5.1 needs loadstring + setfenv
    local chunk, err
    if setfenv then -- luacheck: ignore 113
        -- Lua 5.1 (love.js / PUC Lua)
        chunk, err = loadstring(scriptContent, "@" .. filePath) -- luacheck: ignore 113
        if chunk then setfenv(chunk, scriptEnv) end -- luacheck: ignore 113
    else
        -- LuaJIT / Lua 5.2+
        chunk, err = load(scriptContent, "@" .. filePath, "t", scriptEnv)
    end
    if err then
        logger:error('error: ' .. err)
    else
        if not chunk then
            error("Error loading script: " .. err)
        end

        -- Run the chunk exactly once and return its result (the script
        -- table). Returning the chunk itself made the caller execute it a
        -- second time, doubling every top-level side effect on load/reload.
        local success, result = pcall(chunk)
        if not success then
            error("Error executing script: " .. result)
        end

        logger:info("Script loaded: " .. filePath)
        return result
    end

    return {
        onStart = function() logger:error("error: " .. err .. "\nError in script: " .. filePath) end,
        foundError = err, -- utils.insertNewlines(err, 100)
    }
end

return script
