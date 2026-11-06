-- scene-light.lua — the scene's light level, saved with the scene (LIGHT-AND-SHADOW LS13, ENGINE-MERGE EM1).
-- Nikki 2026-11-06: "I basically want it all, but not always, in cost-efficient steps": a level per scene,
-- stepped through with the light button under the sound button (src/ui/tool-rail.lua), each level adding
-- the next cheapest: off (as drawn) / lit (Mipos lit without clay, contact shadows) / shadows (+ soft
-- shadows on the wall behind) / full (+ clay; with a floor set, 3D shadows along it and up the wall).
-- The floor is a scene setting (the settings panel's light section: src/light-params.lua): where things
-- stand (standY) and how far in front of the wall (depth), as light-grass-check's GROUND_TOP and SOLID_DEPTH.
-- One floor per scene: a room with storeys (the dollhouse) leaves it unset.
-- A level is a table of settings (lib.LEVELS), so tuning one is editing data here.
-- Off touches nothing: scenes that light themselves (light-grass-check, mipo-materials) work as before;
-- a level only sets what the scene hasn't set itself (lib.SHARED), and takes off only what it set.
-- The settings put on a part are taken off again (the part's own values back) when the level drops and
-- before a save (lib.unapply), so they never end up in a scene file.
local lib = {}

local state = require('src.state')
local mipoRegistry = require('src.mipo-registry')
local registry = require('src.registry')
local camera = require('src.camera')

-- the Mipo parts that take the light: picture parts, limb ribbons, torso skin (not the face's decals: a
-- face stays as drawn)
local LIT_PARTS = { texfixture = true, ['connected-texture'] = true, ['trace-vertices'] = true }

-- What the wall shadows land on. 'everything': all of what's behind the things (Nikki 2026-11-06: right
-- for rooms; be flexible, other choices later: the backdrops only, bodies marked as wall).
-- the screen's world rectangle, with room around
local function view()
    local cam = camera.getInstance()
    local w, h = love.graphics.getDimensions()
    local x1, y1 = cam:getWorldCoordinates(0, 0)
    local x2, y2 = cam:getWorldCoordinates(w, h)
    local pad = 200
    return math.min(x1, x2) - pad, math.min(y1, y2) - pad, math.max(x1, x2) + pad, math.max(y1, y2) + pad
end

local WALLS = {
    everything = function()
        local x1, y1, x2, y2 = view()
        love.graphics.rectangle('fill', x1, y1, x2 - x1, y2 - y1)
    end,
}
lib.WALLS = WALLS

-- the soft wall shadow from a sun (the way to it, world): away from it, longer the lower it is (as
-- light-grass-check's wallShadow), `behind` how far the wall is behind the things
local function wallShadowFrom(toLight, behind, strength, wall)
    local tx, ty = toLight[1], toLight[2]
    local len = math.sqrt(tx * tx + ty * ty)
    tx, ty = tx / len, ty / len
    local high = math.max(0, -ty)
    local length = behind * math.min(4, 1 / (high + 0.25))
    return { wall = WALLS[wall], offset = { -tx * length, high * length }, blur = 5 + length * 0.06,
        strength = strength }
end

-- the day's sun (light-grass-check's, high on the left)
local SUN = { -0.5, -0.85 }

local function extend(base, more)
    local t = {}
    for k, v in pairs(base) do t[k] = v end
    for k, v in pairs(more) do t[k] = v end
    return t
end

-- `mipoParts` goes on every lit Mipo part's extra (the plasticine shader's settings, src/render/shaders.lua);
-- `shared` are state fields the engine reads (src/contact-shadows.lua, src/backdrop-shadows.lua,
-- src/shadow-silhouettes.lua; sceneDefaultLights: src/render/shaders.lua, only in a scene without lights
-- of its own). The lit values: light-grass-check's liked ones (its o), the Mipos' own frontal light and
-- softer swing, clay off (LS23: ~5.6 ms for 20 Mipos on the phone instead of ~9.5).
local LIT = {
    name = 'lit',
    mipoParts = {
        plasticine = true, plasticineLightAdd = true, plasticineLightGain = 0.3, plasticineLightZ = 0.75,
        plasticineFormRadius = 0.35, plasticineFormBaked = true, plasticineFormRise = 1,
        -- clay off: light and roundness only
        plasticineStrength = 0, plasticineBump = 0, plasticineSpecStrength = 0, plasticineSSSstrength = 0,
    },
    shared = {
        contactShadows = { strength = 0.45 },
        sceneDefaultLights = {
            { lightType = 'directional', toLight = SUN, colorHex = 'fff2d9ff', intensity = 1.2 },
            -- the sky light at light-grass-check's 1.3 strength
            { lightType = 'sky', toLight = { 0, -1 }, colorHex = '9cc8ffff', groundHex = '8a7a50ff', intensity = 0.78 },
        },
    },
}

