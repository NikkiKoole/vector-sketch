-- scene-light.lua — the scene's light level, saved with the scene (LIGHT-AND-SHADOW LS13, ENGINE-MERGE EM1).
-- Nikki 2026-11-06: "I basically want it all, but not always, in cost-efficient steps": a level per scene,
-- stepped through with the light button under the sound button (src/ui/tool-rail.lua), each level adding
-- the next cheapest: off (as drawn) / lit (Mipos lit without clay, contact shadows). Shadows and full
-- come later, as the rest of light-grass-check's script moves in.
-- A level is a table of settings (lib.LEVELS), so tuning one is editing data here.
-- Off touches nothing: scenes that light themselves (light-grass-check, mipo-materials) work as before.
-- The settings put on a part are taken off again (the part's own values back) when the level drops and
-- before a save (lib.unapply), so they never end up in a scene file.
local lib = {}

local state = require('src.state')
local mipoRegistry = require('src.mipo-registry')

-- the Mipo parts that take the light: picture parts, limb ribbons, torso skin (not the face's decals: a
-- face stays as drawn)
local LIT_PARTS = { texfixture = true, ['connected-texture'] = true, ['trace-vertices'] = true }

-- Each level in order; `mipoParts` goes on every lit Mipo part's extra (the plasticine shader's settings,
-- src/render/shaders.lua), `contactShadows` becomes state.contactShadows (src/contact-shadows.lua).
-- The lit values: light-grass-check's liked ones (its o), the Mipos' own frontal light and softer swing,
-- clay off (LS23: ~5.6 ms for 20 Mipos on the phone instead of ~9.5).
lib.LEVELS = {
    { name = 'off' },
    { name = 'lit',
        mipoParts = {
            plasticine = true, plasticineLightAdd = true, plasticineLightGain = 0.3, plasticineLightZ = 0.75,
            plasticineFormRadius = 0.35, plasticineFormBaked = true, plasticineFormRise = 1,
            -- clay off: light and roundness only
            plasticineStrength = 0, plasticineBump = 0, plasticineSpecStrength = 0, plasticineSSSstrength = 0,
        },
        contactShadows = { strength = 0.45 },
        -- a scene without lights of its own gets these (src/render/shaders.lua): light-grass-check's day,
        -- the sun high on the left, the sky light at its 1.3 strength
        lights = {
            { lightType = 'directional', toLight = { -0.5, -0.85 }, colorHex = 'fff2d9ff', intensity = 1.2 },
            { lightType = 'sky', toLight = { 0, -1 }, colorHex = '9cc8ffff', groundHex = '8a7a50ff', intensity = 0.78 },
        },
    },
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
    state.sceneLight = { level = saved and saved.level or 'off' }
    return state.sceneLight
end

-- for a scene file (off: nothing, the file stays as it was)
function lib.save()
    local s = lib.settings()
    if s.level == 'off' then return nil end
    return { level = s.level }
end

-- the parts lit now: extra -> the values it had before (false for none), kept on state (hot reload)
-- weak keys: a rerolled Mipo's old parts go
local function litParts()
    state.sceneLitParts = state.sceneLitParts or setmetatable({}, { __mode = 'k' })
    return state.sceneLitParts
end

local function restore(extra, before)
    for key, v in pairs(before) do
        if v == false then extra[key] = nil else extra[key] = v end
    end
end

-- every part back to its own values (the level dropped, or a save is coming)
function lib.unapply()
    local lit = litParts()
    for extra, before in pairs(lit) do restore(extra, before) end
    state.sceneLitParts = setmetatable({}, { __mode = 'k' })
    if state.contactShadows and state.contactShadows == state.sceneLightContact then
        state.contactShadows = nil
    end
    state.sceneLightContact = nil
    state.sceneDefaultLights = nil
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
    local lit = litParts()
    if level.name == 'off' then
        if next(lit) or state.sceneLightContact then lib.unapply() end
        return
    end
    if state.sceneLightApplied ~= level.name then
        lib.unapply() -- another level: its settings off first
        lit = litParts()
        state.sceneLightApplied = level.name
    end
    local values = level.mipoParts
    if values then
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
    state.sceneDefaultLights = level.lights
    if level.contactShadows and (state.contactShadows == nil or state.contactShadows == state.sceneLightContact) then
        state.contactShadows = level.contactShadows
        state.sceneLightContact = level.contactShadows
    end
end

return lib
