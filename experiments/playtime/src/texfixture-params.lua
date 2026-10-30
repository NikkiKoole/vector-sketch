-- texfixture-params.lua
-- What the inspector (src/ui/inspector.lua) shows for a selected texfixture, one
-- list per accordion in src/ui/sfixture-editor.lua: position, texture, hairs,
-- plasticine and the patch layers. The target is the fixture; settings live in
-- `extra` (layers in extra.main / extra.patch1..3). Changing an image or colour
-- marks the texture dirty so the composite is rebuilt. Resizing replaces the
-- fixture, so those sets return the new one. Ranges are the old panel's.
local lib = {}
local utils = require('src.utils')

local state = require('src.state')
local shaders = require('src.render.shaders') -- the shader defaults
local fixtures = require('src.fixtures')
local mathutils = require('src.math-utils')
local modes = require('src.modes')

local function extraOf(fixture) return fixture:getUserData().extra end

local function layerOf(fixture, layer)
    local e = extraOf(fixture)
    e[layer] = e[layer] or {}
    return e[layer]
end

local function startVertexEdit(fixture)
    state.texFixtureEdit.tempVerts = utils.shallowCopy(extraOf(fixture).vertices)
end

local function dimensions(fixture)
    local points = extraOf(fixture).vertices or { fixture:getShape():getPoints() }
    return mathutils.getPolygonDimensions(points)
end

-- resizing replaces the fixture: select the new one
local function resize(fixture, w, h)
    local newFixture = fixtures.updateSFixtureDimensions(fixture, w, h)
    state.selection.selectedSFixture = newFixture
    return newFixture
end

local function imageSize(fixture)
    local path = (extraOf(fixture).main or {}).bgURL
    if not path or love.filesystem.getInfo('textures/' .. path, 'file') == nil then return end
    local ok, img = pcall(love.graphics.newImage, 'textures/' .. path)
    if ok then return img:getDimensions() end
end

lib.position = {
    { kind = 'action', label = '∆ move',
      run = function() modes.set(modes.POSITIONING_SFIXTURE) end },
    { kind = 'action', label = 'centre on body',
      run = function(_, fixture)
          local body = fixture:getBody()
          local newFixture = fixtures.updateSFixturePosition(fixture, body:getX(), body:getY())
          state.selection.selectedSFixture = newFixture
          startVertexEdit(newFixture)
          return newFixture
      end },
    { key = 'size from', kind = 'buttons', options = { 'body', 'image' },
      run = function(_, fixture, option)
          local w, h
          if option == 'body' then
              local _, _, bw, bh = mathutils.getCenterAndDimensions(fixture:getBody())
              w, h = bw, bh
          else
              w, h = imageSize(fixture)
              if not w then return end
              -- the old panel also stored the image size on a rectangle body (no rebuild)
              local thing = utils.thingOf(fixture:getBody())
              if thing and thing.shapeType == 'rectangle' then thing.width, thing.height = w, h end
          end
          local newFixture = resize(fixture, w, h)
          startVertexEdit(newFixture)
          return newFixture
      end },
    { key = 'edit verts', kind = 'bool',
      get = function() return state.texFixtureEdit.lockedVerts == false end,
      set = function(fixture, v)
          local edit = state.texFixtureEdit
          edit.lockedVerts = not v
          if v then
              startVertexEdit(fixture)
          else
              edit.tempVerts = nil
              edit.centroid = nil
          end
      end },
    { key = 'corners', kind = 'choice', options = { 4, 8 },
      get = function(fixture) return extraOf(fixture).vertexCount or 4 end,
      set = function(fixture, v) extraOf(fixture).vertexCount = v end },
    { key = 'width', kind = 'number', min = 1, max = 1000, step = 1, advanced = true,
      get = function(fixture) return (dimensions(fixture)) end,
      set = function(fixture, v)
          local w, h = dimensions(fixture)
          if math.abs(v - w) > 1 then return resize(fixture, v, h) end
      end },
    { key = 'height', kind = 'number', min = 1, max = 1000, step = 1, advanced = true,
      get = function(fixture) local _, h = dimensions(fixture); return h end,
      set = function(fixture, v)
          local w, h = dimensions(fixture)
          if math.abs(v - h) > 1 then return resize(fixture, w, v) end
      end },
    { key = 'z offset', kind = 'number', min = -180, max = 180, step = 1, advanced = true,
      get = function(fixture) return extraOf(fixture).zOffset or 0 end,
      set = function(fixture, v) extraOf(fixture).zOffset = math.floor(v) end },
}