-- + soft shadows on the wall behind (~4 ms on the phone; every other frame, half that: LS25)
local SHADOWS = { name = 'shadows', mipoParts = LIT.mipoParts,
    shared = extend(LIT.shared, {
        backdropShadows = wallShadowFrom(SUN, 90, 0.35, 'everything'),
        shadowEveryOther = true,
    }) }

-- full: the Mipos in clay (their own clay values: the clay-off ones left out)
local CLAY = {}
for k, v in pairs(LIT.mipoParts) do CLAY[k] = v end
CLAY.plasticineStrength, CLAY.plasticineBump, CLAY.plasticineSpecStrength, CLAY.plasticineSSSstrength =
    nil, nil, nil, nil

-- with a floor: the 3D shadows (src/projected-shadows.lua) from the sun, a little out of the wall (as
-- light-grass-check's SUN_TOWARDS), and the soft ones only on the wall above the floor, lighter (the two
-- together, Nikki 2026-11-06). Made once per floor (the same tables while it stays: what apply compares).
local fullCache = {}
local function fullShared(settings)
    local floor = settings.floor
    if not floor then return SHADOWS.shared end
    local key = floor.standY .. '|' .. floor.depth
    if fullCache.key == key then return fullCache.shared end
    local floorY = floor.standY - floor.depth
    local function aboveFloor()
        local x1, y1, x2 = view()
        love.graphics.rectangle('fill', x1, y1, x2 - x1, floorY - y1)
    end
    local function wallAndFloor()
        local x1, y1, x2 = view()
        love.graphics.rectangle('fill', x1, y1, x2 - x1, floor.standY - y1)
    end
    local soft = wallShadowFrom(SUN, 90, 0.35 * 0.7, 'everything')
    soft.wall = aboveFloor
    local high = -SUN[2] / math.sqrt(SUN[1] * SUN[1] + SUN[2] * SUN[2])
    fullCache.key = key
    fullCache.shared = extend(LIT.shared, {
        backdropShadows = soft,
        shadowEveryOther = true,
        projectedShadows = { area = wallAndFloor, floorY = floorY, depth = floor.depth, lights = {
            { light = { kind = 'sun', x = SUN[1], h = high, z = 0.5 }, strength = 0.5, softness = 0.03 },
        } },
    })
    return fullCache.shared
end

lib.LEVELS = {
    { name = 'off' },
    LIT,
    SHADOWS,
    { name = 'full', mipoParts = CLAY, shared = fullShared },
}

local function levelIndex(name)
    for i, level in ipairs(lib.LEVELS) do
        if level.name == name then return i end
    end
    return 1
end

function lib.settings()
    state.sceneLight = state.sceneLight or { level = 'off' }
    return state.sceneLight
end

function lib.level() return lib.LEVELS[levelIndex(lib.settings().level)] end

