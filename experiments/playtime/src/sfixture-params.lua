-- sfixture-params.lua
-- What the inspector (src/ui/inspector.lua) shows for a selected sfixture (a
-- special sensor fixture: snap point, anchor, light, ...). The target is the
-- Box2D fixture; settings live in its userData (`label`, `extra`). Moving or
-- resizing replaces the fixture, so those return the new one. Subtypes not in
-- `bySubtype` (texfixture, meshusert, resource, connected-texture,
-- trace-vertices) still use the hand-made panel in src/ui/sfixture-editor.lua.
local subtypes = require('src.subtypes')

local lib = {}

-- lazy: fixtures -> registry -> snap -> ...
local function state() return require('src.state') end

local function extraOf(fixture) return fixture:getUserData().extra end

local function selectFixture(fixture)
    state().selection.selectedSFixture = fixture
    return fixture
end

lib.header = {
    { key = 'label', kind = 'text', keepSpaces = true,
      get = function(fixture) return fixture:getUserData().label or '' end,
      set = function(fixture, v)
          local ud = require('src.utils').shallowCopy(fixture:getUserData())
          ud.label = v
          fixture:setUserData(ud)
      end },
    { kind = 'action', label = 'destroy',
      run = function(_, fixture)
          require('src.fixtures').destroyFixture(fixture)
          state().selection.selectedSFixture = nil
          return true -- gone: stop drawing this panel
      end },
}

-- Move the sfixture to an edge (N/E/S/W) or the centre (C) of its body's
-- bounding box, keeping its shape.
local function placeOnEdge(fixture, place)
    local mathutils = require('src.math-utils')
    local m = ({ N = { 0, -1 }, E = { 1, 0 }, S = { 0, 1 }, W = { -1, 0 }, C = { 0, 0 } })[place]
    local body = fixture:getBody()
    local bounds = mathutils.getBoundingRect(body:getUserData().thing.vertices)
    local points = { fixture:getShape():getPoints() }
    local cx, cy = mathutils.getCenterOfPoints(points)
    local relative = mathutils.makePolygonRelativeToCenter(points, cx, cy)
    local moved = mathutils.makePolygonAbsolute(relative, (bounds.width / 2) * m[1], (bounds.height / 2) * m[2])
    local ud = require('src.utils').shallowCopy(fixture:getUserData())
    fixture:destroy()
    local newFixture = love.physics.newFixture(body, love.physics.newPolygonShape(moved))
    newFixture:setSensor(true)
    newFixture:setUserData(ud)
    require('src.registry').registerSFixture(ud.id, newFixture)
    return selectFixture(newFixture)
end

local position = {
    { kind = 'action', label = '∆ move',
      run = function() local modes = require('src.modes'); modes.set(modes.POSITIONING_SFIXTURE) end },
    { kind = 'action', label = 'centre on body',
      run = function(_, fixture)
          local body = fixture:getBody()
          return selectFixture(require('src.fixtures').updateSFixturePosition(fixture, body:getX(), body:getY()))
      end },
    { key = 'radius', kind = 'number', min = 1, max = 200, step = 1,
      get = function(fixture)
          return require('src.math-utils').getPolygonDimensions({ fixture:getShape():getPoints() })
      end,
      set = function(fixture, v)
          state().selection.selectedSFixture = fixture -- updateSFixtureDimensions works on the selection
          return require('src.fixtures').updateSFixtureDimensions(v, v)
      end },
    { key = 'place', kind = 'buttons', options = { 'N', 'E', 'S', 'W', 'C' }, advanced = true,
      run = function(_, fixture, option) return placeOnEdge(fixture, option) end },
}

local function concat(...)
    local out = {}
    for _, list in ipairs({ ... }) do
        for _, row in ipairs(list) do out[#out + 1] = row end
    end
    return out
end

-- A number in `extra`; `changed(extra)` invalidates caches (mesh, composite).
local function extraNumber(key, label, min, max, default, changed, extra)
    local row = { key = label, kind = 'number', min = min, max = max,
        get = function(fixture) return extraOf(fixture)[key] or default end,
        set = function(fixture, v)
            local e = extraOf(fixture)
            e[key] = v
            if changed then changed(e) end
        end }
    for k, v in pairs(extra or {}) do row[k] = v end
    return row
end

local function mainOf(fixture)
    local e = extraOf(fixture)
    e.main = e.main or {}
    return e.main
end

local function tileMeshChanged(e) e._mesh = nil end
local function textureChanged(e) e.dirty = true end

local zOffset = extraNumber('zOffset', 'z offset', -180, 180, 0, nil, { step = 1, advanced = true })

lib.bySubtype = {
    [subtypes.SNAP] = position,
    [subtypes.ANCHOR] = position,
    [subtypes.UVUSERT] = position,
    [subtypes.TILE_REPEAT] = concat({
        { key = 'texture', kind = 'file',
          get = function(fixture) return mainOf(fixture).bgURL or '' end,
          set = function(fixture, v) mainOf(fixture).bgURL = v; textureChanged(extraOf(fixture)) end },
        { key = 'tint', kind = 'color',
          get = function(fixture) return mainOf(fixture).tint end,
          set = function(fixture, v) mainOf(fixture).tint = v; textureChanged(extraOf(fixture)) end },
        extraNumber('tileWidthM', 'tile width', 0.01, 100, 1, tileMeshChanged),
        extraNumber('tileHeightM', 'tile height', 0.01, 100, 1, tileMeshChanged),
        { key = 'rotation', kind = 'number', min = 0, max = 360, step = 1,
          get = function(fixture) return math.deg(extraOf(fixture).tileRotation or 0) end,
          set = function(fixture, v)
              local e = extraOf(fixture)
              e.tileRotation = math.rad(v)
              tileMeshChanged(e)
          end },
        zOffset,
    }, position),
    [subtypes.LIGHT] = concat({
        { key = 'color', kind = 'color',
          get = function(fixture) return extraOf(fixture).colorHex or 'fff2d9ff' end,
          set = function(fixture, v) extraOf(fixture).colorHex = v end },
        extraNumber('intensity', 'intensity', 0, 3, 1),
        { key = 'type', kind = 'choice', options = { 'directional', 'point' },
          get = function(fixture) return extraOf(fixture).lightType or 'directional' end,
          set = function(fixture, v) extraOf(fixture).lightType = v end },
        extraNumber('range', 'range', 10, 2000, 500),
        { kind = 'note',
          label = function(fixture)
              return (extraOf(fixture).lightType == 'point') and 'origin: this body\'s position'
                  or 'aim: rotate the body (body +X = light dir)'
          end },
    }, position),
}

return lib