-- Layer settings (main, patch1..3). Images and colours mark the texture dirty;
-- a colour also drops the layer's cached composite.
local function layerColor(layer, key, label, extra)
    local row = { key = layer .. ' ' .. label, label = label, kind = 'color',
        get = function(fixture) return layerOf(fixture, layer)[key] end,
        set = function(fixture, v)
            local l = layerOf(fixture, layer)
            l[key] = v
            l.cached = nil
            extraOf(fixture).dirty = true
        end }
    for k, v in pairs(extra or {}) do row[k] = v end
    return row
end

local function layerImage(layer, key, label, extra)
    local row = { key = layer .. ' ' .. label, label = label, kind = 'file',
        get = function(fixture) return layerOf(fixture, layer)[key] or '' end,
        set = function(fixture, v)
            layerOf(fixture, layer)[key] = v
            extraOf(fixture).dirty = true
        end }
    for k, v in pairs(extra or {}) do row[k] = v end
    return row
end

local function layerNumber(layer, key, label, min, max, default, extra)
    local row = { key = layer .. ' ' .. label, label = label, kind = 'number', min = min, max = max,
        get = function(fixture) return layerOf(fixture, layer)[key] or default end,
        set = function(fixture, v)
            layerOf(fixture, layer)[key] = v
            extraOf(fixture).dirty = true
        end }
    for k, v in pairs(extra or {}) do row[k] = v end
    return row
end

-- rotation in degrees on screen, radians in the data
local function layerAngle(layer, key, label, extra)
    local row = { key = layer .. ' ' .. label, label = label, kind = 'number', min = 0, max = 360, step = 1,
        get = function(fixture) return math.deg(layerOf(fixture, layer)[key] or 0) end,
        set = function(fixture, v)
            layerOf(fixture, layer)[key] = math.rad(v)
            extraOf(fixture).dirty = true
        end }
    for k, v in pairs(extra or {}) do row[k] = v end
    return row
end

local function layerFlip(layer, key, label)
    return { key = layer .. ' ' .. label, label = label, kind = 'bool',
        get = function(fixture) return layerOf(fixture, layer)[key] == -1 end,
        set = function(fixture, v)
            layerOf(fixture, layer)[key] = v and -1 or 1
            extraOf(fixture).dirty = true
        end }
end

