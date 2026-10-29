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

-- Every sfixture panel starts with its name (header) and ends with destroy (footer).
lib.header = {
    { key = 'label', kind = 'text', keepSpaces = true,
      get = function(fixture) return fixture:getUserData().label or '' end,
      set = function(fixture, v)
          local ud = require('src.utils').shallowCopy(fixture:getUserData())
          ud.label = v
          fixture:setUserData(ud)
      end },
}

lib.footer = {
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
    { kind = 'action', label = 'centre',
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
    -- the grass rebuilds itself when any of these change (src/grass.lua)
    [subtypes.GRASS] = concat({
        extraNumber('density', 'density', 0.5, 40, 8, nil, { step = 0.5 }),
        extraNumber('height', 'height', 5, 600, 90, nil, { step = 1 }),
        extraNumber('heightVariation', 'variation', 0, 1, 0.5),
        extraNumber('width', 'width', 0.2, 4, 1),
        extraNumber('frontShare', 'in front', 0, 1, 0.25),
        { key = 'back color', kind = 'color',
          get = function(fixture) return extraOf(fixture).colorBack or '2a5b3eff' end,
          set = function(fixture, v) extraOf(fixture).colorBack = v end },
        { key = 'front color', kind = 'color',
          get = function(fixture) return extraOf(fixture).colorFront or '86a542ff' end,
          set = function(fixture, v) extraOf(fixture).colorFront = v end },
        extraNumber('sway', 'sway', 0, 3, 1),
        extraNumber('maxSlope', 'max slope', 0, 89, 50, nil, { step = 1, advanced = true }),
        extraNumber('seed', 'seed', 0, 100, 0, nil, { step = 1, advanced = true }),
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
    -- water in a container (src/liquid.lua): how full (of the body's hollow), the look
    [subtypes.LIQUID] = concat({
        extraNumber('fill', 'fill', 0, 1, 0.6),
        extraNumber('slosh', 'slosh', 0, 3, 1), -- how much moving it rocks the surface
        extraNumber('settle', 'settle', 0.1, 4, 1), -- how quickly that calms down
        { key = 'color', kind = 'color',
          get = function(fixture) return extraOf(fixture).color or '3aa7d9b3' end,
          set = function(fixture, v) extraOf(fixture).color = v end },
        { key = 'surface', kind = 'color',
          get = function(fixture) return extraOf(fixture).surfaceColor or 'cdeeffff' end,
          set = function(fixture, v) extraOf(fixture).surfaceColor = v end },
        { key = 'in front', kind = 'bool', -- in front of the Mipos, for a bath
          get = function(fixture) return extraOf(fixture).front == true end,
          set = function(fixture, v) extraOf(fixture).front = v end },
        zOffset,
    }, position),
    -- a blob (src/blob.lua): size and squish, then the look. Size, rim points and the
    -- outline (bg) rebuild the rim; the rest applies on the fly.
    [subtypes.SOFTBODY] = concat({
        extraNumber('height', 'size', 40, 2000, 300, nil, { step = 1 }),
        extraNumber('stiffness', 'stiffness', 0.5, 20, 4),
        extraNumber('pressure', 'pressure', 0, 4, 1),
        extraNumber('restitution', 'bounce', 0, 1, 0.05),
        extraNumber('damping', 'damping', 0, 1, 0.5, nil, { advanced = true }),
        extraNumber('bend', 'bend', 0, 20, 3, nil, { advanced = true }),
        extraNumber('friction', 'friction', 0, 2, 0.7, nil, { advanced = true }),
        extraNumber('rimPoints', 'rim points', 8, 64, 28, nil, { step = 1, advanced = true }),
        extraNumber('drawSmooth', 'smooth edge', 0, 8, 4, nil, { step = 1, advanced = true }),
        { kind = 'action', label = 'new look',
          run = function(_, fixture)
              local e = extraOf(fixture)
              e.main = require('src.blob').randomLook()
              e.dirty = true
          end },
    }, require('src.texfixture-params').ompRows('main'), { zOffset }, position),
}

return lib
