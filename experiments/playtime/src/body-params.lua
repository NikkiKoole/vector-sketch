-- body-params.lua
-- What the inspector (src/ui/inspector.lua) shows for a selected body. The
-- target is the body's `thing`. Size rows rebuild the body
-- (objectManager.recreateThingFromBody) and flips replace the thing; those sets
-- return the new thing so the panel stops drawing the old one. The lists
-- (behaviors, joints, sfixtures) and polygon tools stay custom in
-- src/ui/body-editor.lua. Ranges are the ones the old panel used.
local ST = require('src.shape-types')

local lib = {}

-- lazy: object-manager -> registry -> snap -> ...
local function selectThing(newThing)
    require('src.state').selection.selectedObj = newThing
    return newThing
end

local function rebuild(thing, settings)
    settings.shapeType = thing.shapeType
    local prefs = require('src.state').editorPreferences
    for _, k in ipairs({ 'width', 'height', 'radius' }) do
        if settings[k] then prefs['lastUsed' .. k:sub(1, 1):upper() .. k:sub(2)] = settings[k] end
    end
    return selectThing(require('src.object-manager').recreateThingFromBody(thing.body, settings))
end

-- Collision fixtures only: sfixtures (sensors with userData) come first on a
-- body and must keep their own settings.
local function collisionFixtures(thing)
    local list = {}
    for _, fixture in ipairs(thing.body:getFixtures()) do
        if fixture:getUserData() == nil then list[#list + 1] = fixture end
    end
    return list
end

local function hasCollision(thing) return collisionFixtures(thing)[1] ~= nil end

local function fixtureRow(key, min, max, getter, setter, extra)
    local row = { key = key, kind = 'number', min = min, max = max, visible = hasCollision,
        get = function(thing) return collisionFixtures(thing)[1][getter](collisionFixtures(thing)[1]) end,
        set = function(thing, v)
            for _, fixture in ipairs(collisionFixtures(thing)) do fixture[setter](fixture, v) end
            if setter == 'setDensity' then thing.body:resetMassData() end
        end }
    for k, v in pairs(extra or {}) do row[k] = v end
    return row
end

local function shapeIs(...)
    local set = {}
    for _, s in ipairs({ ... }) do set[s] = true end
    return function(thing) return set[thing.shapeType] == true end
end

-- A size row: shown for the given shapes, rebuilds the body on change.
local function size(key, max, shown, fallback)
    return { key = key, kind = 'number', min = 1, max = max, step = 1, visible = shown,
        get = function(thing) return thing[key] or (fallback and fallback(thing)) or 1 end,
        set = function(thing, v) return rebuild(thing, { [key] = v }) end }
end

local isRound = shapeIs(ST.CIRCLE, ST.TRIANGLE, ST.PENTAGON, ST.HEXAGON, ST.HEPTAGON, ST.OCTAGON)
local isBox = shapeIs(ST.RECTANGLE, ST.ITRIANGLE, ST.TORSO, ST.TRAPEZIUM, ST.CAPSULE)
local isTorso = shapeIs(ST.TORSO)
local hasWidth2 = shapeIs(ST.TORSO, ST.TRAPEZIUM, ST.CAPSULE)
local function width(thing) return thing.width end
local function height(thing) return thing.height end

local function flip(axis)
    return { kind = 'action', label = 'flip ' .. axis,
        run = function(_, thing) return selectThing(require('src.object-manager').flipThing(thing, axis, true)) end }
end

lib.rows = {
    { key = 'type', kind = 'choice', options = { 'static', 'dynamic', 'kinematic' },
      get = function(thing) return thing.body:getType() end,
      set = function(thing, v) thing.body:setType(v); thing.body:setAwake(true) end },
    { key = 'label', kind = 'text', keepSpaces = true,
      get = function(thing) return thing.label or '' end,
      set = function(thing, v) thing.label = v end },
    size('radius', 200, isRound),
    size('width', 800, isBox),
    size('width2', 800, hasWidth2, width),
    size('width3', 800, isTorso, width),
    size('height', 800, isBox),
    size('height2', 800, isTorso, height),
    size('height3', 800, isTorso, height),
    size('height4', 800, isTorso, height),
    fixtureRow('density', 0, 10, 'getDensity', 'setDensity'),
    fixtureRow('bounce', 0, 1, 'getRestitution', 'setRestitution'),
    fixtureRow('friction', 0, 1, 'getFriction', 'setFriction'),
    flip('x'),
    flip('y'),
    -- advanced
    { key = 'fixed angle', kind = 'bool', advanced = true,
      get = function(thing) return thing.body:isFixedRotation() end,
      set = function(thing, v) thing.body:setFixedRotation(v) end },
    { key = 'angle', kind = 'number', min = -180, max = 180, step = 1, advanced = true,
      get = function(thing) return math.deg(thing.body:getAngle()) end,
      set = function(thing, v) thing.body:setAngle(math.rad(v)) end },
    { key = 'x', kind = 'numberText', advanced = true,
      get = function(thing) return thing.body:getX() end,
      set = function(thing, v) thing.body:setX(v) end },
    { key = 'y', kind = 'numberText', advanced = true,
      get = function(thing) return thing.body:getY() end,
      set = function(thing, v) thing.body:setY(v) end },
    { key = 'sensor', kind = 'bool', advanced = true, visible = hasCollision,
      get = function(thing) return collisionFixtures(thing)[1]:isSensor() end,
      set = function(thing, v)
          for _, fixture in ipairs(collisionFixtures(thing)) do fixture:setSensor(v) end
      end },
    { key = 'group', kind = 'numberText', advanced = true, visible = hasCollision,
      get = function(thing) return thing.body:getFixtures()[1]:getGroupIndex() end,
      set = function(thing, v)
          v = math.max(-32768, math.min(32767, math.floor(v)))
          for _, fixture in ipairs(thing.body:getFixtures()) do fixture:setGroupIndex(v) end
      end },
    { key = 'ang damp', kind = 'number', min = 0, max = 10, advanced = true,
      get = function(thing) return thing.body:getAngularDamping() end,
      set = function(thing, v) thing.body:setAngularDamping(v) end },
    { key = 'lin damp', kind = 'number', min = 0, max = 10, advanced = true,
      get = function(thing) return thing.body:getLinearDamping() end,
      set = function(thing, v) thing.body:setLinearDamping(v) end },
    { key = 'sleep ok', kind = 'bool', advanced = true,
      get = function(thing) return thing.body:isSleepingAllowed() end,
      set = function(thing, v) thing.body:setSleepingAllowed(v) end },
    { key = 'bullet', kind = 'bool', advanced = true,
      get = function(thing) return thing.body:isBullet() end,
      set = function(thing, v) thing.body:setBullet(v) end },
    { key = 'spin', kind = 'number', min = -180, max = 180, advanced = true,
      get = function(thing) return math.deg(thing.body:getAngularVelocity()) end,
      set = function(thing, v) thing.body:setAngularVelocity(math.rad(v)) end },
}

return lib