local function concat(...)
    local out = {}
    for _, list in ipairs({ ... }) do
        for _, row in ipairs(list) do out[#out + 1] = row end
    end
    return out
end

local function withVisible(rows, visible)
    for _, row in ipairs(rows) do row.visible = visible end
    return rows
end

-- outline / mask / pattern images + their colours; the pattern's own transform is advanced
local function ompRows(layer)
    return {
        layerImage(layer, 'bgURL', 'bg'),
        layerColor(layer, 'bgHex', 'bg color'),
        layerImage(layer, 'fgURL', 'fg'),
        layerColor(layer, 'fgHex', 'fg color'),
        layerImage(layer, 'pURL', 'pattern'),
        layerColor(layer, 'pHex', 'pat color'),
        layerAngle(layer, 'pr', 'pat rotate', { advanced = true }),
        layerNumber(layer, 'psx', 'pat scale x', 0.01, 3, 1, { advanced = true }),
        layerNumber(layer, 'psy', 'pat scale y', 0.01, 3, 1, { advanced = true }),
        layerNumber(layer, 'ptx', 'pat x', -1, 1, 0, { advanced = true }),
        layerNumber(layer, 'pty', 'pat y', -1, 1, 0, { advanced = true }),
    }
end

local function flipAndTint(layer)
    return {
        layerFlip(layer, 'fx', 'flip x'),
        layerFlip(layer, 'fy', 'flip y'),
        layerColor(layer, 'tint', 'tint'),
    }
end

lib.ompRows = ompRows -- the blob's look (src/sfixture-params.lua) uses the same rows

local function isOMP(fixture) return extraOf(fixture).OMP == true end
local function notOMP(fixture) return not isOMP(fixture) end

local function extraFlag(key, label)
    return { key = label, kind = 'bool',
        get = function(fixture) return extraOf(fixture)[key] == true end,
        set = function(fixture, v) extraOf(fixture)[key] = v end }
end

lib.texture = concat({
    { key = 'mode', kind = 'choice', options = { 'BG + FG', 'OMP' },
      get = function(fixture) return isOMP(fixture) and 'OMP' or 'BG + FG' end,
      set = function(fixture, v) extraOf(fixture).OMP = (v == 'OMP') end },
    extraFlag('hairs', 'hairs'),
    extraFlag('plasticine', 'plasticine'),
}, withVisible({
    layerImage('main', 'bgURL', 'bg'),
    layerColor('main', 'bgHex', 'bg color'),
    layerImage('main', 'fgURL', 'fg'),
    layerColor('main', 'fgHex', 'fg color'),
}, notOMP), withVisible(concat(ompRows('main'), flipAndTint('main')), isOMP))

-- Hairs and plasticine are shader settings: no composite rebuild needed.
local function shaderNumber(key, label, min, max, extra)
    local row = { key = key, label = label, kind = 'number', min = min, max = max,
        get = function(fixture)
            local v = extraOf(fixture)[key]
            if v == nil then v = shaders[key] end
            return v
        end,
        set = function(fixture, v) extraOf(fixture)[key] = v end }
    for k, v in pairs(extra or {}) do row[k] = v end
    return row
end

local function shaderColor(key, label)
    return { key = key, label = label, kind = 'color',
        get = function(fixture) return extraOf(fixture)[key] or shaders[key] end,
        set = function(fixture, v) extraOf(fixture)[key] = v end }
end

-- Light and mottle: both shaders read these (sendSharedLighting in box2d-draw-textured).
local surfaceLight = {
    { key = 'lighting', kind = 'bool',
      get = function(fixture) return extraOf(fixture).plasticineUseLighting ~= false end,
      set = function(fixture, v) extraOf(fixture).plasticineUseLighting = v end },
    shaderColor('plasticineWarmHex', 'warm (lit)'),
    shaderColor('plasticineCoolHex', 'cool'),
    shaderNumber('plasticineMottleStrength', 'mottle', 0, 0.5, { advanced = true }),
    shaderNumber('plasticineMottleScale', 'mottle size', 1, 20, { advanced = true }),
    shaderNumber('plasticineSpecPow', 'shine tight', 2, 120, { advanced = true }),
    shaderNumber('plasticineSpecStrength', 'shine', 0, 1, { advanced = true }),
    shaderNumber('plasticineSSSpow', 'sss falloff', 0.5, 8, { advanced = true }),
    shaderNumber('plasticineSSSstrength', 'sss', 0, 1, { advanced = true }),
    shaderNumber('plasticineTerminator', 'terminator', 0.5, 6, { advanced = true }),
}

lib.hairs = concat({
    shaderNumber('hairsStrength', 'strength', 0, 1),
    shaderNumber('hairsDensity', 'density', 1, 30),
    shaderNumber('hairsFuzz', 'fuzz', 0, 0.5),
    shaderNumber('hairsBush', 'bush', 0, 3),
}, surfaceLight)

lib.plasticine = concat({
    { key = 'form', kind = 'bool',
      get = function(fixture) return extraOf(fixture).plasticineForm ~= false end,
      set = function(fixture, v) extraOf(fixture).plasticineForm = v end },
    { key = 'rim', kind = 'choice', options = { 'silhouette', 'vignette', 'off' },
      get = function(fixture) return extraOf(fixture).plasticineRimStyle or 'silhouette' end,
      set = function(fixture, v) extraOf(fixture).plasticineRimStyle = v end },
    shaderNumber('plasticineStrength', 'grain', 0, 0.6),
    shaderNumber('plasticineScale', 'grain fine', 4, 120),
    shaderNumber('plasticineEdge', 'edge dark', 0, 0.6),
    shaderNumber('plasticineFormStrength', 'form depth', 0, 6, { advanced = true }),
    shaderNumber('plasticineFormRadius', 'form size', 0.01, 0.2, { advanced = true }),
}, surfaceLight)

-- A patch layer: its images, where it sits on the texture, flips and tint.
local patches = {}
function lib.patch(layer)
    patches[layer] = patches[layer] or concat(ompRows(layer), {
        layerAngle(layer, 'r', 'rotate'),
        layerNumber(layer, 'sx', 'scale x', 0.01, 3, 1),
        layerNumber(layer, 'sy', 'scale y', 0.01, 3, 1),
        layerNumber(layer, 'tx', 'x', -1, 1, 0),
        layerNumber(layer, 'ty', 'y', -1, 1, 0),
    }, flipAndTint(layer))
    return patches[layer]
end

return lib
