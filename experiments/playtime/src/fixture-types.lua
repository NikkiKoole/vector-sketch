-- fixture-types.lua — data-driven registry for sfixture creation
local subtypes = require('src.subtypes')
local shapes = require('src.shapes')

local rect = shapes.rect

local function rect8(w, h, x, y)
    return {
        x - w / 2, y - h / 2,
        x, y - h / 2,
        x + w / 2, y - h / 2,
        x + w / 2, y,
        x + w / 2, y + h / 2,
        x, y + h / 2,
        x - w / 2, y + h / 2,
        x - w / 2, y,
    }
end

local fixtureTypes = {}

-- Most subtypes: square sensor with cfg.radius
local function simpleEntry(subtype, opts)
    opts = opts or {}
    return {
        subtype = subtype,
        getSize = opts.getSize or function(cfg) return cfg.radius, cfg.radius end,
        getExtra = function() return {} end,
    }
end

fixtureTypes[subtypes.SNAP] = simpleEntry(subtypes.SNAP, {
    getSize = function(cfg) return cfg.radius * 5, cfg.radius * 5 end,
})
fixtureTypes[subtypes.ANCHOR]            = simpleEntry(subtypes.ANCHOR)
fixtureTypes[subtypes.CONNECTED_TEXTURE] = simpleEntry(subtypes.CONNECTED_TEXTURE)
fixtureTypes[subtypes.TRACE_VERTICES]    = simpleEntry(subtypes.TRACE_VERTICES)
fixtureTypes[subtypes.TILE_REPEAT]       = simpleEntry(subtypes.TILE_REPEAT)
fixtureTypes[subtypes.RESOURCE] = simpleEntry(subtypes.RESOURCE, {
    getSize = function(cfg) return cfg.radius or 20, cfg.radius or 20 end,
})
fixtureTypes[subtypes.UVUSERT] = simpleEntry(subtypes.UVUSERT, {
    getSize = function(cfg) return cfg.radius or 20, cfg.radius or 20 end,
})
fixtureTypes[subtypes.MESHUSERT] = simpleEntry(subtypes.MESHUSERT, {
    getSize = function(cfg) return cfg.radius or 20, cfg.radius or 20 end,
})
fixtureTypes[subtypes.TEXFIXTURE] = {
    subtype = subtypes.TEXFIXTURE,
    density = 0,
    getSize = function(cfg) return cfg.width, cfg.height end,
    getExtra = function(cfg, localX, localY)
        local vertexCount = 4
        local vertices = vertexCount == 4
            and rect(cfg.width, cfg.height, localX, localY)
            or rect8(cfg.width, cfg.height, localX, localY)
        return { vertexCount = vertexCount, vertices = vertices }
    end,
}

-- Expose rect8 for updateSFixtureDimensions in fixtures.lua
fixtureTypes.rect8 = rect8

return fixtureTypes
