-- scene-light.lua — the scene's light level, saved with the scene (LIGHT-AND-SHADOW LS13, ENGINE-MERGE EM1).
-- Nikki 2026-11-06: "I basically want it all, but not always, in cost-efficient steps": a level per scene,
-- stepped through with the light button under the sound button (src/ui/tool-rail.lua), each level adding
-- the next cheapest: off (as drawn) / lit (Mipos lit without clay, contact shadows) / shadows (+ soft
-- shadows on the wall behind) / full (+ clay; with a floor set, 3D shadows along it and up the wall).
-- The floor is a scene setting (the settings panel's light section: src/light-params.lua): where things
-- stand (standY) and how far in front of the wall (depth), as light-grass-check's GROUND_TOP and SOLID_DEPTH.
-- One floor per scene: a room with storeys (the dollhouse) leaves it unset.
-- A level is a table of settings (lib.LEVELS), so tuning one is editing data here.
-- Off touches nothing but a Mipo part in a material (the lit look on it): scenes that light themselves
-- (light-grass-check, mipo-materials) work as before;
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

-- What the wall shadows land on (the light section's 'falls on', Nikki 2026-11-11): 'walls' (bodies with a
-- wall sfixture, src/walls.lua: each its own distance behind, a shadow pass per distance), 'everything'
-- behind the things (2026-11-06: right for rooms), 'backdrops' (the pictures behind), 'nothing' (no wall
-- shadows; the 3D ones only along the floor), 'auto' (the default): walls when the scene has any, else
-- backdrops with a sky (src/scene-sky.lua: no shadow on open sky), else everything.
lib.WALL_CHOICES = { 'auto', 'walls', 'backdrops', 'everything', 'nothing' }

-- the screen's world rectangle, with room around
local function view()
    local cam = camera.getInstance()
    local w, h = love.graphics.getDimensions()
    local x1, y1 = cam:getWorldCoordinates(0, 0)
    local x2, y2 = cam:getWorldCoordinates(w, h)
    local pad = 200
    return math.min(x1, x2) - pad, math.min(y1, y2) - pad, math.max(x1, x2) + pad, math.max(y1, y2) + pad
end

-- the wall's shape, drawn in world space (a stencil), down to bottom (nil: all of it)
local function everything(bottom)
    return function()
        local x1, y1, x2, y2 = view()
        y2 = bottom and math.min(y2, bottom) or y2
        if y2 > y1 then love.graphics.rectangle('fill', x1, y1, x2 - x1, y2 - y1) end
    end
end

local function backdrops(bottom)
    return function()
        for _, b in ipairs(state.backdrops or {}) do
            local w, h = b.w, b.h
            if b.image and not (w and h) then w, h = b.image:getDimensions() end
            if not b.foreground and w and h then
                local s = b.scale or 1
                local x, y = b.x or 0, b.y or 0
                local y2 = bottom and math.min(y + h * s, bottom) or y + h * s
                if y2 > y then love.graphics.rectangle('fill', x, y, w * s, y2 - y) end
            end
        end
    end
end

local WALLS = { everything = everything(), backdrops = backdrops() }
lib.WALLS = WALLS

-- the wall this scene's shadows land on: one of WALL_CHOICES but 'auto'
function lib.wallOf(settings)
    local wall = settings.wall or 'auto'
    if wall == 'auto' then
        local sky = package.loaded['src.scene-sky']
        if require('src.walls').any() then wall = 'walls'
        else wall = (sky and sky.isOn()) and 'backdrops' or 'everything' end
    end
    return wall
end


-- the soft wall shadow from a sun (the way to it, world): away from it, longer the lower it is (as
-- light-grass-check's wallShadow), `behind` how far the wall is behind the things
local function wallShadowFrom(toLight, behind, strength, wall)
    local tx, ty = toLight[1], toLight[2]
    local len = math.sqrt(tx * tx + ty * ty)
    tx, ty = tx / len, ty / len
    local high = math.max(0, -ty)
    local length = behind * math.min(4, 1 / (high + 0.25))
    return { wall = type(wall) == 'function' and wall or WALLS[wall], offset = { -tx * length, high * length },
        blur = 5 + length * 0.06,
        strength = strength }
end

-- the day's sun (light-grass-check's, high on the left)
local SUN = { -0.5, -0.85 }

-- the walls' shadow layers (src/walls.lua): one per distance behind, each its own length and softness;
-- `strength` for all, `notOn` (optional) cuts a part off (below the floor)
local function wallLayers(layers, strength, notOn)
    local out = {}
    for _, layer in ipairs(layers) do
        local shadow = wallShadowFrom(SUN, layer.behind, strength, layer.draw)
        shadow.notOn = notOn
        out[#out + 1] = shadow
    end
    return { layers = out }
end

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

-- the shared settings made once per level and settings (the same table while they stay: what apply
-- compares)
local sharedCache = {}
local function cached(name, key, make)
    local c = sharedCache[name]
    if c and c.key == key then return c.shared end
    sharedCache[name] = { key = key, shared = make() }
    return sharedCache[name].shared
end

local DEFAULT_BEHIND = 90 -- how far the wall is behind the things (how far their shadows shift)
lib.DEFAULT_BEHIND = DEFAULT_BEHIND

local function wallKey(settings)
    return lib.wallOf(settings) .. '|' .. (settings.wallShadow or 1) .. '|'
        .. (settings.wallBehind or DEFAULT_BEHIND)
end

-- + soft shadows on the wall behind (~4 ms on the phone; every other frame, half that: LS25)
local function shadowsShared(settings)
    local wall = lib.wallOf(settings)
    if wall == 'walls' then
        local layers, key = require('src.walls').layers()
        return cached('shadows', wallKey(settings) .. '|' .. key, function()
            return extend(LIT.shared, {
                backdropShadows = wallLayers(layers, 0.35 * (settings.wallShadow or 1)),
                shadowEveryOther = true,
            })
        end)
    end
    return cached('shadows', wallKey(settings), function()
        if wall == 'nothing' then return LIT.shared end
        return extend(LIT.shared, {
            backdropShadows = wallShadowFrom(SUN, settings.wallBehind or DEFAULT_BEHIND,
                0.35 * (settings.wallShadow or 1), wall),
            shadowEveryOther = true,
        })
    end)
end
local SHADOWS = { name = 'shadows', mipoParts = LIT.mipoParts, shared = shadowsShared }

-- full: the Mipos in clay (their own clay values: the clay-off ones left out)
local CLAY = {}
for k, v in pairs(LIT.mipoParts) do CLAY[k] = v end
CLAY.plasticineStrength, CLAY.plasticineBump, CLAY.plasticineSpecStrength, CLAY.plasticineSSSstrength =
    nil, nil, nil, nil

-- with a floor: the 3D shadows (src/projected-shadows.lua) from the sun, a little out of the wall (as
-- light-grass-check's SUN_TOWARDS), and the soft ones only on the wall above the floor, lighter (the two
-- together, Nikki 2026-11-06). The wall as chosen: the soft ones on it above the floor, the 3D ones on it
-- and on the floor (the floor alone with 'nothing').
local function fullShared(settings)
    local floor = settings.floor
    if not floor then return shadowsShared(settings) end
    local wall = lib.wallOf(settings)
    local layers, wallsKey = {}, ''
    if wall == 'walls' then layers, wallsKey = require('src.walls').layers() end
    return cached('full', floor.standY .. '|' .. floor.depth .. '|' .. wallKey(settings) .. '|' .. wallsKey,
        function()
        local floorY = floor.standY - floor.depth
        local wallAbove = wall == 'backdrops' and backdrops(floorY) or everything(floorY)
        local wallDown = wall == 'backdrops' and backdrops(floor.standY) or everything(floor.standY)
        local function floorBand() -- the floor, under the wall
            local x1, _, x2 = view()
            love.graphics.rectangle('fill', x1, floorY, x2 - x1, floor.standY - floorY)
        end
        local function allWalls() for _, layer in ipairs(layers) do layer.draw() end end
        local area = wall == 'everything' and wallDown or wall == 'nothing' and floorBand
            or wall == 'walls' and function() allWalls() floorBand() end
            or function() wallDown() floorBand() end
        local high = -SUN[2] / math.sqrt(SUN[1] * SUN[1] + SUN[2] * SUN[2])
        local more = {
            shadowEveryOther = true,
            projectedShadows = { area = area, floorY = floorY, depth = floor.depth, lights = {
                { light = { kind = 'sun', x = SUN[1], h = high, z = 0.5 }, strength = 0.5, softness = 0.03 },
            } },
        }
        if wall == 'walls' then
            local function belowFloor() -- the soft ones only above the floor
                local x1, _, x2, y2 = view()
                love.graphics.rectangle('fill', x1, floorY, x2 - x1, y2 - floorY)
            end
            more.backdropShadows = wallLayers(layers, 0.35 * 0.7 * (settings.wallShadow or 1), belowFloor)
        elseif wall ~= 'nothing' then
            more.backdropShadows = wallShadowFrom(SUN, settings.wallBehind or DEFAULT_BEHIND,
                0.35 * 0.7 * (settings.wallShadow or 1), wallAbove)
        end
        return extend(LIT.shared, more)
    end)
end

-- The light section's Mipo rows (Nikki 2026-11-11): the level's Mipo settings with this scene's own on top,
-- settings.mipo = { clay = true/false, front = plasticineLightZ, swing = plasticineLightGain,
-- round = plasticineFormRise }; nil each = the level's.
local CLAY_OFF = { 'plasticineStrength', 'plasticineBump', 'plasticineSpecStrength', 'plasticineSSSstrength' }
local MIPO_KEYS = { front = 'plasticineLightZ', swing = 'plasticineLightGain', round = 'plasticineFormRise' }
lib.MIPO_KEYS = MIPO_KEYS

local function mipoKey(settings)
    local m = settings.mipo
    if not m then return '' end
    return tostring(m.clay) .. '|' .. tostring(m.front) .. '|' .. tostring(m.swing) .. '|' .. tostring(m.round)
end

local mipoCache = {}
local function mipoValues(level, settings)
    if not level.mipoParts then return level.materialParts end -- off: the material parts as they are
    local m = settings.mipo
    if not m or next(m) == nil then return level.mipoParts end
    local key = level.name .. '|' .. mipoKey(settings)
    if mipoCache.key == key then return mipoCache.values end
    local values = {}
    for k, v in pairs(level.mipoParts) do values[k] = v end
    if m.clay == true then for _, k in ipairs(CLAY_OFF) do values[k] = nil end end
    if m.clay == false then for _, k in ipairs(CLAY_OFF) do values[k] = 0 end end
    for name, k in pairs(MIPO_KEYS) do
        if m[name] ~= nil then values[k] = m[name] end
    end
    mipoCache.key, mipoCache.values = key, values
    return values
end

-- what a Mipo row shows when the scene hasn't set it: the level's (clay: whether the level has it)
function lib.mipoDefault(name)
    local level = lib.level()
    local parts = level.mipoParts or level.materialParts or {}
    if name == 'clay' then return parts.plasticineStrength == nil end
    return parts[MIPO_KEYS[name]]
end

lib.LEVELS = {
    -- off: as drawn, except a Mipo part in a material (src/render/materials.lua) gets the lit Mipos' look
    -- (Nikki 2026-11-08: the light-and-shadow Mipos as the materials' default); the scene's lights stay
    -- its own (none: the shader's own light)
    { name = 'off', materialParts = LIT.mipoParts },
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
    if saved then
        local s = state.sceneLight
        s.wall, s.wallShadow, s.wallBehind = saved.wall, saved.wallShadow, saved.wallBehind
        if type(saved.mipo) == 'table' then
            s.mipo = { clay = saved.mipo.clay, front = saved.mipo.front, swing = saved.mipo.swing,
                round = saved.mipo.round }
        end
    end
    return state.sceneLight
end

-- for a scene file (off and nothing else set: nothing, the file stays as it was)
function lib.save()
    local s = lib.settings()
    local mipo = s.mipo and next(s.mipo) and
        { clay = s.mipo.clay, front = s.mipo.front, swing = s.mipo.swing, round = s.mipo.round } or nil
    local wall = s.wall ~= 'auto' and s.wall or nil
    if s.level == 'off' and not s.floor and not mipo and not wall and not s.wallShadow and not s.wallBehind then
        return nil
    end
    return { level = s.level, floor = s.floor and { standY = s.floor.standY, depth = s.floor.depth } or nil,
        wall = wall, wallShadow = s.wallShadow, wallBehind = s.wallBehind, mipo = mipo }
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
    local settings = lib.settings()
    -- another level, or other Mipo rows: the parts' settings off first, then on again as they are now
    local applied = level.name .. '|' .. mipoKey(settings)
    if state.sceneLightApplied ~= applied then
        lib.unapply()
        state.sceneLightApplied = applied
    end
    local lit = litParts()
    local values = mipoValues(level, settings)
    local onlyMaterials = level.mipoParts == nil -- off: only the parts in a material
    -- look for parts again only when an sfixture came or went (a Mipo added or rerolled: lit in that
    -- frame), or once a second (a part's picture remade on the same fixture); walking every Mipo's
    -- fixtures each frame was ~4% of a lit frame on the phone with 20 Mipos
    local now = love.timer.getTime()
    local version = registry.sfixtureVersion
    local due = state.sceneLightScan == nil or state.sceneLightScan.version ~= version
        or now - state.sceneLightScan.at > 1 or state.sceneLightScan.level ~= applied
    if values and due then
        state.sceneLightScan = { version = version, at = now, level = applied }
        eachMipoPartExtra(function(extra)
            if lit[extra] or (onlyMaterials and not extra.material) then return end
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
    if type(shared) == 'function' then shared = shared(settings) end
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