-- the next level (after the last: off)
function lib.step()
    local s = lib.settings()
    s.level = lib.LEVELS[levelIndex(s.level) % #lib.LEVELS + 1].name
    return s.level
end

-- from a scene file (nil: off)
function lib.load(saved)
    lib.unapply()
    state.sceneLight = { level = saved and saved.level or 'off',
        floor = saved and saved.floor and { standY = saved.floor.standY, depth = saved.floor.depth } or nil }
    return state.sceneLight
end

-- for a scene file (off and no floor: nothing, the file stays as it was)
function lib.save()
    local s = lib.settings()
    if s.level == 'off' and not s.floor then return nil end
    return { level = s.level, floor = s.floor and { standY = s.floor.standY, depth = s.floor.depth } or nil }
end

-- the floor where the Mipos stand: the lowest point of their feet (a scene without Mipos: none)
lib.DEFAULT_DEPTH = 400
function lib.floorUnderMipos()
    local lowest
    for _, instance in pairs(mipoRegistry.getAll()) do
        for _, name in ipairs({ 'lfoot', 'rfoot' }) do
            local part = instance.parts and instance.parts[name]
            local body = part and part.body
            if body and not body:isDestroyed() then
                for _, fixture in ipairs(body:getFixtures()) do
                    local _, _, _, y2 = fixture:getBoundingBox()
                    lowest = math.max(lowest or y2, y2)
                end
            end
        end
    end
    if not lowest then return nil end
    local s = lib.settings()
    s.floor = { standY = math.floor(lowest + 0.5), depth = s.floor and s.floor.depth or lib.DEFAULT_DEPTH }
    return s.floor
end

-- the parts lit now: extra -> the values it had before (false for none), kept on state (hot reload);
-- weak keys: a rerolled Mipo's old parts go
local function litParts()
    state.sceneLitParts = state.sceneLitParts or setmetatable({}, { __mode = 'k' })
    return state.sceneLitParts
end

-- the state fields this level set: name -> the value it set
local function owned()
    state.sceneLightOwned = state.sceneLightOwned or {}
    return state.sceneLightOwned
end

local function restore(extra, before)
    for key, v in pairs(before) do
        if v == false then extra[key] = nil else extra[key] = v end
    end
end

-- every part back to its own values and the shared fields this level set cleared (the level dropped,
-- or a save is coming)
function lib.unapply()
    for extra, before in pairs(litParts()) do restore(extra, before) end
    state.sceneLitParts = setmetatable({}, { __mode = 'k' })
    state.sceneLightScan = nil
    for key, v in pairs(owned()) do
        if state[key] == v then state[key] = nil end
    end
    state.sceneLightOwned = {}
end

local function eachMipoPartExtra(fn)
    for _, instance in pairs(mipoRegistry.getAll()) do -- keyed by id
        for _, part in pairs(instance.parts or {}) do
            local body = part.body
            if body and not body:isDestroyed() then
                for _, fixture in ipairs(body:getFixtures()) do
                    local ud = fixture:getUserData()
                    if ud and LIT_PARTS[ud.subtype] and ud.extra and ud.extra.main then fn(ud.extra) end
                end
            end
        end
    end
end

-- once a frame, before the world is drawn (main.lua): the level's settings on what's there now (a Mipo
-- rebuilt or added has new parts; one already lit is skipped)
function lib.apply()
    local level = lib.level()
    if level.name == 'off' then
        if next(litParts()) or next(owned()) then lib.unapply() end
        state.sceneLightApplied = nil
        return
    end
    if state.sceneLightApplied ~= level.name then
        lib.unapply() -- another level: its settings off first
        state.sceneLightApplied = level.name
    end
    local lit = litParts()
    local values = level.mipoParts
    -- look for parts again only when an sfixture came or went (a Mipo added or rerolled: lit in that
    -- frame), or once a second (a part's picture remade on the same fixture); walking every Mipo's
    -- fixtures each frame was ~4% of a lit frame on the phone with 20 Mipos
    local now = love.timer.getTime()
    local version = registry.sfixtureVersion
    local due = state.sceneLightScan == nil or state.sceneLightScan.version ~= version
        or now - state.sceneLightScan.at > 1 or state.sceneLightScan.level ~= level.name
    if values and due then
        state.sceneLightScan = { version = version, at = now, level = level.name }
        eachMipoPartExtra(function(extra)
            if lit[extra] then return end
            local before = {}
            for key, v in pairs(values) do
                if extra[key] == nil then before[key] = false else before[key] = extra[key] end
                extra[key] = v
            end
            lit[extra] = before
        end)
    end
    local mine = owned()
    local shared = level.shared
    if type(shared) == 'function' then shared = shared(lib.settings()) end
    -- a field the level had and doesn't now (full without a floor after with one): cleared
    for key, v in pairs(mine) do
        if not (shared and shared[key]) and state[key] == v then state[key] = nil; mine[key] = nil end
    end
    for key, v in pairs(shared or {}) do
        -- only what the scene hasn't set itself
        if state[key] == nil or state[key] == mine[key] then
            state[key] = v
            mine[key] = v
        end
    end
end

return lib
